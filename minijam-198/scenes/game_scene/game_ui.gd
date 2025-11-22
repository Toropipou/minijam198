# GameManager.gd - Version dynamique avec vitesse adaptative
extends Node

# Variables de jeu
var score : int = 0
var combo : int = 0
var game_running : bool = false

# Système de vitesse dynamique
var speed : float = 200.0
const MIN_SPEED : float = 50.0
const MAX_SPEED : float = 1000.0
const BASE_SPEED : float = 200.0
const SPEED_INCREASE_ON_KILL : float = 100.0
const SPEED_DECREASE_ON_MISS : float = 250.0
const SPEED_DECAY_RATE : float = 10.0

# Métriques de performance
var enemies_killed : int = 0
var enemies_missed : int = 0
var kill_rate : float = 0.0
var performance_rating : float = 1.0

# Système de mana
var current_mana : float = 100.0
const MAX_MANA : float = 100.0
const MANA_REGEN_RATE : float = 35.0
const SPELL_MANA_COST : float = 25.0

# Liste des ennemis actifs
var active_enemies : Array = []

# Cooldown minimal entre sorts
const MIN_SPELL_COOLDOWN : float = 0.1
var spell_cooldown_timer : float = 0.0

# Timer pour calculer le kill rate
var time_elapsed : float = 0.0

# Références
@onready var viewport = $ViewportContainer/ConfigurableSubViewport
@onready var player = $ViewportContainer/ConfigurableSubViewport/Player
@onready var parallax = $ViewportContainer/ConfigurableSubViewport/Bg
@onready var spawner = $ViewportContainer/ConfigurableSubViewport/EnemySpawner
@onready var hud = $ViewportContainer/ConfigurableSubViewport/hud

func _ready() -> void:
	add_to_group("GM")
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	spawner.wave_completed.connect(_on_wave_completed)
	
	# Connecter le signal de santé du joueur au HUD
	player.health_changed.connect(_on_player_health_changed)
	
	new_game()

func new_game():
	score = 0
	combo = 0
	speed = BASE_SPEED
	game_running = false
	current_mana = MAX_MANA
	spell_cooldown_timer = 0.0
	
	# Reset métriques
	enemies_killed = 0
	enemies_missed = 0
	kill_rate = 0.0
	performance_rating = 1.0
	time_elapsed = 0.0
	
	spawner.clear_all_enemies()
	active_enemies.clear()
	
	hud.update_score(score)
	hud.show_start_message()
	
	if hud.has_method("update_mana"):
		hud.update_mana(current_mana, MAX_MANA)
	
	# Initialiser l'affichage des PV
	if hud.has_method("_on_player_health_changed"):
		hud._on_player_health_changed(player.current_health, player.max_health)

func _on_player_health_changed(current_health: int, max_health: int):
	"""Relayer le signal du joueur vers le HUD"""
	if hud.has_method("_on_player_health_changed"):
		hud._on_player_health_changed(current_health, max_health)

func _process(delta: float) -> void:
	if not game_running:
		if Input.is_action_just_pressed("ui_accept"):
			start_game()
		return
	hud.show_speed(speed)
	time_elapsed += delta
	
	# Régénération de la mana
	if current_mana < MAX_MANA:
		current_mana = min(current_mana + MANA_REGEN_RATE * delta, MAX_MANA)
		if hud.has_method("update_mana"):
			hud.update_mana(current_mana, MAX_MANA)
	
	# Décrémenter le cooldown des sorts
	if spell_cooldown_timer > 0:
		spell_cooldown_timer -= delta
	
	# Gestion dynamique de la vitesse
	update_dynamic_speed(delta)
	
	# Défilement du parallax
	parallax.scroll_offset.x -= speed * 2 * delta
	
	# Déplacer les ennemis
	var screen_left = -100
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.position.x -= speed / 2 * delta
			
			if enemy.position.x < screen_left:
				_on_enemy_escaped(enemy)
	
	# Calculer les métriques de performance
	calculate_performance_metrics()
	
	# Mettre à jour le spawner avec les métriques
	spawner.update_difficulty(performance_rating, speed)
	
	# Score augmente avec le temps
	score += delta * 10
	hud.update_score(int(score))
	
	# Debug info (optionnel)
	if hud.has_method("update_debug_info"):
		hud.update_debug_info(speed, performance_rating, kill_rate)

func update_dynamic_speed(delta: float):
	# La vitesse tend progressivement vers BASE_SPEED
	if speed > BASE_SPEED:
		speed = max(speed - SPEED_DECAY_RATE * delta, BASE_SPEED)
	elif speed < BASE_SPEED:
		speed = min(speed + SPEED_DECAY_RATE * delta, BASE_SPEED)
	
	# Clamp final
	speed = clamp(speed, MIN_SPEED, MAX_SPEED)

func increase_speed_from_difficulty(amount: float):
	"""Appelé par le spawner pour augmenter la vitesse basée sur la difficulté"""
	speed += amount
	speed = min(speed, MAX_SPEED)
	
	# Feedback visuel optionnel
	if hud.has_method("show_difficulty_increase"):
		hud.show_difficulty_increase()

func calculate_performance_metrics():
	# Calculer le kill rate (ennemis tués / minute)
	if time_elapsed > 0:
		kill_rate = (enemies_killed / time_elapsed) * 60.0
	
	# Calculer le rating de performance
	# Ratio kills/misses avec bonus pour combo élevé
	var total_encounters = enemies_killed + enemies_missed
	if total_encounters > 0:
		var success_rate = float(enemies_killed) / float(total_encounters)
		var combo_bonus = min(combo / 10.0, 0.5)
		performance_rating = (success_rate + combo_bonus) * 2.0
		performance_rating = clamp(performance_rating, 0.0, 2.0)
	else:
		performance_rating = 1.0

func start_game():
	game_running = true
	spawner.start_spawning()
	hud.hide_start_message()

func _on_enemy_spawned(enemy):
	active_enemies.append(enemy)
	
	enemy.destroyed.connect(_on_enemy_destroyed)
	enemy.weakness_hit.connect(_on_enemy_weakness_hit)
	enemy.wrong_spell_used.connect(_on_wrong_spell)

func _on_enemy_destroyed(enemy):
	active_enemies.erase(enemy)
	
	# BOOST DE VITESSE !
	speed += SPEED_INCREASE_ON_KILL
	speed = min(speed, MAX_SPEED)
	
	# Métriques
	enemies_killed += 1
	
	# Bonus de score avec combo
	combo += 1
	var points = 100 * combo
	score += points
	
	# Feedback visuel
	if hud.has_method("update_combo"):
		hud.update_combo(combo)
	if hud.has_method("show_points_popup"):
		hud.show_points_popup(points, enemy.position)
	if hud.has_method("show_speed_boost"):
		hud.show_speed_boost()

func _on_enemy_escaped(enemy):
	if not is_instance_valid(enemy):
		return
	
	active_enemies.erase(enemy)
	
	# RALENTISSEMENT !
	speed -= SPEED_DECREASE_ON_MISS
	speed = max(speed, MIN_SPEED)
	
	# Métriques
	enemies_missed += 1
	combo = 0
	
	# Feedback visuel
	if hud.has_method("update_combo"):
		hud.update_combo(combo)
	if hud.has_method("show_speed_penalty"):
		hud.show_speed_penalty()
	player.take_damage(1)
	enemy.queue_free()

func _on_enemy_weakness_hit(enemy, remaining: int):
	score += 50
	
	# Petit boost de vitesse pour chaque faiblesse touchée
	speed += 2.0
	speed = min(speed, MAX_SPEED)
	
	if hud.has_method("show_hit_feedback"):
		hud.show_hit_feedback(enemy.position, true)

func _on_wrong_spell(enemy, spell_type: String):
	combo = max(0, combo - 1)
	
	# Petit ralentissement pour erreur
	speed -= 5.0
	speed = max(speed, MIN_SPEED)
	
	if hud.has_method("update_combo"):
		hud.update_combo(combo)
	if hud.has_method("show_hit_feedback"):
		hud.show_hit_feedback(enemy.position, false)

func _on_wave_completed(wave_number: int):
	score += 500
	
	if hud.has_method("show_wave_complete"):
		hud.show_wave_complete(wave_number + 1)

func cast_spell(spell_type: String,lane) -> bool:
	if spell_cooldown_timer > 0:
		return false
	
	if current_mana < SPELL_MANA_COST:
		if hud.has_method("show_not_enough_mana"):
			hud.show_not_enough_mana()
		return false
	
	current_mana -= SPELL_MANA_COST
	spell_cooldown_timer = MIN_SPELL_COOLDOWN
	
	if hud.has_method("update_mana"):
		hud.update_mana(current_mana, MAX_MANA)
	
	var closest_enemy = get_closest_enemy()
	if closest_enemy:
		spawn_spell_projectile(spell_type, closest_enemy)
		player.play_cast_animation(spell_type,lane)
	
	return true

func spawn_spell_projectile(spell_type: String, target_enemy):
	pass

func get_closest_enemy():
	var closest = null
	var min_distance = INF
	
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			var distance = enemy.position.x - player.position.x
			if distance > 0 and distance < min_distance:
				min_distance = distance
				closest = enemy
	
	return closest

func get_mana_percentage() -> float:
	return (current_mana / MAX_MANA) * 100.0

func can_cast_spell() -> bool:
	return spell_cooldown_timer <= 0 and current_mana >= SPELL_MANA_COST

func get_current_speed() -> float:
	return speed

func get_performance_rating() -> float:
	return performance_rating

func switch_to_pattern_mode():
	spawner.set_pattern_mode()

func switch_to_endless_mode():
	spawner.set_endless_mode()

func switch_to_random_mode():
	spawner.set_random_mode()

func skip_to_wave(wave: int):
	spawner.skip_to_wave(wave)

func stop_game():
	game_running = false
	spawner.stop_spawning()
	spawner.clear_all_enemies()
	active_enemies.clear()

func add_mana(n: float) -> void:
	current_mana = clamp(current_mana + n, 0, MAX_MANA)
	
	if hud.has_method("update_mana"):
		hud.update_mana(current_mana, MAX_MANA)

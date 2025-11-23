# GameManager.gd - Version avec QTE de recharge mana
extends Node

@onready var qte_manager: Node = $ViewportContainer/ConfigurableSubViewport/QTE_Manager
var qte_mandatory := false

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
const MANA_REGEN_RATE : float = 0.0
const SPELL_MANA_COST : float = 10.0
const QTE_MANA_REFILL : float = 100.0  # Mana récupérée sur succès QTE

# QTE System
var current_qte_combination : Array = []
var qte_in_progress : bool = false
var trigger_pressed : bool = false

# Slow Motion & VFX
const QTE_TIME_SCALE : float = 0.3  # 30% de vitesse normale
const IMPACT_FREEZE_DURATION : float = 0.12  # Freeze frame à la fin
const FOCUS_FADE_DURATION : float = 0.25
var original_time_scale : float = 1.0
var is_in_slow_motion : bool = false

# Liste des ennemis actifs
var active_enemies : Array = []

# Cooldown minimal entre sorts
const MIN_SPELL_COOLDOWN : float = 0.1
var spell_cooldown_timer : float = 0.0

const QTE_COOLDOWN : float = 2.0  # Cooldown entre QTE
var qte_cooldown_timer : float = 0.0 

# Timer pour calculer le kill rate
var time_elapsed : float = 0.0

# Références
@onready var viewport = $ViewportContainer/ConfigurableSubViewport
@onready var player = $ViewportContainer/ConfigurableSubViewport/Player
@onready var parallax = $ViewportContainer/ConfigurableSubViewport/Bg
@onready var spawner = $ViewportContainer/ConfigurableSubViewport/EnemySpawner
@onready var hud = $ViewportContainer/ConfigurableSubViewport/hud

# Overlay pour l'effet de focus
var focus_overlay: ColorRect
var vignette_overlay: ColorRect 

func _ready() -> void:
	add_to_group("GM")
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	spawner.wave_completed.connect(_on_wave_completed)
	
	# Connecter le signal de santé du joueur au HUD
	player.health_changed.connect(_on_player_health_changed)
	
	# Connecter les signaux QTE
	qte_manager.qte_success.connect(_on_qte_success)
	qte_manager.qte_failed.connect(_on_qte_failed)
	qte_manager.qte_ended.connect(_on_qte_ended)
	qte_manager.qte_started.connect(_on_qte_started) 
	
	# Charger la scène QTE
	qte_manager.qte_scene = preload("res://scenes/game_scene/system/QTE_UI.tscn")
	# Créer les overlays pour l'effet de focus
	_create_focus_overlays()
	new_game()

func _create_focus_overlays() -> void:
	"""Crée les overlays visuels pour l'effet de focus"""
	# Overlay principal (désaturation)
	focus_overlay = ColorRect.new()
	focus_overlay.color = Color(0, 0, 0, 0)  # Noir transparent au départ
	focus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_overlay.z_index = 100
	focus_overlay.visible = false
	hud.add_child(focus_overlay)
	
	# Vignette (effet tunnel vision)
	vignette_overlay = ColorRect.new()
	vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_overlay.z_index = 99
	vignette_overlay.visible = false
	
	# Shader pour la vignette (optionnel, sinon utiliser material)
	var shader_material = ShaderMaterial.new()
	var shader_code = """
	shader_type canvas_item;
	
	uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.5;
	uniform float vignette_size : hint_range(0.0, 2.0) = 0.8;
	
	void fragment() {
		vec2 uv = UV - 0.5;
		float dist = length(uv);
		float vignette = smoothstep(vignette_size, vignette_size - 0.3, dist);
		COLOR.rgb = vec3(0.0);
		COLOR.a = (1.0 - vignette) * vignette_intensity;
	}
	"""
	var shader = Shader.new()
	shader.code = shader_code
	shader_material.shader = shader
	shader_material.set_shader_parameter("vignette_intensity", 0.6)
	shader_material.set_shader_parameter("vignette_size", 0.8)
	vignette_overlay.material = shader_material
	
	hud.add_child(vignette_overlay)


func new_game():
	score = 0
	combo = 0
	speed = BASE_SPEED
	game_running = false
	current_mana = MAX_MANA
	spell_cooldown_timer = 0.0
	qte_in_progress = false
	trigger_pressed = false
	is_in_slow_motion = false
	Engine.time_scale = 1.0
	
	# Générer une nouvelle combinaison QTE aléatoire
	_generate_random_qte_combination()
	
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

func _generate_random_qte_combination() -> void:
	"""Génère une combinaison aléatoire de 2-4 sorts pour le QTE"""
	var available_spells = ["spell_1", "spell_2", "spell_3", "spell_4"]
	var combination_length = randi_range(2, 3)
	
	current_qte_combination.clear()
	for i in range(combination_length):
		var random_spell = available_spells[randi() % available_spells.size()]
		current_qte_combination.append(random_spell)
	
	#print("Nouvelle combinaison QTE générée : ", current_qte_combination)

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
	if speed>800:hud.going_fast(true)
	else:hud.going_fast(false)
	time_elapsed += delta
	
	# Décrémenter cooldown QTE
	if qte_cooldown_timer > 0:
		qte_cooldown_timer -= delta
		if hud.has_method("update_qte_cooldown"):
			hud.update_qte_cooldown(qte_cooldown_timer, QTE_COOLDOWN)
	
	# Gestion du QTE avec les gâchettes
	_handle_qte_input()
	
	# Régénération de la mana (seulement si pas en QTE)
	if not qte_in_progress and current_mana < MAX_MANA:
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
	var screen_left = +250
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

func _handle_qte_input() -> void:
	"""Gère le démarrage/annulation du QTE avec les gâchettes"""
	if qte_mandatory:_start_mana_recharge_qte()
	# Vérifier si une gâchette est pressée (LT ou RT)
	var trigger_just_pressed = Input.is_action_just_pressed("trigger_left") or Input.is_action_just_pressed("trigger_right")
	var trigger_just_released = Input.is_action_just_released("trigger_left") or Input.is_action_just_released("trigger_right")
	
	# Démarrer le QTE au premier appui
	if trigger_just_pressed and not qte_in_progress:
		hud.hide_roue()
		_start_mana_recharge_qte()
		trigger_pressed = true
	
	# Annuler le QTE si la gâchette est relâchée
	if trigger_just_released and qte_in_progress:
		hud.show_roue()
		_cancel_mana_recharge_qte()
		trigger_pressed = false

func _start_mana_recharge_qte() -> void:
	"""Démarre le QTE de recharge de mana"""
	if qte_in_progress:
		return
	
	qte_in_progress = true
	var qte_duration = 0.2 + (current_qte_combination.size() * 0.3)  # Plus de temps si combo long
	
	# Activer le slow motion
	_enter_slow_motion()
	qte_manager.start_qte(current_qte_combination, qte_duration)
	
	# Feedback visuel optionnel
	if hud.has_method("show_qte_started"):
		hud.show_qte_started()
	
	#print("QTE de recharge mana démarré !")

func _cancel_mana_recharge_qte() -> void:
	"""Annule le QTE en cours"""
	if not qte_in_progress:
		return
	# 6. COOLDOWN AVANT PROCHAIN QTE
	qte_cooldown_timer = QTE_COOLDOWN*0.5
	qte_manager.cancel_qte()
	qte_in_progress = false
	# Désactiver le slow motion
	_exit_slow_motion()
	
	#print("QTE annulé par le joueur")
	
	# Feedback visuel optionnel
	if hud.has_method("show_qte_cancelled"):
		hud.show_qte_cancelled()

func _on_qte_started() -> void:
	"""Appelé quand le QTE démarre"""
	hud.hide_roue()
	pass

func _on_qte_success() -> void:
	"""Appelé quand le QTE est réussi - Refill la mana"""
	#print("✅ QTE réussi - Mana rechargée !")
	qte_mandatory = false
	# Remplir complètement la mana
	_trigger_impact_freeze()

	await get_tree().create_timer(IMPACT_FREEZE_DURATION, true, false, true).timeout
	
	# 2. REMPLIR LA MANA
	current_mana = MAX_MANA
	
	if hud.has_method("update_mana"):
		hud.update_mana(current_mana, MAX_MANA)
	
	# 3. EFFETS VISUELS
	_spawn_mana_refill_particles()
	_flash_screen(Color.CYAN, 0.3)
	
	if hud.has_method("show_mana_refill_effect"):
		hud.show_mana_refill_effect()
	hud.show_roue()
	# 4. BONUS PETIT SCORE
	score += 200
	
	# 5. DÉSACTIVER SLOW MOTION
	_exit_slow_motion()
	
	# 6. COOLDOWN AVANT PROCHAIN QTE
	qte_cooldown_timer = QTE_COOLDOWN
	
	# Générer nouvelle combinaison
	_generate_random_qte_combination()

func _on_qte_failed() -> void:
	"""Appelé quand le QTE échoue - Rien ne se passe"""
	#print("❌ QTE échoué - Pas de recharge")
	# Impact négatif (plus subtil)
	_flash_screen(Color.RED, 0.2)
	
	if hud.has_method("show_qte_failed_effect"):
		hud.show_qte_failed_effect()
	hud.show_roue()
	# Désactiver slow motion
	_exit_slow_motion()
	
	# Cooldown réduit en cas d'échec
	qte_cooldown_timer = QTE_COOLDOWN * 0.5

func _on_qte_ended() -> void:
	"""Appelé quand le QTE se termine (succès ou échec)"""
	for i in range(8):await get_tree().process_frame
	qte_in_progress = false
	trigger_pressed = false
	hud.show_roue()
#region SLOW MOTION & VFX

func _enter_slow_motion() -> void:
	"""Active le ralenti + effet de focus"""
	if is_in_slow_motion:
		return
	
	is_in_slow_motion = true
	original_time_scale = Engine.time_scale
	
	# Transition smooth vers slow-mo
	var tween = create_tween()
	tween.tween_method(_set_time_scale, 1.0, QTE_TIME_SCALE, 0.2)
	
	# Activer les overlays de focus
	_show_focus_effect(true)
	
	#print("🎬 Slow motion activé")

func _exit_slow_motion() -> void:
	"""Désactive le ralenti"""
	if not is_in_slow_motion:
		return
	
	is_in_slow_motion = false
	
	# Transition smooth vers vitesse normale
	var tween = create_tween()
	tween.tween_method(_set_time_scale, Engine.time_scale, 1.0, 0.15)
	
	# Désactiver les overlays
	_show_focus_effect(false)
	
	#print("▶️ Slow motion désactivé")

func _set_time_scale(value: float) -> void:
	"""Helper pour tweener le time_scale"""
	Engine.time_scale = value

func _show_focus_effect(show: bool) -> void:
	"""Active/désactive l'effet de focus visuel"""
	if show:
		focus_overlay.visible = true
		vignette_overlay.visible = true
		
		var tween = create_tween()
		tween.tween_property(focus_overlay, "color", Color(0, 0, 0, 0.3), FOCUS_FADE_DURATION)
	else:
		var tween = create_tween()
		tween.tween_property(focus_overlay, "color", Color(0, 0, 0, 0), FOCUS_FADE_DURATION)
		tween.tween_callback(func(): 
			focus_overlay.visible = false
			vignette_overlay.visible = false
		)

func _trigger_impact_freeze() -> void:
	"""Freeze frame complet pour l'impact"""
	Engine.time_scale = 0.0
	
	# Flash intense
	_flash_screen(Color.WHITE, 0.5)
	
	# On utilise un timer physique pour éviter le freeze complet
	await get_tree().create_timer(IMPACT_FREEZE_DURATION, true, false, true).timeout
	Engine.time_scale = 1.0

func _flash_screen(color: Color, intensity: float) -> void:
	"""Flash de couleur à l'écran avec effet impact frame"""
	
	# Récupérer le ShaderMaterial de l'impact frame
	var shader_material = hud.impactframe.material as ShaderMaterial
	
	if shader_material:
		# Rendre visible et configurer les couleurs/intensité si nécessaire
		hud.impactframe.visible = true
		#shader_material.set_shader_parameter("intensity", intensity)
		
		# Créer le tween pour animer le threshold
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		
		# 0.5 -> 0.1 (l'effet s'intensifie)
		tween.tween_method(
			func(value): shader_material.set_shader_parameter("threshold", value),
			0.5, 0.1, 0.05
		)
		
		# 0.1 -> 0.5 (l'effet disparaît)
		tween.tween_method(
			func(value): shader_material.set_shader_parameter("threshold", value),
			0.1, 0.5, 0.2
		)
		
		# Désactiver à la fin
		tween.tween_callback(func(): hud.impactframe.visible = false)
	
func _spawn_mana_refill_particles() -> void:
	"""Spawn des particules de recharge de mana autour du joueur"""
	var particles = CPUParticles2D.new()
	viewport.add_child(particles)
	
	# Positionner sur le joueur
	particles.global_position = player.global_position
	particles.z_index = 10
	
	# Configuration des particules
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 1.0
	particles.explosiveness = 0.8
	
	# Forme d'émission
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 50.0
	
	# Mouvement
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.initial_velocity_min = 100
	particles.initial_velocity_max = 200
	particles.gravity = Vector2(0, -150)
	
	# Apparence
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color.CYAN
	particles.color_ramp = _create_particle_gradient()
	
	# Auto-destruction
	await get_tree().create_timer(1.5).timeout
	particles.queue_free()

func _create_particle_gradient() -> Gradient:
	"""Crée un gradient pour les particules (bleu -> transparent)"""
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0, 1, 1, 1))  # Cyan opaque
	gradient.set_color(1, Color(0, 0.5, 1, 0))  # Bleu transparent
	return gradient

#endregion

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

func cast_spell(spell_type: String, lane) -> bool:
	if spell_cooldown_timer > 0 or qte_in_progress:
		return false
	if current_mana<=0:
		qte_mandatory = true
		return false
	current_mana -= SPELL_MANA_COST
	spell_cooldown_timer = MIN_SPELL_COOLDOWN
	
	if hud.has_method("update_mana"):
		hud.update_mana(current_mana, MAX_MANA)
		
	var closest_enemy = get_closest_enemy()
	if closest_enemy:
		player.play_cast_animation(spell_type, lane)
	return true


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
	
	# Réinitialiser le time scale si on quitte en plein QTE
	if is_in_slow_motion:
		_exit_slow_motion()
	Engine.time_scale = 1.0
	
func add_mana(n: float) -> void:
	current_mana = clamp(current_mana + n, 0, MAX_MANA)
	
	if hud.has_method("update_mana"):
		hud.update_mana(current_mana, MAX_MANA)

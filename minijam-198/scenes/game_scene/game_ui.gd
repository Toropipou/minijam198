# GameManager.gd - Version équilibrée
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
const MAX_SPEED : float = 1500.0
const BASE_SPEED : float = 200.0
const SPEED_INCREASE_ON_KILL : float = 100.0
const SPEED_DECREASE_ON_MISS : float = 150.0  # Réduit pour reset progressif
const SPEED_DECAY_RATE : float = 10.0

# NOUVEAU : Système de reset de vitesse sur erreur
const SPEED_MISS_PENALTY_FACTOR : float = 0.5  # On retombe à 50% de la vitesse actuelle
const MIN_SPEED_AFTER_MISS : float = 180.0     # Ne descend pas en dessous de 180

# Métriques de performance
var enemies_killed : int = 0
var enemies_missed : int = 0
var kill_rate : float = 0.0
var performance_rating : float = 1.0

# NOUVEAU : Système de performance rating lissé
var performance_history : Array = []  # Stocke les derniers succès/échecs
const PERFORMANCE_HISTORY_SIZE : int = 20  # On regarde les 20 derniers ennemis
const PERFORMANCE_INCREASE_RATE : float = 0.02  # Monte lentement
const PERFORMANCE_DECREASE_RATE : float = 0.08  # Descend plus vite sur erreur

# Système de mana
var current_mana : float = 100.0
const MAX_MANA : float = 100.0
const MANA_REGEN_RATE : float = 0.0
const SPELL_MANA_COST : float = 10.0
const QTE_MANA_REFILL : float = 100.0

# QTE System
var current_qte_combination : Array = []
var qte_in_progress : bool = false
var trigger_pressed : bool = false

# Slow Motion & VFX
const QTE_TIME_SCALE : float = 0.3
const IMPACT_FREEZE_DURATION : float = 0.12
const FOCUS_FADE_DURATION : float = 0.25
var original_time_scale : float = 1.0
var is_in_slow_motion : bool = false

# Liste des ennemis actifs
var active_enemies : Array = []

# Cooldown minimal entre sorts
const MIN_SPELL_COOLDOWN : float = 0.1
var spell_cooldown_timer : float = 0.0

const QTE_COOLDOWN : float = 2.0
var qte_cooldown_timer : float = 0.0 

# Timer pour calculer le kill rate et la progression
var time_elapsed : float = 0.0

# NOUVEAU : Système de progression temporelle à deux paliers
var difficulty_progression : float = 0.0  # 0.0 → 2.0 (deux paliers)
const TIME_TO_FIRST_PLATEAU : float = 30.0   # Premier palier à 30s (progression = 1.0)
const TIME_TO_MAX_DIFFICULTY : float = 60.0  # Palier max à 60s (progression = 2.0)

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
	
	player.health_changed.connect(_on_player_health_changed)
	
	qte_manager.qte_success.connect(_on_qte_success)
	qte_manager.qte_failed.connect(_on_qte_failed)
	qte_manager.qte_ended.connect(_on_qte_ended)
	qte_manager.qte_started.connect(_on_qte_started) 
	
	qte_manager.qte_scene = preload("res://scenes/game_scene/system/QTE_UI.tscn")
	_create_focus_overlays()
	new_game()

func _create_focus_overlays() -> void:
	focus_overlay = ColorRect.new()
	focus_overlay.color = Color(0, 0, 0, 0)
	focus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_overlay.z_index = 100
	focus_overlay.visible = false
	hud.add_child(focus_overlay)
	
	vignette_overlay = ColorRect.new()
	vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_overlay.z_index = 99
	vignette_overlay.visible = false
	
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
	
	_generate_random_qte_combination()
	
	# Reset métriques
	enemies_killed = 0
	enemies_missed = 0
	kill_rate = 0.0
	performance_rating = 1.0
	performance_history.clear()
	time_elapsed = 0.0
	difficulty_progression = 0.0
	
	spawner.clear_all_enemies()
	active_enemies.clear()
	
	hud.update_score(score)
	hud.show_start_message()
	
	if hud.has_method("update_mana"):
		hud.update_mana(current_mana, MAX_MANA)
	
	if hud.has_method("_on_player_health_changed"):
		hud._on_player_health_changed(player.current_health, player.max_health)

func _generate_random_qte_combination() -> void:
	var available_spells = ["spell_1", "spell_2", "spell_3", "spell_4"]
	var combination_length = randi_range(2, 3)
	
	current_qte_combination.clear()
	for i in range(combination_length):
		var random_spell = available_spells[randi() % available_spells.size()]
		current_qte_combination.append(random_spell)

func _on_player_health_changed(current_health: int, max_health: int):
	if hud.has_method("_on_player_health_changed"):
		hud._on_player_health_changed(current_health, max_health)

func _process(delta: float) -> void:
	if not game_running:
		if Input.is_action_just_pressed("ui_accept"):
			start_game()
		return
	
	hud.show_diff(spawner.difficulty_level)
	hud.show_perf(performance_rating)
	hud.show_speed(speed)
	if speed > 800:
		hud.going_fast(true)
	else:
		hud.going_fast(false)
	
	time_elapsed += delta
	
	# NOUVEAU : Calculer la progression de difficulté basée sur le temps
	update_difficulty_progression(delta)
	
	if qte_cooldown_timer > 0:
		qte_cooldown_timer -= delta
		if hud.has_method("update_qte_cooldown"):
			hud.update_qte_cooldown(qte_cooldown_timer, QTE_COOLDOWN)
	
	_handle_qte_input()
	
	if not qte_in_progress and current_mana < MAX_MANA:
		current_mana = min(current_mana + MANA_REGEN_RATE * delta, MAX_MANA)
		if hud.has_method("update_mana"):
			hud.update_mana(current_mana, MAX_MANA)
	
	if spell_cooldown_timer > 0:
		spell_cooldown_timer -= delta
	
	update_dynamic_speed(delta)
	parallax.scroll_offset.x -= speed * 2 * delta
	
	var screen_left = +100
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.position.x -= speed / 2 * delta
			
			if enemy.position.x < screen_left:
				_on_enemy_escaped(enemy)
	
	# NOUVEAU : Calculer les métriques de performance de manière lissée
	calculate_smooth_performance_metrics()
	
	# Mettre à jour le spawner moins souvent (toutes les 0.5s au lieu de chaque frame)
	if int(time_elapsed * 2) != int((time_elapsed - delta) * 2):
		spawner.update_difficulty(performance_rating, speed, difficulty_progression)
	
	score += delta * 10
	hud.update_score(int(score))
	
	if hud.has_method("update_debug_info"):
		hud.update_debug_info(speed, performance_rating, kill_rate)

func update_difficulty_progression(delta: float):
	"""Calcule la progression de difficulté avec DEUX paliers distincts (0.0 → 2.0)"""
	
	# Palier 1 : 0-30s → progression 0.0 à 1.0
	# Palier 2 : 30-60s → progression 1.0 à 2.0
	
	if time_elapsed < TIME_TO_FIRST_PLATEAU:
		# Premier palier (0-30s)
		var progress = time_elapsed / TIME_TO_FIRST_PLATEAU
		difficulty_progression = smoothstep(0.0, 1.0, progress)
	else:
		# Deuxième palier (30-60s)
		var time_in_second_phase = time_elapsed - TIME_TO_FIRST_PLATEAU
		var progress = time_in_second_phase / (TIME_TO_MAX_DIFFICULTY - TIME_TO_FIRST_PLATEAU)
		difficulty_progression = 1.0 + smoothstep(0.0, 1.0, clamp(progress, 0.0, 1.0))
	
	# Influence de la performance (±15%)
	var performance_influence = (performance_rating - 1.0) * 0.15
	difficulty_progression = clamp(difficulty_progression + performance_influence, 0.0, 2.0)

func calculate_smooth_performance_metrics():
	"""Calcule un rating de performance lissé sur les derniers ennemis"""
	
	# Calculer le ratio de succès sur l'historique
	if performance_history.size() > 0:
		var successes = performance_history.count(true)
		var success_rate = float(successes) / float(performance_history.size())
		
		# Le rating cible est entre 0.5 et 1.5
		var target_rating = 0.5 + success_rate
		
		# Interpoler lentement vers le target
		if target_rating > performance_rating:
			performance_rating += PERFORMANCE_INCREASE_RATE
		else:
			performance_rating -= PERFORMANCE_DECREASE_RATE
		
		performance_rating = clamp(performance_rating, 0.3, 1.5)
	
	# Calculer le kill rate
	if time_elapsed > 0:
		kill_rate = (enemies_killed / time_elapsed) * 60.0

func _handle_qte_input() -> void:
	if qte_mandatory:
		_start_mana_recharge_qte()
	
	var trigger_just_pressed = Input.is_action_just_pressed("trigger_left") or Input.is_action_just_pressed("trigger_right")
	var trigger_just_released = Input.is_action_just_released("trigger_left") or Input.is_action_just_released("trigger_right")
	
	if trigger_just_pressed and not qte_in_progress:
		hud.hide_roue()
		_start_mana_recharge_qte()
		trigger_pressed = true
	
	if trigger_just_released and qte_in_progress:
		hud.show_roue()
		_cancel_mana_recharge_qte()
		trigger_pressed = false

func _start_mana_recharge_qte() -> void:
	if qte_in_progress:
		return
	
	qte_in_progress = true
	var qte_duration = 0.2 + (current_qte_combination.size() * 0.3)
	
	_enter_slow_motion()
	qte_manager.start_qte(current_qte_combination, qte_duration)
	
	if hud.has_method("show_qte_started"):
		hud.show_qte_started()

func _cancel_mana_recharge_qte() -> void:
	if not qte_in_progress:
		return
	
	qte_cooldown_timer = QTE_COOLDOWN * 0.5
	qte_manager.cancel_qte()
	qte_in_progress = false
	_exit_slow_motion()
	
	if hud.has_method("show_qte_cancelled"):
		hud.show_qte_cancelled()

func _on_qte_started() -> void:
	hud.hide_roue()

func _on_qte_success() -> void:
	qte_mandatory = false
	_trigger_impact_freeze()

	await get_tree().create_timer(IMPACT_FREEZE_DURATION, true, false, true).timeout
	
	current_mana = MAX_MANA
	
	if hud.has_method("update_mana"):
		hud.update_mana(current_mana, MAX_MANA)
	
	_spawn_mana_refill_particles()
	_flash_screen(Color.CYAN, 0.3)
	
	if hud.has_method("show_mana_refill_effect"):
		hud.show_mana_refill_effect()
	hud.show_roue()
	
	score += 200
	_exit_slow_motion()
	qte_cooldown_timer = QTE_COOLDOWN
	_generate_random_qte_combination()

func _on_qte_failed() -> void:
	_flash_screen(Color.RED, 0.2)
	
	if hud.has_method("show_qte_failed_effect"):
		hud.show_qte_failed_effect()
	hud.show_roue()
	
	_exit_slow_motion()
	qte_cooldown_timer = QTE_COOLDOWN * 0.5

func _on_qte_ended() -> void:
	for i in range(8):
		await get_tree().process_frame
	qte_in_progress = false
	trigger_pressed = false
	hud.show_roue()

#region SLOW MOTION & VFX

func _enter_slow_motion() -> void:
	if is_in_slow_motion:
		return
	
	is_in_slow_motion = true
	original_time_scale = Engine.time_scale
	
	var tween = create_tween()
	tween.tween_method(_set_time_scale, 1.0, QTE_TIME_SCALE, 0.2)
	_show_focus_effect(true)

func _exit_slow_motion() -> void:
	if not is_in_slow_motion:
		return
	
	is_in_slow_motion = false
	
	var tween = create_tween()
	tween.tween_method(_set_time_scale, Engine.time_scale, 1.0, 0.15)
	_show_focus_effect(false)

func _set_time_scale(value: float) -> void:
	Engine.time_scale = value

func _show_focus_effect(show: bool) -> void:
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
	Engine.time_scale = 0.0
	_flash_screen(Color.WHITE, 0.5)
	await get_tree().create_timer(IMPACT_FREEZE_DURATION, true, false, true).timeout
	Engine.time_scale = 1.0

func _flash_screen(color: Color, intensity: float) -> void:
	var shader_material = hud.impactframe.material as ShaderMaterial
	
	if shader_material:
		hud.impactframe.visible = true
		
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		
		tween.tween_method(
			func(value): shader_material.set_shader_parameter("threshold", value),
			0.5, 0.1, 0.05
		)
		
		tween.tween_method(
			func(value): shader_material.set_shader_parameter("threshold", value),
			0.1, 0.5, 0.2
		)
		
		tween.tween_callback(func(): hud.impactframe.visible = false)
	
func _spawn_mana_refill_particles() -> void:
	var particles = CPUParticles2D.new()
	viewport.add_child(particles)
	
	particles.global_position = player.global_position
	particles.z_index = 10
	
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 1.0
	particles.explosiveness = 0.8
	
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 50.0
	
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.initial_velocity_min = 100
	particles.initial_velocity_max = 200
	particles.gravity = Vector2(0, -150)
	
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color.CYAN
	particles.color_ramp = _create_particle_gradient()
	
	await get_tree().create_timer(1.5).timeout
	particles.queue_free()

func _create_particle_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0, 1, 1, 1))
	gradient.set_color(1, Color(0, 0.5, 1, 0))
	return gradient

#endregion

func update_dynamic_speed(delta: float):
	if speed > BASE_SPEED:
		speed = max(speed - SPEED_DECAY_RATE * delta, BASE_SPEED)
	elif speed < BASE_SPEED:
		speed = min(speed + SPEED_DECAY_RATE * delta, BASE_SPEED)
	
	speed = clamp(speed, MIN_SPEED, MAX_SPEED)

func increase_speed_from_difficulty(amount: float):
	speed += amount
	speed = min(speed, MAX_SPEED)
	
	if hud.has_method("show_difficulty_increase"):
		hud.show_difficulty_increase()

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
	
	# BOOST DE VITESSE
	speed += SPEED_INCREASE_ON_KILL
	speed = min(speed, MAX_SPEED)
	
	# Ajouter un succès à l'historique
	performance_history.append(true)
	if performance_history.size() > PERFORMANCE_HISTORY_SIZE:
		performance_history.pop_front()
	
	enemies_killed += 1
	combo += 1
	var points = 100 * combo
	score += points
	
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
	
	# GROSSE PÉNALITÉ : Retombe à 50% de la vitesse actuelle
	var target_speed = max(speed * SPEED_MISS_PENALTY_FACTOR, MIN_SPEED_AFTER_MISS)
	speed = target_speed
	
	# Ajouter un échec à l'historique
	performance_history.append(false)
	if performance_history.size() > PERFORMANCE_HISTORY_SIZE:
		performance_history.pop_front()
	
	enemies_missed += 1
	combo = 0
	
	if hud.has_method("update_combo"):
		hud.update_combo(combo)
	if hud.has_method("show_speed_penalty"):
		hud.show_speed_penalty()
	
	player.take_damage(1)
	enemy.queue_free()

func _on_enemy_weakness_hit(enemy, remaining: int):
	score += 50
	speed += 2.0
	speed = min(speed, MAX_SPEED)
	
	if hud.has_method("show_hit_feedback"):
		hud.show_hit_feedback(enemy.position, true)

func _on_wrong_spell(enemy, spell_type: String):
	combo = max(0, combo - 1)
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
	if current_mana <= 0:
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
	
	if is_in_slow_motion:
		_exit_slow_motion()
	Engine.time_scale = 1.0
	
func add_mana(n: float) -> void:
	current_mana = clamp(current_mana + n, 0, MAX_MANA)
	
	if hud.has_method("update_mana"):
		hud.update_mana(current_mana, MAX_MANA)

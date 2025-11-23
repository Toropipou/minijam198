# GameManager.gd - Version équilibrée avec gain de vitesse progressif
extends Node

@onready var qte_manager: Node = $ViewportContainer/ConfigurableSubViewport/QTE_Manager
var qte_mandatory := false

# Tutorial
var tutorial_active : bool = false
var tutorial_step : int = 0
var tutorial_enemy = null
var tutorial_completed : bool = false
const TUTORIAL_TIME_SCALE : float = 0.3

# Variables de jeu
var score : int = 0
var combo : int = 0
var game_running : bool = false

# Système de vitesse dynamique avec PALIERS
var speed : float = 200.0
const MIN_SPEED : float = 50.0
const MAX_SPEED : float = 1500.0
const BASE_SPEED : float = 200.0

# NOUVEAU : Système de gain de vitesse par paliers
const SPEED_TIER_1_THRESHOLD : float = 400.0   # Palier 1
const SPEED_TIER_2_THRESHOLD : float = 700.0   # Palier 2
const SPEED_TIER_3_THRESHOLD : float = 1000.0  # Palier 3

# Gains de vitesse selon le palier atteint
const SPEED_GAIN_TIER_0 : float = 25.0  # < 400 (début facile)
const SPEED_GAIN_TIER_1 : float = 32.0  # 400-700 (accélération)
const SPEED_GAIN_TIER_2 : float = 40.0  # 700-1000 (rapide)
const SPEED_GAIN_TIER_3 : float = 50.0  # > 1000 (extrême)

const SPEED_DECAY_RATE : float = 3.0  # Ralentissement naturel plus doux

# NOUVEAU : Pénalités sur miss ajustées par palier
const MISS_PENALTY_TIER_0 : float = 0.65  # On garde 65% (perte de 35%)
const MISS_PENALTY_TIER_1 : float = 0.55  # On garde 55% (perte de 45%)
const MISS_PENALTY_TIER_2 : float = 0.45  # On garde 45% (perte de 55%)
const MISS_PENALTY_TIER_3 : float = 0.35  # On garde 35% (perte de 65% - brutal!)

const MIN_SPEED_AFTER_MISS : float = 180.0

# Métriques de performance
var enemies_killed : int = 0
var enemies_missed : int = 0
var kill_rate : float = 0.0
var performance_rating : float = 1.0

var performance_history : Array = []
const PERFORMANCE_HISTORY_SIZE : int = 20
const PERFORMANCE_INCREASE_RATE : float = 0.02
const PERFORMANCE_DECREASE_RATE : float = 0.08

# Système de mana
var current_mana : float = 10.0
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

var active_enemies : Array = []

const MIN_SPELL_COOLDOWN : float = 0.1
var spell_cooldown_timer : float = 0.0

const QTE_COOLDOWN : float = 2.0
var qte_cooldown_timer : float = 0.0 

var time_elapsed : float = 0.0

var difficulty_progression : float = 0.0
const TIME_TO_FIRST_PLATEAU : float = 30.0
const TIME_TO_SECOND_PLATEAU : float = 60.0
const TIME_TO_MAX_DIFFICULTY : float = 90.0

# Références
@onready var viewport = $ViewportContainer/ConfigurableSubViewport
@onready var player = $ViewportContainer/ConfigurableSubViewport/Player
@onready var parallax = $ViewportContainer/ConfigurableSubViewport/Bg
@onready var spawner = $ViewportContainer/ConfigurableSubViewport/EnemySpawner
@onready var hud = $ViewportContainer/ConfigurableSubViewport/hud

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
	
	# Charger l'état du tutoriel
	_load_tutorial_state()
	
	new_game()
func _load_tutorial_state():
	"""Charge si le tutoriel a déjà été complété"""
	# Vous pouvez utiliser un fichier de config ou ConfigFile
	# Pour l'instant, simple variable (réinitialise à chaque lancement)
	tutorial_completed = false  # Changez en true pour tester sans tutoriel

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
	
	# NOUVEAU : Détecter la perte de vie
	if current_health < player.max_health:
		_trigger_damage_effects()

# NOUVELLE FONCTION : Effets visuels lors des dégâts
func _trigger_damage_effects() -> void:
	# 1. Freeze court pour l'impact
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.08, true, false, true).timeout
	Engine.time_scale = 1.0
	
	# 2. Flash rouge de l'écran
	_flash_screen(Color(1, 0, 0, 0.8), 0.6)
	
	# 3. Shake de caméra
	_camera_shake(15.0, 0.4)
	
	# 4. Vignette rouge
	if hud.has_method("show_damage_vignette"):
		hud.show_damage_vignette()
	
	# 5. Effet de particules de sang/impact
	_spawn_damage_particles()

# NOUVELLE FONCTION : Shake de caméra
func _camera_shake(intensity: float, duration: float) -> void:
	var camera = viewport.get_camera_2d()
	if not camera:
		return
	
	var original_offset = camera.offset
	var shake_tween = create_tween()
	
	var shake_count = int(duration * 30)  # 30 shakes par seconde
	for i in range(shake_count):
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(camera, "offset", original_offset + shake_offset, duration / shake_count)
	
	shake_tween.tween_property(camera, "offset", original_offset, 0.1)

# NOUVELLE FONCTION : Particules de dégâts
func _spawn_damage_particles() -> void:
	var particles = CPUParticles2D.new()
	viewport.add_child(particles)
	
	particles.global_position = player.global_position
	particles.z_index = 10
	
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 40
	particles.lifetime = 0.8
	particles.explosiveness = 1.0
	
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 30.0
	
	particles.direction = Vector2(1, -0.5)  # Légèrement vers le haut
	particles.spread = 60
	particles.initial_velocity_min = 150
	particles.initial_velocity_max = 300
	particles.gravity = Vector2(0, 400)
	
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	
	# Gradient rouge sang
	particles.color_ramp = _create_blood_gradient()
	
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func _create_blood_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 0, 0, 1))      # Rouge vif
	gradient.set_color(0.5, Color(0.8, 0, 0, 0.8)) # Rouge foncé
	gradient.set_color(1, Color(0.3, 0, 0, 0))     # Transparent
	return gradient

# NOUVELLE FONCTION : Calculer le gain de vitesse selon le palier
func get_speed_gain_for_kill() -> float:
	if speed < SPEED_TIER_1_THRESHOLD:
		return SPEED_GAIN_TIER_0  # Début facile
	elif speed < SPEED_TIER_2_THRESHOLD:
		return SPEED_GAIN_TIER_1  # Accélération
	elif speed < SPEED_TIER_3_THRESHOLD:
		return SPEED_GAIN_TIER_2  # Rapide
	else:
		return SPEED_GAIN_TIER_3  # Extrême

# NOUVELLE FONCTION : Calculer la pénalité sur miss selon le palier
func get_miss_penalty_factor() -> float:
	if speed < SPEED_TIER_1_THRESHOLD:
		return MISS_PENALTY_TIER_0  # Pénalité douce
	elif speed < SPEED_TIER_2_THRESHOLD:
		return MISS_PENALTY_TIER_1  # Pénalité modérée
	elif speed < SPEED_TIER_3_THRESHOLD:
		return MISS_PENALTY_TIER_2  # Pénalité sévère
	else:
		return MISS_PENALTY_TIER_3  # Pénalité brutale

func _process(delta: float) -> void:
	if not game_running:
		start_game()
		return
	Datagame.high_score = max(score,Datagame.high_score)
	player.play_run_speed(speed)
	hud.show_diff(spawner.difficulty_level)
	hud.show_perf(performance_rating)
	hud.show_speed(speed)
	
	# Indicateurs visuels de vitesse par paliers
	if speed > SPEED_TIER_2_THRESHOLD:
		hud.going_fast(true, speed)
		$BackgroundMusicPlayer.pitch_scale = 1.3
	else:
		hud.going_fast(false)
		$BackgroundMusicPlayer.pitch_scale = 1.0
	
	if speed > SPEED_TIER_3_THRESHOLD:
		hud.going_fast2(true)
		$BackgroundMusicPlayer.pitch_scale = 1.5
	else:
		hud.going_fast2(false)	
		$BackgroundMusicPlayer.pitch_scale = 1.0
	
	time_elapsed += delta
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
	parallax.scroll_offset.x -= speed * 2.5 * delta
	
	var screen_left = -100
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.position.x -= speed / 1.5 * delta
			if enemy.position.x < screen_left:
				_on_enemy_escaped(enemy)
	
	calculate_smooth_performance_metrics()
	
	if int(time_elapsed * 2) != int((time_elapsed - delta) * 2):
		spawner.update_difficulty(performance_rating, speed, difficulty_progression)
	
	score += delta * 10
	hud.update_score(int(score))
	
	if hud.has_method("update_debug_info"):
		hud.update_debug_info(speed, performance_rating, kill_rate)

func update_difficulty_progression(delta: float):
	if time_elapsed < TIME_TO_FIRST_PLATEAU:
		var progress = time_elapsed / TIME_TO_FIRST_PLATEAU
		difficulty_progression = smoothstep(0.0, 1.0, progress)
	else:
		var time_in_second_phase = time_elapsed - TIME_TO_FIRST_PLATEAU
		var progress = time_in_second_phase / (TIME_TO_MAX_DIFFICULTY - TIME_TO_FIRST_PLATEAU)
		difficulty_progression = 1.0 + smoothstep(0.0, 1.0, clamp(progress, 0.0, 1.0))
	
	var performance_influence = (performance_rating - 1.0) * 0.01
	difficulty_progression = clamp(difficulty_progression + performance_influence, 0.0, 2.0)

func calculate_smooth_performance_metrics():
	if performance_history.size() > 0:
		var successes = performance_history.count(true)
		var success_rate = float(successes) / float(performance_history.size())
		var target_rating = 0.5 + success_rate
		
		if target_rating > performance_rating:
			performance_rating += PERFORMANCE_INCREASE_RATE
		else:
			performance_rating -= PERFORMANCE_DECREASE_RATE
		
		performance_rating = clamp(performance_rating, 0.3, 1.5)
	
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
	
	# Si on est dans le tutoriel étape 2
	if tutorial_active and tutorial_step == 2:
		await get_tree().create_timer(0.5 * TUTORIAL_TIME_SCALE, true, false, true).timeout
		hud.hide_tutorial_message()
		hud.clear_all_highlights()
		_tutorial_step_3()
		
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
	# Retour progressif vers BASE_SPEED quand pas d'action
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
	$BackgroundMusicPlayer.play()
	if not Datagame.tuto_completed and not tutorial_active:
		_start_tutorial()
	else:
		_start_normal_game()

func _start_normal_game():
	game_running = true
	spawner.start_spawning()
	hud.hide_start_message()
	Engine.time_scale = 1.0

func _start_tutorial():
	"""Démarre le tutoriel"""
	tutorial_active = true
	tutorial_step = 0
	game_running = true
	
	# Ralentir le jeu
	Engine.time_scale = TUTORIAL_TIME_SCALE
	
	# Désactiver le spawner normal
	spawner.stop_spawning()
	
	hud.hide_start_message()
	
	# Lancer l'étape 1
	_tutorial_step_1()

func _tutorial_step_1():
	"""Étape 1 : Spawn un ennemi 1-weakness sur le couloir BOTTOM"""
	tutorial_step = 1
	
	# Message d'instruction
	hud.show_tutorial_message("An enemy is coming ! Use the right spell to damage him.")
	
	# Attendre un peu avant de spawn
	await get_tree().create_timer(1.5 * TUTORIAL_TIME_SCALE, true, false, true).timeout
	
	# Spawn ennemi avec 1 faiblesse aléatoire
	var weakness_type = ["Coeur", "Carreau", "Trefle", "Pique"][randi() % 4]
	tutorial_enemy = _spawn_tutorial_enemy([weakness_type], spawner.SpawnLane.BOTTOM)
	tutorial_enemy.position.x = 1600
	# Highlight du sort correspondant
	hud.highlight_spell_for_weakness(weakness_type)

func _tutorial_step_2():
	"""Étape 2 : Mana à 0, apprendre le QTE"""
	tutorial_step = 2
	
	# Vider la mana
	current_mana = 0.0
	hud.update_mana(current_mana, MAX_MANA)
	
	# Message
	hud.show_tutorial_message("We are out of Mana ! Hold any trigger (LT/RT) or shift to reload.")
	
	# Highlight des gâchettes (vous pouvez ajouter un effet visuel)
	hud.highlight_triggers()

func _tutorial_step_3():
	"""Étape 3 : Ennemi 2-weaknesses sur couloir TOP"""
	tutorial_step = 3
	await get_tree().create_timer(2.0 * TUTORIAL_TIME_SCALE, true, false, true).timeout
	# Message
	hud.show_tutorial_message("Enemies can have many weaknesses !\nThey can also appear on the upper lane (press UP/DOWN to navigate)")
	await get_tree().create_timer(3.0 * TUTORIAL_TIME_SCALE, true, false, true).timeout

	
	# Spawn ennemi avec 2 faiblesses sur TOP
	var available = ["Coeur", "Carreau", "Trefle", "Pique"]
	available.shuffle()
	var weaknesses = [available[0], available[1]]
	tutorial_enemy = _spawn_tutorial_enemy(weaknesses, spawner.SpawnLane.TOP)
	
	# Highlight des deux sorts
	hud.highlight_spell_for_weakness(weaknesses[0])
	await get_tree().create_timer(0.3, true, false, true).timeout
	hud.highlight_spell_for_weakness(weaknesses[1])

func _tutorial_step_4():
	"""Étape 4 : Mettre en lumière le score"""
	tutorial_step = 4
	
	# Message
	hud.show_tutorial_message("Your objective : Survive !\nScore goes up by kill and time ! Good luck.")
	
	# Highlight du score
	hud.highlight_score()
	
	await get_tree().create_timer(3.0 * TUTORIAL_TIME_SCALE, true, false, true).timeout
	
	_end_tutorial()

func _end_tutorial():
	"""Termine le tutoriel et lance le jeu normal"""
	tutorial_active = false
	tutorial_completed = true
	Datagame.tuto_completed = true
	tutorial_step = 0
	
	# Retour à la vitesse normale progressivement
	var tween = create_tween()
	tween.tween_method(_set_time_scale, TUTORIAL_TIME_SCALE, 1.0, 0.5)
	
	await tween.finished
	
	# Message final
	hud.show_tutorial_message("Let's go !")
	await get_tree().create_timer(1.0, true, false, true).timeout
	hud.hide_tutorial_message()
	
	# Démarrer le jeu normal
	spawner.start_spawning()
	hud.clear_all_highlights()


func _spawn_tutorial_enemy(weaknesses: Array, lane) -> Node:
	"""Spawn un ennemi de tutoriel qui reste figé"""
	var enemy = spawner.enemy_scene.instantiate()
	active_enemies.append(enemy)
	match lane:
		spawner.SpawnLane.TOP:
			enemy.position = spawner.spawn_position_top
			enemy.top_or_bottom = "top"
		spawner.SpawnLane.BOTTOM:
			enemy.position = spawner.spawn_position_bottom
			enemy.top_or_bottom = "bottom"
	
	viewport.add_child(enemy)
	enemy.set_weaknesses(weaknesses)
	
	# Connecter les signaux
	enemy.destroyed.connect(_on_tutorial_enemy_destroyed)
	enemy.weakness_hit.connect(_on_tutorial_enemy_weakness_hit)
	
	# Figer l'ennemi (vitesse très lente)
	enemy.set_physics_process(false)  # Désactiver son mouvement
	
	return enemy

func _on_tutorial_enemy_destroyed(enemy):
	"""Quand l'ennemi du tutoriel est détruit"""
	if not tutorial_active:
		return
	
	# Feedback visuel
	_flash_screen(Color.GREEN, 0.3)
	
	# Passer à l'étape suivante selon l'étape actuelle
	match tutorial_step:
		1:
			await get_tree().create_timer(0.5 * TUTORIAL_TIME_SCALE, true, false, true).timeout
			_tutorial_step_2()
		3:
			await get_tree().create_timer(0.5 * TUTORIAL_TIME_SCALE, true, false, true).timeout
			_tutorial_step_4()

func _on_tutorial_enemy_weakness_hit(enemy, remaining: int):
	"""Feedback lors d'un hit sur l'ennemi tutoriel"""
	if not tutorial_active:
		return
	
	# Petit effet visuel
	if hud.has_method("show_hit_feedback"):
		hud.show_hit_feedback(enemy.position, true)

func _on_enemy_spawned(enemy):
	active_enemies.append(enemy)
	enemy.destroyed.connect(_on_enemy_destroyed)
	enemy.weakness_hit.connect(_on_enemy_weakness_hit)
	enemy.wrong_spell_used.connect(_on_wrong_spell)

func _on_enemy_destroyed(enemy):
	active_enemies.erase(enemy)
	
	# BOOST DE VITESSE SELON LE PALIER ATTEINT
	var speed_gain = get_speed_gain_for_kill()
	speed += speed_gain
	speed = min(speed, MAX_SPEED)
	
	# Feedback visuel selon le palier
	if speed >= SPEED_TIER_3_THRESHOLD:
		if hud.has_method("show_speed_boost_extreme"):
			hud.show_speed_boost_extreme()
	elif speed >= SPEED_TIER_2_THRESHOLD:
		if hud.has_method("show_speed_boost_high"):
			hud.show_speed_boost_high()
	
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
	
	# PÉNALITÉ SELON LE PALIER : Plus on est rapide, plus on perd!
	var penalty_factor = get_miss_penalty_factor()
	var target_speed = max(speed * penalty_factor, MIN_SPEED_AFTER_MISS)
	speed = target_speed
	
	# Feedback visuel de la punition
	if penalty_factor <= MISS_PENALTY_TIER_3:
		if hud.has_method("show_speed_penalty_brutal"):
			hud.show_speed_penalty_brutal()
	
	performance_history.append(false)
	if performance_history.size() > PERFORMANCE_HISTORY_SIZE:
		performance_history.pop_front()
	
	enemies_missed += 1
	combo = 0
	
	if hud.has_method("update_combo"):
		hud.update_combo(combo)
	if hud.has_method("show_speed_penalty"):
		hud.show_speed_penalty()
	if not enemy.is_dead:player.take_damage(1)
	enemy.queue_free()

func _on_enemy_weakness_hit(enemy, remaining: int):
	score += 50
	
	# Petit boost aussi sur les hits intermédiaires
	var mini_boost = get_speed_gain_for_kill() * 0.15
	speed += mini_boost
	speed = min(speed, MAX_SPEED)
	
	if hud.has_method("show_hit_feedback"):
		hud.show_hit_feedback(enemy.position, true)

func _on_wrong_spell(enemy, spell_type: String):
	combo = max(0, combo - 1)
	
	# Petite pénalité sur mauvais sort
	speed -= 8.0
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
	# Pendant le tutoriel, vérifier si c'est le bon sort
	if tutorial_active and tutorial_enemy and is_instance_valid(tutorial_enemy):
		if tutorial_step == 1 or tutorial_step == 3:
			var expected_weaknesses = tutorial_enemy.weaknesses
			var spell_matches = false
			# Vérifier si le sort correspond à une faiblesse attendue
			for weakness in expected_weaknesses:
				if weakness == spell_type:
					spell_matches = true
					break
			
			if not spell_matches:
				# Mauvais sort pendant le tutoriel - afficher un feedback
				hud.show_tutorial_error("Mauvais sort ! Essaie celui qui correspond à la couleur de l'ennemi.")
				return false
	
	if current_mana <= 0:
		qte_mandatory = true
		return false
	player.play_animation_attack()

	current_mana -= SPELL_MANA_COST
	spell_cooldown_timer = MIN_SPELL_COOLDOWN
	
	if hud.has_method("update_mana"):
		hud.update_mana(current_mana, MAX_MANA)
		
	var closest_enemy = get_closest_enemy()
	print(closest_enemy)
	if closest_enemy:
		player.play_cast_animation(spell_type, lane)
	return true
	
func _spell_type_matches_weakness(spell_type: String, weakness: String) -> bool:
	"""Vérifie si un type de sort correspond à une faiblesse"""
	var mapping = {
		"spell_1": "Coeur",
		"spell_2": "Carreau",
		"spell_3": "Trefle",
		"spell_4": "Pique"
	}
	return mapping.get(spell_type, "") == weakness
	
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

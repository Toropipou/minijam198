# EnemySpawner.gd - Version équilibrée avec progression douce
extends Node2D

signal enemy_spawned(enemy)
signal wave_completed(wave_number)

@export var enemy_scene : PackedScene = preload("res://scenes/entity/enemy.tscn")
@export var spawn_position_top : Vector2 = Vector2(1200, 300)
@export var spawn_position_bottom : Vector2 = Vector2(1200, 547)
@export var auto_start : bool = false

@onready var spawn_timer = $SpawnTimer

# Gestion des deux couloirs
enum SpawnLane { TOP, BOTTOM, BOTH }
var available_lanes : Array = [SpawnLane.TOP, SpawnLane.BOTTOM]

# Difficulté dynamique (maintenant contrôlée par progression temporelle)
var difficulty_level : float = 0.0  # 0.0 → 1.0 basé sur le temps
var performance_rating : float = 1.0
var game_speed : float = 200.0
var difficulty_progression : float = 0.0  # Reçu du GameManager

# NOUVEAU : Paramètres de délai de spawn - TRÈS RAPIDES au début pour sensation de massacre
const BASE_SPAWN_DELAY_AT_MIN_SPEED : float = 1.5  # À vitesse 200 (encore plus rapide!)
const BASE_SPAWN_DELAY_AT_MAX_SPEED : float = 0.6  # À vitesse 800+ (ultra rapide)
var current_spawn_delay : float = 1.5

# NOUVEAU : Distribution des faiblesses avec TROIS paliers distincts
# CAP MAXIMUM : 3 FAIBLESSES (pas de 4-weakness)
# TOUJOURS au moins 20% de 1-weakness pour la cadence !
#
# Palier 1 (progression 0.0 - 1.0 / 0-30s):
#   Début : 85% 1w, 15% 2w
#   Fin : 40% 1w, 45% 2w, 15% 3w
#
# Palier 2 (progression 1.0 - 2.0 / 30-60s):
#   Début : 30% 1w, 50% 2w, 20% 3w
#   Fin : 25% 1w, 45% 2w, 30% 3w
#
# Palier 3 ENFER (progression 2.0 - 3.0 / 60-90s):
#   Début : 20% 1w, 40% 2w, 40% 3w
#   Fin : 15% 1w, 35% 2w, 50% 3w (MAXIMUM DE 3-WEAKNESS!)

# Spawn en vagues
var enemies_per_wave : int = 1
var enemies_spawned_in_wave : int = 0
var time_between_waves : float = 5.0

# Distribution des couloirs
var current_wave_lanes : Array = []

# État
var is_spawning : bool = false
var spawned_enemies : Array = []
var total_enemies_spawned : int = 0

# Patterns
var spawn_patterns : Array = ["single", "burst", "increasing", "mixed"]
var current_pattern : String = "single"
var pattern_timer : float = 0.0
const PATTERN_CHANGE_INTERVAL : float = 30.0

func _ready() -> void:
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	if auto_start:
		start_spawning()

func _process(delta: float) -> void:
	if not is_spawning:
		return
	
	pattern_timer += delta
	if pattern_timer >= PATTERN_CHANGE_INTERVAL:
		pattern_timer = 0.0
		select_next_pattern()

func start_spawning():
	is_spawning = true
	difficulty_level = 0.0
	total_enemies_spawned = 0
	current_pattern = "single"
	
	spawn_next_enemy()

func stop_spawning():
	is_spawning = false
	spawn_timer.stop()

func update_difficulty(perf_rating: float, speed: float, progression: float):
	"""Appelé toutes les 0.5s par le GameManager"""
	performance_rating = perf_rating
	game_speed = speed
	difficulty_progression = progression
	
	# La difficulté suit maintenant la progression temporelle
	difficulty_level = progression
	
	# Calculer les paramètres de spawn
	calculate_spawn_parameters()

func calculate_spawn_parameters():
	"""Calcule les paramètres de spawn basés sur vitesse + progression"""
	
	# 1. DÉLAI DE SPAWN : Inversement proportionnel à la vitesse
	var speed_normalized = clamp((game_speed - 200.0) / (800.0 - 200.0), 0.0, 1.0)
	current_spawn_delay = lerp(BASE_SPAWN_DELAY_AT_MIN_SPEED, BASE_SPAWN_DELAY_AT_MAX_SPEED, speed_normalized)
	
	# Ajustement léger selon la progression
	current_spawn_delay *= (1.0 - difficulty_progression * 0.2)  # -20% max
	current_spawn_delay = clamp(current_spawn_delay, 0.8, 4.0)
	
	# 2. NOMBRE D'ENNEMIS PAR VAGUE - Beaucoup plus au début!
	match current_pattern:
		"single":
			# Même en single, on augmente progressivement
			if difficulty_progression < 0.5:
				enemies_per_wave = 1
			else:
				enemies_per_wave = randi_range(1, 2)
		
		"burst":
			# Palier 1: 2-3 ennemis
			# Palier 2: 3-5 ennemis
			# Palier 3: 4-6 ennemis
			if difficulty_progression < 1.0:
				enemies_per_wave = int(2 + difficulty_progression)
			elif difficulty_progression < 2.0:
				enemies_per_wave = int(3 + (difficulty_progression - 1.0) * 2)
			else:
				enemies_per_wave = int(4 + (difficulty_progression - 2.0) * 2)
		
		"increasing":
			enemies_per_wave = int(2 + (total_enemies_spawned / 10.0))  # Plus agressif
		
		"mixed":
			if difficulty_progression < 1.0:
				enemies_per_wave = randi_range(1, int(2 + difficulty_progression * 2))
			elif difficulty_progression < 2.0:
				enemies_per_wave = randi_range(2, int(3 + difficulty_progression))
			else:
				enemies_per_wave = randi_range(2, int(4 + difficulty_progression))
	
	enemies_per_wave = clamp(enemies_per_wave, 1, 6)
	
	# 3. TEMPS ENTRE VAGUES - Plus rapide, surtout au début
	if difficulty_progression < 1.0:
		time_between_waves = lerp(3.0, 2.5, difficulty_progression)
	elif difficulty_progression < 2.0:
		time_between_waves = lerp(2.5, 2.0, difficulty_progression - 1.0)
	else:
		time_between_waves = lerp(2.0, 1.5, difficulty_progression - 2.0)
	
	prepare_wave_lanes()

func spawn_next_enemy():
	if not is_spawning:
		return
	
	# NOUVEAU : Système de distribution progressive
	var num_weaknesses = calculate_progressive_weaknesses()
	var weaknesses = generate_smart_weaknesses(num_weaknesses)
	var lane = get_lane_for_current_enemy()
	
	spawn_enemy(weaknesses, lane)
	
	enemies_spawned_in_wave += 1
	total_enemies_spawned += 1
	
	if enemies_spawned_in_wave >= enemies_per_wave:
		enemies_spawned_in_wave = 0
		spawn_timer.wait_time = time_between_waves
	else:
		spawn_timer.wait_time = current_spawn_delay
	
	spawn_timer.start()

func calculate_progressive_weaknesses() -> int:
	"""Distribution progressive avec TROIS PALIERS + CAP à 3 faiblesses max"""
	
	var rand = randf()
	
	# ===== PALIER 1 : Facile/Normal (progression 0.0 - 1.0) =====
	if difficulty_progression < 1.0:
		var p = difficulty_progression
		
		# Début (p=0) : 85% 1w, 15% 2w
		# Fin (p=1) : 40% 1w, 45% 2w, 15% 3w
		var chance_1w = lerp(0.85, 0.60, p)
		var chance_2w = lerp(0.15, 0.35, p)
		var chance_3w = lerp(0.0, 0.05, p)
		
		if rand < chance_1w:
			return 1
		elif rand < chance_1w + chance_2w:
			return 2
		else:
			return 3
	
	# ===== PALIER 2 : Difficile (progression 1.0 - 2.0) =====
	elif difficulty_progression < 2.0:
		var p = difficulty_progression - 1.0
		
		# Début (p=0) : 30% 1w, 50% 2w, 20% 3w
		# Fin (p=1) : 25% 1w, 45% 2w, 30% 3w
		var chance_1w = lerp(0.40, 0.35, p)
		var chance_2w = lerp(0.50, 0.45, p)
		var chance_3w = lerp(0.10, 0.20, p)
		
		if rand < chance_1w:
			return 1
		elif rand < chance_1w + chance_2w:
			
			return 2
		else:
			return 3
	
	# ===== PALIER 3 : ENFER (progression 2.0 - 3.0) =====
	else:
		var p = difficulty_progression - 2.0
		
		# Début (p=0) : 20% 1w, 40% 2w, 40% 3w
		# Fin (p=1) : 15% 1w, 35% 2w, 50% 3w
		var chance_1w = lerp(0.20, 0.15, p)
		var chance_2w = lerp(0.40, 0.35, p)
		var chance_3w = lerp(0.40, 0.50, p)
		
		if rand < chance_1w:
			return 1
		elif rand < chance_1w + chance_2w:
			return 2
		else:
			return 3  # CAP MAX à 3 faiblesses!

func generate_smart_weaknesses(count: int) -> Array:
	"""Génère des faiblesses avec des patterns intéressants"""
	var available_types = ["Coeur", "Carreau", "Trefle", "Pique"]
	var weaknesses = []
	
	if count == 1:
		weaknesses.append(available_types[randi() % 4])
		
	elif count == 2:
		if randf() < 0.7:
			# Deux différents
			available_types.shuffle()
			weaknesses.append(available_types[0])
			weaknesses.append(available_types[1])
		else:
			# Deux identiques
			var type = available_types[randi() % 4]
			weaknesses.append(type)
			weaknesses.append(type)
			
	elif count == 3:
		var pattern_type = randi() % 3
		match pattern_type:
			0:  # A-B-A
				var a = available_types[randi() % 4]
				var b = available_types[(available_types.find(a) + 1) % 4]
				weaknesses = [a, b, a]
			1:  # A-A-B
				available_types.shuffle()
				weaknesses = [available_types[0], available_types[0], available_types[1]]
			2:  # A-B-C
				available_types.shuffle()
				weaknesses = [available_types[0], available_types[1], available_types[2]]
				
	else:  # 4 faiblesses
		var pattern_type = randi() % 4
		match pattern_type:
			0:  # Tous différents
				available_types.shuffle()
				weaknesses = available_types.duplicate()
			1:  # A-A-B-B
				available_types.shuffle()
				weaknesses = [available_types[0], available_types[0], available_types[1], available_types[1]]
			2:  # A-B-C-A
				available_types.shuffle()
				weaknesses = [available_types[0], available_types[1], available_types[2], available_types[0]]
			3:  # A-A-A-B
				available_types.shuffle()
				weaknesses = [available_types[0], available_types[0], available_types[0], available_types[1]]
	
	return weaknesses

func prepare_wave_lanes():
	"""Prépare la distribution des couloirs pour la vague"""
	current_wave_lanes.clear()
	
	if enemies_per_wave == 1:
		current_wave_lanes.append(available_lanes[randi() % 2])
		
	elif enemies_per_wave == 2:
		var strategy = randi() % 3
		match strategy:
			0:  # Même couloir
				var lane = available_lanes[randi() % 2]
				current_wave_lanes.append(lane)
				current_wave_lanes.append(lane)
			1:  # TOP puis BOTTOM
				current_wave_lanes.append(SpawnLane.TOP)
				current_wave_lanes.append(SpawnLane.BOTTOM)
			2:  # BOTTOM puis TOP
				current_wave_lanes.append(SpawnLane.BOTTOM)
				current_wave_lanes.append(SpawnLane.TOP)
	
	else:
		var strategy = randi() % 4
		match strategy:
			0:  # Alternance TOP-BOTTOM
				for i in range(enemies_per_wave):
					current_wave_lanes.append(SpawnLane.TOP if i % 2 == 0 else SpawnLane.BOTTOM)
			1:  # Alternance BOTTOM-TOP
				for i in range(enemies_per_wave):
					current_wave_lanes.append(SpawnLane.BOTTOM if i % 2 == 0 else SpawnLane.TOP)
			2:  # Groupes
				var half = enemies_per_wave / 2
				for i in range(enemies_per_wave):
					current_wave_lanes.append(SpawnLane.TOP if i < half else SpawnLane.BOTTOM)
			3:  # Aléatoire
				for i in range(enemies_per_wave):
					current_wave_lanes.append(available_lanes[randi() % 2])

func get_lane_for_current_enemy() -> SpawnLane:
	var index = enemies_spawned_in_wave
	if index < current_wave_lanes.size():
		return current_wave_lanes[index]
	else:
		return available_lanes[randi() % 2]

func spawn_enemy(weaknesses: Array, lane: SpawnLane):
	var enemy = enemy_scene.instantiate()
	
	match lane:
		SpawnLane.TOP:
			enemy.position = spawn_position_top
			enemy.top_or_bottom = "top"
		SpawnLane.BOTTOM:
			enemy.position = spawn_position_bottom
			enemy.top_or_bottom = "bottom"
	
	get_parent().add_child(enemy)
	enemy.set_weaknesses(weaknesses)
	enemy.destroyed.connect(_on_enemy_destroyed)
	spawned_enemies.append(enemy)
	enemy_spawned.emit(enemy)

func select_next_pattern():
	var old_pattern = current_pattern
	var available = spawn_patterns.filter(func(p): return p != old_pattern)
	current_pattern = available[randi() % available.size()]

func _on_spawn_timer_timeout():
	spawn_next_enemy()

func _on_enemy_destroyed(enemy):
	spawned_enemies.erase(enemy)

func clear_all_enemies():
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()

func set_pattern_mode():
	current_pattern = "single"

func set_random_mode():
	current_pattern = "mixed"

func set_endless_mode():
	current_pattern = "increasing"

func skip_to_wave(wave_index: int):
	difficulty_level = float(wave_index) / 10.0  # Convertir en progression 0-1

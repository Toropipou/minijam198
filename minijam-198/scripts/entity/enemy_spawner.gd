# EnemySpawner.gd - Version dynamique et adaptative
extends Node2D

signal enemy_spawned(enemy)
signal wave_completed(wave_number)

@export var enemy_scene : PackedScene = preload("res://scenes/entity/enemy.tscn")
@export var spawn_position_top : Vector2 = Vector2(1200, 200)
@export var spawn_position_bottom : Vector2 = Vector2(1200, 547)
@export var auto_start : bool = false

@onready var spawn_timer = $SpawnTimer

# Gestion des deux couloirs
enum SpawnLane { TOP, BOTTOM, BOTH }
var available_lanes : Array = [SpawnLane.TOP, SpawnLane.BOTTOM]

# Difficulté dynamique
var difficulty_level : float = 1.0
var performance_rating : float = 1.0  # Vient du GameManager
var game_speed : float = 200.0

# Paramètres de spawn adaptatifs
var min_spawn_delay : float = 1.5
var max_spawn_delay : float = 5.0
var current_spawn_delay : float = 2.0

# Complexité des ennemis
var min_weaknesses : int = 1
var max_weaknesses : int = 3
var avg_weaknesses : float = 1.2

# Spawn en vagues ou groupes
var enemies_per_wave : int = 1
var enemies_spawned_in_wave : int = 0
var time_between_waves : float = 5.0

# Distribution des couloirs dans la vague actuelle
var current_wave_lanes : Array = []  # Stocke quel couloir pour chaque ennemi de la vague

# État
var is_spawning : bool = false
var spawned_enemies : Array = []
var total_enemies_spawned : int = 0

# Patterns intelligents
var spawn_patterns : Array = [
	"single",      # Un ennemi à la fois
	"burst",       # Plusieurs ennemis rapidement
	"increasing",  # Difficulté croissante
	"mixed"        # Mélange aléatoire
]
var current_pattern : String = "single"
var pattern_timer : float = 0.0
const PATTERN_CHANGE_INTERVAL : float = 30.0  # Change de pattern toutes les 30s

func _ready() -> void:
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	if auto_start:
		start_spawning()

func _process(delta: float) -> void:
	if not is_spawning:
		return
	
	# Changer de pattern périodiquement
	pattern_timer += delta
	if pattern_timer >= PATTERN_CHANGE_INTERVAL:
		pattern_timer = 0.0
		select_next_pattern()

func start_spawning():
	is_spawning = true
	difficulty_level = 1.0
	total_enemies_spawned = 0
	current_pattern = "single"
	
	spawn_next_enemy()

func stop_spawning():
	is_spawning = false
	spawn_timer.stop()

func update_difficulty(perf_rating: float, speed: float):
	"""Appelé par le GameManager pour mettre à jour les paramètres"""
	performance_rating = perf_rating
	game_speed = speed
	
	# Ajuster la difficulté selon les performances
	# Si le joueur performe bien (rating > 1.2), augmenter la difficulté
	# Si le joueur galère (rating < 0.8), réduire la difficulté
	
	var old_difficulty = difficulty_level
	
	if performance_rating > 1.3:
		difficulty_level = min(difficulty_level + 0.01, 3.0)
	elif performance_rating < 0.7:
		difficulty_level = max(difficulty_level - 0.02, 0.5)
	
	# Si la difficulté a augmenté significativement, augmenter légèrement la vitesse du jeu
	if difficulty_level > old_difficulty + 0.5:
		request_speed_increase()
	
	# Ajuster selon la vitesse du jeu
	var speed_factor = (speed - 150.0) / (500.0 - 150.0)  # Normaliser entre 0 et 1
	
	# Calculer les paramètres de spawn
	calculate_spawn_parameters(speed_factor)

func request_speed_increase():
	"""Demande au GameManager d'augmenter légèrement la vitesse globale"""
	var game_manager = get_tree().get_first_node_in_group("GM")
	if game_manager and game_manager.has_method("increase_speed_from_difficulty"):
		game_manager.increase_speed_from_difficulty(5.0)  # Boost de +5

func calculate_spawn_parameters(speed_factor: float):
	"""Calcule les paramètres de spawn en fonction de la difficulté"""
	
	# Délai entre spawns (plus rapide = moins de délai)
	var base_delay = lerp(max_spawn_delay, min_spawn_delay, difficulty_level / 3.0)
	current_spawn_delay = base_delay * (1.0 - speed_factor * 0.3)
	current_spawn_delay = clamp(current_spawn_delay, min_spawn_delay, max_spawn_delay)
	
	# Nombre moyen de faiblesses
	avg_weaknesses = 1.0 + (difficulty_level * 0.8)
	avg_weaknesses = clamp(avg_weaknesses, 1.0, 4.0)
	
	# Nombre d'ennemis par vague selon le pattern
	match current_pattern:
		"single":
			enemies_per_wave = 1
		"burst":
			enemies_per_wave = int(2 + difficulty_level)
		"increasing":
			enemies_per_wave = int(1 + (total_enemies_spawned / 10.0))
		"mixed":
			enemies_per_wave = randi_range(1, int(2 + difficulty_level))
	
	# Limiter à 6 ennemis max par vague
	enemies_per_wave = min(enemies_per_wave, 6)
	
	# Préparer la distribution des couloirs pour cette vague
	prepare_wave_lanes()

func spawn_next_enemy():
	if not is_spawning:
		return
	
	# Déterminer le nombre de faiblesses pour cet ennemi
	var num_weaknesses = calculate_enemy_weaknesses()
	
	# Créer les faiblesses
	var weaknesses = generate_smart_weaknesses(num_weaknesses)
	
	# Déterminer le couloir pour cet ennemi
	var lane = get_lane_for_current_enemy()
	
	# Spawn l'ennemi
	spawn_enemy(weaknesses, lane)
	
	# Gestion des vagues
	enemies_spawned_in_wave += 1
	total_enemies_spawned += 1
	
	# Vérifier si on doit continuer la vague ou faire une pause
	if enemies_spawned_in_wave >= enemies_per_wave:
		# Fin de vague, pause plus longue
		enemies_spawned_in_wave = 0
		spawn_timer.wait_time = time_between_waves / (1.0 + difficulty_level * 0.2)
	else:
		# Spawn suivant dans la vague
		spawn_timer.wait_time = current_spawn_delay
	
	spawn_timer.start()

func calculate_enemy_weaknesses() -> int:
	"""Détermine intelligemment le nombre de faiblesses"""
	
	# Distribution pondérée basée sur avg_weaknesses
	var base = floor(avg_weaknesses)
	var chance = avg_weaknesses - base
	
	var num = int(base)
	if randf() < chance:
		num += 1
	
	# Variation aléatoire ±1 pour plus de variété
	if randf() < 0.3:
		num += [-1, 1][randi() % 2]
	
	return clamp(num, min_weaknesses, max_weaknesses)

func generate_smart_weaknesses(count: int) -> Array:
	"""Génère des faiblesses avec des patterns intéressants"""
	var available_types = ["fire", "water", "earth", "air"]
	var weaknesses = []
	
	# Pattern selon la difficulté
	if count == 1:
		# Simple : un seul élément aléatoire
		weaknesses.append(available_types[randi() % 4])
		
	elif count == 2:
		# Moyen : deux éléments différents ou répétés
		if randf() < 0.7:
			# Deux différents
			available_types.shuffle()
			weaknesses.append(available_types[0])
			weaknesses.append(available_types[1])
		else:
			# Deux identiques (plus difficile)
			var type = available_types[randi() % 4]
			weaknesses.append(type)
			weaknesses.append(type)
			
	elif count == 3:
		# Difficile : patterns variés
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
		# Très difficile : patterns complexes
		var pattern_type = randi() % 4
		match pattern_type:
			0:  # Tous différents
				available_types.shuffle()
				weaknesses = available_types.duplicate()
			1:  # A-A-B-B
				available_types.shuffle()
				weaknesses = [available_types[0], available_types[0], available_types[1], available_types[1]]
			2:  # A-B-C-A (cycle)
				available_types.shuffle()
				weaknesses = [available_types[0], available_types[1], available_types[2], available_types[0]]
			3:  # A-A-A-B (spam)
				available_types.shuffle()
				weaknesses = [available_types[0], available_types[0], available_types[0], available_types[1]]
	
	return weaknesses

func prepare_wave_lanes():
	"""Prépare la distribution des couloirs pour la vague à venir"""
	current_wave_lanes.clear()
	
	# Stratégies selon le nombre d'ennemis
	if enemies_per_wave == 1:
		# Un seul ennemi : couloir aléatoire
		current_wave_lanes.append(available_lanes[randi() % 2])
		
	elif enemies_per_wave == 2:
		# Deux ennemis : plusieurs possibilités
		var strategy = randi() % 3
		match strategy:
			0:  # Même couloir (plus difficile)
				var lane = available_lanes[randi() % 2]
				current_wave_lanes.append(lane)
				current_wave_lanes.append(lane)
			1:  # Couloirs différents
				current_wave_lanes.append(SpawnLane.TOP)
				current_wave_lanes.append(SpawnLane.BOTTOM)
			2:  # Couloirs différents inversés
				current_wave_lanes.append(SpawnLane.BOTTOM)
				current_wave_lanes.append(SpawnLane.TOP)
	
	else:
		# 3+ ennemis : distribution intelligente
		var strategy = randi() % 4
		match strategy:
			0:  # Alternance TOP-BOTTOM-TOP-BOTTOM
				for i in range(enemies_per_wave):
					current_wave_lanes.append(SpawnLane.TOP if i % 2 == 0 else SpawnLane.BOTTOM)
			
			1:  # Alternance BOTTOM-TOP-BOTTOM-TOP
				for i in range(enemies_per_wave):
					current_wave_lanes.append(SpawnLane.BOTTOM if i % 2 == 0 else SpawnLane.TOP)
			
			2:  # Groupes par couloir (ex: TOP-TOP-BOTTOM-BOTTOM)
				var half = enemies_per_wave / 2
				for i in range(enemies_per_wave):
					current_wave_lanes.append(SpawnLane.TOP if i < half else SpawnLane.BOTTOM)
			
			3:  # Complètement aléatoire (chaos)
				for i in range(enemies_per_wave):
					current_wave_lanes.append(available_lanes[randi() % 2])

func get_lane_for_current_enemy() -> SpawnLane:
	"""Retourne le couloir pour l'ennemi actuel dans la vague"""
	var index = enemies_spawned_in_wave
	if index < current_wave_lanes.size():
		return current_wave_lanes[index]
	else:
		# Fallback si jamais on dépasse (ne devrait pas arriver)
		return available_lanes[randi() % 2]

func spawn_enemy(weaknesses: Array, lane: SpawnLane):
	var enemy = enemy_scene.instantiate()
	
	# Définir la position selon le couloir
	match lane:
		SpawnLane.TOP:
			enemy.position = spawn_position_top
		SpawnLane.BOTTOM:
			enemy.position = spawn_position_bottom
	
	enemy.set_weaknesses(weaknesses)
	enemy.destroyed.connect(_on_enemy_destroyed)
	
	get_parent().add_child(enemy)
	spawned_enemies.append(enemy)
	enemy_spawned.emit(enemy)

func select_next_pattern():
	"""Change intelligemment de pattern"""
	var old_pattern = current_pattern
	
	# Choisir un nouveau pattern différent
	var available = spawn_patterns.filter(func(p): return p != old_pattern)
	current_pattern = available[randi() % available.size()]
	
	print("Pattern changé : ", old_pattern, " -> ", current_pattern)

func _on_spawn_timer_timeout():
	spawn_next_enemy()

func _on_enemy_destroyed(enemy):
	spawned_enemies.erase(enemy)

# Fonctions utilitaires
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
	difficulty_level = wave_index

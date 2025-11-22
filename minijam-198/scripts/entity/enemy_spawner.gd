# EnemySpawner.gd
extends Node2D

signal enemy_spawned(enemy)
signal wave_completed(wave_number)

# Scène de l'ennemi de base
@export var enemy_scene : PackedScene = preload("res://scenes/entity/enemy.tscn")

# Configuration du spawn
@export var spawn_position : Vector2 = Vector2(1200, 300)
@export var auto_start : bool = false

# Timers
@onready var spawn_timer = $SpawnTimer

# Patterns de spawn (vagues)
var spawn_patterns := [
	# Wave 1 : Facile - 1 faiblesse
	{
		"enemies": [
			{"weaknesses": ["fire"], "delay": 2.0},
			{"weaknesses": ["water"], "delay": 2.0},
			{"weaknesses": ["earth"], "delay": 2.0},
		]
	},
	# Wave 2 : Moyen - 2 faiblesses
	{
		"enemies": [
			{"weaknesses": ["fire", "air"], "delay": 1.5},
			{"weaknesses": ["water", "earth"], "delay": 1.5},
			{"weaknesses": ["air", "fire"], "delay": 1.5},
		]
	},
	# Wave 3 : Difficile - 3 faiblesses
	{
		"enemies": [
			{"weaknesses": ["fire", "water", "air"], "delay": 1.2},
			{"weaknesses": ["earth", "fire", "water"], "delay": 1.2},
			{"weaknesses": ["air", "earth", "fire"], "delay": 1.2},
		]
	},
	# Wave 4 : Expert - 4 faiblesses + rapide
	{
		"enemies": [
			{"weaknesses": ["fire", "water", "earth", "air"], "delay": 1.0},
			{"weaknesses": ["air", "earth", "water", "fire"], "delay": 0.8},
		]
	}
]

# État actuel
var current_wave : int = 0
var current_enemy_index : int = 0
var is_spawning : bool = false
var spawned_enemies : Array = []

# Mode de spawn
enum SpawnMode {
	PATTERN,      # Suit les patterns définis
	RANDOM,       # Spawn aléatoire
	ENDLESS       # Mode infini avec difficulté croissante
}
@export var spawn_mode : SpawnMode = SpawnMode.PATTERN

# Configuration du mode aléatoire/infini
var difficulty : float = 1.0
const DIFFICULTY_INCREASE : float = 0.1

func _ready() -> void:
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	if auto_start:
		start_spawning()

func start_spawning():
	is_spawning = true
	current_wave = 0
	current_enemy_index = 0
	difficulty = 1.0
	
	match spawn_mode:
		SpawnMode.PATTERN:
			spawn_next_from_pattern()
		SpawnMode.RANDOM, SpawnMode.ENDLESS:
			spawn_random_enemy()

func stop_spawning():
	is_spawning = false
	spawn_timer.stop()

func spawn_next_from_pattern():
	if not is_spawning:
		return
	
	# Vérifier si on a fini toutes les vagues
	if current_wave >= spawn_patterns.size():
		stop_spawning()
		print("Toutes les vagues terminées !")
		return
	
	var wave = spawn_patterns[current_wave]
	
	# Vérifier si on a fini tous les ennemis de cette vague
	if current_enemy_index >= wave["enemies"].size():
		current_wave += 1
		current_enemy_index = 0
		wave_completed.emit(current_wave - 1)
		
		# Pause entre les vagues
		await get_tree().create_timer(3.0).timeout
		spawn_next_from_pattern()
		return
	
	# Spawn l'ennemi actuel
	var enemy_data = wave["enemies"][current_enemy_index]
	spawn_enemy(enemy_data["weaknesses"])
	
	# Préparer le prochain spawn
	current_enemy_index += 1
	spawn_timer.wait_time = enemy_data["delay"]
	spawn_timer.start()

func spawn_random_enemy():
	if not is_spawning:
		return
	
	# Générer des faiblesses aléatoires basées sur la difficulté
	var num_weaknesses = clamp(int(difficulty), 1, 4)
	var weaknesses = generate_random_weaknesses(num_weaknesses)
	
	spawn_enemy(weaknesses)
	
	# Calculer le délai en fonction de la difficulté
	var delay = max(0.5, 2.0 - (difficulty * 0.1))
	spawn_timer.wait_time = delay
	spawn_timer.start()
	
	# Augmenter la difficulté en mode infini
	if spawn_mode == SpawnMode.ENDLESS:
		difficulty += DIFFICULTY_INCREASE

func spawn_enemy(weaknesses: Array):
	var enemy = enemy_scene.instantiate()
	enemy.position = spawn_position
	enemy.set_weaknesses(weaknesses)
	
	# Connecter les signaux
	enemy.destroyed.connect(_on_enemy_destroyed)
	
	get_parent().add_child(enemy)
	spawned_enemies.append(enemy)
	enemy_spawned.emit(enemy)

func generate_random_weaknesses(count: int) -> Array:
	var available_types = ["fire", "water", "earth", "air"]
	var weaknesses = []
	
	# Mélanger pour éviter les répétitions immédiates
	available_types.shuffle()
	
	for i in range(count):
		weaknesses.append(available_types[i % available_types.size()])
	
	return weaknesses

func _on_spawn_timer_timeout():
	match spawn_mode:
		SpawnMode.PATTERN:
			spawn_next_from_pattern()
		SpawnMode.RANDOM, SpawnMode.ENDLESS:
			spawn_random_enemy()

func _on_enemy_destroyed(enemy):
	spawned_enemies.erase(enemy)


# Fonctions utilitaires pour changer de mode
func set_pattern_mode():
	spawn_mode = SpawnMode.PATTERN
	current_wave = 0
	current_enemy_index = 0

func set_random_mode():
	spawn_mode = SpawnMode.RANDOM
	difficulty = 1.0

func set_endless_mode():
	spawn_mode = SpawnMode.ENDLESS
	difficulty = 1.0

func skip_to_wave(wave_index: int):
	if wave_index < spawn_patterns.size():
		current_wave = wave_index
		current_enemy_index = 0
		spawn_next_from_pattern()

# Ajouter des patterns personnalisés en runtime
func add_custom_pattern(pattern: Dictionary):
	spawn_patterns.append(pattern)

func clear_all_enemies():
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()

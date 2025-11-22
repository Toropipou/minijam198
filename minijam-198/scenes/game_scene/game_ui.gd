# GameManager.gd - Version adaptée avec spawner
extends Node

# Variables de jeu
var score : int = 0
var combo : int = 0  # Système de combo
var game_running : bool = false
var speed : float = 200.0
const MAX_SPEED : float = 400.0
const SPEED_INCREASE : float = 5.0

# Liste des ennemis actifs
var active_enemies : Array = []

# Cooldowns des sorts
var spell_cooldowns := {
	"fire": 0.0,
	"water": 0.0,
	"earth": 0.0,
	"air": 0.0
}
const SPELL_COOLDOWN_TIME : float = 0.5
var global_spell_cooldown
# Références
@onready var viewport = $ViewportContainer/ConfigurableSubViewport
@onready var player = $ViewportContainer/ConfigurableSubViewport/Player
@onready var parallax = $ViewportContainer/ConfigurableSubViewport/Bg
@onready var spawner = $ViewportContainer/ConfigurableSubViewport/EnemySpawner
@onready var hud = $ViewportContainer/ConfigurableSubViewport/hud

func _ready() -> void:
	# Connecter les signaux du spawner
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	spawner.wave_completed.connect(_on_wave_completed)
	
	new_game()

func new_game():
	score = 0
	combo = 0
	speed = 200.0
	game_running = false
	
	# Nettoyer les ennemis existants
	spawner.clear_all_enemies()
	active_enemies.clear()
	
	# Reset cooldown global
	global_spell_cooldown = 0.0
	
	hud.update_score(score)
	hud.show_start_message()

func _process(delta: float) -> void:
	if not game_running:
		if Input.is_action_just_pressed("ui_accept"):
			start_game()
		return
	
	# Augmenter progressivement la vitesse
	if speed < MAX_SPEED:
		speed += SPEED_INCREASE * delta
	
	# Défilement du parallax (vers la gauche)
	parallax.scroll_offset.x -= speed * delta
	
	# Déplacer les ennemis
	var screen_left = -100
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.position.x -= speed / 5 * delta
			
			# Vérifier si l'ennemi est sorti de l'écran
			if enemy.position.x < screen_left:
				_on_enemy_escaped(enemy)
	
	# Mettre à jour le cooldown global
	if global_spell_cooldown > 0:
		global_spell_cooldown -= delta
		hud.update_cooldown("global", global_spell_cooldown / SPELL_COOLDOWN_TIME)
	
	# Score augmente avec le temps
	score += delta * 10
	hud.update_score(int(score))

func start_game():
	game_running = true
	spawner.start_spawning()
	hud.hide_start_message()

func _on_enemy_spawned(enemy):
	active_enemies.append(enemy)
	
	# Connecter les signaux de l'ennemi
	enemy.destroyed.connect(_on_enemy_destroyed)
	enemy.weakness_hit.connect(_on_enemy_weakness_hit)
	enemy.wrong_spell_used.connect(_on_wrong_spell)

func _on_enemy_destroyed(enemy):
	active_enemies.erase(enemy)
	
	# Bonus de score avec combo
	combo += 1
	var points = 100 * combo
	score += points
	
	# Feedback visuel (si tu as ces fonctions dans le HUD)
	if hud.has_method("update_combo"):
		hud.update_combo(combo)
	if hud.has_method("show_points_popup"):
		hud.show_points_popup(points, enemy.position)

func _on_enemy_escaped(enemy):
	if not is_instance_valid(enemy):
		return
		
	active_enemies.erase(enemy)
	combo = 0  # Reset combo
	
	# Feedback visuel
	if hud.has_method("update_combo"):
		hud.update_combo(combo)
	
	# L'ennemi s'autodétruit via le signal escaped
	enemy.queue_free()

func _on_enemy_weakness_hit(enemy, remaining: int):
	# Bonus partiel pour chaque faiblesse correcte
	score += 50
	
	# Feedback visuel
	if hud.has_method("show_hit_feedback"):
		hud.show_hit_feedback(enemy.position, true)

func _on_wrong_spell(enemy, spell_type: String):
	# Pénalité pour mauvais sort
	combo = max(0, combo - 1)
	
	# Feedback visuel
	if hud.has_method("update_combo"):
		hud.update_combo(combo)
	if hud.has_method("show_hit_feedback"):
		hud.show_hit_feedback(enemy.position, false)

func _on_wave_completed(wave_number: int):
	# Bonus de vague complétée
	score += 500
	
	# Feedback visuel
	if hud.has_method("show_wave_complete"):
		hud.show_wave_complete(wave_number + 1)

func cast_spell(spell_type: String):
	# Vérifier le cooldown global
	if global_spell_cooldown > 0:
		return
	
	# Activer le cooldown global
	global_spell_cooldown = SPELL_COOLDOWN_TIME
	
	# Trouver l'ennemi le plus proche
	var closest_enemy = get_closest_enemy()
	if closest_enemy:
		# Lancer un projectile vers l'ennemi
		spawn_spell_projectile(spell_type, closest_enemy)
		player.play_cast_animation(spell_type)

func spawn_spell_projectile(spell_type: String, target_enemy):
	# Charger la scène du projectile
	var projectile_scene = preload("res://scenes/entity/spell_projectile.tscn")
	var projectile = projectile_scene.instantiate()
	
	# Configurer le projectile
	projectile.position = player.position + Vector2(50, 0)  # Spawn devant le joueur
	projectile.spell_type = spell_type
	projectile.target_enemy = target_enemy
	
	# Ajouter le projectile au viewport
	viewport.add_child(projectile)

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

# Fonctions utilitaires pour changer de mode de spawn (debug/testing)
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

# Player.gd
extends CharacterBody2D

@onready var sprite = $ColorRect
@onready var game_manager = get_parent().get_parent().get_parent()
@onready var spell_projectile_scene = preload("res://scenes/entity/spell_projectile.tscn")

# Système de PV
signal health_changed(current_health: int, max_health: int)

@export var max_health: int = 3
var current_health: int = 3

# Mapping des touches aux sorts
const SPELL_KEYS = {
	"spell_1": "fire",    # Par exemple touche 1 ou Z
	"spell_2": "water",   # Touche 2 ou X
	"spell_3": "earth",   # Touche 3 ou C
	"spell_4": "air"      # Touche 4 ou V
}

# Système de ciblage de couloir
enum TargetLane { TOP, BOTTOM }
var current_target_lane : TargetLane = TargetLane.BOTTOM

# Positions des couloirs (doivent correspondre aux positions du spawner)
const LANE_TOP_Y : float = 200.0
const LANE_BOTTOM_Y : float = 547.0

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	health_changed.emit(current_health, max_health)

func _process(_delta: float) -> void:
	# Changement de couloir ciblé avec les flèches ou W/S
	if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("lane_up"):
		switch_to_top_lane()
	elif Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("lane_down"):
		switch_to_bottom_lane()
	
	# Détecter les inputs de sorts
	for action in SPELL_KEYS.keys():
		if Input.is_action_just_pressed(action):
			var spell_type = SPELL_KEYS[action]
			
			# Tentative de lancer le sort avec le couloir ciblé
			var success = game_manager.cast_spell(spell_type, current_target_lane)
			
			if success:
				print("Sort lancé : ", spell_type, " vers couloir ", "HAUT" if current_target_lane == TargetLane.TOP else "BAS")
			else:
				print("Impossible de lancer le sort (mana ou cooldown)")
			
			break

# Méthode pour prendre des dégâts
func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	
	current_health = clamp(current_health - amount, 0, max_health)
	health_changed.emit(current_health, max_health)
	
	print("💔 Dégâts reçus : ", amount, " | PV restants : ", current_health, "/", max_health)
	
	# Vérifier si le joueur est mort
	if current_health <= 0:
		die()

# Méthode pour se soigner
func heal(amount: int) -> void:
	if amount <= 0:
		return
	
	var old_health = current_health
	current_health = clamp(current_health + amount, 0, max_health)
	var actual_heal = current_health - old_health
	
	if actual_heal > 0:
		health_changed.emit(current_health, max_health)
		print("💚 Soins reçus : ", actual_heal, " | PV actuels : ", current_health, "/", max_health)
	else:
		print("⚕️ PV déjà au maximum")

# Méthode appelée lors de la mort du joueur
func die() -> void:
	print("💀 Le joueur est mort !")
	SceneLoader.load_scene(get_main_menu_scene_path())
@export_file("*.tscn") var main_menu_scene_path : String
func get_main_menu_scene_path() -> String:
	if main_menu_scene_path.is_empty():
		return AppConfig.main_menu_scene_path
	return main_menu_scene_path
	
func switch_to_top_lane():
	current_target_lane = TargetLane.TOP
	update_visual_indicator()
	print("🎯 Ciblage : COULOIR HAUT")

func switch_to_bottom_lane():
	current_target_lane = TargetLane.BOTTOM
	update_visual_indicator()
	print("🎯 Ciblage : COULOIR BAS")

func update_visual_indicator():
	# Déplacer légèrement le sprite pour indiquer le couloir ciblé
	var target_y = LANE_BOTTOM_Y if current_target_lane == TargetLane.BOTTOM else LANE_TOP_Y
	
	# Animation douce vers la position du couloir
	var tween = create_tween()
	tween.tween_property(self, "position:y", target_y, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func play_cast_animation(spell_type: String, lane: TargetLane):
	# Jouer une animation de cast selon le type de sort
	#sprite.play("cast_" + spell_type)
	
	# Instancier un effet visuel du sort
	spawn_spell_effect(spell_type, lane)

func spawn_spell_effect(spell_type: String, lane: TargetLane):
	var projectile = spell_projectile_scene.instantiate()
	projectile.position = position + Vector2(50, 0)
	projectile.spell_type = spell_type
	
	# Définir la trajectoire du projectile vers le couloir ciblé
	var target_y = LANE_TOP_Y if lane == TargetLane.TOP else LANE_BOTTOM_Y
	projectile.target_y = target_y
	
	get_parent().add_child(projectile)

func get_current_lane() -> TargetLane:
	return current_target_lane

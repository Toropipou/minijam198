# Player.gd
extends CharacterBody2D

@onready var sprite = $ColorRect
@onready var game_manager = get_parent().get_parent().get_parent()
@onready var spell_projectile_scene = preload("res://scenes/entity/spell_projectile.tscn")

# Indicateur de visée
@onready var targeting_indicator = $TargetingIndicator  # Nœud qui contiendra la flèche
var arrow_size_base := Vector2(2,2)

# Système de PV
signal health_changed(current_health: int, max_health: int)

@export var max_health: int = 3
var current_health: int = 3

# Mapping des touches aux sorts
const SPELL_KEYS = {
	"spell_1": "Coeur",
	"spell_2": "Carreau",
	"spell_3": "Trefle",
	"spell_4": "Pique"
}

# Système de ciblage de couloir
enum TargetLane { TOP, BOTTOM }
var current_target_lane : TargetLane = TargetLane.BOTTOM

# Positions des couloirs (pour les projectiles)
const LANE_TOP_Y : float = 350.0
const LANE_BOTTOM_Y : float = 722.0

# Paramètres de l'indicateur rotatif (comme dans CarryBallChallenge)
const INDICATOR_DISTANCE : float = 130.0  # Distance de la flèche par rapport au centre du joueur

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	health_changed.emit(current_health, max_health)
	
	# Créer l'indicateur si non présent
	_setup_targeting_indicator()
	
	# Initialiser la rotation de l'indicateur
	update_arrow_direction()
	
	# Animation idle subtile
	_start_indicator_idle_animation()

func _setup_targeting_indicator() -> void:
	"""Crée l'indicateur de visée rotatif"""
	targeting_indicator = $TargetingIndicator

func _start_indicator_idle_animation():
	"""Animation idle subtile de l'indicateur"""
	if not targeting_indicator:
		return
	
	var tween = create_tween()
	tween.set_loops()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# Pulsation d'échelle légère
	var base_scale = arrow_size_base
	tween.tween_property(targeting_indicator, "scale", base_scale * 1.1, 0.6)
	tween.tween_property(targeting_indicator, "scale", base_scale, 0.6)

func _process(_delta: float) -> void:
	# Changement de couloir ciblé
	if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("lane_up"):
		switch_to_top_lane()
	elif Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("lane_down"):
		switch_to_bottom_lane()
	
	# Mettre à jour la direction de la flèche en continu
	update_arrow_direction()
	
	# Détecter les inputs de sorts
	for action in SPELL_KEYS.keys():
		if Input.is_action_just_pressed(action):
			var spell_type = SPELL_KEYS[action]
			
			var success = game_manager.cast_spell(spell_type, current_target_lane)
			
			if success:
				print("Sort lancé : ", spell_type, " vers couloir ", "HAUT" if current_target_lane == TargetLane.TOP else "BAS")
				if game_manager.current_mana <= 0:
					game_manager.qte_mandatory = true
			else:
				print("Impossible de lancer le sort (mana ou cooldown)")
			
			break

func update_arrow_direction():
	"""Met à jour la direction de la flèche pour pointer vers le couloir ciblé"""
	if not is_instance_valid(targeting_indicator):
		return
	
	# Déterminer la position cible selon le couloir
	var target_y = LANE_TOP_Y if current_target_lane == TargetLane.TOP else LANE_BOTTOM_Y
	
	# Position cible dans le monde
	var target_position = Vector2(global_position.x + INDICATOR_DISTANCE, target_y)
	
	# Calculer la direction depuis le joueur vers la cible
	var direction = (target_position - global_position).normalized()
	var angle = direction.angle()
	
	# Appliquer la rotation à la flèche
	targeting_indicator.rotation = angle

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	
	current_health = clamp(current_health - amount, 0, max_health)
	health_changed.emit(current_health, max_health)
	
	print("💔 Dégâts reçus : ", amount, " | PV restants : ", current_health, "/", max_health)
	
	if current_health <= 0:
		die()

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
	print("🎯 Ciblage : COULOIR HAUT")

func switch_to_bottom_lane():
	current_target_lane = TargetLane.BOTTOM
	print("🎯 Ciblage : COULOIR BAS")

func play_cast_animation(spell_type: String, lane: TargetLane):
	# Animation de l'indicateur lors du cast
	_flash_indicator()
	
	# Instancier l'effet visuel du sort avec trajectoire courbe
	spawn_spell_effect(spell_type, lane)

func _flash_indicator():
	"""Fait flasher l'indicateur lors d'un cast"""
	if not targeting_indicator:
		return
	
	var original_modulate = targeting_indicator.modulate
	var flash_color = Color(2.0, 2.0, 2.0, 1.0)  # Super lumineux
	
	var tween = create_tween()
	tween.tween_property(targeting_indicator, "modulate", flash_color, 0.05)
	tween.tween_property(targeting_indicator, "modulate", original_modulate, 0.15)

func spawn_spell_effect(spell_type: String, lane: TargetLane):
	var projectile = spell_projectile_scene.instantiate()
	projectile.position = position + Vector2(50, 0)
	projectile.spell_type = spell_type
	
	# Le projectile part de la position du joueur et va vers le couloir ciblé
	var target_y = LANE_TOP_Y if lane == TargetLane.TOP else LANE_BOTTOM_Y
	projectile.target_y = target_y
	
	# Passer le type de trajectoire (courbe si c'est vers le haut)
	projectile.use_curved_trajectory = (lane == TargetLane.TOP)
	
	get_parent().add_child(projectile)

func get_current_lane() -> TargetLane:
	return current_target_lane

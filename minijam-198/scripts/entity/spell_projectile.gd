# SpellProjectile.gd
extends Area2D

var spell_type : String = "fire"
var speed : float = 800.0
var target_y : float = 300.0  # Position Y du couloir ciblé

@onready var visual = $ColorRect
@onready var particles = $particles

# Couleurs selon le type de sort
const SPELL_COLORS = {
	"fire": Color(1.0, 0.3, 0.1),
	"water": Color(0.1, 0.5, 1.0),
	"earth": Color(0.2, 0.8, 0.2),
	"air": Color(0.912, 0.862, 0.0, 1.0)
}

# Système de trajectoire
var start_pos : Vector2
var start_y : float
var has_reached_lane : bool = false
var travel_distance : float = 0.0

# Nouveau : trajectoire courbe
var use_curved_trajectory : bool = false
const CURVE_HEIGHT : float = 50.0  # Hauteur de l'arc de la courbe
const CURVE_DISTANCE : float = 30.0  # Distance sur laquelle la courbe se produit

func _ready() -> void:
	# Appliquer la couleur selon le type de sort
	if SPELL_COLORS.has(spell_type):
		visual.color = SPELL_COLORS[spell_type]
		particles.color = SPELL_COLORS[spell_type]
	
	# Sauvegarder la position de départ
	start_pos = position
	start_y = position.y
	
	# Auto-destruction après un certain temps (sécurité)
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(self):
		queue_free()

func _process(delta: float) -> void:
	# Avancer horizontalement
	position.x += speed * delta
	travel_distance += speed * delta
	
	if use_curved_trajectory:
		# Trajectoire en arc parabolique
		_update_curved_trajectory()
	else:
		# Trajectoire linéaire originale
		_update_linear_trajectory(delta)
	
	# Rotation pour suivre la direction du mouvement
	_update_rotation()

func _update_curved_trajectory() -> void:
	"""Trajectoire courbe parabolique pour tir vers le haut"""
	if has_reached_lane:
		return
	
	# Progression normalisée (0 à 1)
	var progress = clamp(travel_distance / CURVE_DISTANCE, 0.0, 1.0)
	
	if progress >= 1.0:
		# Fin de la trajectoire courbe
		position.y = target_y
		has_reached_lane = true
		return
	
	# Interpolation quadratique pour une courbe douce
	# On part de start_y, monte en arc, puis descend vers target_y
	var height_diff = target_y - start_y
	
	# Fonction quadratique : y = a*x^2 + b*x + c
	# Pour créer un arc qui monte puis descend
	var arc_offset = -CURVE_HEIGHT * 4.0 * progress * (1.0 - progress)
	
	# Position Y = interpolation linéaire + offset de l'arc
	var linear_y = lerp(start_y, target_y, progress)
	position.y = linear_y + arc_offset

func _update_linear_trajectory(delta: float) -> void:
	"""Trajectoire linéaire originale pour tir horizontal"""
	if has_reached_lane:
		return
	
	var distance_to_target = target_y - position.y
	
	if abs(distance_to_target) < 5.0:
		position.y = target_y
		has_reached_lane = true
		rotation = 0
	else:
		# Se déplacer vers le couloir
		var direction = sign(distance_to_target)
		var vertical_speed = 600.0
		position.y += direction * vertical_speed * delta

func _update_rotation() -> void:
	"""Met à jour la rotation pour suivre la trajectoire"""
	if has_reached_lane and not use_curved_trajectory:
		rotation = 0
		return
	
	if use_curved_trajectory:
		# Calculer la dérivée de la trajectoire pour obtenir la tangente
		var progress = clamp(travel_distance / CURVE_DISTANCE, 0.0, 1.0)
		
		if progress < 1.0:
			# Dérivée de la fonction parabolique
			var arc_derivative = -CURVE_HEIGHT * 4.0 * (1.0 - 2.0 * progress)
			var height_diff = target_y - start_y
			var linear_derivative = height_diff / CURVE_DISTANCE
			
			# Pente totale
			var total_derivative = linear_derivative + arc_derivative
			
			# Angle basé sur la vitesse horizontale et verticale
			var velocity = Vector2(speed, total_derivative * speed)
			rotation = velocity.angle()
		else:
			rotation = 0
	else:
		# Rotation pour trajectoire linéaire
		if not has_reached_lane:
			var distance_to_target = target_y - position.y
			var direction = sign(distance_to_target)
			var vertical_speed = 600.0
			var velocity = Vector2(speed, direction * vertical_speed)
			rotation = velocity.angle()

# Fonction appelée par l'ennemi pour récupérer le type de sort
func get_spell_type() -> String:
	return spell_type

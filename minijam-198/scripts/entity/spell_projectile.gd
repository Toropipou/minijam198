# SpellProjectile.gd
extends Area2D

var spell_type : String = "fire"
var speed : float = 800.0
var target_y : float = 300.0  # Position Y du couloir ciblé

@onready var visual = $ColorRect
@onready var particles = $particles

# Couleurs selon le type de sort
const SPELL_COLORS = {
	"fire": Color(1.0, 0.3, 0.1),      # Rouge-orange
	"water": Color(0.1, 0.5, 1.0),     # Bleu
	"earth": Color(0.2, 0.8, 0.2),     # Vert
	"air": Color(0.912, 0.862, 0.0, 1.0)       # Blanc-bleu clair
}

# Pour la trajectoire
var start_y : float
var has_reached_lane : bool = false
const VERTICAL_SPEED : float = 600.0

func _ready() -> void:
	# Appliquer la couleur selon le type de sort
	if SPELL_COLORS.has(spell_type):
		visual.color = SPELL_COLORS[spell_type]
		particles.color = SPELL_COLORS[spell_type]
	
	# Sauvegarder la position de départ
	start_y = position.y
	
	# Auto-destruction après un certain temps (sécurité)
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(self):
		queue_free()

func _process(delta: float) -> void:
	# Avancer horizontalement
	position.x += speed * delta
	
	# Se déplacer vers le couloir ciblé
	if not has_reached_lane:
		var distance_to_target = target_y - position.y
		
		if abs(distance_to_target) < 5.0:
			# On a atteint le couloir
			position.y = target_y
			has_reached_lane = true
			rotation = 0  # Remettre horizontal
		else:
			# Se déplacer vers le couloir
			var direction = sign(distance_to_target)
			position.y += direction * VERTICAL_SPEED * delta
			
			# Rotation pour suivre la trajectoire
			var velocity = Vector2(speed, direction * VERTICAL_SPEED)
			rotation = velocity.angle()

# Fonction appelée par l'ennemi pour récupérer le type de sort
func get_spell_type() -> String:
	return spell_type

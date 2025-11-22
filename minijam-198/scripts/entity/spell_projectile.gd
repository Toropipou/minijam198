# SpellProjectile.gd
extends Area2D

var spell_type : String = "fire"
var speed : float = 800.0
var target_enemy = null
var is_homing : bool = true  # Suit l'ennemi ciblé

@onready var visual = $ColorRect
@onready var particles = $particles
# Couleurs selon le type de sort
const SPELL_COLORS = {
	"fire": Color(1.0, 0.3, 0.1),      # Rouge-orange
	"water": Color(0.1, 0.5, 1.0),     # Bleu
	"earth": Color(0.2, 0.8, 0.2),     # Vert
	"air": Color(0.912, 0.862, 0.0, 1.0)       # Blanc-bleu clair
}

func _ready() -> void:
	# Appliquer la couleur selon le type de sort
	if SPELL_COLORS.has(spell_type):
		visual.color = SPELL_COLORS[spell_type]
		particles.color = SPELL_COLORS[spell_type]
	# Auto-destruction après un certain temps (sécurité)
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(self):
		queue_free()

func _process(delta: float) -> void:
	if is_homing and is_instance_valid(target_enemy):
		# Suivre l'ennemi ciblé
		var direction = (target_enemy.global_position - global_position).normalized()
		position += direction * speed * delta
		
		# Rotation pour suivre la direction
		rotation = direction.angle()
	else:
		# Avancer tout droit vers la droite
		position.x += speed * delta

# Fonction appelée par l'ennemi pour récupérer le type de sort
func get_spell_type() -> String:
	return spell_type

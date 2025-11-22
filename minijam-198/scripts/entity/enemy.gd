# Enemy.gd
extends Area2D

signal destroyed(enemy)
signal weakness_hit(enemy, remaining_weaknesses)
signal wrong_spell_used(enemy, spell_type)

# Liste des faiblesses dans l'ordre
var weaknesses : Array = ["fire"]  # Par défaut
var current_weakness_index : int = 0

@onready var visual = $ColorRect
@onready var weakness_label = $WeaknessLabel
@onready var collision_shape = $CollisionShape2D

# Symboles de carte pour chaque type de sort
const WEAKNESS_SYMBOLS = {
	"fire": "♥",    # Coeur
	"water": "♦",   # Carreau
	"earth": "♣",   # Trèfle
	"air": "♠"      # Pique
}

# Couleurs pour les sorts
const WEAKNESS_COLORS = {
	"fire": Color(1.0, 0.3, 0.1),      # Rouge
	"water": Color(0.1, 0.5, 1.0),     # Bleu
	"earth": Color(0.2, 0.8, 0.2),     # Vert
	"air": Color(0.979, 0.915, 0.618, 1.0)        # Blanc-bleu
}

# État
var is_alive : bool = true

func _ready() -> void:
	# Connecter le signal de collision avec les projectiles
	area_entered.connect(_on_area_entered)
	
	# Configuration visuelle de base
	visual.color = Color(0.5, 0.5, 0.5)  # Gris par défaut
	
	update_weakness_display()

func set_weaknesses(new_weaknesses: Array):
	weaknesses = new_weaknesses.duplicate()
	current_weakness_index = 0
	update_weakness_display()

func _on_area_entered(area):
	# Vérifier si c'est un projectile de sort
	if area.has_method("get_spell_type"):
		var spell_type = area.get_spell_type()
		receive_spell(spell_type)
		
		# Détruire le projectile
		area.queue_free()

func receive_spell(spell_type: String):
	if not is_alive:
		return
	
	# Vérifier si c'est la bonne faiblesse
	var expected_weakness = weaknesses[current_weakness_index]
	
	if spell_type == expected_weakness:
		# BON SORT !
		hit_correct_weakness(spell_type)
	else:
		# MAUVAIS SORT
		hit_wrong_spell(spell_type)

func hit_correct_weakness(spell_type: String):
	# Effet visuel de succès
	flash_color(WEAKNESS_COLORS[spell_type], 0.3)
	
	# Passer à la faiblesse suivante
	current_weakness_index += 1
	
	# Vérifier si toutes les faiblesses sont éliminées
	if current_weakness_index >= weaknesses.size():
		# ENNEMI DÉTRUIT !
		weakness_hit.emit(self, 0)
		destroy()
	else:
		# Il reste des faiblesses
		var remaining = weaknesses.size() - current_weakness_index
		weakness_hit.emit(self, remaining)
		update_weakness_display()

func hit_wrong_spell(spell_type: String):
	# Effet visuel d'erreur (flash rouge)
	wrong_spell_used.emit(self, spell_type)
	flash_color(Color(1.0, 0.2, 0.2), 0.05)

func flash_color(color: Color, duration: float):
	var original_color = visual.color
	var tween = create_tween()
	tween.tween_property(visual, "color", color, duration / 2)
	tween.tween_property(visual, "color", original_color, duration / 2)

func update_weakness_display():
	if not weakness_label:
		return
	
	# Construire la chaîne de symboles pour les faiblesses restantes
	var remaining_weaknesses = weaknesses.slice(current_weakness_index)
	var display_text = ""
	
	for weakness_type in remaining_weaknesses:
		if WEAKNESS_SYMBOLS.has(weakness_type):
			display_text += WEAKNESS_SYMBOLS[weakness_type] + " "
	
	weakness_label.text = display_text.strip_edges()
	
	# Colorer le label selon la faiblesse actuelle
	if remaining_weaknesses.size() > 0:
		var current_weakness = remaining_weaknesses[0]
		weakness_label.modulate = WEAKNESS_COLORS[current_weakness]
	
		# Mise à jour de la couleur du ColorRect
		visual.color = WEAKNESS_COLORS[current_weakness]

func destroy():
	is_alive = false
	
	# Animation de destruction
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "modulate:a", 0.0, 0.3)
	tween.tween_property(visual, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(weakness_label, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	destroyed.emit(self)
	queue_free()

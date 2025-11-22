# Enemy.gd
extends Area2D

signal destroyed(enemy)
signal weakness_hit(enemy, remaining_weaknesses)
signal wrong_spell_used(enemy, spell_type)

# Liste des faiblesses dans l'ordre
var weaknesses : Array = ["fire"]  # Par défaut
var current_weakness_index : int = 0

@onready var visual = $ColorRect
@onready var weakness_container = $WeaknessContainer  # HBoxContainer
@onready var collision_shape = $CollisionShape2D

# Preload des textures pour chaque type de sort
const WEAKNESS_TEXTURES = {
	"fire": preload("res://assets/UI/coeursymbole.png"),
	"water": preload("res://assets/UI/carreausymbole.png"),
	"earth": preload("res://assets/UI/treflesymbole.png"),
	"air": preload("res://assets/UI/picsymbole.png")
}
# Couleurs pour les sorts
const WEAKNESS_COLORS = {
	"fire": Color(1.0, 0.3, 0.1),      # Rouge
	"water": Color(0.1, 0.5, 1.0),     # Bleu
	"earth": Color(0.2, 0.8, 0.2),     # Vert
	"air": Color(0.984, 0.936, 0.0, 1.0)        # Blanc-bleu
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
		
		# Effet visuel de succès APRÈS la mise à jour
		flash_color(WEAKNESS_COLORS[spell_type], 0.3)

func hit_wrong_spell(spell_type: String):
	# Effet visuel d'erreur (flash rouge)
	wrong_spell_used.emit(self, spell_type)
	flash_color(Color(1.0, 0.2, 0.2), 0.2)

func flash_color(color: Color, duration: float):
	var original_color = visual.color
	var tween = create_tween()
	tween.tween_property(visual, "color", color, duration / 2)
	tween.tween_property(visual, "color", original_color, duration / 2)

func update_weakness_display():
	if not weakness_container:
		return
	
	# Nettoyer les icônes existantes
	for child in weakness_container.get_children():
		child.queue_free()
	
	# Construire les icônes pour les faiblesses restantes
	var remaining_weaknesses = weaknesses.slice(current_weakness_index)
	
	for i in range(remaining_weaknesses.size()):
		var weakness_type = remaining_weaknesses[i]
		
		if WEAKNESS_TEXTURES.has(weakness_type):
			# Créer un TextureRect pour cette faiblesse
			var texture_rect = TextureRect.new()
			texture_rect.texture = WEAKNESS_TEXTURES[weakness_type]
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.custom_minimum_size = Vector2(32, 32)  # Taille des icônes
			
			# Colorer l'icône actuelle (la première)
			if i == 0:
				texture_rect.modulate = WEAKNESS_COLORS[weakness_type]
			else:
				# Les icônes suivantes sont plus transparentes
				texture_rect.modulate = Color(1, 1, 1, 0.6)
			
			weakness_container.add_child(texture_rect)
	
	# Mise à jour de la couleur du ColorRect selon la faiblesse actuelle
	if remaining_weaknesses.size() > 0:
		var current_weakness = remaining_weaknesses[0]
		visual.color = WEAKNESS_COLORS[current_weakness].darkened(0.3)

func destroy():
	is_alive = false
	spawn_hit_particles()
	# Animation de destruction
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "modulate:a", 0.0, 0.3)
	tween.tween_property(visual, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(weakness_container, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	destroyed.emit(self)
	queue_free()

func spawn_hit_particles():
	var p = $hit_particle.duplicate()
	p.emitting = true
	
	# Le parent doit être le parent de l'ennemi, pour survivre au queue_free()
	get_parent().add_child(p)
	p.global_position = global_position
	for node in get_tree().get_nodes_in_group("GM"):
		node.add_mana(10)
	# Effacer les particules après leur durée de vie
	await get_tree().create_timer(p.lifetime).timeout
	p.queue_free()

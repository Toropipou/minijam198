# Enemy.gd
extends Area2D

signal destroyed(enemy)
signal weakness_hit(enemy, remaining_weaknesses)
signal wrong_spell_used(enemy, spell_type)

# Liste des faiblesses dans l'ordre
var weaknesses : Array = ["fire"]  # Par défaut
var current_weakness_index : int = 0

@onready var weakness_container = $WeaknessContainer
@onready var collision_shape = $CollisionShape2D
@onready var perso_sprite = $Perso
@onready var couronne_sprite = $Couronne
@onready var sceptre_sprite = $Sceptre

# Preload des textures pour chaque type de sort
const WEAKNESS_TEXTURES = {
	#"Coeur": preload("res://assets/UI/coeursymbole.png"),
	#"Carreau": preload("res://assets/UI/carreausymbole.png"),
	#"Trefle": preload("res://assets/UI/treflesymbole.png"),
	#"Pique": preload("res://assets/UI/picsymbole.png")
	"Coeur": preload("res://assets/UI/bouton/b_button.png"),
	"Carreau": preload("res://assets/UI/bouton/x_button.png"),
	"Trefle": preload("res://assets/UI/bouton/a_button.png"),
	"Pique": preload("res://assets/UI/bouton/y_button.png")
}

# Couleurs pour les sorts
const WEAKNESS_COLORS = {
	"Coeur": Color(1.0, 0.3, 0.1),
	"Carreau": Color(0.1, 0.5, 1.0),
	"Trefle": Color(0.2, 0.8, 0.2),
	"Pique": Color(0.984, 0.936, 0.0, 1.0)
}

# État
var is_alive : bool = true

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	update_weakness_display()

func set_weaknesses(new_weaknesses: Array):
	weaknesses = new_weaknesses.duplicate()
	current_weakness_index = 0
	update_character_appearance()
	update_weakness_display()

func update_character_appearance():
	"""Configure les animations du personnage selon ses weaknesses"""
	if weaknesses.is_empty():
		return
	print(weaknesses)
	# Déterminer le type de personnage selon le nombre de weaknesses
	var num_weaknesses = weaknesses.size()
	var character_type = ""
	
	match num_weaknesses:
		1:
			character_type = "Valet"
		2:
			character_type = "Reine"
		3, _:  # 3 ou plus = Roi
			character_type = "Roi"
	
	# Déterminer la couleur (suit) selon la dernière weakness
	var suit = weaknesses[-1]  # Dernière faiblesse = couleur du personnage
	
	# Jouer l'animation du personnage principal
	var perso_animation = character_type + "_" + suit
	if perso_sprite.sprite_frames.has_animation(perso_animation):
		perso_sprite.play(perso_animation)
	else:
		push_warning("Animation introuvable : " + perso_animation)
	
	# Gérer la couronne (Roi et Reine seulement)
	if character_type == "Roi" or character_type == "Reine":
		# La couleur de la couronne est weakness[-2] (avant-dernière)
		if num_weaknesses >= 2:
			var couronne_suit = weaknesses[-2]
			var couronne_animation = character_type + "_Couronne_" + couronne_suit
			if couronne_sprite.sprite_frames.has_animation(couronne_animation):
				couronne_sprite.play(couronne_animation)
			else:
				couronne_sprite.play("Sans_Couronne")
		else:
			couronne_sprite.play("Sans_Couronne")
	else:
		# Valet n'a pas de couronne
		couronne_sprite.play("Sans_Couronne")
	
	# Gérer le sceptre (Roi seulement)
	if character_type == "Roi":
		# La couleur du sceptre est weakness[-3] (avant-avant-dernière)
		if num_weaknesses >= 3:
			var sceptre_suit = weaknesses[-3]
			var sceptre_animation = "Roi_Sceptre_" + sceptre_suit
			if sceptre_sprite.sprite_frames.has_animation(sceptre_animation):
				sceptre_sprite.play(sceptre_animation)
			else:
				sceptre_sprite.play("Roi_sans_sceptre")
		else:
			sceptre_sprite.play("Roi_sans_sceptre")
	else:
		# Reine et Valet n'ont pas de sceptre
		sceptre_sprite.play("Roi_sans_sceptre")
		$WeaknessContainer.position.x+=20

func _on_area_entered(area):
	if area.has_method("get_spell_type"):
		var spell_type = area.get_spell_type()
		receive_spell(spell_type)
		area.queue_free()

func receive_spell(spell_type: String):
	if not is_alive:
		return
	
	var expected_weakness = weaknesses[current_weakness_index]
	
	if spell_type == expected_weakness:
		hit_correct_weakness(spell_type)
	else:
		hit_wrong_spell(spell_type)

func hit_correct_weakness(spell_type: String):
	current_weakness_index += 1
	
	if current_weakness_index >= weaknesses.size():
		weakness_hit.emit(self, 0)
		destroy()
	else:
		var remaining = weaknesses.size() - current_weakness_index
		weakness_hit.emit(self, remaining)
		update_weakness_display()

func hit_wrong_spell(spell_type: String):
	wrong_spell_used.emit(self, spell_type)


func update_weakness_display():
	if not weakness_container:
		return
	
	for child in weakness_container.get_children():
		child.queue_free()
	
	var remaining_weaknesses = weaknesses.slice(current_weakness_index)
	
	for i in range(remaining_weaknesses.size()):
		var weakness_type = remaining_weaknesses[i]
		
		if WEAKNESS_TEXTURES.has(weakness_type):
			var texture_rect = TextureRect.new()
			texture_rect.texture = WEAKNESS_TEXTURES[weakness_type]
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.custom_minimum_size = Vector2(32, 32)
		
			weakness_container.add_child(texture_rect)
	

func destroy():
	is_alive = false
	spawn_hit_particles()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(weakness_container, "modulate:a", 0.0, 0.3)
	tween.tween_property(perso_sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(couronne_sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(sceptre_sprite, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	destroyed.emit(self)
	queue_free()

func spawn_hit_particles():
	var p = $hit_particle.duplicate()
	p.emitting = true
	
	get_parent().add_child(p)
	p.global_position = global_position
	
	for node in get_tree().get_nodes_in_group("GM"):
		node.add_mana(10)
	
	await get_tree().create_timer(p.lifetime).timeout
	p.queue_free()

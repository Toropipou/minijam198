# Enemy.gd
extends Area2D

signal destroyed(enemy)
signal weakness_hit(enemy, remaining_weaknesses)
signal wrong_spell_used(enemy, spell_type)

var top_or_bottom = "bottom"
var is_dead
var weaknesses : Array = ["fire"]
var current_weakness_index : int = 0
@onready var sprites = $sprites
@onready var weakness_container = $WeaknessContainer
@onready var collision_shape = $CollisionShape2D
@onready var perso_sprite = $sprites/Perso
@onready var couronne_sprite = $sprites/Couronne
@onready var sceptre_sprite = $sprites/Sceptre
var character_type

# Paramètres d'animation
@export var hop_height : float = 20.0
@export var hop_duration : float = 0.4
@export var hop_interval : float = 0.8
@export var squash_intensity : float = 0.2

var movement_tween : Tween
var hop_tween : Tween
var initial_y : float = 0.0
var dust_particles : CPUParticles2D

# Détection du type d'input
var using_gamepad : bool = true

# Textures CLAVIER (WASD)
const WEAKNESS_TEXTURES_KEYBOARD = {
	"Coeur": preload("res://assets/UI/bouton/d_keyboard_button.png"),
	"Carreau": preload("res://assets/UI/bouton/a_keyboard_button.png"),
	"Trefle": preload("res://assets/UI/bouton/s_keyboard_button.png"),
	"Pique": preload("res://assets/UI/bouton/w_keyboard_button.png")
	
}

# Textures MANETTE
const WEAKNESS_TEXTURES_GAMEPAD = {
	"Coeur": preload("res://assets/UI/bouton/b_button.png"),   # D
	"Carreau": preload("res://assets/UI/bouton/x_button.png"), # A
	"Trefle": preload("res://assets/UI/bouton/a_button.png"),  # S
	"Pique": preload("res://assets/UI/bouton/y_button.png")    # W
}

# Couleurs pour les sorts
const WEAKNESS_COLORS = {
	"Coeur": Color(1.0, 0.3, 0.1),
	"Carreau": Color(0.1, 0.5, 1.0),
	"Trefle": Color(0.2, 0.8, 0.2),
	"Pique": Color(0.984, 0.936, 0.0, 1.0)
}

var is_alive : bool = true
var initial_sprites_scale : Vector2 = Vector2.ONE

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	initial_sprites_scale = sprites.scale
	update_weakness_display()
	initial_y = position.y
	setup_dust_particles()
	
	if top_or_bottom == "bottom":
		start_hopping_animation()
	else:
		start_floating_animation()

func _input(event: InputEvent) -> void:
	"""Détecte le changement de type d'input et met à jour les icônes"""
	var previous_state = using_gamepad
	
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_gamepad = false
	
	# Si le type d'input a changé, mettre à jour l'affichage
	if previous_state != using_gamepad:
		update_weakness_display()

func setup_dust_particles():
	dust_particles = CPUParticles2D.new()
	add_child(dust_particles)
	
	dust_particles.emitting = false
	dust_particles.one_shot = true
	dust_particles.amount = 8
	dust_particles.lifetime = 0.6
	dust_particles.explosiveness = 1.0
	
	dust_particles.scale_amount_min = 2.0
	dust_particles.scale_amount_max = 4.0
	dust_particles.color = Color(0.8, 0.7, 0.6, 0.8)
	
	dust_particles.direction = Vector2(0, -1)
	dust_particles.spread = 45.0
	dust_particles.gravity = Vector2(0, 100)
	dust_particles.initial_velocity_min = 30.0
	dust_particles.initial_velocity_max = 60.0
	dust_particles.angular_velocity_min = -180.0
	dust_particles.angular_velocity_max = 180.0
	
	if character_type=="Roi":
		dust_particles.position = Vector2(20, 40)
	else:
		dust_particles.position = Vector2(40, +80)

func start_hopping_animation():
	if hop_tween:
		hop_tween.kill()
	
	if character_type=="Reine":
		hop_height = hop_height *1.5
	if character_type=="Veine":
		hop_height = hop_duration/2
	
	hop_tween = create_tween()
	hop_tween.set_loops()
	
	hop_tween.tween_property(
		sprites,
		"scale",
		initial_sprites_scale * Vector2(1.0 + squash_intensity, 1.0 - squash_intensity),
		hop_duration * 0.15
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	hop_tween.parallel().tween_property(
		self,
		"position:y",
		initial_y - hop_height,
		hop_duration * 0.4
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	hop_tween.parallel().tween_property(
		sprites,
		"scale",
		initial_sprites_scale * Vector2(1.0 - squash_intensity * 0.5, 1.0 + squash_intensity * 0.5),
		hop_duration * 0.2
	).set_trans(Tween.TRANS_QUAD)
	
	hop_tween.chain().tween_property(
		sprites,
		"scale",
		initial_sprites_scale,
		hop_duration * 0.2
	)
	
	hop_tween.parallel().tween_property(
		self,
		"position:y",
		initial_y,
		hop_duration * 0.4
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	hop_tween.chain().tween_callback(spawn_dust_particles)
	
	hop_tween.parallel().tween_property(
		sprites,
		"scale",
		initial_sprites_scale * Vector2(1.0 + squash_intensity * 1.2, 1.0 - squash_intensity * 1.2),
		hop_duration * 0.1
	).set_trans(Tween.TRANS_BOUNCE)
	
	hop_tween.chain().tween_property(
		sprites,
		"scale",
		initial_sprites_scale,
		hop_duration * 0.15
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	hop_tween.chain().tween_interval(hop_interval)

func start_floating_animation():
	if hop_tween:
		hop_tween.kill()
	
	hop_tween = create_tween()
	hop_tween.set_loops()
	hop_tween.set_parallel(true)
	
	hop_tween.tween_property(
		self,
		"position:y",
		initial_y - 8,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	hop_tween.chain().tween_property(
		self,
		"position:y",
		initial_y + 8,
		2.4
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	hop_tween.chain().tween_property(
		self,
		"position:y",
		initial_y - 8,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	hop_tween.tween_property(
		self,
		"rotation_degrees",
		3,
		1.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	hop_tween.chain().tween_property(
		self,
		"rotation_degrees",
		-3,
		3.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	hop_tween.chain().tween_property(
		self,
		"rotation_degrees",
		3,
		1.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func spawn_dust_particles():
	if dust_particles and top_or_bottom == "bottom":
		dust_particles.restart()

func set_weaknesses(new_weaknesses: Array):
	weaknesses = new_weaknesses.duplicate()
	current_weakness_index = 0
	update_character_appearance()
	update_weakness_display()

func update_character_appearance():
	if weaknesses.is_empty():
		return
	
	var num_weaknesses = weaknesses.size()
	character_type = ""
	
	match num_weaknesses:
		1:
			character_type = "Valet"
		2:
			character_type = "Reine"
		3, _:
			character_type = "Roi"
	
	var suit = weaknesses[-1]
	
	var perso_animation = character_type + "_" + suit
	if perso_sprite.sprite_frames.has_animation(perso_animation):
		perso_sprite.play(perso_animation)
	else:
		push_warning("Animation introuvable : " + perso_animation)
	
	if character_type == "Roi" or character_type == "Reine":
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
		couronne_sprite.play("Sans_Couronne")
	
	if character_type == "Roi":
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
		sceptre_sprite.play("Roi_sans_sceptre")
		$WeaknessContainer.position.x+=20

func update_character_appearance_from_remaining():
	var remaining_weaknesses = weaknesses.slice(current_weakness_index)
	
	if remaining_weaknesses.is_empty():
		return
	
	var num_remaining = remaining_weaknesses.size()
	
	if num_remaining >= 2 and (character_type == "Roi" or character_type == "Reine"):
		var couronne_suit = remaining_weaknesses[-2]
		var couronne_animation = character_type + "_Couronne_" + couronne_suit
		if couronne_sprite.sprite_frames.has_animation(couronne_animation):
			couronne_sprite.play(couronne_animation)
		else:
			couronne_sprite.play("Sans_Couronne")
	else:
		couronne_sprite.play("Sans_Couronne")
	
	if num_remaining >= 3 and character_type == "Roi":
		var sceptre_suit = remaining_weaknesses[-3]
		var sceptre_animation = "Roi_Sceptre_" + sceptre_suit
		if sceptre_sprite.sprite_frames.has_animation(sceptre_animation):
			sceptre_sprite.play(sceptre_animation)
		else:
			sceptre_sprite.play("Roi_sans_sceptre")
	else:
		sceptre_sprite.play("Roi_sans_sceptre")

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

func hit_correct_weakness(_spell_type: String):
	hit_bounce_animation()
	current_weakness_index += 1

	if current_weakness_index >= weaknesses.size():
		weakness_hit.emit(self, 0)
		destroy()
	else:
		var remaining = weaknesses.size() - current_weakness_index
		update_character_appearance_from_remaining()
		update_weakness_display()
		weakness_hit.emit(self, remaining)

func hit_wrong_spell(spell_type: String):
	shake_animation()
	wrong_spell_used.emit(self, spell_type)

func hit_bounce_animation():
	var bounce_tween = create_tween()
	bounce_tween.set_parallel(true)
	
	var perso_initial_scale = perso_sprite.scale
	
	bounce_tween.tween_property(perso_sprite, "scale", perso_initial_scale * Vector2(1.2, 0.8), 0.1)
	bounce_tween.chain().tween_property(perso_sprite, "scale", perso_initial_scale * Vector2(0.9, 1.1), 0.1)
	bounce_tween.chain().tween_property(perso_sprite, "scale", perso_initial_scale, 0.1)

func shake_animation():
	var shake_tween = create_tween()
	var original_pos = position
	
	for i in range(4):
		shake_tween.tween_property(self, "position:x", original_pos.x + 5, 0.05)
		shake_tween.chain().tween_property(self, "position:x", original_pos.x - 5, 0.05)
	
	shake_tween.chain().tween_property(self, "position", original_pos, 0.05)

func update_weakness_display():
	"""Met à jour l'affichage des faiblesses avec les bonnes textures selon l'input"""
	if not weakness_container:
		return
	
	for child in weakness_container.get_children():
		child.queue_free()
	
	var remaining_weaknesses = weaknesses.slice(current_weakness_index)
	if character_type=="Roi":
		weakness_container.position.x-=40
	
	# Choisir le bon dictionnaire de textures
	var texture_dict = WEAKNESS_TEXTURES_GAMEPAD if using_gamepad else WEAKNESS_TEXTURES_KEYBOARD
	
	for i in range(remaining_weaknesses.size()):
		var weakness_type = remaining_weaknesses[i]
		
		if texture_dict.has(weakness_type):
			var texture_rect = TextureRect.new()
			texture_rect.texture = texture_dict[weakness_type]
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.custom_minimum_size = Vector2(32, 32)
			
			weakness_container.add_child(texture_rect)

func destroy():
	is_alive = false
	is_dead = true
	collision_shape.set_deferred("disabled",true)
	$WeaknessContainer.visible = false
	
	if hop_tween:
		hop_tween.kill()
	
	spawn_hit_particles()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(weakness_container, "modulate:a", 0.0, 0.3)
	tween.tween_property(perso_sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(couronne_sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(sceptre_sprite, "modulate:a", 0.0, 0.3)
	
	tween.tween_property(sprites, "rotation_degrees", 360, 0.5).set_ease(Tween.EASE_IN)	
	tween.tween_property(sprites, "scale", Vector2.ZERO, 0.3).set_ease(Tween.EASE_IN)
	
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

## qte_ui.gd - Version avec anti-spam
extends Control

signal qte_success
signal qte_failed

@onready var buttons_container: HBoxContainer = $CenterContainer/HBoxContainer

var button_sequence: Array = []
var current_index: int = 0
var time_left: float = 0.0
var max_time: float = 0.0
var is_waiting: bool = false
var button_nodes: Array[TextureRect] = []

var using_gamepad := false





# Anti-spam
var can_input: bool = true
var penalty_duration: float = 0.2  # 200ms de pénalité
var is_first_input: bool = true

# Couleurs pour les états
var color_waiting = Color.WHITE
var color_success = Color.GREEN
var color_failed = Color.RED
var color_inactive = Color(0.3, 0.3, 0.3, 0.5)
var color_penalty = Color.ORANGE

# Textures des boutons
@export var texture_x: Texture2D
@export var texture_w: Texture2D
@export var texture_a: Texture2D
@export var texture_q: Texture2D
@export var texture_s: Texture2D
@export var texture_d: Texture2D
@export var texture_space: Texture2D
@export var texture_e: Texture2D
@export var texture_f: Texture2D
@export var texture_b: Texture2D
@export var texture_mouse_left: Texture2D
@export var texture_mouse_right: Texture2D
@export var texture_controller_A: Texture2D
@export var texture_controller_B: Texture2D
@export var texture_controller_Y: Texture2D
@export var texture_controller_X: Texture2D
@export var texture_controller_LT: Texture2D
@export var texture_controller_RT: Texture2D

# Nouvelles textures pour les sorts
@export var texture_spell_1: Texture2D
@export var texture_spell_2: Texture2D
@export var texture_spell_3: Texture2D
@export var texture_spell_4: Texture2D

func _ready() -> void:
	hide()

func setup(buttons: Array, duration: float) -> void:
	"""
	Configure et démarre le QTE
	buttons: ["spell_1", "spell_2", "spell_3"] ou ["x", "a", "b"]
	duration: temps total en secondes
	"""
	button_sequence = buttons.duplicate()
	max_time = duration
	time_left = duration
	current_index = 0
	is_waiting = true
	can_input = true
	is_first_input = true
	
	# Nettoyer les anciens boutons
	_clear_buttons()
	
	# Créer les boutons visuels
	_create_button_display()
	# Afficher et animer   
	show()

func _clear_buttons() -> void:
	"""Supprime tous les boutons existants"""
	for btn in button_nodes:
		btn.queue_free()
	button_nodes.clear()

func _create_button_display() -> void:
	"""Crée l'affichage des boutons en horizontal"""
	for i in range(button_sequence.size()):
		var btn_key = button_sequence[i]
		var texture_rect = TextureRect.new()
		
		# Configuration
		texture_rect.custom_minimum_size = Vector2(96, 96)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture = _get_button_texture(btn_key)
		texture_rect.pivot_offset = texture_rect.custom_minimum_size / 2
		# Couleur selon l'état
		if i == 0:
			texture_rect.modulate = color_waiting  # Premier bouton actif
		else:
			texture_rect.modulate = color_inactive  # Autres inactifs
		
		buttons_container.add_child.call_deferred(texture_rect)
		button_nodes.append(texture_rect)
	
	# Animation du bouton actif
	if button_nodes.size() > 0:
		_pulse_current_button()

func _get_button_texture(button_key: String) -> Texture2D:
	"""Retourne la texture correspondant au bouton"""
	match button_key:
		"spell_1": return texture_spell_1 if texture_spell_1 else texture_x
		"spell_2": return texture_spell_2 if texture_spell_2 else texture_a
		"spell_3": return texture_spell_3 if texture_spell_3 else texture_b
		"spell_4": return texture_spell_4 if texture_spell_4 else texture_e
		"x": return texture_x
		"a": return texture_a
		"b": return texture_b
		"space": return texture_space
		"e": return texture_e
		"f": return texture_f
		"mouse_left": return texture_mouse_left
		"mouse_right": return texture_mouse_right
		_: 
			push_warning("Texture non trouvée pour le bouton : " + button_key)
			return null

func _process(delta: float) -> void:
	if not is_waiting:
		return
	
	# Décompte du temps
	time_left -= delta
	
	# Temps écoulé = échec
	if time_left <= 0.0:
		_fail()
		
	print (using_gamepad)
		
	if using_gamepad == false:
		texture_spell_1 = texture_s
		texture_spell_2 = texture_d
		texture_spell_3= texture_w
		texture_spell_4 = texture_a
		
	if using_gamepad == true:
		texture_spell_1 = texture_controller_B
		texture_spell_2 = texture_controller_X
		texture_spell_3= texture_controller_A
		texture_spell_4 = texture_controller_Y
		
		
		pass

func _input(event: InputEvent) -> void:
		# Détection manette
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		using_gamepad = true
		print(using_gamepad)

	# Détection clavier / souris
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		using_gamepad = false
		print(using_gamepad)  
	
	if not is_waiting or current_index >= button_sequence.size():
		return
	
	# Vérifier si on peut accepter des inputs (anti-spam)
	if not can_input and not is_first_input:
		return
	
	var target = button_sequence[current_index]
	var pressed = _check_input(event, target)
	
	if pressed:
		is_first_input = false
		_on_button_pressed()
	elif _check_any_input(event):
		# Mauvais input détecté -> pénalité
		is_first_input = false
		_apply_penalty()

func _check_input(event: InputEvent, button: String) -> bool:
	"""Vérifie si l'input correspond au bouton attendu"""
	match button:
		"spell_1":
			return event.is_action_pressed("spell_1")
		"spell_2":
			return event.is_action_pressed("spell_2")
		"spell_3":
			return event.is_action_pressed("spell_3")
		"spell_4":
			return event.is_action_pressed("spell_4")
		"space":
			return event.is_action_pressed("ui_accept")
		"mouse_left":
			return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		"mouse_right":
			return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
		_:
			# Touches clavier génériques (x, a, b, e, f, etc.)
			return event is InputEventKey and event.pressed and event.keycode == OS.find_keycode_from_string(button.to_upper())

func _check_any_input(event: InputEvent) -> bool:
	"""Vérifie si un input QTE quelconque a été détecté"""
	if event is InputEventKey and event.pressed:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	# Vérifier les actions de sorts
	for spell in ["spell_1", "spell_2", "spell_3", "spell_4"]:
		if event.is_action_pressed(spell):
			return true
	return false

func _apply_penalty() -> void:
	"""Applique une pénalité pour mauvais input"""
	can_input = false
	
	# Effet visuel de pénalité sur le bouton actuel
	if current_index < button_nodes.size():
		var btn = button_nodes[current_index]
		var original_color = btn.modulate
		
		# Flash orange
		var tween = create_tween()
		tween.tween_property(btn, "modulate", color_penalty, 0.1)
		tween.tween_property(btn, "modulate", original_color, 0.1)
		
		# Shake
		var shake_tween = create_tween()
		shake_tween.tween_property(btn, "position:x", btn.position.x + 10, 0.05)
		shake_tween.tween_property(btn, "position:x", btn.position.x - 10, 0.05)
		shake_tween.tween_property(btn, "position:x", btn.position.x, 0.05)
	
	# Timer pour réactiver les inputs
	await get_tree().create_timer(penalty_duration).timeout
	can_input = true

func _on_button_pressed() -> void:
	"""Gère l'appui sur le bon bouton"""
	# Marquer le bouton comme réussi
	button_nodes[current_index].modulate = color_success
	
	# Animation de succès
	var tween = create_tween()
	tween.tween_property(button_nodes[current_index], "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(button_nodes[current_index], "scale", Vector2(1.0, 1.0), 0.1)
	
	current_index += 1
	
	# Vérifier si séquence terminée
	if current_index >= button_sequence.size():
		_success()
	else:
		# Activer le bouton suivant
		button_nodes[current_index].modulate = color_waiting
		_pulse_current_button()

func _pulse_current_button() -> void:
	"""Anime le bouton actuel"""
	if current_index < button_nodes.size():
		var btn = button_nodes[current_index]
		var tween = create_tween().set_loops()
		tween.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.5)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.5)

func _success() -> void:
	"""Séquence QTE réussie"""
	is_waiting = false
	
	# Tous les boutons en vert
	for btn in button_nodes:
		btn.modulate = color_success

	qte_success.emit()
	hide()

func _fail() -> void:
	"""Séquence QTE échouée"""
	is_waiting = false
	
	# Bouton actuel en rouge, reste en gris
	if current_index < button_nodes.size():
		button_nodes[current_index].modulate = color_failed
	
	qte_failed.emit()
	hide()

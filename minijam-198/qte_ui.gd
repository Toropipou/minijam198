## qte_ui.gd - Version avec anti-spam et changement de textures
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
var penalty_duration: float = 0.2
var is_first_input: bool = true

# Couleurs pour les états
var color_waiting = Color.WHITE
var color_success = Color.GREEN
var color_failed = Color.RED
var color_inactive = Color(0.3, 0.3, 0.3, 0.5)
var color_penalty = Color.ORANGE

# Textures des boutons clavier
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

# Textures manette
@export var texture_controller_A: Texture2D
@export var texture_controller_B: Texture2D
@export var texture_controller_Y: Texture2D
@export var texture_controller_X: Texture2D
@export var texture_controller_LT: Texture2D
@export var texture_controller_RT: Texture2D

# Mapping des sorts : clavier -> manette
# Affichage en QWERTY (W/A/S/D) mais Godot gère la conversion clavier
var spell_mapping_keyboard := {
	"spell_1": "d",
	"spell_2": "a", 
	"spell_3": "s",
	"spell_4": "w"
}

var spell_mapping_gamepad := {
	"spell_1": "controller_B",
	"spell_2": "controller_X",
	"spell_3": "controller_A", 
	"spell_4": "controller_Y"
}

func _ready() -> void:
	hide()

func setup(buttons: Array, duration: float, start_with_gamepad: bool = false) -> void:
	button_sequence = buttons.duplicate()
	max_time = duration
	time_left = duration
	current_index = 0
	is_waiting = true
	can_input = true
	is_first_input = true
	using_gamepad = start_with_gamepad  # Initialiser avec le bon état
	
	_clear_buttons()
	_create_button_display()
	show()

func _clear_buttons() -> void:
	for btn in button_nodes:
		btn.queue_free()
	button_nodes.clear()

func _create_button_display() -> void:
	for i in range(button_sequence.size()):
		var btn_key = button_sequence[i]
		var texture_rect = TextureRect.new()
		
		texture_rect.custom_minimum_size = Vector2(96, 96)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture = _get_button_texture(btn_key)
		texture_rect.pivot_offset = texture_rect.custom_minimum_size / 2
		
		if i == 0:
			texture_rect.modulate = color_waiting
		else:
			texture_rect.modulate = color_inactive
		
		buttons_container.add_child.call_deferred(texture_rect)
		button_nodes.append(texture_rect)
	
	if button_nodes.size() > 0:
		_pulse_current_button()

func _get_button_texture(button_key: String) -> Texture2D:
	"""Retourne la texture en fonction du type d'input et du bouton"""
	# Si c'est un sort, utiliser le mapping
	if button_key.begins_with("spell_"):
		if using_gamepad:
			var gamepad_key = spell_mapping_gamepad.get(button_key, "controller_A")
			return _get_texture_by_name(gamepad_key)
		else:
			var keyboard_key = spell_mapping_keyboard.get(button_key, "s")
			return _get_texture_by_name(keyboard_key)
	
	# Sinon, utiliser le nom direct
	return _get_texture_by_name(button_key)

func _get_texture_by_name(key: String) -> Texture2D:
	"""Retourne la texture correspondant au nom de touche"""
	match key:
		"x": return texture_x
		"w": return texture_w
		"a": return texture_a
		"q": return texture_q
		"s": return texture_s
		"d": return texture_d
		"b": return texture_b
		"space": return texture_space
		"e": return texture_e
		"f": return texture_f
		"mouse_left": return texture_mouse_left
		"mouse_right": return texture_mouse_right
		"controller_A": return texture_controller_A
		"controller_B": return texture_controller_B
		"controller_X": return texture_controller_X
		"controller_Y": return texture_controller_Y
		"controller_LT": return texture_controller_LT
		"controller_RT": return texture_controller_RT
		_:
			push_warning("Texture non trouvée pour : " + key)
			return null

func _update_all_button_textures() -> void:
	"""Met à jour toutes les textures selon le type d'input"""
	for i in range(button_nodes.size()):
		if i < button_sequence.size():
			var btn_key = button_sequence[i]
			button_nodes[i].texture = _get_button_texture(btn_key)

func _process(delta: float) -> void:
	if not is_waiting:
		return
	
	time_left -= delta
	
	if time_left <= 0.0:
		_fail()

func _input(event: InputEvent) -> void:
	var previous_gamepad_state = using_gamepad
	
	# Détection du type d'input
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_gamepad = false
	
	# Si le type d'input a changé, mettre à jour les textures
	if previous_gamepad_state != using_gamepad:
		_update_all_button_textures()
	
	if not is_waiting or current_index >= button_sequence.size():
		return
	
	if not can_input and not is_first_input:
		return
	
	var target = button_sequence[current_index]
	var pressed = _check_input(event, target)
	
	if pressed:
		is_first_input = false
		_on_button_pressed()
	elif _check_any_input(event):
		is_first_input = false
		_apply_penalty()

func _check_input(event: InputEvent, button: String) -> bool:
	# D'abord vérifier si c'est une action spell
	if button.begins_with("spell_"):
		return event.is_action_pressed(button)
	
	# Ensuite les autres actions
	match button:
		"space":
			return event.is_action_pressed("ui_accept")
		"mouse_left":
			return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		"mouse_right":
			return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
		_:
			# Pour les touches clavier simples (w, a, s, d, etc.)
			if event is InputEventKey and event.pressed:
				var key_string = OS.get_keycode_string(event.keycode).to_lower()
				return key_string == button.to_lower()
			return false

func _check_any_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
			# Ignorer les touches modificatrices
		var ignored_keys = [
			KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META,
			KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK
		]
		if event.keycode in ignored_keys:
			return false  # <-- Shift ne compte pas comme un input
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	for spell in ["spell_1", "spell_2", "spell_3", "spell_4"]:
		if event.is_action_pressed(spell):
			return true
	return false

func _apply_penalty() -> void:
	can_input = false
	
	if current_index < button_nodes.size():
		var btn = button_nodes[current_index]
		var original_color = btn.modulate
		
		var tween = create_tween()
		tween.tween_property(btn, "modulate", color_penalty, 0.1)
		tween.tween_property(btn, "modulate", original_color, 0.1)
		
		var shake_tween = create_tween()
		shake_tween.tween_property(btn, "position:x", btn.position.x + 10, 0.05)
		shake_tween.tween_property(btn, "position:x", btn.position.x - 10, 0.05)
		shake_tween.tween_property(btn, "position:x", btn.position.x, 0.05)
	
	await get_tree().create_timer(penalty_duration).timeout
	can_input = true

func _on_button_pressed() -> void:
	button_nodes[current_index].modulate = color_success
	
	var tween = create_tween()
	tween.tween_property(button_nodes[current_index], "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(button_nodes[current_index], "scale", Vector2(1.0, 1.0), 0.1)
	
	current_index += 1
	
	if current_index >= button_sequence.size():
		_success()
	else:
		button_nodes[current_index].modulate = color_waiting
		_pulse_current_button()

func _pulse_current_button() -> void:
	if current_index < button_nodes.size():
		var btn = button_nodes[current_index]
		var tween = create_tween().set_loops()
		tween.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.5)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.5)

func _success() -> void:
	is_waiting = false
	
	for btn in button_nodes:
		btn.modulate = color_success

	qte_success.emit()
	hide()

func _fail() -> void:
	is_waiting = false
	
	if current_index < button_nodes.size():
		button_nodes[current_index].modulate = color_failed
	
	qte_failed.emit()
	hide()

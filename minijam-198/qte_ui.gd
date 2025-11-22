## qte_ui.gd
extends Control

signal qte_success
signal qte_failed

@onready var buttons_container: HBoxContainer = $CenterContainer/HBoxContainer
#@onready var animation_player: AnimationPlayer = $AnimationPlayer

var button_sequence: Array = []
var current_index: int = 0
var time_left: float = 0.0
var max_time: float = 0.0
var is_waiting: bool = false
var button_nodes: Array[TextureRect] = []

# Couleurs pour les états
var color_waiting = Color.WHITE
var color_success = Color.GREEN
var color_failed = Color.RED
var color_inactive = Color(0.3, 0.3, 0.3, 0.5)


@export var texture_x: Texture2D
@export var texture_a: Texture2D
@export var texture_b: Texture2D
@export var texture_space: Texture2D
@export var texture_e: Texture2D
@export var texture_f: Texture2D
@export var texture_mouse_left: Texture2D
@export var texture_mouse_right: Texture2D



func _ready() -> void:
	hide()
	#setup(["x","space"],2)

func setup(buttons: Array, duration: float) -> void:
	"""
	Configure et démarre le QTE
	buttons: ["x", "a", "b"] ou ["space", "e"]
	duration: temps total en secondes
	"""
	button_sequence = buttons.duplicate()
	max_time = duration
	time_left = duration
	current_index = 0
	is_waiting = true
	
	# Nettoyer les anciens boutons
	_clear_buttons()
	
	# Créer les boutons visuels
	_create_button_display()
	
	# Afficher et animer
	show()
	#animation_player.play("appear")

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

func _input(event: InputEvent) -> void:
	if not is_waiting or current_index >= button_sequence.size():
		return
	
	var target = button_sequence[current_index]
	var pressed = _check_input(event, target)
	
	if pressed:
		_on_button_pressed()

func _check_input(event: InputEvent, button: String) -> bool:
	"""Vérifie si l'input correspond au bouton attendu"""
	match button:
		"space":
			return event.is_action_pressed("ui_accept")
		"mouse_left":
			return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		"mouse_right":
			return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
		_:
			# Touches clavier génériques (x, a, b, e, f, etc.)
			return event is InputEventKey and event.pressed and event.keycode == OS.find_keycode_from_string(button.to_upper())

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
	#animation_player.stop()
	
	# Tous les boutons en vert
	for btn in button_nodes:
		btn.modulate = color_success
	
	#animation_player.play("success")
	await get_tree().create_timer(0.4).timeout
	qte_success.emit()

func _fail() -> void:
	"""Séquence QTE échouée"""
	is_waiting = false
	#animation_player.stop()
	
	# Bouton actuel en rouge, reste en gris
	if current_index < button_nodes.size():
		button_nodes[current_index].modulate = color_failed
	
	#animation_player.play("fail")
	await get_tree().create_timer(0.4).timeout
	qte_failed.emit()

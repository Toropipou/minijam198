## qte_manager.gd
extends Node

signal qte_started
signal qte_success
signal qte_failed
signal qte_ended

@export var qte_scene: PackedScene
var current_qte: Control = null
var is_active: bool = false

# Garde en mémoire le dernier type d'input
var last_input_was_gamepad: bool = false

func _input(event: InputEvent) -> void:
	# Détecter le type d'input en continu
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		last_input_was_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		last_input_was_gamepad = false

func start_qte(buttons: Array, duration: float = 2.0) -> void:
	"""
	Démarre un QTE avec une séquence de boutons
	buttons: ["x", "a", "b"] ou ["space", "e"]
	duration: temps total en secondes pour compléter la séquence
	"""
	if is_active:
		push_warning("QTE déjà actif")
		return
	
	if not qte_scene:
		push_error("Aucune scène QTE assignée au manager")
		return
	
	# Instancier la scène QTE
	current_qte = qte_scene.instantiate()
	add_child(current_qte)
	
	# Configurer le QTE avec le type d'input actuel
	current_qte.setup(buttons, duration, last_input_was_gamepad)
	
	# Connecter les signaux
	current_qte.qte_success.connect(_on_qte_success)
	current_qte.qte_failed.connect(_on_qte_failed)
	
	is_active = true
	qte_started.emit()

func _on_qte_success() -> void:
	is_active = false
	qte_success.emit()
	_cleanup_qte()

func _on_qte_failed() -> void:
	is_active = false
	qte_failed.emit()
	_cleanup_qte()

func _cleanup_qte() -> void:
	if current_qte:
		current_qte.queue_free()
		current_qte = null
	qte_ended.emit()

func cancel_qte() -> void:
	"""Annule le QTE en cours"""
	if is_active and current_qte:
		is_active = false
		_cleanup_qte()

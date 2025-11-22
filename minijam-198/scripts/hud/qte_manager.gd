## qte_manager.gd
extends Node

signal qte_started
signal qte_success
signal qte_failed
signal qte_ended

@export var qte_scene: PackedScene

var current_qte: Control = null
var is_active: bool = false

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
	print(current_qte)
	add_child(current_qte)
	
	# Configurer le QTE
	current_qte.setup(buttons, duration)
	
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
		await get_tree().create_timer(0.5).timeout
		current_qte.queue_free()
		current_qte = null
	qte_ended.emit()

func cancel_qte() -> void:
	"""Annule le QTE en cours"""
	if is_active and current_qte:
		is_active = false
		_cleanup_qte()

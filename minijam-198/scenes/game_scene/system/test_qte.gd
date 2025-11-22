extends Node2D


@onready var qte_manager: Node = $QTE_Manager

func _ready() -> void:
	# Connecter les signaux
	qte_manager.qte_success.connect(_on_qte_success)
	qte_manager.qte_failed.connect(_on_qte_failed)
	
	# Charger la scène QTE
	qte_manager.qte_scene = preload("res://scenes/game_scene/system/QTE_UI.tscn")
	qte_manager.start_qte(["x","x"],2)



func _on_interact_button_pressed() -> void:
	# Démarre un QTE simple : X → A → B en 3 secondes
	qte_manager.start_qte(["x", "a", "b"], 3.0)

func _on_qte_success() -> void:
	print("✅ Combo réussi !")
	# Ton code ici : dégâts, points, etc.

func _on_qte_failed() -> void:
	print("❌ Combo raté !")
	# Ton code ici : pénalité, échec, etc.

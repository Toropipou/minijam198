# HUD.gd
extends CanvasLayer

@onready var score_label = $ScoreLabel
@onready var start_label = $StartLabel
@onready var mana_bar = $ManaBar
@onready var pv_label = $PVLabel  # Nouveau label pour les PV
@onready var impactframe = $impactframe

func _ready():
	# Connecter le signal du joueur
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(current_health: int, max_health: int):
	pv_label.text = "PV: " + str(current_health) + "/" + str(max_health)
	
	# Optionnel : changer la couleur si les PV sont bas
	if current_health <= max_health * 0.25:  # 25% ou moins
		pv_label.add_theme_color_override("font_color", Color.RED)
	elif current_health <= max_health * 0.5:  # 50% ou moins
		pv_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		pv_label.add_theme_color_override("font_color", Color.WHITE)

func update_score(new_score: int):
	score_label.text = "SCORE: " + str(new_score)

func show_start_message():
	start_label.show()
	start_label.text = "Appuie sur ESPACE pour commencer\n1-4: Lancer des sorts"

func hide_start_message():
	start_label.hide()
	
func update_mana(current: float, max_value: float):
	var percentage = (current / max_value) * 100.0
	# Mettre à jour ta ProgressBar ou ColorRect
	mana_bar.value = percentage

func show_speed(speed):
	$SpeedLabel.text = str(speed)

func going_fast(is_it) -> void:
	if is_it:$fastshader.visible = true
	else:$fastshader.visible=false

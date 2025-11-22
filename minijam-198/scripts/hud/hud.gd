# HUD.gd
extends CanvasLayer

@onready var score_label = $ScoreLabel
@onready var start_label = $StartLabel
@onready var mana_bar = $ManaBar
@onready var pv_label = $PVLabel
@onready var impactframe = $impactframe
@onready var roue = $Roue

# Références aux sprites de touches dans la roue
@onready var spell_1_sprite = $Roue/Spell1
@onready var spell_2_sprite = $Roue/Spell2
@onready var spell_3_sprite = $Roue/Spell3
@onready var spell_4_sprite = $Roue/Spell4

# Couleurs pour le feedback
const NORMAL_COLOR = Color(1, 1, 1, 1)  # Blanc normal
const PRESSED_COLOR = Color(2, 2, 2, 1)  # Blanc brillant (surexposé)
const PRESSED_DURATION = 0.15  # Durée de l'effet en secondes

func _ready():
	# Connecter le signal du joueur
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_player_health_changed)

func _process(_delta):
	# Détecter les inputs et afficher le feedback
	if Input.is_action_just_pressed("spell_1"):
		show_input_pressed("spell_1")
	elif Input.is_action_just_pressed("spell_2"):
		show_input_pressed("spell_2")
	elif Input.is_action_just_pressed("spell_3"):
		show_input_pressed("spell_3")
	elif Input.is_action_just_pressed("spell_4"):
		show_input_pressed("spell_4")

func show_input_pressed(spell_type: String) -> void:
	"""Affiche un feedback visuel quand une touche est pressée"""
	var sprite: Sprite2D = null
	
	# Récupérer le bon sprite selon le type de sort
	match spell_type:
		"spell_1":
			sprite = spell_1_sprite
		"spell_2":
			sprite = spell_2_sprite
		"spell_3":
			sprite = spell_3_sprite
		"spell_4":
			sprite = spell_4_sprite
	
	if not sprite:
		return
	
	# Animation de "flash" avec un tween
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Passer à la couleur pressed immédiatement
	sprite.modulate = PRESSED_COLOR
	
	# Scale punch (optionnel, pour plus d'impact)
	var original_scale = sprite.scale
	tween.tween_property(sprite, "scale", original_scale * 1.2, PRESSED_DURATION * 0.3)
	tween.tween_property(sprite, "scale", original_scale, PRESSED_DURATION * 0.7)
	
	# Retour à la couleur normale
	tween.parallel().tween_property(sprite, "modulate", NORMAL_COLOR, PRESSED_DURATION)

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
	mana_bar.value = percentage

func show_speed(speed):
	$SpeedLabel.text = str(speed)

func going_fast(is_it) -> void:
	if is_it:
		$fastshader.visible = true
	else:
		$fastshader.visible = false

func show_roue():
	$Roue.visible=true
func hide_roue():
	$Roue.visible=false

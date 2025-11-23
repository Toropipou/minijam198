extends CanvasLayer

@onready var score_label = $ScoreLabel
@onready var start_label = $StartLabel
@onready var mana_bar = $ManaBar
@onready var impactframe = $impactframe
@onready var roue = $Roue
@onready var pv_container = $PVContainer

# Références aux sprites de touches dans la roue
@onready var spell_1_sprite = $Roue/Spell1
@onready var spell_2_sprite = $Roue/Spell2
@onready var spell_3_sprite = $Roue/Spell3
@onready var spell_4_sprite = $Roue/Spell4

# Couleurs pour le feedback
const NORMAL_COLOR = Color(1, 1, 1, 1)
const PRESSED_COLOR = Color(2, 2, 2, 1)
const PRESSED_DURATION = 0.15

# Configuration des cartes de PV
var health_card_scene: PackedScene = preload("res://scenes/hud/pvcard.tscn")  # Ajustez le chemin
var health_cards: Array[TextureRect] = []
var current_displayed_health: int = 0

func _ready():
	# Connecter le signal du joueur
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_player_health_changed)
		# Initialiser les cartes avec les PV actuels
		initialize_health_cards(player.current_health, player.max_health)

func initialize_health_cards(current_health: int, max_health: int):
	"""Crée toutes les cartes de PV au démarrage"""
	# Nettoyer les cartes existantes
	for card in health_cards:
		card.queue_free()
	health_cards.clear()
	
	# Créer une carte pour chaque PV max
	for i in range(max_health):
		var card = health_card_scene.instantiate() as TextureRect
		
		# Dupliquer le material pour que chaque carte ait son propre shader
		if card.material:
			card.material = card.material.duplicate()
			# Réinitialiser le threshold à 0 (visible)
			card.material.set_shader_parameter("dissolve_value", 1.0)
		
		pv_container.add_child(card)
		health_cards.append(card)
	
	current_displayed_health = max_health
	
	# Si le joueur a déjà perdu des PV, les masquer immédiatement
	if current_health < max_health:
		for i in range(current_health, max_health):
			if i < health_cards.size() and health_cards[i].material:
				health_cards[i].material.set_shader_parameter("dissolve_value", 0.0)
		current_displayed_health = current_health

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
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	sprite.modulate = PRESSED_COLOR
	
	var original_scale = sprite.scale
	tween.tween_property(sprite, "scale", original_scale * 1.2, PRESSED_DURATION * 0.3)
	tween.tween_property(sprite, "scale", original_scale, PRESSED_DURATION * 0.7)
	tween.parallel().tween_property(sprite, "modulate", NORMAL_COLOR, PRESSED_DURATION)

func _on_player_health_changed(current_health: int, max_health: int):
		
	# Gérer l'animation des cartes
	if current_health < current_displayed_health:
		# Le joueur a perdu des PV - faire disparaître des cartes
		for i in range(current_health, current_displayed_health):
			if i < health_cards.size():
				animate_card_disappear(health_cards[i])
		current_displayed_health = current_health
	elif current_health > current_displayed_health:
		# Le joueur a gagné des PV - faire réapparaître des cartes
		for i in range(current_displayed_health, current_health):
			if i < health_cards.size():
				animate_card_appear(health_cards[i])
		current_displayed_health = current_health

func animate_card_disappear(card: TextureRect):
	"""Anime la disparition d'une carte via le shader"""
	if not card or not card.material:
		return
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Animer le paramètre threshold du shader de 0 à 1
	# Plus le threshold est élevé, plus la carte disparaît
	tween.tween_method(
		func(value): card.material.set_shader_parameter("dissolve_value", value),
		1.0,
		0.0,
		1.5  # Durée de l'animation en secondes
	)
	

func animate_card_appear(card: TextureRect):
	"""Anime l'apparition d'une carte via le shader (healing)"""
	if not card or not card.material:
		return
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Animer le paramètre threshold du shader de 1 à 0
	tween.tween_method(
		func(value): card.material.set_shader_parameter("threshold", value),
		0.0,
		1.0,
		1.5
	)
	

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

func show_diff(diff):
	$difflabel.text = str(diff)

func show_perf(perf):
	$perflabel.text = str(perf)

func going_fast(is_it) -> void:
	if is_it:
		$fastshader.visible = true
	else:
		$fastshader.visible = false

func show_roue():
	if true: return
	$Roue.visible = true

func hide_roue():
	if true: return
	$Roue.visible = false

extends CanvasLayer
var tutorial_message_label: Label
var highlighted_elements: Array = []

@onready var score_label = $ScoreLabel
@onready var start_label = $StartLabel
@onready var mana_bar = $ManaBarC
@onready var impactframe = $impactframe
@onready var roue = $Roue
@onready var pv_container = $PVContainer

# Références aux sprites de touches dans la roue
@onready var spell_1_sprite = $Roue/Spell1
@onready var spell_2_sprite = $Roue/Spell2
@onready var spell_3_sprite = $Roue/Spell3
@onready var spell_4_sprite = $Roue/Spell4

# Variables pour le score fancy
var current_score: int = 0
var displayed_score: int = 0
var score_tween: Tween
var high_score_beaten: bool = false
var high_score_particles: CPUParticles2D

# Couleurs pour le feedback
const NORMAL_COLOR = Color(1, 1, 1, 1)
const PRESSED_COLOR = Color(2, 2, 2, 1)
const PRESSED_DURATION = 0.15

# Configuration des cartes de PV
var health_card_scene: PackedScene = preload("res://scenes/hud/pvcard.tscn")
var health_cards: Array[TextureRect] = []
var current_displayed_health: int = 0

func _ready():
	# Connecter le signal du joueur
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_player_health_changed)
		initialize_health_cards(player.current_health, player.max_health)
	
	_create_tutorial_ui()
	_setup_fancy_score()
	
func _setup_fancy_score():
	"""Configure le score fancy avec des effets"""
	# Augmenter la taille de police
	score_label.add_theme_font_size_override("font_size", 64)
	
	# Créer des particules pour le high score
	high_score_particles = CPUParticles2D.new()
	high_score_particles.position = score_label.position + Vector2(score_label.size.x / 2, score_label.size.y / 2)
	high_score_particles.emitting = false
	high_score_particles.amount = 50
	high_score_particles.lifetime = 2.0
	high_score_particles.one_shot = true
	high_score_particles.explosiveness = 0.8
	high_score_particles.direction = Vector2(0, -1)
	high_score_particles.spread = 180
	high_score_particles.gravity = Vector2(0, 200)
	high_score_particles.initial_velocity_min = 150.0
	high_score_particles.initial_velocity_max = 300.0
	high_score_particles.scale_amount_min = 2.0
	high_score_particles.scale_amount_max = 4.0
	high_score_particles.color = Color(1, 0.8, 0, 1)
	add_child(high_score_particles)

func _process(_delta):
	# Animation du compteur de score
	if displayed_score != current_score:
		var diff = current_score - displayed_score
		var increment = max(1, abs(diff) / 10)
		if diff > 0:
			displayed_score = min(displayed_score + increment, current_score)
		else:
			displayed_score = max(displayed_score - increment, current_score)
		
		_update_score_display()
	
	# Détecter les inputs et afficher le feedback
	if Input.is_action_just_pressed("spell_1"):
		show_input_pressed("spell_1")
	elif Input.is_action_just_pressed("spell_2"):
		show_input_pressed("spell_2")
	elif Input.is_action_just_pressed("spell_3"):
		show_input_pressed("spell_3")
	elif Input.is_action_just_pressed("spell_4"):
		show_input_pressed("spell_4")

func update_score(new_score: int):
	var old_score = current_score
	current_score = new_score
	
	# Vérifier si on bat le high score
	if not high_score_beaten and current_score > Datagame.high_score:
		_trigger_high_score_effect()
		high_score_beaten = true
	
	# Animation de pulsation proportionnelle au gain
	var score_gain = new_score - old_score
	if score_gain > 0:
		_animate_score_gain(score_gain)

func _update_score_display():
	"""Met à jour l'affichage du score avec des couleurs"""
	if high_score_beaten:
		# Mode high score battu - arc-en-ciel
		var hue = fmod(Time.get_ticks_msec() / 1000.0, 1.0)
		score_label.modulate = Color.from_hsv(hue, 0.8, 1.0)
		score_label.text = "★ RECORD: " + str(displayed_score) + " ★"
	elif current_score > Datagame.high_score * 0.8:
		# Proche du high score - orange
		score_label.modulate = Color(1, 0.6, 0, 1)
		score_label.text = "SCORE: " + str(displayed_score)
	else:
		# Score normal
		score_label.modulate = Color(1, 1, 1, 1)
		score_label.text = "SCORE: " + str(displayed_score)

func _animate_score_gain(gain: int):
	"""Anime le score en fonction du gain"""
	# Annuler l'animation précédente
	if score_tween and score_tween.is_valid():
		score_tween.kill()
	
	score_tween = create_tween()
	score_tween.set_parallel(true)
	score_tween.set_ease(Tween.EASE_OUT)
	score_tween.set_trans(Tween.TRANS_ELASTIC)
	
	var original_scale = Vector2.ONE
	var scale_multiplier = 1.0 + min(gain / 1000.0, 0.5)  # Max 1.5x
	
	# Animation de scale
	score_label.scale = original_scale
	score_tween.tween_property(score_label, "scale", original_scale * scale_multiplier, 0.3)
	score_tween.chain().tween_property(score_label, "scale", original_scale, 0.4)
	
	# Flash de couleur pour gros gains
	if gain > 100:
		var flash_color = Color(2, 2, 1, 1)
		score_tween.tween_property(score_label, "modulate", flash_color, 0.1)
		score_tween.chain().tween_property(score_label, "modulate", Color.WHITE, 0.3)

func _trigger_high_score_effect():
	"""Effet spectaculaire quand on bat le high score"""
	# Particules d'explosion
	high_score_particles.position = score_label.global_position + Vector2(score_label.size.x / 2, 0)
	high_score_particles.emitting = true
	
	# Animation de célébration
	var celebration_tween = create_tween()
	celebration_tween.set_ease(Tween.EASE_OUT)
	celebration_tween.set_trans(Tween.TRANS_BACK)
	
	# Gros zoom
	score_label.scale = Vector2.ONE
	celebration_tween.tween_property(score_label, "scale", Vector2.ONE * 2.0, 0.5)
	celebration_tween.tween_property(score_label, "scale", Vector2.ONE * 1.2, 0.3)
	
	# Rotation subtile
	celebration_tween.parallel().tween_property(score_label, "rotation", deg_to_rad(5), 0.4)
	celebration_tween.tween_property(score_label, "rotation", deg_to_rad(-5), 0.4)
	celebration_tween.tween_property(score_label, "rotation", 0, 0.4)
	
	# Message de félicitations
	show_tutorial_message("🎉 NEW HIGH SCORE! 🎉")
	await get_tree().create_timer(3.0).timeout
	hide_tutorial_message()

func _create_tutorial_ui():
	"""Crée l'UI pour le tutoriel"""
	tutorial_message_label = Label.new()
	tutorial_message_label.add_theme_font_size_override("font_size", 48)
	tutorial_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_message_label.set_anchors_preset(Control.PRESET_CENTER)
	tutorial_message_label.offset_top = -600
	tutorial_message_label.offset_bottom = -400
	tutorial_message_label.offset_left = -1200
	tutorial_message_label.offset_right = 500
	tutorial_message_label.modulate = Color(1, 1, 0.5, 1)
	tutorial_message_label.visible = false
	tutorial_message_label.z_index = 200
	add_child(tutorial_message_label)

func show_tutorial_message(text: String):
	"""Affiche un message de tutoriel"""
	tutorial_message_label.text = text
	tutorial_message_label.visible = true
	tutorial_message_label.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(tutorial_message_label, "modulate:a", 1.0, 0.3)

func hide_tutorial_message():
	"""Cache le message de tutoriel"""
	var tween = create_tween()
	tween.tween_property(tutorial_message_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): tutorial_message_label.visible = false)

func show_tutorial_error(text: String):
	"""Affiche une erreur tutoriel en rouge"""
	tutorial_message_label.text = text
	tutorial_message_label.modulate = Color(1, 0.3, 0.3, 1)
	tutorial_message_label.visible = true
	
	await get_tree().create_timer(2.0).timeout
	tutorial_message_label.modulate = Color(1, 1, 0.5, 1)

func highlight_spell_for_weakness(weakness: String):
	"""Met en surbrillance le sort correspondant à une faiblesse"""
	var spell_sprite: Sprite2D = null
	
	match weakness:
		"Coeur":
			spell_sprite = spell_1_sprite
		"Carreau":
			spell_sprite = spell_2_sprite
		"Trefle":
			spell_sprite = spell_3_sprite
		"Pique":
			spell_sprite = spell_4_sprite
	
	if not spell_sprite:
		return
	
	_create_pulse_effect(spell_sprite)

func highlight_triggers():
	"""Met en surbrillance les gâchettes"""
	show_tutorial_message("Hold any trigger button (LT,RT,LB,RB) or Shift to reload !")

func highlight_score():
	"""Met en surbrillance le score"""
	_create_pulse_effect(score_label)

func _create_pulse_effect(node: Node):
	"""Crée un effet de pulsation sur un nœud"""
	if node in highlighted_elements:
		return
	
	highlighted_elements.append(node)
	
	var tween = create_tween()
	tween.set_loops()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	var original_scale = node.scale
	var original_modulate = node.modulate
	
	tween.tween_property(node, "scale", original_scale * 1.3, 0.6)
	tween.parallel().tween_property(node, "modulate", Color(2, 2, 1, 1), 0.6)
	tween.tween_property(node, "scale", original_scale, 0.6)
	tween.parallel().tween_property(node, "modulate", original_modulate, 0.6)
	
	node.set_meta("tutorial_tween", tween)

func clear_all_highlights():
	"""Enlève tous les highlights"""
	for node in highlighted_elements:
		if is_instance_valid(node):
			var tween = node.get_meta("tutorial_tween", null)
			if tween:
				tween.kill()
			
			var reset_tween = create_tween()
			reset_tween.set_parallel(true)
			reset_tween.tween_property(node, "scale", Vector2.ONE, 0.3)
			reset_tween.tween_property(node, "modulate", Color.WHITE, 0.3)
	
	highlighted_elements.clear()
	
func initialize_health_cards(current_health: int, max_health: int):
	"""Crée toutes les cartes de PV au démarrage"""
	for card in health_cards:
		card.queue_free()
	health_cards.clear()
	
	for i in range(max_health):
		var card = health_card_scene.instantiate() as TextureRect
		
		if card.material:
			card.material = card.material.duplicate()
			card.material.set_shader_parameter("dissolve_value", 1.0)
		
		pv_container.add_child(card)
		health_cards.append(card)
	
	current_displayed_health = max_health
	
	if current_health < max_health:
		for i in range(current_health, max_health):
			if i < health_cards.size() and health_cards[i].material:
				health_cards[i].material.set_shader_parameter("dissolve_value", 0.0)
		current_displayed_health = current_health

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
	if current_health < current_displayed_health:
		for i in range(current_health, current_displayed_health):
			if i < health_cards.size():
				animate_card_disappear(health_cards[i])
		current_displayed_health = current_health
	elif current_health > current_displayed_health:
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
	
	tween.tween_method(
		func(value): card.material.set_shader_parameter("dissolve_value", value),
		1.0,
		0.0,
		1.5
	)

func animate_card_appear(card: TextureRect):
	"""Anime l'apparition d'une carte via le shader (healing)"""
	if not card or not card.material:
		return
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_method(
		func(value): card.material.set_shader_parameter("threshold", value),
		0.0,
		1.0,
		1.5
	)

func show_start_message():
	start_label.show()
	start_label.text = "Appuie sur ESPACE pour commencer\n1-4: Lancer des sorts"

func hide_start_message():
	start_label.hide()
	
func update_mana(current: float, max_value: float):
	var percentage = (current / max_value) * 100.0
	#mana_bar.value = percentage
	mana_bar.material.set_shader_parameter("discrete_fill_amount",round(percentage/10))

func show_speed(speed):
	$SpeedLabel.text = str(speed)

func show_diff(diff):
	$difflabel.text = str(diff)

func show_perf(perf):
	$perflabel.text = str(perf)

func going_fast(is_it: bool, speed: float = 50.0) -> void:
	if is_it:
		$fastshader.visible = true
		var s: float = clamp(speed, 500.0, 1500.0)
		var ratio: float = (s - 200.0) / (1500.0 - 200.0)
		var shader_speed: float = lerp(0.02, 0.07, ratio)
		$fastshader.material.set_shader_parameter("speed", shader_speed)
	else:
		$fastshader.visible = false

func going_fast2(is_it) -> void:
	if is_it:
		$speed2.visible = true
	else:
		$speed2.visible = false

func show_roue():
	if true: return
	$Roue.visible = true

func hide_roue():
	if true: return
	$Roue.visible = false

# ScreenShakeManager.gd - À ajouter à ton GameManager
extends Node

@export var enabled: bool = true  # Pour désactiver le shake si besoin

var camera: Camera2D
var original_position: Vector2
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var decay_rate: float = 0.0
var shake_frequency: float = 0.0
var shake_time: float = 0.0

# Ajoute ces variables en haut du script
var ui_layer: CanvasLayer
var original_ui_offset: Vector2
var ui_shake_intensity: float = 0.0
var ui_shake_timer: float = 0.0
var ui_shake_duration: float = 0.0
var ui_shake_frequency: float = 0.0
var ui_shake_time: float = 0.0

# Variables pour le zoom
var original_zoom = Vector2(1,1)
var is_zooming: bool = false
var zoom_tween: Tween

# Patterns de shake prédéfinis
enum ShakeType {
	IMPACT,        # Court et intense
	EXPLOSION,     # Long et puissant
	EARTHQUAKE,    # Très long, intensité variable
	DAMAGE,        # Court et moyen
	LANDING,       # Très court
	RUMBLE         # Continu et faible
}

func _ready():
	# Trouve automatiquement la caméra
	_find_camera()
	_find_ui_layer()

func _find_ui_layer():
	# Cherche le CanvasLayer UI
	ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if ui_layer:
		original_ui_offset = ui_layer.offset

func _find_camera():
	# Cherche la caméra dans la scène
	camera = get_tree().get_first_node_in_group("camera")
	if not camera:
		# Fallback : cherche par type
		var cameras = get_tree().get_nodes_in_group("camera")
		if cameras.size() > 0:
			camera = cameras[0]
	
	if camera:
		original_position = camera.offset

func _process(delta):
	if not enabled or not camera or shake_timer <= 0.0:
		return
	
	shake_timer -= delta
	shake_time += delta
	
	# Calcul de l'intensité avec decay
	var current_intensity = shake_intensity * (shake_timer / shake_duration)
	current_intensity *= decay_rate
	
	# Génère le shake avec du bruit
	var shake_offset = Vector2(
		sin(shake_time * shake_frequency) * current_intensity,
		cos(shake_time * shake_frequency * 1.3) * current_intensity
	)
	
	# Ajoute du bruit aléatoire pour plus de naturel
	shake_offset += Vector2(
		randf_range(-current_intensity * 0.3, current_intensity * 0.3),
		randf_range(-current_intensity * 0.3, current_intensity * 0.3)
	)
	
	camera.offset = original_position + shake_offset
	
	# Arrêt du shake
	if shake_timer <= 0.0:
		_stop_shake()

	# ========== SHAKE UI (NOUVEAU) ==========
	if enabled and ui_layer and ui_shake_timer > 0.0:
		ui_shake_timer -= delta
		ui_shake_time += delta
		
		var current_intensity_ui = ui_shake_intensity * (ui_shake_timer / ui_shake_duration)
		
		var shake_offset_ui = Vector2(
			sin(ui_shake_time * ui_shake_frequency) * current_intensity_ui,
			cos(ui_shake_time * ui_shake_frequency * 1.3) * current_intensity_ui
		)
		
		shake_offset_ui += Vector2(
			randf_range(-current_intensity_ui * 0.3, current_intensity_ui * 0.3),
			randf_range(-current_intensity_ui * 0.3, current_intensity_ui * 0.3)
		)
		
		ui_layer.offset = original_ui_offset + shake_offset_ui
		
		if ui_shake_timer <= 0.0:
			_stop_ui_shake()

# Shake UI avec presets
func shake_ui_preset(type: ShakeType):
	match type:
		ShakeType.IMPACT:
			shake_ui(8.0, 0.3, 25.0)
		ShakeType.DAMAGE:
			shake_ui(5.0, 0.4, 30.0)
		ShakeType.LANDING:
			shake_ui(6.0, 0.15, 35.0)
		_:
			shake_ui(5.0, 0.3, 20.0)

# Shake les deux en même temps
func shake_all(type: ShakeType):
	shake_preset(type)
	shake_ui_preset(type)  # UI shake moins fort

func _stop_ui_shake():
	ui_shake_timer = 0.0
	ui_shake_intensity = 0.0
	if ui_layer:
		ui_layer.offset = original_ui_offset


func shake_ui(intensity: float, duration: float, frequency: float = 20.0):
	if not enabled or not ui_layer:
		return
	
	ui_shake_intensity = intensity
	ui_shake_duration = duration
	ui_shake_timer = duration
	ui_shake_frequency = frequency
	ui_shake_time = 0.0

# Fonction principale pour déclencher un shake
func shake(intensity: float, duration: float, frequency: float = 20.0, decay: float = 1.0):
	if not enabled or not camera:
		return
	
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = duration
	shake_frequency = frequency
	decay_rate = decay
	shake_time = 0.0

# Shake avec type prédéfini
func shake_preset(type: ShakeType):
	match type:
		ShakeType.IMPACT:
			shake(15.0, 0.3, 25.0, 0.8)
		ShakeType.EXPLOSION:
			shake(25.0, 0.8, 15.0, 0.9)
		ShakeType.EARTHQUAKE:
			shake(12.0, 2.0, 8.0, 0.95)
		ShakeType.DAMAGE:
			shake(8.0, 0.4, 30.0, 0.7)
		ShakeType.LANDING:
			shake(10.0, 0.15, 35.0, 0.6)
		ShakeType.RUMBLE:
			shake(5.0, 1.5, 12.0, 1.0)

# Shake custom avec tous les paramètres
func shake_custom(intensity: float, duration: float, frequency: float = 20.0, 
				 decay: float = 1.0, fade_in: bool = false):
	shake(intensity, duration, frequency, decay)
	
	if fade_in:
		# Démarre faible et monte en intensité
		var tween = create_tween()
		tween.tween_method(_set_intensity_multiplier, 0.1, 1.0, 0.2)

# Arrête le shake immédiatement
func stop_shake():
	stop_all()

# Shake additionnel (pour empiler les effets)
func add_shake(intensity: float, duration: float, frequency: float = 20.0):
	if shake_timer > 0.0:
		# Mélange avec le shake existant
		shake_intensity = max(shake_intensity, intensity)
		shake_timer = max(shake_timer, duration)
		shake_frequency = (shake_frequency + frequency) / 2.0
	else:
		shake(intensity, duration, frequency)

# Shake directionnel (dans une direction spécifique)
func shake_directional(_direction: Vector2, _intensity: float, duration: float):
	if not enabled or not camera:
		return
	
	var tween = create_tween()
	
	tween.tween_method(_apply_directional_shake, 0.0, 1.0, duration)
	tween.tween_callback(_stop_shake)

func _apply_directional_shake(progress: float):
	var fade = 1.0 - progress  # Diminue avec le temps
	var shake_offset = Vector2(
		sin(Time.get_time_dict_from_system()["second"] * 25.0) * fade * shake_intensity,
		cos(Time.get_time_dict_from_system()["second"] * 25.0) * fade * shake_intensity
	)
	camera.offset = original_position + shake_offset

func _set_intensity_multiplier(multiplier: float):
	shake_intensity *= multiplier

func _stop_shake():
	shake_timer = 0.0
	shake_intensity = 0.0
	if camera:
		camera.offset = original_position

# Fonctions utilitaires pour les événements courants
func shake_hit():
	shake_preset(ShakeType.DAMAGE)
	shake_ui_preset(ShakeType.DAMAGE)

func shake_explosion():
	shake_preset(ShakeType.EXPLOSION)
	shake_ui_preset(ShakeType.DAMAGE)

func shake_jump_land():
	shake_preset(ShakeType.LANDING)
	shake_ui_preset(ShakeType.DAMAGE)

func shake_boss_slam():
	shake(20.0, 0.6, 18.0, 0.85)
	shake_ui(5.0, 0.6, 18.0)

# Getter pour savoir si un shake est actif
func is_shaking() -> bool:
	return shake_timer > 0.0
	

# ==================== NOUVELLES FONCTIONS DE ZOOM ====================

# Zoom rapide pour warning/danger - zoom in puis retour
func warning_zoom(zoom_factor: float = 0.8, duration: float = 0.8):
	if not camera or is_zooming:
		return
	
	is_zooming = true
	
	if zoom_tween:
		zoom_tween.kill()
	
	zoom_tween = create_tween()
	
	# Calcul du zoom target avec lerp (limite entre original_zoom et zoom_factor)
	var target_zoom = Vector2(
		lerp(original_zoom.x, zoom_factor, 1.0),
		lerp(original_zoom.y, zoom_factor, 1.0)
	)
	
	# Zoom in pendant toute la durée puis retour instantané
	zoom_tween.tween_property(camera, "zoom", target_zoom, duration)
	zoom_tween.tween_property(camera, "zoom", original_zoom, 0.0)
	
	zoom_tween.finished.connect(_on_zoom_finished)

# Zoom dramatique pour boss/événement important - zoom out puis retour
func dramatic_zoom(zoom_factor: float = 0.6, duration: float = 1.2):
	if not camera or is_zooming:
		return
	
	is_zooming = true
	
	if zoom_tween:
		zoom_tween.kill()
	
	zoom_tween = create_tween()
	zoom_tween.set_ease(Tween.EASE_IN_OUT)
	zoom_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Calcul du zoom target avec lerp
	var target_zoom = Vector2(
		lerp(original_zoom.x, zoom_factor, 1.0),
		lerp(original_zoom.y, zoom_factor, 1.0)
	)
	
	# Zoom out pendant toute la durée puis retour instantané
	zoom_tween.tween_property(camera, "zoom", target_zoom, duration)
	zoom_tween.tween_property(camera, "zoom", original_zoom, 0.0)
	
	zoom_tween.finished.connect(_on_zoom_finished)

# Fonction pour arrêter le zoom et remettre à la normale
func stop_zoom():
	if zoom_tween:
		zoom_tween.kill()
	if camera:
		camera.zoom = original_zoom
	is_zooming = false

func _on_zoom_finished():
	is_zooming = false
	if camera:
		camera.zoom = original_zoom

# Fonctions pratiques combinées shake + zoom pour tes warnings
func warning_shake_zoom():
	shake_preset(ShakeType.DAMAGE)
	warning_zoom(0.7, 0.6)

func boss_warning():
	shake_preset(ShakeType.RUMBLE)
	dramatic_zoom(0.5, 1.0)
	
func stop_all():
	stop_shake()
	_stop_ui_shake()

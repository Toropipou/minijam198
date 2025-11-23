# Ajoutez ce script à un nœud AutoLoad dans votre projet
# Project Settings > AutoLoad > Ajouter ce script
# IMPORTANT: Dans Project Settings > Input Map, 
# créez vos actions en utilisant les INDICES de boutons (0, 1, 2, 3...)
# au lieu des constantes JOY_BUTTON_A, JOY_BUTTON_B, etc.

extends Node

# Table de remappage : bouton Godot -> bouton navigateur
var button_remap = {
	JOY_BUTTON_B: 0,  # B -> Position 0 du navigateur
	JOY_BUTTON_X: 1,  # X -> Position 1 du navigateur
	JOY_BUTTON_A: 2,  # A -> Position 2 du navigateur
	JOY_BUTTON_Y: 3,  # Y -> Position 3
	JOY_BUTTON_LEFT_SHOULDER: 4,
	JOY_BUTTON_RIGHT_SHOULDER: 5,
	JOY_BUTTON_BACK: 8,
	JOY_BUTTON_START: 9,
	JOY_BUTTON_LEFT_STICK: 10,
	JOY_BUTTON_RIGHT_STICK: 11,
	JOY_BUTTON_DPAD_UP: 12,
	JOY_BUTTON_DPAD_DOWN: 13,
	JOY_BUTTON_DPAD_LEFT: 14,
	JOY_BUTTON_DPAD_RIGHT: 15
}

# Table inverse pour vérifier les inputs
var inverse_remap = {}

func _ready():
	if OS.has_feature("web"):
		print("Mode Web détecté - Configuration manette navigateur")
		# Créer la table inverse
		for godot_btn in button_remap:
			inverse_remap[button_remap[godot_btn]] = godot_btn

# Alternative : utilisez cette fonction pour vérifier les inputs dans votre code de jeu
# Au lieu de Input.is_action_pressed("jump"), utilisez :
# GamepadMapper.is_button_pressed(0, JOY_BUTTON_A)
func is_button_pressed(device: int, button: int) -> bool:
	if not OS.has_feature("web"):
		return Input.is_joy_button_pressed(device, button)
	
	# Sur web, vérifier le bouton remappé
	var web_button = button_remap.get(button, button)
	return Input.is_joy_button_pressed(device, web_button)

func is_button_just_pressed(device: int, button: int) -> bool:
	if not OS.has_feature("web"):
		return Input.is_action_just_pressed("joy_" + str(button))
	
	var web_button = button_remap.get(button, button)
	# Vérifier directement l'index du bouton
	return Input.is_joy_button_pressed(device, web_button)

# Si vous utilisez Input Map, utilisez cette méthode alternative
# Créez vos actions avec les BONS indices dans Input Map:
# action "jump" = Joypad Button 2 (au lieu de JOY_BUTTON_A)
# action "shoot" = Joypad Button 0 (au lieu de JOY_BUTTON_B)
# etc.

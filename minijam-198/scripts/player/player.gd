# Player.gd
extends CharacterBody2D

@onready var sprite = $ColorRect
@onready var game_manager = get_parent().get_parent().get_parent()
@onready var spell_projectile_scene = preload("res://scenes/entity/spell_projectile.tscn")
# Mapping des touches aux sorts
const SPELL_KEYS = {
	"spell_1": "fire",    # Par exemple touche 1 ou Z
	"spell_2": "water",   # Touche 2 ou X
	"spell_3": "earth",   # Touche 3 ou C
	"spell_4": "air"      # Touche 4 ou V
}

func _process(_delta: float) -> void:	
	# Détecter les inputs de sorts
	for action in SPELL_KEYS.keys():
		if Input.is_action_just_pressed(action):
			var spell_type = SPELL_KEYS[action]
			print(spell_type)
			game_manager.cast_spell(spell_type)

			break

func play_cast_animation(spell_type: String):
	# Jouer une animation de cast selon le type de sort
	#sprite.play("cast_" + spell_type)
	
	
	# Tu peux aussi instancier un effet visuel du sort ici
	spawn_spell_effect(spell_type)

func spawn_spell_effect(spell_type: String):
	var projectile = spell_projectile_scene.instantiate()
	projectile.position = position + Vector2(50, 0)
	projectile.spell_type = spell_type
	get_parent().add_child(projectile)
	pass

# HUD.gd
extends CanvasLayer

@onready var score_label = $ScoreLabel
@onready var start_label = $StartLabel

# Indicateurs de cooldown pour chaque sort
@onready var cooldown_indicators = {
	"fire": $SpellCooldowns/FireCooldown,
	"water": $SpellCooldowns/WaterCooldown,
	"earth": $SpellCooldowns/EarthCooldown,
	"air": $SpellCooldowns/AirCooldown
}


func update_score(new_score: int):
	score_label.text = "SCORE: " + str(new_score)

func show_start_message():
	start_label.show()
	start_label.text = "Appuie sur ESPACE pour commencer\n1-4: Lancer des sorts"

func hide_start_message():
	start_label.hide()

func update_cooldown(spell_type: String, progress: float):
	# progress va de 1.0 (plein cooldown) à 0.0 (prêt)
	if cooldown_indicators.has(spell_type):
		var indicator = cooldown_indicators[spell_type]
		
		# Si c'est une ProgressBar
		if indicator is ProgressBar:
			indicator.value = (1.0 - progress) * 100
		
		# Si c'est un ColorRect pour un effet de remplissage
		elif indicator is ColorRect:
			indicator.modulate.a = 0.5 if progress > 0 else 1.0

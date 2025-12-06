extends Node
class_name SkyManager

@export var world_env: WorldEnvironment

const NIGHT_FRAC := 1.0 / 3.0

@export var night_color: Color = Color(0.02, 0.02, 0.08)
@export var day_color: Color   = Color(0.4, 0.7, 1.0)

@export var night_ambient_energy: float = 0.2
@export var day_ambient_energy: float   = 1.0


func _process(_delta: float) -> void:
	if world_env == null or world_env.environment == null:
		return

	var env := world_env.environment
	var p: float = TimeManager.get_day_progress()   # 0..1

	var color: Color
	var energy: float

	if p < NIGHT_FRAC:
		# NOITE → AMANHECER – 0% até 33% do círculo
		var t := p / NIGHT_FRAC
		color = night_color.lerp(day_color, t)
		energy = lerp(night_ambient_energy, day_ambient_energy, t)
	else:
		# DIA → ENTARDECER → NOITE – 33% até 100% do círculo
		var t := (p - NIGHT_FRAC) / (1.0 - NIGHT_FRAC)
		color = day_color.lerp(night_color, t)
		energy = lerp(day_ambient_energy, night_ambient_energy, t)

	env.ambient_light_color = color
	env.ambient_light_energy = energy

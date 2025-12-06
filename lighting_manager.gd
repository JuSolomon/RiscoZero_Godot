extends Node
class_name LightingManager

# arrasta o Sol aqui ou deixe nulo pra ele tentar achar "../Sol"
@export var sun: DirectionalLight3D

# fração do dia que é “noite” (incluindo amanhecer)
const NIGHT_FRAC := 1.0 / 3.0   # ≈ 0.333

@export var night_energy: float = 0.1
@export var day_energy: float   = 1.0


func _ready() -> void:
	if sun == null:
		sun = get_node_or_null("../Sol") as DirectionalLight3D
	if sun == null:
		push_error("LightingManager: nó 'Sol' não encontrado.")


func _process(_delta: float) -> void:
	if sun == null:
		return

	# p = 0.0 .. 1.0 – É O MESMO VALOR QUE VOCÊ USA NO DayCycle
	var p: float = TimeManager.get_day_progress()

	# Sol dá uma volta contínua: de -90º até 270º ao longo do dia
	var angle: float = lerp(-90.0, 270.0, p)
	sun.rotation_degrees.x = angle

	var energy: float

	if p < NIGHT_FRAC:
		# NOITE → AMANHECER (0% até 33% do círculo)
		# p == 0   -> energia baixa
		# p == 1/3 -> energia máxima (começa o “dia”)
		var t := p / NIGHT_FRAC              # 0..1
		energy = lerp(night_energy, day_energy, t)
	else:
		# DIA → ENTARDECER → VOLTA PRA NOITE (33% até 100% do círculo)
		var t := (p - NIGHT_FRAC) / (1.0 - NIGHT_FRAC)   # 0..1
		energy = lerp(day_energy, night_energy, t)

	sun.light_energy = energy

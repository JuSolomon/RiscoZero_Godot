extends CanvasLayer

@onready var time_label: Label = $Panel/TimeLabel
@onready var day_cycle: TextureProgressBar = $Panel/DayCycle

@onready var pause_button: Button = $Panel/pause_button
@onready var speed1: Button = $Panel/speed1
@onready var speed2: Button = $Panel/speed2
@onready var speed3: Button = $Panel/speed3

@onready var sun: DirectionalLight3D = $"../Sol"

var _last_speed: float = 1.0


func _ready() -> void:
	# Botões toggle
	pause_button.toggle_mode = true
	speed1.toggle_mode = true
	speed2.toggle_mode = true
	speed3.toggle_mode = true

	# Inicial: 1x
	_set_speed(1.0)

	# Conectar sinais do TimeManager (autoload)
	TimeManager.tick.connect(_on_tick)

	# Conectar botões
	pause_button.toggled.connect(_on_pause_toggled)
	speed1.pressed.connect(func() -> void: _set_speed(1.0))
	speed2.pressed.connect(func() -> void: _set_speed(2.0))
	speed3.pressed.connect(func() -> void: _set_speed(3.0))


func _on_tick(_t, _d, _w, _y, _term) -> void:
	_update_time_label()
	_update_day_circle()
	_update_sun()


func _update_time_label() -> void:
	var d: int = TimeManager.day_in_week
	var w: int = TimeManager.week_in_year
	var y: int = TimeManager.year_in_term
	var t: int = TimeManager.term_index

	time_label.text = "Dia %d | Semana %d | Ano %d | Mandato %d" % [d, w, y, t]


func _update_day_circle() -> void:
	var p: float = TimeManager.get_day_progress()
	day_cycle.value = p * 100.0


func _update_sun() -> void:
	if sun == null:
		return

	var p: float = TimeManager.get_day_progress() # 0.0 .. 1.0
	var angle: float

	var night_fraction := 1.0 / 3.0      # 1/3 do dia é noite
	var day_fraction := 2.0 / 3.0        # 2/3 é dia

	if p < night_fraction:
		# NOITE: -90º (meia-noite) -> 0º (nascer do sol)
		var t := p / night_fraction              # 0..1 dentro da noite
		angle = lerp(-90.0, 0.0, t)
	else:
		# DIA: 0º (nascer) -> 180º (pôr do sol)
		var t := (p - night_fraction) / day_fraction  # 0..1 dentro do dia
		angle = lerp(0.0, 180.0, t)

	sun.rotation_degrees.x = angle


func _set_speed(value: float) -> void:
	_last_speed = value
	TimeManager.set_time_scale(value)
	TimeManager.set_running(true)

	pause_button.button_pressed = false
	speed1.button_pressed = value == 1.0
	speed2.button_pressed = value == 2.0
	speed3.button_pressed = value == 3.0


func _on_pause_toggled(pressed: bool) -> void:
	if pressed:
		if TimeManager.time_scale > 0.0:
			_last_speed = TimeManager.time_scale
		TimeManager.set_running(false)
	else:
		TimeManager.set_running(true)
		TimeManager.set_time_scale(_last_speed)

		speed1.button_pressed = _last_speed == 1.0
		speed2.button_pressed = _last_speed == 2.0
		speed3.button_pressed = _last_speed == 3.0

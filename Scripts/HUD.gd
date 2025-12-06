extends CanvasLayer

# ------------------------------
# Referências de UI
# ------------------------------
var time_label: Label = null
var clock_label: Label = null
var day_cycle: TextureProgressBar = null
var tick_bar: ProgressBar = null

var pause_button: Button = null
var speed1: Button = null
var speed2: Button = null
var speed3: Button = null

# Card de evento
var event_card: Panel = null
var event_title_label: Label = null
var event_body_label: Label = null
var event_close_button: Button = null

var _last_speed: float = 1.0


# ------------------------------
# _ready
# ------------------------------
func _ready() -> void:
	# Para o EventManager encontrar a HUD
	add_to_group("HUD")

	# --- Encontrar nós de forma tolerante a mudanças de layout ---
	time_label = find_child("TimeLabel", true, false)
	clock_label = find_child("ClockLabel", true, false)
	day_cycle = find_child("DayCycle", true, false)
	tick_bar = find_child("TickBar", true, false)

	pause_button = find_child("pause_button", true, false)
	speed1 = find_child("speed1", true, false)
	speed2 = find_child("speed2", true, false)
	speed3 = find_child("speed3", true, false)

	event_card = find_child("EventCard", true, false)
	if event_card:
		event_title_label = event_card.find_child("TitleLabel", true, false)
		event_body_label = event_card.find_child("BodyLabel", true, false)
		event_close_button = event_card.find_child("CloseButton", true, false)

	# --- Estiliza textos básicos (branco) ---
	if time_label:
		time_label.add_theme_color_override("font_color", Color(1, 1, 1))
	if clock_label:
		clock_label.add_theme_color_override("font_color", Color(1, 1, 1))

	for b in [pause_button, speed1, speed2, speed3]:
		if b:
			b.add_theme_color_override("font_color", Color(1, 1, 1))

	# --- Ajuste das barras ---
	if day_cycle:
		day_cycle.min_value = 0.0
		day_cycle.max_value = 100.0
		day_cycle.value = 0.0

	if tick_bar:
		tick_bar.min_value = 0.0
		tick_bar.max_value = 100.0
		tick_bar.value = 0.0

	# --- Card de evento: começa escondido ---
	if event_card:
		event_card.visible = false

	# --- Botões como toggle ---
	if pause_button:
		pause_button.toggle_mode = true
	if speed1:
		speed1.toggle_mode = true
	if speed2:
		speed2.toggle_mode = true
	if speed3:
		speed3.toggle_mode = true

	# --- Velocidade inicial: 1x ---
	_set_speed(1.0)

	# --- Conectar TimeManager (autoload) ---
	if TimeManager:
		TimeManager.tick.connect(_on_tick)

	# --- Conectar botões ---
	if pause_button:
		pause_button.toggled.connect(_on_pause_toggled)
	if speed1:
		speed1.pressed.connect(func() -> void: _set_speed(1.0))
	if speed2:
		speed2.pressed.connect(func() -> void: _set_speed(2.0))
	if speed3:
		speed3.pressed.connect(func() -> void: _set_speed(3.0))

	if event_close_button:
		event_close_button.pressed.connect(_close_event_card)

	# Atualiza tudo na largada
	_update_all()


# ------------------------------------------------
# Atualizações em resposta ao tick
# ------------------------------------------------
func _on_tick(_t, _d, _w, _y, _term) -> void:
	_update_all()


func _update_all() -> void:
	_update_time_label()
	_update_clock_label()
	_update_day_visuals()


# ------------------------------------------------
# Texto: Dia / Semana / Ano / Mandato
# ------------------------------------------------
func _update_time_label() -> void:
	if time_label == null:
		return

	if TimeManager and TimeManager.has_method("get_current_date"):
		time_label.text = TimeManager.get_current_date()
	else:
		var d: int = TimeManager.day_in_week
		var w: int = TimeManager.week_in_year
		var y: int = TimeManager.year_in_term
		var t: int = TimeManager.term_index
		time_label.text = "Dia %d | Semana %d | Ano %d | Mandato %d" % [d, w, y, t]


# ------------------------------------------------
# Relógio HH:MM (baseado no progresso do dia)
# ------------------------------------------------
func _update_clock_label() -> void:
	if clock_label == null:
		return

	if TimeManager and TimeManager.has_method("get_time_string"):
		clock_label.text = "Hora: %s" % TimeManager.get_time_string()
	else:
		var p: float = TimeManager.get_day_progress()
		var total_minutes: int = int(p * 24.0 * 60.0)
		var hour: int = total_minutes / 60
		var minute: int = total_minutes % 60
		var time_str := "%02d:%02d" % [hour, minute]
		clock_label.text = "Hora: %s" % time_str


# ------------------------------------------------
# Visual do dia: círculo + barra linear
# ------------------------------------------------
func _update_day_visuals() -> void:
	var p: float = TimeManager.get_day_progress() # 0.0 .. 1.0

	if day_cycle:
		day_cycle.value = p * day_cycle.max_value

	if tick_bar and TimeManager.ticks_per_day > 0:
		var pct: float = float(TimeManager.current_tick) / float(TimeManager.ticks_per_day)
		tick_bar.value = pct * tick_bar.max_value


# ------------------------------------------------
# Controle de velocidade / pause
# ------------------------------------------------
func _set_speed(value: float) -> void:
	_last_speed = value
	TimeManager.set_time_scale(value)
	TimeManager.set_running(true)

	if pause_button:
		pause_button.button_pressed = false
	if speed1:
		speed1.button_pressed = (value == 1.0)
	if speed2:
		speed2.button_pressed = (value == 2.0)
	if speed3:
		speed3.button_pressed = (value == 3.0)


func _on_pause_toggled(pressed: bool) -> void:
	if pressed:
		if TimeManager.time_scale > 0.0:
			_last_speed = TimeManager.time_scale
		TimeManager.set_running(false)
	else:
		TimeManager.set_running(true)
		TimeManager.set_time_scale(_last_speed)

		if speed1:
			speed1.button_pressed = (_last_speed == 1.0)
		if speed2:
			speed2.button_pressed = (_last_speed == 2.0)
		if speed3:
			speed3.button_pressed = (_last_speed == 3.0)


# ------------------------------------------------
# Integração com EventManager – abertura de card
# ------------------------------------------------

# Traduz o tipo de unidade (int do enum UnitType em CAPS) para nome exibido
func _get_unit_type_name(unit_type: int) -> String:
	match unit_type:
		0: return "COMLURB"
		1: return "CET"
		2: return "SAMU"
		3: return "DEFESA CIVIL"
		4: return "GUARDA MUNICIPAL"
		5: return "BOMBEIROS"
		_: return "ÓRGÃO DESCONHECIDO"


## Chamada pelo EventManager ao clicar num marcador
## event_data:
## {
##   "id": String,
##   "title": String,
##   "body": String,
##   "dias_restantes_resolver": int,
##   "dias_restantes_escalar": int,
##   "required_unit_type": int
## }
func show_event_card(event_data: Dictionary) -> void:
	if event_card == null:
		print("HUD: EventCard não encontrado, não foi possível abrir o evento.")
		return

	var title := str(event_data.get("title", "Ocorrência"))
	var body := str(event_data.get("body", "Sem descrição detalhada."))

	var dias_resolver: int = int(event_data.get("dias_restantes_resolver", -1))
	var dias_escalar: int = int(event_data.get("dias_restantes_escalar", -1))
	var required_unit: int = int(event_data.get("required_unit_type", -1))

	var extra_info := ""

	if dias_resolver >= 0:
		extra_info += "\n\nDias para resolver: %d" % dias_resolver

	if dias_escalar >= 0:
		extra_info += "\nDias até escalar: %d" % dias_escalar

	if required_unit >= 0:
		extra_info += "\nÓrgão responsável: %s" % _get_unit_type_name(required_unit)

	if event_title_label:
		event_title_label.text = title

	if event_body_label:
		event_body_label.text = body + extra_info

	event_card.visible = true

	print("EVENTO ABERTO: %s" % title)


func _close_event_card() -> void:
	if event_card:
		event_card.visible = false

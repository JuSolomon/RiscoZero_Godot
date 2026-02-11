extends Node
##
# TimeManager – controla ticks, dias, semanas, anos e mandatos.
#
# Agora atualizado para:
#   ✔ Garantir integração perfeita com EventManager
#   ✔ Emitir sinal de "início de novo dia" antes da lógica dos eventos
#   ✔ Facilitar debug e HUD com helper de data/hora
##

# -------------------------
# CONFIGURAÇÕES DE TEMPO
# -------------------------

@export var seconds_per_tick: float = 0.15
@export var ticks_per_day: int = 2000

@export var days_per_week: int = 7
@export var weeks_per_year: int = 52
@export var years_per_term: int = 4

@export var enable_mvp_limit: bool = false
@export var mvp_weeks_limit: int = 2

@export var running: bool = true
@export var time_scale: float = 1.0


# -------------------------
# ESTADO ATUAL
# -------------------------

var current_tick: int = 0
var day_in_week: int = 1
var week_in_year: int = 1
var year_in_term: int = 1
var term_index: int = 1

var total_days: int = 0
var total_weeks: int = 0
var total_years: int = 0

var _accumulator: float = 0.0
var _mvp_finished: bool = false

var is_waiting_for_week_start: bool = false

# -------------------------
# SINAIS
# -------------------------

signal tick(current_tick, day_in_week, week_in_year, year_in_term, term_index)

# Agora 100% necessário para EventManager.on_new_day()
signal new_day_started(day_in_week, week_in_year, year_in_term, term_index)

signal day_changed(day_in_week, week_in_year, year_in_term, term_index)
signal week_ended(week_in_year, year_in_term, term_index)
signal week_started(week_in_year, year_in_term, term_index)
signal year_changed(year_in_term, term_index)
signal term_changed(new_term, previous_term)

signal mvp_period_finished()


# -------------------------
# READY
# -------------------------

func _ready() -> void:
	emit_signal("day_changed", day_in_week, week_in_year, year_in_term, term_index)
	emit_signal("week_started", week_in_year, year_in_term, term_index)
	emit_signal("year_changed", year_in_term, term_index)


# -------------------------
# PROCESSO
# -------------------------

func _process(delta: float) -> void:
	if not running or is_waiting_for_week_start:
		return

	_accumulator += delta * time_scale

	while _accumulator >= seconds_per_tick:
		_accumulator -= seconds_per_tick
		_do_tick()


# -------------------------
# TICK / DIA / SEMANA / ANO
# -------------------------

func _do_tick() -> void:
	current_tick += 1
	emit_signal("tick", current_tick, day_in_week, week_in_year, year_in_term, term_index)

	if current_tick >= ticks_per_day:
		current_tick = 0
		_start_new_day()


func _start_new_day() -> void:
	# Emite novo dia ANTES de alterar valores
	emit_signal("new_day_started", day_in_week, week_in_year, year_in_term, term_index)

	day_in_week += 1
	total_days += 1
	current_tick = 0

	if day_in_week > days_per_week:
		day_in_week = 1
		_advance_week()

	emit_signal("day_changed", day_in_week, week_in_year, year_in_term, term_index)


func _advance_week() -> void:
	
	emit_signal("week_ended", week_in_year, year_in_term, term_index)
	is_waiting_for_week_start = true
	
func start_next_week() -> void:
	if not is_waiting_for_week_start:
		return
		
	# Agora sim, avançamos os dados
	week_in_year += 1
	total_weeks += 1
	current_tick = 0
	
	# Lógica de virada de ano (movida para cá)
	if week_in_year > weeks_per_year:
		week_in_year = 1
		_advance_year()

	# Checagem de MVP (movida para cá)
	if enable_mvp_limit and not _mvp_finished and total_weeks >= mvp_weeks_limit:
		_mvp_finished = true
		emit_signal("mvp_period_finished")
	
	# Libera o tempo
	is_waiting_for_week_start = false
	
	# Emite que a NOVA semana começou
	emit_signal("week_started", week_in_year, year_in_term, term_index)


func _advance_year() -> void:
	year_in_term += 1
	total_years += 1
	current_tick = 0

	if year_in_term > years_per_term:
		var prev := term_index
		term_index += 1
		year_in_term = 1
		emit_signal("term_changed", term_index, prev)

	emit_signal("year_changed", year_in_term, term_index)


# -------------------------
# FUNÇÕES PÚBLICAS
# -------------------------

func reset_time(full_reset: bool = true) -> void:
	current_tick = 0
	day_in_week = 1
	week_in_year = 1
	year_in_term = 1
	term_index = 1
	_accumulator = 0.0
	_mvp_finished = false

	if full_reset:
		total_days = 0
		total_weeks = 0
		total_years = 0

	running = true

	emit_signal("new_day_started", day_in_week, week_in_year, year_in_term, term_index)
	emit_signal("day_changed", day_in_week, week_in_year, year_in_term, term_index)
	emit_signal("week_started", week_in_year, year_in_term, term_index)
	emit_signal("year_changed", year_in_term, term_index)


func set_running(value: bool) -> void:
	running = value


func set_time_scale(value: float) -> void:
	time_scale = max(value, 0.0)


# -------------------------
# HUD / DEBUG HELPERS
# -------------------------

func get_current_date() -> String:
	return "Dia %d • Semana %d • Ano %d • Mandato %d" % [
		day_in_week,
		week_in_year,
		year_in_term,
		term_index
	]


# -------------------------
# DIA / NOITE / HORÁRIO
# -------------------------

const NIGHT_FRACTION := 1.0 / 3.0
const DAY_FRACTION := 2.0 / 3.0

func get_day_progress() -> float:
	if ticks_per_day <= 0:
		return 0.0
	return float(current_tick) / float(ticks_per_day)


func is_night() -> bool:
	return get_day_progress() < NIGHT_FRACTION


func is_day() -> bool:
	return get_day_progress() >= NIGHT_FRACTION


func get_sun_phase() -> String:
	return "night" if is_night() else "day"


func get_daytime_hours() -> int:
	return int(get_day_progress() * 24.0) % 24


func get_daytime_minutes() -> int:
	return int(get_day_progress() * 24.0 * 60.0) % 60


func get_time_string() -> String:
	return "%02d:%02d" % [get_daytime_hours(), get_daytime_minutes()]


func is_morning() -> bool:
	var p := get_day_progress()
	return p >= NIGHT_FRACTION and p < (NIGHT_FRACTION + (DAY_FRACTION * 0.33))


func is_afternoon() -> bool:
	var p := get_day_progress()
	return p >= (NIGHT_FRACTION + (DAY_FRACTION * 0.33)) and \
		   p < (NIGHT_FRACTION + (DAY_FRACTION * 0.66))


func is_evening() -> bool:
	var p := get_day_progress()
	return p >= (NIGHT_FRACTION + (DAY_FRACTION * 0.66))


func is_peak_hour() -> bool:
	var h := get_daytime_hours()
	return (h >= 8 and h <= 10) or (h >= 17 and h <= 19)


func is_sleep_time() -> bool:
	var h := get_daytime_hours()
	return h >= 0 and h < 5


func is_late_night() -> bool:
	var h := get_daytime_hours()
	return h >= 22 or h < 2


func get_night_progress() -> float:
	if is_day():
		return 0.0
	return get_day_progress() / NIGHT_FRACTION


func get_day_cycle_progress() -> float:
	if is_night():
		return 0.0
	var p := get_day_progress()
	return (p - NIGHT_FRACTION) / DAY_FRACTION

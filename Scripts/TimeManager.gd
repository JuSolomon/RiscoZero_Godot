extends Node
##
# TimeManager – controla ticks, dias, semanas, anos e mandatos.
#
# Configuração:
#   - 1 dia  = 5 minutos reais (300s)
#   - tick   = 0.15s
#   - 300 / 0.15 = 2000 ticks/dia
#   - 1 semana = 7 dias (35 minutos)
#
# Suporta:
#   - MVP com limite de semanas (ex.: 2 semanas)
#   - Mandatos de 4 anos (years_per_term)
#   - Mandatos infinitos (term_index vai incrementando)
##

# -------------------------
# CONFIGURAÇÕES DE TEMPO
# -------------------------

# tempo real de cada tick em segundos
@export var seconds_per_tick: float = 0.15

# 5 minutos (300s) / 0.15s = 2000 ticks por dia
@export var ticks_per_day: int = 2000

@export var days_per_week: int = 7
@export var weeks_per_year: int = 52
@export var years_per_term: int = 4  # cada mandato tem 4 anos

# MVP – limite de semanas (por exemplo, 2 para o Carnaval)
@export var enable_mvp_limit: bool = false
@export var mvp_weeks_limit: int = 2

# Controle geral do tempo
@export var running: bool = true
@export var time_scale: float = 1.0  # 1x, 2x, 3x...

# -------------------------
# ESTADO ATUAL
# -------------------------

var current_tick: int = 0          # tick atual dentro do dia
var day_in_week: int = 1           # 1..days_per_week
var week_in_year: int = 1          # 1..weeks_per_year
var year_in_term: int = 1          # 1..years_per_term
var term_index: int = 1            # nº do mandato (1º, 2º, 3º...)

# Contadores globais (não resetam em novo mandato)
var total_days: int = 0
var total_weeks: int = 0
var total_years: int = 0

# Interno
var _accumulator: float = 0.0
var _mvp_finished: bool = false

# -------------------------
# SINAIS
# -------------------------

signal tick(current_tick, day_in_week, week_in_year, year_in_term, term_index)
signal day_changed(day_in_week, week_in_year, year_in_term, term_index)
signal week_changed(week_in_year, year_in_term, term_index)
signal year_changed(year_in_term, term_index)
signal term_changed(new_term, previous_term)

signal mvp_period_finished()  # quando atingir o limite de semanas do MVP

# -------------------------
# CICLO DE VIDA
# -------------------------

func _ready() -> void:
	# emite estado inicial se alguém quiser usar
	emit_signal("day_changed", day_in_week, week_in_year, year_in_term, term_index)
	emit_signal("week_changed", week_in_year, year_in_term, term_index)
	emit_signal("year_changed", year_in_term, term_index)


func _process(delta: float) -> void:
	if not running:
		return

	_accumulator += delta * time_scale

	while _accumulator >= seconds_per_tick:
		_accumulator -= seconds_per_tick
		_do_tick()

# -------------------------
# LÓGICA DE TICK / DIA / SEMANA / ANO
# -------------------------

func _do_tick() -> void:
	current_tick += 1
	emit_signal("tick", current_tick, day_in_week, week_in_year, year_in_term, term_index)

	if current_tick >= ticks_per_day:
		current_tick = 0
		_advance_day()


func _advance_day() -> void:
	day_in_week += 1
	total_days += 1

	if day_in_week > days_per_week:
		day_in_week = 1
		_advance_week()

	emit_signal("day_changed", day_in_week, week_in_year, year_in_term, term_index)


func _advance_week() -> void:
	week_in_year += 1
	total_weeks += 1

	# MVP: avisa quando completar o limite de semanas
	if enable_mvp_limit and not _mvp_finished and total_weeks >= mvp_weeks_limit:
		_mvp_finished = true
		emit_signal("mvp_period_finished")

	if week_in_year > weeks_per_year:
		week_in_year = 1
		_advance_year()

	emit_signal("week_changed", week_in_year, year_in_term, term_index)


func _advance_year() -> void:
	year_in_term += 1
	total_years += 1

	if year_in_term > years_per_term:
		# terminou o mandato atual → começa outro
		var previous_term := term_index
		term_index += 1
		year_in_term = 1
		emit_signal("term_changed", term_index, previous_term)

	emit_signal("year_changed", year_in_term, term_index)

# -------------------------
# FUNÇÕES PÚBLICAS
# -------------------------

func reset_time(full_reset: bool = true) -> void:
	# full_reset = true → novo save (zera tudo)
	# full_reset = false → reinicia contagem visual, mas pode manter total_* se quiser
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

	emit_signal("day_changed", day_in_week, week_in_year, year_in_term, term_index)
	emit_signal("week_changed", week_in_year, year_in_term, term_index)
	emit_signal("year_changed", year_in_term, term_index)


func set_running(value: bool) -> void:
	running = value


func set_time_scale(value: float) -> void:
	time_scale = max(value, 0.0)


func get_day_progress() -> float:
	# 0.0 = começo do dia, 1.0 = final do dia
	if ticks_per_day <= 0:
		return 0.0
	return float(current_tick) / float(ticks_per_day)

extends Node

# --- ESTADO GLOBAL (NÃO RESETAR) ---
var money_total: int = 10000
var popularity_current: float = 50.0

# --- RELATÓRIO DA SEMANA ANTERIOR (RESETAR) ---
var last_week_deaths: int = 0
var last_week_expenses: int = 0
var last_week_pop_delta: float = 0.0 # Variação da popularidade
var risk_per_zone: Dictionary = {
	"Centro": "Baixo",
	"Zona Sul": "Médio",
	"Industrial": "Alto"
}

# --- PREVISÕES PARA A PRÓXIMA SEMANA ---
var forecast_weather: String = "Ensolarado"
var forecast_events: Array = []

# ---------------------------------------------------------

func _ready() -> void:
	# Conecta ao sinal correto (corrigindo o erro de 'starded' para 'started')
	TimeManager.week_started.connect(_on_new_week_started)
	
	# VALORES DE TESTE (Delete isso depois que funcionar)
	last_week_deaths = 12
	last_week_expenses = 4500
	last_week_pop_delta = -5.4
	forecast_weather = "Tempestade"
	forecast_events = ["Festival de Verão", "Grande Prêmio de F1"]

func _on_new_week_started(_week, _year, _term) -> void:
	_reset_weekly_report()
	_generate_new_forecast()

func _reset_weekly_report() -> void:
	last_week_deaths = 0
	last_week_expenses = 0
	last_week_pop_delta = 0.0
	# Aqui você pode atualizar o risco por zona baseado na performance
	print("CityStats: Relatório resetado para a nova semana.")

func _generate_new_forecast() -> void:
	# Exemplo de preenchimento de previsão
	forecast_weather = "Chuva Forte"
	forecast_events = ["Feriado: Dia da Independência", "Final de Campeonato"]

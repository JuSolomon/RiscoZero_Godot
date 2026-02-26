extends Node
class_name GameManager

##
# GameManager
# Orquestra o fluxo geral do jogo e conversa com o TimeManager.
# MVP:
#   - controla estados (jogando, pausado, fim de MVP)
#   - centraliza pause / unpause / velocidade
#   - reage ao fim das 2 semanas do MVP
##

# Estados possíveis do jogo
enum GameState {
	BOOT,          # cena acabou de carregar
	PLAYING,       # jogando normalmente
	PAUSED,        # pausa (menu, popups, etc.)
	MVP_SUMMARY,   # fim das 2 semanas do MVP
	GAME_OVER      # futuro (impeachment, etc.)
}

@export var start_paused: bool = false

# Referências para outros sistemas (ligar no Inspector depois)
@export var hud: CanvasLayer         # CanvasLayer com HUD.gd
@export var city_root: Node3D        # nó raiz da cidade (opcional, futuro)
@export var event_system: Node       # nó de sistema de eventos (opcional, futuro)

var state: GameState = GameState.BOOT

# Sinais próprios do GameManager (para o futuro)
signal state_changed(new_state: GameState, old_state: GameState)
signal day_started(day: int, week: int, year: int)
signal week_started(week: int, year: int)
signal mvp_finished()


func _ready() -> void:
	# Conecta sinais do TimeManager
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.week_started.connect(_on_week_started)
	TimeManager.mvp_period_finished.connect(_on_mvp_period_finished)

	# Configura estado inicial
	if start_paused:
		_change_state(GameState.PAUSED)
		TimeManager.set_running(false)
	else:
		_change_state(GameState.PLAYING)
		TimeManager.set_running(true)

	# Garante velocidade padrão
	TimeManager.set_time_scale(1.0)
	
	# HACK PARA MVP: Começar no fim da semana 1
	_começar_no_resumo_v1.call_deferred()


# -------------------------------------------------
#  CONTROLE DE ESTADO
# -------------------------------------------------

func _change_state(new_state: GameState) -> void:
	if new_state == state:
		return

	var old := state
	state = new_state
	emit_signal("state_changed", new_state, old)

	match new_state:
		GameState.BOOT:
			# futuro: tela de loading / main menu
			pass

		GameState.PLAYING:
			TimeManager.set_running(true)

		GameState.PAUSED:
			TimeManager.set_running(false)

		GameState.MVP_SUMMARY:
			TimeManager.set_running(false)
			# Aqui no futuro você pode abrir um painel de resumo, estatísticas, etc.
			print("MVP FINALIZADO – mostrar tela de resumo.")

		GameState.GAME_OVER:
			TimeManager.set_running(false)
			print("GAME OVER – futuro (impeachment, renúncia, etc.)")


# -------------------------------------------------
#  API PÚBLICA (para HUD / outros sistemas)
# -------------------------------------------------

func toggle_pause() -> void:
	if state == GameState.PAUSED:
		resume_game()
	elif state == GameState.PLAYING:
		pause_game()


func pause_game() -> void:
	_change_state(GameState.PAUSED)


func resume_game() -> void:
	_change_state(GameState.PLAYING)


func set_speed(multiplier: float) -> void:
	# Centraliza mudança de velocidade
	multiplier = max(multiplier, 0.0)
	TimeManager.set_time_scale(multiplier)

	# Se definir speed > 0 e o jogo estiver em pausa,
	# você pode decidir se volta a rodar automaticamente ou não.
	# Aqui eu só deixo rodar se o estado for PLAYING.
	if state == GameState.PLAYING and multiplier > 0.0:
		TimeManager.set_running(true)


func start_new_game(full_reset: bool = true) -> void:
	# Reseta tempo e volta para o início de um mandato
	TimeManager.reset_time(full_reset)
	_change_state(GameState.PLAYING)
	TimeManager.set_time_scale(1.0)


# -------------------------------------------------
#  CALLBACKS DO TIMEMANAGER
# -------------------------------------------------

func _on_day_changed(day_in_week: int, week_in_year: int, year_in_term: int, _term: int) -> void:
	emit_signal("day_started", day_in_week, week_in_year, year_in_term)
	# No futuro: disparar geração de eventos diários aqui
	print("Novo dia – Dia %d, Semana %d, Ano %d" % [day_in_week, week_in_year, year_in_term])


func _on_week_started(week_in_year: int, year_in_term: int, _term: int) -> void:
	emit_signal("week_started", week_in_year, year_in_term)
	print("Nova semana – Semana %d, Ano %d" % [week_in_year, year_in_term])


func _on_mvp_period_finished() -> void:
	emit_signal("mvp_finished")
	print(">>> LIMITE DE SEMANAS DO MVP ATINGIDO <<<")

	# Entra no estado de resumo do MVP
	_change_state(GameState.MVP_SUMMARY)
	
func _começar_no_resumo_v1() -> void:
	print("MVP: Forçando início no resumo da Semana 1")
	
	# 1. (Opcional) Alguns dados iniciais para o CityStats não começar zerado
	CityStats.last_week_deaths = 0
	CityStats.last_week_expenses = 0
	CityStats.forecast_weather = "Nublado"
	
	# 2. Emite o sinal manualmente (Semana 1, Ano 1, Mandato 0)
	# Isso vai fazer a WeekSummaryScreen.gd capturar o sinal e aparecer.
	TimeManager.emit_signal("week_ended", 1, 1, 0)

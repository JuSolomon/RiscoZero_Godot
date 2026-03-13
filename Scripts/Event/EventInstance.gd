extends Node
class_name EventInstance

var evento_base: EventData
var id: String

var tick_inicio: int
var dia_inicio: int
var semana_inicio: int
var ano_inicio: int

var dias_para_resolver: int
var dias_para_escalar: int

var ticks_para_resolver: int = 0
var ticks_para_escalar: int = 0

var estado : GameTypes.EventState: set = set_estado_evento

signal escalar_evento(evento_id: String)
signal resolver_evento(evento_id: String)

signal progresso_evento_escalar(progresso_atual_ticks: int, progresso_restante_ticks)
signal progresso_evento_resolver(progresso_atual_ticks: int, progresso_restante_ticks)

func _init() -> void:
	if TimeManager:
		tick_inicio = TimeManager.current_tick
		dia_inicio = TimeManager.day_in_week
		semana_inicio = TimeManager.week_in_year
		ano_inicio = TimeManager.year_in_term
	else:
		push_error("EventInstance: TimeManager autoload não encontrado.")

func _ready() -> void:
	if TimeManager:
		TimeManager.tick.connect(_on_tick)
	else:
		push_error("EventInstance: TimeManager autoload não encontrado.")


# ------------------------------------------------
# INTEGRAÇÃO COM O TEMPO
# ------------------------------------------------

func _on_tick(_t, _d, _w, _y, _term) -> void:
	if TimeManager.ticks_per_day <= 0:
		return
	
	match estado:
		GameTypes.EventState.ATIVO:
			ticks_para_escalar += 1
			var ticks_restantes = TimeManager.ticks_per_day * dias_para_escalar - ticks_para_escalar
			progresso_evento_escalar.emit(ticks_para_escalar, ticks_restantes)
			if ticks_restantes <= 0:
				#if evento_base.evento_escalonado:
#					Escalar evento
				#else:
#					Falhar evento
				escalar_evento.emit(id)
			
		GameTypes.EventState.EM_ATENDIMENTO:
			ticks_para_resolver += 1
			var ticks_restantes = TimeManager.ticks_per_day * dias_para_resolver - ticks_para_resolver
			progresso_evento_resolver.emit(ticks_para_resolver, ticks_restantes)
			if ticks_restantes <= 0:
				resolver_evento.emit(id)
				
		GameTypes.EventState.EXPIRADO:
			queue_free()
		GameTypes.EventState.ESCALADO:
			queue_free()

# ------------------------------------------------
# CONTROLE DE VARIÁVEIS
# ------------------------------------------------

func set_estado_evento(novo_estado: GameTypes.EventState):
	estado = novo_estado

func get_dias_restantes_resolver() -> int:
	var resultado = float(dias_para_resolver) - float(ticks_para_resolver)/float(TimeManager.ticks_per_day)
	if resultado > 1:
		resultado = floori(resultado)
	return resultado

func get_tempo_restante_escalar() -> int:
	#var resultado = float(dias_para_escalar) - float(ticks_para_escalar)/float(TimeManager.ticks_per_day)
	#if resultado > 1:
		#resultado = floori(resultado)
	return (TimeManager.ticks_per_day * dias_para_escalar) - ticks_para_escalar

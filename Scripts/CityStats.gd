extends Node
##
# CityStats (autoload)
# Dinheiro, popularidade e as estatísticas da rodada usadas na nota de aproveitamento.
# Os números vêm de res://Config/balanceamento.tres (BalanceConfig).
##

signal mudou

const ARQ_CONFIG := "res://Config/balanceamento.tres"

var config: BalanceConfig

var money_total: int = 0
var popularity_current: float = 50.0

# --- estatísticas da rodada ---
var gastos: int = 0
var mortes: int = 0
var popularidade_inicio: float = 50.0
var resolvidas_a_tempo: int = 0
var resolvidas_apos_escalar: int = 0
var falhas: int = 0


func _ready() -> void:
	config = load(ARQ_CONFIG)
	nova_rodada()


func nova_rodada() -> void:
	money_total = config.orcamento_rodada
	popularity_current = config.popularidade_inicial
	popularidade_inicio = popularity_current
	gastos = 0
	mortes = 0
	resolvidas_a_tempo = 0
	resolvidas_apos_escalar = 0
	falhas = 0
	mudou.emit()


# -------------------------------------------------
#  REGISTROS (chamados pelo EventManager / DispatchManager)
# -------------------------------------------------

func registrar_envio(custo: int) -> void:
	money_total -= custo
	gastos += custo
	mudou.emit()


func registrar_resolucao(ev: EventInstance) -> void:
	if ev.escaladas == 0:
		resolvidas_a_tempo += 1
	else:
		resolvidas_apos_escalar += 1
	_mudar_popularidade(config.pop_resolver[_nivel(ev)])


## Tirar uma viatura de uma ocorrência em aberto (voltar ou redirecionar)
func registrar_cancelamento(ev: EventInstance) -> void:
	_mudar_popularidade(config.pop_cancelar[_nivel(ev)])


func registrar_escalada(ev: EventInstance) -> void:
	_mudar_popularidade(config.pop_escalar[_nivel(ev)])


## Retorna quantas pessoas morreram
func registrar_falha(ev: EventInstance) -> int:
	var n := _nivel(ev)
	var m := randi_range(config.mortes_min[n], config.mortes_max[n])
	falhas += 1
	mortes += m
	_mudar_popularidade(config.pop_falhar[n] + m * config.pop_por_morte)
	return m


# -------------------------------------------------
#  NOTA DE APROVEITAMENTO
# -------------------------------------------------

## `pendentes_escalados`: demandas ainda abertas no fim da rodada que já escalaram (contam como 0)
func calcular_nota(pendentes_escalados: int = 0) -> Dictionary:
	var c := config
	var total := resolvidas_a_tempo + resolvidas_apos_escalar + falhas + pendentes_escalados
	var atendimento := 100.0
	if total > 0:
		atendimento = (resolvidas_a_tempo * 100.0 + resolvidas_apos_escalar * c.valor_resolvida_apos_escalar) / total

	var nota_mortes := maxf(0.0, 100.0 * (1.0 - float(mortes) / c.mortes_para_zerar))

	var financas := 100.0
	if gastos > c.orcamento_rodada:
		var estouro := float(gastos - c.orcamento_rodada) / (c.orcamento_rodada * c.estouro_para_zerar)
		financas = maxf(0.0, 100.0 * (1.0 - estouro))

	var variacao := popularity_current - popularidade_inicio
	var nota_pop := clampf(50.0 + 50.0 * variacao / c.variacao_pop_extrema, 0.0, 100.0)

	var final := atendimento * c.peso_atendimento + nota_mortes * c.peso_mortes \
		+ financas * c.peso_financas + nota_pop * c.peso_popularidade
	return {
		"final": final,
		"aprovado": final >= c.nota_minima,
		"atendimento": atendimento,
		"mortes": nota_mortes,
		"financas": financas,
		"popularidade": nota_pop,
		"demandas": total,
		"pendentes_escalados": pendentes_escalados,
		"variacao_popularidade": variacao,
	}


func _mudar_popularidade(delta: float) -> void:
	popularity_current = clampf(popularity_current + delta, 0.0, 100.0)
	mudou.emit()


func _nivel(ev: EventInstance) -> int:
	return clampi(ev.evento_base.severidade_inicial, 1, 3) - 1

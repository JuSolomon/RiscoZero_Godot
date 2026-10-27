extends Node
class_name SedeManager
##
# SedeManager
# Construção e upgrade das sedes:
#   - cada subprefeitura tem um número de vagas (pela dificuldade) e no máximo
#     N sedes do mesmo órgão
#   - upgrades em ordem: 1 Frota rápida -> 2 Equipe treinada -> 3 Ampliação
#   - manutenção semanal das sedes e viaturas
# Valores em Config/balanceamento.tres.
##

signal sedes_mudaram

const NOMES_UPGRADE := ["Frota rápida", "Equipe treinada", "Ampliação"]

@export var regioes: RegionManager


func _ready() -> void:
	add_to_group("sedes_manager")


# -------------------------------------------------
#  CONSULTAS
# -------------------------------------------------

func sedes() -> Array:
	return get_tree().get_nodes_in_group("bases")


func sedes_na_regiao(regiao_id: String) -> Array:
	return sedes().filter(func(b) -> bool: return b.regiao_id == regiao_id)


func vagas_total(regiao_id: String) -> int:
	var dificuldade := regioes.dados(regiao_id).dificuldade(CityStats.config)
	return CityStats.config.vagas_por_dificuldade[dificuldade]


func vagas_livres(regiao_id: String) -> int:
	return vagas_total(regiao_id) - sedes_na_regiao(regiao_id).size()


## Motivo para não poder construir ("" = pode)
func motivo_nao_construir(tipo: int, regiao_id: String) -> String:
	if regiao_id == "" or not regiao_id in regioes.desbloqueadas:
		return "Fora das subprefeituras sob o seu comando."
	if vagas_livres(regiao_id) <= 0:
		return "Sem vagas para sedes em %s." % regioes.nome(regiao_id)
	var mesmas := sedes_na_regiao(regiao_id).filter(func(b) -> bool: return b.unit_type == tipo).size()
	if mesmas >= CityStats.config.max_sedes_por_orgao:
		return "%s já tem %d sedes de %s." % [regioes.nome(regiao_id), mesmas, GameTypes.UnitDict[tipo]]
	if CityStats.money_total < CityStats.config.custo_sede:
		return "Dinheiro insuficiente (R$ %d)." % CityStats.config.custo_sede
	return ""


## Nome e descrição do próximo upgrade ("" se já está no nível máximo)
func proximo_upgrade(base: UnitBase) -> Dictionary:
	if base.nivel >= NOMES_UPGRADE.size():
		return {}
	var c := CityStats.config
	var efeitos := [
		"viaturas %d%% mais rápidas" % roundi(c.bonus_velocidade * 100),
		"atendimentos %d%% mais rápidos" % roundi(c.bonus_resolucao * 100),
		"+%d viaturas" % c.viaturas_ampliacao,
	]
	return {"nome": NOMES_UPGRADE[base.nivel], "efeito": efeitos[base.nivel], "custo": c.custo_upgrade[base.nivel]}


func manutencao_semanal() -> int:
	var c := CityStats.config
	var total := 0
	for b in sedes():
		# sede recém-criada ainda pode estar sem as viaturas (são criadas logo em seguida)
		total += c.manutencao_por_sede + c.manutencao_por_viatura * maxi(b.unidades.size(), b.viaturas)
	return total


# -------------------------------------------------
#  AÇÕES
# -------------------------------------------------

## Cria uma sede sem cobrar (sedes iniciais da região)
func criar_sede(tipo: int, posicao: Vector3, regiao_id: String) -> UnitBase:
	var raiz := get_tree().current_scene.get_node_or_null("Sedes")
	if raiz == null:
		raiz = Node3D.new()
		raiz.name = "Sedes"
		get_tree().current_scene.add_child(raiz)
	var base := UnitBase.new()
	base.name = "Sede_%s_%s" % [regiao_id, GameTypes.UnitDict[tipo].replace(" ", "")]
	base.unit_type = tipo
	base.viaturas = CityStats.config.viaturas_por_sede
	base.regiao_id = regiao_id
	raiz.add_child(base, true)
	base.global_position = posicao
	sedes_mudaram.emit()
	return base


## Constrói uma sede nova (cobra o custo). Retorna null se não puder.
func construir(tipo: int, posicao: Vector3, regiao_id: String) -> UnitBase:
	if motivo_nao_construir(tipo, regiao_id) != "":
		return null
	CityStats.registrar_gasto(CityStats.config.custo_sede)
	print("SedeManager: nova sede de %s em %s" % [GameTypes.UnitDict[tipo], regioes.nome(regiao_id)])
	return criar_sede(tipo, posicao, regiao_id)


## Faz o próximo upgrade da sede (cobra o custo). Retorna false se não puder.
func fazer_upgrade(base: UnitBase) -> bool:
	var proximo := proximo_upgrade(base)
	if proximo.is_empty() or CityStats.money_total < proximo["custo"]:
		return false
	CityStats.registrar_gasto(proximo["custo"])
	base.nivel += 1
	if base.nivel == 3:
		var dispatch := get_tree().get_first_node_in_group("dispatch")
		dispatch.criar_viaturas(base, CityStats.config.viaturas_ampliacao)
	print("SedeManager: %s agora no nível %d (%s)" % [base.nome(), base.nivel, proximo["nome"]])
	sedes_mudaram.emit()
	return true

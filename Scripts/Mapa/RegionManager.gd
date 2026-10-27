extends Node
class_name RegionManager
##
# RegionManager
# Controla quais subprefeituras estão sob o comando do jogador:
#   - cobre as bloqueadas com nuvens e revela as desbloqueadas
#   - cria as sedes dos órgãos em cada região desbloqueada
#   - sorteia a próxima região oferecida (sempre vizinha das atuais)
##

signal regiao_desbloqueada(id: String)

## "Tentar de novo" recarrega a cena e recomeça nesta região (vazio = mostra o menu)
static var regiao_para_reiniciar: String = ""

const PASTA_DADOS := "res://Subprefeituras/"

@export var mapa: MapaRio
@export var road_network: RoadNetwork

var desbloqueadas: Array[String] = []

# id -> SubprefeituraData (carregado sob demanda)
var _dados: Dictionary = {}


func _ready() -> void:
	add_to_group("regioes")


func cobrir_todas() -> void:
	for id in mapa.ids_regioes():
		if not id in desbloqueadas:
			mapa.cobrir(id)


## criar_sedes = false: a região chega sem sedes (o jogador constrói depois)
func desbloquear(id: String, animar: bool, criar_sedes: bool = true) -> void:
	if id in desbloqueadas:
		return
	desbloqueadas.append(id)
	if criar_sedes:
		_criar_sedes(id)
	if animar:
		mapa.revelar(id)
	else:
		mapa.descobrir(id)
	regiao_desbloqueada.emit(id)


## Dados de jogo da subprefeitura (res://Subprefeituras/<id>.tres)
func dados(id: String) -> SubprefeituraData:
	if not _dados.has(id):
		var caminho := PASTA_DADOS + id + ".tres"
		if ResourceLoader.exists(caminho):
			_dados[id] = load(caminho)
		else:
			push_warning("RegionManager: sem %s; usando valores padrão." % caminho)
			var d := SubprefeituraData.new()
			d.id = id
			d.nome = mapa.get_regiao(id).get("nome", id)
			_dados[id] = d
	return _dados[id]


func nome(id: String) -> String:
	return dados(id).nome


## Sorteia uma região vizinha das desbloqueadas ("" se não houver)
func sortear_oferta() -> String:
	var candidatas: Array[String] = []
	for id in desbloqueadas:
		for v in mapa.get_regiao(id)["vizinhas"]:
			if not v in desbloqueadas and not v in candidatas:
				candidatas.append(v)
	if candidatas.is_empty():
		return ""
	return candidatas.pick_random()


## Retângulo que engloba todas as regiões desbloqueadas
func limites_desbloqueados() -> Rect2:
	var area := Rect2()
	for i in desbloqueadas.size():
		var r := mapa.limites_regiao(desbloqueadas[i])
		area = r if i == 0 else area.merge(r)
	return area


# Uma sede de cada órgão em volta do centro da região, sempre num cruzamento de rua
func _criar_sedes(id: String) -> void:
	var sedes_manager := get_tree().get_first_node_in_group("sedes_manager")
	var centro := mapa.centro_regiao(id)
	var limites := mapa.limites_regiao(id)
	var raio := minf(limites.size.x, limites.size.y) * 0.18
	var tipos := GameTypes.UnitDict.keys()
	for i in tipos.size():
		var angulo := TAU * i / tipos.size()
		var alvo := centro + Vector3(cos(angulo), 0.0, sin(angulo)) * raio
		var ponto := road_network.ponto_na_regiao_perto_de(id, alvo) if road_network else Vector3.INF
		sedes_manager.criar_sede(tipos[i], alvo if ponto == Vector3.INF else ponto, id)

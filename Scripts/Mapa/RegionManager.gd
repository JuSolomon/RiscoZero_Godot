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

@export var mapa: MapaRio
@export var road_network: RoadNetwork
@export var viaturas_por_sede: int = 2

var desbloqueadas: Array[String] = []


func cobrir_todas() -> void:
	for id in mapa.ids_regioes():
		if not id in desbloqueadas:
			mapa.cobrir(id)


func desbloquear(id: String, animar: bool) -> void:
	if id in desbloqueadas:
		return
	desbloqueadas.append(id)
	_criar_sedes(id)
	if animar:
		mapa.revelar(id)
	else:
		mapa.descobrir(id)
	regiao_desbloqueada.emit(id)


func nome(id: String) -> String:
	return mapa.get_regiao(id).get("nome", id)


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
	var raiz := get_tree().current_scene.get_node_or_null("Sedes")
	if raiz == null:
		raiz = Node3D.new()
		raiz.name = "Sedes"
		get_tree().current_scene.add_child(raiz)

	var centro := mapa.centro_regiao(id)
	var limites := mapa.limites_regiao(id)
	var raio := minf(limites.size.x, limites.size.y) * 0.18
	var tipos := GameTypes.UnitDict.keys()
	for i in tipos.size():
		var angulo := TAU * i / tipos.size()
		var alvo := centro + Vector3(cos(angulo), 0.0, sin(angulo)) * raio
		var base := UnitBase.new()
		base.name = "Sede_%s_%s" % [id, GameTypes.UnitDict[tipos[i]].replace(" ", "")]
		base.unit_type = tipos[i]
		base.viaturas = viaturas_por_sede
		raiz.add_child(base)
		var ponto := road_network.ponto_na_regiao_perto_de(id, alvo) if road_network else Vector3.INF
		base.global_position = alvo if ponto == Vector3.INF else ponto

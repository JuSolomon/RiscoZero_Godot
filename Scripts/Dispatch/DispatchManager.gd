extends Node
class_name DispatchManager
##
# DispatchManager
# Envia viaturas das sedes (UnitBase) até os eventos, pela menor rota do RoadNetwork.
#   - viatura chega no local -> evento entra em atendimento
#   - evento some do mapa (resolvido, falhou) -> viatura volta para a sede
##

@export var road_network: RoadNetwork
@export var event_manager: Node
@export var unit_scene: PackedScene

## A viatura estaciona um pouco antes do marcador, para não ficar embaixo dele
@export var distancia_estacionar: float = 4.0


func _ready() -> void:
	add_to_group("dispatch")
	_verificar_ruas.call_deferred()


# O mapa carrega as ruas no _ready dele, que roda depois deste
func _verificar_ruas() -> void:
	if road_network == null or not road_network.tem_ruas():
		push_warning("DispatchManager: sem rede de ruas, as viaturas vão em linha reta.")


# -------------------------------------------------
#  API PÚBLICA (usada pelo EventCard)
# -------------------------------------------------

## Texto explicando por que não dá para enviar equipe ("" = pode enviar)
func motivo_bloqueio(ev: EventInstance) -> String:
	if ev.estado == GameTypes.EventState.EM_ATENDIMENTO:
		return "Equipe no local, resolvendo a ocorrência."
	if ev.unidade_designada and is_instance_valid(ev.unidade_designada):
		return "Equipe a caminho."
	var tipo := ev.evento_base.required_unit_type
	if _encontrar_base(tipo, ev.get_parent().global_position) == null:
		return "Nenhuma viatura de %s disponível." % GameTypes.UnitDict[tipo]
	return ""


func despachar(ev: EventInstance) -> bool:
	if motivo_bloqueio(ev) != "":
		return false

	var marcador: Node3D = ev.get_parent()
	var tipo := ev.evento_base.required_unit_type
	var base := _encontrar_base(tipo, marcador.global_position)

	var unit: Unit = unit_scene.instantiate()
	unit.configurar(tipo, base, marcador)
	get_tree().current_scene.add_child(unit)
	unit.global_position = base.global_position

	base.disponiveis -= 1
	ev.unidade_designada = unit
	CityStats.registrar_envio(ev)

	unit.chegou_ao_destino.connect(_on_unidade_chegou)
	unit.voltou_para_base.connect(_on_unidade_voltou)
	marcador.tree_exiting.connect(_mandar_voltar.bind(unit))

	unit.seguir_rota(_rota_ate_evento(base.global_position, marcador.global_position), Unit.Estado.INDO)
	print("DispatchManager: %s saiu para o evento %s" % [GameTypes.UnitDict[tipo], ev.id])
	return true


# -------------------------------------------------
#  CICLO DA VIATURA
# -------------------------------------------------

func _on_unidade_chegou(unit: Unit) -> void:
	var ev: EventInstance = event_manager.get_evento_do_marcador(unit.marcador)

	# O evento pode ter escalado no caminho para algo que exige outro órgão
	if ev and ev.estado == GameTypes.EventState.ATIVO \
	and ev.evento_base.required_unit_type == unit.unit_type:
		ev.unidade_designada = unit
		event_manager.iniciar_atendimento(ev.id)
		return

	if ev and ev.unidade_designada == unit:
		ev.unidade_designada = null
	_mandar_voltar(unit)


func _on_unidade_voltou(unit: Unit) -> void:
	unit.base.disponiveis += 1


func _mandar_voltar(unit: Unit) -> void:
	# Na troca de cena tudo sai da árvore junto: não há para onde voltar
	if not is_instance_valid(unit) or not unit.is_inside_tree() or unit.estado == Unit.Estado.VOLTANDO:
		return
	unit.seguir_rota(_rota(unit.global_position, unit.base.global_position), Unit.Estado.VOLTANDO)


# -------------------------------------------------
#  AUXILIARES
# -------------------------------------------------

func _encontrar_base(tipo: int, destino: Vector3) -> UnitBase:
	var melhor: UnitBase = null
	for b in get_tree().get_nodes_in_group("bases"):
		if b.unit_type != tipo or b.disponiveis <= 0:
			continue
		if melhor == null or b.global_position.distance_to(destino) < melhor.global_position.distance_to(destino):
			melhor = b
	return melhor


func _rota(de: Vector3, para: Vector3) -> PackedVector3Array:
	para.y = de.y  # viatura anda no chão, não na altura do marcador
	if road_network and road_network.tem_ruas():
		return road_network.get_route(de, para)
	return PackedVector3Array([para])


func _rota_ate_evento(de: Vector3, evento: Vector3) -> PackedVector3Array:
	var rota := _rota(de, evento)
	var anterior := de if rota.size() < 2 else rota[rota.size() - 2]
	var direcao := rota[rota.size() - 1] - anterior
	if direcao.length() > distancia_estacionar:
		rota[rota.size() - 1] -= direcao.normalized() * distancia_estacionar
	return rota

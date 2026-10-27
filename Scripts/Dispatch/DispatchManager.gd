extends Node
class_name DispatchManager
##
# DispatchManager
# Envia viaturas das sedes (UnitBase) até os eventos, pela menor rota do RoadNetwork.
#   - cada evento tem uma receita (órgão -> quantidade de viaturas)
#   - o atendimento só começa quando a equipe completa está no local
#   - evento some do mapa (resolvido, falhou) -> viaturas voltam para a sede
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

## Texto explicando por que não dá para enviar viaturas ("" = pode enviar)
func motivo_bloqueio(ev: EventInstance) -> String:
	if ev.estado == GameTypes.EventState.EM_ATENDIMENTO:
		return "Equipe completa no local, resolvendo a ocorrência."
	ev.limpar_unidades()
	var falta := ev.faltando()
	if falta.is_empty():
		return "Todas as viaturas necessárias já foram enviadas."
	var destino: Vector3 = ev.get_parent().global_position
	var sem_viatura: Array[String] = []
	for tipo in falta:
		if _encontrar_base(tipo, destino) == null:
			sem_viatura.append(GameTypes.UnitDict[tipo])
	if sem_viatura.size() == falta.size():
		return "Sem viaturas disponíveis de: %s." % ", ".join(sem_viatura)
	return ""


## Envia as viaturas que faltam na receita (as que houver disponíveis). Retorna quantas saíram.
func despachar(ev: EventInstance) -> int:
	if motivo_bloqueio(ev) != "":
		return 0
	var marcador: Node3D = ev.get_parent()
	var enviadas := 0
	var falta := ev.faltando()
	for tipo in falta:
		for i in falta[tipo]:
			var base := _encontrar_base(tipo, marcador.global_position)
			if base == null:
				break
			_enviar(base, ev, marcador)
			enviadas += 1
	return enviadas


## Custo aproximado de enviar as viaturas que faltam (para mostrar no card)
func estimar_custo(ev: EventInstance) -> int:
	var destino: Vector3 = ev.get_parent().global_position
	var total := 0
	var falta := ev.faltando()
	for tipo in falta:
		var base := _encontrar_base(tipo, destino)
		if base == null:
			continue
		# distância em linha reta x 1.3 (as ruas não são retas)
		var km := base.global_position.distance_to(destino) * 1.3 / 10.0
		total += falta[tipo] * _custo(km)
	return total


## Manda de volta para a sede uma viatura que não é mais necessária
func liberar(unit: Unit) -> void:
	_mandar_voltar(unit)


## Começa o atendimento se a equipe completa já estiver no local
func verificar_inicio(ev: EventInstance) -> void:
	if ev.estado == GameTypes.EventState.ATIVO and not ev.receita.is_empty() and ev.equipe_completa_no_local():
		event_manager.iniciar_atendimento(ev.id)


# -------------------------------------------------
#  CICLO DA VIATURA
# -------------------------------------------------

func _enviar(base: UnitBase, ev: EventInstance, marcador: Node3D) -> void:
	var unit: Unit = unit_scene.instantiate()
	unit.configurar(base.unit_type, base, marcador)
	get_tree().current_scene.add_child(unit)
	unit.global_position = base.global_position

	# cada viatura do mesmo evento estaciona numa "vaga" diferente
	var rota := _rota_ate_evento(base.global_position, marcador.global_position, ev.unidades.size())
	var custo := _custo(_comprimento(rota) / 10.0)   # 1 unidade = 100 m
	base.disponiveis -= 1
	ev.unidades.append(unit)
	CityStats.registrar_envio(custo)

	unit.chegou_ao_destino.connect(_on_unidade_chegou)
	unit.voltou_para_base.connect(_on_unidade_voltou)
	# uma ligação por viatura (bind com argumentos diferentes conta como a mesma ligação)
	marcador.tree_exiting.connect(func() -> void: _mandar_voltar(unit))

	unit.seguir_rota(rota, Unit.Estado.INDO)
	print("DispatchManager: %s saiu para %s (R$ %d)" % [GameTypes.UnitDict[base.unit_type], ev.evento_base.nome, custo])


func _on_unidade_chegou(unit: Unit) -> void:
	var ev: EventInstance = event_manager.get_evento_do_marcador(unit.marcador)

	# Continua designada? (o evento pode ter escalado para algo que não usa este órgão)
	if ev and unit in ev.unidades and ev.estado == GameTypes.EventState.ATIVO:
		verificar_inicio(ev)
		return

	if ev:
		ev.unidades.erase(unit)
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


## vaga 0, 1, 2...: viaturas do mesmo evento param lado a lado, em volta do marcador
func _rota_ate_evento(de: Vector3, evento: Vector3, vaga: int = 0) -> PackedVector3Array:
	var rota := _rota(de, evento)
	var anterior := de if rota.size() < 2 else rota[rota.size() - 2]
	var direcao := rota[rota.size() - 1] - anterior
	if direcao.length() > distancia_estacionar:
		rota[rota.size() - 1] -= direcao.normalized() * distancia_estacionar
	if vaga > 0:
		var angulo := TAU * vaga / 6.0
		rota.append(rota[rota.size() - 1] + Vector3(cos(angulo), 0.0, sin(angulo)) * distancia_estacionar * 0.8)
	return rota


func _custo(km: float) -> int:
	var c := CityStats.config
	return c.custo_por_viatura + roundi(c.custo_por_km * km)


func _comprimento(rota: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, rota.size()):
		total += rota[i - 1].distance_to(rota[i])
	return total

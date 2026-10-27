extends Node
class_name DispatchManager
##
# DispatchManager
# Envia viaturas das sedes (UnitBase) até os eventos, pela menor rota do RoadNetwork.
#   - cada sede tem viaturas fixas; elas saem, atendem e voltam para a sede
#   - cada evento tem uma receita (órgão -> quantidade de viaturas)
#   - o atendimento só começa quando a equipe completa está no local
#   - viatura voltando para a sede conta como disponível e pode ser reenviada no caminho
#   - tirar uma viatura de uma ocorrência em aberto (voltar ou redirecionar) custa popularidade
#   - evento some do mapa (resolvido, falhou) -> viaturas voltam para a sede
##

signal viatura_mudou(unit: Unit)

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


## Cria as viaturas de uma sede (chamado pela própria UnitBase)
func criar_viaturas(base: UnitBase, quantidade: int) -> void:
	for i in quantidade:
		var unit: Unit = unit_scene.instantiate()
		unit.configurar(base.unit_type, base, base.unidades.size() + 1)
		get_tree().current_scene.add_child(unit)
		unit.estacionar_na_sede()
		unit.chegou_ao_destino.connect(_on_unidade_chegou)
		unit.voltou_para_base.connect(func(u: Unit) -> void: viatura_mudou.emit(u))
		base.unidades.append(unit)


# -------------------------------------------------
#  CONSULTAS
# -------------------------------------------------

## Evento em que a viatura está trabalhando (ou indo trabalhar); null se nenhum
func evento_da_viatura(unit: Unit) -> EventInstance:
	if unit.marcador == null or not is_instance_valid(unit.marcador):
		return null
	var ev: EventInstance = event_manager.get_evento_do_marcador(unit.marcador)
	return ev if ev and unit in ev.unidades else null


## Texto explicando por que não dá para usar o envio rápido do card ("" = pode enviar)
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
		if _viatura_mais_proxima(tipo, destino) == null:
			sem_viatura.append(GameTypes.UnitDict[tipo])
	if sem_viatura.size() == falta.size():
		return "Sem viaturas disponíveis de: %s." % ", ".join(sem_viatura)
	return ""


## Custo aproximado de enviar as viaturas que faltam (para mostrar no card)
func estimar_custo(ev: EventInstance) -> int:
	var destino: Vector3 = ev.get_parent().global_position
	var total := 0
	var falta := ev.faltando()
	for tipo in falta:
		var unit := _viatura_mais_proxima(tipo, destino)
		if unit:
			# distância em linha reta x 1.3 (as ruas não são retas)
			total += falta[tipo] * _custo(_origem(unit).distance_to(destino) * 1.3 / 10.0)
	return total


# -------------------------------------------------
#  AÇÕES DO JOGADOR
# -------------------------------------------------

## Envio rápido (card): manda as viaturas que faltam, cada uma a mais próxima disponível.
## Retorna quantas saíram.
func despachar(ev: EventInstance) -> int:
	if motivo_bloqueio(ev) != "":
		return 0
	var destino: Vector3 = ev.get_parent().global_position
	var enviadas := 0
	var falta := ev.faltando()
	for tipo in falta:
		for i in falta[tipo]:
			var unit := _viatura_mais_proxima(tipo, destino)
			if unit == null:
				break
			if enviar(unit, ev):
				enviadas += 1
	return enviadas


## Manda uma viatura específica para um evento (menu da sede ou redirecionar).
## Retorna false se o evento não precisa (mais) desse órgão.
func enviar(unit: Unit, ev: EventInstance) -> bool:
	if ev.estado != GameTypes.EventState.ATIVO or ev.faltando().get(unit.unit_type, 0) <= 0:
		return false

	# Estava em outra ocorrência: sair dela é um cancelamento
	var anterior := evento_da_viatura(unit)
	if anterior and anterior != ev:
		_retirar_do_evento(unit, anterior, true)

	var marcador: Node3D = ev.get_parent()
	# cada viatura do mesmo evento estaciona numa "vaga" diferente
	var rota := _rota_ate_evento(unit.global_position if unit.visible else unit.base.global_position,
		marcador.global_position, ev.unidades.size())
	if not unit.visible:
		unit.global_position = unit.base.global_position
	var custo := _custo(_comprimento(rota, unit.global_position) / 10.0)   # 1 unidade = 100 m

	unit.marcador = marcador
	ev.unidades.append(unit)
	CityStats.registrar_envio(custo)
	unit.seguir_rota(rota, Unit.Estado.INDO)
	viatura_mudou.emit(unit)
	print("DispatchManager: %s saiu para %s (R$ %d)" % [unit.nome(), ev.evento_base.nome, custo])
	return true


## "Voltar para a sede" (menu da viatura): deixa a ocorrência sem essa viatura
func mandar_voltar(unit: Unit) -> void:
	var ev := evento_da_viatura(unit)
	if ev:
		_retirar_do_evento(unit, ev, true)
	_voltar(unit)


## Libera uma viatura que o sistema não precisa mais (evento acabou ou escalou), sem penalidade
func liberar(unit: Unit) -> void:
	var ev := evento_da_viatura(unit)
	if ev:
		_retirar_do_evento(unit, ev, false)
	_voltar(unit)


## Libera todas as viaturas de um evento que está saindo do mapa
func liberar_evento(ev: EventInstance) -> void:
	for unit in ev.unidades.duplicate():
		if is_instance_valid(unit):
			ev.unidades.erase(unit)
			_voltar(unit)
	ev.unidades.clear()


## Começa o atendimento se a equipe completa já estiver no local
func verificar_inicio(ev: EventInstance) -> void:
	if ev.estado == GameTypes.EventState.ATIVO and not ev.receita.is_empty() and ev.equipe_completa_no_local():
		event_manager.iniciar_atendimento(ev.id)


# -------------------------------------------------
#  CICLO DA VIATURA
# -------------------------------------------------

func _on_unidade_chegou(unit: Unit) -> void:
	var ev := evento_da_viatura(unit)
	if ev and ev.estado == GameTypes.EventState.ATIVO:
		verificar_inicio(ev)
	elif ev == null:
		_voltar(unit)
	viatura_mudou.emit(unit)


func _retirar_do_evento(unit: Unit, ev: EventInstance, cancelamento: bool) -> void:
	ev.unidades.erase(unit)
	# Sem a equipe completa o atendimento para e o prazo para escalar volta a correr
	if ev.estado == GameTypes.EventState.EM_ATENDIMENTO:
		ev.set_estado_evento(GameTypes.EventState.ATIVO)
	if cancelamento:
		CityStats.registrar_cancelamento(ev)


func _voltar(unit: Unit) -> void:
	# Na troca de cena tudo sai da árvore junto: não há para onde voltar
	if not is_instance_valid(unit) or not unit.is_inside_tree():
		return
	unit.marcador = null
	if unit.estado == Unit.Estado.NA_SEDE or unit.estado == Unit.Estado.VOLTANDO:
		return
	unit.seguir_rota(_rota(unit.global_position, unit.base.global_position), Unit.Estado.VOLTANDO)
	viatura_mudou.emit(unit)


# -------------------------------------------------
#  AUXILIARES
# -------------------------------------------------

# Viatura disponível do órgão mais perto do destino (na sede ou já voltando)
func _viatura_mais_proxima(tipo: int, destino: Vector3) -> Unit:
	var melhor: Unit = null
	for b in get_tree().get_nodes_in_group("bases"):
		if b.unit_type != tipo:
			continue
		for u in b.unidades:
			if u.disponivel() and (melhor == null
					or _origem(u).distance_squared_to(destino) < _origem(melhor).distance_squared_to(destino)):
				melhor = u
	return melhor


func _origem(unit: Unit) -> Vector3:
	return unit.global_position if unit.visible else unit.base.global_position


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


func _comprimento(rota: PackedVector3Array, de: Vector3) -> float:
	var total := 0.0
	var anterior := de
	for p in rota:
		total += anterior.distance_to(p)
		anterior = p
	return total

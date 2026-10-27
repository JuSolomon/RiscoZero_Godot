extends Node
## EventManager.gd
## Gera eventos ao longo do dia, controla instâncias e posiciona os marcadores na cidade.

# ------------------------------------------------
# CONFIGURAÇÕES
# ------------------------------------------------

@export var event_library: EventLibrary

## Cena do marcador (arraste EventMarker.tscn no Inspector)
@export var marker_scene: PackedScene

## Regiões desbloqueadas: os eventos surgem nos cruzamentos de rua delas
@export var regioes: RegionManager

## Centro da cidade para gerar posições aleatórias (usado só sem RegionManager)
@export var city_center: Node3D

## Raio de spawn dos eventos (em torno do city_center)
@export var city_radius: float = 80.0

## Altura inicial do raycast (de cima pra baixo)
@export var spawn_height: float = 200.0

## Quanto acima do chão o marcador deve aparecer
@export var marker_height_offset: float = 3.0

## Tamanho do marcador no mapa
@export var escala_marcador: float = 1.0

## Avisa quando uma nova ocorrência aparece no mapa (alertas do HUD)
signal evento_criado(ev: EventInstance)

## Avisos para as manchetes diárias
signal evento_resolvido(ev: EventInstance)
signal evento_escalado(antigo: EventInstance, novo: EventInstance)
signal evento_falhou(ev: EventInstance, mortes: int)

# ------------------------------------------------
# VARIÁVEIS INTERNAS
# ------------------------------------------------

## Previsão do clima de cada dia da semana (GameTypes.Clima), índice 0 = dia 1
var previsao: Array[int] = []

# Agenda da semana: [dia, tick], em ordem
var _agenda: Array = []
var _proximo_da_agenda: int = 0

# id -> instância do evento
var _active_events: Dictionary = {}


# ------------------------------------------------
# READY
# ------------------------------------------------

func _ready() -> void:
	randomize()
	add_to_group("eventos")

	if TimeManager:
		TimeManager.tick.connect(_on_tick)
	else:
		push_error("EventManager: TimeManager autoload não encontrado.")


# ------------------------------------------------
# GERAÇÃO DA SEMANA
# ------------------------------------------------

## Monta a semana: previsão do clima e quantos eventos surgem em cada dia.
## `hora_inicial`: o primeiro dia começa nesse horário (os eventos dele ficam depois disso)
func planejar_semana(hora_inicial: float = 7.0) -> void:
	var c := CityStats.config
	previsao.clear()
	for dia in TimeManager.days_per_week:
		previsao.append(_sortear(c.chance_clima))

	var subprefeituras := maxi(regioes.desbloqueadas.size(), 1) if regioes else 1
	var total := c.eventos_semana_base + c.eventos_por_subprefeitura_extra * (subprefeituras - 1) + randi_range(-1, 1)
	total = clampi(total, c.eventos_semana_min, c.eventos_semana_max)

	# dias de temporal recebem mais eventos; nenhum dia passa do máximo
	var por_dia: Array[int] = []
	por_dia.resize(previsao.size())
	por_dia.fill(0)
	var pesos: Array[float] = []
	for clima in previsao:
		pesos.append(c.peso_dia_por_clima[clima])
	for i in total:
		var livres := pesos.duplicate()
		for d in livres.size():
			if por_dia[d] >= c.eventos_por_dia_max:
				livres[d] = 0.0
		if livres.max() <= 0.0:
			break
		por_dia[_sortear(livres)] += 1

	var tpd := TimeManager.ticks_per_day
	var inicio := int(tpd * hora_inicial / 24.0)
	_agenda.clear()
	for d in por_dia.size():
		for i in por_dia[d]:
			_agenda.append([d + 1, randi_range(inicio if d == 0 else 0, tpd - 1)])
	_agenda.sort_custom(func(a, b) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	_proximo_da_agenda = 0
	print("EventManager: semana planejada -> %d eventos, por dia %s, clima %s" % [_agenda.size(), por_dia, previsao])


func eventos_previstos() -> int:
	return _agenda.size()


func clima_de_hoje() -> int:
	var dia := TimeManager.day_in_week - 1
	return previsao[dia] if dia >= 0 and dia < previsao.size() else GameTypes.Clima.SOL


# índice sorteado proporcional aos pesos
func _sortear(pesos: Array) -> int:
	var total := 0.0
	for p in pesos:
		total += p
	var r := randf() * total
	for i in pesos.size():
		r -= pesos[i]
		if r <= 0.0 and pesos[i] > 0.0:
			return i
	return pesos.size() - 1


# ------------------------------------------------
# INTEGRAÇÃO COM O TEMPO
# ------------------------------------------------

func _on_tick(_t, _d, _w, _y, _term) -> void:
	while _proximo_da_agenda < _agenda.size():
		var item: Array = _agenda[_proximo_da_agenda]
		var chegou: bool = TimeManager.day_in_week > item[0] \
			or (TimeManager.day_in_week == item[0] and TimeManager.current_tick >= item[1])
		if not chegou:
			break
		_proximo_da_agenda += 1
		spawn_random_event()


func _resolver_evento(event_id: String) -> void:
	if not _active_events.has(event_id):
		return

	var ev: EventInstance = _active_events[event_id]
	ev.set_estado_evento(GameTypes.EventState.RESOLVIDO)
	_active_events.erase(event_id)

	CityStats.registrar_resolucao(ev)
	evento_resolvido.emit(ev)
	_remover_marcador(ev)
	print("EventManager: evento resolvido -> ", event_id)


func _escalar_evento(event_id: String) -> void:
	if not _active_events.has(event_id):
		return

	var ev: EventInstance = _active_events[event_id]
	var template: EventData = ev.evento_base.evento_escalonado

	# Sem evento seguinte para escalar: o evento falha
	if template == null:
		_falhar_evento(event_id)
		return

	ev.set_estado_evento(GameTypes.EventState.ESCALADO)
	_active_events.erase(event_id)
	CityStats.registrar_escalada(ev)

	# O novo evento ocupa o mesmo marcador do evento antigo
	var ev_marker := ev.get_parent()
	var novo_id := _gerar_id()
	if "event_id" in ev_marker:
		ev_marker.event_id = novo_id

	var novo_evento := _criar_instancia(template, novo_id, ev.dificuldade, ev.regiao_id)
	novo_evento.escaladas = ev.escaladas + 1

	# Viaturas já designadas continuam se o novo estágio precisar do órgão delas; as outras voltam
	var dispatch := get_tree().get_first_node_in_group("dispatch")
	ev.limpar_unidades()
	for u in ev.unidades.duplicate():
		if novo_evento.faltando().get(u.unit_type, 0) > 0:
			novo_evento.unidades.append(u)
		elif dispatch:
			ev.unidades.erase(u)
			dispatch.liberar(u)
	ev.unidades.clear()

	ev.queue_free()
	ev_marker.add_child(novo_evento)
	if dispatch:
		dispatch.verificar_inicio(novo_evento)
	evento_escalado.emit(ev, novo_evento)

	print("EventManager: evento escalado -> ", event_id, " virou ", novo_id, " (", template.nome, ")")


func _falhar_evento(event_id: String) -> void:
	if not _active_events.has(event_id):
		return

	var ev: EventInstance = _active_events[event_id]
	ev.set_estado_evento(GameTypes.EventState.EXPIRADO)
	_active_events.erase(event_id)

	var mortes := CityStats.registrar_falha(ev)
	evento_falhou.emit(ev, mortes)
	_remover_marcador(ev)
	print("EventManager: evento expirado sem resolução -> ", event_id, " (mortes: ", mortes, ")")


func iniciar_atendimento(event_id: String) -> void:
	if not _active_events.has(event_id):
		return
	_active_events[event_id].set_estado_evento(GameTypes.EventState.EM_ATENDIMENTO)
	print("EventManager: equipe chegou, atendimento iniciado -> ", event_id)


## Ocorrências em aberto no mapa
func eventos_ativos() -> Array:
	return _active_events.values()


## Demandas ainda abertas que já escalaram (contam como não atendidas na nota)
func contar_pendentes_escalados() -> int:
	var n := 0
	for ev in _active_events.values():
		if ev.escaladas > 0:
			n += 1
	return n


## Remove todos os eventos do mapa (fim de rodada)
func limpar_eventos() -> void:
	for ev in _active_events.values():
		_remover_marcador(ev)
	_active_events.clear()


func get_evento_do_marcador(marker: Node) -> EventInstance:
	if marker == null or not is_instance_valid(marker) or not ("event_id" in marker):
		return null
	return _active_events.get(marker.event_id)


# Remove o marcador do mapa junto com a instância do evento (e libera as viaturas dele)
func _remover_marcador(ev: EventInstance) -> void:
	var dispatch := get_tree().get_first_node_in_group("dispatch")
	if dispatch:
		dispatch.liberar_evento(ev)
	var marker := ev.get_parent()
	if marker is Area3D:
		marker.queue_free()
	else:
		ev.queue_free()


func _gerar_id() -> String:
	return str(Time.get_ticks_msec()) + "_" + str(randi())


# Cria a instância de um evento a partir do template e registra nos ativos
func _criar_instancia(template: EventData, event_id: String,
		dificuldade: int = GameTypes.Dificuldade.NORMAL, regiao_id: String = "") -> EventInstance:
	var novo_evento := EventInstance.new()
	novo_evento.name = event_id
	novo_evento.id = event_id
	novo_evento.evento_base = template
	novo_evento.regiao_id = regiao_id
	novo_evento.dificuldade = dificuldade
	novo_evento.receita = template.receita(dificuldade).duplicate()
	if novo_evento.receita.is_empty():
		push_warning("EventManager: evento '%s' sem receita para a dificuldade %d." % [template.nome, dificuldade])
	novo_evento.dias_para_resolver = template.dias_para_resolver
	novo_evento.dias_para_escalar = template.dias_para_escalar
	novo_evento.set_estado_evento(GameTypes.EventState.ATIVO)

	novo_evento.escalar_evento.connect(_escalar_evento)
	novo_evento.resolver_evento.connect(_resolver_evento)

	_active_events[event_id] = novo_evento
	return novo_evento


# ------------------------------------------------
# POSICIONAMENTO – cruzamento de rua da região (ou raycast até o chão)
# ------------------------------------------------

func _get_random_city_position(regiao_id: String = "") -> Vector3:
	if regiao_id != "" and regioes and regioes.road_network:
		var ponto: Vector3 = regioes.road_network.ponto_aleatorio([regiao_id])
		if ponto != Vector3.INF:
			return ponto + Vector3.UP * marker_height_offset

	var center := Vector3.ZERO

	if city_center and is_instance_valid(city_center):
		center = city_center.global_transform.origin

	# Ponto aleatório dentro de um disco
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var angle := rng.randf() * TAU
	var radius := sqrt(rng.randf()) * city_radius

	var x := center.x + cos(angle) * radius
	var z := center.z + sin(angle) * radius

	# Raycast: do alto para baixo
	var from := Vector3(x, spawn_height, z)
	var to := Vector3(x, -1000, z)

	var space := get_viewport().world_3d.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit: Dictionary = space.intersect_ray(query)

	if not hit.is_empty():
		var hit_pos: Vector3 = hit["position"]
		var ground_y: float = hit_pos.y
		return Vector3(x, ground_y + marker_height_offset, z)
	else:
		# fallback caso não ache colisão
		return Vector3(x, 2.0, z)


# ------------------------------------------------
# SPAWN DOS EVENTOS
# ------------------------------------------------

func spawn_random_event() -> void:
	if marker_scene == null:
		print("EventManager: ERRO – marker_scene não configurado.")
		return

	if event_library == null:
		print("EventManager: ERRO – event_library não configurada.")
		return

	# Sorteia a subprefeitura e um evento que faça sentido nela
	var regiao_id := ""
	var dificuldade: int = GameTypes.Dificuldade.NORMAL
	var template: EventData
	if regioes and not regioes.desbloqueadas.is_empty():
		# subprefeituras mais populosas têm mais ocorrências
		var pops: Array = regioes.desbloqueadas.map(func(id) -> float: return float(regioes.dados(id).populacao))
		regiao_id = regioes.desbloqueadas[_sortear(pops)]
		var sub: SubprefeituraData = regioes.dados(regiao_id)
		template = event_library.get_random_event_for_clima(sub.etiquetas, clima_de_hoje(), CityStats.config.peso_clima_favoravel)
		dificuldade = sub.dificuldade(CityStats.config)
	else:
		template = event_library.get_random_event()
	if template == null:
		print("EventManager: ERRO – nenhum evento possível na biblioteca.")
		return

	var marker := marker_scene.instantiate() as Area3D
	if marker == null:
		print("EventManager: ERRO – marker_scene não é uma Area3D válida.")
		return

	# Cria id único para essa instância
	var event_id := _gerar_id()

	# Passa o id para o marcador (assumindo que ele tenha essa variável)
	if "event_id" in marker:
		marker.event_id = event_id

	# Conecta clique
	marker.clicked.connect(_on_marker_clicked)

	# Adiciona ao mapa antes de posicionar (global_position exige estar na árvore)
	get_tree().current_scene.add_child(marker)
	var pos := _get_random_city_position(regiao_id)
	marker.global_position = pos
	marker.scale = Vector3.ONE * escala_marcador
	var instancia := _criar_instancia(template, event_id, dificuldade, regiao_id)
	marker.add_child(instancia)
	evento_criado.emit(instancia)

	print("EventManager: Evento criado em ", pos, " id = ", event_id, " template = ", template.nome)


# ------------------------------------------------
# CLIQUE NO MARCADOR -> ABRIR HUD
# ------------------------------------------------

func _on_marker_clicked(event_id: String) -> void:
	print("EventManager: marcador clicado id = ", event_id)

	if not _active_events.has(event_id):
		push_error("EventManager: clique em marcador com id desconhecido: " + event_id)
		return

	var ev: EventInstance = _active_events[event_id]
	var template: EventData = ev.evento_base

	# Escolhendo destino para viaturas (menu da sede / redirecionar): o clique envia
	var painel := get_tree().get_first_node_in_group("painel_despacho")
	if painel and painel.escolhendo_alvo():
		painel.alvo_escolhido(ev)
		return

	var hud: Node = null

	# 1) Tenta caminho direto Main/HUD
	if get_tree().root.has_node("Main/HUD"):
		hud = get_tree().root.get_node("Main/HUD")
		print("EventManager: HUD encontrada em Main/HUD")
	else:
		# 2) fallback: grupo HUD
		hud = get_tree().get_first_node_in_group("HUD")
		if hud:
			print("EventManager: HUD encontrada pelo grupo 'HUD'")
		else:
			push_error("EventManager: HUD não encontrada (nem Main/HUD nem grupo HUD).")
			return

	if not hud.has_method("show_event_card"):
		push_error("EventManager: HUD encontrada, mas sem método show_event_card().")
		return

	print("EventManager: chamando HUD.show_event_card(...)")
	hud.show_event_card(ev)

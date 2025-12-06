extends Node
## EventManager.gd
## Gera eventos ao longo do dia, controla instâncias e posiciona os marcadores na cidade.

# ------------------------------------------------
# CONFIGURAÇÕES
# ------------------------------------------------

@export var event_library: EventLibrary

## Cena do marcador (arraste EventMarker.tscn no Inspector)
@export var marker_scene: PackedScene

## Centro da cidade para gerar posições aleatórias
@export var city_center: Node3D

## Raio de spawn dos eventos (em torno do city_center)
@export var city_radius: float = 80.0

## Altura inicial do raycast (de cima pra baixo)
@export var spawn_height: float = 200.0

## Quanto acima do chão o marcador deve aparecer
@export var marker_height_offset: float = 1.0

## Quantos eventos por dia
@export var min_events_per_day: int = 1
@export var max_events_per_day: int = 3

# ------------------------------------------------
# VARIÁVEIS INTERNAS
# ------------------------------------------------

var _event_ticks_today: Array[int] = []
var _events_spawned_today: int = 0
var _last_tick: int = -1

# id -> dicionário com dados da instância do evento
var _active_events: Dictionary = {}


# ------------------------------------------------
# READY
# ------------------------------------------------

func _ready() -> void:
	randomize()

	if TimeManager:
		TimeManager.tick.connect(_on_tick)
	else:
		push_error("EventManager: TimeManager autoload não encontrado.")


# ------------------------------------------------
# INTEGRAÇÃO COM O TEMPO
# ------------------------------------------------

func _on_tick(_t, _d, _w, _y, _term) -> void:
	if TimeManager.ticks_per_day <= 0:
		return

	var current_tick := TimeManager.current_tick

	# Detecta virada de dia
	if _last_tick != -1 and current_tick < _last_tick:
		_on_new_day()
		_start_new_day()

	_last_tick = current_tick

	# Se ainda não temos agenda, cria
	if _event_ticks_today.is_empty():
		_start_new_day()

	# Chegou hora de spawnar?
	if _events_spawned_today < _event_ticks_today.size():
		var next_tick := _event_ticks_today[_events_spawned_today]
		if current_tick >= next_tick:
			spawn_random_event()
			_events_spawned_today += 1


func _start_new_day() -> void:
	_event_ticks_today.clear()
	_events_spawned_today = 0

	var tpd := TimeManager.ticks_per_day
	if tpd <= 0:
		return

	var num_events := randi_range(min_events_per_day, max_events_per_day)

	for i in range(num_events):
		var tick := randi_range(0, tpd - 1)
		_event_ticks_today.append(tick)

	_event_ticks_today.sort()

	print("EventManager: Novo dia -> eventos em ticks: ", _event_ticks_today)


func _on_new_day() -> void:
	# Avança um dia na vida de cada evento ativo
	for event_id in _active_events.keys():
		var ev = _active_events[event_id]

		if ev["estado"] != "ativo":
			continue

		ev["dias_restantes_resolver"] -= 1
		ev["dias_restantes_escalar"] -= 1

		if ev["dias_restantes_escalar"] <= 0:
			_escalar_evento(event_id)
		elif ev["dias_restantes_resolver"] <= 0:
			_falhar_evento(event_id)


func _escalar_evento(event_id: String) -> void:
	if not _active_events.has(event_id):
		return

	var ev = _active_events[event_id]
	ev["estado"] = "escalado"

	# Aqui você pode trocar o template, aumentar severidade, criar novo evento etc.
	print("EventManager: evento escalado -> ", event_id)


func _falhar_evento(event_id: String) -> void:
	if not _active_events.has(event_id):
		return

	var ev = _active_events[event_id]
	ev["estado"] = "expirado"

	# Aplicar penalidades, remover marcador, etc.
	print("EventManager: evento expirado sem resolução -> ", event_id)


# ------------------------------------------------
# POSICIONAMENTO – Raycast até o chão
# ------------------------------------------------

func _get_random_city_position() -> Vector3:
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

	var template: EventData = event_library.get_random_event()
	if template == null:
		print("EventManager: ERRO – event_library está vazia.")
		return

	var marker := marker_scene.instantiate() as Area3D
	if marker == null:
		print("EventManager: ERRO – marker_scene não é uma Area3D válida.")
		return

	var pos := _get_random_city_position()
	marker.global_position = pos

	# Cria id único para essa instância
	var event_id := str(Time.get_ticks_msec()) + "_" + str(randi())

	# Salva instância de evento na memória
	var instance := {
		"id": event_id,
		"template": template,
		"dias_restantes_resolver": template.dias_para_resolver,
		"dias_restantes_escalar": template.dias_para_escalar,
		"estado": "ativo",
		"world_position": pos
	}
	_active_events[event_id] = instance

	# Passa o id para o marcador (assumindo que ele tenha essa variável)
	if "event_id" in marker:
		marker.event_id = event_id

	# Conecta clique
	marker.clicked.connect(_on_marker_clicked)

	# Adiciona ao mapa
	get_tree().current_scene.add_child(marker)

	print("EventManager: Evento criado em ", pos, " id = ", event_id, " template = ", template.nome)


# ------------------------------------------------
# CLIQUE NO MARCADOR -> ABRIR HUD
# ------------------------------------------------

func _on_marker_clicked(event_id: String) -> void:
	print("EventManager: marcador clicado id = ", event_id)

	if not _active_events.has(event_id):
		push_error("EventManager: clique em marcador com id desconhecido: " + event_id)
		return

	var ev = _active_events[event_id]
	var template: EventData = ev["template"]

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

	var event_data := {
		"id": event_id,
		"title": template.nome,
		"body": template.descricao,
		"dias_restantes_resolver": ev["dias_restantes_resolver"],
		"dias_restantes_escalar": ev["dias_restantes_escalar"],
		"required_unit_type": template.required_unit_type
	}

	print("EventManager: chamando HUD.show_event_card(...)")
	hud.show_event_card(event_data)

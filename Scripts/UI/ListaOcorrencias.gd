extends CanvasLayer
class_name ListaOcorrencias
##
# HUD de ocorrências:
#   - alerta no topo quando surge uma ocorrência nova
#   - lista das ocorrências em aberto (clicar abre o card e leva a câmera até ela)
##

@export var event_manager: Node
@export var hud: CanvasLayer
@export var max_itens: int = 12
@export var segundos_alerta: float = 4.0

const CORES_INTENSIDADE := [Color(1.0, 0.9, 0.45), Color(1.0, 0.6, 0.25), Color(1.0, 0.35, 0.35)]

var _lista: VBoxContainer
var _alerta: Label
var _ticks: int = 0


func _ready() -> void:
	layer = 15

	var painel := PanelContainer.new()
	painel.position = Vector2(12, 56)
	painel.custom_minimum_size = Vector2(360, 0)
	add_child(painel)
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 10)
	painel.add_child(margem)
	_lista = VBoxContainer.new()
	margem.add_child(_lista)

	_alerta = Label.new()
	_alerta.anchor_left = 0.5
	_alerta.anchor_right = 0.5
	_alerta.offset_top = 60
	_alerta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_alerta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alerta.add_theme_font_size_override("font_size", 26)
	_alerta.add_theme_color_override("font_outline_color", Color.BLACK)
	_alerta.add_theme_constant_override("outline_size", 8)
	add_child(_alerta)
	_alerta.hide()

	if event_manager:
		event_manager.evento_criado.connect(_on_evento_criado)
	TimeManager.tick.connect(func(_a, _b, _c, _d, _e) -> void:
		_ticks += 1
		if _ticks % 10 == 0:
			_atualizar())
	_atualizar()


# só durante a rodada (some no menu, no resumo e na oferta)
func _process(_delta: float) -> void:
	visible = not TimeManager.is_waiting_for_week_start


func _on_evento_criado(ev: EventInstance) -> void:
	var regioes := get_tree().get_first_node_in_group("regioes")
	var local: String = regioes.nome(ev.regiao_id) if regioes and ev.regiao_id != "" else ""
	_alerta.text = "⚠ Nova ocorrência: %s — %s" % [ev.evento_base.nome, local]
	_alerta.add_theme_color_override("font_color", CORES_INTENSIDADE[clampi(ev.evento_base.severidade_inicial, 1, 3) - 1])
	_alerta.show()
	var este := _alerta.text
	get_tree().create_timer(segundos_alerta).timeout.connect(func() -> void:
		if _alerta.text == este:
			_alerta.hide())
	_atualizar.call_deferred()


func _atualizar() -> void:
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()

	var eventos: Array = event_manager.eventos_ativos() if event_manager else []
	var titulo := Label.new()
	titulo.text = "Ocorrências em aberto (%d)" % eventos.size()
	titulo.add_theme_font_size_override("font_size", 18)
	_lista.add_child(titulo)

	# as que estão mais perto de escalar primeiro
	eventos.sort_custom(func(a, b) -> bool: return a.get_tempo_restante_escalar() < b.get_tempo_restante_escalar())
	for i in mini(eventos.size(), max_itens):
		var ev: EventInstance = eventos[i]
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s  •  %s" % [ev.evento_base.nome, _situacao(ev)]
		b.add_theme_color_override("font_color", CORES_INTENSIDADE[clampi(ev.evento_base.severidade_inicial, 1, 3) - 1])
		b.pressed.connect(_abrir.bind(ev))
		_lista.add_child(b)
	if eventos.size() > max_itens:
		var mais := Label.new()
		mais.text = "+ %d" % (eventos.size() - max_itens)
		_lista.add_child(mais)


func _situacao(ev: EventInstance) -> String:
	if ev.estado == GameTypes.EventState.EM_ATENDIMENTO:
		return "em atendimento"
	var ticks: int = ev.get_tempo_restante_escalar()
	var minutos := float(ticks) / TimeManager.ticks_per_day * 1440.0
	var a_caminho := ev.unidades.size()
	return "escala em %dh%02d%s" % [int(minutos) / 60, int(minutos) % 60,
		"  (%d a caminho)" % a_caminho if a_caminho > 0 else ""]


func _abrir(ev: EventInstance) -> void:
	if not is_instance_valid(ev):
		_atualizar()
		return
	var camera := get_viewport().get_camera_3d()
	if camera and camera.has_method("voar_para"):
		camera.voar_para(ev.get_parent().global_position, minf(camera.current_distance, 70.0), 0.8)
	# no modo "escolher destino", clicar na lista também escolhe
	var painel := get_tree().get_first_node_in_group("painel_despacho")
	if painel and painel.escolhendo_alvo():
		painel.alvo_escolhido(ev)
	elif hud and hud.has_method("show_event_card"):
		hud.show_event_card(ev)

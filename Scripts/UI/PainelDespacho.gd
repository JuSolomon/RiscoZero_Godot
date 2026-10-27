extends CanvasLayer
class_name PainelDespacho
##
# Menus de despacho no estilo 911 Operator:
#   - Menu da sede (clicar na sede): viaturas disponíveis e ocupadas; marcar e enviar
#   - Menu da viatura (clicar na viatura): o que está fazendo, voltar para a sede, redirecionar
#   - Modo "escolher destino": depois de Enviar/Redirecionar, o próximo clique numa ocorrência
#     é o destino (Esc cancela)
##

@export var dispatch: DispatchManager
@export var largura: float = 440.0

var _painel: PanelContainer
var _conteudo: VBoxContainer
var _aviso: Label

# O que está aberto: uma sede ou uma viatura
var _sede: UnitBase
var _viatura: Unit
# Viaturas marcadas no menu da sede
var _marcadas: Array[Unit] = []
# Viaturas esperando o clique na ocorrência de destino
var _aguardando: Array[Unit] = []
var _ticks: int = 0


func _ready() -> void:
	layer = 20
	add_to_group("painel_despacho")

	_painel = PanelContainer.new()
	_painel.anchor_top = 1.0
	_painel.anchor_bottom = 1.0
	_painel.offset_left = 12
	_painel.offset_right = 12 + largura
	_painel.offset_bottom = -12
	_painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_painel)
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 14)
	_painel.add_child(margem)
	_conteudo = VBoxContainer.new()
	_conteudo.add_theme_constant_override("separation", 8)
	margem.add_child(_conteudo)
	_painel.hide()

	_aviso = Label.new()
	_aviso.anchor_left = 0.5
	_aviso.anchor_right = 0.5
	_aviso.offset_top = 110
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 24)
	_aviso.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 8)
	add_child(_aviso)
	_aviso.hide()

	if dispatch:
		dispatch.viatura_mudou.connect(func(_u) -> void: _atualizar())
	TimeManager.tick.connect(func(_a, _b, _c, _d, _e) -> void:
		_ticks += 1
		if _ticks % 10 == 0:
			_atualizar())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if escolhendo_alvo():
			_cancelar_escolha()
		elif _painel.visible:
			fechar()
		get_viewport().set_input_as_handled()


# -------------------------------------------------
#  API (chamada ao clicar na sede, na viatura e na ocorrência)
# -------------------------------------------------

func abrir_sede(base: UnitBase) -> void:
	_sede = base
	_viatura = null
	_marcadas.clear()
	_atualizar()


func abrir_viatura(unit: Unit) -> void:
	_viatura = unit
	_sede = null
	_atualizar()


func fechar() -> void:
	_sede = null
	_viatura = null
	_marcadas.clear()
	_painel.hide()


func escolhendo_alvo() -> bool:
	return not _aguardando.is_empty()


## O jogador clicou numa ocorrência enquanto escolhia o destino
func alvo_escolhido(ev: EventInstance) -> void:
	var enviadas := 0
	var sobras: Array[String] = []
	for unit in _aguardando:
		if is_instance_valid(unit) and dispatch.enviar(unit, ev):
			enviadas += 1
		elif is_instance_valid(unit):
			sobras.append(unit.nome())
	_aguardando.clear()
	_marcadas.clear()
	if sobras.is_empty():
		_mostrar_aviso("%d viatura(s) a caminho de %s." % [enviadas, ev.evento_base.nome], 2.5)
	else:
		_mostrar_aviso("%s: esta ocorrência não precisa (mais) desse órgão." % ", ".join(sobras), 3.5)
	_atualizar()


# -------------------------------------------------
#  MONTAGEM DOS MENUS
# -------------------------------------------------

func _atualizar() -> void:
	if _sede and is_instance_valid(_sede):
		_montar_sede()
	elif _viatura and is_instance_valid(_viatura):
		_montar_viatura()
	else:
		_painel.hide()


func _montar_sede() -> void:
	_limpar()
	var regioes := get_tree().get_first_node_in_group("regioes")
	var local: String = regioes.nome(_sede.regiao_id) if regioes and _sede.regiao_id != "" else ""
	_titulo("%s — %s" % [_sede.nome(), local], Unit.CORES[_sede.unit_type])
	_texto("%d de %d viaturas disponíveis" % [_sede.disponiveis(), _sede.unidades.size()])

	# Upgrades em ordem: 1 Frota rápida -> 2 Equipe treinada -> 3 Ampliação
	var sedes := get_tree().get_first_node_in_group("sedes_manager")
	if sedes:
		var feitos: Array[String] = []
		for i in _sede.nivel:
			feitos.append(SedeManager.NOMES_UPGRADE[i])
		_texto("Nível %d/3%s" % [_sede.nivel, "  (" + ", ".join(feitos) + ")" if not feitos.is_empty() else ""], true)
		var proximo: Dictionary = sedes.proximo_upgrade(_sede)
		if not proximo.is_empty():
			var up := Button.new()
			up.text = "Upgrade %d: %s — %s (R$ %d)" % [_sede.nivel + 1, proximo["nome"], proximo["efeito"], proximo["custo"]]
			up.disabled = CityStats.money_total < proximo["custo"]
			up.pressed.connect(func() -> void:
				sedes.fazer_upgrade(_sede)
				_atualizar())
			_conteudo.add_child(up)

	for unit in _sede.unidades:
		var linha := HBoxContainer.new()
		var marcar := CheckBox.new()
		marcar.disabled = not unit.disponivel()
		marcar.button_pressed = unit in _marcadas and unit.disponivel()
		marcar.toggled.connect(func(ligado: bool) -> void:
			if ligado and not unit in _marcadas:
				_marcadas.append(unit)
			elif not ligado:
				_marcadas.erase(unit))
		linha.add_child(marcar)
		var rotulo := Label.new()
		rotulo.text = "%s — %s" % [unit.nome(), _status(unit)]
		rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(rotulo)
		var ver := Button.new()
		ver.text = "Ver"
		ver.disabled = not unit.visible
		ver.pressed.connect(func() -> void: abrir_viatura(unit); _focar(unit.global_position))
		linha.add_child(ver)
		_conteudo.add_child(linha)

	_botoes([
		["Enviar marcadas → clicar na ocorrência", func() -> void:
			var lista: Array[Unit] = []
			for u in _marcadas:
				if is_instance_valid(u) and u.disponivel():
					lista.append(u)
			if lista.is_empty():
				_mostrar_aviso("Marque pelo menos uma viatura disponível.", 2.5)
			else:
				_comecar_escolha(lista)],
		["Fechar", fechar],
	])
	_painel.show()


func _montar_viatura() -> void:
	_limpar()
	_titulo("%s (%s)" % [_viatura.nome(), _viatura.base.nome()], Unit.CORES[_viatura.unit_type])
	_texto(_status(_viatura))
	var em_servico := _viatura.estado == Unit.Estado.INDO or _viatura.estado == Unit.Estado.ESTACIONADO
	if em_servico:
		_texto("Voltar ou redirecionar deixa a ocorrência sem esta viatura e custa popularidade.", true)
	var botoes := []
	if em_servico:
		botoes.append(["Voltar para a sede", func() -> void: dispatch.mandar_voltar(_viatura)])
	if _viatura.visible:
		botoes.append(["Redirecionar → clicar na ocorrência", func() -> void: _comecar_escolha([_viatura])])
	botoes.append(["Ver sede", func() -> void: _focar(_viatura.base.global_position); abrir_sede(_viatura.base)])
	botoes.append(["Fechar", fechar])
	_botoes(botoes)
	_painel.show()


func _status(unit: Unit) -> String:
	var ev := dispatch.evento_da_viatura(unit)
	match unit.estado:
		Unit.Estado.NA_SEDE:
			return "Na sede"
		Unit.Estado.INDO:
			return "A caminho de %s (chega em ~%s)" % [ev.evento_base.nome if ev else "?", _tempo(unit.segundos_restantes())]
		Unit.Estado.ESTACIONADO:
			if ev and ev.estado == GameTypes.EventState.EM_ATENDIMENTO:
				return "No local, atendendo: %s" % ev.evento_base.nome
			return "No local, esperando o resto da equipe: %s" % (ev.evento_base.nome if ev else "?")
		Unit.Estado.VOLTANDO:
			return "Voltando para a sede (~%s) — disponível" % _tempo(unit.segundos_restantes())
	return ""


# segundos reais na velocidade 1x -> tempo de jogo "1h20"
func _tempo(segundos: float) -> String:
	var minutos := segundos / TimeManager.seconds_per_tick / TimeManager.ticks_per_day * 1440.0
	return "%dh%02d" % [int(minutos) / 60, int(minutos) % 60]


# -------------------------------------------------
#  ESCOLHA DO DESTINO
# -------------------------------------------------

func _comecar_escolha(unidades: Array) -> void:
	_aguardando.assign(unidades)
	_mostrar_aviso("Clique na ocorrência de destino para %d viatura(s)  —  Esc cancela" % unidades.size(), 0.0)


func _cancelar_escolha() -> void:
	_aguardando.clear()
	_aviso.hide()


func _mostrar_aviso(texto: String, segundos: float) -> void:
	_aviso.text = texto
	_aviso.show()
	if segundos > 0.0:
		var este := texto
		get_tree().create_timer(segundos).timeout.connect(func() -> void:
			if _aviso.text == este and not escolhendo_alvo():
				_aviso.hide())


# -------------------------------------------------
#  AUXILIARES DE UI
# -------------------------------------------------

func _focar(ponto: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera and camera.has_method("voar_para"):
		camera.voar_para(ponto, minf(camera.current_distance, 60.0), 0.8)


func _limpar() -> void:
	for filho in _conteudo.get_children():
		_conteudo.remove_child(filho)
		filho.queue_free()


func _titulo(texto: String, cor: Color) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", cor.lightened(0.3))
	_conteudo.add_child(l)


func _texto(texto: String, pequeno: bool = false) -> void:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = largura - 40
	if pequeno:
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(1, 0.85, 0.6))
	_conteudo.add_child(l)


func _botoes(lista: Array) -> void:
	for par in lista:
		var b := Button.new()
		b.text = par[0]
		b.pressed.connect(par[1])
		_conteudo.add_child(b)

extends CanvasLayer
class_name ConstrucaoUI
##
# Menu de construção de sedes (funciona com o jogo pausado ou com o relógio correndo):
#   1. botão "Construir sede" na barra do topo
#   2. escolher o órgão (mostra o custo)
#   3. a prévia segue o mouse, presa ao cruzamento de rua mais próximo:
#      verde = pode construir; vermelha = mostra o motivo
#   4. clique esquerdo constrói; clique direito ou Esc cancela
##

@export var sedes: SedeManager
@export var road_network: RoadNetwork

var _botao: Button
var _painel: PanelContainer
var _lista: VBoxContainer
var _tipo_escolhido: int = -1
var _previa: Node3D
var _previa_material: StandardMaterial3D
var _previa_texto: Label3D
var _posicao: Vector3 = Vector3.INF
var _regiao: String = ""


func _ready() -> void:
	layer = 25
	add_to_group("construcao")

	_botao = Button.new()
	_botao.text = "Construir sede"
	_botao.position = Vector2(520, 4)
	_botao.custom_minimum_size = Vector2(170, 34)
	_botao.pressed.connect(func() -> void: fechar() if _painel.visible else abrir())
	add_child(_botao)

	_painel = PanelContainer.new()
	_painel.anchor_left = 1.0
	_painel.anchor_right = 1.0
	_painel.anchor_top = 1.0
	_painel.anchor_bottom = 1.0
	_painel.offset_left = -400
	_painel.offset_right = -12
	_painel.offset_bottom = -12
	_painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_painel)
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 14)
	_painel.add_child(margem)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 6)
	margem.add_child(_lista)
	_painel.hide()

	CityStats.mudou.connect(func() -> void:
		if _painel.visible and _tipo_escolhido < 0:
			_montar())


func _process(_delta: float) -> void:
	# o botão só aparece quando há uma subprefeitura sob comando
	var regioes := get_tree().get_first_node_in_group("regioes")
	_botao.visible = regioes != null and not regioes.desbloqueadas.is_empty()
	if _tipo_escolhido >= 0:
		_mover_previa()


func _unhandled_input(event: InputEvent) -> void:
	if _tipo_escolhido < 0:
		if event.is_action_pressed("ui_cancel") and _painel.visible:
			fechar()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			confirmar()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancelar_posicionamento()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_cancelar_posicionamento()
		get_viewport().set_input_as_handled()


# -------------------------------------------------
#  API
# -------------------------------------------------

func abrir() -> void:
	_montar()
	_painel.show()


func fechar() -> void:
	_cancelar_posicionamento()
	_painel.hide()


func posicionando() -> bool:
	return _tipo_escolhido >= 0


## Começa a posicionar uma sede do órgão (também usado pelos testes)
func escolher(tipo: int) -> void:
	_tipo_escolhido = tipo
	_criar_previa()
	_montar()


## Move a prévia para um ponto do mapa (o mouse faz isso sozinho)
func mover_para(ponto: Vector3) -> void:
	_posicao = road_network.ponto_mais_proximo(ponto) if road_network else ponto
	_regiao = road_network.regiao_perto_de(_posicao) if road_network else ""
	_atualizar_previa()


## Constrói no ponto atual da prévia
func confirmar() -> void:
	if _posicao == Vector3.INF:
		return
	var motivo := sedes.motivo_nao_construir(_tipo_escolhido, _regiao)
	if motivo != "":
		return
	var base := sedes.construir(_tipo_escolhido, _posicao, _regiao)
	if base:
		_cancelar_posicionamento()
		fechar()


# -------------------------------------------------
#  MENU
# -------------------------------------------------

func _montar() -> void:
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()
	var titulo := Label.new()
	titulo.text = "Construir sede — R$ %d" % CityStats.config.custo_sede
	titulo.add_theme_font_size_override("font_size", 20)
	_lista.add_child(titulo)

	if _tipo_escolhido >= 0:
		var dica := Label.new()
		dica.text = "Posicione a sede de %s no mapa.\nClique esquerdo constrói; direito ou Esc cancela." \
			% GameTypes.UnitDict[_tipo_escolhido]
		dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lista.add_child(dica)
	else:
		var regioes := get_tree().get_first_node_in_group("regioes")
		if regioes:
			for id in regioes.desbloqueadas:
				var vagas := Label.new()
				vagas.text = "%s: %d de %d vagas livres" % [regioes.nome(id), sedes.vagas_livres(id), sedes.vagas_total(id)]
				vagas.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
				_lista.add_child(vagas)
		var manut := Label.new()
		manut.text = "Manutenção: R$ %d por sede + R$ %d por viatura, por semana" \
			% [CityStats.config.manutencao_por_sede, CityStats.config.manutencao_por_viatura]
		manut.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		manut.add_theme_font_size_override("font_size", 13)
		_lista.add_child(manut)
		for tipo in GameTypes.UnitDict:
			var b := Button.new()
			b.text = GameTypes.UnitDict[tipo]
			b.add_theme_color_override("font_color", Unit.CORES[tipo].lightened(0.2))
			b.disabled = CityStats.money_total < CityStats.config.custo_sede
			b.pressed.connect(escolher.bind(tipo))
			_lista.add_child(b)

	var fechar_b := Button.new()
	fechar_b.text = "Cancelar" if _tipo_escolhido >= 0 else "Fechar"
	fechar_b.pressed.connect(func() -> void: _cancelar_posicionamento() if _tipo_escolhido >= 0 else fechar())
	_lista.add_child(fechar_b)


# -------------------------------------------------
#  PRÉVIA NO MAPA
# -------------------------------------------------

func _criar_previa() -> void:
	if _previa:
		_previa.queue_free()
	_previa = Node3D.new()
	_previa.name = "PreviaSede"
	var pino := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 1.2
	cilindro.bottom_radius = 1.4
	cilindro.height = 0.6
	pino.mesh = cilindro
	pino.position.y = 0.3
	_previa_material = StandardMaterial3D.new()
	_previa_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_previa_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pino.material_override = _previa_material
	_previa.add_child(pino)
	_previa_texto = Label3D.new()
	_previa_texto.font_size = 40
	_previa_texto.pixel_size = 0.0005
	_previa_texto.fixed_size = true
	_previa_texto.no_depth_test = true
	_previa_texto.outline_size = 10
	_previa_texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_previa_texto.position.y = 2.5
	_previa.add_child(_previa_texto)
	get_tree().current_scene.add_child(_previa)
	_posicao = Vector3.INF


func _mover_previa() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var origem := camera.project_ray_origin(mouse)
	var direcao := camera.project_ray_normal(mouse)
	if absf(direcao.y) < 0.0001:
		return
	var t := -origem.y / direcao.y
	if t > 0.0:
		mover_para(origem + direcao * t)


func _atualizar_previa() -> void:
	if _previa == null or _posicao == Vector3.INF:
		return
	_previa.global_position = _posicao
	var motivo := sedes.motivo_nao_construir(_tipo_escolhido, _regiao)
	var ok := motivo == ""
	_previa_material.albedo_color = Color(0.3, 1.0, 0.4, 0.75) if ok else Color(1.0, 0.3, 0.3, 0.75)
	_previa_texto.modulate = Color(0.6, 1.0, 0.6) if ok else Color(1.0, 0.6, 0.6)
	_previa_texto.text = ("Sede %s — clique para construir" % GameTypes.UnitDict[_tipo_escolhido]) if ok else motivo


func _cancelar_posicionamento() -> void:
	_tipo_escolhido = -1
	_posicao = Vector3.INF
	if _previa:
		_previa.queue_free()
		_previa = null
	if _painel.visible:
		_montar()

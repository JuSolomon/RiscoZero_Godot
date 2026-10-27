extends CanvasLayer
class_name TelaMVP
##
# Tela de painel central usada no fluxo do MVP (menu, resumo, oferta, fim).
# O GameManager monta o conteúdo com mostrar(titulo, texto, botoes).
##

@export var tamanho_titulo: int = 44
@export var tamanho_texto: int = 26
@export var tamanho_botao: int = 26

var _fundo: ColorRect
var _titulo: Label
var _texto: RichTextLabel
var _botoes: GridContainer
var _centro: Container
var _painel: PanelContainer


func _ready() -> void:
	layer = 90
	_fundo = ColorRect.new()
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.color = Color(0, 0, 0, 0.45)
	add_child(_fundo)

	_centro = VBoxContainer.new()
	_centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_centro.alignment = BoxContainer.ALIGNMENT_CENTER
	_fundo.add_child(_centro)

	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(900, 0)
	painel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_centro.add_child(painel)
	_painel = painel

	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 32)
	painel.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 20)
	margem.add_child(coluna)

	_titulo = Label.new()
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_size_override("font_size", tamanho_titulo)
	coluna.add_child(_titulo)

	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.add_theme_font_size_override("normal_font_size", tamanho_texto)
	_texto.add_theme_font_size_override("bold_font_size", tamanho_texto)
	coluna.add_child(_texto)

	_botoes = GridContainer.new()
	_botoes.add_theme_constant_override("h_separation", 12)
	_botoes.add_theme_constant_override("v_separation", 12)
	coluna.add_child(_botoes)

	hide()


## botoes: Array de [texto, Callable] ou [texto, Callable, dica ao passar o mouse]
## embaixo = true deixa o meio da tela livre para ver o mapa
func mostrar(titulo: String, texto: String, botoes: Array, colunas: int = 1, escurecer: bool = true, embaixo: bool = false) -> void:
	_centro.alignment = BoxContainer.ALIGNMENT_END if embaixo else BoxContainer.ALIGNMENT_CENTER
	_centro.add_theme_constant_override("separation", 0)
	_painel.custom_minimum_size.x = 1100 if embaixo else 900
	_titulo.text = titulo
	_texto.text = texto
	_texto.visible = texto != ""
	_fundo.color.a = 0.45 if escurecer else 0.0
	_botoes.columns = colunas
	for b in _botoes.get_children():
		b.queue_free()
	for par in botoes:
		var botao := Button.new()
		botao.text = par[0]
		botao.custom_minimum_size = Vector2(0, 56)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.add_theme_font_size_override("font_size", tamanho_botao)
		botao.pressed.connect(par[1])
		if par.size() > 2:
			botao.tooltip_text = par[2]
		_botoes.add_child(botao)
	show()


func fechar() -> void:
	hide()


## Para testes: aperta o botão pelo texto
func apertar(texto: String) -> void:
	for b in _botoes.get_children():
		if b is Button and b.text == texto and not b.is_queued_for_deletion():
			b.pressed.emit()
			return
	push_error("TelaMVP: botão não encontrado: " + texto)

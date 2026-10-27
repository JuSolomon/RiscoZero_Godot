extends CanvasLayer
class_name PainelPreparacao
##
# Preparação da semana (sem pressão de tempo; o relógio só começa em "Iniciar semana").
# Não bloqueia o mapa: dá para clicar nas sedes (upgrades) e construir sedes enquanto ela está aberta.
##

signal iniciar_semana

var _painel: PanelContainer
var _texto: RichTextLabel


func _ready() -> void:
	layer = 18
	_painel = PanelContainer.new()
	_painel.anchor_left = 1.0
	_painel.anchor_right = 1.0
	_painel.offset_left = -470
	_painel.offset_right = -12
	_painel.offset_top = 56
	add_child(_painel)
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 16)
	_painel.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	margem.add_child(coluna)
	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.custom_minimum_size = Vector2(430, 0)
	coluna.add_child(_texto)
	var iniciar := Button.new()
	iniciar.text = "Iniciar semana"
	iniciar.custom_minimum_size = Vector2(0, 48)
	iniciar.add_theme_font_size_override("font_size", 22)
	iniciar.pressed.connect(func() -> void:
		hide()
		iniciar_semana.emit())
	coluna.add_child(iniciar)
	hide()


## Monta o texto da semana. `relatorio` vazio = primeira semana.
func mostrar(semana: int, regiao_nome: String, relatorio: String) -> void:
	var eventos := get_tree().get_first_node_in_group("eventos")
	var sedes := get_tree().get_first_node_in_group("sedes_manager")
	var regioes := get_tree().get_first_node_in_group("regioes")
	var c := CityStats.config

	var t := "[font_size=26][b]Preparação — Semana %d[/b][/font_size]\n" % semana
	if relatorio == "":
		t += "Primeira semana como subprefeito em [b]%s[/b]. Boa sorte.\n" % regiao_nome
	else:
		t += "[b]Semana anterior[/b]\n%s\n" % relatorio

	t += "\n[b]Previsão do clima[/b]\n"
	for i in eventos.previsao.size():
		var clima: int = eventos.previsao[i]
		var cor := "#ffd36b" if clima == GameTypes.Clima.CALOR else ("#9fd0ff" if clima >= GameTypes.Clima.CHUVA else "#ffffff")
		t += "Dia %d: [color=%s]%s[/color]%s\n" % [i + 1, cor, GameTypes.ClimaDict[clima],
			"  ⚠ risco de enchentes e deslizamentos" if clima == GameTypes.Clima.TEMPORAL else ""]
	t += "\nOcorrências esperadas: [b]~%d[/b]\n" % eventos.eventos_previstos()

	var subs: int = regioes.desbloqueadas.size()
	t += "\n[b]Caixa:[/b] R$ %s\n" % _dinheiro(CityStats.money_total)
	t += "No fim da semana: arrecadação +R$ %s, manutenção −R$ %s\n" % [
		_dinheiro(c.arrecadacao_por_subprefeitura * subs), _dinheiro(sedes.manutencao_semanal())]
	t += "\n[color=#c0c0c0]Clique numa sede para ver as viaturas e fazer upgrades, ou use \"Construir sede\". " \
		+ "Dá para fazer isso também durante a semana.[/color]"
	_texto.text = t
	show()


func _dinheiro(valor: int) -> String:
	var s := str(absi(valor))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if valor < 0 else "") + s + out

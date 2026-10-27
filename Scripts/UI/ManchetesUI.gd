extends CanvasLayer
class_name ManchetesUI
##
# Resumo diário em forma de manchete de jornal fictício.
# Aparece no fim de cada dia por alguns segundos e NÃO pausa o jogo.
# Ex.: "PREFEITURA DEMORA E BUEIROS ENTUPIDOS VIRAM ENCHENTE NA ZONA NORTE 3"
#      Dia 3: 2 resolvidas, 1 agravada • popularidade −3 • R$ −4.000
##

@export var event_manager: Node
@export var segundos_na_tela: float = 7.0

var _painel: PanelContainer
var _jornal: Label
var _manchete: Label
var _linha: Label

# o que aconteceu no dia
var _resolvidas: Array = []
var _escaladas: Array = []   # [antigo_nome, novo_nome, regiao]
var _falhas: Array = []      # [nome, regiao, mortes]
var _dinheiro_inicio: int = 0
var _pop_inicio: float = 0.0


func _ready() -> void:
	layer = 16
	_painel = PanelContainer.new()
	_painel.anchor_left = 0.5
	_painel.anchor_right = 0.5
	_painel.anchor_top = 1.0
	_painel.anchor_bottom = 1.0
	_painel.offset_left = -430
	_painel.offset_right = 430
	_painel.offset_bottom = -16
	_painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.96, 0.94, 0.88)
	estilo.border_color = Color(0.2, 0.2, 0.2)
	estilo.set_border_width_all(2)
	estilo.set_content_margin_all(14)
	_painel.add_theme_stylebox_override("panel", estilo)
	add_child(_painel)
	var coluna := VBoxContainer.new()
	_painel.add_child(coluna)
	_jornal = _rotulo(coluna, 14, Color(0.35, 0.35, 0.35))
	_manchete = _rotulo(coluna, 26, Color(0.08, 0.08, 0.08))
	_linha = _rotulo(coluna, 16, Color(0.25, 0.25, 0.25))
	_painel.hide()

	if event_manager:
		event_manager.evento_resolvido.connect(func(ev) -> void: _resolvidas.append([ev.evento_base.nome, _regiao(ev)]))
		event_manager.evento_escalado.connect(func(a, n) -> void: _escaladas.append([a.evento_base.nome, n.evento_base.nome, _regiao(n)]))
		event_manager.evento_falhou.connect(func(ev, m) -> void: _falhas.append([ev.evento_base.nome, _regiao(ev), m]))
	# adiado: no último dia, a semana termina logo depois e a manchete não deve aparecer sobre o resumo
	TimeManager.new_day_started.connect(func(dia, _s, _a, _m) -> void: _fim_do_dia.call_deferred(dia))
	_zerar()


func _rotulo(pai: Node, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 820
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	pai.add_child(l)
	return l


func _zerar() -> void:
	_resolvidas.clear()
	_escaladas.clear()
	_falhas.clear()
	_dinheiro_inicio = CityStats.money_total
	_pop_inicio = CityStats.popularity_current


func _regiao(ev) -> String:
	var regioes := get_tree().get_first_node_in_group("regioes")
	return regioes.nome(ev.regiao_id) if regioes and ev.regiao_id != "" else "cidade"


# -------------------------------------------------
#  MANCHETE
# -------------------------------------------------

func _fim_do_dia(dia: int) -> void:
	# fim da semana: o resumo semanal é que conta a história
	if TimeManager.is_waiting_for_week_start:
		_painel.hide()
		_zerar()
		return
	var manchete := manchete_do_dia()
	var delta_pop := roundi(CityStats.popularity_current - _pop_inicio)
	var delta_din := CityStats.money_total - _dinheiro_inicio
	_jornal.text = "O DIÁRIO CARIOCA  •  DIA %d" % dia
	_manchete.text = manchete.to_upper()
	_linha.text = "%d resolvida%s, %d agravada%s, %d sem solução  •  popularidade %+d  •  R$ %s" % [
		_resolvidas.size(), "" if _resolvidas.size() == 1 else "s",
		_escaladas.size(), "" if _escaladas.size() == 1 else "s", _falhas.size(),
		delta_pop, ("+" if delta_din >= 0 else "−") + str(absi(delta_din))]
	_zerar()
	_painel.show()
	var este := _manchete.text
	get_tree().create_timer(segundos_na_tela).timeout.connect(func() -> void:
		if _manchete.text == este:
			_painel.hide())


## A notícia mais importante do dia (mortes > falhas > escaladas > resolvidas > dia calmo)
func manchete_do_dia() -> String:
	var mortes := 0
	var pior: Array = []
	for f in _falhas:
		if pior.is_empty() or f[2] > pior[2]:
			pior = f
		mortes += f[2]
	if mortes > 0:
		return ["Tragédia em %s: %s termina com %d morto%s" % [pior[1], pior[0].to_lower(), pior[2], "" if pior[2] == 1 else "s"],
			"%s deixa %d vítima%s em %s; oposição pede explicações" % [pior[0], pior[2], "" if pior[2] == 1 else "s", pior[1]]].pick_random()
	if not _falhas.is_empty():
		var f: Array = _falhas.pick_random()
		return ["%s fica sem solução em %s e moradores reclamam do abandono" % [f[0], f[1]],
			"Ninguém apareceu: %s segue sem resposta em %s" % [f[0].to_lower(), f[1]]].pick_random()
	if not _escaladas.is_empty():
		var e: Array = _escaladas.pick_random()
		return ["Prefeitura demora e %s vira %s em %s" % [e[0].to_lower(), e[1].to_lower(), e[2]],
			"Da demora ao caos: %s em %s" % [e[1].to_lower(), e[2]]].pick_random()
	if not _resolvidas.is_empty():
		var r: Array = _resolvidas.pick_random()
		if _resolvidas.size() >= 3:
			return "Dia produtivo: prefeitura resolve %d ocorrências e cariocas desconfiam" % _resolvidas.size()
		return ["Eficiência: prefeitura resolve %s em %s" % [r[0].to_lower(), r[1]],
			"Até que enfim! %s resolvido em %s" % [r[0], r[1]]].pick_random()
	var abertas: int = event_manager.eventos_ativos().size() if event_manager else 0
	if abertas >= 3:
		return "%d ocorrências em aberto: vereadores cobram o subprefeito" % abertas
	return ["Dia tranquilo no Rio; subprefeito é visto tomando mate na praia",
		"Nada de novo no front: cariocas reclamam só do calor",
		"Sem crises hoje. A imprensa, entediada, publica receita de biscoito Globo"].pick_random()

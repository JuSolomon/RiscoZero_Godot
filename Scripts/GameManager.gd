extends Node
class_name GameManager

##
# GameManager
# Fluxo do MVP:
#   MENU (escolhe a subprefeitura ou sorteia)
#   -> JOGANDO (rodada de N dias, eventos só nas regiões desbloqueadas)
#   -> RESUMO (nota de aproveitamento)
#        nota < mínima: "Tentar de novo" recomeça na mesma região
#   -> OFERTA (subprefeitura vizinha sorteada: aceitar ou recusar)
#   -> REVELACAO (nuvens se abrem sobre a região oferecida)
#   -> FIM_MVP
##

enum GameState { MENU, PLAYING, RESUMO, OFERTA, REVELACAO, FIM_MVP }

@export var hud: CanvasLayer
@export var tela: TelaMVP
@export var regioes: RegionManager
@export var event_manager: Node
@export var camera: Camera3D

var state: GameState = GameState.MENU
var _regiao_ofertada: String = ""

signal state_changed(new_state: GameState, old_state: GameState)


func _ready() -> void:
	# Espera o mapa e as telas (que vêm depois na árvore) ficarem prontos
	_preparar.call_deferred()


func _preparar() -> void:
	TimeManager.reset_time()
	TimeManager.days_per_week = CityStats.config.dias_por_rodada
	CityStats.nova_rodada()
	TimeManager.week_ended.connect(_on_rodada_terminou)

	regioes.cobrir_todas()
	camera.enable_limits = false
	camera.focus_point = Vector3(-30, 0, 0)
	camera.current_distance = 420.0

	# "Tentar de novo" recarrega a cena e volta direto para a mesma região
	if RegionManager.regiao_para_reiniciar != "":
		var id := RegionManager.regiao_para_reiniciar
		RegionManager.regiao_para_reiniciar = ""
		_iniciar(id)
	else:
		_mostrar_menu()


func _change_state(new_state: GameState) -> void:
	var old := state
	state = new_state
	state_changed.emit(new_state, old)


# -------------------------------------------------
#  MENU
# -------------------------------------------------

func _mostrar_menu() -> void:
	_change_state(GameState.MENU)
	var botoes := []
	var ids: Array = regioes.mapa.ids_regioes()
	ids.sort_custom(func(a, b): return regioes.nome(a) < regioes.nome(b))
	for id in ids:
		var sub := regioes.dados(id)
		botoes.append([sub.nome, _iniciar.bind(id), "%s\n\nPopulação: ~%s mil • Dificuldade: %s" % [
			sub.descricao, sub.populacao / 1000, GameTypes.DificuldadeDict[sub.dificuldade(CityStats.config)]]])
	botoes.append(["Aleatória", func() -> void: _iniciar(ids.pick_random())])
	tela.mostrar("Risco Zero",
		"[center]Você é o novo subprefeito. Escolha a subprefeitura onde vai começar o seu mandato.[/center]",
		botoes, 3, false)


func _iniciar(id: String) -> void:
	tela.fechar()
	regioes.desbloquear(id, false)
	camera.definir_limites(regioes.limites_desbloqueados())
	camera.voar_para(regioes.mapa.centro_regiao(id), 110.0, 2.0)
	_change_state(GameState.PLAYING)
	TimeManager.iniciar_rodada()
	print("GameManager: rodada iniciada em ", regioes.nome(id))


# -------------------------------------------------
#  FIM DA RODADA
# -------------------------------------------------

func _on_rodada_terminou(_semana: int, _ano: int, _mandato: int) -> void:
	if state != GameState.PLAYING:
		return
	_change_state(GameState.RESUMO)
	var nota := CityStats.calcular_nota(event_manager.contar_pendentes_escalados())
	event_manager.limpar_eventos()
	hud.fechar_card()

	var texto := _texto_resumo(nota)
	if nota["aprovado"]:
		tela.mostrar("Fim da semana: bom trabalho!", texto,
			[["Ver proposta da prefeitura", _mostrar_oferta]])
	else:
		texto += "\n[center][color=#ff8080]Desempenho insuficiente: a anexação não foi oferecida.[/color][/center]"
		tela.mostrar("Fim da semana", texto, [["Tentar de novo", _tentar_de_novo]])


func _texto_resumo(nota: Dictionary) -> String:
	var c := CityStats.config
	var cor := "#80ff80" if nota["aprovado"] else "#ff8080"
	var t := "[center][font_size=40][b][color=%s]Aproveitamento: %d[/color][/b][/font_size]  (mínimo %d)[/center]\n" \
		% [cor, roundi(nota["final"]), roundi(c.nota_minima)]
	t += "[table=3]"
	t += _linha("Atendimento", nota["atendimento"], c.peso_atendimento,
		"%d a tempo, %d após escalar, %d falhas%s" % [CityStats.resolvidas_a_tempo, CityStats.resolvidas_apos_escalar,
		CityStats.falhas, "" if nota["pendentes_escalados"] == 0 else ", %d escaladas sem atendimento" % nota["pendentes_escalados"]])
	t += _linha("Mortes", nota["mortes"], c.peso_mortes, "%d mortes" % CityStats.mortes)
	t += _linha("Finanças", nota["financas"], c.peso_financas,
		"gastou R$ %s de R$ %s" % [_dinheiro(CityStats.gastos), _dinheiro(c.orcamento_rodada)])
	t += _linha("Popularidade", nota["popularidade"], c.peso_popularidade,
		"%d%% → %d%% (%+d)" % [roundi(CityStats.popularidade_inicio), roundi(CityStats.popularity_current),
		roundi(nota["variacao_popularidade"])])
	t += "[/table]"
	return t


func _linha(nome: String, nota: float, peso: float, detalhe: String) -> String:
	return "[cell][b]%s[/b]  [/cell][cell]%d  (peso %d%%)  [/cell][cell][color=#c0c0c0]%s[/color][/cell]" \
		% [nome, roundi(nota), roundi(peso * 100), detalhe]


func _dinheiro(valor: int) -> String:
	var s := str(absi(valor))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if valor < 0 else "") + s + out


func _tentar_de_novo() -> void:
	RegionManager.regiao_para_reiniciar = regioes.desbloqueadas[0]
	get_tree().reload_current_scene()


# -------------------------------------------------
#  OFERTA E REVELAÇÃO
# -------------------------------------------------

func _mostrar_oferta() -> void:
	_regiao_ofertada = regioes.sortear_oferta()
	if _regiao_ofertada == "":
		_mostrar_fim("Você já comanda todas as regiões vizinhas.")
		return
	_change_state(GameState.OFERTA)
	var atual := regioes.nome(regioes.desbloqueadas[0])
	var nova := regioes.nome(_regiao_ofertada)
	var dados := regioes.mapa.get_regiao(_regiao_ofertada)

	camera.enable_limits = false
	var meio: Vector3 = (regioes.mapa.centro_regiao(regioes.desbloqueadas[0]) + regioes.mapa.centro_regiao(_regiao_ofertada)) / 2.0
	camera.voar_para(meio, 220.0, 2.0)

	tela.mostrar("Proposta de anexação",
		("[center]O prefeito ficou satisfeito com o seu trabalho em [b]%s[/b] e oferece a subprefeitura vizinha:\n\n" +
		"[font_size=36][b]%s[/b][/font_size]\n(%s km², oficialmente \"%s\")\n\n%s\n\n" +
		"Mais território significa mais demandas — e mais responsabilidade.[/center]")
		% [atual, nova, str(dados["area_km2"]).replace(".", ","), dados["nome_oficial"],
		regioes.dados(_regiao_ofertada).descricao],
		[["Aceitar", _responder_oferta.bind(true)], ["Recusar", _responder_oferta.bind(false)]], 2, false, true)


func _responder_oferta(aceitou: bool) -> void:
	tela.fechar()
	_change_state(GameState.REVELACAO)
	var id := _regiao_ofertada
	camera.voar_para(regioes.mapa.centro_regiao(id), 160.0, 1.5)
	await get_tree().create_timer(1.6).timeout

	regioes.mapa.revelacao_terminada.connect(func(_id) -> void:
		var nome := regioes.nome(id)
		if aceitou:
			_mostrar_fim("[b]%s[/b] agora faz parte do seu comando. A região chega sem sedes: construí-las será o seu próximo desafio." % nome)
		else:
			_mostrar_fim("Você recusou [b]%s[/b] e manteve o foco na sua subprefeitura. A região segue com outra gestão." % nome),
		CONNECT_ONE_SHOT)
	if aceitou:
		regioes.desbloquear(id, true, false)
	else:
		regioes.mapa.revelar(id)


func _mostrar_fim(texto: String) -> void:
	_change_state(GameState.FIM_MVP)
	tela.mostrar("Fim do MVP",
		"[center]%s\n\nNo jogo completo, cada nova anexação libera mais um pedaço do Rio até a cidade inteira estar sob o seu comando.\n\nObrigado por jogar![/center]" % texto,
		[["Jogar de novo", func() -> void: get_tree().reload_current_scene()], ["Sair", func() -> void: get_tree().quit()]],
		2, false, true)

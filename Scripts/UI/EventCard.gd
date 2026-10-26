extends Control
class_name EventCard

var tags: Array[Label]
var valores: Array[Label]
var title: Label
var body: Label
var close_button: Button
var enviar_button: Button
var avisos: RichTextLabel
var evento_atual: EventInstance = null

func _ready() -> void:
	var tags_master = find_child("Tags", true, false)
	for l in tags_master.get_children():
		if l.is_class("Label"):
			tags.append(l)

	var valores_master = find_child("Valores", true, false)
	for l in valores_master.get_children():
		if l.is_class("Label"):
			valores.append(l)
	
	title = find_child("TitleLabel", true, false)
	body = find_child("BodyLabel", true, false)
	
	close_button = find_child("CloseButton", true, false)
	enviar_button = find_child("EnviarButton", true, false)
	avisos = find_child("Avisos", true, false)
	enviar_button.pressed.connect(_on_enviar_pressed)

func setup_completo(event: EventInstance):
	_desconectar_evento()
	evento_atual = event

	tags[0].text = 'Tempo para escalar'
	tags[1].text = 'Tempo para resolver'
	tags[2].text = 'Órgão responsável'
	
	valores[0].text = _formatar_ticks(event.get_tempo_restante_escalar())
	valores[1].text = _formatar_ticks(TimeManager.ticks_per_day * event.dias_para_resolver - event.ticks_para_resolver)
	valores[2].text = str(GameTypes.UnitDict[event.evento_base.required_unit_type])
	
	title.text = event.evento_base.nome
	body.text = event.evento_base.descricao
	
	event.progresso_evento_escalar.connect(_on_progresso_evento_escalar)
	event.progresso_evento_resolver.connect(_on_progresso_evento_resolver)
	event.tree_exiting.connect(_on_evento_removido)
	_atualizar_despacho()


# Desfaz as conexões com o evento mostrado antes, para o card não misturar contadores
func _desconectar_evento() -> void:
	if evento_atual and is_instance_valid(evento_atual):
		if evento_atual.progresso_evento_escalar.is_connected(_on_progresso_evento_escalar):
			evento_atual.progresso_evento_escalar.disconnect(_on_progresso_evento_escalar)
		if evento_atual.progresso_evento_resolver.is_connected(_on_progresso_evento_resolver):
			evento_atual.progresso_evento_resolver.disconnect(_on_progresso_evento_resolver)
		if evento_atual.tree_exiting.is_connected(_on_evento_removido):
			evento_atual.tree_exiting.disconnect(_on_evento_removido)
	evento_atual = null


# O evento foi resolvido, escalou ou expirou: o card não tem mais o que mostrar
func _on_evento_removido() -> void:
	_desconectar_evento()
	visible = false


func _formatar_ticks(ticks_restantes: int) -> String:
	ticks_restantes = max(ticks_restantes, 0)
	var t_minutes = float(ticks_restantes) / float(TimeManager.ticks_per_day) * 24 * 60
	return "%02dd %02dh %02dm" % [
		ticks_restantes / TimeManager.ticks_per_day,
		int(t_minutes / 60) % 24,
		int(t_minutes) % 60
		]


func _on_progresso_evento_escalar(_progresso_atual_ticks: int, progresso_restante_ticks):
	valores[0].text = _formatar_ticks(progresso_restante_ticks)
	_atualizar_despacho()
	
func _on_progresso_evento_resolver(_progresso_atual_ticks: int, progresso_restante_ticks):
	valores[1].text = _formatar_ticks(progresso_restante_ticks)
	_atualizar_despacho()


# ------------------------------------------------
# ENVIO DE EQUIPE
# ------------------------------------------------

func _on_enviar_pressed() -> void:
	var dispatch := get_tree().get_first_node_in_group("dispatch")
	if dispatch and evento_atual and is_instance_valid(evento_atual):
		dispatch.despachar(evento_atual)
	_atualizar_despacho()


# Habilita o botão só quando dá para enviar; senão explica o motivo
func _atualizar_despacho() -> void:
	if evento_atual == null or not is_instance_valid(evento_atual):
		return
	var dispatch := get_tree().get_first_node_in_group("dispatch")
	var motivo: String = "Sistema de despacho não encontrado." if dispatch == null else dispatch.motivo_bloqueio(evento_atual)
	enviar_button.disabled = motivo != ""
	avisos.text = motivo

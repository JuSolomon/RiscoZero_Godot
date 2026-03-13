extends Control
class_name EventCard

var tags: Array[Label]
var valores: Array[Label]
var title: Label
var body: Label
var close_button: Button

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

func setup_completo(event: EventInstance):	
	tags[0].text = 'Dias para resolver'
	tags[1].text = 'Dias para escalar'
	tags[2].text = 'Órgão responsável'
	
	valores[0].text = "%02dd 00h 00m" % event.dias_para_escalar
	valores[1].text = "%02dd 00h 00m" % event.dias_para_resolver
	valores[2].text = str(GameTypes.UnitDict[event.evento_base.required_unit_type])
	
	title.text = event.evento_base.nome
	body.text = event.evento_base.descricao
	
	event.progresso_evento_escalar.connect(_on_progresso_evento_escalar)
	event.progresso_evento_resolver.connect(_on_progresso_evento_resolver)


func _on_progresso_evento_escalar(progresso_atual_ticks: int, progresso_restante_ticks):
	var t_minutes = float(progresso_restante_ticks) / float(TimeManager.ticks_per_day) * 24 * 60
	
	valores[0].text = "%02dd %02dh %02dm" % [
		progresso_restante_ticks/TimeManager.ticks_per_day,
		int(t_minutes / 60) % 24,
		int(t_minutes) % 60
		]
	
func _on_progresso_evento_resolver(progresso_atual_ticks: int, progresso_restante_ticks):
	var t_minutes = float(progresso_restante_ticks) / float(TimeManager.ticks_per_day) * 24 * 60
	
	valores[1].text = "%02dd %02dh %02dm" % [
		progresso_restante_ticks/TimeManager.ticks_per_day,
		int(t_minutes / 60) % 24,
		int(t_minutes) % 60
		]

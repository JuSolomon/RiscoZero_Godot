extends Node3D
class_name Unit

# Pega os enums (COMLURB, CET, SAMU, etc.)
const GameTypes = preload("res://Scripts/game_types.gd")

@export var unit_type: int = GameTypes.UnitType.SAMU
@export var move_speed: float = 10.0

var _has_target: bool = false
var _target_position: Vector3 = Vector3.ZERO
var _current_event_id: String = ""


func _ready() -> void:
	# Só pra debug
	print("Unit pronta. Tipo =", _get_unit_type_name(unit_type))


func _physics_process(delta: float) -> void:
	if not _has_target:
		return

	var dir := _target_position - global_position
	var distance := dir.length()

	# Chegou no destino
	if distance < 1.0:
		_has_target = false
		_on_reached_target()
		return

	dir = dir.normalized()
	global_position += dir * move_speed * delta


# ------------------------------------------------
# API PÚBLICA – para o DispatchManager / GameManager
# ------------------------------------------------

func dispatch_to(event_id: String, world_position: Vector3) -> void:
	# Chame isso quando quiser mandar o carrinho pra um evento
	_current_event_id = event_id
	_target_position = world_position
	_has_target = true
	print("Unit (%s) despachada para evento %s" % [_get_unit_type_name(unit_type), event_id])


# Quando o carrinho chega no evento
func _on_reached_target() -> void:
	print("Unit (%s) chegou no evento %s" % [_get_unit_type_name(unit_type), _current_event_id])

	# Aqui no futuro:
	# - você pode chamar EventManager.try_resolve_event(_current_event_id, unit_type)
	#   assim que implementar essa função no EventManager.
	#
	# Exemplo (quando estiver pronto lá):
	#
	# var em := get_tree().root.get_node_or_null("Main/EventManager")
	# if em and em.has_method("try_resolve_event"):
	#     em.try_resolve_event(_current_event_id, unit_type)

	_current_event_id = ""


# Nome bonitinho para debug / logs
func _get_unit_type_name(t: int) -> String:
	match t:
		GameTypes.UnitType.COMLURB:        return "COMLURB"
		GameTypes.UnitType.CET:            return "CET"
		GameTypes.UnitType.SAMU:           return "SAMU"
		GameTypes.UnitType.DEFESA_CIVIL:   return "DEFESA CIVIL"
		GameTypes.UnitType.GUARDA_MUNICIPAL: return "GUARDA MUNICIPAL"
		GameTypes.UnitType.BOMBEIROS:      return "BOMBEIROS"
		_:                                 return "DESCONHECIDO"

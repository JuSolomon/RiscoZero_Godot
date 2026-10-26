extends Marker3D
class_name UnitBase
##
# Sede de um órgão: ponto de onde as viaturas saem e para onde voltam.
##

@export var unit_type: GameTypes.UnitType = GameTypes.UnitType.SAMU
@export var viaturas: int = 2

var disponiveis: int = 0


func _ready() -> void:
	disponiveis = viaturas
	add_to_group("bases")

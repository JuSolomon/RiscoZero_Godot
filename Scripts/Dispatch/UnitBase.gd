extends Marker3D
class_name UnitBase
##
# Sede de um órgão: ponto de onde as viaturas saem e para onde voltam.
##

@export var unit_type: GameTypes.UnitType = GameTypes.UnitType.SAMU
@export var viaturas: int = 2
@export var mostrar_no_mapa: bool = true

var disponiveis: int = 0


func _ready() -> void:
	disponiveis = viaturas
	add_to_group("bases")
	if mostrar_no_mapa:
		_criar_visual()


# Pino colorido com o nome do órgão
func _criar_visual() -> void:
	var cor: Color = Unit.CORES[unit_type]
	var pino := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 0.8
	cilindro.bottom_radius = 1.0
	cilindro.height = 0.4
	pino.mesh = cilindro
	pino.position.y = 0.2
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	pino.material_override = material
	add_child(pino)

	var nome := Label3D.new()
	nome.text = "Sede " + GameTypes.UnitDict[unit_type]
	nome.font_size = 48
	nome.pixel_size = 0.0005
	nome.fixed_size = true
	nome.no_depth_test = true
	nome.outline_size = 12
	nome.modulate = cor.darkened(0.3)
	nome.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nome.position.y = 1.5
	add_child(nome)

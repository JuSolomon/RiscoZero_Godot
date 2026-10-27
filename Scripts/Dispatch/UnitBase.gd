extends Marker3D
class_name UnitBase
##
# Sede de um órgão: guarda as viaturas, que saem daqui e voltam para cá.
# Clicar na sede abre o menu dela (PainelDespacho).
##

@export var unit_type: GameTypes.UnitType = GameTypes.UnitType.SAMU
## Quantas viaturas a sede recebe ao ser criada
@export var viaturas: int = 2
@export var mostrar_no_mapa: bool = true
## Nome da região da sede (aparece no menu)
@export var regiao_id: String = ""

## Viaturas desta sede (criadas pelo DispatchManager)
var unidades: Array[Unit] = []


func _ready() -> void:
	add_to_group("bases")
	if mostrar_no_mapa:
		_criar_visual()
	_criar_area_de_clique()
	_equipar.call_deferred()


func nome() -> String:
	return "Sede " + GameTypes.UnitDict[unit_type]


## Viaturas que podem ser enviadas agora (na sede ou voltando para ela)
func disponiveis() -> int:
	return unidades.filter(func(u: Unit) -> bool: return u.disponivel()).size()


func _equipar() -> void:
	var dispatch := get_tree().get_first_node_in_group("dispatch")
	if dispatch:
		dispatch.criar_viaturas(self, viaturas)


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

	var nome_label := Label3D.new()
	nome_label.text = nome()
	nome_label.font_size = 48
	nome_label.pixel_size = 0.0005
	nome_label.fixed_size = true
	nome_label.no_depth_test = true
	nome_label.outline_size = 12
	nome_label.modulate = cor.darkened(0.3)
	nome_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nome_label.position.y = 1.5
	add_child(nome_label)


func _criar_area_de_clique() -> void:
	var area := Area3D.new()
	area.name = "Clique"
	area.input_ray_pickable = true
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 2.5
	forma.shape = esfera
	area.add_child(forma)
	add_child(area)
	area.input_event.connect(func(_c, evento: InputEvent, _p, _n, _i) -> void:
		if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and evento.pressed:
			var painel := get_tree().get_first_node_in_group("painel_despacho")
			if painel:
				painel.abrir_sede(self))

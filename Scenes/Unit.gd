extends Node3D
class_name Unit
##
# Viatura de um órgão. Pertence a uma sede (UnitBase) e fica guardada nela até ser enviada.
# Segue uma rota (lista de pontos) no tempo do jogo: pausa junto com o TimeManager
# e acelera com a velocidade do jogo. Estacionada no evento, mostra um anel girando
# e uma sirene piscando. De longe vira uma bolinha na cor do órgão. Clicar abre o menu dela.
##

signal chegou_ao_destino(unit: Unit)
signal voltou_para_base(unit: Unit)

enum Estado { INDO, ESTACIONADO, VOLTANDO, NA_SEDE }

const MODELOS := {
	GameTypes.UnitType.COMLURB: "res://3D Models/Veículos/Carros/garbage-truck.fbx",
	GameTypes.UnitType.CET: "res://3D Models/Veículos/Carros/suv.fbx",
	GameTypes.UnitType.SAMU: "res://3D Models/Veículos/Carros/ambulance.fbx",
	GameTypes.UnitType.DEFESA_CIVIL: "res://3D Models/Veículos/Carros/truck.fbx",
	GameTypes.UnitType.GUARDA_MUNICIPAL: "res://3D Models/Veículos/Carros/police.fbx",
	GameTypes.UnitType.BOMBEIROS: "res://3D Models/Veículos/Carros/firetruck.fbx",
}

const CORES := {
	GameTypes.UnitType.COMLURB: Color(1.0, 0.55, 0.1),
	GameTypes.UnitType.CET: Color(1.0, 0.85, 0.1),
	GameTypes.UnitType.SAMU: Color(1.0, 0.2, 0.2),
	GameTypes.UnitType.DEFESA_CIVIL: Color(1.0, 0.45, 0.0),
	GameTypes.UnitType.GUARDA_MUNICIPAL: Color(0.2, 0.5, 1.0),
	GameTypes.UnitType.BOMBEIROS: Color(0.9, 0.1, 0.1),
}

## Unidades de mundo por segundo, na velocidade 1x do jogo
@export var velocidade: float = 4.0
@export var escala_modelo: float = 2.5
@export var altura_efeito: float = 4.5

@export_group("Visualização por zoom")
## A partir desta distância da câmera a viatura vira uma bolinha na cor do órgão
@export var distancia_troca_bolinha: float = 70.0
## Tamanho da bolinha na tela
@export var tamanho_bolinha: float = 0.0005

var unit_type: int = GameTypes.UnitType.SAMU
var base: UnitBase
## Marcador do evento para onde a viatura vai ou onde está (null = nenhum)
var marcador: Node3D
var estado: Estado = Estado.NA_SEDE
## Número da viatura dentro da sede (1, 2, 3...)
var numero: int = 1

var _rota := PackedVector3Array()
var _indice: int = 0
var _tempo_efeito: float = 0.0
var _bolinha: Sprite3D

@onready var modelo: Node3D = $Modelo
@onready var efeito: Node3D = $Efeito
@onready var anel: MeshInstance3D = $Efeito/Anel
@onready var sirene: OmniLight3D = $Efeito/Sirene
@onready var rotulo: Label3D = $Efeito/Rotulo


## Chame antes de adicionar na árvore
func configurar(tipo: int, base_origem: UnitBase, n: int = 1) -> void:
	unit_type = tipo
	base = base_origem
	numero = n


func _ready() -> void:
	var carro: Node3D = load(MODELOS[unit_type]).instantiate()
	carro.scale = Vector3.ONE * escala_modelo
	modelo.add_child(carro)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = CORES[unit_type]
	anel.material_override = material
	rotulo.text = GameTypes.UnitDict[unit_type]
	rotulo.modulate = CORES[unit_type]
	efeito.visible = false

	_criar_bolinha()
	_criar_area_de_clique()
	_atualizar_visibilidade()


func nome() -> String:
	return "%s %d" % [GameTypes.UnitDict[unit_type], numero]


## Pode receber um novo envio? (na sede ou voltando para ela)
func disponivel() -> bool:
	return estado == Estado.NA_SEDE or estado == Estado.VOLTANDO


func seguir_rota(rota: PackedVector3Array, novo_estado: Estado) -> void:
	_rota = rota
	_indice = 0
	estado = novo_estado
	efeito.visible = false
	_atualizar_visibilidade()


## Segundos (na velocidade 1x) até chegar ao fim da rota atual
func segundos_restantes() -> float:
	if estado != Estado.INDO and estado != Estado.VOLTANDO:
		return 0.0
	var total := 0.0
	var anterior := global_position
	for i in range(_indice, _rota.size()):
		total += anterior.distance_to(_rota[i])
		anterior = _rota[i]
	return total / (velocidade * base.fator_velocidade())


## Volta direto para a sede, sem animação (início de jogo, recarregar)
func estacionar_na_sede() -> void:
	estado = Estado.NA_SEDE
	marcador = null
	_rota = PackedVector3Array()
	efeito.visible = false
	global_position = base.global_position
	_atualizar_visibilidade()


func _process(delta: float) -> void:
	_animar_efeito(delta)
	_atualizar_lod()

	if estado == Estado.ESTACIONADO or estado == Estado.NA_SEDE:
		return
	if not TimeManager.running or TimeManager.is_waiting_for_week_start:
		return

	var passo := velocidade * base.fator_velocidade() * TimeManager.time_scale * delta
	while passo > 0.0 and _indice < _rota.size():
		var alvo := _rota[_indice]
		var vetor := alvo - global_position
		var distancia := vetor.length()
		_virar_para(vetor)
		if distancia <= passo:
			global_position = alvo
			passo -= distancia
			_indice += 1
		else:
			global_position += vetor / distancia * passo
			passo = 0.0

	if _indice >= _rota.size():
		_ao_chegar()


func _virar_para(direcao: Vector3) -> void:
	direcao.y = 0.0
	if direcao.length_squared() < 0.0001:
		return
	# Os carros do kit apontam para +Z, por isso use_model_front = true
	look_at(global_position + direcao, Vector3.UP, true)


func _ao_chegar() -> void:
	match estado:
		Estado.INDO:
			estado = Estado.ESTACIONADO
			efeito.visible = true
			chegou_ao_destino.emit(self)
		Estado.VOLTANDO:
			estado = Estado.NA_SEDE
			marcador = null
			_atualizar_visibilidade()
			voltou_para_base.emit(self)


# -------------------------------------------------
#  VISUAL
# -------------------------------------------------

# Na sede a viatura fica guardada (invisível)
func _atualizar_visibilidade() -> void:
	visible = estado != Estado.NA_SEDE
	var area := get_node_or_null("Clique") as Area3D
	if area:
		area.input_ray_pickable = visible


# De longe: bolinha na cor do órgão; de perto: o modelo
func _atualizar_lod() -> void:
	if not visible:
		return
	var camera := get_viewport().get_camera_3d()
	var longe := camera != null and camera.global_position.distance_to(global_position) > distancia_troca_bolinha
	_bolinha.visible = longe
	modelo.visible = not longe


func _criar_bolinha() -> void:
	# círculo de borda dura: branco até 78% do raio, transparente depois
	var gradiente := Gradient.new()
	gradiente.offsets = PackedFloat32Array([0.0, 0.78, 0.8, 1.0])
	gradiente.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 64
	textura.height = 64

	_bolinha = Sprite3D.new()
	_bolinha.name = "Bolinha"
	_bolinha.texture = textura
	_bolinha.modulate = CORES[unit_type]
	_bolinha.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bolinha.fixed_size = true
	_bolinha.no_depth_test = true
	_bolinha.pixel_size = tamanho_bolinha
	_bolinha.position.y = 1.0
	_bolinha.visible = false
	add_child(_bolinha)


# Área para clicar na viatura e abrir o menu dela
func _criar_area_de_clique() -> void:
	var area := Area3D.new()
	area.name = "Clique"
	area.input_ray_pickable = true
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 2.5
	forma.shape = esfera
	forma.position.y = 1.0
	area.add_child(forma)
	add_child(area)
	area.input_event.connect(func(_c, evento: InputEvent, _p, _n, _i) -> void:
		if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and evento.pressed:
			var painel := get_tree().get_first_node_in_group("painel_despacho")
			if painel:
				painel.abrir_viatura(self))


# Anel girando e subindo/descendo + sirene alternando vermelho/azul
func _animar_efeito(delta: float) -> void:
	if not efeito.visible:
		return
	_tempo_efeito += delta
	efeito.position.y = altura_efeito + sin(_tempo_efeito * 3.0) * 0.4
	anel.rotate_y(delta * 2.5)
	sirene.light_color = Color.RED if int(_tempo_efeito * 4.0) % 2 == 0 else Color.BLUE

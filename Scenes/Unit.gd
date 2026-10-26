extends Node3D
class_name Unit
##
# Viatura de um órgão. Segue uma rota (lista de pontos) no tempo do jogo:
# pausa junto com o TimeManager e acelera com a velocidade do jogo.
# Estacionada no evento, mostra um anel girando e uma sirene piscando.
##

signal chegou_ao_destino(unit: Unit)
signal voltou_para_base(unit: Unit)

enum Estado { INDO, ESTACIONADO, VOLTANDO }

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

var unit_type: int = GameTypes.UnitType.SAMU
var base: UnitBase
var marcador: Node3D
var estado: Estado = Estado.INDO

var _rota := PackedVector3Array()
var _indice: int = 0
var _tempo_efeito: float = 0.0

@onready var modelo: Node3D = $Modelo
@onready var efeito: Node3D = $Efeito
@onready var anel: MeshInstance3D = $Efeito/Anel
@onready var sirene: OmniLight3D = $Efeito/Sirene
@onready var rotulo: Label3D = $Efeito/Rotulo


## Chame antes de adicionar na árvore
func configurar(tipo: int, base_origem: UnitBase, alvo: Node3D) -> void:
	unit_type = tipo
	base = base_origem
	marcador = alvo


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


func seguir_rota(rota: PackedVector3Array, novo_estado: Estado) -> void:
	_rota = rota
	_indice = 0
	estado = novo_estado
	efeito.visible = false


func _process(delta: float) -> void:
	_animar_efeito(delta)

	if estado == Estado.ESTACIONADO:
		return
	if not TimeManager.running or TimeManager.is_waiting_for_week_start:
		return

	var passo := velocidade * TimeManager.time_scale * delta
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
			voltou_para_base.emit(self)
			queue_free()


# Anel girando e subindo/descendo + sirene alternando vermelho/azul
func _animar_efeito(delta: float) -> void:
	if not efeito.visible:
		return
	_tempo_efeito += delta
	efeito.position.y = altura_efeito + sin(_tempo_efeito * 3.0) * 0.4
	anel.rotate_y(delta * 2.5)
	sirene.light_color = Color.RED if int(_tempo_efeito * 4.0) % 2 == 0 else Color.BLUE

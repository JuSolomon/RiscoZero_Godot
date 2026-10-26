extends Camera3D
##
# Camera 2.5D estilo Don't Starve:
# - Pan (WASD) – W anda para onde a câmera olha
# - Zoom limitado (scroll normal)
# - Rotação 8 direções (Q/E) – invertida
# - Pitch dinâmico: mais perto = mais horizontal
##

## Velocidade do pan em "telas por segundo" (proporcional ao zoom)
@export var move_speed: float = 0.8
## Cada passo do scroll multiplica/divide a distância por este fator
@export var zoom_step: float = 1.15

@export var min_distance: float = 6.0
@export var max_distance: float = 400.0

# Ponto focal da câmera
@export var focus_point: Vector3 = Vector3.ZERO

# Limites do mapa
@export var enable_limits: bool = true
@export var limit_x_min: float = -40.0
@export var limit_x_max: float =  40.0
@export var limit_z_min: float = -40.0
@export var limit_z_max: float =  40.0

# Yaw inicial e passos de 45 graus
## 270 = olhando para o norte (norte em cima da tela)
@export var initial_yaw_degrees: float = 270.0
const YAW_STEP_DEG := 45.0

# Pitch dinâmico
# Zoom perto  -> visão mais horizontal (ex.: -30)
# Zoom longe  -> visão mais top-down (ex.: -75)
@export var pitch_near: float = -35.0   # mais perto
@export var pitch_far: float = -70.0    # mais longe

var yaw_index: int = 0
var current_distance: float = 80.0

var _voo: Tween


func _ready() -> void:
	current_distance = clamp(current_distance, min_distance, max_distance)
	_update_transform()


func _process(delta: float) -> void:
	if not (_voo and _voo.is_running()):
		_handle_pan(delta)
		_handle_zoom()
		_handle_rotation()
	_update_transform()


# -------------------------
#  PAN INVERTIDO (WASD)
# -------------------------
func _handle_pan(delta: float) -> void:
	var dir := Vector3.ZERO

	if Input.is_action_pressed("camera_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("camera_right"):
		dir.x += 1.0
	if Input.is_action_pressed("camera_up"):
		dir.z -= 1.0
	if Input.is_action_pressed("camera_down"):
		dir.z += 1.0

	if dir == Vector3.ZERO:
		return

	dir = dir.normalized()

	# Move no sentido da tela, considerando a rotação atual da câmera
	var yaw_rad: float = deg_to_rad(initial_yaw_degrees + yaw_index * YAW_STEP_DEG)
	var frente := Vector3(cos(yaw_rad), 0.0, sin(yaw_rad))
	var direita := Vector3(-frente.z, 0.0, frente.x)
	var passo := move_speed * current_distance * delta
	focus_point += (direita * dir.x - frente * dir.z) * passo

	if enable_limits:
		focus_point.x = clamp(focus_point.x, limit_x_min, limit_x_max)
		focus_point.z = clamp(focus_point.z, limit_z_min, limit_z_max)


# -------------------------
#  ZOOM NORMAL (scroll)
# -------------------------
func _handle_zoom() -> void:
	var changed := false

	# Zoom In aproxima (distância menor)
	if Input.is_action_just_pressed("zoom_in"):
		current_distance /= zoom_step
		changed = true

	# Zoom Out afasta (distância maior)
	if Input.is_action_just_pressed("zoom_out"):
		current_distance *= zoom_step
		changed = true

	if not changed:
		return

	current_distance = clamp(current_distance, min_distance, max_distance)


# -------------------------
#  ROTAÇÃO 8 DIREÇÕES
# -------------------------
func _handle_rotation() -> void:
	var changed := false

	# Rotação invertida como você pediu
	if Input.is_action_just_pressed("camera_rotate_left"):
		yaw_index += 1
		changed = true

	if Input.is_action_just_pressed("camera_rotate_right"):
		yaw_index -= 1
		changed = true

	if not changed:
		return

	# Normaliza o intervalo para 0..7
	yaw_index = (yaw_index % 8 + 8) % 8


# -------------------------
#  API: LIMITES E VOO
# -------------------------

## Restringe o foco da câmera a um retângulo do mapa (x, z, largura, altura)
func definir_limites(area: Rect2, margem: float = 10.0) -> void:
	enable_limits = true
	limit_x_min = area.position.x - margem
	limit_x_max = area.end.x + margem
	limit_z_min = area.position.y - margem
	limit_z_max = area.end.y + margem


## Move a câmera suavemente até um ponto, com a distância dada
func voar_para(ponto: Vector3, distancia: float, duracao: float = 1.5) -> Tween:
	if _voo:
		_voo.kill()
	_voo = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_voo.tween_property(self, "focus_point", ponto, duracao)
	_voo.tween_property(self, "current_distance", clampf(distancia, min_distance, max_distance), duracao)
	return _voo


# -------------------------
#  ATUALIZA TRANSFORMAÇÃO COMPLETA
# -------------------------
func _update_transform() -> void:
	# t = 0 → zoom mínimo (perto)
	# t = 1 → zoom máximo (longe)
	var t: float = (current_distance - min_distance) / float(max_distance - min_distance)
	t = clamp(t, 0.0, 1.0)

	# Pitch dependendo do zoom:
	# - perto → pitch_near (mais horizontal)
	# - longe → pitch_far (mais top-down)
	var pitch: float = lerp(pitch_near, pitch_far, t)
	var pitch_rad: float = deg_to_rad(pitch)

	# Calcula yaw baseado no índice (0 a 7)
	var yaw_rad: float = deg_to_rad(initial_yaw_degrees + yaw_index * YAW_STEP_DEG)

	# Converte pitch+yaw para vetor direção (esférico)
	var dir := Vector3(
		cos(pitch_rad) * cos(yaw_rad),
		sin(pitch_rad),
		cos(pitch_rad) * sin(yaw_rad)
	).normalized()

	# Câmera orbita em torno do foco
	var cam_pos: Vector3 = focus_point - dir * current_distance

	global_position = cam_pos
	look_at(focus_point, Vector3.UP)

extends Camera3D
##
# Camera 2.5D estilo Don't Starve:
# - Pan (WASD) – invertido
# - Zoom limitado (scroll normal)
# - Rotação 8 direções (Q/E) – invertida
# - Pitch dinâmico: mais perto = mais horizontal
##

@export var move_speed: float = 20.0
@export var zoom_step: float = 2.0

@export var min_distance: float = 8.0
@export var max_distance: float = 35.0

# Ponto focal da câmera
@export var focus_point: Vector3 = Vector3.ZERO

# Limites do mapa
@export var enable_limits: bool = true
@export var limit_x_min: float = -40.0
@export var limit_x_max: float =  40.0
@export var limit_z_min: float = -40.0
@export var limit_z_max: float =  40.0

# Yaw inicial e passos de 45 graus
@export var initial_yaw_degrees: float = 45.0
const YAW_STEP_DEG := 45.0

# Pitch dinâmico
# Zoom perto  -> visão mais horizontal (ex.: -30)
# Zoom longe  -> visão mais top-down (ex.: -75)
@export var pitch_near: float = -30.0   # mais perto
@export var pitch_far: float = -75.0    # mais longe

var yaw_index: int = 0
var current_distance: float = 15.0


func _ready() -> void:
	current_distance = clamp(current_distance, min_distance, max_distance)
	_update_transform()


func _process(delta: float) -> void:
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

	# Inverte direções como solicitado
	dir = -dir.normalized()

	focus_point.x += dir.x * move_speed * delta
	focus_point.z += dir.z * move_speed * delta

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
		current_distance -= zoom_step
		changed = true

	# Zoom Out afasta (distância maior)
	if Input.is_action_just_pressed("zoom_out"):
		current_distance += zoom_step
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

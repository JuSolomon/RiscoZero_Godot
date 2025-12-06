extends Area3D

signal clicked(event_id: String)

@export var event_id: String = ""

func _ready() -> void:
	# Permite clique com raycast do mouse
	input_ray_pickable = true

	# Gera um id se estiver vazio
	if event_id == "":
		event_id = str(get_instance_id())

	# Só pra ficar mais fácil de ver
	if has_node("MeshInstance3D"):
		$MeshInstance3D.modulate = Color(1, 0, 0)  # vermelho
	elif has_node("Sprite3D"):
		$Sprite3D.modulate = Color(1, 0, 0)


func _input_event(camera, event, position, normal, shape_idx) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		print("Marker clicado! id =", event_id)
		clicked.emit(event_id)

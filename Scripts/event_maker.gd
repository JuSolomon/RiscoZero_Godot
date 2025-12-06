extends Area3D

signal clicked(event_id: String)

@export var event_id: String = ""

@onready var sprite: Sprite3D = $Sprite3D

func _ready() -> void:
	# Permite receber clique por raycast da câmera
	input_ray_pickable = true

	# Gera um id se estiver vazio
	if event_id == "":
		event_id = str(get_instance_id())

	# Só pra debug
	print("EventMarker pronto. id =", event_id)

	# Deixa o marker visível (opcional)
	if sprite:
		sprite.modulate = Color(1, 1, 1)

func _input_event(camera, event, position, normal, shape_idx) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		print("EventMarker recebeu clique! id =", event_id)
		clicked.emit(event_id)

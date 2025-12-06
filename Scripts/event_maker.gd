extends Area3D

## EventMarker.gd
## Marca visualmente um evento no mapa e repassa cliques para o EventManager/HUD.

signal clicked(event_id: String)

@export var event_id: String = ""   # preenchido pelo EventManager

@onready var sprite: Sprite3D = $Sprite3D


func _ready() -> void:
	# Permite receber clique por raycast da câmera
	input_ray_pickable = true

	# Agora o id deve vir do EventManager. Se vier vazio, avisa no console.
	if event_id == "":
		push_warning("EventMarker: event_id vazio. Verifique se o EventManager está atribuindo o id corretamente.")

	# Debug
	print("EventMarker pronto. id =", event_id)

	# Deixa o marker visível (se tiver sprite)
	if sprite:
		sprite.modulate = Color(1, 1, 1)


func _input_event(camera, event, position, normal, shape_idx) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		print("EventMarker recebeu clique! id =", event_id)
		clicked.emit(event_id)

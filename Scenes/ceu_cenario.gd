extends MeshInstance3D

@export var camera: Camera3D

func _process(_delta: float) -> void:
	if camera:
		global_position = camera.global_position

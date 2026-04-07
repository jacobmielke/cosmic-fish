extends Node

@export var world: IsometricWorld


func _unhandled_input(event: InputEvent) -> void:
	if not world:
		return
	if event.is_action_pressed("swipe_right"):
		world.rotate_world(1)
	elif event.is_action_pressed("swipe_left"):
		world.rotate_world(-1)

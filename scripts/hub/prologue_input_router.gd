extends Node
## Last child gets world shortcuts before inventory's input handler. UI buttons
## still use normal GUI input; this router only consumes relevant world keys.
var hub: PrologueHub

func _input(event: InputEvent) -> void:
	hub.route_world_input(event)

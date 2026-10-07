class_name ActorState
extends Node
## A state is ticked by its owner, never by a second physics callback.

@export var state_id: StringName
var actor: Node


func setup(context: Node) -> void:
	actor = context


func enter(_previous_id: StringName) -> void:
	pass


func exit(_next_id: StringName) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass

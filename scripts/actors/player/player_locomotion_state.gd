class_name PlayerLocomotionState
extends ActorState
## Idle/Run use ground acceleration; Jump/Fall use air control.

var motor: PlayerMotor


func setup(context: Node) -> void:
	super.setup(context)
	motor = context.motor


func physics_update(delta: float) -> void:
	var airborne: bool = state_id == &"jump" or state_id == &"fall"
	motor.apply_locomotion(delta, actor.move_axis, actor.jump_held, airborne)

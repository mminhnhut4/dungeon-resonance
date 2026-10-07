class_name PlayerDashState
extends ActorState
## The movement override is always released on exit (timeout, wall or respawn).

var motor: PlayerMotor


func setup(context: Node) -> void:
	super.setup(context)
	motor = context.motor


func enter(_previous_id: StringName) -> void:
	motor.start_dash(actor.move_axis, actor.facing_direction)


func physics_update(_delta: float) -> void:
	if motor.dash_remaining <= 0.0:
		(get_parent() as ActorStateMachine).transition_to(&"ready")
	else:
		motor.apply_dash_motion()


func exit(_next_id: StringName) -> void:
	motor.end_dash()

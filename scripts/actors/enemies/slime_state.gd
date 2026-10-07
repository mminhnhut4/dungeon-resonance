class_name SlimeState
extends ActorState
## FSM transitions/actions; SlimeEnemy delegates all movement to its Motor.


func enter(_previous_id: StringName) -> void:
	actor.enter_state(state_id)


func physics_update(delta: float) -> void:
	actor.tick_state(state_id, delta)


func exit(_next_id: StringName) -> void:
	if state_id == &"attack":
		actor.bite_hitbox.deactivate()

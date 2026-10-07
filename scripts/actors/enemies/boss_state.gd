extends ActorState

func enter(_previous_id: StringName) -> void:
	actor.enter_state(state_id)


func exit(_next_id: StringName) -> void:
	actor.attack_hitbox.deactivate()


func physics_update(delta: float) -> void:
	actor.tick_state(state_id, delta)

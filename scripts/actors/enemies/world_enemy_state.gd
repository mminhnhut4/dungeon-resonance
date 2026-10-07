class_name WorldEnemyState
extends ActorState

func enter(_previous: StringName) -> void:
	actor.enter_state(state_id)

func physics_update(delta: float) -> void:
	actor.tick_state(state_id, delta)

func exit(_next: StringName) -> void:
	if state_id == &"attack":
		actor.attack_hitbox.deactivate()


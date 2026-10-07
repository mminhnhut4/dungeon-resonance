class_name PlayerCastState
extends ActorState
## Windup commits cooldown; dash/death cancellation cannot create a free spell.

var payload: SpellSnapshot
var _remaining: float = 0.0
var _launched: bool = false


func enter(_previous_id: StringName) -> void:
	payload = actor.resonance_controller.commit_cast()
	_launched = false
	_remaining = payload.windup if payload != null else 0.0


func physics_update(delta: float) -> void:
	if payload == null:
		(get_parent() as ActorStateMachine).transition_to(&"ready")
		return
	_remaining -= delta
	if _remaining > 0.000001:
		return
	if not _launched:
		_launched = true
		# Spawn at the current chest position, retain the committed aim/loadout.
		payload.origin = actor.aim.global_position
		actor.resonance_controller.executor.spawn_cast(payload)
		_remaining += payload.recovery
	else:
		(get_parent() as ActorStateMachine).transition_to(&"ready")


func exit(_next_id: StringName) -> void:
	payload = null

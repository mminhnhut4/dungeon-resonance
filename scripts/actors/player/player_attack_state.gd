class_name PlayerAttackState
extends ActorState
## Weapon owns the data-driven timeline; Action FSM owns its cancellation lifetime.

var weapon: Weapon


func setup(context: Node) -> void:
	super.setup(context)
	weapon = context.equipped_weapon


func enter(_previous_id: StringName) -> void:
	weapon.start_combo()


func physics_update(delta: float) -> void:
	weapon.advance(delta)
	if not weapon.is_attacking():
		(get_parent() as ActorStateMachine).transition_to(&"ready")


func exit(_next_id: StringName) -> void:
	weapon.cancel_combo()

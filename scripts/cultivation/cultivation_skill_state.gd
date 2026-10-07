class_name CultivationSkillState
extends ActorState
var runtime: CultivationStyleRuntime
func physics_update(delta: float) -> void:
	if is_instance_valid(runtime): runtime.advance_skill(delta)
	else: (get_parent() as ActorStateMachine).transition_to(&"ready")
func exit(next_id: StringName) -> void:
	if is_instance_valid(runtime): runtime.end_skill(next_id)

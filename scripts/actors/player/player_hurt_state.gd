class_name PlayerHurtState
extends ActorState
## Reaction component owns time; the two FSMs retain their single Player tick.


func physics_update(_delta: float) -> void:
	var reaction: HitReactionComponent = actor.hit_reaction
	if reaction == null or not reaction.blocks_controls():
		(get_parent() as ActorStateMachine).transition_to(&"ready")


func exit(next_id: StringName) -> void:
	if next_id != &"hurt" and actor.hit_reaction != null:
		actor.hit_reaction.clear()

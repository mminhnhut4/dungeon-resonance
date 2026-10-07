class_name NpcPilotResolver
extends DamageResolver
## Every damage kind, including internal DOT, shares this terminal-state guard.
var world_state: NpcWorldState
var stable_id: String
var origin_offset_x: float = 0.0

func resolve(event: DamageEvent) -> DamageResult:
	if world_state == null or world_state.read_only or world_state.records[stable_id]["mode"] in ["downed", "dead", "talk"]:
		var blocked := DamageResult.new()
		blocked.blocked = true
		blocked.block_reason = &"npc_protected"
		return blocked
	# Health floor keeps killed=false, so combat cannot award a kill or relic heal.
	health.minimum_health = 1.0
	# Sample the Hurtbox owner's actual contact position before damage callbacks.
	# The actor can be between 4Hz decision positions; never rewrite that clock.
	var actor_x: float = NAN
	if is_instance_valid(health) and health.get_parent() is Node2D:
		actor_x = (health.get_parent() as Node2D).global_position.x - origin_offset_x
	var result: DamageResult = super.resolve(event)
	if result.actual_damage > 0:
		var player_caused: bool = event.source_team_id == 1 and event.source_kind != DamageEvent.SourceKind.ENVIRONMENT
		world_state.receive_hit(stable_id, health.current_health, event.attack_origin.x - origin_offset_x, player_caused, actor_x)
	return result

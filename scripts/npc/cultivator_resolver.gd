class_name CultivatorResolver
extends DamageResolver
## Runtime cause cache belongs to this local representation, never to save data.
var world_state: NpcWorldState
var stable_id: String
var player: Player
var origin_offset_x: float = 0.0
var _causes: Dictionary[String, bool] = {}

func resolve(event: DamageEvent) -> DamageResult:
	if world_state == null or world_state.read_only or not world_state.records.has(stable_id) or world_state.records[stable_id]["mode"] in ["downed","dead","recovering","talk"]:
		var blocked := DamageResult.new()
		blocked.blocked = true
		blocked.block_reason = &"npc_protected"
		return blocked
	# The accepted damage pipeline remains shared. No synthetic kill is emitted.
	health.minimum_health = 1.0
	var result: DamageResult = super.resolve(event)
	if result.actual_damage > 0.0:
		var cause_id: int = event.root_event_id if event.root_event_id > 0 else event.attack_id
		var cause: String = "%d:%d" % [event.source_id,cause_id]
		var first_cause: bool = not _causes.has(cause)
		if first_cause:
			if _causes.size() >= 128: _causes.erase(_causes.keys()[0])
			_causes[cause] = true
		var actor: Node2D = health.get_parent() as Node2D
		world_state.receive_hit(stable_id,health.current_health,event.attack_origin.x-origin_offset_x,is_player_cause(event),actor.global_position.x-origin_offset_x,first_cause)
	return result

func is_player_cause(event: DamageEvent) -> bool:
	# Team is only collision policy. A companion/fake source on team 1 is not Player.
	return is_instance_valid(player) and player.is_inside_tree() and event.source_id == player.get_instance_id() and event.source_kind != DamageEvent.SourceKind.ENVIRONMENT

extends "res://tests/tan_dang_horizon_runtime_probe.gd"
## Actual adapter/actor boundary fixture. State calls are explicit, not native play.
class ReplaceFault extends SanctuaryProfile:
	var primary: String = ""
	func _replace_file(temporary: String,target: String) -> bool:
		return false if target==primary else super._replace_file(temporary,target)

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	await _setup_horizon("terminal_fault")
	var life: NpcWorldState=population.state
	var enemy: TanDangLivingSlime=_far_threat()
	var actor: CultivatorActor=population.actors.get(LAM) as CultivatorActor
	if not is_instance_valid(actor) or not is_instance_valid(enemy):_check(false,"Physical encounter fixture exists");await _finish();return
	for _i: int in 360:life.advance_living_danger(0.1)
	_check(life.save() and _elapsed()==35.0,"Existing owner saves the saturated horizon before resolve")
	var before: Dictionary=life.snapshot();var bytes: PackedByteArray=FileAccess.get_file_as_bytes(life.save_path)
	var fault:=ReplaceFault.new();fault.primary=life.save_path;life.io=fault
	enemy.position.x=actor.position.x+70.0
	_check(actor.request_living_defense(enemy),"Actual NPC can own a threat before failed horizon resolution")
	enemy._open_living_bite()
	hub.living._tick_danger(0.1)
	_check(_elapsed()==35.0 and life.snapshot()==before and FileAccess.get_file_as_bytes(life.save_path)==bytes and not life.last_save_ok,"Failed result retains saturated time, prior phase and exact durable bytes")
	_check(not enemy.ai_enabled and not enemy.bite_hitbox.active and actor.living_enemy==null and not actor.strike_hitbox.active,"Failed horizon result suspends actual bite and NPC strike; no extra contact")
	var actor_hp: float=actor.health.current_health;var player_hp: float=hub.player.health.current_health
	hub.living._process(0.1)
	_check(_elapsed()==35.0 and not enemy.ai_enabled and not enemy.bite_hitbox.active and actor.health.current_health==actor_hp and hub.player.health.current_health==player_hp,"Repeated failed frame cannot restart combat or rewind time")
	life.io=SanctuaryProfile.new()
	hub.living._tick_danger(0.1)
	_check(life.living_view(LAM)["event_phase"]=="returning" and life.living_view(LAM)["outcome"]=="withdrew" and _elapsed()==35.0,"Successful retry resolves once at the same horizon")
	flow.queue_free();current_scene=null;await _step(6)
	await _setup_horizon("before_spawn")
	life=population.state
	for _i: int in 360:life.advance_living_danger(0.1)
	_check(life.save() and not is_instance_valid(hub.living.enemy),"New saved35 fixture has no transient monster")
	actor=population.actors.get(LAM) as CultivatorActor
	# A deliberately unsupported route would reject _spawn_enemy. Horizon must
	# resolve before that operation and must not add any enemy node anyway.
	var old_route: StringName=hub.exterior.route_id
	hub.exterior.route_id=&"fixture_spawn_rejected"
	var children: int=hub.exterior.get_child_count()
	hub.living._tick_danger(0.1)
	_check(life.living_view(LAM)["event_phase"]=="returning" and not is_instance_valid(hub.living.enemy) and hub.exterior.get_child_count()==children,"Saved35 resolves before a failing spawn path without allocating a monster")
	hub.exterior.route_id=old_route
	await _finish()

extends "res://tests/linked_gameplay_probe.gd"
## Earned H7 normal portal, existing encounter. QA controller sends only input.
class EncounterBot:
	extends Node
	var run: DungeonRun
	var harrier: SlimeEnemy
	var enabled: bool=false
	var gap: float=150
	var aim_harrier: bool=false
	var tick: int=0
	var jump_until: int=0
	func action(id: StringName,down: bool) -> void:
		var e:=InputEventAction.new();e.action=id;e.pressed=down;Input.parse_input_event(e)
	func stop() -> void:
		enabled=false
		for id: StringName in [&"attack",&"spell_cast",&"jump",&"dash",&"move_left",&"move_right"]:action(id,false)
	func _physics_process(_delta: float) -> void:
		if not enabled or not is_instance_valid(run) or not is_instance_valid(harrier) or harrier.health.current_health<=0 or run.player.health.current_health<=0:return
		tick+=1;action(&"jump",tick<jump_until)
		var dx: float=harrier.global_position.x-run.player.global_position.x
		var correction: float=absf(dx)-gap
		action(&"move_left",absf(correction)>9 and signf(dx)*signf(correction)<0);action(&"move_right",absf(correction)>9 and signf(dx)*signf(correction)>0)
		if aim_harrier:
			var motion:=InputEventMouseMotion.new();motion.position=harrier.get_global_transform_with_canvas()*Vector2(0,-14);get_tree().root.push_input(motion,true)
		for enemy: Node2D in run.living_enemies():
			if enemy is BaseEnemy and enemy.definition.id==&"ancient_guard" and enemy.global_position.distance_to(run.player.global_position)<170:
				if enemy.state_machine.get_state_id()==&"attack" or (enemy.state_machine.get_state_id()==&"telegraph" and enemy.state_time>enemy.definition.windup-.15):
					if run.player.motor.is_grounded():action(&"jump",true);jump_until=tick+12
var scout: EncounterBot
var run_scene: DungeonRun
var ranged: SlimeEnemy
var harrier_rows: Array[Dictionary]=[]
var hit_rows: Array[Dictionary]=[]
var hero_hits: Array[Dictionary]=[]
var pending: Dictionary={}
var any_guard_with_tell: bool=false
func incoming(event: DamageEvent) -> void:pending[event.attack_id]={"windup":float(ranged.get("ranged_windup")),"hp":ranged.health.current_health}
func resolved(event: DamageEvent,result: DamageResult) -> void:
	var before: Dictionary=pending.get(event.attack_id,{});pending.erase(event.attack_id)
	hit_rows.append({"before":before,"kind":event.source_kind,"damage":result.actual_damage,"blocked":result.blocked,"windup_after":float(ranged.get("ranged_windup")),"hp_after":ranged.health.current_health,"wall_usec":Time.get_ticks_usec()})
func hero_received(event: DamageEvent,result: DamageResult) -> void:hero_hits.append({"source":event.source_id,"attack":event.attack_id,"amount":result.actual_damage,"blocked":result.blocked,"wall_usec":Time.get_ticks_usec()})
func observe() -> void:
	if not is_instance_valid(ranged) or not is_instance_valid(run_scene):return
	var guards: int=run_scene.living_enemies().filter(func(e: Node2D)->bool:return e is BaseEnemy and e.definition.id==&"ancient_guard").size()
	var tell: float=ranged.get("ranged_windup")
	any_guard_with_tell=any_guard_with_tell or (guards>0 and tell>0)
	if harrier_rows.size()<2400:harrier_rows.append({"phase":phase,"tell":tell,"shots":ranged.get("shots_fired"),"cancelled":ranged.get("tells_cancelled"),"guards":guards,"hero_hp":run_scene.player.health.current_health,"x_gap":absf(run_scene.player.global_position.x-ranged.global_position.x),"projectiles":get_nodes_in_group(&"runic_harrier_bolts").size(),"wall_usec":Time.get_ticks_usec()})
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or not "--qa-seed-h7" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	_check(FileAccess.get_sha256(profile_path)==OS.get_environment("FOLLOWUP_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("FOLLOWUP_SOURCE_NPC"),"Exact earned H7 pair before normal gameplay")
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30);hub=flow.active_scene as ExteriorHub
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	_stage("ordinary_portal_to_existing_encounter")
	if not await _walk(hub.player,hub.stations[&"portal"].global_position.x):await finish_proto(false);return
	await _key(KEY_E);await _step(12);run_scene=flow.active_scene as DungeonRun
	if not _check(run_scene!=null and not flow.qa_tools_enabled,"Physical portal enters the ordinary connected opening"):await finish_proto(false);return
	var prototypes: Array[Node2D]=run_scene.living_enemies().filter(func(e: Node2D)->bool:return e.get_script().resource_path=="res://scripts/actors/enemies/runic_slime_harrier.gd")
	if not _check(prototypes.size()==1 and run_scene.living_enemies().size()==4,"Exactly one prototype in the existing four-enemy encounter"):await finish_proto(false);return
	ranged=prototypes[0] as SlimeEnemy
	_check(ranged.health.maximum_health==60 and run_scene.living_enemies().filter(func(e: Node2D)->bool:return e is BaseEnemy and e.definition.id==&"ancient_guard").size()==2,"Same60HP slot alongside both original Guards")
	ranged.hurtbox.damage_received.connect(incoming);ranged.hurtbox.hit_resolved.connect(resolved);run_scene.player.hurtbox.hit_resolved.connect(hero_received);process_frame.connect(observe)
	scout=EncounterBot.new();scout.run=run_scene;scout.harrier=ranged;root.add_child(scout);scout.enabled=true
	_stage("approach_under_melee_pressure_then_read_tell")
	for i: int in 900:
		if ranged.get("shots_fired")>0 or run_scene.player.health.current_health<=0:break
		await _step(1)
	if not _check(run_scene.player.health.current_health>0 and ranged.get("shots_fired")>0 and any_guard_with_tell,"Live ranged tell/shot occurs alongside active melee enemies"):await finish_proto(false);return
	await _shot("ranged_lane_with_guards");await pause(.7)
	_stage("close_gap_and_interrupt_the_caster")
	scout.gap=95;scout.aim_harrier=true
	var requested: bool=false
	for i: int in 720:
		if not is_instance_valid(ranged) or ranged.health.current_health<=0 or run_scene.player.health.current_health<=0:break
		if float(ranged.get("ranged_windup"))>.28 and run_scene.player.motor.is_grounded() and run_scene.player.action_state_machine.get_state_id()==&"ready" and run_scene.player.resonance_controller.can_cast() and run_scene.player.global_position.distance_to(ranged.global_position)<115:
			await _key(KEY_I);requested=true
			await _step(24);break
		await _step(1)
	_check(requested,"Ordinary input targets the caster during its readable windup")
	_check(hit_rows.any(func(h: Dictionary)->bool:return h["before"].get("windup",0)>0 and h["kind"]!=DamageEvent.SourceKind.DOT and h["damage"]>0 and h["hp_after"]>0 and h["windup_after"]==0),"A real nonlethal direct spell hit cancels the caster tell")
	await _shot("actual_caster_interrupted");scout.stop();await pause(.6)
	_check(run_scene.player.health.current_health>0,"Player survives the prototype observation without HP/stat overrides")
	await finish_proto(true)
func finish_proto(complete: bool) -> void:
	if is_instance_valid(scout):scout.stop()
	bot.stop();await pause(.4);var cap: Dictionary=recorder.finish()
	var file:=FileAccess.open(evidence.path_join("harrier-gameplay.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"complete":complete,"checks":checks,"failures":failures,"guard_with_tell":any_guard_with_tell,"rows":harrier_rows,"caster_hits":hit_rows,"hero_hits":hero_hits,"capture":{"wall_seconds":cap["wall_seconds"],"frames":cap["frames"].size(),"audio":cap["audio"]},"scope":"Earned H7, physical portal, existing first four-enemy encounter and normal movement/jump/I inputs. One Runic prototype, no HP/damage/AI/warp/RNG/grant overrides. Observation stops after caster counter, not a clear/victory claim. QA automation, not player study."},"\t"));file.close()
	if process_frame.is_connected(observe):process_frame.disconnect(observe)
	if is_instance_valid(scout):scout.queue_free()
	bot.queue_free();flow.queue_free();recorder.queue_free();current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT HarrierGameplay checks=%d failures=%d complete=%s wall=%.3f"%[checks,failures,complete,cap["wall_seconds"]]);quit(0 if complete and failures==0 else 1)

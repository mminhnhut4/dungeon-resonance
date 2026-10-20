extends "res://tests/milestone_balance_native.gd"
## Actual Common milestone and adaptive normal inputs; fixed seed only for comparison.
var campaign: WorldCampaign
var spawn_rows: Array[Dictionary]=[]
var role_rows: Array[Dictionary]=[]
var player_rows: Array[Dictionary]=[]
var native_hits: Array[Dictionary]=[]
var remembered: Dictionary[int,StringName]={}
var before_hit: Dictionary[int,Dictionary]={}
var combat_started: int=0
var tick_count: int=0
var comparison_seed: int=137
var audio_rows: Array[Dictionary]=[]
var frame_rows: Array[Dictionary]=[]
var previous_frame_usec: int=0

func born(node: Node) -> void:
	if node is AudioStreamPlayer2D and node.name.begins_with("SFX_"):
		audio_rows.append({"name":String(node.name),"at_usec":Time.get_ticks_usec(),"physics":Engine.get_physics_frames(),"pitch":node.pitch_scale,"bus":String(node.bus),"volume_db":node.volume_db})
	if node is WorldCampaign:node.run_seed=comparison_seed
	if node is BaseEnemy and node.get_parent() is DungeonRoom:
		spawn_rows.append({"id":node.get_instance_id(),"role":String(node.definition.id),"x":node.position.x,"y":node.position.y})
	elif node is SlimeEnemy and node.get_parent() is DungeonRoom:
		spawn_rows.append({"id":node.get_instance_id(),"role":"runic_slime","x":node.position.x,"y":node.position.y})

func incoming_native(event: DamageEvent,target: Node2D) -> void:
	var state: StringName=target.state_machine.get_state_id()
	before_hit[event.attack_id]={"state":String(state),"tell":float(target.get("ranged_windup")) if target is SlimeEnemy else maxf(0,target.definition.windup-target.state_time) if state==&"telegraph" else 0.0}

func hit_native(event: DamageEvent,result: DamageResult,target: Node2D) -> void:
	var old: Dictionary=before_hit.get(event.attack_id,{});before_hit.erase(event.attack_id)
	native_hits.append({"target":target.get_instance_id(),"spell":String(event.spell_id),"kind":event.source_kind,"amount":result.actual_damage,"blocked":result.blocked,"before":old,"after":String(target.state_machine.get_state_id()),"hp":target.health.current_health,"at_usec":Time.get_ticks_usec()})

func observe_native() -> void:
	if not is_instance_valid(campaign):return
	tick_count+=1
	var now: int=Time.get_ticks_usec()
	if previous_frame_usec>0:frame_rows.append({"wall_usec":now-previous_frame_usec,"hitstop":campaign.feedback.is_frozen(),"capture_enabled":true})
	previous_frame_usec=now
	for enemy: Node2D in campaign.living_enemies():
		var state: StringName=enemy.state_machine.get_state_id()
		if enemy is SlimeEnemy and float(enemy.get("ranged_windup"))>0:state=&"ranged_tell"
		if remembered.get(enemy.get_instance_id(),&"")!=state:
			remembered[enemy.get_instance_id()]=state
			role_rows.append({"id":enemy.get_instance_id(),"role":String(enemy.enemy_type) if enemy is BaseEnemy else "runic_slime","state":String(state),"x":enemy.global_position.x,"hero_x":campaign.player.global_position.x,"at_usec":Time.get_ticks_usec()})
	if tick_count%6==0:
		player_rows.append({"at_usec":Time.get_ticks_usec(),"x":campaign.player.global_position.x,"y":campaign.player.global_position.y,"hp":campaign.player.health.current_health,"energy":campaign.player.energy.current,"action":String(campaign.player.action_state_machine.get_state_id()),"remaining":campaign.living_enemies().size(),"hitstop":campaign.feedback.is_frozen()})

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	native=true;evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json";start_usec=Time.get_ticks_usec()
	if not _check(FileAccess.get_sha256(profile_path)==OS.get_environment("MINE_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("MINE_SOURCE_NPC"),"Exact earned QA profile pair before startup"):quit(2);return
	node_added.connect(born)
	bot=CombatBot.new();root.add_child(bot)
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30)
	_check(not flow.qa_tools_enabled,"No product QA tools enabled")
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	if not await configure_milestone():await finish_formation(false);return
	_stage("ordinary_portal_common_milestone")
	var home: ExteriorHub=flow.active_scene as ExteriorHub
	if not await _walk(home.player,home.stations[&"portal"].global_position.x):await finish_formation(false);return
	await _key(KEY_E);await _step(12);campaign=flow.active_scene as WorldCampaign
	if not _check(campaign!=null and campaign.stage==1 and campaign.living_enemies().size()==4,"Ordinary portal enters original four-enemy opening"):await finish_formation(false);return
	_check(campaign.player.health.maximum_health==115 and campaign.player.hurtbox.damage_resolver.armor_rating==11 and campaign.player.energy.maximum==100 and campaign.player.resonance_controller.get_recipe().id==&"fire_bolt","Common+1, CommonFire and milestone stats survive scene replacement")
	for enemy: Node2D in campaign.living_enemies():
		enemy.hurtbox.damage_received.connect(incoming_native.bind(enemy))
		enemy.hurtbox.hit_resolved.connect(hit_native.bind(enemy))
	process_frame.connect(observe_native);combat_started=Time.get_ticks_usec()
	bot.run=campaign;bot.enabled=true;_stage("common_fire_real_opening_combat")
	for i: int in 7200:
		if campaign.outcome!=&"" or (campaign.living_enemies().is_empty() and not campaign.room.locked):break
		await _step(1)
	bot.stop()
	var survived: bool=campaign.outcome==&"" and campaign.player.health.current_health>0 and not campaign.room.locked
	_check(survived,"Real input clears the opening with the unchanged Common milestone")
	await _shot("opening_cleared_common");await pause(.5)
	if survived:
		if not await _walk(campaign.player,1240):await finish_formation(false);return
		await _key(KEY_E);await pause(.4)
		if not _check(campaign.floor_exit.is_open,"Normal cleared-room exit opens"):await finish_formation(false);return
		await _click(campaign.floor_exit.return_button);await _step(16)
		_check(flow.active_scene is ExteriorHub,"Normal return banks the run")
	await finish_formation(survived and failures==0)

func finish_formation(complete: bool) -> void:
	bot.stop();await pause(.3)
	var captured: Dictionary=recorder.finish()
	var result: Dictionary={"complete":complete,"checks":checks,"failures":failures,"spawn_seed":comparison_seed,"audio_events":audio_rows,"frame_observations_capture_on":frame_rows,"music":"No music owner is present in this milestone; existing ambience unchanged. No music candidate merged.","spawn":spawn_rows,"roles":role_rows,"player":player_rows,"hits":native_hits,"loadout":loadout_after,"combat_started_usec":combat_started,"capture":{"wall_seconds":captured["wall_seconds"],"frames":captured["frames"].size(),"audio":captured["audio"]},"scope":"Identical earned QA source; real inventory removes LegendaryWind. Common+1/CommonFire, HP115 armor11 mana100. Same adaptive input bot and fixed QA spawn seed137. No HP/AI/damage/actor-position overrides. Not human playtest or identical timed input replay."}
	var f:=FileAccess.open(evidence.path_join("recorded-pair-native.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	if process_frame.is_connected(observe_native):process_frame.disconnect(observe_native)
	if node_added.is_connected(born):node_added.disconnect(born)
	bot.queue_free();flow.queue_free();current_scene=null;recorder.queue_free();campaign=null;await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT RecordedPairNative checks=%d failures=%d complete=%s"%[checks,failures,complete]);quit(0 if complete and failures==0 else 1)

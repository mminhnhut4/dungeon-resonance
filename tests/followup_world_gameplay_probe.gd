extends "res://tests/story_gameplay_probe.gd"
## Earned H7 profile and normal viewport input; one independent video per mode.
var mode: String = "rooms"
var transition_rows: Array[Dictionary] = []
var original_story: String
var original_gear: String
var original_living: Dictionary
var fresh_route: bool = false
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args():quit(2);return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
	if mode not in ["rooms","explore","memory","cold_memory"]:quit(2);return
	fresh_route="--fresh-route" in OS.get_cmdline_user_args()
	if (fresh_route and mode!="rooms") or (not fresh_route and not "--qa-seed-h7" in OS.get_cmdline_user_args()):quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	if fresh_route:_check(not FileAccess.file_exists(profile_path),"Fresh ordinary product startup, profile did not exist")
	else:_check(FileAccess.get_sha256(profile_path)==OS.get_environment("FOLLOWUP_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("FOLLOWUP_SOURCE_NPC"),"Exact played source pair before product startup, no save edits")
	bot=CombatBot.new();root.add_child(bot)
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	_stage("actual_product_owner_startup");await _step(3)
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30);hub=flow.active_scene as ExteriorHub
	_check(not flow.qa_tools_enabled and not hub.outside and (not hub.tan_dang.progress.state()["accepted"] if fresh_route else hub.tan_dang.progress.state()["rewards"].has("q3")),"Actual fresh/earned Hub without QA tools")
	original_story=Writer.canonical(hub.tan_dang.progress.state());original_gear=Writer.canonical(GearInventoryCodec.encode(hub.gear.inventory));original_living=hub.npc_population.state.living_view(TanDangProgress.LAM)
	if mode=="rooms":
		if not await _rooms():await _finish_world(false);return
	elif mode=="explore":
		if not await _explore():await _finish_world(false);return
	else:
		if not await _memory():await _finish_world(false);return
	await _finish_world(true)
func _door(id: StringName, destination: StringName) -> bool:
	var source: String=String(hub.exterior.room_id) if hub.outside else String(ExteriorRouteCatalog.HUB)
	_stage("walk_and_E_"+source+"_to_"+String(destination))
	var started: int=Time.get_ticks_usec()
	var ok: bool=await travel(id,destination)
	transition_rows.append({"from":source,"to":String(destination),"via":String(id),"elapsed_with_walking_s":(Time.get_ticks_usec()-started)/1000000.0,"ok":ok,"route":String(hub.exterior.route_id) if hub.outside else "hub"})
	await pause(.7)
	return ok
func _rooms() -> bool:
	# Both visits use authored doors and walking. The timing fixture, not this
	# capture with GPU readback, supplies the performance comparison.
	for lap: int in 2:
		_stage("ordinary_route_lap_%d"%lap)
		if not await _door(&"exterior_road",&"o01_p01"):return false
		if not await _door(&"door_east",&"o01_p02"):return false
		if not await _door(&"door_east",&"o01_p03"):return false
		await _shot("p03_visit_%d"%lap)
		if not await _door(&"door_west",&"o01_p02"):return false
		if not await _door(&"door_west",&"o01_p01"):return false
		if not await _door(&"door_west",ExteriorRouteCatalog.HUB):return false
	_check(hub.npc_population.state.living_view(TanDangProgress.LAM)["event_phase"]==("none" if fresh_route else "done"),"Room cycles preserve the original NPC journey state")
	return true
func _explore() -> bool:
	await journal(&"opening_exploration","journal_reports_SC01_already_open")
	var row: Dictionary=hub.exploration.journal_rows().back()
	_check(str(row["body"]).contains("SC01: cơ cấu đường giữ đèn đã mở.") and not str(row["body"]).contains("sẽ mở"),"Actual journal explains the earned q3 opening")
	if not await _door(&"exterior_road",&"o01_p01"):return false
	if not await _door(&"tunnel",&"o01_p02"):return false
	_check(hub.exterior.route_id==ExteriorRouteCatalog.TUNNEL and hub.exterior.gate_open and hub.exterior.gate.collision_layer==0,"Existing physical SC01 gate is open on the tunnel route")
	await _shot("physical_SC01_open");await pause(1.5)
	if not await _door(&"door_east",&"o01_p03"):return false
	_stage("walk_to_existing_P03_lever")
	if not await _walk(hub.player,(ExteriorHub.ORIGIN+hub.exterior.interactions[&"sc01_lever"]).x):return false
	await pause(1.5)
	_check(hub.nearest_station()==&"sc01_lever" and hub.prompt.text=="E · Cơ cấu đường giữ đèn · Đã mở","Lever prompt agrees with the existing open collider and map")
	await _shot("actual_lever_prompt_already_open")
	await journal(&"opening_exploration","P03_journal_remembers_open_mechanism")
	return true
func _memory() -> bool:
	_check(original_living["event_phase"]=="done" and original_living["outcome"]=="withdrew" and original_living["help_credited"] and original_living["forage_help"],"Previously played real helping strike and withdrawal survive startup")
	await journal(&"tan_dang_relations","saved_trip_and_relationships_after_"+mode)
	if not await interact_story(StringName(TanDangProgress.LAM),"Lam_remembers_the_actual_trip",true):return false
	await close_dialogue()
	if not await interact_story(StringName(TanDangProgress.DU),"Du_remembers_the_local_report",true):return false
	await close_dialogue()
	if mode=="memory":
		if not await _door(&"exterior_road",&"o01_p01"):return false
		if not await _door(&"door_west",ExteriorRouteCatalog.HUB):return false
		await journal(&"tan_dang_relations","relationships_after_actual_return")
	var now: Dictionary=hub.npc_population.state.living_view(TanDangProgress.LAM)
	for key: String in ["event_phase","outcome","help_credited","forage_help","acknowledged"]:
		_check(now[key]==original_living[key],"No replay or forgotten consequence after return: "+key)
	return true
func _finish_world(complete: bool) -> void:
	bot.stop();await close_dialogue();await pause(.4)
	_check(Writer.canonical(hub.tan_dang.progress.state())==original_story,"Travel/read-only journal never replay quests or change the canonical rescue choice")
	_check(Writer.canonical(GearInventoryCodec.encode(hub.gear.inventory))==original_gear,"Travel/read-only journal preserves all owned UIDs/affixes/equipment/runes/materials")
	var after: Dictionary=hub.npc_population.state.snapshot()
	var cap: Dictionary=recorder.finish()
	recorder.queue_free();bot.queue_free();flow.queue_free();current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	var data: Dictionary={"mode":mode,"fresh_route":fresh_route,"complete":complete,"checks":checks,"failures":failures,"transitions":transition_rows,"spoken":spoken,"living_before":original_living,"npc_after":after,"source_profile":OS.get_environment("FOLLOWUP_SOURCE_PROFILE"),"source_npc":OS.get_environment("FOLLOWUP_SOURCE_NPC"),"profile_sha256":FileAccess.get_sha256(profile_path),"npc_sha256":FileAccess.get_sha256(profile_path+".npc_v1.json"),"capture":{"wall_seconds":cap["wall_seconds"],"frames":cap["frames"].size(),"audio":cap["audio"]},"scope":("Fresh ordinary product defaults with no preexisting profile. " if fresh_route else "Exact earned H7 q3 save. ")+"Normal wall time, viewport walking/doors/E/dialogue/journal. No grants, warp, HP/damage/RNG/phase/save edits. Videos are readability/gameplay evidence, not benchmarks. New horizon continuity has separate owner/native evidence. Owner startup after script resources load is included, not full OS/application boot."}
	var f:=FileAccess.open(evidence.path_join("followup-world.json"),FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"));f.close()
	print("RESULT FollowupWorld mode=%s checks=%d failures=%d complete=%s wall=%.3f"%[mode,checks,failures,complete,cap["wall_seconds"]]);quit(0 if complete and failures==0 else 1)

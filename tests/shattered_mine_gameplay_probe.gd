extends "res://tests/floor_supply_gameplay_probe.gd"
## Earned QA pair, ordinary viewport inputs only; no actor/stat/AI/loot overrides.
var mine_sources: Array[Dictionary]=[]
var mine_route: Array[Dictionary]=[]
var starting_ledger: Dictionary={}
func mine_pickup(pickup: LootPickup) -> void:
	if pickup.has_meta(&"shattered_mine_source"):
		mine_sources.append({"id":String(pickup.get_meta(&"shattered_mine_source")),"item":String(pickup.item_id),"quantity":pickup.quantity,"at_usec":Time.get_ticks_usec()})
func mine_position(label: String) -> void:
	var run: DungeonRun=flow.active_scene as DungeonRun
	mine_route.append({"label":label,"x":run.player.global_position.x,"y":run.player.global_position.y,"hp":run.player.health.current_health,"enemies":run.living_enemies().size(),"shortcut":run.room.get("shortcut_open")})
func _run() -> void:
	native=DisplayServer.get_name()!="headless"
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or not native or not "--native-approved" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json";start_usec=Time.get_ticks_usec()
	if not _check(FileAccess.get_sha256(profile_path)==OS.get_environment("MINE_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("MINE_SOURCE_NPC"),"Exact earned source pair before prototype startup"):quit(2);return
	bot=CombatBot.new();root.add_child(bot)
	flow=preload("res://scenes/maps/shattered_mine_entry.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30)
	var hub: PrologueHub=flow.active_scene as PrologueHub
	if not _check(hub!=null and not flow.qa_tools_enabled and not flow.depth_expansion_enabled,"Standalone prototype uses ordinary hub owners and no production floor list"):await finish_mine(false);return
	starting_ledger=GearInventoryCodec.encode(hub.gear.inventory)
	_check(hub.gear.inventory.materials[&"dust"]==0 and hub.gear.inventory.materials[&"crystal"]==0,"Earned stash transfer leaves a genuine material need")
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	_stage("prototype_departure_actual_portal");await _shot("prototype_hub")
	if not await _walk(hub.player,hub.stations[&"portal"].global_position.x):await finish_mine(false);return
	await _key(KEY_E);await _step(20)
	var run: DungeonRun=flow.active_scene as DungeonRun
	if not _check(run!=null and run.get_script().resource_path.ends_with("shattered_mine_run.gd") and not run.content.qa_tools_enabled,"Actual E enters the standalone mine using ordinary prepared inventory"):await finish_mine(false);return
	if not _check(not run.floor_exit.is_open and run.player.controls_enabled,"Portal E is not consumed again by the mine entrance return choice"):await finish_mine(false);return
	run.gear.loot.pickup_collected.connect(mine_pickup)
	for enemy: Node2D in run.living_enemies():enemy.hurtbox.hit_resolved.connect(hit_received)
	mine_position("entry");await _shot("mine_entry")
	_stage("walk_down_main_slope")
	if not await _walk(run.player,2000,1800):await finish_mine(false);return
	mine_position("lower_arena");await _shot("mine_lower_arena")
	_stage("ordinary_ground_combat");bot.run=run;bot.enabled=true
	for i: int in 7200:
		if run.outcome!=&"" or run.living_enemies().is_empty():break
		await _step(1)
	bot.stop();await _step(20)
	if not _check(run.outcome==&"" and run.player.health.current_health>0 and run.living_enemies().is_empty() and actual_enemy_hits>0,"Ordinary input combat clears existing live enemies without damage/HP/AI overrides"):await finish_mine(false);return
	mine_position("combat_cleared")
	_stage("walk_up_main_slope_to_lever")
	if not await _walk(run.player,4500,1800):await finish_mine(false);return
	mine_position("east_lever");await _shot("mine_east_lever")
	_check(not run.room.get("shortcut_open"),"Shortcut stays closed until the actual interaction")
	await _key(KEY_E);await pause(.5)
	if not _check(run.room.get("shortcut_open"),"Physical E at the lever opens the return bridge"):await finish_mine(false);return
	_stage("optional_resource_spur")
	if not await _walk(run.player,5020):await finish_mine(false);return
	await _key(KEY_E)
	await pause(1.5);mine_position("resource_spur");await _shot("mine_resource_spur")
	if not _check(mine_sources.size()==2 and mine_sources.any(func(v: Dictionary)->bool:return v["item"]=="dust" and v["quantity"]==2) and mine_sources.any(func(v: Dictionary)->bool:return v["item"]=="crystal" and v["quantity"]==1),"Both real mine sources physically enter the bag exactly once"):await finish_mine(false);return
	_stage("return_across_open_upper_shortcut")
	if not await _walk(run.player,2600,1800):await finish_mine(false);return
	mine_position("upper_bridge_midpoint");await _shot("mine_shortcut")
	if not _check(absf(run.player.global_position.y-360)<12,"Player actually stands on the upper return bridge above the lower arena"):await finish_mine(false);return
	if not await _walk(run.player,180,1800):await finish_mine(false);return
	mine_position("west_return");await _key(KEY_E);await pause(.5)
	if not _check(run.floor_exit.is_open,"Actual entrance E opens the return choice"):await finish_mine(false);return
	await _click(run.floor_exit.return_button);await _step(20)
	if not _check(flow.active_scene is PrologueHub,"Existing GameFlow banks carried materials and returns to the hub"):await finish_mine(false);return
	if not await craft_from_bag():await finish_mine(false);return
	await finish_mine(true)
func finish_mine(complete: bool) -> void:
	bot.stop();var capture: Dictionary={}
	if is_instance_valid(recorder):await pause(.5);capture=recorder.finish()
	var result: Dictionary={"complete":complete,"checks":checks,"failures":failures,"profile_sha256":FileAccess.get_sha256(profile_path),"npc_sha256":FileAccess.get_sha256(profile_path+".npc_v1.json"),"mine_sources":mine_sources,"route":mine_route,"enemy_hits":actual_enemy_hits,"starting_ledger":starting_ledger,"craft":craft_result,"capture":capture,"scope":"Standalone mine private prototype, real earned QA pair and viewport input; no actor/stat/AI/loot overrides. Focused playthrough, not balance, FPS or crash fix proof."}
	var file:=FileAccess.open(evidence.path_join("shattered-mine-route.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	bot.queue_free();flow.queue_free()
	if is_instance_valid(recorder):recorder.queue_free()
	current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT ShatteredMineGameplay checks=%d failures=%d complete=%s"%[checks,failures,complete]);quit(0 if complete and failures==0 else 1)

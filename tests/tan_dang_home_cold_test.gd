extends "res://tests/tan_dang_home_loop_test.gd"
## Separate-process verification of copied, actually earned post-teardown saves.
## Root copies all existing sidecars; this test never creates/edits a fixture.
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
		if arg == "--native-approved": capture = true
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").to_lower().trim_suffix("/")
	var source_path: String = OS.get_environment("SECT_HOME_SOURCE_PATH").replace("\\","/").simplify_path()
	var userdata_root: String = OS.get_user_data_dir().replace("\\","/").simplify_path().trim_suffix("/")
	var expected_path: String = OS.get_environment("SECT_HOME_EXPECTED")
	if not _check(FileAccess.file_exists(expected_path),"The prior native loop receipt is provided"):
		quit(2); return
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	if not _check(expected is Dictionary and expected.get("completed",false) and expected.get("failures",-1) == 0,"The source loop actually completed without failures"):
		quit(2); return
	var expected_profile: String = str(expected.get("post_teardown_profile_sha256","")).to_lower()
	var expected_npc: String = str(expected.get("post_teardown_npc_sha256","")).to_lower()
	var isolated: bool = qa.is_absolute_path() and userdata_root.to_lower().begins_with(qa+"/") and source_path.is_absolute_path() and source_path.to_lower().begins_with(userdata_root.to_lower()+"/")
	if not _check(isolated and capture == (DisplayServer.get_name() != "headless"),"Separate-process cold check requires copied files inside its own QA root and native opt-in"):
		quit(2); return
	# The writer deliberately accepts only user://. Keep the copied bytes and
	# relative filename; translate the verified QA filesystem path, not the data.
	path = "user://"+source_path.substr(userdata_root.length()+1)
	if not _check(ProjectSettings.globalize_path(path).simplify_path().to_lower() == source_path.to_lower(),"The writer-facing user:// path resolves to the exact copied QA participant"):
		quit(2); return
	if not _check(expected_profile.length() == 64 and expected_npc.length() == 64 and FileAccess.file_exists(path) and FileAccess.file_exists(path+".npc_v1.json"),"Expected post-teardown hashes and both copied participants are provided"):
		quit(2); return
	if not _check(FileAccess.get_sha256(path) == expected_profile and FileAccess.get_sha256(path+".npc_v1.json") == expected_npc,"Both cold input files exactly match the previous process's post-teardown bytes"):
		quit(2); return
	var original: Dictionary = Writer.read_json(path)
	var original_npc: Dictionary = Writer.read_json(path+".npc_v1.json")
	if not _check(Writer.seal_valid(original) and NpcWorldState.valid(original_npc) and original_npc["npc_schema"] == 9 and original_npc["records"].size() == 15,"Copied authority is sealed profile plus canonical NPC9, not a generated fixture"):
		quit(2); return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.unfocusable = true
	root.current_screen = mini(1,DisplayServer.get_screen_count()-1) if capture else 0
	root.size = Vector2i(1152,648)
	Engine.max_fps = 60 if capture else 0
	AudioServer.set_bus_mute(0,true)
	await _open_home_flow()
	if hub == null:
		_check(false,"Cold process opens ExteriorHub")
		await _close_home_flow()
		quit(1); return
	var progress: TanDangProgress = hub.tan_dang.progress
	var state: Dictionary = progress.state()
	if not _check(progress.available() and not flow.profile.hub_inventory_quarantined,"Existing owners accept both copied files without quarantine"):
		print("COLD_STARTUP_FAILURE "+JSON.stringify({"profile_read_only":flow.profile.read_only,"profile_last_commit":flow.profile.last_commit,"npc_read_only":progress.life.read_only,"path":path}))
		await _close_home_flow()
		root.get_node("AudioManager").stop_all()
		quit(1); return
	_check(hub.outside and hub.exterior.room_id == HomeCatalog.ROOM and hub.npc_population.state.records.size() == 15,"New process restores saved TD01 and all fifteen canonical lives")
	_check(hub.npc_population.actors.size() == 2 and hub.npc_population.actors.has(TanDangProgress.DEPUTY) and hub.npc_population.actors.has(TanDangProgress.LEADER),"Only the two living home officers are instantiated")
	_check(state["rewards"] == ["q1","q2","q3"] and state["contribution"] == 0 and progress.earned_merit() == 6 and state["recipe_claimed"] and state["recipe_paid"] and progress.known_recipe() and state["membership"] == "member","New process preserves one earned loop, paid recipe, zero contribution, merit6 and membership")
	_check(Writer.canonical(GearInventoryCodec.encode(hub.gear.inventory)) == Writer.canonical(original["hub_inventory"]) and flow.profile.coins == int(original.get("coins",0)) and flow.profile.souls == int(original["souls"]) and Writer.canonical(flow.profile.material_stash) == Writer.canonical(original["material_stash"]),"Cold load preserves exact carried UIDs and existing wallets/material storage, including an omitted zero-coin field")
	for officer: String in [TanDangProgress.DEPUTY,TanDangProgress.LEADER]:
		var record: Dictionary = hub.npc_population.state.records[officer]
		_check(record["room"] == String(HomeCatalog.ROOM) and record["death"] == original_npc["records"][officer]["death"] and record["hp"] == original_npc["records"][officer]["hp"],"Officer home, life and health survive independently: "+officer)
	var no_duplicates: bool = await _interact(StringName(TanDangProgress.DEPUTY))
	if no_duplicates:
		no_duplicates = _check(_choice_missing(&"td_q1_reward") and _choice_missing(&"td_q3_reward") and _choice_missing(&"td_recipe"),"Actual cold deputy dialog offers no repeated reward or book purchase")
		await _picture("cold-process-deputy-no-duplicates")
		var closed: bool = await _close_dialogue()
		no_duplicates = closed and no_duplicates
	_check(progress.state() == state and progress.earned_merit() == 6,"Reading the cold officer never regrants a completed transaction")
	var final_state: Dictionary = progress.state()
	await _close_home_flow()
	root.get_node("AudioManager").stop_all()
	_check(is_equal_approx(Engine.time_scale,1.0),"Cold teardown releases all modal claims")
	var receipt: Dictionary = {"checks":checks,"failures":failures,"completed":no_duplicates and failures == 0,"process_id":OS.get_process_id(),"source_path":source_path,"writer_path":path,"expected_profile_sha256":expected_profile,"expected_npc_sha256":expected_npc,"post_teardown_profile_sha256":FileAccess.get_sha256(path),"post_teardown_npc_sha256":FileAccess.get_sha256(path+".npc_v1.json"),"final_quest":final_state,"earned_merit":6,"proof":"separate process; exact copied post-teardown QA participants; normal startup and walking/E; no grants, warps or save edits"}
	var evidence: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	var output: String = evidence.path_join("tan-dang-home-cold.json") if not evidence.is_empty() else "user://tan_dang_home_cold.json"
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(receipt,"\t")); file.close()
	else: _check(false,"Cold receipt path is writable")
	print("RESULT tan_dang_home_cold checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

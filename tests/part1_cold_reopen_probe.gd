extends SceneTree
var checks: int=0
var failures: int=0
func _initialize() -> void:_run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)
func _step(count: int) -> void:
	for _i: int in count:await physics_frame;await process_frame
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"New isolated process user directory")
	var receipt_path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-receipt="):receipt_path=arg.trim_prefix("--source-receipt=").replace("\\","/")
	var allowed: String=qa.get_base_dir()+"/"
	_check(receipt_path.begins_with(allowed) and receipt_path.ends_with("/captures/first_loop.json") and not receipt_path.contains(".."),"Source is explicitly this task's synthetic loop receipt")
	if failures:quit(2);return
	var expected: Variant=JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
	_check(expected is Dictionary and expected.get("complete_loop",false) and expected.get("failures",1)==0,"Source loop completed without failed assertions")
	if failures:quit(2);return
	var source: String=String(expected["profile_path"]).replace("\\","/")
	_check(source.begins_with(receipt_path.get_base_dir().get_base_dir()+"/AppData/") and FileAccess.get_sha256(source)==expected["profile_sha256"],"Synthetic source matches its completed-loop SHA256")
	if failures:quit(2);return
	var destination: String="user://part1-first-loop/profile.json"
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var copied: Array[Dictionary]=[]
	for name: String in DirAccess.get_files_at(source.get_base_dir()):
		var original: String=source.get_base_dir().path_join(name)
		var target: String=destination.get_base_dir().path_join(name)
		_check(DirAccess.copy_absolute(original,target)==OK and FileAccess.get_sha256(original)==FileAccess.get_sha256(target),"Synthetic transaction family copied byte-exact: "+name)
		copied.append({"name":name,"sha256":FileAccess.get_sha256(target)})
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=120;AudioServer.set_bus_mute(0,true)
	var started: int=Time.get_ticks_usec()
	var flow: GameFlow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override=destination;root.add_child(flow);await _step(30)
	var hub: PrologueHub=flow.active_scene as PrologueHub
	_check(hub!=null and not flow.qa_tools_enabled and not flow.profile.read_only,"Actual main cold-load reaches editable product hub")
	_check(flow.profile.bounty_accepted and flow.profile.permanent_upgrades[&"max_hp"]==1 and flow.profile.souls==int(expected["souls"]),"Quest, paid HP upgrade and exact remaining bank persist")
	# Godot JSON reads numeric tokens as floats. Compare both QA snapshots through
	# the same parser; inventory UIDs are bounded by GearInventoryCodec.MAX_UID.
	_check(JSON.parse_string(JSON.stringify(flow.profile.hub_inventory))==expected["inventory"],"Saved inventory and item UIDs persist exactly")
	_check(JSON.parse_string(JSON.stringify(flow.profile.opening_objectives()))==expected["opening"],"Opening milestones persist exactly")
	_check(hub!=null and hub.player.health.maximum_health>=125.0,"Cold-loaded player receives the permanent HP upgrade")
	var evidence: String=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(evidence.path_join("cold_reopened.png"))==OK,"Native cold-reopen screenshot")
	var result: Dictionary={"checks":checks,"failures":failures,"elapsed_seconds":(Time.get_ticks_usec()-started)/1000000.0,"source_receipt":receipt_path,"source_sha256":expected["profile_sha256"],"destination":ProjectSettings.globalize_path(destination),"copied":copied,"souls":flow.profile.souls,"upgrades":flow.profile.permanent_upgrades}
	var out:=FileAccess.open(evidence.path_join("cold_reopen.json"),FileAccess.WRITE);out.store_string(JSON.stringify(result,"\t"));out.close()
	flow.queue_free();await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT Part1ColdReopen checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

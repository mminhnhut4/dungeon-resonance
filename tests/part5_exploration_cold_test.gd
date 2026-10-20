extends "res://tests/part5_exploration_runtime_test.gd"
## Separate-process cold proof. Only the runner's fresh QA profiles may be seeded.
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or not "--qa-seed-part5" in OS.get_cmdline_user_args():quit(2);return
	AudioServer.set_bus_mute(0,true)
	for next_branch: String in ["rescue","gate"]:
		branch=next_branch;path="user://verification/part5_runtime/"+branch+".json"
		_check(FileAccess.file_exists(path) and FileAccess.file_exists(path+".npc_v1.json"),"Explicit fresh QA source exists before separate-process load")
		flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow;flow.save_path_override=path;root.add_child(flow);current_scene=flow;await _frames(16);hub=flow.active_scene as ExteriorHub
		_check(hub.outside and hub.exterior.room_id==&"o01_p03" and hub.player.motor.is_grounded(),"New process restores a safe dry P03 anchor")
		_check(OpeningExplorationProgress.shortcut_open(flow.profile) and OpeningExplorationProgress.state_for(flow.profile)["cache_claimed"],"New process reads completion release and the one cache receipt")
		_check(hub.tan_dang.progress.alive(TanDangProgress.DU)==(branch=="rescue") and hub.exploration.scene_choice==branch,"Canonical permanent death / rescue and yard scene choice survive the new process")
		var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path);var dust: int=flow.profile.material_stash[&"dust"]
		_check(not hub.exploration.progress.claim().get("ok",false) and flow.profile.material_stash[&"dust"]==dust and FileAccess.get_file_as_bytes(path)==bytes,"Separate process cannot farm or rewrite a claimed cache")
		flow.queue_free();current_scene=null;await _frames(8)
	await root.get_node("AudioManager").shutdown()
	print("RESULT Part5ExplorationCold checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

extends "res://tests/part5_exploration_runtime_test.gd"
## Final source native check; uses only fresh QA profiles made by the story test.
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or not "--qa-seed-part5" in OS.get_cmdline_user_args() or not "--native-approved" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":quit(2);return
	native=true;root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=60;AudioServer.set_bus_mute(0,true)
	for next_branch: String in ["rescue","gate"]:
		branch=next_branch;path="user://verification/part5_runtime/"+branch+".json"
		flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow;flow.save_path_override=path;root.add_child(flow);current_scene=flow;await _frames(16);hub=flow.active_scene as ExteriorHub
		_check(hub.exploration.progress.available() and OpeningExplorationProgress.state_for(flow.profile)["cache_claimed"] and OpeningExplorationProgress.shortcut_open(flow.profile),"Final validator loads committed QA receipt/release, no personal data")
		await _key(KEY_M)
		var screen: InventoryScreen=hub.gear.modal as InventoryScreen;var journal: QuestJournal=screen.journal
		(journal.quest_buttons[&"opening_exploration"] as Button).grab_focus();await _key(KEY_ENTER)
		_check(journal.graph.shortcut and journal.selected_id==&"opening_exploration","Final M graph and navigation now share actual quest-derived physical release")
		var original: Vector2i=root.content_scale_size
		for dims: Vector2i in [Vector2i(1152,648),Vector2i(800,600)]:
			if dims.x==800:root.content_scale_size=dims
			root.size=dims;await _frames(5)
			_check(root.get_visible_rect().grow(2).encloses(screen.panel.get_global_rect()),"Final native/explicit logical800 modal fits viewport")
			journal.detail_scroll.scroll_vertical=0;await mark("final_map_%d"%dims.x,1)
		root.content_scale_size=original;root.size=Vector2i(1152,648);await _frames(5);await _key(KEY_ESCAPE)
		if not await _door(&"tunnel",&"o01_p02") or not await _door(&"door_west",&"o01_p01") or not await _door(&"door_west",ExteriorRouteCatalog.HUB):break
		_check(hub.exploration.scene_choice==branch and hub.tan_dang.progress.alive(TanDangProgress.DU)==(branch=="rescue"),"Final native return keeps branch scenery and canonical life")
		await _walk_x(1010);await mark("final_aftermath",1)
		flow.queue_free();current_scene=null;await _frames(8)
	await root.get_node("AudioManager").shutdown()
	print("RESULT Part5ExplorationNative checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

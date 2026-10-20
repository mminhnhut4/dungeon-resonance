extends SceneTree
## Explicit isolated story fixture; actual existing journal and owner publication.
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	Engine.physics_ticks_per_second = 120 if "--hz=120" in OS.get_cmdline_user_args() else 60
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+label)
func step(n: int = 4) -> void:
	for _i: int in ceili(float(n)*float(Engine.physics_ticks_per_second)/60.0): await physics_frame; await process_frame
func _run() -> void:
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if allowed.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"): quit(2); return
	var flow: GameFlow = preload("res://scenes/maps/prologue_hub.tscn").instantiate()
	flow.save_path_override = "user://verification/living_journal_%d_%d.json"%[OS.get_process_id(),Time.get_ticks_usec()]
	root.add_child(flow); await step(8)
	var hub: ExteriorHub = flow.active_scene as ExteriorHub
	hub.living.set_process(false); hub.npc_population.set_process(false)
	flow.profile.changed.disconnect(flow.cultivation_session._profile_changed)
	flow.cultivation_session.set_physics_process(false)
	var progress: TanDangProgress = hub.tan_dang.progress
	for pair: Array in [["accept","ledger"],["observe_lamp","lamp"],["find_lam","refuge"],["inspect_core","refuge"],["q1_reward",""],["choice_rescue","refuge"],["report_moc",TanDangProgress.MOC],["report_lam",TanDangProgress.LAM],["q3_reward",""]]:
		check(progress.apply(pair[0],"",pair[1]).get("ok",false),"Canonical story fixture commits "+pair[0])
	var screen: InventoryScreen = hub.gear.modal
	var journal: QuestJournal = screen.journal
	journal.refresh(); journal.relations_button.pressed.emit(); journal.hide()
	var original: int = journal.quest_list.get_child(0).get_instance_id()
	check(progress.life.start_living_event(progress.state()),"Finite NPC event commits through its sole owner")
	check(journal._projection_dirty and journal.quest_list.get_child(0).get_instance_id()==original,"Hidden journal receives the durable event publication without rebuilding buttons")
	var profile_bytes: PackedByteArray = FileAccess.get_file_as_bytes(flow.profile.save_path)
	var npc_bytes: PackedByteArray = FileAccess.get_file_as_bytes(progress.life.save_path)
	var key := InputEventKey.new(); key.physical_keycode=KEY_M; key.pressed=true; Input.parse_input_event(key)
	await step(); key.pressed=false; Input.parse_input_event(key); await step()
	journal.relations_button.pressed.emit(); await step()
	check(journal.is_visible_in_tree() and not journal._projection_dirty and journal.objective_label.text.contains("đang đi ra cửa"),"Actual M screen refreshes the newly started trip immediately, without waiting for another stop")
	check(FileAccess.get_file_as_bytes(flow.profile.save_path)==profile_bytes and FileAccess.get_file_as_bytes(progress.life.save_path)==npc_bytes,"Reading the refreshed relationship journal writes neither authority file")
	flow.queue_free(); await step(6); await root.get_node("AudioManager").shutdown()
	print("RESULT LivingJournal checks=%d failures=%d"%[checks,failures]); quit(0 if failures==0 else 1)

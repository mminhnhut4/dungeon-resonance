extends SceneTree
var failures: int=0
var checks: int=0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,title: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS: " if ok else "FAIL: ")+title)
func _run() -> void:
	var flow: GameFlow=preload("res://scenes/maps/prologue_hub.tscn").instantiate()
	flow.save_path_override="user://verification/hidden_journal.json"; root.add_child(flow)
	for _i: int in 8: await physics_frame; await process_frame
	var profile: SanctuaryProfile=flow.profile
	# Isolate the read-only projection from the separate auto-insight writer.
	profile.changed.disconnect(flow.cultivation_session._profile_changed)
	var before: String=FileAccess.get_file_as_string(profile.save_path)
	var journal: QuestJournal=flow.active_scene.gear.modal.journal
	var original: int=journal.quest_list.get_child(0).get_instance_id()
	journal.hide(); profile.opening_progress=OpeningProgress.with_event(profile.opening_progress,&"explored"); profile.changed.emit()
	check(journal._projection_dirty and journal.quest_list.get_child(0).get_instance_id()==original,"Hidden publication keeps the existing button tree and marks it dirty")
	profile.changed.emit(); profile.changed.emit()
	check(journal.quest_list.get_child(0).get_instance_id()==original,"Repeated hit publications coalesce while hidden")
	var key:=InputEventKey.new(); key.physical_keycode=KEY_M; key.pressed=true; Input.parse_input_event(key)
	for _i: int in 3: await physics_frame; await process_frame
	key.pressed=false; Input.parse_input_event(key)
	check(journal.is_visible_in_tree() and not journal._projection_dirty and journal.quest_list.get_child(0).get_instance_id()!=original and journal.rows.any(func(row: Dictionary) -> bool: return row["id"]==&"explored" and row["done"]),"Real M input flushes canonical progress before map presentation")
	journal.hide(); profile.opening_progress=OpeningProgress.with_event(profile.opening_progress,&"golem_defeated"); journal.refresh()
	check(journal.rows.any(func(row: Dictionary) -> bool: return row["id"]==&"golem_defeated" and row["done"]),"Explicit hidden refresh retains its synchronous API")
	check(FileAccess.get_file_as_string(profile.save_path)==before,"Projection refresh performs no save or reward")
	root.remove_child(flow); flow.queue_free()
	for _i: int in 4: await physics_frame; await process_frame
	await root.get_node("AudioManager").shutdown()
	print("RESULT hidden_journal checks=%d failures=%d"%[checks,failures]); quit(1 if failures else 0)

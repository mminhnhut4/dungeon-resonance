extends "res://tests/tan_dang_walkthrough_test.gd"
## Fresh normal-input loop. Uses the original walker, doors and focused buttons.
## No grants, fixture teleports, direct travel calls or edited save payloads.
const HomeCatalog = preload("res://scripts/world/tan_dang_home_catalog.gd")
var capture: bool = false

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
		if arg == "--native-approved": capture = true
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").to_lower().trim_suffix("/")
	if not _check(qa.is_absolute_path() and OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/") and capture == (DisplayServer.get_name() != "headless"),"Isolated QA root and explicit native opt-in"):
		quit(2); return
	path = "user://verification/tan_dang_home_loop_%d_%d.json" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	if not _check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".npc_v1.json"),"Fresh profile and NPC authority"):
		quit(2); return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.unfocusable = true
	root.current_screen = mini(1,DisplayServer.get_screen_count()-1) if capture else 0
	root.size = Vector2i(1152,648)
	Engine.max_fps = 60 if capture else 0
	AudioServer.set_bus_mute(0,true)
	await _open_home_flow()
	var completed: bool = await _walkthrough()
	_release_motion()
	var final_state: Dictionary = hub.tan_dang.progress.state() if is_instance_valid(hub) else {}
	var final_merit: int = hub.tan_dang.progress.earned_merit() if is_instance_valid(hub) else -1
	await _close_home_flow()
	root.get_node("AudioManager").stop_all()
	_check(is_equal_approx(Engine.time_scale,1.0),"Teardown releases modal time claims")
	var receipt: Dictionary = {"checks":checks,"failures":failures,"completed":completed,"blocked_at":blocked_at,"physics_hz":Engine.physics_ticks_per_second,"walked_ticks":walked_ticks,"walked_distance":walked_distance,"segments":segments,"checkpoints":checkpoints,"final_quest":final_state,"earned_merit":final_merit,"save_path":ProjectSettings.globalize_path(path),"post_teardown_profile_sha256":FileAccess.get_sha256(path),"post_teardown_npc_sha256":FileAccess.get_sha256(path+".npc_v1.json"),"proof":"fresh product; continuous Input walking; real E doors; focused buttons + Enter; cold GameFlow recreation; hashes after final scene teardown; no warps, direct grants or edited save"}
	var evidence: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	var output: String = evidence.path_join("tan-dang-home-loop.json") if not evidence.is_empty() else "user://tan_dang_home_loop_%d.json" % Engine.physics_ticks_per_second
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(receipt,"\t")); file.close()
	else: _check(false,"QA receipt path is writable")
	print("RESULT tan_dang_home_loop checks=%d failures=%d hz=%d walked_ticks=%d distance=%.2f completed=%s" % [checks,failures,Engine.physics_ticks_per_second,walked_ticks,walked_distance,completed])
	quit(0 if completed and failures == 0 else 1)

func _open_home_flow() -> void:
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path
	root.add_child(flow)
	current_scene = flow
	await _frames(12)
	hub = flow.active_scene as ExteriorHub

func _close_home_flow() -> void:
	flow.queue_free()
	current_scene = null
	await _frames(8)

func _picture(label: String) -> void:
	if not capture: return
	var evidence: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	if evidence.is_empty(): return
	if hub.dialogue.is_open:
		for _page: int in 60:
			if not hub.dialogue.is_typing() and hub.dialogue.page_index == hub.dialogue.pages.size()-1: break
			await _key(KEY_E)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))

func _choice_missing(id: StringName) -> bool:
	# Inspect actual offered controls; do not invoke a nonexistent choice.
	return not hub.tan_dang.offered.has(id) and hub.dialogue.choice_list.get_node_or_null("Choice_"+String(id)) == null

func _walkthrough() -> bool:
	if not _check(hub != null and not hub.outside and hub.player.position.distance_to(Vector2(430,640)) < 2.0 and hub.player.motor.is_grounded(),"Original product spawn and motor"):
		return false
	var original_actor: int = hub.player.get_instance_id()
	var gear: Dictionary = GearInventoryCodec.encode(hub.gear.inventory)
	var hp: float = hub.player.health.current_health
	var energy: float = hub.player.energy.current
	var coins: int = flow.profile.coins
	var souls: int = flow.profile.souls
	var progress: TanDangProgress = hub.tan_dang.progress
	if not _check(not flow.qa_tools_enabled and not progress.state()["accepted"] and not progress.known_recipe(),"Normal fresh product, no prepared grants or known purchase"):
		return false
	if not await _door(HomeCatalog.HUB_DOOR,HomeCatalog.ROOM): return false
	await _picture("00-home-gate")
	if not _check(not flow.profile.opening_objectives()["completed"].has("explored"),"Visiting own sect courtyard does not complete the road exploration milestone"): return false
	if not _check(hub.npc_population.actors.size() == 2 and hub.npc_population.actors.has(TanDangProgress.LEADER) and hub.npc_population.actors.has(TanDangProgress.DEPUTY),"One room creates exactly its two officer actors"): return false
	if not await _home_map(): return false
	if not await _interact(StringName(TanDangProgress.LEADER)): return false
	if not _check(hub.dialogue.speaker_label.text == "Tông chủ Đỗ Thanh Đăng" and _choice_missing(&"td_accept") and _choice_missing(&"td_join"),"Leader introduces the existing trial but cannot accept deputy work or admit before merit"): return false
	await _picture("01-tong-chu-trial")
	if not await _close_dialogue(): return false
	if not await _interact(StringName(TanDangProgress.DEPUTY)): return false
	if not _check(hub.dialogue.speaker_label.text == "Phó tông chủ Hà Nghi" and _choice_missing(&"td_join"),"Deputy has the requested visible title and no leader admission choice"): return false
	await _picture("02a-deputy-quest-offer")
	if not await _choose(&"td_accept"): return false
	if not _check(progress.state()["accepted"] and progress.earned_merit() == 0,"Actual deputy UI accepts the existing quest without granting merit"): return false
	await _picture("02-pho-tong-chu-accepted")
	if not await _close_dialogue(): return false
	if not await _door(&"door_west",ExteriorRouteCatalog.HUB): return false
	if not _check(flow.profile.exterior_progress["anchor_id"] == String(HomeCatalog.HUB_DOOR) and hub.player.global_position.distance_to(hub.stations[HomeCatalog.HUB_DOOR].global_position) < 8.0,"Home west door returns to its own durable hub anchor"): return false
	if not await _interact(TanDangJourney.LAMP): return false
	if not await _choose(&"td_observe_lamp"): return false
	if not await _close_dialogue(): return false
	if not await _door(&"exterior_road",&"o01_p01"): return false
	if not await _door(&"door_east",&"o01_p02"): return false
	if not await _door(&"door_east",&"o01_p03"): return false
	if not await _interact(TanDangJourney.REFUGE): return false
	for choice: StringName in [&"td_find_lam",&"td_inspect_core",&"td_q1_reward"]:
		if not await _choose(choice): return false
	if not _check(progress.earned_merit() == 2 and progress.state()["contribution"] == 2,"Existing evidence at real refuge earns first receipt once"): return false
	if not await _choose(&"td_choice_rescue"): return false
	if not _check(hub.dialogue.pending_choice == &"td_choice_rescue" and progress.state()["choice"] == "","Rescue still requires the ordinary confirmation"): return false
	hub.dialogue.confirm_button.grab_focus()
	await _key(KEY_ENTER)
	if not _check(progress.state()["choice"] == "rescue" and progress.alive(TanDangProgress.DU) and progress.earned_merit() == 4,"Confirmed real choice keeps its life consequence and second receipt"): return false
	if not await _close_dialogue(): return false
	if not await _door(&"door_west",&"o01_p02"): return false
	if not await _door(&"door_west",&"o01_p01"): return false
	if not await _door(&"door_west",ExteriorRouteCatalog.HUB): return false
	if not await _interact(StringName(TanDangProgress.MOC)): return false
	if not await _choose(&"td_report_moc"): return false
	if not await _close_dialogue(): return false
	if not await _interact(StringName(TanDangProgress.LAM)): return false
	if not await _choose(&"td_report_lam"): return false
	if not await _close_dialogue(): return false
	if not await _door(HomeCatalog.HUB_DOOR,HomeCatalog.ROOM): return false
	if not await _interact(StringName(TanDangProgress.DEPUTY)): return false
	if not await _choose(&"td_q3_reward"): return false
	if not _check(progress.state()["contribution"] == 6 and progress.earned_merit() == 6 and _choice_missing(&"td_q3_reward"),"Deputy closes the completed reports once; contribution6 and merit6"): return false
	await _picture("03-deputy-turn-in")
	if not await _choose(&"td_recipe"): return false
	if not _check(hub.dialogue.pending_choice == &"td_recipe" and progress.state()["contribution"] == 6,"Purchase asks confirmation before charging"): return false
	hub.dialogue.confirm_button.grab_focus()
	await _key(KEY_ENTER)
	if not _check(progress.known_recipe() and progress.state()["contribution"] == 0 and progress.earned_merit() == 6 and _choice_missing(&"td_recipe"),"One existing Hồi Đăng purchase spends contribution while merit remains6"): return false
	await _picture("04-book-purchased")
	if not await _close_dialogue(): return false
	if not await _interact(StringName(TanDangProgress.LEADER)): return false
	if not await _choose(&"td_join"): return false
	if not _check(hub.dialogue.pending_choice == &"td_join" and progress.state()["membership"] == "guest","Leader admission is voluntary and confirmed"): return false
	hub.dialogue.confirm_button.grab_focus()
	await _key(KEY_ENTER)
	if not _check(progress.state()["membership"] == "member" and progress.earned_merit() == 6,"Spent contribution does not block earned-merit admission"): return false
	await _picture("05-tong-chu-admission")
	if not await _close_dialogue(): return false
	if not _check(hub.player.get_instance_id() == original_actor and GearInventoryCodec.encode(hub.gear.inventory) == gear and hub.player.health.current_health == hp and hub.player.energy.current == energy and flow.profile.coins == coins and flow.profile.souls == souls,"Same Player, gear UIDs, HP/energy and existing currencies survive the whole walk"): return false
	var final_quest: Dictionary = progress.state()
	if not await _door(&"door_west",ExteriorRouteCatalog.HUB): return false
	await _close_home_flow()
	await _open_home_flow()
	progress = hub.tan_dang.progress
	if not _check(not hub.outside and flow.profile.exterior_progress["anchor_id"] == String(HomeCatalog.HUB_DOOR) and hub.player.global_position.distance_to(hub.stations[HomeCatalog.HUB_DOOR].global_position) < 8.0,"Cold hub entry restores the saved Tàn Đăng return anchor"): return false
	if not await _door(HomeCatalog.HUB_DOOR,HomeCatalog.ROOM): return false
	if not _check(progress.state() == final_quest and progress.earned_merit() == 6 and hub.npc_population.actors.size() == 2,"Reentry creates two officers without regranting rewards"): return false
	await _close_home_flow()
	await _open_home_flow()
	progress = hub.tan_dang.progress
	if not _check(hub.outside and hub.exterior.room_id == HomeCatalog.ROOM and hub.npc_population.actors.size() == 2 and progress.state() == final_quest,"Cold home entry restores its room, unique officers and exact quest receipts"): return false
	if not await _interact(StringName(TanDangProgress.DEPUTY)): return false
	if not _check(_choice_missing(&"td_q1_reward") and _choice_missing(&"td_q3_reward") and _choice_missing(&"td_recipe"),"Cold deputy offers no duplicate completed reward or purchased book"): return false
	await _picture("06-cold-home-no-duplicates")
	if not await _close_dialogue(): return false
	return _check(progress.known_recipe() and progress.state()["membership"] == "member" and progress.state()["contribution"] == 0 and progress.earned_merit() == 6,"Full map/NPC/quest/turn-in/purchase/admission/cold loop retains one completed result")

func _home_map() -> bool:
	await _key(KEY_M)
	await _frames(4)
	var screen: InventoryScreen = hub.gear.modal as InventoryScreen
	var journal: QuestJournal = screen.journal
	var button: Button = journal.quest_buttons.get(&"tan_dang_home") as Button
	if not _check(screen.is_open and button != null,"M opens the real journal with a navigable home entry"): return false
	button.grab_focus()
	await _key(KEY_ENTER)
	if not _check(journal.selected_id == &"tan_dang_home" and journal.graph.buttons.size() == 14 and MapQuestProjection.known_rooms(flow.profile).has(HomeCatalog.ROOM),"Home card and current room appear on the fourteen-node map"): return false
	await _picture("00-home-map")
	await _key(KEY_ESCAPE)
	return _check(not screen.is_open and hub.player.controls_enabled,"Closing M restores walking without a travel or reward transaction")

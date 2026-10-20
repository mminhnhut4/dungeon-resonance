extends "res://tests/depth_floor_selection_test.gd"
## Fresh isolated product flows. Relocations are explicit setup, not traversal proof.
var hub: ExteriorHub
var prefix: String

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
		if arg == "--native-approved": capture = true
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/") or capture != (DisplayServer.get_name() != "headless"):
		print("FAIL: isolated QA root and explicit native opt-in required")
		quit(2); return
	prefix = "user://verification/tan_dang_flow_%d_%d" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	for branch: String in ["gate","rescue"]:
		await _branch(branch)
	await _life_choices()
	print("RESULT tan_dang_flow checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

func _branch(branch: String) -> void:
	path = prefix+"_"+branch+".json"
	await _open()
	hub = flow.active_scene as ExteriorHub
	var journey: TanDangJourney = hub.tan_dang
	var actor: Player = hub.player
	var carried: Dictionary = GearInventoryCodec.encode(hub.gear.inventory)
	var coins: int = flow.profile.coins
	var souls: int = flow.profile.souls
	_check(journey != null and journey.progress.available(),"Product owns writable finite Tàn Đăng quest")
	_check(hub.npc_population.actors.size() == 1 and hub.npc_population.actors.has(TanDangProgress.MOC),"Fresh hub owns only Mộc Yên from new story")
	await _at(TanDangJourney.LEDGER)
	var before: Dictionary = _bytes()
	await _key(root,KEY_E)
	_check(hub.dialogue.is_open and not actor.controls_enabled,"Physical E opens real ledger modal")
	await _picture(branch+"_ledger_offer")
	hub.dialogue.close()
	await _step(3)
	_check(_bytes() == before and actor.controls_enabled and is_equal_approx(Engine.time_scale,1.0),"Close without choice changes neither file and restores controls")
	await _key(root,KEY_E)
	await _choose(&"td_accept")
	_check(journey.progress.state()["accepted"],"Explicit ledger choice accepts quest")
	await _close_dialogue()
	await _at(TanDangJourney.LAMP)
	await _key(root,KEY_E)
	await _choose(&"td_observe_lamp")
	_check("lamp" in journey.progress.state()["discoveries"],"Actual lamp interaction records missing core")
	await _close_dialogue()
	_check(hub.enter_exterior(&"o01_p03"),"Fixture enters existing P03 through existing travel owner")
	await _step(4)
	_check(hub.player == actor and hub.npc_population.actors.has(TanDangProgress.LAM) and hub.npc_population.actors.has(TanDangProgress.DU),"P03 creates unique living story actors without replacing Player")
	await _at(TanDangJourney.REFUGE)
	await _picture(branch+"_refuge")
	await _key(root,KEY_E)
	await _choose(&"td_find_lam")
	await _choose(&"td_inspect_core")
	await _choose(&"td_q1_reward")
	_check(journey.progress.state()["contribution"] == 2,"Three physical evidence facts yield one Q1 reward")
	before = _bytes()
	var choice := StringName("td_choice_"+branch)
	await _choose(choice)
	_check(hub.dialogue.pending_choice == choice and journey.progress.state()["choice"] == "" and _bytes() == before,"Irreversible choice first opens confirmation without writing")
	await _picture(branch+"_confirmation")
	hub.dialogue.cancel_confirmation()
	_check(_bytes() == before and journey.progress.state()["choice"] == "","Cancel confirmation leaves quest and NPC bytes identical")
	await _choose(choice)
	hub.dialogue.confirm_choice()
	await _step(3)
	_check(journey.progress.state()["choice"] == branch and journey.progress.state()["contribution"] == 4,"Confirmed choice commits branch and Q2 contribution together")
	_check(journey.progress.alive(TanDangProgress.DU) == (branch == "rescue"),"Canonical Dư Hành life matches chosen branch")
	_check(not hub.npc_population.actors.has(TanDangProgress.LAM) and not hub.npc_population.actors.has(TanDangProgress.DU),"Committed return/death removes old P03 representations")
	await _close_dialogue()
	_check(hub.return_to_hub(),"Return uses existing travel transaction")
	await _step(4)
	_check(hub.player == actor and hub.npc_population.actors.has(TanDangProgress.LAM),"Returned Lâm Tước exists exactly once in hub")
	if branch == "gate":
		await _at(TanDangJourney.LAMP)
		await _key(root,KEY_E)
		await _choose(&"td_install_core")
		await _close_dialogue()
	await _at(TanDangJourney.LAMP)
	await _picture(branch+"_lamp")
	_check(journey.progress.state()["lamp"] == ("lit" if branch == "gate" else "broken"),"Visible lamp reads committed finite state")
	await _at(StringName(TanDangProgress.MOC))
	await _key(root,KEY_E)
	await _choose(&"td_report_moc")
	await _close_dialogue()
	await _at(StringName(TanDangProgress.LAM))
	await _key(root,KEY_E)
	await _choose(&"td_report_lam")
	await _choose(&"td_q3_reward")
	_check(journey.progress.state()["contribution"] == 6 and journey.progress.state()["membership"] == "guest","Guest receives full three-quest contribution before joining")
	await _choose(&"td_recipe")
	hub.dialogue.confirm_choice()
	await _step(3)
	_check(journey.progress.known_recipe() and journey.progress.state()["contribution"] == 0 and flow.profile.souls == souls,"Hồi Đăng grants exact existing firestorm without Souls fee")
	await _choose(&"td_support")
	_check(journey.progress.state()["support_claimed"] and hub.dialogue.pages.any(func(line: String) -> bool: return line.contains("TRÚC CƠ")),"Support displays current cultivation next step")
	await _choose(&"td_decline")
	_check(journey.progress.state()["declined"] and journey.progress.state()["membership"] == "guest","Player may stay independent after full rewards")
	await _close_dialogue()
	var helper: String = TanDangProgress.MOC if branch == "gate" else TanDangProgress.LAM
	await _at(StringName(helper))
	await _key(root,KEY_E)
	var linen: int = int(flow.profile.material_stash.get(&"linen_fiber",0))
	await _choose(&"td_assist")
	_check(hub.dialogue.pending_choice==&"td_assist","One-time aid requires the actual confirmation")
	hub.dialogue.confirm_choice();await _step(4)
	_check(int(flow.profile.material_stash.get(&"linen_fiber",0)) == linen+2 and journey.progress.life.karma(helper)["assistance_used"],"Grateful NPC deposits one aid grant into existing warehouse atomically")
	await _close_dialogue()
	_check(GearInventoryCodec.encode(hub.gear.inventory) == carried and flow.profile.coins == coins and flow.profile.souls == souls,"Story, travel and aid preserve carried UIDs, coins and Souls")
	await _journal(branch)
	await _close()
	await _open()
	hub = flow.active_scene as ExteriorHub
	journey = hub.tan_dang
	_check(journey.progress.state()["choice"] == branch and journey.progress.state()["rewards"].size() == 3 and journey.progress.known_recipe(),"Cold product load retains choice, receipts and knowledge")
	_check(journey.progress.alive(TanDangProgress.DU) == (branch == "rescue"),"Cold load never resurrects gate victim")
	await _close()

func _life_choices() -> void:
	path = prefix+"_life.json"
	await _open()
	hub = flow.active_scene as ExteriorHub
	var life: NpcWorldState = hub.npc_population.state
	await _at(StringName(TanDangProgress.MOC))
	_check(life.receive_hit(TanDangProgress.MOC,1.0,1000.0),"Fixture downs Mộc Yên through authoritative life owner")
	await _step(3)
	await _key(root,KEY_E)
	var before: Dictionary = _bytes()
	await _choose(&"pilot_kill_sect")
	_check(hub.dialogue.pending_choice == &"pilot_kill_sect" and life.records[TanDangProgress.MOC]["mode"] == "downed","Execution requires actual confirmation modal")
	await _picture("life_execution_confirmation")
	hub.dialogue.cancel_confirmation()
	_check(_bytes() == before,"Cancelled execution preserves both durable files")
	await _choose(&"pilot_spare")
	_check(life.records[TanDangProgress.MOC]["mode"] == "recovering" and life.karma(TanDangProgress.MOC)["spared"] and life.karma(TanDangProgress.MOC)["grievance"] == "attacked","Spare preserves life and grievance without buying forgiveness")
	await _close_dialogue()
	_check(hub.enter_exterior(&"o01_p03"),"Fixture enters P03 for explicit execution")
	await _step(4)
	var id: String = TanDangProgress.DU
	await _at(StringName(id))
	_check(life.receive_hit(id,1.0,1300.0),"Fixture downs Dư Hành")
	await _step(3)
	await _key(root,KEY_E)
	await _choose(&"pilot_kill_sect")
	hub.dialogue.confirm_choice()
	await _step(4)
	_check(not hub.tan_dang.progress.alive(id) and life.karma(id)["player_murdered"] and not hub.npc_population.actors.has(id),"Confirmed execution persists canonical murder and removes physical actor")
	_check(not hub.tan_dang.progress.can_join(),"Recorded player murder blocks new invitation")
	await _close_dialogue()
	_check(hub.return_to_hub(),"Life-choice fixture returns through real owner")
	await _step(3)
	await _at(TanDangJourney.LEDGER)
	await _key(root,KEY_E)
	_check(hub.dialogue.speaker_label.text == "Sổ Tàn Đăng Môn" and hub.dialogue.pages.any(func(line: String) -> bool: return line.contains("M → Quan hệ")),"Physical ledger keeps its narrator and points to full relationship memory")
	await _picture("life_karma_ledger")
	await _close_dialogue()
	await _key(root,KEY_M)
	await _step(3)
	var memory: QuestJournal = (hub.gear.modal as InventoryScreen).journal
	memory.relations_button.pressed.emit()
	await _step(3)
	_check(memory.selected_id == &"tan_dang_relations" and memory.objective_label.visible and memory.objective_label.text.contains("Đã chết vĩnh viễn"),"Actual M relationship journal exposes permanent death without impersonating dead NPC")
	await _key(root,KEY_ESCAPE)
	await _step(3)
	await _close()
	await _open()
	hub = flow.active_scene as ExteriorHub
	_check(not hub.tan_dang.progress.alive(id) and hub.tan_dang.progress.life.karma(id)["player_murdered"],"Cold launch retains explicit death and culprit")
	await _close()

func _journal(branch: String) -> void:
	var screen: InventoryScreen = hub.gear.modal as InventoryScreen
	for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		root.size = extent
		await _key(root,KEY_M)
		await _step(4)
		var journal: QuestJournal = screen.journal
		var count: int = 0
		for row: Dictionary in journal.projection_rows():
			if row["id"] in [&"tan_dang_q1",&"tan_dang_q2",&"tan_dang_q3"]:
				count += 1
				_check(row["done"] and row["card"]["optional"],"Completed story card remains inspectable and optional")
		_check(count == 3 and screen.is_open,"Map UI contains all three canonical story cards")
		journal.select_quest(&"tan_dang_q3")
		_check(root.get_visible_rect().encloses(screen.panel.get_global_rect()),"Story map panel fits "+str(extent))
		await _picture(branch+"_journal_%d" % extent.x)
		screen.close()
		await _step(3)

func _bytes() -> Dictionary:
	return {"profile":FileAccess.get_file_as_bytes(path),"npc":FileAccess.get_file_as_bytes(path+".npc_v1.json")}

func _at(key: StringName) -> void:
	var at: Vector2
	if hub.stations.has(key) and not hub.outside: at = hub.stations[key].global_position
	elif hub.npc_population.actors.has(String(key)): at = hub.npc_population.actors[String(key)].global_position
	else: at = hub.exterior.to_global(hub.exterior.interactions[key])
	PlayerTravel.relocate(hub.player,at)
	hub.door_latched = false
	await _step(4)
	_check(hub.nearest_station() == key and hub.player.motor.is_grounded(),"Fixture reaches real interaction "+String(key))

func _choose(id: StringName) -> void:
	for _index: int in 35:
		if not hub.dialogue.is_typing() and hub.dialogue.page_index == hub.dialogue.pages.size()-1: break
		hub.dialogue.advance()
	hub.dialogue.select_choice(id)
	await _step(3)

func _close_dialogue() -> void:
	hub.dialogue.close()
	await _step(3)

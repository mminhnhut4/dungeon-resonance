extends SceneTree
## Actual main input dispatch and explicitly enabled private QA compatibility.

var checks: int = 0
var failures: int = 0
var baseline_repro: bool = false
var fixture_serial: int = 0
var qa_user_root: String = ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--baseline-repro": baseline_repro = true
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
		if arg.begins_with("--qa-user-root="): qa_user_root = arg.trim_prefix("--qa-user-root=").replace("\\", "/").simplify_path().trim_suffix("/")
	call_deferred("_run")

func _run() -> void:
	var user_dir: String = OS.get_user_data_dir().replace("\\", "/")
	print("QA_USER_DIR: ", user_dir)
	if not qa_user_root.is_absolute_path() or not user_dir.to_lower().begins_with(qa_user_root.to_lower() + "/"):
		push_error("Refusing a user directory outside this private QA workspace")
		quit(2)
		return
	get_root().get_node("AudioManager").enabled = false
	await _production()
	if not baseline_repro: await _enabled_qa()
	await _step(5)
	_check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "Teardown releases time and pause claims")
	print("RESULT OpeningQaGate checks=%d failures=%d hz=%d baseline_repro=%s" % [checks, failures, Engine.physics_ticks_per_second, baseline_repro])
	quit(0 if failures == 0 else 1)

func _flow(qa: bool = false) -> GameFlow:
	fixture_serial += 1
	var flow: GameFlow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/opening_gate_%d_%d.json" % [OS.get_process_id(), fixture_serial]
	if qa: flow.qa_tools_enabled = true
	root.add_child(flow)
	current_scene = flow
	return flow

func _production() -> void:
	var flow: GameFlow = _flow()
	await _step(8)
	var hub: PrologueHub = flow.active_scene as PrologueHub
	_check(hub.get("qa_tools_enabled") != true, "Main starts without QA capability")
	_check(not hub.stations.has(&"test_chest") and not is_instance_valid(hub.test_chest), "Main has no test chest actor or interaction marker")
	var inventory_before: Dictionary = GearInventoryCodec.encode(hub.gear.inventory)
	var economy_before: Dictionary = _economy(flow.profile)
	_check(not hub.claim_test_chest(), "Direct demo reward call is rejected in main")
	_check(GearInventoryCodec.encode(hub.gear.inventory) == inventory_before and _economy(flow.profile) == economy_before, "Rejected reward cannot change UID inventory or economy")
	hub.open_station(&"test_chest")
	_check(not hub.station_open, "Direct station opening cannot reveal the QA chest menu")
	if hub.station_open: hub.close_station()
	# Ordinary E and Tab still enter their existing runtime routes.
	hub.player.relocate(hub.stations[&"stash"].global_position)
	await _step(3)
	await _key(KEY_E)
	_check(hub.station_open and hub.current_station == &"stash", "E still opens the legitimate stash interaction")
	hub.close_station()
	await _key(KEY_TAB)
	_check(hub.gear.modal.is_open, "Tab still opens the legitimate inventory")
	hub.gear.modal.close()
	flow.start_campaign()
	await _step(8)
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	_freeze_combat(run)
	_check(run.content.get("qa_tools_enabled") != true, "Main campaign starts without QA content capability")
	# The existing authored exploration stage supplies real fire barriers.
	_check(run.enter_stage(2), "Fixture reaches the existing exploration room")
	await _step(4)
	var before: Dictionary = _snapshot(run, flow.profile)
	for code: int in [KEY_F5, KEY_F6, KEY_F7, KEY_F8]:
		await _key(code)
		_check(_snapshot(run, flow.profile) == before, "Main key %s leaves UID inventory, economy, stage and barriers unchanged" % OS.get_keycode_string(code))
		_check(not run.content.panel_open, "Main key %s cannot expose the granting matrix" % OS.get_keycode_string(code))
	# Direct APIs and stale UI callbacks use the same capability boundary.
	run.content.cycle_weapon()
	_check(not run.content.select_recipe(&"firestorm"), "Direct recipe grant is rejected without QA capability")
	run.content.unlock_secret()
	run.content.open()
	_check(_snapshot(run, flow.profile) == before and not run.content.panel_open, "Direct helpers cannot bypass the input gate")
	flow.queue_free()
	await _step(6)

func _enabled_qa() -> void:
	var flow: GameFlow = _flow(true)
	await _step(8)
	var hub: PrologueHub = flow.active_scene as PrologueHub
	_check(hub.qa_tools_enabled and hub.stations.has(&"test_chest") and is_instance_valid(hub.test_chest), "Explicit private QA capability builds the demo chest")
	_check(hub.claim_test_chest(), "Explicit QA fixture can claim its existing demo items")
	var owned: int = hub.gear.inventory.items.size()
	_check(not hub.claim_test_chest() and hub.gear.inventory.items.size() == owned, "QA demo keeps its once-per-session guard")
	flow.start_campaign()
	await _step(8)
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	_freeze_combat(run)
	_check(run.content.qa_tools_enabled, "GameFlow forwards explicit QA capability to its campaign")
	_check(run.enter_stage(2), "QA fixture reaches real authored barriers")
	await _step(4)
	await _key(KEY_F5)
	_check(run.gear.inventory.items.values().all(func(item: GearItem) -> bool: return item.uid > 0) and ContentSession.WEAPON_IDS.all(func(id: StringName) -> bool: return run.gear.inventory.items.values().any(func(item: GearItem) -> bool: return item.kind == &"weapon" and item.definition_id == id)), "Enabled F5 retains the four debug weapon fixtures")
	await _key(KEY_F6)
	_check(run.content.panel_open, "Enabled F6 retains the QA matrix")
	_check(run.content.select_recipe(&"firestorm") and not run.content.panel_open and run.player.resonance_controller.get_recipe().id == &"firestorm", "Enabled QA recipe selection grants and equips the exact pair")
	await _key(KEY_F7)
	_check(_barriers(run).all(func(opened: bool) -> bool: return opened) and run.content.relics.owned.size() == RelicRuntime.CATALOG.size(), "Enabled F7 retains real barrier and relic fixture setup")
	await _key(KEY_F8)
	_check(run.stage == 4 and is_instance_valid(run.boss), "Enabled F8 retains direct boss fixture setup")
	run.finish(&"defeat")
	flow.show_hub(true)
	await _step(7)
	hub = flow.active_scene as PrologueHub
	_check(hub.qa_tools_enabled and is_instance_valid(hub.test_chest), "QA opt-in survives a fresh Hub representation")
	_check(not hub.claim_test_chest(), "QA return does not reset the existing session claim marker")
	flow.queue_free()
	await _step(6)

func _freeze_combat(run: DungeonRun) -> void:
	run.survival.director.automatic = false
	run.feedback.hit_stop_seconds = 0.0
	run.player.health.minimum_health = 1.0
	for enemy: Node2D in run.living_enemies(): enemy.set("ai_enabled", false)

func _economy(profile: SanctuaryProfile) -> Dictionary:
	return {"souls": profile.souls, "coins": profile.coins, "stash": profile.material_stash.duplicate(true), "proofs": profile.boss_proofs.duplicate(true), "receipts": profile.boss_receipts.duplicate(), "upgrades": profile.permanent_upgrades.duplicate(true), "bounty_accepted": profile.bounty_accepted, "bounty_claimed": profile.bounty_claimed}

func _barriers(node: Node) -> Array[bool]:
	var result: Array[bool] = []
	for child: Node in node.get_children():
		if child is EnvironmentBarrier: result.append(child.is_open)
		result.append_array(_barriers(child))
	return result

func _snapshot(run: WorldCampaign, profile: SanctuaryProfile) -> Dictionary:
	return {"inventory": GearInventoryCodec.encode(run.gear.inventory), "economy": _economy(profile), "stage": run.stage, "barriers": _barriers(run.room), "relics": run.content.relics.owned.duplicate()}

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _step(2)
	event.pressed = false
	Input.parse_input_event(event)
	await _step(2)

func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)

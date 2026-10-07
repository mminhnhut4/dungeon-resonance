extends SceneTree
## Completed-floor return through real GameFlow, finite pickups and writer faults.
class FaultProfile extends SanctuaryProfile:
	var reject: bool = false
	var fault: StringName = &"write"
	var writes: int = 0
	func save() -> bool:
		writes += 1
		return super.save()
	func _open_writer(path: String) -> FileAccess:
		return null if reject and fault == &"write" else super._open_writer(path)
	func _rename_file(source: String, target: String) -> Error:
		return ERR_CANT_CREATE if reject and fault == &"commit" and source == save_path + ".tmp" and target == save_path else super._rename_file(source, target)

var checks: int = 0
var failures: int = 0
var directory: String
var gpu: bool = false
var images: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", label])

func _step(count: int = 3) -> void:
	for _index: int in count:
		await physics_frame
		await process_frame

func _open(id: String, saved_path: String = "") -> GameFlow:
	var flow := GameFlow.new()
	flow.hub_scene = preload("res://scenes/hub/exterior_hub_room.tscn")
	flow.campaign_scene = preload("res://scenes/world_campaign.tscn")
	flow.world_building_enabled = true
	flow.save_path_override = directory + "/" + id + "/profile.json" if saved_path.is_empty() else saved_path
	root.add_child(flow)
	flow.set_process(false)
	flow.cultivation_session.set_physics_process(false)
	flow.active_scene.npc_population.set_process(false)
	await _step()
	return flow

func _close(flow: GameFlow) -> void:
	flow.queue_free()
	await _step(4)
	_check(is_equal_approx(Engine.time_scale, 1.0) and TimeScaleClaims.owner_count(self) == 0, "Scene cleanup releases modal claims")

func _start(flow: GameFlow) -> WorldCampaign:
	flow.start_campaign()
	await _step()
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	run.feedback.hit_stop_seconds = 0.0
	run.feedback.enable_global_hitstop(false)
	run.gear.loot.drop_table = run.gear.loot.drop_table.duplicate(true) as DropTableResource
	run.gear.loot.drop_table.none_chance = 1.0
	run.gear.loot.drop_table.blueprint_chance_total = 0.0
	return run

func _clear_floor(run: WorldCampaign) -> void:
	for _attempt: int in 4:
		for enemy: Node2D in run.living_enemies(): enemy.health.apply_damage(99999)
		await _step(4)
		if not run.room.locked: break
	_check(not run.room.locked and run.living_enemies().is_empty(), "Actual deaths finish all waves before the exit unlocks")

func _exit(run: DungeonRun) -> void:
	PlayerTravel.relocate(run.player, Vector2(1240, 640), PlayerTravel.Kind.INTRA_EXPEDITION)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _step(2)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await _step(2)

func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await _step(2)
	event = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = false
	Input.parse_input_event(event)
	await _step(2)

func _loot(run: DungeonRun) -> Dictionary:
	var rune: LootPickup = run.gear.loot.spawn(&"rune", &"fire", run.player.position)
	var coins: LootPickup = run.gear.loot.spawn(&"coins", &"coins", run.player.position, 11)
	var material: LootPickup = run.gear.loot.spawn(&"material", &"dust", run.player.position, 3)
	for pickup: LootPickup in [rune, coins, material]:
		pickup.automatic = false
		_check(pickup.collect() and not pickup.collect(), "Finite carried pickup collects exactly once")
	var expected: Dictionary = GearInventoryCodec.encode(run.gear.inventory)
	expected["run_coins"] = 0
	return expected

func _fault(flow: GameFlow, stage: StringName) -> FaultProfile:
	var bank := FaultProfile.new()
	bank.save_path = flow.profile.save_path
	_check(bank.load_profile(), "Writer-fault profile loads the native committed file")
	bank.fault = stage
	flow.profile = bank
	flow.active_scene.profile = bank
	flow.active_scene.economy.profile = bank
	return bank

func _return_and_reload() -> void:
	var flow: GameFlow = await _open("return")
	var run: WorldCampaign = await _start(flow)
	_check(not run.request_floor_return(), "Locked first floor cannot retreat or bank loot")
	await _clear_floor(run)
	_check(not run.can_choose_floor_exit(), "Cleared floor still requires reaching the native exit")
	_exit(run)
	var expected: Dictionary = _loot(run)
	await _step()
	_check(run.can_choose_floor_exit() and run.floor_exit.open(), "Cleared native exit opens the choice")
	_check(run.floor_exit.continue_button.visible and run.floor_exit.return_button.visible, "Continue and return are adjacent choices")
	await _key(KEY_SPACE)
	_check(run.floor_exit.is_open and run.stage == 1 and run.outcome == &"", "Space cannot select either floor outcome")
	await _key(KEY_ESCAPE)
	_check(not run.floor_exit.is_open and run.player.controls_enabled and run.gear.inventory.run_coins == 11, "Cancel resumes the same cleared floor without banking or loss")
	var path: String = flow.profile.save_path
	_check(run.floor_exit.open() and run.request_floor_return() and not run.request_floor_return(), "Return request latches exactly once")
	await _step()
	_check(flow.active_scene is ExteriorHub and not flow.return_save_pending, "Successful return swaps into the native safe Hub")
	_check(GearInventoryCodec.encode(flow.active_scene.gear.inventory) == expected and flow.profile.coins == 11, "Safe Hub owns exact collected item UIDs/materials and one coin deposit")
	_check(not flow.profile.opening_progress["completed"].has("returned_to_hub") and flow.profile.boss_proofs[&"golem"] == 0, "First-floor retreat invents no victory return or boss proof")
	_check(flow.show_hub(false) and flow.profile.coins == 11, "Repeated Hub callback cannot duplicate deposit")
	await _step()
	await _close(flow)
	flow = await _open("reload", path)
	_check(GearInventoryCodec.encode(flow.active_scene.gear.inventory) == expected and flow.profile.coins == 11, "Cold reload restores banked snapshot exactly once")
	var next: WorldCampaign = await _start(flow)
	_check(next.stage == 1 and GearInventoryCodec.encode(next.gear.inventory) == expected and flow.profile.hub_inventory.is_empty(), "Next run starts at floor one and transfers ownership once; no resume")
	await _close(flow)

func _continue_and_floor_rules() -> void:
	var flow: GameFlow = await _open("continue")
	var run: WorldCampaign = await _start(flow)
	await _clear_floor(run)
	_exit(run)
	var before: Dictionary = GearInventoryCodec.encode(run.gear.inventory)
	_check(run.floor_exit.open(), "Continue fixture opens first-floor exit")
	run.floor_exit.continue_button.pressed.emit()
	await _step()
	_check(run.stage == 2 and run.outcome == &"" and GearInventoryCodec.encode(run.gear.inventory) == before, "Continue keeps the current run and carried inventory")
	_check(not run.can_choose_floor_exit(), "Exploration is unlocked on entry but is not finished at spawn")
	_exit(run)
	_check(run.can_choose_floor_exit() and run.floor_exit.open(), "Existing exploration exit completes its floor without inventing a combat wave")
	await _joy(JOY_BUTTON_B)
	_check(not run.floor_exit.is_open and run.stage == 2, "Controller B cancels at exploration exit")
	_check(run.advance_room() and run.stage == 3 and run.room.locked, "Existing continuation enters the two-wave arena")
	for enemy: Node2D in run.living_enemies(): enemy.health.apply_damage(99999)
	await _step(4)
	_exit(run)
	_check(run.wave == 2 and run.room.locked and not run.request_floor_return(), "Arena first wave cannot count as a cleared floor")
	await _clear_floor(run)
	_exit(run)
	_check(run.can_choose_floor_exit() and run.request_floor_return(), "Arena return becomes valid only after the final wave")
	await _step()
	_check(flow.active_scene is ExteriorHub and flow.profile.boss_proofs[&"golem"] == 0 and not flow.profile.opening_progress["completed"].has("returned_to_hub"), "Arena retreat does not unlock Golem objectives")
	await _close(flow)

func _save_failure(stage: StringName) -> void:
	var flow: GameFlow = await _open("fault_" + String(stage))
	var bank: FaultProfile = _fault(flow, stage)
	var run: WorldCampaign = await _start(flow)
	await _clear_floor(run)
	_exit(run)
	var expected: Dictionary = _loot(run)
	await _step()
	var carried: Dictionary = GearInventoryCodec.encode(run.gear.inventory)
	var disk: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	bank.reject = true
	_check(run.floor_exit.open() and run.request_floor_return(), "%s return command is accepted once" % stage)
	_check(flow.active_scene == run and run.outcome == &"retreat" and flow.return_save_pending, "%s write failure keeps completed run alive" % stage)
	_check(GearInventoryCodec.encode(run.gear.inventory) == carried and bank.coins == 0 and bank.hub_inventory.is_empty() and FileAccess.get_file_as_bytes(bank.save_path) == disk, "%s failure rolls back bank while preserving every carried reward" % stage)
	_check(not run.floor_exit.continue_button.visible and not run.floor_exit.cancel_button.visible and run.floor_exit.return_button.text.begins_with("Thử lưu"), "%s failure exposes one explicit retry instead of discarding the run" % stage)
	var writes: int = bank.writes
	for _index: int in 5:
		flow._process(1.0)
		flow.show_hub(false)
		run.request_floor_return()
	_check(bank.writes == writes and not run.advance_room(), "%s repeated callbacks neither auto retry nor advance" % stage)
	await _key(KEY_ESCAPE)
	_check(run.floor_exit.is_open and flow.active_scene == run, "%s cancel cannot abandon unsaved carried rewards" % stage)
	_check(not flow.retry_pending_return() and bank.writes == writes + 1, "%s explicit failed retry makes one transaction attempt" % stage)
	bank.reject = false
	run.floor_exit.return_button.pressed.emit()
	await _step()
	_check(flow.active_scene is ExteriorHub and GearInventoryCodec.encode(flow.active_scene.gear.inventory) == expected and bank.coins == 11, "%s successful retry banks exact rewards once" % stage)
	_check(not flow.retry_pending_return() and not bank.opening_progress["completed"].has("returned_to_hub"), "%s retry clears without adding a victory milestone" % stage)
	await _close(flow)

func _pending_soul() -> void:
	var flow: GameFlow = await _open("pending_soul")
	var bank: FaultProfile = _fault(flow, &"write")
	var run: WorldCampaign = await _start(flow)
	await _clear_floor(run)
	_exit(run)
	bank.reject = true
	var pickup: LootPickup = run.gear.loot.spawn(&"soul", &"souls", run.player.position, 3)
	pickup.automatic = false
	_check(not pickup.collect() and run.has_pending_rewards(), "Failed permanent Soul pickup enters existing run escrow")
	_check(run.floor_exit.open() and run.request_floor_return() and flow.active_scene == run and bank.souls == 0, "Uncommitted Soul blocks retreat without destroying escrow")
	bank.reject = false
	run.floor_exit.return_button.pressed.emit()
	await _step()
	_check(flow.active_scene is ExteriorHub and bank.souls == 3 and not flow.retry_pending_return(), "Explicit retry commits escrow once then returns")
	await _close(flow)

func _boss_and_defeat() -> void:
	var flow: GameFlow = await _open("boss")
	var run: WorldCampaign = await _start(flow)
	_check(run.enter_stage(4), "Existing final Golem floor remains reachable")
	PlayerTravel.relocate(run.player, Vector2(1160, 640), PlayerTravel.Kind.INTRA_EXPEDITION)
	_check(not run.request_floor_return(), "Live Golem cannot be bypassed by floor return")
	run.boss.health.apply_damage(99999)
	await _step(5)
	_check(run.portal_active and run.floor_exit.open() and not run.floor_exit.continue_button.visible, "Final cleared floor offers return without a nonexistent next floor")
	_check(run.request_floor_return(), "Final portal uses the native victory owner")
	await _step()
	_check(flow.active_scene is ExteriorHub and flow.profile.boss_proofs[&"golem"] == 1 and flow.profile.opening_progress["completed"].has("returned_to_hub"), "Actual Golem victory retains its proof and victory-return milestone")
	await _close(flow)
	flow = await _open("defeat")
	run = await _start(flow)
	await _clear_floor(run)
	_exit(run)
	_loot(run)
	run.player.health.apply_damage(99999)
	_check(not run.request_floor_return() and flow.show_hub(true), "Death cannot claim a cleared-floor retreat")
	await _step()
	_check(flow.profile.coins == 0 and not flow.profile.opening_progress["completed"].has("returned_to_hub"), "Existing defeat discards carried coins without inventing victory")
	await _close(flow)

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join(name + ".png")
	_check(root.get_texture().get_image().save_png(path) == OK, "Native GPU capture " + name)
	images += 1

func _gpu_ui() -> void:
	var flow: GameFlow = await _open("gpu")
	var bank: FaultProfile = _fault(flow, &"write")
	var run: WorldCampaign = await _start(flow)
	await _clear_floor(run)
	_exit(run)
	_loot(run)
	await _step()
	await _key(KEY_SPACE)
	_check(not run.floor_exit.is_open, "Native Space at cleared exit does not open the menu")
	await _key(KEY_E)
	_check(run.floor_exit.is_open and root.gui_get_focus_owner() == run.floor_exit.continue_button, "Native E opens antique floor choice with keyboard focus")
	await _capture("floor_exit_choice")
	await _key(KEY_SPACE)
	_check(run.floor_exit.is_open and run.stage == 1, "Native Space inside choice cannot activate Continue")
	await _key(KEY_ESCAPE)
	_check(not run.floor_exit.is_open and run.player.controls_enabled, "Native Esc resumes the cleared floor")
	await _key(KEY_E)
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	_check(root.gui_get_focus_owner() == run.floor_exit.return_button, "Native D-pad selects Return beside Continue")
	await _capture("floor_exit_return_focus")
	bank.reject = true
	await _joy(JOY_BUTTON_A)
	_check(flow.return_save_pending and flow.active_scene == run and run.floor_exit.is_open, "Native A save failure retains run and opens retry state")
	await _capture("floor_exit_save_retry")
	bank.reject = false
	await _key(KEY_ENTER)
	_check(flow.active_scene is ExteriorHub and bank.coins == 11, "Native Enter retries and returns with one coin deposit")
	await _capture("floor_exit_returned_hub")
	await _close(flow)

func _postcheck() -> void:
	var flow: GameFlow = await _open("alpha_postcheck")
	flow.start_run()
	await _step()
	var run: DungeonRun = flow.active_scene as DungeonRun
	run.feedback.enable_global_hitstop(false)
	_check(not run.request_floor_return(), "Alpha locked floor blocks return")
	for enemy: Node2D in run.living_enemies(): enemy.health.apply_damage(99999)
	await _step(5)
	_exit(run)
	await _step()
	_check(run.floor_exit.exit_hint.is_visible_in_tree() and (run.floor_exit.exit_hint.get_child(0) as Label).is_visible_in_tree(), "Player-facing exit hint survives the debug overlay")
	_check(run.floor_exit.open() and not run.advance_room(), "Alpha open choice blocks competing room transition")
	run.floor_exit.continue_button.pressed.emit()
	await _step()
	_check(run.room_number == 2 and run.outcome == &"", "Alpha continues through its original room owner")
	await _close(flow)
	flow = await _open("capacity_postcheck")
	var campaign: WorldCampaign = await _start(flow)
	await _clear_floor(campaign)
	_exit(campaign)
	_loot(campaign)
	flow.profile.coins = MaterialCatalog.MAX_COUNT
	_check(flow.profile.save(), "Coin-capacity fixture writes a valid native bank")
	_check(campaign.floor_exit.open() and campaign.request_floor_return() and flow.active_scene == campaign and flow.return_save_error == &"coin_capacity", "Full bank keeps retreat pending with exact capacity reason")
	_check(campaign.gear.inventory.run_coins == 11 and flow.profile.coins == MaterialCatalog.MAX_COUNT, "Coin-capacity rejection neither drops nor duplicates carried coins")
	flow.profile.coins -= 11
	_check(flow.retry_pending_return(), "Capacity retry returns after legitimate room is available")
	await _step()
	_check(flow.active_scene is ExteriorHub and flow.profile.coins == MaterialCatalog.MAX_COUNT and not flow.profile.opening_progress["completed"].has("returned_to_hub"), "Capacity retry deposits once without a victory milestone")
	await _close(flow)

func _gpu_hint() -> void:
	var flow: GameFlow = await _open("gpu_hint")
	var run: WorldCampaign = await _start(flow)
	await _clear_floor(run)
	_exit(run)
	await _step()
	_check(run.floor_exit.exit_hint.is_visible_in_tree() and (run.floor_exit.exit_hint.get_child(0) as Label).is_visible_in_tree(), "Native clear-exit prompt is visible without debug HUD")
	await _capture("floor_exit_native_hint")
	_check(run.enter_stage(4), "Native final-room check uses existing Golem room")
	PlayerTravel.relocate(run.player, Vector2(1160, 640), PlayerTravel.Kind.INTRA_EXPEDITION)
	run.boss.health.apply_damage(99999)
	await _step(5)
	await _key(KEY_E)
	_check(run.floor_exit.is_open and not run.floor_exit.continue_button.visible, "Native final clear choice has return and cancel only")
	await _capture("floor_exit_final_choice")
	await _close(flow)

func _original_smoke() -> void:
	var flow: GameFlow = await _open("original_smoke")
	var run: WorldCampaign = await _start(flow)
	await _clear_floor(run)
	_exit(run)
	var expected: Dictionary = _loot(run)
	await _step()
	_check(run.floor_exit.exit_hint.is_visible_in_tree() and run.floor_exit.open(), "Applied floor UI and clear-exit hint are mounted")
	var saved_path: String = flow.profile.save_path
	_check(run.request_floor_return() and not run.request_floor_return(), "Applied return command is accepted once")
	await _step()
	_check(flow.active_scene is ExteriorHub and flow.profile.coins == 11 and GearInventoryCodec.encode(flow.active_scene.gear.inventory) == expected, "Applied flow banks exact collected UIDs/materials/coins into native Hub")
	_check(not flow.profile.opening_progress["completed"].has("returned_to_hub") and flow.profile.boss_proofs[&"golem"] == 0, "Applied first-floor return keeps boss and victory objectives locked")
	await _close(flow)
	flow = await _open("original_smoke_reload", saved_path)
	_check(flow.profile.coins == 11 and GearInventoryCodec.encode(flow.active_scene.gear.inventory) == expected, "Applied bank persists through cold profile reload")
	await _close(flow)

func _run() -> void:
	gpu = "--gpu" in OS.get_cmdline_user_args()
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\", "/").begins_with(allowed + "/"):
		print("FAIL: isolated QA profile required"); quit(2); return
	directory = "user://verification/floor_return_%d" % OS.get_process_id()
	Engine.physics_ticks_per_second = 60
	AudioServer.set_bus_mute(0, true)
	if "--original-smoke" in OS.get_cmdline_user_args(): await _original_smoke()
	elif "--postcheck" in OS.get_cmdline_user_args(): await _postcheck()
	elif "--hint-only" in OS.get_cmdline_user_args(): await _gpu_hint()
	elif gpu: await _gpu_ui()
	else:
		await _return_and_reload()
		await _continue_and_floor_rules()
		for stage: StringName in [&"write", &"commit"]: await _save_failure(stage)
		await _pending_soul()
		await _boss_and_defeat()
	print("RESULT FloorReturn checks=%d failures=%d gpu=%s images=%d" % [checks, failures, gpu, images])
	quit(0 if failures == 0 else 1)

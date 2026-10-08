extends SceneTree
## New quest transactions, real hub input and safe prepared-gear launch; synthetic saves only.
const Progress = preload("res://scripts/runtime/depth_progress.gd")
const Cultivation = preload("res://scripts/cultivation/opening_cultivation_state.gd")
class FaultProfile extends SanctuaryProfile:
	var fail_write: bool = false
	func _open_writer(path: String) -> FileAccess:
		if fail_write:
			fail_write = false
			return null
		return super._open_writer(path)
var checks: int = 0
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func _step(count: int = 4) -> void:
	for index: int in count: await physics_frame
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var directory: String = "user://verification/depth_quest_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var bank := FaultProfile.new()
	bank.save_path = directory + "/transaction.json"
	bank.load_profile()
	_check(bank.commit_cultivation(Cultivation.initial_proposal(Cultivation.new_progress(73), bank.material_stash, bank.souls, bank.boss_proofs)), "Fixture uses the actual v2 cultivation initialization contract")
	_check(bank.save(), "QA profile establishes sealed durable baseline")
	var progress = Progress.new(); progress.initialize(bank)
	_check(not progress.accept(), "Uncleared opening boss cannot accept deeper quest")
	_check(bank.record_boss_defeat("depth_quest_controlled_proof"), "Fixture records opening proof through existing durable owner")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	var souls: int = bank.souls
	bank.fail_write = true
	_check(not progress.accept() and not progress.state()["accepted"], "Failed accept rolls back the new namespace state")
	_check(bytes == FileAccess.get_file_as_bytes(bank.save_path) and souls == bank.souls, "Failed accept preserves exact disk bytes and bank")
	_check(progress.accept() and progress.state()["accepted"], "Retry durably accepts quest once")
	var revision: int = bank.extension_revision(Progress.SCOPE)
	_check(progress.accept() and revision == bank.extension_revision(Progress.SCOPE), "Repeated accept creates no duplicate receipt")
	_check(not progress.record(&"depth_floor_3", 3), "Floor milestone cannot skip an uncleared prerequisite")
	_check(not progress.record(&"depth_boss_defeated", 5), "Boss receipt cannot bypass the four earlier quest milestones")
	for number: int in 5:
		bytes = FileAccess.get_file_as_bytes(bank.save_path)
		bank.fail_write = true
		_check(not progress.record(StringName("depth_floor_%d" % (number + 1)), number + 1), "Floor %d failure remains pending without publishing" % (number + 1))
		_check(int(progress.state()["cleared"]) == number and bytes == FileAccess.get_file_as_bytes(bank.save_path), "Floor %d failure preserves state and bytes" % (number + 1))
		_check(progress.record(StringName("depth_floor_%d" % (number + 1)), number + 1), "Floor %d retry commits exact milestone" % (number + 1))
	_check(progress.record(&"depth_boss_defeated", 5), "Fifth-floor boss has distinct quest receipt")
	var cold := SanctuaryProfile.new(); cold.save_path = bank.save_path
	cold.load_profile()
	var cold_progress = Progress.new(); cold_progress.initialize(cold)
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(bank.save_path))
	_check(cold_progress.state() == progress.state() and SanctuaryProfile.CommitWriter.seal_valid(payload), "New reader restores five-floor progress with existing numeric seal")
	_check(not progress.record(&"depth_floor_99", 5), "Unrecognized events cannot write expedition progress")
	var flow: GameFlow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = directory + "/flow.json"
	root.add_child(flow); await _step(8)
	var hub: PrologueHub = flow.active_scene as PrologueHub
	var guide: Node2D = hub.get_node("DepthGuide") as Node2D
	_check(guide != null and guide.npc.portrait != null, "Product entrypoint installs the painted hub guide")
	_check(not flow.start_depth_campaign(), "Product deeper launch respects boss and accepted-quest gates")
	PlayerTravel.relocate(hub.player, Vector2(1055, 640)); await _step(5)
	var event := InputEventAction.new(); event.action = &"interact"; event.pressed = true
	Input.parse_input_event(event); await _step(3)
	event = InputEventAction.new(); event.action = &"interact"; event.pressed = false
	Input.parse_input_event(event); await _step(3)
	_check(guide.opened and not hub.player.controls_enabled and guide.action.disabled, "Real E input opens the locked quest panel and suspends movement")
	_check(not hub.gear.modal.open_button.visible, "Quest modal hides the inventory launcher to avoid overlapping screens")
	for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size = Vector2i.ZERO
		root.size = extent; guide._resize(); await _step(3)
		var bounds: Rect2 = root.get_visible_rect()
		_check(bounds.encloses(guide.panel.get_global_rect()) and guide.panel.get_global_rect().encloses(guide.action.get_global_rect()), "Quest panel and action fit %s" % extent)
	guide.close(); await _step()
	_check(hub.player.controls_enabled, "Closing quest restores controls")
	_check(hub.gear.modal.open_button.visible, "Closing quest restores the prior inventory launcher")
	_check(flow.profile.record_boss_defeat("depth_launch_controlled_proof"), "Product fixture durably unlocks the expansion")
	_check(guide.open(), "Unlocked guide can open at its physical location")
	guide._act(); await _step()
	_check(flow.depth_progress.state()["accepted"] and "Xuống tầng 1" in guide.action.text, "Actual quest action saves then clearly offers descent")
	var inventory: GearInventory = hub.gear.inventory
	var starter_uid: int = inventory.equipment_bag_uids()[0] if not inventory.equipment_bag_uids().is_empty() else inventory.items.keys()[0]
	guide._act(); await _step(8)
	var run: DungeonRun = flow.active_scene as DungeonRun
	_check(run != null and run.get("stage") == 1 and run.get_script().resource_path.ends_with("depth_campaign.gd"), "Guide launches first deeper floor through GameFlow")
	_check(run.gear.inventory.items.has(starter_uid), "Prepared gear UID survives hub-to-expedition ownership transfer")
	_check(run.player.health.current_health == run.player.health.maximum_health and run.player.energy.current == run.player.energy.maximum, "New expedition resets health and energy after gear preparation")
	_check(run.get("depth_progress_committer").is_valid(), "Run milestones use the single profile transaction owner")
	flow.queue_free(); await _step(8)
	_check(absf(Engine.time_scale - 1.0) < .001, "Guide and expedition teardown release time claims")
	print("RESULT: DepthQuest %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
## Real main, physical D/E and GUI mouse events, isolated QA userdata only.
## Writer faults are injected explicitly; they are not a claim about a user's PC.
var checks: int = 0
var failures: int = 0
var flow: GameFlow
var hub: PrologueHub

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\", "/").begins_with(allowed + "/"):
		print("FAIL: separate QA userdata required")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(800, 600)
	flow = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate() as GameFlow
	root.add_child(flow)
	current_scene = flow
	await _step(25)
	hub = flow.active_scene as PrologueHub
	_check(hub != null and hub.portal_feedback != null and not flow.qa_tools_enabled, "Configured main binds portal feedback without QA grants")
	if hub == null or hub.portal_feedback == null:
		await _finish()
		return
	_key(KEY_D, true)
	var frames: int = 0
	while hub.player.global_position.x < hub.stations[&"portal"].global_position.x - 10.0 and frames < 1800:
		await _step(1)
		frames += 1
	_key(KEY_D, false)
	await _step(12)
	_check(hub.nearest_station() == &"portal" and frames < 1800, "Physical D walks from stock spawn to the actual portal")
	var ui: Node = hub.portal_feedback
	_check(ui.panel.visible and ui.enter_button.is_visible_in_tree(), "Mouse entrance is visible at the dungeon portal")
	for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720)]:
		root.size = size
		await _step(5)
		_check(Rect2(Vector2.ZERO, Vector2(size)).encloses(ui.panel.get_global_rect()), "Entrance panel remains inside viewport %s" % str(size))
		_check(ui.panel.get_global_rect().encloses(ui.enter_button.get_global_rect()) and ui.panel.get_global_rect().encloses(ui.notice.get_global_rect()), "Entrance button and notice fit panel %s" % str(size))
	root.size = Vector2i(800, 600)
	await _step(5)
	var inventory: GearInventory = hub.gear.inventory
	var before_inventory: Dictionary = GearInventoryCodec.encode(inventory)
	var before_bytes: PackedByteArray = FileAccess.get_file_as_bytes(flow.profile.save_path)
	flow.profile._writer.fault_plan = {"write_candidate":true}
	await _press(KEY_E)
	_check(flow.active_scene == hub and flow.profile.last_commit.get("error") == "candidate_write_failed", "E preserves the save gate when candidate write fails")
	_check(ui.last_error == &"candidate_write_failed" and ui.notice.text.contains("candidate_write_failed"), "Failed departure shows the actual writer reason")
	_check(ui.last_probe.get("kind") == "departure_blocked" and ui.last_key.get("mapped_interact", false), "Trace distinguishes received E from blocked departure")
	_check(ui.panel.get_global_rect().encloses(ui.notice.get_global_rect()) and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(ui.panel.get_global_rect()), "Writer-failure text stays inside panel and viewport")
	_check(GearInventoryCodec.encode(inventory) == before_inventory and FileAccess.get_file_as_bytes(flow.profile.save_path) == before_bytes, "Save failure preserves every carried field and durable profile byte")
	var key_unmatched := InputEventKey.new()
	key_unmatched.device = 12345
	key_unmatched.keycode = KEY_E
	key_unmatched.physical_keycode = KEY_E
	key_unmatched.pressed = true
	Input.parse_input_event(key_unmatched)
	await _step(3)
	key_unmatched.pressed = false
	Input.parse_input_event(key_unmatched)
	await _step(3)
	_check(flow.active_scene == hub and ui.last_error == &"interact_key_unmatched", "Unmatched keyboard device is observed without forwarding/doubling interaction")
	_check(ui.notice.text.contains("nhấp nút"), "Unmatched-key feedback offers mouse entrance")
	flow.profile.read_only = true
	await _click(ui.enter_button)
	_check(flow.active_scene == hub and ui.last_error == &"profile_read_only_or_invalid_path", "Mouse entrance cannot bypass a protected profile")
	_check(GearInventoryCodec.encode(inventory) == before_inventory and FileAccess.get_file_as_bytes(flow.profile.save_path) == before_bytes, "Protected profile also retains inventory and disk bytes")
	flow.profile.read_only = false
	hub.gear.modal.open()
	await _step(3)
	_check(not ui.panel.visible, "Inventory modal hides portal controls")
	hub.gear.modal.close()
	await _step(3)
	_check(ui.panel.visible and hub.player.controls_enabled, "Closing inventory restores entrance and player controls")
	var uids: Array = inventory.items.keys()
	await _click(ui.enter_button)
	var run: DepthCampaign = flow.active_scene as DepthCampaign
	_check(run != null and run.connected_opening, "Actual GUI mouse click enters the same connected dungeon")
	if run != null:
		_check(run.gear.inventory.items.keys() == uids and inventory.items.is_empty(), "Mouse departure transfers exact UIDs once")
		_check(run.player.controls_enabled and run.player.health.current_health > 0.0, "Entered dungeon actor is alive and controllable")
	var reload := SanctuaryProfile.new()
	_check(reload.load_profile() and not reload.read_only and reload.hub_inventory.is_empty(), "Cold readback confirms prepared UIDs no longer remain in Hub save")
	root.remove_child(flow)
	flow.queue_free()
	await _step(4)
	flow = null
	# Component-only launch must give a clear reason instead of a false success hint.
	hub = load("res://scenes/hub/exterior_hub_room.tscn").instantiate() as PrologueHub
	root.add_child(hub)
	current_scene = hub
	await _step(15)
	hub.player.relocate(hub.stations[&"portal"].global_position)
	await _step(4)
	ui = hub.portal_feedback
	await _press(KEY_E)
	_check(hub.campaign_requested.get_connections().is_empty() and ui.last_error == &"missing_game_flow", "Component-only E explicitly identifies missing GameFlow")
	_check(ui.notice.text.contains("CHAY_GAME.cmd") and ui.notice.text.contains("F5"), "Component-only feedback gives the correct entrypoint")
	root.remove_child(hub)
	hub.queue_free()
	await _step(4)
	hub = null
	await _finish()

func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func _press(code: int) -> void:
	_key(code, true)
	await _step(3)
	_key(code, false)
	await _step(8)

func _click(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await _step(2)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await _step(2)
	await _step(8)

func _step(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed: failures += 1
	print("PASS: " if passed else "FAIL: ", label)

func _finish() -> void:
	if is_instance_valid(flow):
		root.remove_child(flow)
		flow.queue_free()
		await _step(3)
	print("RESULT portal_departure_feedback checks=%d failures=%d hz=%d" % [checks, failures, Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

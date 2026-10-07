extends SceneTree
## Technical fixture only. Does not certify authored O01/O02 or a folded P04.
var checks: int = 0
var failures: int = 0
var gpu: bool = false
var world: TraversalLabWorld
var actor: Player
var event_snapshot: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	gpu = DisplayServer.get_name() != "headless"
	if gpu:
		root.size = Vector2i(1152,648)
		root.content_scale_size = Vector2i(1280,720)
		AudioServer.set_bus_mute(0,true)
	world = preload("res://scenes/qa/exterior_traversal_lab.tscn").instantiate() as TraversalLabWorld
	root.add_child(world)
	current_scene = world
	world.checkpoint.path = "user://verification/lab_%d_%d.json" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	await _step(12)
	actor = world.player
	world.feedback.hit_stop_seconds = 0
	var inventory: GearInventory = world.gear.inventory
	var uids: Array = inventory.items.keys()
	world.profile.coins = 700
	inventory.run_coins = 13
	actor.health.current_health = 37
	actor.energy.current = 41
	actor.energy.regeneration_delay = 10000
	_check(world.profile.save_path.begins_with("user://verification/") and world.checkpoint.path.begins_with("user://verification/"), "Opening QA fixture cannot read/write the user's main profile")
	_check(world.lab.room_id == &"qa_traversal_lab_01" and actor.motor is BuildPlayerMotor, "Lab uses unchanged production Player and BuildPlayerMotor")
	_check(actor.floor_snap_length == 1.0 and is_equal_approx(actor.motor.run_speed,320), "Lab did not tune snap or run speed")
	for id: StringName in TraversalLabRoom.IDS:
		var geometry := TraversalLabRoom.new()
		_check(geometry.configure(id,false), "Typed lab ID builds: %s" % id)
		_check(geometry.valid_anchor(&"west") and geometry.valid_anchor(&"east"), "Both entries are dry, flat, wide: %s" % id)
		var safe: bool = true
		for index: int in geometry.surface.size() - 1:
			var delta: Vector2 = geometry.surface[index+1] - geometry.surface[index]
			safe = safe and absf(rad_to_deg(atan2(delta.y,delta.x))) <= 10.0
		_check(safe, "Every mandatory ramp stays within measured 10 degrees: %s" % id)
		geometry.free()
	await _walk_to(2450)
	_check(actor.motor.is_grounded() and absf(actor.global_position.y-640) < 2, "LAB01 W walks east, including below optional shelves, without jump/dash")
	await _walk_to(150)
	_check(actor.motor.is_grounded() and absf(actor.global_position.y-640) < 2, "LAB01 W returns west without jump/dash")
	_check(actor.health.current_health == 37 and actor.energy.current == 41 and inventory.run_coins == 13 and world.profile.coins == 700, "W traversal neither heals/refills nor banks escrow")
	PlayerTravel.relocate(actor,TraversalLabWorld.ORIGIN+Vector2(790,588.25))
	await _step(5)
	await _capture("exterior_lab01_ramps")
	for cycle: int in 3:
		PlayerTravel.relocate(actor,TraversalLabWorld.ORIGIN+Vector2(1705,590))
		await _step(5)
		await _jump_to(1855,1)
		_check(actor.motor.is_grounded() and absf(actor.global_position.y-550) < 2 and actor.global_position.x-TraversalLabWorld.ORIGIN.x >= 1810 and actor.global_position.x-TraversalLabWorld.ORIGIN.x <= 1900, "Actual +40/70 intro jump lands whole-foot, repeat %d" % cycle)
		await _capture("exterior_lab01_jump" if cycle == 0 else "")
		PlayerTravel.relocate(actor,TraversalLabWorld.ORIGIN+Vector2(1815,550))
		await _step(5)
		await _jump_to(1685,-1)
		_check(actor.motor.is_grounded() and absf(actor.global_position.y-590) < 2, "Actual return jump to lower shelf, repeat %d" % cycle)
	# Fall from a missed optional shelf returns to the continuous W floor.
	PlayerTravel.relocate(actor,TraversalLabWorld.ORIGIN+Vector2(1770,575))
	await _step(Engine.physics_ticks_per_second)
	_check(actor.motor.is_grounded() and absf(actor.global_position.y-640) < 2, "Missed optional jump has a dry catch floor")
	_check(world.transition_lab(&"qa_traversal_lab_02",&"west"), "Lab01->Lab02 transition commits typed dry entry")
	await _step(5)
	await _walk_to(2000)
	_check(actor.global_position.x-TraversalLabWorld.ORIGIN.x < 1740 and not world.lab.gate_open, "Closed QA gate physically stops west approach")
	await _capture("exterior_lab02_gate_closed")
	_check(world.transition_lab(&"qa_traversal_lab_01",&"west"), "Return to QA loop junction")
	await _step(5)
	PlayerTravel.relocate(actor,TraversalLabWorld.ORIGIN+Vector2(90,640))
	await _step(4)
	actor.motor.dash_cooldown_remaining = 0.9
	actor.motor.air_dash_available = false
	(actor.motor as BuildPlayerMotor).air_dashes_used = 1
	actor.resonance_controller.loadout_state.cooldowns_by_recipe_id[&"basic_bolt"] = 7.5
	var tick_start: int = Engine.get_physics_frames()
	await _press_e(true)
	_check(world.lab.room_id == &"qa_traversal_lab_03", "Actual E at west door enters the two-way QA loop")
	_check(not event_snapshot["air_available"] and event_snapshot["used_air_dashes"] == 1, "At actual E relocation, spent air-dash charges remain; later grounding follows the existing motor")
	var held_room: StringName = world.lab.room_id
	await _press_e(true)
	_check(world.lab.room_id == held_room, "Held/repeated E cannot immediately bounce through the arrival door")
	await _press_e(false)
	var elapsed: float = float(Engine.get_physics_frames()-tick_start)/Engine.physics_ticks_per_second
	_check(absf(actor.motor.dash_cooldown_remaining-maxf(0,0.9-elapsed)) <= 1.1/Engine.physics_ticks_per_second, "Door accounts for measured elapsed dash clock without refund")
	_check(absf(float(actor.resonance_controller.loadout_state.cooldowns_by_recipe_id[&"basic_bolt"])-(7.5-elapsed)) <= 1.1/Engine.physics_ticks_per_second, "Door retains naturally elapsed spell cooldown")
	_check(world.player == actor and world.gear.inventory == inventory and inventory.items.keys() == uids, "Doors preserve one actor, one inventory and exact carried UIDs")
	PlayerTravel.relocate(actor,TraversalLabWorld.ORIGIN+Vector2(90,640))
	await _step(4)
	await _key_e()
	_check(world.lab.room_id == &"qa_traversal_lab_02" and actor.global_position.x-TraversalLabWorld.ORIGIN.x > 2000, "Actual loop reaches the gate's far side")
	await _walk_to(1980)
	world.checkpoint.reject_commit = true
	_check(not world.interact_station(&"gate_lever") and not world.lab.gate_open and not world.checkpoint.gate_open, "Failed gate commit rolls back logical and physical states")
	world.checkpoint.reject_commit = false
	await _key_e()
	_check(world.lab.gate_open and world.checkpoint.gate_open and world.lab.gate.collision_layer == 0, "Far-side E opens the physical QA gate after successful save")
	var gate_payload: String = FileAccess.get_file_as_string(world.checkpoint.path)
	_check(world.interact_station(&"gate_lever") and FileAccess.get_file_as_string(world.checkpoint.path) == gate_payload, "Already-open lever is idempotent")
	await _capture("exterior_lab02_gate_open")
	await _walk_to(150)
	_check(actor.motor.is_grounded() and absf(actor.global_position.y-640) < 2, "Lab02 after gate opening walks down/up all main slopes west")
	await _walk_to(2250)
	_check(actor.motor.is_grounded() and absf(actor.global_position.y-640) < 2, "Lab02 after gate opening walks back east")
	_check(world.transition_lab(&"qa_traversal_lab_03",&"west"), "Enter dry-water lab")
	await _step(4)
	await _walk_to(1000)
	await _key_e()
	_check(world.checkpoint.anchor == &"checkpoint" and actor.motor.is_grounded(), "Actual checkpoint interaction commits a dry flat geographic anchor")
	_check(actor.health.current_health == 37 and actor.energy.current == 41 and world.profile.coins == 700 and inventory.run_coins == 13, "Checkpoint gives no free HP/energy and performs no banking")
	await _capture("exterior_lab03_water_checkpoint")
	if gpu:
		await _walk_to(1700)
		await _capture("exterior_lab03_flooded_street")
	var expected: Dictionary = world.checkpoint.payload().duplicate(true)
	_check(world.transition_lab(&"qa_traversal_lab_01",&"west",false), "Leave without overwriting checkpoint for load test")
	await _step(4)
	_check(world.restore_checkpoint(), "Load valid private checkpoint")
	await _step(4)
	_check(world.lab.room_id == &"qa_traversal_lab_03" and actor.global_position.distance_to(TraversalLabWorld.ORIGIN+Vector2(1000,560)) < 2 and world.checkpoint.gate_open, "Load returns same actor to saved dry anchor and persistent QA gate")
	_check(inventory.items.keys() == uids and world.gear.inventory == inventory, "Checkpoint payload cannot resurrect or duplicate a UID ledger")
	var position_before: Vector2 = actor.global_position
	var state_before: Dictionary = world.checkpoint.payload().duplicate(true)
	var camera := actor.get_node("Camera2D") as Camera2D
	var bounds_before: Vector4 = Vector4(camera.limit_left,camera.limit_right,camera.limit_top,camera.limit_bottom)
	world.reject_next_load = true
	_check(not world.transition_lab(&"qa_traversal_lab_01",&"west") and actor.global_position == position_before and world.checkpoint.payload() == state_before, "Loader cancellation leaves actor and checkpoint unchanged")
	world.checkpoint.reject_commit = true
	_check(not world.transition_lab(&"qa_traversal_lab_01",&"west") and actor.global_position == position_before and Vector4(camera.limit_left,camera.limit_right,camera.limit_top,camera.limit_bottom) == bounds_before, "Disk commit failure preserves current room, position and camera")
	world.checkpoint.reject_commit = false
	_check(not world.transition_lab(&"o02_ben_tram",&"west") and not world.transition_lab(&"qa_traversal_lab_01",&"checkpoint"), "Unknown room and non-flat/nonexistent entry are rejected before commit")
	world.gear.modal.open()
	_check(not world.transition_lab(&"qa_traversal_lab_01",&"west") and actor.global_position == position_before, "Inventory modal blocks transition without taking its time/input claim")
	world.gear.modal.close()
	_check(actor.controls_enabled and TimeScaleClaims.owner_count(self) == 0, "Closing actual modal restores controls/time ownership")
	actor.health.current_health = 0
	_check(not world.restore_checkpoint() and actor.health.current_health == 0, "Geographic checkpoint load does not silently revive a dead actor")
	actor.health.current_health = 37
	await _checkpoint_cases()
	_check(world.checkpoint.valid(expected), "Valid geographic checkpoint payload has stable QA IDs")
	var motor_shape := (actor.get_node("BodyCollision") as CollisionShape2D).shape as CapsuleShape2D
	_check(motor_shape.radius == 10 and motor_shape.height == 36, "Production collider dimensions remain B20/C36")
	_release()
	world.queue_free()
	await _step(8)
	_check(TimeScaleClaims.owner_count(self) == 0 and is_equal_approx(Engine.time_scale,1), "QA teardown releases all fixture-owned claims")
	print("NOT_RUN Authored O01/O02, folded LAB02/P04, overworld death policy and full NPC/sect simulation")
	print("RESULT TraversalLab %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _checkpoint_cases() -> void:
	var state := TraversalLabCheckpoint.new()
	state.path = "user://verification/lab_backup_%d.json" % Time.get_ticks_usec()
	_check(state.save(), "Private state writes validated v1 checkpoint")
	state.room = &"qa_traversal_lab_03"
	state.anchor = &"checkpoint"
	state.gate_open = true
	_check(state.save(), "Private checkpoint rotates previously valid backup")
	_write(state.path,"{\"version\":1,\"room_id\":\"made_up\",\"anchor_id\":\"west\",\"gate_open\":true}")
	var loaded := TraversalLabCheckpoint.new()
	loaded.path = state.path
	_check(loaded.load_checkpoint() and loaded.recovered_backup and loaded.room == &"qa_traversal_lab_01" and not loaded.gate_open, "Corrupt/unknown-ID main recovers only last valid anchor, not a carried ledger")
	_write(state.path,"{\"version\":2,\"room_id\":\"qa_traversal_lab_03\",\"anchor_id\":\"checkpoint\",\"gate_open\":true}")
	var future: String = FileAccess.get_file_as_string(state.path)
	_check(not loaded.load_checkpoint() and not state.save() and FileAccess.get_file_as_string(state.path) == future, "Future checkpoint schema cannot be overwritten or rolled back through old backup")
	_check(not state.valid({"version":1,"room_id":"qa_traversal_lab_01","anchor_id":"checkpoint","gate_open":false}) and not state.valid({"version":1,"room_id":"qa_traversal_lab_01","anchor_id":"west","gate_open":1}), "Typed anchor and boolean gate reject malformed state")

func _walk_to(x: float) -> void:
	var target: float = TraversalLabWorld.ORIGIN.x + x
	var direction: int = 1 if target > actor.global_position.x else -1
	var action: StringName = &"move_right" if direction > 0 else &"move_left"
	Input.action_press(action)
	for tick: int in Engine.physics_ticks_per_second * 12:
		await _step(1)
		if direction * (actor.global_position.x-target) >= 0: break
	Input.action_release(action)
	await _step(int(Engine.physics_ticks_per_second * 0.2))

func _jump_to(x: float, direction: int) -> void:
	var action: StringName = &"move_right" if direction > 0 else &"move_left"
	Input.action_press(action)
	Input.action_press(&"jump")
	for tick: int in Engine.physics_ticks_per_second:
		await _step(1)
		if direction*(actor.global_position.x-TraversalLabWorld.ORIGIN.x-x) >= 0: break
	Input.action_release(action)
	await _step(Engine.physics_ticks_per_second)
	Input.action_release(&"jump")
	await _step(3)

func _press_e(pressed: bool) -> void:
	if pressed: Input.action_press(&"interact")
	else: Input.action_release(&"interact")
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event,true)
	event_snapshot = {"air_available":actor.motor.air_dash_available,"used_air_dashes":(actor.motor as BuildPlayerMotor).air_dashes_used}
	await _step(2)

func _key_e() -> void:
	await _press_e(true)
	await _press_e(false)

func _write(path: String, data: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(data)
	file.close()

func _release() -> void:
	for action: StringName in [&"move_left",&"move_right",&"jump",&"dash",&"interact"]: Input.action_release(action)

func _step(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame

func _capture(file_name: String) -> void:
	if not gpu or file_name.is_empty(): return
	await _step(3)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://docs/verification/"+file_name+".png") == OK, "Actual GPU screenshot saved: %s" % file_name)

func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		print("FAIL: "+message)

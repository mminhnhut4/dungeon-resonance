extends SceneTree
## Real Player input/motor regression for the narrow WestStair boundary pocket.
## QA resets only establish each case; entry, contact and escape use real physics.

var run: WorldCampaign
var actor: Player
var checks: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var contact_keys: Dictionary[String, bool] = {}
var current_case: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").to_lower()
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(qa + "/"), "Isolated QA user directory")
	if failures > 0:
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	run = preload("res://scenes/world_campaign.tscn").instantiate() as WorldCampaign
	run.profile = SanctuaryProfile.new()
	run.run_seed = 41
	root.add_child(run)
	current_scene = run
	actor = run.player
	run.survival.set_enabled(false)
	run.feedback.hit_stop_seconds = 0.0
	for stage_number: int in [1, 3]:
		if stage_number != 1:
			_check(run.enter_stage(stage_number), "Load actual campaign stage %d" % stage_number)
		for enemy: Node2D in run.living_enemies():
			enemy.set_physics_process(false) # Geometry isolation; not an enemy AI/playthrough claim.
		await _frames(8)
		_check(actor.motor.is_grounded() and absf(actor.position.y - 640.0) < 1.0, "Safe unchanged room %d spawn" % run.room.room_number)
		_check(run.room.traversal_points[&"west_stair"] == Vector2(90, 534) and run.room.traversal_points[&"east_stair"] == Vector2(1130, 534), "Existing stair anchors remain unchanged")
		var west: StaticBody2D = run.room.get_node("WestStair") as StaticBody2D
		var west_shape: CollisionShape2D = west.get_node("Shape") as CollisionShape2D
		_check(west_shape.one_way_collision and is_equal_approx(west_shape.one_way_collision_margin, 4.0), "West stair keeps jump-through collision and margin")
		for entry: String in ["walk_off_stair", "jump_from_floor", "knockback_stair"]:
			await _west_case(entry)
		await _east_case(false)
		await _east_case(true)
		await _ordinary_stair_route()
	_release_inputs()
	run.queue_free()
	await _frames(8)
	root.get_node("AudioManager").stop_all()
	var folder: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	var report_path: String = folder.path_join("dungeon_corner_escape_%d.json" % Engine.physics_ticks_per_second) if not folder.is_empty() else "user://dungeon_corner_escape_%d.json" % Engine.physics_ticks_per_second
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "physics_hz": Engine.physics_ticks_per_second, "cases": rows, "scope": "Headless controlled geometry; real Player inputs, motor, DamageEvent and casting; no GPU/game-feel claim"}, "\t"))
	file.close()
	print("RESULT DungeonCornerEscape %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _west_case(entry: String) -> void:
	current_case = "room%d_west_%s" % [run.room.room_number, entry]
	_release_inputs()
	actor.reset_movement_at(Vector2(180, 640) if entry == "jump_from_floor" else Vector2(90, 534))
	await _frames(8)
	_reset_contacts()
	if entry == "knockback_stair":
		var hp_before: float = actor.health.current_health
		var event := DamageEvent.new()
		event.source_id = run.get_instance_id() # Live source, never a fake ObjectDB ID.
		event.source_team_id = 2
		event.target_id = actor.get_instance_id()
		event.attack_id = CombatIds.next_id()
		event.root_event_id = event.attack_id
		event.hit_window_id = 1
		event.base_damage = 1.0
		event.hit_reaction = &"knockback"
		event.attack_direction = Vector2.LEFT
		event.knockback = Vector2(-700, 0)
		actor.hurtbox.take_damage(event)
		_check(actor.health.current_health < hp_before and actor.hit_reaction.is_active, current_case + " applies actual damage/reaction")
	else:
		Input.action_press(&"move_left")
		if entry == "jump_from_floor":
			Input.action_press(&"jump")
	await _seconds(1.0)
	_release_inputs()
	await _seconds(0.2)
	var before: Vector2 = actor.position
	var before_contacts: Array[Dictionary] = contacts.duplicate(true)
	var casts_before: int = actor.resonance_controller.cast_count
	var projectiles_before: int = run.executor.spawned_projectiles
	Input.action_press(&"spell_cast")
	await _frames(1)
	Input.action_release(&"spell_cast")
	await _seconds(0.7)
	_check(actor.resonance_controller.cast_count == casts_before + 1 and run.executor.spawned_projectiles > projectiles_before, current_case + " still commits and launches a real spell")
	var during_cast: Vector2 = actor.position
	_reset_contacts()
	Input.action_press(&"move_right")
	await _seconds(1.0)
	var accepted_axis: float = actor.move_axis
	_release_inputs()
	await _frames(2)
	_check(accepted_axis > 0.0 and actor.position.x > 180.0 and actor.motor.is_grounded() and absf(actor.position.y - 640.0) < 1.0, current_case + " walks right out of boundary corner onto combat floor")
	rows.append({"case": current_case, "before": _point(before), "after_cast": _point(during_cast), "after_escape": _point(actor.position), "accepted_axis": accepted_axis, "casts_committed": actor.resonance_controller.cast_count - casts_before, "projectiles_launched": run.executor.spawned_projectiles - projectiles_before, "floor": actor.motor.is_grounded(), "corner_contacts": before_contacts, "escape_contacts": contacts.duplicate(true)})


func _east_case(unlocked: bool) -> void:
	current_case = "room%d_east_%s" % [run.room.room_number, "unlocked" if unlocked else "locked"]
	_release_inputs()
	run.room.set_locked(not unlocked)
	actor.reset_movement_at(Vector2(1130, 534))
	await _frames(8)
	_reset_contacts()
	Input.action_press(&"move_right")
	await _seconds(1.2)
	_release_inputs()
	await _seconds(0.1)
	var boundary: Vector2 = actor.position
	var before_contacts: Array[Dictionary] = contacts.duplicate(true)
	_check(actor.position.x < 1240.0 and actor.position.x > (1225.0 if unlocked else 1155.0) and (unlocked or actor.position.x < 1178.0), current_case + " respects actual gate/wall")
	Input.action_press(&"move_left")
	await _seconds(1.2)
	_release_inputs()
	await _frames(2)
	_check(actor.position.x < 1000.0 and actor.motor.is_grounded() and absf(actor.position.y - 640.0) < 1.0, current_case + " returns left onto combat floor")
	rows.append({"case": current_case, "boundary": _point(boundary), "after_escape": _point(actor.position), "contacts": before_contacts})
	run.room.set_locked(true)
	await _frames(2)


func _ordinary_stair_route() -> void:
	current_case = "room%d_ordinary_route" % run.room.room_number
	_release_inputs()
	actor.reset_movement_at(Vector2(180, 640))
	await _frames(8)
	await _jump_to(Vector2(90, 534))
	_check(actor.motor.is_grounded() and absf(actor.position.y - 534.0) < 1.0, current_case + " jumps through west stair from below")
	await _jump_to(Vector2(250, 444))
	_check(actor.motor.is_grounded() and absf(actor.position.y - 444.0) < 1.0, current_case + " reaches west gallery")
	actor.reset_movement_at(Vector2(1010, 640))
	await _frames(8)
	await _jump_to(Vector2(1130, 534))
	_check(actor.motor.is_grounded() and absf(actor.position.y - 534.0) < 1.0, current_case + " jumps through east stair from below")
	await _jump_to(Vector2(990, 444))
	_check(actor.motor.is_grounded() and absf(actor.position.y - 444.0) < 1.0, current_case + " reaches east gallery")


func _jump_to(target: Vector2) -> void:
	var action: StringName = &"move_right" if target.x > actor.position.x else &"move_left"
	var direction: float = 1.0 if action == &"move_right" else -1.0
	Input.action_press(action)
	Input.action_press(&"jump")
	for tick: int in Engine.physics_ticks_per_second:
		await _frames(1)
		if direction * (actor.position.x - target.x) >= 0.0:
			break
	Input.action_release(action)
	await _seconds(1.0)
	Input.action_release(&"jump")
	await _frames(4)


func _reset_contacts() -> void:
	contacts.clear()
	contact_keys.clear()


func _point(value: Vector2) -> Array[float]:
	return [value.x, value.y]


func _seconds(seconds: float) -> void:
	await _frames(ceili(seconds * Engine.physics_ticks_per_second))


func _frames(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame
		if not is_instance_valid(actor):
			continue
		for index: int in actor.get_slide_collision_count():
			var hit: KinematicCollision2D = actor.get_slide_collision(index)
			var collider: Node = hit.get_collider() as Node
			if collider == null:
				continue
			var normal: Vector2 = hit.get_normal()
			var key: String = "%s:%.2f,%.2f" % [String(collider.name), normal.x, normal.y]
			if contact_keys.has(key):
				continue
			contact_keys[key] = true
			contacts.append({"collider": String(collider.name), "normal": _point(normal), "position": _point(hit.get_position())})


func _release_inputs() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump", &"dash", &"spell_cast"]:
		Input.action_release(action)


func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		print("FAIL: " + message)

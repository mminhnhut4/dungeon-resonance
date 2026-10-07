extends SceneTree
## Integration tests use real input actions and the actual test_level collisions.
## godot --headless --path . --fixed-fps 60 --script res://tests/movement_test.gd

var level: Node2D
var player: Player
var checks: int = 0
var failures: int = 0
var damage_deliveries: int = 0
var observed_states: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	level = (load("res://scenes/test_level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	player = level.player
	preload("res://tests/neutral_equipment_fixture.gd").install(level.gear)
	level.survival.set_enabled(false) # Existing fixture isolates its milestone.
	level.combat_feedback.hit_stop_seconds = 0.0 # Movement clocks isolated from receive-hit feedback.
	player.energy.enabled = false # Baseline movement/combat fixture; gear suite covers costs.
	player.equipped_weapon.definition = load("res://data/weapons/training_sword.tres")
	player.gear_switch_enabled = false
	for enemy: SlimeEnemy in level.enemies:
		enemy.ai_enabled = false
	player.hurtbox.damage_received.connect(_on_damage_received)
	player.locomotion_state_machine.state_changed.connect(_on_state_changed)
	await _step_frames(4)
	print("MOVEMENT TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	_check_bindings()
	await _test_run_and_stop()
	await _test_variable_jump()
	await _test_coyote()
	await _test_jump_buffer()
	await _test_dash()
	await _test_wall_and_respawn()
	for state_id: StringName in [&"idle", &"run", &"jump", &"fall"]:
		_check(observed_states.has(state_id), "Locomotion FSM visited %s" % state_id)
	_release_inputs()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_bindings() -> void:
	var bindings: Dictionary = {
		&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
		&"jump": [KEY_SPACE, KEY_W], &"dash": [KEY_SHIFT, KEY_K],
	}
	for action: StringName in bindings:
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			_check(InputMap.action_has_event(action, event), "%s binding %s" % [action, OS.get_keycode_string(key)])


func _test_run_and_stop() -> void:
	await _reset(Vector2(640, 640))
	_check(player.motor.is_grounded(), "Player spawns grounded")
	_check(player.action_state_machine.get_state_id() == &"ready", "Action FSM starts Ready")
	Input.action_press(&"move_right")
	await _step_frames(1)
	_check(player.velocity.x > 0.0 and player.velocity.x < player.motor.run_speed, "Running accelerates instead of snapping")
	await _step_time(0.2)
	_check(is_equal_approx(player.velocity.x, player.motor.run_speed), "Running reaches configured speed")
	Input.action_release(&"move_right")
	var stop_x: float = player.position.x
	await _step_time(0.12)
	_check(is_zero_approx(player.velocity.x), "Ground braking reaches zero")
	_check(player.position.x - stop_x < 20.0, "Braking drift stays below 20 pixels")
	Input.action_press(&"move_left")
	await _step_time(0.04)
	_check(player.body_sprite.flip_h and player.facing_direction < 0.0, "Sprite faces movement direction")


func _test_variable_jump() -> void:
	var held_height: float = await _jump_height(0.5)
	var tap_height: float = await _jump_height(0.035)
	print("MEASURE: held jump %.2f px; tap jump %.2f px" % [held_height, tap_height])
	_check(held_height > 105.0, "Held jump clears 100px steps")
	_check(tap_height > 20.0 and held_height > tap_height * 1.6, "Releasing jump creates a shorter jump")
	await _reset(Vector2(640, 640))
	Input.action_press(&"jump")
	await _step_time(0.1)
	Input.action_release(&"jump")
	await _step_frames(1)
	var velocity_before: float = player.velocity.y
	Input.action_press(&"jump")
	await _step_frames(1)
	_check(player.velocity.y >= velocity_before, "Re-pressing jump in air does not grant a double jump")


func _jump_height(hold_seconds: float) -> float:
	await _reset(Vector2(640, 640))
	var start_y: float = player.position.y
	var minimum_y: float = start_y
	Input.action_press(&"jump")
	for frame: int in _frames(1.1):
		if frame == _frames(hold_seconds):
			Input.action_release(&"jump")
		await _step_frames(1)
		minimum_y = minf(minimum_y, player.position.y)
	_check(player.motor.is_grounded(), "Jump returns to the floor")
	return start_y - minimum_y


func _test_coyote() -> void:
	await _walk_off_step()
	await _step_time(0.06)
	Input.action_press(&"jump")
	await _step_frames(1)
	_check(player.velocity.y < -250.0, "Coyote: jump 60ms after leaving a ledge succeeds")
	await _walk_off_step()
	await _step_time(0.16)
	Input.action_press(&"jump")
	await _step_frames(1)
	_check(player.velocity.y >= 0.0, "Coyote: jump after the 120ms window is rejected")


func _walk_off_step() -> void:
	await _reset(Vector2(938, 540))
	_check(player.motor.is_grounded(), "Coyote fixture starts on the actual platform")
	Input.action_press(&"move_right")
	for frame: int in _frames(0.5):
		await _step_frames(1)
		if not player.motor.is_grounded():
			break
	Input.action_release(&"move_right")
	_check(not player.motor.is_grounded(), "Walking leaves the platform edge")


func _test_jump_buffer() -> void:
	await _reset(Vector2(680, 605))
	await _step_time(0.1)
	Input.action_press(&"jump")
	await _step_frames(1)
	Input.action_release(&"jump")
	var bounced: bool = false
	for frame: int in _frames(0.3):
		await _step_frames(1)
		bounced = bounced or player.velocity.y < 0.0
	_check(bounced, "Buffered tap shortly before landing automatically jumps")
	await _reset(Vector2(680, 450))
	Input.action_press(&"jump")
	await _step_frames(1)
	Input.action_release(&"jump")
	var expired_bounce: bool = false
	for frame: int in _frames(0.7):
		await _step_frames(1)
		expired_bounce = expired_bounce or player.velocity.y < 0.0
	_check(not expired_bounce and player.motor.is_grounded(), "Expired buffer does not jump after a late landing")


func _test_dash() -> void:
	await _reset(Vector2(500, 80))
	Input.action_press(&"move_right")
	Input.action_press(&"dash")
	var start_y: float = player.position.y
	await _step_frames(1)
	Input.action_release(&"dash")
	Input.action_release(&"move_right")
	_check(player.action_state_machine.get_state_id() == &"dash", "Air dash enters the Action FSM Dash state")
	_check(is_equal_approx(player.velocity.x, player.motor.dash_speed), "Air dash uses dash speed")
	_check(is_equal_approx(player.position.y, start_y), "Dash suspends vertical motion")
	_check(player.hurtbox.invulnerable, "Dash starts invulnerable")
	var event := DamageEvent.new()
	event.source_id = 2
	event.target_id = player.get_instance_id()
	event.attack_id = 90001
	event.hit_window_id = 1
	event.base_damage = 1.0
	_check(not player.hurtbox.receive_damage(event) and damage_deliveries == 0, "Invulnerability blocks delivery of a DamageEvent")
	await _step_time(0.11)
	_check(player.motor.is_dashing and not player.hurtbox.invulnerable, "100ms invulnerability expires before dash ends")
	_check(player.hurtbox.receive_damage(event) and damage_deliveries == 1, "DamageEvent delivery resumes after invulnerability")
	await _step_time(0.08)
	_check(not player.motor.is_dashing and player.action_state_machine.get_state_id() == &"ready", "Dash exits to Ready")
	_check(absf(player.velocity.x) <= player.motor.run_speed, "Dash exit does not leave excessive momentum")
	Input.action_press(&"dash")
	await _step_frames(1)
	Input.action_release(&"dash")
	_check(not player.motor.is_dashing, "Cooldown blocks an immediate second dash")
	await _step_time(0.5)
	_check(not player.motor.is_grounded(), "Single-air-dash fixture remains airborne")
	_check(is_zero_approx(player.motor.dash_cooldown_remaining), "Cooldown expires while airborne")
	Input.action_press(&"dash")
	await _step_frames(1)
	Input.action_release(&"dash")
	_check(not player.motor.is_dashing, "Only one dash is allowed before landing, even after cooldown")
	for frame: int in _frames(1.5):
		await _step_frames(1)
		if player.motor.is_grounded():
			break
	await _step_frames(1)
	_check(player.motor.can_dash(), "Landing restores the air-dash charge")
	Input.action_press(&"dash")
	await _step_frames(1)
	Input.action_release(&"dash")
	_check(player.motor.is_dashing, "Restored charge can start a ground dash")
	await _step_time(0.2)
	Input.action_press(&"dash")
	await _step_frames(1)
	Input.action_release(&"dash")
	_check(not player.motor.is_dashing, "Touching ground does not reset the dash cooldown")
	await _reset(Vector2(640, 640))
	Input.action_press(&"move_left")
	await _step_time(0.04)
	Input.action_release(&"move_left")
	Input.action_press(&"dash")
	await _step_frames(1)
	_check(player.velocity.x < 0.0, "Dash with no direction uses the last facing direction")
	await _reset(Vector2(640, 640))
	Input.action_press(&"jump")
	Input.action_press(&"dash")
	await _step_frames(1)
	Input.action_release(&"dash")
	await _step_time(0.3)
	_check(player.motor.is_grounded(), "Simultaneous jump + dash prioritizes dash without a delayed auto-jump")


func _test_wall_and_respawn() -> void:
	await _reset(Vector2(1228, 640))
	Input.action_press(&"move_right")
	Input.action_press(&"dash")
	await _step_frames(2)
	_release_inputs()
	_check(player.position.x < 1250.0 and player.is_on_wall(), "Dash collides with the room wall without tunneling")
	_check(not player.motor.is_dashing and not player.hurtbox.invulnerable, "Wall cancellation clears dash and invulnerability")
	await _reset(Vector2(500, 80))
	Input.action_press(&"dash")
	await _step_frames(1)
	_release_inputs()
	player.global_position = Vector2(540, 900)
	await _step_frames(3)
	_check(player.position.distance_to(level.spawn_point.position) < 2.0, "Falling below the room respawns at the center")
	_check(not player.motor.is_dashing and not player.hurtbox.invulnerable, "Respawn clears a running dash")
	player.reset_movement_at(Vector2(700, 640))
	Input.action_press(&"reset_player")
	await _step_frames(2)
	Input.action_release(&"reset_player")
	_check(absf(player.position.x - 640.0) < 1.0, "R action returns Player to the spawn point")


func _reset(position: Vector2) -> void:
	_release_inputs()
	player.reset_movement_at(position)
	await _step_frames(3)


func _release_inputs() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump", &"dash", &"reset_player"]:
		Input.action_release(action)


func _frames(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


func _step_time(seconds: float) -> void:
	await _step_frames(_frames(seconds))


func _step_frames(count: int) -> void:
	for frame: int in count:
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", description])


func _on_damage_received(_event: DamageEvent) -> void:
	damage_deliveries += 1


func _on_state_changed(_previous_id: StringName, next_id: StringName) -> void:
	observed_states.append(next_id)



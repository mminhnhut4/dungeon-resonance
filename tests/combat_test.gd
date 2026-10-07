extends SceneTree
## Integration: actual input, FSM, physics hitboxes, dummy HP and room feedback.

var level: Node2D
var player: Player
var weapon: Weapon
var dummy: TrainingDummy
var feedback: CombatFeedback
var committed: Array[AttackSnapshot] = []
var checks: int = 0
var failures: int = 0
var cast_requests: int = 0
var last_cast_target: Vector2 = Vector2.ZERO
var last_cast_direction: Vector2 = Vector2.ZERO


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	_load_room()
	await _step_frames(5)
	print("COMBAT TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	await _test_input_and_scene()
	await _test_hit_window_and_combo()
	await _test_combo_window()
	await _test_hold_miss_and_direction()
	await _test_cursor_aim()
	await _test_cancel_and_air_attack()
	await _test_damage_pipeline()
	await _test_snapshot_and_multiple_hurtboxes()
	await _test_hit_stop_and_multi_target()
	await _test_scene_cleanup()
	_release_inputs()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _load_room() -> void:
	level = (load("res://scenes/test_level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	player = level.player
	preload("res://tests/neutral_equipment_fixture.gd").install(level.gear)
	level.survival.set_enabled(false) # Existing fixture isolates its milestone.
	player.energy.enabled = false # Baseline movement/combat fixture; gear suite covers costs.
	player.equipped_weapon.definition = load("res://data/weapons/training_sword.tres")
	player.gear_switch_enabled = false
	weapon = player.equipped_weapon
	dummy = level.dummy_a
	feedback = level.combat_feedback
	# Preserve the original fixed-camera baseline (including exact float checks).
	# game_feel_test separately covers the live Player camera at zoom 1.35.
	(player.get_node("Camera2D") as PlayerCamera).enabled = false
	feedback.camera = level.get_node("RoomCamera") as Camera2D
	feedback.camera.enabled = true
	feedback.camera.make_current()
	player.resonance_controller.casting_enabled = false
	for enemy: SlimeEnemy in level.enemies:
		enemy.ai_enabled = false
	weapon.attack_committed.connect(_on_committed)
	player.spell_cast_requested.connect(_on_cast_requested)


func _test_input_and_scene() -> void:
	_check(dummy.is_on_floor() and level.dummy_b.is_on_floor(), "Both dummies stand on real platforms")
	_check(dummy.health != level.dummy_b.health, "Dummy health belongs to separate runtime instances")
	for action: StringName in [&"attack", &"spell_cast"]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_J if action == &"attack" else KEY_I
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT if action == &"attack" else MOUSE_BUTTON_RIGHT
		_check(InputMap.action_has_event(action, key), "%s keyboard binding" % action)
		_check(InputMap.action_has_event(action, mouse), "%s mouse binding" % action)
	await _prepare()
	await _key_tap(KEY_J)
	_check(player.action_state_machine.get_state_id() == &"attack", "Physical J input starts Attack FSM")
	await _prepare()
	await _mouse_tap(MOUSE_BUTTON_LEFT)
	_check(player.action_state_machine.get_state_id() == &"attack", "Left mouse input starts Attack FSM")
	await _prepare()
	var before: int = cast_requests
	await _key_tap(KEY_I)
	await _mouse_tap(MOUSE_BUTTON_RIGHT)
	_check(cast_requests == before + 2, "I and right mouse send spell requests")
	_check(player.action_state_machine.get_state_id() == &"ready", "Unconfigured spell leaves Player ready")
	_check(level.combat_hint.text.begins_with("Chưa gắn"), "Spell request shows the unconfigured Catalyst hint")


func _test_hit_window_and_combo() -> void:
	await _prepare()
	await _tap(&"attack")
	_check(weapon.phase == Weapon.Phase.WINDUP and not weapon.hitbox.active, "Hitbox stays closed during windup")
	_check(dummy.hit_count == 0 and dummy.health.current_health == 120.0, "Windup does not damage an overlapping target")
	_check(await _wait_for_hits(1), "First active window hits the dummy")
	_check(weapon.phase == Weapon.Phase.ACTIVE and weapon.hitbox.active, "Hit occurs during the active hitbox window")
	_check(dummy.health.current_health == 110.0, "First slash deals 10 damage")
	_check(level.dummy_b.health.current_health == 120.0, "Hitting A does not change B health")
	var first: DamageEvent = dummy.last_damage_event
	_check(first != null and first.source_id == player.get_instance_id() and first.target_id == dummy.get_instance_id(), "DamageEvent identifies source and target")
	_check(first != null and first.attack_direction == Vector2.RIGHT and first.knockback.x > 0.0, "DamageEvent carries direction and world-space knockback")
	_check(first != null and first.root_event_id == first.attack_id and not first.allow_resonance, "Direct hit has a root ID and no unconfigured resonance")
	await _tap(&"attack")
	_check(await _wait_for_hits(2), "Buffered second press continues to slash two")
	await _tap(&"attack")
	_check(await _wait_for_hits(3), "Third press continues to the finisher")
	_check(dummy.health.current_health == 80.0, "Three-hit combo deals 10 + 12 + 18 damage")
	_check(committed.size() == 3, "Three slashes commit three distinct attacks")
	if committed.size() == 3:
		_check(committed[0].attack_id != committed[1].attack_id and committed[1].attack_id != committed[2].attack_id, "Each combo step has a distinct attack ID")
		_check(committed[2].knockback.x > committed[0].knockback.x, "Finisher has stronger authored knockback")
	await _step_time(0.25)
	_check(not weapon.hitbox.active and dummy.hit_count == 3, "Recovery closes the hitbox without repeated overlap damage")
	await _step_time(0.15)
	_check(player.action_state_machine.get_state_id() == &"ready", "Finisher returns Action FSM to Ready")


func _test_combo_window() -> void:
	await _prepare()
	await _tap(&"attack")
	_check(await _wait_for_phase(Weapon.Phase.COMBO_WAIT), "Single slash opens the post-recovery combo window")
	await _step_time(0.1)
	await _tap(&"attack")
	_check(weapon.combo_index == 1, "A press inside the combo window resumes slash two")
	await _prepare()
	await _tap(&"attack")
	await _wait_for_phase(Weapon.Phase.COMBO_WAIT)
	await _step_time(0.25)
	_check(player.action_state_machine.get_state_id() == &"ready", "Combo window expires without input")
	await _tap(&"attack")
	_check(weapon.combo_index == 0, "A late press starts a new combo from slash one")


func _test_hold_miss_and_direction() -> void:
	await _prepare()
	Input.action_press(&"attack")
	await _step_time(1.0)
	_check(dummy.hit_count == 1 and committed.size() == 1, "Holding attack does not auto-chain or repeat")
	await _prepare(Vector2(640, 640))
	await _tap(&"attack")
	await _step_time(0.6)
	_check(dummy.hit_count == 0 and level.dummy_b.hit_count == 0, "Attacking out of reach misses")
	_check(feedback.impact_count == 0 and get_nodes_in_group(&"combat_text").is_empty(), "A miss creates no hit-stop or combat text")
	await _prepare(Vector2(465, 547))
	await _tap(&"attack")
	await _step_time(0.2)
	_check(dummy.hit_count == 0, "A right-aimed slash does not hit a target behind Player")
	await _prepare(Vector2(465, 547))
	_aim_at(player.aim.global_position + Vector2.LEFT * 100.0)
	await _tap(&"attack")
	_check(await _wait_for_hits(1), "Mouse aims left while Player still faces right")
	await _step_time(0.08)
	_check(dummy.last_damage_event != null and dummy.last_damage_event.knockback.x < 0.0, "Left slash mirrors knockback direction")
	_check(dummy.position.x < 415.0, "Dummy physically moves left after left-aimed knockback")


func _test_cursor_aim() -> void:
	await _prepare()
	Input.action_press(&"move_left")
	await _step_frames(2)
	Input.action_release(&"move_left")
	_aim_at(player.aim.global_position + Vector2.RIGHT * 150.0)
	await _tap(&"attack")
	_check(player.facing_direction < 0.0 and weapon.snapshot.attack_direction.is_equal_approx(Vector2.RIGHT), "Mouse aim is independent of movement-facing direction")
	_check(await _wait_for_hits(1), "A right-aimed slash hits while the body faces left")
	await _prepare()
	dummy.global_position = player.global_position + Vector2(0, -40)
	await _step_frames(1)
	_aim_at(player.aim.global_position + Vector2.UP * 120.0)
	await _tap(&"attack")
	_check(await _wait_for_hits(1), "Upward cursor aim rotates the hitbox onto an airborne target")
	_check(dummy.last_damage_event != null and dummy.last_damage_event.attack_direction.is_equal_approx(Vector2.UP) and dummy.last_damage_event.knockback.y < 0.0, "Upward DamageEvent carries aim direction and upward knockback")
	await _prepare()
	dummy.global_position = player.global_position + Vector2(0, 45)
	await _step_frames(1)
	_aim_at(player.aim.global_position + Vector2.DOWN * 120.0)
	await _tap(&"attack")
	_check(await _wait_for_hits(1), "Downward cursor aim reaches a target below Player")
	_check(dummy.last_damage_event != null and dummy.last_damage_event.attack_direction.is_equal_approx(Vector2.DOWN), "Downward hit retains a normalized downward direction")
	await _prepare()
	dummy.global_position = player.global_position + Vector2(36, -32)
	await _step_frames(1)
	var diagonal_target: Vector2 = player.aim.global_position + Vector2(100, -100)
	_aim_at(diagonal_target)
	await _tap(&"attack")
	_check(weapon.snapshot.attack_direction.is_equal_approx(Vector2(1, -1).normalized()), "Diagonal cursor aim is normalized")
	_check(weapon.snapshot.aim_position.distance_to(diagonal_target) < 0.01, "Commit stores the world-space cursor target")
	_check(await _wait_for_hits(1), "Diagonal hitbox reaches the diagonal target")
	_check(dummy.last_damage_event != null and dummy.last_damage_event.aim_position.distance_to(diagonal_target) < 0.01, "DamageEvent preserves the committed target position")
	await _prepare()
	_aim_at(player.aim.global_position + Vector2.UP * 120.0)
	await _tap(&"attack")
	await _step_time(0.3)
	_check(dummy.hit_count == 0, "A target to the right is not hit by an upward slash")
	await _prepare()
	_aim_at(player.aim.global_position + Vector2.LEFT * 120.0)
	player.aim.sample_cursor()
	_aim_at(player.aim.global_position)
	await _tap(&"attack")
	_check(weapon.snapshot.attack_direction.is_equal_approx(Vector2.LEFT) and is_equal_approx(weapon.snapshot.attack_direction.length(), 1.0), "Pointer at aim origin retains the last valid direction")
	await _prepare()
	_aim_at(player.aim.global_position + Vector2.RIGHT * 120.0)
	await _tap(&"attack")
	var first_direction: Vector2 = weapon.snapshot.attack_direction
	_aim_at(player.aim.global_position + Vector2.LEFT * 120.0)
	await _step_frames(2)
	_check(weapon.snapshot.attack_direction == first_direction and weapon.global_rotation == 0.0, "Moving the cursor cannot rotate an already committed slash")
	await _tap(&"attack")
	await _wait_for_phase(Weapon.Phase.RECOVERY)
	for frame: int in _frames(0.5):
		if committed.size() >= 2:
			break
		await _step_frames(1)
	_check(committed.size() == 2 and committed[1].attack_direction.is_equal_approx(Vector2.LEFT), "A buffered second slash samples the new cursor direction at its own commit")
	_check(dummy.hit_count == 1, "Re-aiming away prevents the second slash from damaging the first target")
	await _prepare()
	var camera: Camera2D = feedback.camera
	camera.position += Vector2(35, -25)
	camera.zoom = Vector2(1.25, 1.25)
	camera.force_update_scroll()
	var world_target: Vector2 = player.aim.global_position + Vector2(90, -45)
	_aim_at(world_target)
	await _tap(&"spell_cast")
	_check(last_cast_target.distance_to(world_target) < 0.01 and last_cast_direction.is_equal_approx(Vector2(2, -1).normalized()), "Spell request shares world-space targeting with camera pan and zoom")
	camera.position = Vector2(640, 360)
	camera.zoom = Vector2.ONE
	camera.force_update_scroll()


func _test_cancel_and_air_attack() -> void:
	await _prepare()
	await _tap(&"attack")
	await _tap(&"dash")
	_check(player.action_state_machine.get_state_id() == &"dash" and not weapon.is_attacking(), "Dash cancels an attack in windup")
	await _step_time(0.25)
	_check(dummy.hit_count == 0 and not weapon.hitbox.active, "Cancelled windup cannot activate a late hitbox")
	await _prepare()
	await _tap(&"attack")
	await _wait_for_hits(1)
	await _tap(&"dash")
	_check(not weapon.hitbox.active, "Dash cancellation immediately closes an active hitbox")
	await _step_time(0.2)
	_check(dummy.hit_count == 1, "Cancelling an active slash leaves only the already resolved hit")
	await _prepare()
	Input.action_press(&"jump")
	await _tap(&"attack")
	_check(player.locomotion_state_machine.get_state_id() == &"jump" and player.action_state_machine.get_state_id() == &"attack", "Locomotion Jump and Action Attack coexist")
	_check(await _wait_for_hits(1), "An airborne slash damages the dummy")
	await _prepare()
	await _tap(&"attack")
	await _wait_for_hits(1)
	await _tap(&"reset_player")
	await _step_frames(2)
	_check(player.action_state_machine.get_state_id() == &"ready" and not weapon.hitbox.active, "R clears the attack state and hitbox")
	_check(dummy.health.current_health == 120.0 and dummy.hit_count == 0, "R restores both dummy health and statistics")
	_check(get_nodes_in_group(&"combat_text").is_empty(), "R removes floating combat text")


func _test_damage_pipeline() -> void:
	await _prepare()
	var event: DamageEvent = _event_for(dummy, 10.0, 100001)
	event.knockback = Vector2(-200, -100)
	event.attack_direction = Vector2.LEFT
	var result: DamageResult = dummy.hurtbox.take_damage(event)
	_check(result.actual_damage == 10.0 and not result.blocked, "Hurtbox resolves valid damage through Health")
	var duplicate: DamageResult = dummy.hurtbox.take_damage(event)
	_check(duplicate.blocked and duplicate.block_reason == &"duplicate", "Receiver rejects duplicate attack/window delivery")
	_check(dummy.hit_count == 1 and dummy.health.current_health == 110.0, "Duplicate produces no extra damage or hit feedback")
	_check(dummy.body_visual.color == Color.WHITE, "Successful hit starts the white flash")
	await _step_time(0.06)
	_check(dummy.position.x < 415.0, "DamageEvent knockback moves the physics body")
	_check(dummy.body_visual.color.r > 0.9 and dummy.body_visual.color.g < 0.3, "White flash changes to red")
	var texts: Array[Node] = get_nodes_in_group(&"combat_text")
	_check(texts.size() == 1, "Successful damage spawns one floating number")
	if not texts.is_empty():
		var text := texts[0] as FloatingCombatText
		_check(text.label.text == "10" and text.global_position.y < dummy.position.y - 48.0, "Floating text displays actual damage above the dummy")
	await _step_time(0.7)
	_check(get_nodes_in_group(&"combat_text").is_empty(), "Expired combat text frees itself")
	await _prepare()
	dummy.hurtbox.set_invulnerable(true)
	_check(dummy.hurtbox.take_damage(_event_for(dummy, 10.0, 100002)).blocked, "Invulnerable target rejects damage")
	dummy.hurtbox.set_invulnerable(false)
	var friendly: DamageEvent = _event_for(dummy, 10.0, 100003)
	friendly.source_team_id = 2
	_check(dummy.hurtbox.take_damage(friendly).blocked, "Friendly fire is blocked")
	_check(dummy.hurtbox.take_damage(_event_for(dummy, -10.0, 100004)).blocked, "Negative damage is rejected")
	_check(dummy.health.current_health == 120.0 and dummy.hit_count == 0, "Blocked events do not change health or flash statistics")
	var deaths: Array[int] = [0]
	dummy.health.died.connect(func(): deaths[0] += 1, CONNECT_ONE_SHOT)
	var lethal: DamageResult = dummy.hurtbox.take_damage(_event_for(dummy, 999.0, 100005))
	_check(lethal.killed and lethal.actual_damage == 120.0 and dummy.health.current_health == 0.0, "Lethal damage clamps actual loss to remaining HP")
	_check(dummy.hurtbox.take_damage(_event_for(dummy, 10.0, 100006)).blocked and deaths[0] == 1, "Dead dummy takes no extra hit and emits death once")
	await _step_time(0.9)
	_check(dummy.health.current_health == 120.0, "Destroyed training dummy automatically respawns")
	await _prepare()
	await _tap(&"attack")
	var killed_player: DamageEvent = _event_for(dummy, 999.0, 100007)
	killed_player.source_id = dummy.get_instance_id()
	killed_player.target_id = player.get_instance_id()
	killed_player.source_team_id = 2
	player.hurtbox.take_damage(killed_player)
	_check(player.action_state_machine.get_state_id() == &"dead" and not weapon.hitbox.active, "Player death cancels the attack lifetime")
	await _tap(&"attack")
	_check(player.action_state_machine.get_state_id() == &"dead", "Dead action state cannot start another attack")
	player.reset_movement_at(Vector2(365, 547))
	_check(player.health.current_health == 100.0 and player.action_state_machine.get_state_id() == &"ready", "Respawn restores player health and Ready state")


func _test_snapshot_and_multiple_hurtboxes() -> void:
	await _prepare()
	var original: WeaponDefinition = weapon.definition
	await _tap(&"attack")
	var replacement := original.duplicate(true) as WeaponDefinition
	replacement.base_damage = 99.0
	replacement.combo_steps[0].active_seconds = 0.8
	weapon.definition = replacement
	_check(await _wait_for_hits(1), "Committed attack survives a loadout-definition replacement")
	_check(dummy.last_damage_event != null and dummy.last_damage_event.base_damage == 10.0, "Committed damage is preserved by AttackSnapshot")
	weapon.definition = original
	await _prepare()
	var extra := dummy.hurtbox.duplicate() as Hurtbox
	extra.name = "ExtraHurtbox"
	extra.health = dummy.health
	extra.damage_resolver = dummy.hurtbox.damage_resolver
	extra.actor_body = dummy
	dummy.add_child(extra)
	await _step_frames(2)
	await _tap(&"attack")
	await _step_time(0.3)
	_check(dummy.hit_count == 1 and dummy.health.current_health == 110.0, "Multiple hurtboxes on one actor still receive one hit per slash (hits=%d, hp=%.1f)" % [dummy.hit_count, dummy.health.current_health])
	extra.queue_free()
	await _step_frames(2)


func _test_hit_stop_and_multi_target() -> void:
	await _prepare()
	feedback.hit_stop_seconds = 0.05
	player.motor.dash_cooldown_remaining = 0.4
	await _tap(&"attack")
	_check(await _wait_for_hits(1), "Real hit requests combat feedback")
	_check(feedback.is_frozen() and feedback.hit_stop_remaining > 0.0, "Hit-stop is active after a confirmed hit")
	var player_position: Vector2 = player.position
	var dummy_position: Vector2 = dummy.position
	var cooldown: float = player.motor.dash_cooldown_remaining
	Input.action_press(&"attack")
	await _step_frames(1)
	Input.action_release(&"attack")
	_check(player.position == player_position and dummy.position == dummy_position, "Hit-stop freezes both actor bodies")
	_check(is_equal_approx(player.motor.dash_cooldown_remaining, cooldown), "Hit-stop freezes gameplay cooldowns")
	_check(feedback.camera.offset.length() > 0.000001 and feedback.camera.offset.length() < 4.0, "Confirmed hit creates bounded camera shake")
	for frame: int in _frames(0.12):
		await _step_frames(1)
		if not feedback.is_frozen():
			break
	_check(not feedback.is_frozen(), "Hit-stop ends automatically")
	_check(dummy.position.x > dummy_position.x, "Pending knockback resumes after freeze")
	_check(await _wait_for_hits(2), "Attack pressed during hit-stop is buffered for the next slash")
	await _step_time(0.5)
	_check(feedback.camera.offset.is_zero_approx(), "Camera returns to its resting offset")
	await _prepare()
	feedback.hit_stop_seconds = 0.05
	level.dummy_b.global_position = dummy.global_position + Vector2(15, 0)
	await _step_frames(2)
	await _tap(&"attack")
	await _wait_for_hits(1)
	_check(dummy.hit_count == 1 and level.dummy_b.hit_count == 1, "A single slash can hit two distinct targets")
	_check(feedback.impact_count == 1, "Multi-target hit-stop is requested once per attack")


func _test_scene_cleanup() -> void:
	level.queue_free()
	await _step_frames(3)
	_load_room()
	await _step_frames(5)
	_check(not paused and is_equal_approx(Engine.time_scale, 1.0), "Leaving during hit-stop preserves global pause/time scale")
	_check(not feedback.is_frozen() and player.action_state_machine.get_state_id() == &"ready", "A new room has no stale action or freeze")
	_check(get_nodes_in_group(&"combat_text").is_empty(), "Scene cleanup removes room-owned combat text")


func _prepare(position: Vector2 = Vector2(365, 547)) -> void:
	_release_inputs()
	level.reset_room()
	feedback.hit_stop_seconds = 0.0
	feedback.impact_count = 0
	player.reset_movement_at(position)
	await _step_frames(4)
	_aim_at(player.aim.global_position + Vector2.RIGHT * 150.0)
	player.aim.sample_cursor()
	committed.clear()


func _event_for(target: TrainingDummy, damage: float, attack_id: int) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = player.get_instance_id()
	event.target_id = target.get_instance_id()
	event.source_team_id = 1
	event.attack_id = attack_id
	event.root_event_id = attack_id
	event.hit_window_id = 1
	event.base_damage = damage
	return event


func _wait_for_hits(count: int, seconds: float = 1.0) -> bool:
	for frame: int in _frames(seconds):
		if dummy.hit_count >= count:
			return true
		await _step_frames(1)
	return dummy.hit_count >= count


func _wait_for_phase(value: Weapon.Phase, seconds: float = 1.0) -> bool:
	for frame: int in _frames(seconds):
		if weapon.phase == value:
			return true
		await _step_frames(1)
	return weapon.phase == value


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _step_frames(1)
	Input.action_release(action)


func _key_tap(key: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await _step_frames(1)
	event.pressed = false
	Input.parse_input_event(event)


func _mouse_tap(button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = root.get_canvas_transform() * player.aim.target_position
	event.pressed = true
	Input.parse_input_event(event)
	await _step_frames(1)
	event.pressed = false
	Input.parse_input_event(event)


func _aim_at(world_position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_canvas_transform() * world_position
	event.global_position = event.position
	root.push_input(event, true)


func _release_inputs() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump", &"dash", &"attack", &"spell_cast", &"reset_player"]:
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


func _on_committed(attack: AttackSnapshot) -> void:
	committed.append(attack)


func _on_cast_requested(target_position: Vector2, direction: Vector2) -> void:
	cast_requests += 1
	last_cast_target = target_position
	last_cast_direction = direction



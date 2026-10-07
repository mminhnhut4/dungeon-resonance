extends SceneTree
## Real defeat freezes room AI while its static terrain still supports Player.

var run: DungeonRun
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	print("DEATH_GROUND TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	for scene_path: String in ["res://scenes/dungeon_run.tscn", "res://scenes/linear_campaign.tscn"]:
		run = (load(scene_path) as PackedScene).instantiate() as DungeonRun
		run.profile = SanctuaryProfile.new()
		run.profile.save_path = "user://verification/death_ground_%d.json" % Engine.physics_ticks_per_second
		root.add_child(run)
		current_scene = run
		run.survival.set_enabled(false)
		run.feedback.hit_stop_seconds = 0.0
		_freeze_ai()
		await _step(4)
		await _test_grounded_defeat(scene_path)
		await _test_platform_defeat(scene_path)
		await _test_airborne_defeat(scene_path)
		if run is LinearCampaign:
			await _test_bramble_defeat(scene_path)
		var room_id: int = run.room.get_instance_id()
		var floor_ids: Array[int] = []
		for body: Node in run.room.find_children("*", "StaticBody2D", true, false):
			floor_ids.append(body.get_instance_id())
		run.queue_free()
		await _step(4)
		_check(not is_instance_id_valid(room_id) and floor_ids.all(func(id: int) -> bool: return not is_instance_id_valid(id)), "%s: KEEP_ACTIVE terrain still frees with its room" % scene_path)
	_check(not paused and is_equal_approx(Engine.time_scale, 1.0), "Defeat/retry/teardown preserve global pause and time scale")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _freeze_ai() -> void:
	for enemy: Node2D in run.living_enemies():
		enemy.ai_enabled = false
		if enemy is SlimeEnemy:
			(enemy as SlimeEnemy).contact_damage_enabled = false


func _kill_player() -> DamageResult:
	var event := DamageEvent.new()
	event.source_id = 987654
	event.source_team_id = 2
	event.target_id = run.player.get_instance_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = 999.0
	run.player.hurtbox.set_invulnerable(false)
	return run.player.hurtbox.take_damage(event)


func _retry() -> void:
	run.retry()
	_freeze_ai()
	await _step(4)


func _test_grounded_defeat(label: String) -> void:
	run.player.relocate(Vector2(540, 640))
	await _step(4)
	var player: Player = run.player
	var body: CollisionShape2D = player.get_node("BodyCollision") as CollisionShape2D
	var shape: Shape2D = body.shape
	var transform: Transform2D = body.transform
	var layer: int = player.collision_layer
	var mask: int = player.collision_mask
	var positions: Array[Vector2] = []
	var enemies: Array[Node2D] = run.living_enemies()
	for enemy: Node2D in enemies:
		positions.append(enemy.global_position)
	_check(player.motor.is_grounded(), "%s: product Player stands on the actual room floor before lethal hit" % label)
	var result: DamageResult = _kill_player()
	_check(result.killed and run.outcome == &"defeat" and player.action_state_machine.get_state_id() == &"dead", "%s: ordinary lethal damage enters the production defeat flow" % label)
	_check(run.room.process_mode == Node.PROCESS_MODE_DISABLED and not player.controls_enabled, "%s: defeat keeps room gameplay and input disabled" % label)
	await _time(1.0)
	_check(player.motor.is_grounded() and absf(player.global_position.y - 640.0) < 0.1 and is_zero_approx(player.velocity.y), "%s: corpse stays on the floor throughout its death animation" % label)
	_check(player.collision_layer == layer and player.collision_mask == mask and layer == 2 and mask == 1 and body.shape == shape and body.transform == transform and not body.disabled, "%s: death preserves the Player's original world collision and shape" % label)
	var frozen: bool = true
	for index: int in enemies.size():
		frozen = frozen and enemies[index].global_position == positions[index]
	_check(frozen, "%s: preserving terrain does not reactivate frozen room enemies" % label)
	Input.action_press(&"attack")
	Input.action_press(&"dash")
	Input.action_press(&"jump")
	await _step(2)
	for action: StringName in [&"attack", &"dash", &"jump"]:
		Input.action_release(action)
	_check(player.action_state_machine.get_state_id() == &"dead" and not player.motor.is_dashing and not player.equipped_weapon.hitbox.active, "%s: death still rejects attack, jump and Dash input" % label)
	await _retry()
	_check(run.outcome == &"" and player.health.current_health > 0.0 and player.controls_enabled and player.motor.is_grounded(), "%s: retry restores a live Player on newly active terrain" % label)


func _test_platform_defeat(label: String) -> void:
	run.player.relocate(Vector2(400, 550))
	await _step(4)
	_check(run.player.motor.is_grounded(), "%s: platform fixture rests at the authored 550px top" % label)
	_kill_player()
	await _time(0.8)
	_check(run.player.motor.is_grounded() and absf(run.player.global_position.y - 550.0) < 0.1, "%s: corpse remains on an elevated platform after room disable" % label)
	await _retry()


func _test_airborne_defeat(label: String) -> void:
	run.player.relocate(Vector2(540, 450))
	await _step(2)
	_check(not run.player.motor.is_grounded(), "%s: airborne death fixture starts off the floor" % label)
	_kill_player()
	await _time(1.0)
	_check(run.player.action_state_machine.get_state_id() == &"dead" and run.player.motor.is_grounded() and absf(run.player.global_position.y - 640.0) < 0.1, "%s: airborne corpse still lands through the single motor move call" % label)
	await _retry()
	run.player.reset_movement_at(Vector2(540, 640))
	await _step(3)
	var event := DamageEvent.new()
	event.source_id = 987654
	event.source_team_id = 2
	event.target_id = run.player.get_instance_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = 3.0
	event.hit_reaction = &"thrown"
	event.knockback = Vector2(200, -440)
	run.player.hurtbox.take_damage(event)
	await _time(0.08)
	_kill_player()
	await _time(1.0)
	_check(not run.player.hit_reaction.is_active and run.player.action_state_machine.get_state_id() == &"dead" and run.player.motor.is_grounded(), "%s: death during thrown reaction settles without get-up or lost terrain" % label)
	await _retry()


func _test_bramble_defeat(label: String) -> void:
	var campaign: LinearCampaign = run as LinearCampaign
	_check(campaign.enter_stage(2), "%s: enter the actual secret floor containing a Bramble Gate" % label)
	campaign.player.relocate(Vector2(215, 235))
	await _step(4)
	var barrier: EnvironmentBarrier
	for child: Node in campaign.room.get_children():
		if child is EnvironmentBarrier and (child as EnvironmentBarrier).requires_fire:
			barrier = child as EnvironmentBarrier
			break
	_check(barrier != null and campaign.player.motor.is_grounded() and absf(campaign.player.global_position.y - 235.0) < 0.1, "%s: Player rests on the actual elevated Bramble top before death" % label)
	if barrier == null:
		return
	_kill_player()
	await _time(1.0)
	_check(campaign.player.motor.is_grounded() and absf(campaign.player.global_position.y - 235.0) < 0.1 and campaign.player.action_state_machine.get_state_id() == &"dead", "%s: frozen Bramble terrain preserves corpse support instead of dropping it 131px" % label)
	_check(barrier.disable_mode == CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE and barrier.hurtbox.disable_mode == CollisionObject2D.DISABLE_MODE_REMOVE and not barrier.hurtbox.can_process(), "%s: terrain stays active while its damage Area retains the disabled-room gate" % label)
	await _retry()


func _time(seconds: float) -> void:
	await _step(ceili(seconds * Engine.physics_ticks_per_second))


func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

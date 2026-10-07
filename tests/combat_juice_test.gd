extends "res://tests/survival_test_base.gd"
## Real DamageEvent/Hitbox flow, real-time slowdown claims and additive camera noise.


func _initialize() -> void:
	suite = "combat_juice"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.set_physics_process(false)
	var feedback: CombatFeedback = level.combat_feedback
	_check(not feedback.global_hitstop_enabled and not feedback.is_frozen(), "Headless baseline preserves isolated local-clock fixtures")
	feedback.hit_stop_seconds = 0.05
	feedback.enable_global_hitstop(true)
	_check(feedback.hitstop_manager != null and feedback.get_child_count() == 1, "Live mode owns one finite real-time hitstop manager")
	_check(feedback.hitstop_manager.regular_seconds == 0.06 and feedback.hitstop_manager.heavy_seconds == 0.12 and feedback.hitstop_manager.slow_scale == 0.05, "Regular and heavy hitstop use configured real-time windows")
	await _test_real_melee(feedback)
	await _test_heavy_and_dedup(feedback)
	await _test_inventory_claims(feedback)
	await _test_timer_lifetime(feedback)
	_test_camera(feedback)
	await _test_scene_teardown()


func _test_real_melee(feedback: CombatFeedback) -> void:
	var dummy: TrainingDummy = level.dummy_a
	dummy.reset_at_home(false)
	dummy.set_physics_process(false)
	var collision: CollisionShape2D = player.get_node("BodyCollision") as CollisionShape2D
	var shape_id: int = collision.shape.get_instance_id()
	var body_transform: Transform2D = collision.transform
	player.energy.enabled = false
	player.gear_switch_enabled = false
	player.equipped_weapon.equip(load("res://data/weapons/training_sword.tres"))
	player.reset_movement_at(Vector2(365, 547))
	var mouse := InputEventMouseMotion.new()
	mouse.position = root.get_canvas_transform() * (player.aim.global_position + Vector2(150, 0))
	root.push_input(mouse, true)
	var weapon: Weapon = player.equipped_weapon
	weapon.start_combo()
	weapon.advance(0.0651)
	await _step(1) # Hitbox shape intentionally enters the physics space deferred.
	var before: float = dummy.health.current_health
	var started: int = Time.get_ticks_usec()
	weapon.sample_hits()
	_check(dummy.health.current_health == before - 10.0 and dummy.last_damage_event.melee_hit, "Actual melee Hitbox resolves its unchanged ten-damage payload")
	_check(feedback.is_frozen() and is_equal_approx(Engine.time_scale, 0.05), "Confirmed melee starts global five-percent time scale")
	_check(TimeScaleClaims.owner_count(self) == 1 and feedback.impact_count == 1, "One confirmed root owns one slowdown claim")
	_check(weapon.hitbox.active and collision.shape.get_instance_id() == shape_id and collision.transform == body_transform, "Hitstop does not move collision geometry or change active hitbox")
	var position_before: Vector2 = player.position
	var phase_remaining: float = weapon._phase_remaining
	await _real_time(0.025)
	_check(feedback.is_frozen() and player.position == position_before and weapon._phase_remaining == phase_remaining, "Unscaled interval freezes actor and weapon clocks together")
	weapon.sample_hits()
	_check(dummy.health.current_health == before - 10.0 and feedback.impact_count == 1, "Repeated contact during hitstop cannot duplicate damage or trauma")
	await _real_time(0.075)
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1000000.0
	_check(not feedback.is_frozen() and is_equal_approx(Engine.time_scale, 1.0), "Regular hitstop releases in real time instead of stretching to 1.2 seconds")
	_check(elapsed >= 0.06 and elapsed < 0.5, "Real-time timer finishes within a bounded wall-clock interval (%.4fs)" % elapsed)
	feedback._physics_process(1.0 / float(Engine.physics_ticks_per_second))
	_check(feedback.hit_stop_remaining == 0.0 and not feedback._frozen_this_tick, "Global release has no leftover scaled local freeze")
	weapon.cancel_combo()
	_check(not weapon.hitbox.active and TimeScaleClaims.owner_count(self) == 0, "Recovery cleanup releases the transient hitbox and scale claim")
	feedback.reset_feedback()


func _test_heavy_and_dedup(feedback: CombatFeedback) -> void:
	var dummy: TrainingDummy = level.dummy_a
	feedback.impact_count = 0
	var critical: DamageEvent = _damage(dummy.hurtbox, 1.0)
	critical.melee_hit = true
	critical.critical = true
	_confirm(feedback, dummy.hurtbox, critical)
	_check(feedback.hitstop_manager.remaining_seconds() > 0.10, "Critical hit requests the longer twelve-hundredths window")
	await _real_time(0.075)
	_check(feedback.is_frozen() and is_equal_approx(Engine.time_scale, 0.05), "Critical freeze outlasts the regular window")
	await _real_time(0.075)
	_check(not feedback.is_frozen() and Engine.time_scale == 1.0, "Critical freeze always restores normal speed")
	feedback.reset_feedback()
	feedback.impact_count = 0
	var boss: BossGolem = preload("res://scenes/enemies/boss_golem.tscn").instantiate()
	boss.ai_enabled = false
	boss.feedback = feedback
	boss.position = Vector2(1120, 640)
	level.add_child(boss)
	await _step(2)
	var regular: DamageEvent = _damage(dummy.hurtbox, 1.0)
	regular.melee_hit = true
	_confirm(feedback, dummy.hurtbox, regular)
	var against_boss: DamageEvent = _damage(boss.hurtbox, 1.0)
	against_boss.melee_hit = true
	against_boss.root_event_id = regular.root_event_id
	boss.hurtbox.take_damage(against_boss) # Actor's actual hit listener routes feedback.
	_check(feedback.impact_count == 1 and feedback.hitstop_manager.request_count > 0 and feedback.hitstop_manager.remaining_seconds() > 0.10, "One slash hitting Slime-like target then Boss upgrades its single root to heavy")
	var timer: SceneTreeTimer = feedback.hitstop_manager._timer
	var count: int = feedback.impact_count
	var unrelated: DamageEvent = _damage(dummy.hurtbox, 1.0)
	unrelated.melee_hit = true
	_confirm(feedback, dummy.hurtbox, unrelated)
	var duplicate_result := DamageResult.new()
	duplicate_result.actual_damage = 1.0
	feedback.on_hit_confirmed(regular, duplicate_result)
	_check(feedback.impact_count == count + 1 and feedback.hitstop_manager._timer == timer, "Interleaved roots cannot replay a previous impact or allocate another concurrent timer")
	var blocked: DamageResult = dummy.hurtbox.take_damage(regular)
	feedback.on_hit_confirmed(regular, blocked)
	_check(blocked.blocked and feedback.impact_count == count + 1, "Blocked duplicate Hurtbox event cannot refresh hitstop")
	feedback.reset_feedback()
	var dot: DamageEvent = _damage(dummy.hurtbox, 1.0)
	dot.source_kind = DamageEvent.SourceKind.DOT
	_confirm(feedback, dummy.hurtbox, dot)
	_check(not feedback.is_frozen() and Engine.time_scale == 1.0, "DOT never produces global freeze or trauma")
	var spell: DamageEvent = _damage(dummy.hurtbox, 1.0)
	spell.spell_id = &"fire_bolt"
	_confirm(feedback, dummy.hurtbox, spell)
	_check(not feedback.is_frozen() and Engine.time_scale == 1.0, "Ordinary ranged contact does not interrupt the melee hitstop policy")
	feedback.hit_stop_seconds = 0.0
	var no_stop: DamageEvent = _damage(dummy.hurtbox, 1.0)
	no_stop.melee_hit = true
	_confirm(feedback, dummy.hurtbox, no_stop)
	_check(not feedback.is_frozen() and Engine.time_scale == 1.0, "Existing zero hit-stop benchmark switch disables global slowdown too")
	feedback.hit_stop_seconds = 0.05
	feedback.reset_feedback()
	boss.queue_free()
	await _step(2)


func _test_inventory_claims(feedback: CombatFeedback) -> void:
	var modal: GearInventoryModal = level.gear.modal
	modal.open()
	_check(modal.is_open and is_equal_approx(Engine.time_scale, 0.1), "Inventory owns its ten-percent slowdown through a claim")
	feedback.hitstop_manager.request_hitstop()
	_check(is_equal_approx(Engine.time_scale, 0.05) and TimeScaleClaims.owner_count(self) == 2, "Combat and inventory compose the smaller scale with two scalar owners")
	await _real_time(0.09)
	_check(modal.is_open and is_equal_approx(Engine.time_scale, 0.1), "Hitstop timeout restores inventory slowdown instead of writing normal speed")
	modal.close()
	_check(not modal.is_open and Engine.time_scale == 1.0 and player.controls_enabled, "Closing inventory releases its claim and restores controls")
	feedback.hitstop_manager.request_hitstop()
	modal.open()
	modal.close()
	_check(feedback.is_frozen() and is_equal_approx(Engine.time_scale, 0.05), "Closing inventory during a hit cannot release combat's claim")
	await _real_time(0.09)
	_check(Engine.time_scale == 1.0 and TimeScaleClaims.owner_count(self) == 0, "Combat release restores the original baseline after modal closed first")
	Engine.time_scale = 0.35
	modal.open()
	feedback.hitstop_manager.request_hitstop()
	feedback.reset_feedback()
	_check(is_equal_approx(Engine.time_scale, 0.1) and modal.is_open, "Feedback reset respects a surviving inventory claim")
	modal.close()
	_check(is_equal_approx(Engine.time_scale, 0.35), "Claim teardown preserves an existing nonstandard baseline scale")
	Engine.time_scale = 1.0


func _test_timer_lifetime(feedback: CombatFeedback) -> void:
	var manager: HitstopManager = feedback.hitstop_manager
	manager.request_hitstop()
	var timer: SceneTreeTimer = manager._timer
	var before: int = manager.timer_count
	for index: int in 50:
		manager.request_hitstop(index % 2 == 0)
	_check(manager._timer == timer and manager.timer_count == before and feedback.get_child_count() == 1, "Fifty simultaneous requests share one active timer and one manager")
	paused = true
	await _real_time(0.16)
	_check(not manager.is_active() and Engine.time_scale == 1.0 and paused, "Unscaled process-always timer releases even while the tree is paused")
	paused = false
	manager.request_hitstop()
	var dying_timer: SceneTreeTimer = manager._timer
	manager.cancel()
	_check(not dying_timer.timeout.is_connected(manager._on_timeout) and Engine.time_scale == 1.0, "Cancellation disconnects pending callbacks and immediately releases scale")
	await _real_time(0.08)
	_check(manager._timer == null and Engine.time_scale == 1.0, "A cancelled timer cannot restore over a later scene or modal")


func _test_camera(feedback: CombatFeedback) -> void:
	var camera: PlayerCamera = player.get_node("Camera2D") as PlayerCamera
	camera.set_process(false)
	camera.reset_shake()
	feedback.camera = camera
	var original_position: Vector2 = camera.position
	var player_position: Vector2 = player.position
	camera.add_shake(0.2)
	_check(is_equal_approx(camera.trauma, 0.2) and is_equal_approx(camera.shake_amplitude(), 0.04), "Normal melee trauma produces squared rather than linear amplitude")
	camera.advance_shake(0.01)
	_check(camera.offset.length() > 0.000001 and absf(camera.offset.x) <= 12.0 and absf(camera.offset.y) <= 8.0, "Smooth native noise produces bounded positional shake")
	_check(camera.position == original_position and player.position == player_position and camera.zoom == Vector2(1.35, 1.35), "Shake cannot change lookahead position, Player physics or zoom")
	camera.reset_shake()
	feedback.notify_spell_explosion()
	_check(is_equal_approx(camera.trauma, 0.4), "Spell explosion uses its heavier four-tenths trauma cue")
	camera.reset_shake()
	feedback.notify_boss_stomp()
	_check(is_equal_approx(camera.trauma, 0.7), "Boss stomp uses seven-tenths trauma without changing gameplay damage")
	camera.add_shake(10.0)
	_check(camera.trauma == 1.0, "Simultaneous impact trauma saturates at one")
	for index: int in 30:
		camera.advance_shake(0.02)
	_check(camera.trauma == 0.0 and camera.offset == Vector2.ZERO, "Smooth decay reaches the exact resting offset within a bounded interval")
	camera.offset = Vector2(2, -3)
	camera.advance_shake(0.02)
	_check(camera.offset == Vector2(2, -3), "An idle shake component cannot overwrite another camera offset owner")
	camera.reset_shake()
	camera.shake_intensity = 0.0
	camera.add_shake(0.7)
	camera.advance_shake(0.02)
	_check(camera.offset == Vector2.ZERO and camera.trauma == 0.0, "Zero shake accessibility setting disables noise without changing actor state")
	camera.shake_intensity = 1.0
	feedback.reset_feedback()
	_check(camera.offset == Vector2.ZERO and TimeScaleClaims.owner_count(self) == 0, "Feedback reset drains both camera trauma and transient scale ownership")


func _test_scene_teardown() -> void:
	var feedback: CombatFeedback = level.combat_feedback
	var modal: GearInventoryModal = level.gear.modal
	modal.open()
	feedback.hitstop_manager.request_hitstop(true)
	_check(TimeScaleClaims.owner_count(self) == 2 and is_equal_approx(Engine.time_scale, 0.05), "Scene-switch fixture begins with both inventory and combat claims active")
	var doomed_timer: SceneTreeTimer = feedback.hitstop_manager._timer
	var doomed_manager: int = feedback.hitstop_manager.get_instance_id()
	TimeScaleClaims.release_subtree(level)
	_check(Engine.time_scale == 1.0 and TimeScaleClaims.owner_count(self) == 0, "Run detachment releases its complete subtree before entering the Hub")
	level.queue_free()
	await _step(3)
	_check(not is_instance_id_valid(doomed_manager) and doomed_timer.timeout.get_connections().is_empty(), "Room exit releases the manager and disconnects its real-time timer callback")
	var survivor := Node.new()
	root.add_child(survivor)
	TimeScaleClaims.acquire(survivor, 0.1)
	await _real_time(0.16)
	_check(is_equal_approx(Engine.time_scale, 0.1) and TimeScaleClaims.owner_count(self) == 1, "A previous room's timeout cannot overwrite a new room's claim")
	TimeScaleClaims.release(survivor)
	survivor.queue_free()
	await _step(2)
	_check(Engine.time_scale == 1.0 and not has_meta(TimeScaleClaims.META_KEY), "Final owner release removes scalar metadata and restores the original baseline")


func _confirm(feedback: CombatFeedback, target: Hurtbox, event: DamageEvent) -> void:
	feedback.on_hit_confirmed(event, target.take_damage(event))


func _real_time(seconds: float) -> void:
	# Runner uses --fixed-fps: its unscaled timer delta is simulated time. The
	# HitstopManager deadline is wall time, so measure and yield wall time here.
	var deadline: int = Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		await process_frame
		OS.delay_msec(2)
	await process_frame # Allow the timer release callback on the following frame.

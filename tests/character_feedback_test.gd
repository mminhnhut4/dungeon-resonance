extends "res://tests/survival_test_base.gd"
## Real motor travel/input and room-owned finite footsteps, never new gameplay.


func _initialize() -> void:
	suite = "character_feedback"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.energy.enabled = false
	var presentation: SlicePresentation = level.presentation
	var body: CollisionShape2D = player.get_node("BodyCollision") as CollisionShape2D
	var shape: Shape2D = body.shape
	var local_transform: Transform2D = body.transform
	var hurt_shape: Shape2D = player.hurtbox.get_node("CollisionShape2D").shape
	await _prepare_floor(presentation)
	var before: int = presentation.foot_dust_count
	await _time(0.4)
	_check(presentation.foot_dust_count == before, "Standing still produces no repeated foot dust")
	var origin: Vector2 = player.global_position
	Input.action_press(&"move_right")
	await _time(0.45)
	Input.action_release(&"move_right")
	var puffs: int = presentation.foot_dust_count - before
	_check(player.global_position.x > origin.x + 100.0 and player.motor.is_grounded(), "Run fixture travels on actual floor collisions")
	_check(puffs >= 2 and puffs <= 3, "Grounded run uses distance and a minimum 0.16-second cadence (%d puffs)" % puffs)
	_check(presentation.foot_dust.get_child_count() <= 3, "Routine running never fills the eight-owner dust budget")
	var finite_geometry: bool = true
	for puff: FootstepDust in presentation.foot_dust.get_children():
		finite_geometry = finite_geometry and puff.particles.amount == 4 and puff.particles.one_shot and not puff.particles.local_coords and absf(puff.global_position.y - 640.0) < 0.1
	_check(finite_geometry, "Every run puff has four world-space particles at real floor contact")
	await _time(0.2)
	before = presentation.foot_dust_count
	await _time(0.45)
	_check(is_zero_approx(player.velocity.x) and presentation.foot_dust_count == before and presentation.foot_dust.get_child_count() == 0, "Braking settles once and all run dust expires without idle emission")
	await _test_airborne_and_jump(presentation)
	await _test_dash_and_inventory(presentation)
	await _test_wall_and_warp(presentation)
	_test_frozen_clock(presentation)
	await _test_rebuild_and_teardown(presentation)
	_check(body.shape == shape and body.transform == local_transform and player.hurtbox.get_node("CollisionShape2D").shape == hurt_shape, "All foot feedback preserves BodyCollision/Hurtbox resources and local transforms")
	var disposable: FootstepDust = presentation.spawn_foot_dust(Vector2(780, 640))
	var puff_id: int = disposable.get_instance_id()
	var particles_id: int = disposable.particles.get_instance_id()
	level.queue_free()
	await _step(4)
	_check(not is_instance_id_valid(puff_id) and not is_instance_id_valid(particles_id), "Room teardown releases an active puff and its GPU node with their owner")


func _prepare_floor(presentation: SlicePresentation) -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"jump")
	Input.action_release(&"dash")
	player.reset_movement_at(Vector2(780, 640))
	player.controls_enabled = true
	player.set_physics_process(true)
	presentation.set_physics_process(true)
	level.combat_feedback.reset_feedback()
	await _step(3)
	presentation.rebuild()
	await _step(2)


func _test_airborne_and_jump(presentation: SlicePresentation) -> void:
	await _prepare_floor(presentation)
	var before: int = presentation.foot_dust_count
	Input.action_press(&"jump")
	await _step(2)
	_check(player.velocity.y < 0.0 and presentation.foot_dust_count == before + 1, "Real jump input emits exactly one grounded takeoff puff")
	Input.action_press(&"move_right")
	await _time(0.12)
	_check(not player.motor.is_grounded() and presentation.foot_dust_count == before + 1, "Horizontal air movement cannot emit running foot dust")
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	await _time(0.7)
	_check(player.motor.is_grounded() and presentation.foot_dust_count == before + 2, "Jump cycle adds one landing puff after its one takeoff puff")
	before = presentation.foot_dust_count
	await _time(0.25)
	_check(presentation.foot_dust_count == before, "Landing feedback remains a single edge-triggered puff")
	player.reset_movement_at(Vector2(850, 350))
	Input.action_press(&"move_right")
	await _time(0.08)
	Input.action_release(&"move_right")
	_check(not player.motor.is_grounded() and presentation.foot_dust_count == before, "Falling with movement input creates no floor dust")


func _test_dash_and_inventory(presentation: SlicePresentation) -> void:
	await _prepare_floor(presentation)
	var before: int = presentation.foot_dust_count
	Input.action_press(&"move_right")
	Input.action_press(&"dash")
	await _time(0.10)
	Input.action_release(&"dash")
	Input.action_release(&"move_right")
	_check(player.motor.is_dashing and presentation.foot_dust_count == before + 1, "Dash keeps its one authored puff without running-cadence duplicates")
	await _time(0.2)
	await _prepare_floor(presentation)
	Input.action_press(&"move_right")
	await _time(0.13)
	level.gear.modal.open()
	before = presentation.foot_dust_count
	await _time(0.2)
	_check(level.gear.modal.is_open and not player.controls_enabled and presentation.foot_dust_count == before, "Open inventory suppresses cadence while controls are suspended")
	_check(not presentation._step_tracking and is_zero_approx(presentation._step_distance), "Suspension clears partial distance rather than saving a delayed step")
	Input.action_release(&"move_right")
	level.gear.modal.close()
	await _time(0.3)


func _test_wall_and_warp(presentation: SlicePresentation) -> void:
	await _prepare_floor(presentation)
	player.reset_movement_at(Vector2(1238, 640))
	Input.action_press(&"move_right")
	await _time(0.35)
	var before: int = presentation.foot_dust_count
	var position: Vector2 = player.global_position
	await _time(0.3)
	Input.action_release(&"move_right")
	_check(player.is_on_wall() and player.global_position.distance_to(position) < 0.1 and presentation.foot_dust_count == before, "Holding movement into a wall cannot produce stationary footsteps")
	await _prepare_floor(presentation)
	Input.action_press(&"move_right")
	await _time(0.06)
	before = presentation.foot_dust_count
	player.relocate(Vector2(1080, 640))
	await _step(1)
	_check(presentation.foot_dust_count == before, "Room-style relocation is not counted as hundreds of pixels of foot travel")
	Input.action_release(&"move_right")
	player.reset_movement_at(Vector2(780, 640))
	await _step(3)
	_check(not presentation._step_tracking and is_zero_approx(presentation._step_distance), "Reset to the floor discards old run cadence")


func _test_frozen_clock(presentation: SlicePresentation) -> void:
	player.set_physics_process(false)
	presentation.set_physics_process(false)
	player.velocity = Vector2(320, 0)
	player.locomotion_state_machine.transition_to(&"run")
	presentation._update_footsteps(1.0 / Engine.physics_ticks_per_second, true)
	player.position.x += 6.0
	presentation._update_footsteps(0.025, true)
	var distance: float = presentation._step_distance
	var cooldown: float = presentation._step_cooldown
	var last_position: Vector2 = presentation._step_last_position
	var before: int = presentation.foot_dust_count
	level.combat_feedback._frozen_this_tick = true
	presentation._physics_process(0.25)
	_check(presentation._step_distance == distance and presentation._step_cooldown == cooldown and presentation._step_last_position == last_position and presentation.foot_dust_count == before, "Hit-stop freezes distance, interval and anchor together without a new puff")
	level.combat_feedback.reset_feedback()
	player.velocity = Vector2.ZERO
	player.locomotion_state_machine.transition_to(&"idle")
	presentation._physics_process(0.01)
	_check(not presentation._step_tracking and is_zero_approx(presentation._step_distance), "Returning to idle after hit-stop resets cadence cleanly")
	player.set_physics_process(true)
	presentation.set_physics_process(true)


func _test_rebuild_and_teardown(presentation: SlicePresentation) -> void:
	var ids: Array[int] = []
	for index: int in 25:
		ids.append(presentation.spawn_foot_dust(Vector2(780, 640), Vector2.RIGHT).get_instance_id())
	_check(presentation.foot_dust.get_child_count() == 8, "Run, jump, landing and dash share the existing eight-owner hard budget")
	await _time(0.4)
	_check(presentation.foot_dust.get_child_count() == 0 and ids.all(func(id: int) -> bool: return not is_instance_id_valid(id)), "Finite lifetime releases all spawned puffs, including owners displaced by budget")
	var leftover: FootstepDust = presentation.spawn_foot_dust(Vector2(780, 640))
	var leftover_id: int = leftover.get_instance_id()
	presentation._step_distance = 21.0
	presentation._step_cooldown = 0.11
	presentation._step_tracking = true
	presentation.rebuild()
	_check(presentation.foot_dust.get_child_count() == 0 and not presentation._step_tracking and presentation._step_distance == 0.0 and presentation._step_cooldown == 0.0, "Room rebuild immediately removes dust and resets all cadence clocks")
	await _step(2)
	_check(not is_instance_id_valid(leftover_id), "Rebuild's detached puff is freed on the next safe frame")

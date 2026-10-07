extends SceneTree
## Before/after transform measurements, not a GPU/game-feel verdict.

var arena: Node2D
var hero: Player
var feedback: CombatFeedback
var report: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	print("ISOLATED_USER: ", OS.get_user_data_dir())
	report["visual_sha256"] = FileAccess.get_sha256("res://scripts/presentation/world_enemy_visual.gd")
	report["slime_skin_sha256"] = FileAccess.get_sha256("res://scripts/presentation/slime_sprite_skin.gd")
	report["base_enemy_sha256"] = FileAccess.get_sha256("res://scripts/actors/enemies/base_enemy.gd")
	arena = Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(640, 680)
	floor_body.collision_layer = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1280, 80)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	arena.add_child(floor_body)
	feedback = CombatFeedback.new()
	feedback.hit_stop_seconds = 0
	arena.add_child(feedback)
	hero = preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	arena.add_child(hero)
	hero.reset_movement_at(Vector2(500, 640))
	hero.controls_enabled = false
	(hero.get_node("Camera2D") as Camera2D).enabled = false
	var guard := preload("res://scenes/enemies/ancient_guard.tscn").instantiate() as BaseEnemy
	guard.position = Vector2(730, 640)
	guard.combat_feedback = feedback
	guard.facing = 1
	arena.add_child(guard)
	var foot_gap: float = 0
	var flips: int = 0
	var previous_face: float = guard.facing
	for frame: int in Engine.physics_ticks_per_second * 2:
		await _step(1)
		if guard.is_on_floor():
			var foot: Vector2 = EnemySpriteArt.foot_world(guard.visual.sprite, guard.visual.geometry["foot_pixel"])
			foot_gap = maxf(foot_gap, absf(foot.y - guard.global_position.y))
		if guard.facing != previous_face: flips += 1
		previous_face = guard.facing
	report["guard_grounded_sprite_foot_gap_max_px"] = foot_gap
	report["guard_flat_patrol_turns_in_two_seconds"] = flips
	guard.player = hero
	guard.ai_enabled = false
	guard.visual.set_physics_process(false)
	guard.state_machine.transition_to(&"telegraph")
	for tick: int in ceili(guard.definition.windup * Engine.physics_ticks_per_second):
		guard.state_time = minf(guard.definition.windup, float(tick + 1) / Engine.physics_ticks_per_second)
		guard.visual._physics_process(1.0 / Engine.physics_ticks_per_second)
	report["guard_windup_rotation_rad"] = guard.visual.motion.rotation
	guard.state_machine.transition_to(&"attack")
	for tick: int in ceili(guard.definition.active * Engine.physics_ticks_per_second):
		guard.state_time = minf(guard.definition.active, float(tick + 1) / Engine.physics_ticks_per_second)
		guard.visual._physics_process(1.0 / Engine.physics_ticks_per_second)
	var active_rotation: float = guard.visual.motion.rotation
	guard.state_machine.transition_to(&"recover")
	guard.visual._physics_process(1.0 / Engine.physics_ticks_per_second)
	report["guard_attack_to_recovery_first_step_rad"] = absf(angle_difference(active_rotation, guard.visual.motion.rotation))
	# Settle recovery first so an attack followthrough cannot masquerade as recoil.
	for tick: int in ceili(0.4 * Engine.physics_ticks_per_second): guard.visual._physics_process(1.0 / Engine.physics_ticks_per_second)
	var rest_rotation: float = guard.visual.motion.rotation
	var event := DamageEvent.new()
	event.source_id = hero.get_instance_id()
	event.source_team_id = 1
	event.target_id = guard.get_instance_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = 1
	event.attack_direction = Vector2.RIGHT
	guard.hurtbox.take_damage(event)
	guard.visual._physics_process(0.05)
	report["guard_incoming_hit_pose_delta_rad"] = absf(angle_difference(rest_rotation, guard.visual.motion.rotation))
	# Deliberate 0.25px target crossover, within melee cooldown: stationary intent.
	guard.state_machine.transition_to(&"chase")
	guard.attack_cooldown = 2.0
	guard.ai_enabled = true
	guard.visual.set_physics_process(true)
	var mirror_changes: int = 0
	var previous_mirror: bool = guard.visual.sprite.flip_h
	var crossover_origin: Vector2 = guard.global_position
	var max_crossover_displacement: float = 0.0
	for tick: int in 20:
		hero.global_position = guard.global_position + Vector2(0.25 if tick % 2 == 0 else -0.25, 0)
		await _step(1)
		if "--trace-crossover" in OS.get_cmdline_user_args(): print("CROSSOVER: ", tick, " body=", guard.global_position, " velocity=", guard.velocity, " target=", hero.global_position, " state=", guard.state_machine.get_state_id())
		if guard.visual.sprite.flip_h != previous_mirror: mirror_changes += 1
		previous_mirror = guard.visual.sprite.flip_h
		max_crossover_displacement = maxf(max_crossover_displacement, guard.global_position.distance_to(crossover_origin))
	report["guard_stopped_crossover_sprite_flips_in_20_ticks"] = mirror_changes
	report["guard_stopped_crossover_body_displacement_px"] = max_crossover_displacement
	guard.ai_enabled = false
	hero.reset_movement_at(Vector2(500, 640))
	var slime := preload("res://scenes/enemies/slime_enemy.tscn").instantiate() as SlimeEnemy
	slime.position = Vector2(850, 640)
	slime.combat_feedback = feedback
	arena.add_child(slime)
	var skin := SlimeSpriteSkin.new()
	slime.add_child(skin)
	skin.bind(slime)
	await _step(ceili(0.4 * Engine.physics_ticks_per_second))
	var changing_poses: int = 0
	var previous_pose: Transform2D = skin.motion.transform
	for frame: int in Engine.physics_ticks_per_second:
		await _step(1)
		if absf(slime.velocity.x) > 8 and skin.motion.transform != previous_pose: changing_poses += 1
		previous_pose = skin.motion.transform
	report["slime_walk_pose_changes_in_one_second"] = changing_poses
	report["hz"] = Engine.physics_ticks_per_second
	print("AUDIT: ", JSON.stringify(report))
	DirAccess.make_dir_recursive_absolute("res://docs/verification")
	var destination: String = "res://docs/verification/opening_audit_%d.json" % Engine.physics_ticks_per_second
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): destination = arg.trim_prefix("--report=")
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	arena.queue_free()
	await _step(5)
	quit()

func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame

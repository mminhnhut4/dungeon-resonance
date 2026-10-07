extends SceneTree
## Focused read-only adapters against real world collision, FSM and DamageEvent.

const IDS: Array[StringName] = [&"ancient_guard", &"bloodwing_bat", &"sword_wraith", &"runic_champion"]
var arena: Node2D
var hero: Player
var feedback: CombatFeedback
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	print("ISOLATED_USER: ", OS.get_user_data_dir())
	print("OPENING POLISH TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	arena = Node2D.new()
	root.add_child(arena)
	current_scene = arena
	_block(Vector2(800, 680), Vector2(1600, 80))
	_block(Vector2(1180, 520), Vector2(24, 240))
	var ramp := StaticBody2D.new()
	ramp.collision_layer = 1
	var ramp_shape := CollisionPolygon2D.new()
	ramp_shape.polygon = PackedVector2Array([Vector2(1600, 640), Vector2(1900, 580), Vector2(1900, 720), Vector2(1600, 720)])
	ramp.add_child(ramp_shape)
	arena.add_child(ramp)
	feedback = CombatFeedback.new()
	feedback.hit_stop_seconds = 0.0
	feedback.shake_strength = 0.0
	arena.add_child(feedback)
	hero = preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	arena.add_child(hero)
	hero.reset_movement_at(Vector2(500, 640))
	hero.controls_enabled = false
	hero.combat_feedback = feedback
	(hero.get_node("Camera2D") as Camera2D).enabled = false
	await _ground_motion()
	await _world_actions()
	await _slime()
	await _training_slime()
	await _pause_and_lifetime()
	print("METRICS: ", JSON.stringify(metrics))
	DirAccess.make_dir_recursive_absolute("res://docs/verification")
	var file := FileAccess.open("res://docs/verification/opening_polish_%d.json" % Engine.physics_ticks_per_second, FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "\t"))
	file.close()
	arena.queue_free()
	await _step(5)
	_check(get_nodes_in_group(&"enemies").is_empty() and get_nodes_in_group(&"world_enemy_hazards").is_empty(), "Final teardown releases actors and attack entities")
	_check(not paused and is_equal_approx(Engine.time_scale, 1.0), "Test leaves pause and global time restored")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _ground_motion() -> void:
	for id: StringName in [&"ancient_guard", &"runic_champion"]:
		var enemy: BaseEnemy = await _fresh(id, Vector2(850, 640))
		enemy.player = null
		enemy.facing = 1
		enemy.ai_enabled = true
		var gap: float = 0.0
		var phase_error: float = 0.0
		for frame: int in Engine.physics_ticks_per_second:
			var position_before: Vector2 = enemy.global_position
			var phase_before: float = enemy.visual.walk_phase
			await _step(1)
			if enemy.is_on_floor():
				gap = maxf(gap, EnemySpriteArt.foot_world(enemy.visual.sprite, enemy.visual.geometry["foot_pixel"]).distance_to(enemy.global_position))
				var expected: float = fmod(phase_before + absf(enemy.global_position.x - position_before.x) * TAU / 36.0, TAU)
				phase_error = maxf(phase_error, absf(angle_difference(expected, enemy.visual.walk_phase)))
		_check(gap < 0.001, "%s grounded walk keeps solid sprite foot at physical pivot" % id)
		_check(phase_error < 0.001, "%s walking phase follows actual distance without frame-clock restart" % id)
		metrics["%s_foot_gap_px" % id] = gap
		metrics["%s_gait_phase_error_rad" % id] = phase_error
		enemy.ai_enabled = false
		var phase: float = enemy.visual.walk_phase
		await _step(12)
		_check(is_equal_approx(enemy.visual.walk_phase, phase), "%s stationary body cannot keep advancing its walking phase" % id)
		# Controlled stopped crossover: don't alternate the PNG for sub-pixel target jitter.
		enemy.visual.set_physics_process(false)
		enemy.velocity = Vector2.ZERO
		enemy.player = hero
		var held_facing: float = enemy.visual.displayed_facing
		for tick: int in 20:
			hero.global_position.x = enemy.global_position.x + (0.25 if tick % 2 == 0 else -0.25)
			enemy.facing = 1 if tick % 2 == 0 else -1
			enemy.visual._physics_process(1.0 / Engine.physics_ticks_per_second)
		_check(enemy.visual.displayed_facing == held_facing, "%s stopped target crossover cannot cause sprite flip thrash" % id)
		enemy.state_machine.transition_to(&"telegraph")
		enemy.visual._physics_process(1.0 / Engine.physics_ticks_per_second)
		_check(enemy.visual.displayed_facing == enemy.facing, "%s committed warning keeps the authoritative attack facing" % id)
		# Real AI crossover during cooldown, rather than only sampling the adapter.
		enemy = await _fresh(id, Vector2(850, 640))
		enemy.state_machine.transition_to(&"chase")
		enemy.attack_cooldown = 2.0
		enemy.ai_enabled = true
		var origin_x: float = enemy.global_position.x
		var displacement: float = 0.0
		for tick: int in 20:
			hero.global_position = enemy.global_position + Vector2(0.25 if tick % 2 == 0 else -0.25, 0)
			await _step(1)
			displacement = maxf(displacement, absf(enemy.global_position.x - origin_x))
		_check(displacement < 0.001 and absf(enemy.velocity.x) < 0.001 and enemy.state_machine.get_state_id() == &"chase", "%s real grounded cooldown waits in range without micro-chase steps" % id)
		metrics["%s_cooldown_crossover_body_dx_px" % id] = displacement
		hero.reset_movement_at(enemy.global_position + Vector2(-enemy.definition.attack_range - 40.0, 0))
		hero.controls_enabled = false
		await _time(0.2)
		_check(enemy.global_position.x < origin_x - 5.0, "%s cooldown can still approach a target outside attack range" % id)
	var guard: BaseEnemy = await _fresh(&"ancient_guard", Vector2(1140, 640))
	guard.player = null
	guard.facing = 1
	guard.ai_enabled = true
	await _time(0.8)
	_check(guard.facing < 0 and guard.global_position.x < 1156 and guard.visual.displayed_facing < 0, "Real wall turn preserves motor collision and visual travel facing")
	guard = await _fresh(&"ancient_guard", Vector2(1660, 630))
	guard.player = null
	guard.facing = 1
	guard.ai_enabled = true
	var grounded_frames: int = 0
	var slope_gap: float = 0
	var start_x: float = guard.global_position.x
	for frame: int in Engine.physics_ticks_per_second:
		await _step(1)
		if guard.is_on_floor():
			grounded_frames += 1
			slope_gap = maxf(slope_gap, EnemySpriteArt.foot_world(guard.visual.sprite, guard.visual.geometry["foot_pixel"]).distance_to(guard.global_position))
	_check(grounded_frames > Engine.physics_ticks_per_second / 2 and guard.global_position.x > start_x + 20 and slope_gap < 0.001, "Actual ramp traversal adds no cosmetic foot displacement or terrain collision changes")
	metrics["guard_slope_foot_gap_px"] = slope_gap
	# Existing slowdown changes travel, therefore the distance-driven gait as well.
	guard = await _fresh(&"ancient_guard", Vector2(850, 640))
	guard.player = null
	guard.facing = 1
	guard.condition_speed_multiplier = 0.5
	guard.ai_enabled = true
	await _time(0.5)
	_check(absf(guard.velocity.x) <= guard.definition.patrol_speed * 0.5 + 0.01, "Slowed walk keeps the existing motor speed modifier")
	_check(guard.visual.walk_phase > 0 and guard.visual.walk_phase < PI, "Slowed walk advances a proportionally smaller cosmetic stride")

func _world_actions() -> void:
	for id: StringName in IDS:
		var enemy: BaseEnemy = await _fresh(id, Vector2(800, 500 if id == &"bloodwing_bat" else 640))
		enemy.visual.set_physics_process(false)
		var body: CollisionShape2D = enemy.get_node("BodyCollision") as CollisionShape2D
		var physical: Transform2D = body.global_transform
		var hurt: Transform2D = enemy.hurtbox.global_transform
		var shape_id: int = body.shape.get_instance_id()
		var definition_before: String = var_to_str(enemy.definition)
		enemy.state_machine.transition_to(&"telegraph")
		for tick: int in ceili(enemy.definition.windup * Engine.physics_ticks_per_second):
			enemy.state_time = minf(enemy.definition.windup, float(tick + 1) / Engine.physics_ticks_per_second)
			enemy.visual._physics_process(1.0 / Engine.physics_ticks_per_second)
		var prepared: bool = enemy.visual.body_frames != null and enemy.visual.body_frames.clip_id == &"attack_sweep" and enemy.visual.body_frames.frame_index == 1 if id == &"ancient_guard" else absf(enemy.visual.motion.rotation) > 0.045
		_check(not enemy.attack_hitbox.active and prepared, "%s anticipation has a visible prepared pose before its active window" % id)
		var incoming_count: int = enemy.visual.hit_reaction_count
		var outgoing_count: int = feedback.impact_count
		enemy.state_machine.transition_to(&"attack")
		var count_before: int = enemy.visual.active_cue_count
		for tick: int in ceili(enemy.definition.active * Engine.physics_ticks_per_second):
			enemy.state_time = minf(enemy.definition.active, float(tick + 1) / Engine.physics_ticks_per_second)
			enemy.visual._physics_process(1.0 / Engine.physics_ticks_per_second)
		_check(enemy.visual.active_cue_count == count_before + 1 and feedback.impact_count == outgoing_count, "%s creates one launch cue; a miss cannot claim an accepted hit" % id)
		var rotation_before: float = enemy.visual.motion.rotation
		enemy.state_machine.transition_to(&"recover")
		enemy.visual._physics_process(1.0 / Engine.physics_ticks_per_second)
		var recovery_step: float = absf(angle_difference(rotation_before, enemy.visual.motion.rotation))
		_check(recovery_step < 0.09 and enemy.visual.active_cue_remaining == 0 and not enemy.attack_hitbox.active, "%s recovery blends pose and closes launch cue/hitbox" % id)
		metrics["%s_recovery_first_step_rad" % id] = recovery_step
		_check(body.global_transform == physical and enemy.hurtbox.global_transform == hurt and body.shape.get_instance_id() == shape_id and var_to_str(enemy.definition) == definition_before, "%s entire presentation leaves physics resources and definition unchanged" % id)
		var event: DamageEvent = _damage(enemy.hurtbox, 1)
		var pose_before_hit: float = enemy.visual.motion.rotation
		var hit: DamageResult = enemy.hurtbox.take_damage(event)
		var feedback_count: int = feedback.impact_count
		var hp: float = enemy.health.current_health
		var duplicate: DamageResult = enemy.hurtbox.take_damage(event)
		enemy.visual._physics_process(0.05)
		_check(not hit.blocked and duplicate.blocked and enemy.health.current_health == hp and enemy.visual.hit_reaction_count == incoming_count + 1 and feedback.impact_count == feedback_count, "%s accepted incoming hit reacts once; duplicate adds no feedback" % id)
		var recoil_pose: bool = enemy.visual.body_frames != null and enemy.visual.body_frames.clip_id == &"hurt" and enemy.flash_remaining > 0.0 if id == &"ancient_guard" else absf(angle_difference(pose_before_hit, enemy.visual.motion.rotation)) > 0.04
		_check(recoil_pose and enemy.visual._hit_remaining > 0.0, "%s accepted hit changes pose with finite recoil alongside its existing flash" % id)
		var dot: DamageEvent = _damage(enemy.hurtbox, 1)
		dot.source_kind = DamageEvent.SourceKind.DOT
		enemy.hurtbox.take_damage(dot)
		_check(enemy.visual.hit_reaction_count == incoming_count + 1, "%s DoT does not restart its impact pose" % id)
		enemy.hurtbox.set_invulnerable(true)
		enemy.hurtbox.take_damage(_damage(enemy.hurtbox, 1))
		_check(enemy.visual.hit_reaction_count == incoming_count + 1, "%s blocked hit produces no impact pose" % id)
		enemy.hurtbox.set_invulnerable(false)
		enemy.state_machine.transition_to(&"telegraph")
		enemy.state_machine.transition_to(&"attack")
		enemy.visual._physics_process(1.0 / Engine.physics_ticks_per_second)
		var stun: DamageEvent = _damage(enemy.hurtbox, 1)
		stun.stun_seconds = 0.2
		enemy.hurtbox.take_damage(stun)
		enemy.visual._physics_process(1.0 / Engine.physics_ticks_per_second)
		_check(enemy.state_machine.get_state_id() == &"hurt" and not enemy.attack_hitbox.active and enemy.visual.active_cue_remaining == 0 and enemy.visual.trail.is_empty(), "%s interrupted active attack clears the hostile window and local attack effects" % id)

func _slime() -> void:
	await _wipe()
	var slime: SlimeEnemy = preload("res://scenes/enemies/slime_enemy.tscn").instantiate() as SlimeEnemy
	slime.position = Vector2(850, 640)
	slime.combat_feedback = feedback
	arena.add_child(slime)
	var skin := SlimeSpriteSkin.new()
	slime.add_child(skin)
	await _time(0.4)
	var gait_changes: int = 0
	var gap: float = 0.0
	for frame: int in Engine.physics_ticks_per_second:
		var old_pose: Transform2D = skin.motion.transform
		await _step(1)
		if skin.motion.transform != old_pose and absf(slime.velocity.x) > 8: gait_changes += 1
		if slime.is_on_floor(): gap = maxf(gap, skin.get_foot_world().distance_to(slime.global_position))
	_check(gait_changes > Engine.physics_ticks_per_second / 2 and gap < 0.001, "Settled Slime walk changes pose with travel while keeping its physical foot pivot")
	metrics["slime_walk_pose_changes_per_second"] = gait_changes
	metrics["slime_grounded_foot_gap_px"] = gap
	slime.ai_enabled = false
	skin.set_physics_process(false)
	slime.player = hero
	var collision: Transform2D = (slime.get_node("BodyCollision") as CollisionShape2D).global_transform
	var hurt: Transform2D = slime.hurtbox.global_transform
	var position_before: Vector2 = slime.global_position
	slime.state_machine.transition_to(&"attack")
	slime._state_time = 0.12
	for tick: int in 12: skin._physics_process(1.0 / Engine.physics_ticks_per_second)
	_check(skin.motion.scale.x > 1.25 and skin.motion.scale.y < 0.8 and not slime.bite_hitbox.active and skin.active_cue_count == 0, "Slime readable tell prepares its authored squash without a damage/launch cue")
	slime._state_time = slime.telegraph_seconds + 0.01
	slime.tick_state(&"attack", 0)
	skin._physics_process(1.0 / Engine.physics_ticks_per_second)
	var count: int = skin.active_cue_count
	skin._physics_process(1.0 / Engine.physics_ticks_per_second)
	_check(slime.bite_hitbox.active and count == 1 and skin.active_cue_count == count, "Real Slime bite window creates one local launch mark")
	var event: DamageEvent = _damage(slime.hurtbox, 1)
	slime.hurtbox.take_damage(event)
	slime.hurtbox.take_damage(event)
	skin._physics_process(0.05)
	_check(skin.hit_reaction_count == 1 and absf(skin.motion.rotation) > 0.04 and skin.active_cue_remaining == 0 and not slime.bite_hitbox.active, "Accepted Slime hit recoils once and attack cancellation clears cue/hitbox")
	_check((slime.get_node("BodyCollision") as CollisionShape2D).global_transform == collision and slime.hurtbox.global_transform == hurt and slime.global_position == position_before, "Slime tell, active and hurt presentation never moves authoritative geometry")
	var dot: DamageEvent = _damage(slime.hurtbox, 1)
	dot.source_kind = DamageEvent.SourceKind.DOT
	slime.hurtbox.take_damage(dot)
	_check(skin.hit_reaction_count == 1, "Slime DoT does not restart the cosmetic impact pose")
	slime.hurtbox.set_invulnerable(true)
	slime.hurtbox.take_damage(_damage(slime.hurtbox, 1))
	_check(skin.hit_reaction_count == 1, "Slime blocked hit creates no cosmetic impact pose")
	var connection_count: int = slime.hurtbox.hit_resolved.get_connections().size()
	skin.bind(null)
	_check(not slime.hurtbox.hit_resolved.is_connected(skin._on_visual_hit), "Slime unbind disconnects its accepted-hit observer")
	skin.bind(slime)
	_check(slime.hurtbox.hit_resolved.get_connections().size() == connection_count, "Slime rebind installs exactly one accepted-hit observer")
	slime.reset_at_home()
	skin._physics_process(0)
	_check(skin._hit_remaining == 0 and skin.active_cue_remaining == 0 and skin.get_foot_world().distance_to(slime.global_position) < 0.001, "Home reset clears transient recoil and attack effects at the original foot")

func _pause_and_lifetime() -> void:
	var enemy: BaseEnemy = await _fresh(&"ancient_guard", Vector2(850, 640))
	enemy.state_machine.transition_to(&"telegraph")
	enemy.ai_enabled = true
	await _step(3)
	var pose: Transform2D = enemy.visual.motion.transform
	var authored_texture: Texture2D = enemy.visual.sprite.texture
	var state_time: float = enemy.state_time
	var phase: float = enemy.visual.walk_phase
	paused = true
	for frame: int in 6: await process_frame
	_check(enemy.visual.motion.transform == pose and enemy.state_time == state_time and enemy.visual.walk_phase == phase, "SceneTree pause freezes presentation and gameplay clocks together")
	paused = false
	feedback.set_physics_process(false)
	feedback._frozen_this_tick = true
	await _step(3)
	_check(enemy.visual.motion.transform == pose and enemy.state_time == state_time, "Shared hit-stop freezes presentation on the same gameplay clock")
	feedback.reset_feedback()
	feedback.set_physics_process(true)
	await _step(ceili(enemy.definition.windup / 5.0 * Engine.physics_ticks_per_second))
	_check(enemy.state_time > state_time and enemy.visual.sprite.texture != authored_texture and enemy.visual.body_frames.clip_id == &"windup_sweep", "Unpause resumes the existing warning into its next authored pose instead of restarting it")
	var released: Array[int] = [enemy.visual.get_instance_id(), enemy.visual.shadow.get_instance_id()]
	enemy.queue_free()
	await _step(4)
	_check(not is_instance_id_valid(released[0]) and not is_instance_id_valid(released[1]), "Actor removal releases local motion, cue and shadow ownership")

func _training_slime() -> void:
	await _wipe()
	hero.reset_movement_at(Vector2(500, 640))
	hero.controls_enabled = false
	var slime: HubTrainingSlime = preload("res://scenes/hub/training_slime.tscn").instantiate() as HubTrainingSlime
	slime.position = Vector2(530, 640)
	slime.patrol_speed = 25
	slime.chase_speed = 65
	slime.telegraph_seconds = 0.45
	slime.aggro_radius = 160
	slime.combat_feedback = feedback
	slime.player = hero
	slime.ai_enabled = false
	arena.add_child(slime)
	var skin := SlimeSpriteSkin.new()
	slime.add_child(skin)
	skin.set_physics_process(false)
	slime.state_machine.transition_to(&"attack")
	slime._state_time = 0.44
	slime.tick_state(&"attack", 0)
	skin._physics_process(0.02)
	_check(not slime.bite_hitbox.active and skin.active_cue_count == 0, "Opening training Slime preserves its longer 0.45s warning")
	slime._state_time = 0.46
	slime.tick_state(&"attack", 0)
	skin._physics_process(0.02)
	_check(slime.bite_hitbox.active and skin.active_cue_count == 1 and slime.chase_speed == 65 and slime.patrol_speed == 25, "Training bite gets the same launch mark without changing authored speeds")
	var attack: AttackSnapshot = slime.bite_hitbox.attack_snapshot
	var hp: float = hero.health.current_health
	var feedback_count: int = feedback.impact_count
	slime._bite_contact(hero.hurtbox, attack)
	slime._bite_contact(hero.hurtbox, attack)
	_check(is_equal_approx(hero.health.current_health, hp - 5.0) and feedback.impact_count == feedback_count + 1, "Real opening training DamageEvent remains 5 damage and one confirmed feedback on duplicate delivery")
	var cue: float = skin.active_cue_remaining
	var pose: Transform2D = skin.motion.transform
	feedback._frozen_this_tick = true
	skin._physics_process(0.3)
	_check(skin.active_cue_remaining == cue and skin.motion.transform == pose, "Training launch cue and pose share existing local hit-stop")
	feedback.reset_feedback()
	slime._state_time = slime.telegraph_seconds + 0.2
	slime.tick_state(&"attack", 0)
	skin._physics_process(0.02)
	_check(not slime.bite_hitbox.active and skin.active_cue_remaining == 0, "Opening training recovery closes cue and damage window together")

func _fresh(id: StringName, position: Vector2) -> BaseEnemy:
	await _wipe()
	hero.reset_movement_at(Vector2(500, 640))
	hero.controls_enabled = false
	var enemy: BaseEnemy = (load("res://scenes/enemies/%s.tscn" % id) as PackedScene).instantiate() as BaseEnemy
	enemy.position = position
	enemy.player = hero
	enemy.combat_feedback = feedback
	enemy.ai_enabled = false
	arena.add_child(enemy)
	await _step(3)
	return enemy

func _wipe() -> void:
	feedback.reset_feedback()
	for node: Node in get_nodes_in_group(&"enemies") + get_nodes_in_group(&"enemy_hazards") + get_nodes_in_group(&"combat_text"):
		if arena.is_ancestor_of(node): node.queue_free()
	await _step(4)

func _damage(target: Hurtbox, amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = hero.get_instance_id()
	event.source_team_id = 1
	event.target_id = target.get_actor_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = amount
	event.attack_direction = Vector2.RIGHT
	return event

func _block(position: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = position
	body.collision_layer = 1
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	arena.add_child(body)

func _time(seconds: float) -> void:
	await _step(ceili(seconds * Engine.physics_ticks_per_second))

func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", label])

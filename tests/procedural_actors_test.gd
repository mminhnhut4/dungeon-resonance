extends "res://tests/survival_test_base.gd"
## Cosmetic dynamics must never move authoritative physics or combat clocks.

const PLAYER_SCENE: PackedScene = preload("res://scenes/actors/player/player.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime_enemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/boss_golem.tscn")


func _initialize() -> void:
	suite = "procedural_actors"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.set_physics_process(false)
	var rig: PlayerVisualRig = player.get_node("Visuals") as PlayerVisualRig
	rig.set_physics_process(false)
	rig.set_modular_skin(null) # Explicit historical PNG/14-bone fixture; assertions stay intact.
	_test_pose_math()
	await _test_player(rig)
	_test_shadow(rig.actor_shadow)
	_test_slime()
	await _test_boss()
	await _test_lifetimes()
	player.velocity = Vector2.ZERO
	rig.bind(player)
	rig.set_physics_process(true)
	player.set_physics_process(true)


func _test_pose_math() -> void:
	_check(is_equal_approx(ProceduralAnimator.breathing_scale(0.0), 1.0) and is_equal_approx(ProceduralAnimator.breathing_scale(0.6), 1.035) and is_equal_approx(ProceduralAnimator.breathing_scale(1.2), 1.0), "Idle breathing completes a bounded 1.0 to 1.035 cycle")
	_check(ProceduralAnimator.slime_attack_scale(0.0, 0.3).is_equal_approx(Vector2.ONE) and ProceduralAnimator.slime_attack_scale(0.12, 0.3).is_equal_approx(Vector2(1.35, 0.65)), "Slime anticipation reaches its authored squash after 0.12 seconds")
	_check(ProceduralAnimator.slime_attack_scale(0.36, 0.3).is_equal_approx(Vector2(0.75, 1.3)) and is_equal_approx(ProceduralAnimator.slime_hop_offset(0.36, 0.3), -6.0), "Bite lunge has a vertical stretch and small purely visual hop")
	_check(ProceduralAnimator.landing_scale(0.08).is_equal_approx(Vector2(1.25, 0.75)) and ProceduralAnimator.landing_scale(0.30).is_equal_approx(Vector2.ONE), "Landing compresses in 0.08 seconds and restores its rest silhouette")
	# Sample the first elastic rebound peak, rather than its later zero crossing.
	var elastic: Vector2 = ProceduralAnimator.landing_scale(0.115)
	_check(elastic.x < 1.0 and elastic.y > 1.0 and elastic.x > 0.8 and elastic.y < 1.2, "Landing elasticity overshoots once within a bounded cosmetic envelope")
	var animator := ProceduralAnimator.new()
	animator.advance_player(0.25, 320.0, 320.0, true)
	_check(animator.bob >= -2.5 and animator.bob <= 0.0 and animator.lean > deg_to_rad(5.0) and animator.lean <= deg_to_rad(8.0), "Running bob stays above the floor and lean approaches five to eight degrees")
	animator.advance_player(0.25, -320.0, 320.0, true)
	_check(animator.lean < -deg_to_rad(5.0), "A sudden direction reversal smoothly changes visual lean sign")
	animator.advance_player(0.5, 0.0, 320.0, false)
	_check(is_zero_approx(animator.bob) and absf(animator.lean) < 0.0001, "Stopping settles the visual offset without leftover drift")


func _test_player(rig: PlayerVisualRig) -> void:
	var body: CollisionShape2D = player.get_node("BodyCollision") as CollisionShape2D
	var hurt: CollisionShape2D = player.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D
	var physical: Transform2D = body.global_transform
	var hurt_transform: Transform2D = hurt.global_transform
	var weapon_transform: Transform2D = player.equipped_weapon.global_transform
	var shape_id: int = body.shape.get_instance_id()
	var foot: Vector2 = body.to_global(Vector2(0.0, body.shape.get_rect().end.y))
	player.velocity = Vector2.ZERO
	player.action_state_machine.transition_to(&"ready")
	player.locomotion_state_machine.transition_to(&"idle")
	rig.bind(player)
	rig.sync_from_player()
	var breath: Tween = rig.breath_tween
	breath.pause()
	breath.custom_step(0.6)
	_check(is_equal_approx(rig.concept_pivot.scale.y, 1.03) and is_equal_approx(rig.concept_pivot.scale.y * rig.concept_dynamics.scale.y, 1.035), "Composed Player breathing reaches 1.035 while preserving the existing 1.03 Tween")
	_check(rig.get_concept_foot_world().is_equal_approx(foot), "Idle expansion rotates and scales about the original physical foot pivot")
	player.locomotion_state_machine.transition_to(&"run")
	player.velocity.x = 320.0
	rig.sync_from_player(0.15)
	_check(rig.concept_dynamics.position.y < 0.0 and rig.concept_dynamics.rotation > 0.0 and rig.breath_tween == null, "Actual Run state reads velocity for lifted step and forward lean")
	_check(body.global_transform == physical and hurt.global_transform == hurt_transform and body.shape.get_instance_id() == shape_id and player.equipped_weapon.global_transform == weapon_transform, "Procedural motion cannot translate a collider, Hurtbox or WeaponSocket")
	var pose: Transform2D = rig.concept_dynamics.transform
	var motion_clock: float = rig.procedural.clock
	level.combat_feedback._frozen_this_tick = true
	rig.sync_from_player(0.25)
	_check(rig.concept_dynamics.transform == pose and rig.procedural.clock == motion_clock, "Local hit-stop freezes procedural bob and inertia on the same gameplay frame")
	level.combat_feedback.reset_feedback()
	player.velocity = Vector2.ZERO
	player.locomotion_state_machine.transition_to(&"idle")
	rig.bind(player)
	rig.sync_from_player()
	_check(rig.get_concept_foot_world().is_equal_approx(foot) and rig.concept_dynamics.rotation == 0.0, "Fresh bind restores grounded feet with no inherited lean")
	player.hurtbox.set_invulnerable(false)
	player.damage_grace_remaining = 0.0
	var result: DamageResult = player.hurtbox.take_damage(_damage(player.hurtbox, 3.0))
	_check(result.actual_damage == 3.0 and not bool(rig._concept_material.get_shader_parameter("active")) and float(rig._concept_material.get_shader_parameter("flash")) > 0.0 and float(rig._concept_material.get_shader_parameter("flash")) <= 0.25, "Real resolved Player damage enables bounded texture-preserving contact tint")
	level.combat_feedback._frozen_this_tick = true
	var remaining: float = rig._flash_remaining
	rig.sync_from_player(0.08)
	_check(rig._flash_remaining == remaining and not bool(rig._concept_material.get_shader_parameter("active")) and float(rig._concept_material.get_shader_parameter("flash")) > 0.0, "Bounded contact tint cannot expire while hit-stop holds its actor")
	level.combat_feedback.reset_feedback()
	rig.sync_from_player(0.081)
	_check(not bool(rig._concept_material.get_shader_parameter("active")) and is_zero_approx(float(rig._concept_material.get_shader_parameter("flash"))) and player.damage_grace_remaining > 0.0, "Bounded tint expires at0.08 seconds independently of the existing immunity window")
	var actor_id: int = rig._actor_id
	rig.bind(null)
	_check(rig._hurtbox_id == 0 and not player.hurtbox.hit_resolved.is_connected(rig._on_visual_hit) and actor_id != 0, "Unbind disconnects the damage adapter rather than retaining actor ownership")
	rig.bind(player)
	await _step(2)


func _test_shadow(shadow: ActorShadow) -> void:
	shadow.set_physics_process(false)
	var original: Vector2 = player.global_position
	shadow._physics_process(0.05)
	_check(shadow.has_ground and absf(shadow.ground_position.y - 640.0) < 1.0 and shadow.drop_height < 1.0, "Grounded shadow projects onto the actual World collider at the feet")
	var ground_width: float = shadow.ellipse_scale
	var ground_alpha: float = shadow.shadow_strength
	player.position.y -= 100.0
	shadow._physics_process(0.05)
	_check(shadow.drop_height > 99.0 and shadow.ellipse_scale < ground_width and shadow.shadow_strength < ground_alpha and absf(shadow.global_position.y - 639.5) < 1.0, "Airborne shadow stays on the floor while shrinking and fading with height")
	var count: int = shadow.projection_count
	var query_id: int = shadow._ray.get_instance_id()
	for tick: int in 120:
		shadow._physics_process(1.0 / 120.0)
	_check(shadow.projection_count - count <= 31 and shadow._ray.get_instance_id() == query_id and shadow._points.size() == 24, "Stationary projection reuses its query and ellipse with at most thirty ground casts per second")
	var airborne_position: Vector2 = player.position
	count = shadow.projection_count
	for tick: int in 120:
		player.position += Vector2(8.0, -2.0)
		shadow._physics_process(1.0 / 120.0)
	_check(shadow.projection_count - count <= 31, "Rapid dash and airborne displacement cannot exceed the thirty-Hz shadow ray budget")
	player.position = airborne_position
	shadow._physics_process(0.05)
	level.combat_feedback._frozen_this_tick = true
	var position: Vector2 = shadow.global_position
	count = shadow.projection_count
	shadow._physics_process(1.0)
	_check(shadow.global_position == position and shadow.projection_count == count, "Actor shadow stays frozen with the combat clock")
	level.combat_feedback.reset_feedback()
	player.position = original
	shadow._physics_process(0.05)
	_check(player.collision_mask == 1 and shadow._ray.collision_mask == 1 and not shadow._ray.collide_with_areas, "Cosmetic projection reads World only and never interacts with Hurtbox areas")
	shadow.set_physics_process(true)


func _test_slime() -> void:
	var slime: SlimeEnemy = level.enemies[0]
	var skin: SlimeSpriteSkin = slime.get_node("SlimeSpriteSkin") as SlimeSpriteSkin
	skin.set_physics_process(false)
	var body: CollisionShape2D = slime.get_node("BodyCollision") as CollisionShape2D
	var hurt: Transform2D = slime.hurtbox.global_transform
	var collision: Transform2D = body.global_transform
	var bite: Transform2D = slime.bite_hitbox.global_transform
	var shape_id: int = body.shape.get_instance_id()
	slime.state_machine.transition_to(&"attack")
	slime._state_time = 0.12
	skin._physics_process(0.0)
	_check(skin.motion.scale.is_equal_approx(Vector2(1.35, 0.65)) and not slime.bite_hitbox.active, "Slime visually squashes during the real bite telegraph without opening the hitbox")
	slime._state_time = slime.telegraph_seconds + 0.06
	skin._physics_process(0.0)
	_check(skin.motion.scale.is_equal_approx(Vector2(0.75, 1.3)) and skin.motion.position.y < -5.9 and slime.global_position.y == 640.0, "Existing horizontal bite receives a cosmetic hop without launching the physical body")
	_check(body.global_transform == collision and slime.hurtbox.global_transform == hurt and slime.bite_hitbox.global_transform == bite and body.shape.get_instance_id() == shape_id, "Every Slime pose leaves contact and damage geometry untouched")
	level.combat_feedback._frozen_this_tick = true
	var frozen: Transform2D = skin.motion.transform
	var clock: float = skin.clock
	skin._physics_process(0.20)
	_check(skin.motion.transform == frozen and skin.clock == clock, "Slime anticipation and hop clocks pause through local hit-stop")
	level.combat_feedback.reset_feedback()
	slime._state_time = slime.telegraph_seconds + 0.20
	skin._physics_process(0.0)
	_check(skin.motion.scale.is_equal_approx(Vector2(1.25, 0.75)) and is_zero_approx(skin.motion.position.y), "Bite recovery shows the authored landing squash on its original action clock")
	slime.reset_at_home()
	skin._physics_process(0.0)
	_check(skin.get_foot_world().is_equal_approx(slime.global_position) and skin.actor_shadow.get_parent() == skin and skin.sprite.get_parent() == skin.motion, "Slime reset restores its foot and keeps dynamics/shadow owned by the skin")
	skin.set_physics_process(true)


func _test_boss() -> void:
	var boss: BossGolem = BOSS_SCENE.instantiate()
	boss.ai_enabled = false
	boss.feedback = level.combat_feedback
	boss.position = Vector2(1180, 640)
	level.add_child(boss)
	await _step(3)
	var skin: BossGolemSkin = boss.get_node("GolemStoneSkin") as BossGolemSkin
	skin.set_physics_process(false)
	var body: CollisionShape2D = boss.get_node("Body") as CollisionShape2D
	var body_transform: Transform2D = body.global_transform
	var hurt_transform: Transform2D = boss.hurtbox.global_transform
	skin.clock = 0.9
	skin.refresh_skin()
	_check(is_equal_approx(skin.motion.scale.y, 1.035) and skin.get_foot_world().is_equal_approx(boss.global_position), "Idle Golem breathes upward while its hundred-pixel physical foot remains fixed")
	_check(body.global_transform == body_transform and boss.hurtbox.global_transform == hurt_transform and boss.health.maximum_health == 500.0 and skin.core_light.position.y < -58.0, "Boss breathing follows the chest light without modifying HP or damage geometry")
	level.combat_feedback._frozen_this_tick = true
	var clock: float = skin.clock
	skin._physics_process(0.5)
	_check(skin.clock == clock and skin.actor_shadow.get_parent() == skin, "Boss sprite and actor-owned shadow share the existing freeze and room lifetime")
	level.combat_feedback.reset_feedback()
	var shadow_id: int = skin.actor_shadow.get_instance_id()
	boss.queue_free()
	await _step(3)
	_check(not is_instance_id_valid(shadow_id), "Boss despawn releases its projected shadow immediately with the actor")


func _test_lifetimes() -> void:
	await _step(40)
	var fixture := Node2D.new()
	root.add_child(fixture)
	var object_before: int = 0
	var resources_before: int = 0
	var shadows_released: bool = true
	for cycle: int in 8:
		var temporary_player: Player = PLAYER_SCENE.instantiate()
		temporary_player.controls_enabled = false
		fixture.add_child(temporary_player)
		temporary_player.set_physics_process(false)
		var temporary_slime: SlimeEnemy = SLIME_SCENE.instantiate()
		temporary_slime.ai_enabled = false
		fixture.add_child(temporary_slime)
		var slime_skin := SlimeSpriteSkin.new()
		temporary_slime.add_child(slime_skin)
		var temporary_boss: BossGolem = BOSS_SCENE.instantiate()
		temporary_boss.ai_enabled = false
		fixture.add_child(temporary_boss)
		var boss_skin := BossGolemSkin.new()
		temporary_boss.add_child(boss_skin)
		var temporary_rig: PlayerVisualRig = temporary_player.get_node("Visuals") as PlayerVisualRig
		var ids: Array[int] = [temporary_rig.actor_shadow.get_instance_id(), slime_skin.actor_shadow.get_instance_id(), boss_skin.actor_shadow.get_instance_id()]
		temporary_player.queue_free()
		temporary_slime.queue_free()
		temporary_boss.queue_free()
		await _step(4)
		for instance_id: int in ids:
			shadows_released = shadows_released and not is_instance_id_valid(instance_id)
		if cycle == 1:
			object_before = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			resources_before = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var object_after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_after: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	print("STRESS: procedural actors objects=%d->%d resources=%d->%d" % [object_before, object_after, resources_before, resources_after])
	_check(shadows_released, "Eight mixed actor lifecycles leave no projected shadow nodes alive")
	_check(object_after <= object_before and resources_after <= resources_before, "Repeated procedural skins release native geometry, flash materials and local pose state")
	fixture.queue_free()
	await _step(3)

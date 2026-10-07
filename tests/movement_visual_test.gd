extends "res://tests/survival_test_base.gd"
## Actual approved parts, equipment and input path; cosmetic nodes never own motion.

func _initialize() -> void:
	suite = "movement_visual"
	use_neutral_equipment = false
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	for enemy: SlimeEnemy in level.enemies:
		enemy.contact_damage_enabled = false
	player.energy.enabled = false
	var rig: PlayerVisualRig = player.get_node("Visuals")
	var vfx: MovementVFX = level.presentation.movement_vfx
	var body: CollisionShape2D = player.get_node("BodyCollision")
	var body_shape: Shape2D = body.shape
	var body_transform: Transform2D = body.transform
	var hurt_shape: Shape2D = player.hurtbox.get_node("CollisionShape2D").shape
	var socket: Transform2D = player.equipped_weapon.get_parent().transform
	_check(vfx.get_parent() == level.presentation and vfx.ghosts.get_parent() == vfx, "Movement pictures belong to the room presentation, outside physics and hitboxes")
	_check([MovementVFX.DUST, MovementVFX.TAKEOFF, MovementVFX.LANDING, MovementVFX.WIND].all(func(texture: Texture2D) -> bool: return texture is AtlasTexture and texture.get_width() > 100), "Movement uses four separate regions from the approved transparent production atlas")
	player.set_physics_process(false)
	rig.set_physics_process(false)
	vfx.set_physics_process(false)
	player.action_state_machine.transition_to(&"ready")
	player.locomotion_state_machine.transition_to(&"run")
	player.velocity.x = player.motor.run_speed
	_aim(player.global_position + Vector2(250.0, -25.0))
	for frame: int in 20:
		rig.sync_from_player(1.0 / Engine.physics_ticks_per_second)
	var hair: Sprite2D = rig._modular_base[1]
	var sash: Sprite2D = rig._modular_equipment[&"armor"][1]
	_check(hair.rotation != 0.0 and sash.rotation != 0.0 and not is_equal_approx(hair.rotation, sash.rotation), "Hair and cloth sash each lag the running body with separate bounded angles")
	_check(absf(hair.rotation) <= 0.16 and absf(sash.rotation) <= 0.26 and hair.get_parent() is Bone2D and sash.get_parent() is Bone2D, "Secondary motion turns only mounted sprites around their authored bone pivots")
	var hair_angle: float = hair.rotation
	var sash_angle: float = sash.rotation
	level.combat_feedback._frozen_this_tick = true
	rig.sync_from_player(1.0)
	_check(hair.rotation == hair_angle and sash.rotation == sash_angle, "Hit-stop pauses both independent secondary clocks")
	level.combat_feedback.reset_feedback()
	player.locomotion_state_machine.transition_to(&"idle")
	player.velocity = Vector2.ZERO
	var foot: Vector2 = rig.get_modular_foot_world()
	rig._seek(&"land", 0.06)
	_check(rig.skeleton.scale.y < rig.modular_skin.visual_scale and absf(rig.skeleton.scale.x) > rig.modular_skin.visual_scale, "Landing compresses the whole drawing briefly with a slight horizontal spread")
	_check(rig.get_modular_foot_world().distance_to(foot) < 0.001 and body.transform == body_transform, "Landing squash preserves the authored contact anchor and physical collider")
	var first_compression: Transform2D = rig.skeleton.transform
	rig._seek(&"land", 0.06)
	_check(rig.skeleton.transform.is_equal_approx(first_compression), "Repeated manual seeks do not accumulate compression or move the rig")
	var compressed_world: Transform2D = rig.skeleton.global_transform
	var compressed_bounds: Rect2 = rig.get_modular_visual_bounds()
	level.combat_feedback._frozen_this_tick = true
	rig.sync_from_player(0.5)
	_check(rig.skeleton.global_transform.is_equal_approx(compressed_world) and rig.get_modular_visual_bounds().is_equal_approx(compressed_bounds), "Hit-stop keeps the complete landing squash transform and drawn bounds exactly fixed")
	level.combat_feedback.reset_feedback()
	rig._seek(&"idle", 0.0)
	_check(rig.skeleton.scale.y == rig.modular_skin.visual_scale, "The next ordinary pose restores the exact authored scale")
	await _test_reaction_clocks(rig)
	level.gear.equipment_visual.refresh_pose()
	var image: Node2D = vfx.spawn_afterimage(player)
	_check(image.get_child_count() == rig.get_mounted_part_sprites().size() + 1 and image.has_node("HeldWeapon"), "A dash snapshot contains every worn/body part plus the actual held sword")
	var sword: Sprite2D = image.get_node("HeldWeapon")
	_check(sword.texture == level.gear.equipment_visual.weapon_sprite.texture and sword.global_transform.is_equal_approx(level.gear.equipment_visual.weapon_sprite.global_transform), "Weapon afterimage uses the current texture and hand transform without another attack clock")
	var first_part: Sprite2D = image.get_child(0)
	var saved_transform: Transform2D = first_part.global_transform
	var original_texture: Texture2D = first_part.texture
	rig._seek(&"run", 0.25)
	_check(first_part.global_transform.is_equal_approx(saved_transform) and first_part.texture == original_texture, "Snapshots stay fixed in world space after the live limbs move")
	_check(image.find_children("*", "CollisionObject2D", true, false).is_empty() and image.find_children("*", "Light2D", true, false).is_empty(), "Afterimages contain no physics, damaging hitboxes or additional light passes")
	vfx.clear()
	player.reset_movement_at(Vector2(780, 640))
	player.set_physics_process(true)
	rig.set_physics_process(true)
	vfx.set_physics_process(true)
	await _step(10)
	var ghost_before: int = vfx.ghost_count
	var smoke_before: int = level.presentation.foot_dust_count
	Input.action_press(&"dash")
	await _step(1)
	Input.action_release(&"dash")
	await _time(0.19)
	_check(vfx.ghost_count == ghost_before + 5 and vfx.wind_count == 1, "Real dash input produces five finite afterimages and one wind streak at both tick rates")
	_check(vfx.ghosts.get_child_count() <= 5 and level.presentation.foot_dust_count == smoke_before + 1, "New dash visuals retain the five-ghost cap and the original single foot puff cadence")
	await _time(0.3)
	_check(vfx.ghosts.get_child_count() == 0 and vfx.marks.get_child_count() == 0, "Dash pictures retire independently of GPU completion within their finite lifetimes")
	player.reset_movement_at(Vector2(780, 640))
	vfx.clear()
	await _step(5)
	Input.action_press(&"jump")
	await _step(2)
	Input.action_release(&"jump")
	await _time(0.8)
	_check(vfx.takeoff_count == 1 and vfx.landing_count == 1 and player.motor.is_grounded(), "Real short jump emits one takeoff ring and one floor landing wave")
	var marks_before: int = vfx.landing_count + vfx.takeoff_count
	await _time(0.25)
	_check(vfx.landing_count + vfx.takeoff_count == marks_before, "Standing on the floor never repeats the jump/landing marks")
	var skid_before: int = vfx.skid_count
	Input.action_press(&"move_right")
	await _time(0.4)
	Input.action_release(&"move_right")
	await _time(0.15)
	_check(vfx.skid_count == skid_before + 1 and absf(player.velocity.x) < 1.0, "Sustained real run followed by braking produces one finite skid dust emitter")
	await _time(0.3)
	_check(vfx.skid_count == skid_before + 1, "Resting after the skid does not repeat the braking puff")
	var heavy_before: int = vfx.heavy_landing_count
	var camera: PlayerCamera = player.get_node("Camera2D")
	camera.reset_shake()
	player.relocate(Vector2(780, 280))
	vfx.clear()
	await _time(0.8)
	_check(player.motor.is_grounded() and vfx.heavy_landing_count == heavy_before + 1, "A genuine long fall triggers exactly one bounded landing camera impulse")
	player.set_physics_process(false)
	rig.set_physics_process(false)
	vfx.set_physics_process(false)
	await _test_budgets(vfx)
	_check(body.shape == body_shape and body.transform == body_transform and player.hurtbox.get_node("CollisionShape2D").shape == hurt_shape and player.equipped_weapon.get_parent().transform == socket, "All movement, ghost, compression and reaction pictures preserve body/Hurtbox/WeaponSocket data")
	player.set_physics_process(true)
	rig.set_physics_process(true)
	vfx.set_physics_process(true)


func _test_reaction_clocks(rig: PlayerVisualRig) -> void:
	var reaction: HitReactionComponent = player.get_node("HitReaction")
	for pose: StringName in [&"flinch", &"knockback", &"kneel", &"thrown"]:
		player.action_state_machine.transition_to(&"ready")
		player.hurtbox.set_invulnerable(false)
		player.damage_grace_remaining = 0.0
		var event: DamageEvent = _damage(player.hurtbox, 1.0)
		event.hit_reaction = pose
		var result: DamageResult = player.hurtbox.take_damage(event)
		reaction.physics_tick(0.06)
		rig.sync_from_player(0.0)
		_check(result.actual_damage > 0.0 and rig.displayed_animation == StringName("reaction_" + String(pose)) and rig.displayed_time == reaction.pose_time, "%s pose reads the actual resolved hit reaction clock" % pose)
		if pose == &"thrown":
			# The real component progresses air -> down -> get_up on floor contact.
			player.velocity = Vector2.ZERO
			reaction.physics_tick(0.1)
			reaction.physics_tick(HitReactionComponent.DOWN_SECONDS + 0.001)
			rig.sync_from_player(0.0)
			_check(reaction.pose_id == &"get_up" and rig.displayed_animation == &"reaction_get_up" and rig.displayed_time == reaction.pose_time, "Thrown floor recovery displays the real get-up clock without a second visual timer")
			var first: float = (rig.get_node("Skeleton2D/Root") as Bone2D).rotation
			reaction.physics_tick(HitReactionComponent.GET_UP_SECONDS * 0.5)
			rig.sync_from_player(0.0)
			_check(absf((rig.get_node("Skeleton2D/Root") as Bone2D).rotation) < absf(first), "The get-up drawing rises smoothly while the recovery clock advances")
		reaction.clear()
	player.action_state_machine.transition_to(&"ready")
	rig._hurt_pose_remaining = 0.0
	player.damage_grace_remaining = 0.0
	player.hurtbox.set_invulnerable(false)
	player.velocity = Vector2.ZERO
	rig.sync_from_player(0.0)


func _test_budgets(vfx: MovementVFX) -> void:
	vfx.clear()
	for sample: int in 12:
		vfx.spawn_afterimage(player)
		vfx.spawn_mark(MovementVFX.WIND, player.global_position, 0.1, 0.2, 0.3)
	_check(vfx.ghosts.get_child_count() == 5 and vfx.marks.get_child_count() == 8 and vfx._lifetimes.size() == 13, "Spam prunes both finite pools and their lifetime registries together")
	vfx.advance_lifetimes(0.3)
	await _step(3)
	_check(vfx.ghosts.get_child_count() == 0 and vfx.marks.get_child_count() == 0 and vfx._lifetimes.is_empty(), "Expired movement effects free snapshots and clear weak lifetime entries")
	var objects_before: int = 0
	var resources_before: int = 0
	for cycle: int in 8:
		for sample: int in 6:
			vfx.spawn_afterimage(player)
			vfx.spawn_skid(player.global_position, Vector2.RIGHT)
		vfx.clear()
		await _step(3)
		if cycle == 1:
			objects_before = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			resources_before = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var objects_after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_after: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	print("STRESS: movement presentation objects=%d->%d resources=%d->%d" % [objects_before, objects_after, resources_before, resources_after])
	_check(objects_after <= objects_before and resources_after <= resources_before and vfx._lifetimes.is_empty(), "Eight mixed ghost/particle rebuild cycles release native materials and all room effects")


func _aim(target: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = player.get_canvas_transform() * target
	Input.parse_input_event(event)
	player.aim.sample_cursor()

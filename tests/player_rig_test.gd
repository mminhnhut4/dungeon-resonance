extends "res://tests/survival_test_base.gd"

const RIG_SCENE: PackedScene = preload("res://scenes/actors/player_visual_rig.tscn")


func _initialize() -> void:
	suite = "player_rig"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.energy.enabled = false
	var empty: Node2D = RIG_SCENE.instantiate()
	root.add_child(empty)
	await _step(2)
	var skeleton: Skeleton2D = empty.get_node("Skeleton2D") as Skeleton2D
	_check(skeleton.get_bone_count() == 14, "Modular skeleton registers fourteen hierarchical bones")
	var authored_bones: bool = true
	for index: int in range(skeleton.get_bone_count()):
		var bone: Bone2D = skeleton.get_bone(index)
		authored_bones = authored_bones and not bone.get_autocalculate_length_and_angle() and bone.get_length() > 0.0 and not is_zero_approx(bone.rest.determinant())
	_check(authored_bones, "Every bone has an explicit non-singular rest pose and finite authored length")
	_check(empty._sprites.size() == 18 and empty._sprites.values().all(func(sprite: Sprite2D) -> bool: return sprite.texture == null), "Standalone rig has eighteen empty independent PNG slots")
	var clips := PackedStringArray(["idle", "run", "attack_slash_1", "attack_slash_2", "cast_spell"])
	var safe_tracks: bool = true
	for clip: String in clips:
		var animation: Animation = empty.animation_player.get_animation(clip)
		safe_tracks = safe_tracks and animation != null and animation.get_track_count() >= 4
		for index: int in range(animation.get_track_count()):
			safe_tracks = safe_tracks and animation.track_get_type(index) == Animation.TYPE_VALUE and String(animation.track_get_path(index)).begins_with("Skeleton2D/")
	_check(safe_tracks, "Five authored clips animate visual bones only, with no method, damage or physics tracks")
	_check(empty.animation_player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "Animation clock is manual and cannot drift from the weapon timeline")
	empty._seek(&"idle", 0.6)
	var torso: Bone2D = empty.get_node("Skeleton2D/Root/Hip/Torso") as Bone2D
	_check(torso.scale.y > 1.02, "Idle clip visibly expands the torso for breathing")
	empty._seek(&"run", 0.0)
	var left_leg: Bone2D = empty.get_node("Skeleton2D/Root/Hip/Leg.L") as Bone2D
	var right_leg: Bone2D = empty.get_node("Skeleton2D/Root/Hip/Leg.R") as Bone2D
	var left_arm: Bone2D = empty.get_node("Skeleton2D/Root/Hip/Torso/Shoulder.L/Arm.L") as Bone2D
	var right_arm: Bone2D = empty.get_node("Skeleton2D/Root/Hip/Torso/Shoulder.R/Arm.R") as Bone2D
	_check(left_leg.rotation * right_leg.rotation < 0.0 and left_arm.rotation * right_arm.rotation < 0.0 and torso.rotation > 0.0, "Run clip alternates arms and legs while leaning the torso")
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture: Texture2D = ImageTexture.create_from_image(image)
	_check(empty.equip(&"mask", texture) and empty.get_slot_sprite(&"mask").texture == texture and empty.body_sprite.texture == null, "Equipping a mask changes its own sprite without altering the body")
	_check(not empty.equip(&"../Combat/WeaponSocket", texture) and empty.get_slot_sprite(&"missing") == null, "Slot whitelist rejects paths into gameplay nodes")
	_check(empty.equip(&"mask", null) and empty.get_slot_sprite(&"mask").texture == null, "Unequipping releases the modular texture")
	var other: Node2D = RIG_SCENE.instantiate()
	root.add_child(other)
	empty.equip(&"hair", texture)
	_check(other.get_slot_sprite(&"hair").texture == null, "Two rig instances do not share mutable equipment assignments")
	other.queue_free()
	empty.queue_free()
	await _step(3)
	var rig: Node2D = player.get_node("Visuals") as Node2D
	_check(rig.get_script() == preload("res://scripts/presentation/player_visual_rig.gd") and player.body_sprite == rig.body_sprite, "Live Player uses the visual rig's torso sprite for existing feedback")
	_check(rig.body_sprite.texture != null, "Live Player retains a PNG fallback while standalone rig remains empty")
	_check(not rig.is_ancestor_of(player.equipped_weapon) and player.equipped_weapon.get_parent().name == &"WeaponSocket", "Gameplay Weapon and Hitbox keep their independent physics hierarchy")
	rig.set_physics_process(false)
	rig.set_modular_skin(null) # Explicit historical PNG/14-bone fixture; assertions stay intact.
	player.set_physics_process(false)
	player.controls_enabled = false
	level.dummy_a.position = Vector2(-2000, 640)
	level.dummy_b.position = Vector2(-2100, 640)
	var collision: CollisionShape2D = player.get_node("BodyCollision") as CollisionShape2D
	var hurt_shape: CollisionShape2D = player.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D
	var body_transform: Transform2D = collision.global_transform
	var hurt_transform: Transform2D = hurt_shape.global_transform
	var body_shape: Shape2D = collision.shape
	var physics_origin: Vector2 = player.equipped_weapon.global_position
	var health_before: float = player.health.current_health
	var energy_before: float = player.energy.current
	player.facing_direction = -1.0
	_aim(player.global_position + Vector2(-250, -40))
	player.damage_grace_remaining = 0.5
	player._update_visuals()
	rig.sync_from_player(0.0)
	var head_sprite: Sprite2D = rig.get_slot_sprite(&"head")
	_check(head_sprite.modulate == player.body_sprite.modulate and player.body_sprite.modulate.r == 1.0 and player.body_sprite.modulate.g < 0.5, "Existing damage flash propagates to modular body parts")
	_check(player.body_sprite.flip_h and rig.skeleton.scale.x < 0.0 and player.body_sprite.scale.x < 0.0, "Mouse-left mirroring preserves controller-owned flip_h and compensates its local reflection")
	_check(player.body_sprite.global_transform.x.x * (-1.0 if player.body_sprite.flip_h else 1.0) < 0.0, "Fallback artwork faces left once instead of being mirrored twice")
	player.damage_grace_remaining = 0.0
	player._update_visuals()
	player.locomotion_state_machine.transition_to(&"run")
	rig.sync_from_player(0.15)
	_check(rig.displayed_animation == &"run" and is_equal_approx(rig.displayed_time, 0.15), "Locomotion bridge reads Run FSM and advances only the cosmetic cycle")
	player.locomotion_state_machine.transition_to(&"idle")
	rig.sync_from_player(0.2)
	_check(rig.displayed_animation == &"idle" and is_equal_approx(rig.displayed_time, 0.2), "Returning to Idle resets its own visual cycle")
	var weapon: Weapon = player.equipped_weapon
	for weapon_id: StringName in ContentSession.WEAPON_IDS:
		player.action_state_machine.transition_to(&"ready")
		weapon.equip(load("res://data/weapons/%s.tres" % weapon_id))
		_aim(player.aim.global_position + Vector2(250, -180))
		player.action_state_machine.transition_to(&"attack")
		var direction: Vector2 = weapon.snapshot.attack_direction
		var step: AttackStepDefinition = weapon.definition.combo_steps[0]
		weapon.advance(step.windup_seconds * 0.5)
		rig.sync_from_player(0.0)
		_check(rig.displayed_animation == &"attack_slash_1" and is_equal_approx(rig.displayed_time, 0.1) and not weapon.hitbox.active, "%s wind-up seeks the first half without opening a hitbox" % weapon_id)
		weapon.advance(step.windup_seconds * 0.5 + step.active_seconds * 0.25)
		var hit_transform: Transform2D = weapon.hitbox.global_transform
		var hit_shape: Shape2D = weapon.hitbox._query_shape
		rig.sync_from_player(0.0)
		var expected_active: bool = weapon.definition.attack_kind == &"melee"
		_check(is_equal_approx(rig.displayed_time, 0.225) and weapon.hitbox.active == expected_active, "%s active pose follows its authored hit timing" % weapon_id)
		_check(weapon.hitbox.global_transform.is_equal_approx(hit_transform) and weapon.hitbox._query_shape == hit_shape, "%s bone pose leaves the active hitbox transform and shape untouched" % weapon_id)
		_aim(player.aim.global_position + Vector2(-250, 180))
		rig.sync_from_player(0.0)
		_check(rig.committed_direction.is_equal_approx(direction) and weapon.snapshot.attack_direction.is_equal_approx(direction) and is_equal_approx(weapon.global_rotation, direction.angle()), "%s visuals keep committed 360-degree aim when the pointer moves" % weapon_id)
		weapon.advance(step.active_seconds * 0.75 + step.recovery_seconds * 0.5)
		rig.sync_from_player(0.0)
		_check(is_equal_approx(rig.displayed_time, 0.45) and not weapon.hitbox.active, "%s recovery pose cannot reopen the ended hit window" % weapon_id)
	weapon._begin_step(1)
	weapon.advance(weapon.definition.combo_steps[1].windup_seconds * 0.5)
	rig.sync_from_player(0.0)
	_check(rig.displayed_animation == &"attack_slash_2" and is_equal_approx(rig.displayed_time, 0.1), "Second combo step uses the alternate authored slash")
	var frozen_time: float = rig.displayed_time
	level.combat_feedback._frozen_this_tick = true
	rig.sync_from_player(0.2)
	_check(rig.displayed_time == frozen_time, "Hit-stop freezes the visual timeline with the existing feedback clock")
	level.combat_feedback.reset_feedback()
	player.action_state_machine.transition_to(&"ready")
	player.resonance_controller.reset_runtime()
	_aim(player.aim.global_position + Vector2(-200, -230))
	player.action_state_machine.transition_to(&"cast_spell")
	var cast: PlayerCastState = player.action_state_machine.current_state as PlayerCastState
	var committed_cast: Vector2 = cast.payload.direction
	cast.physics_update(cast.payload.windup * 0.5)
	rig.sync_from_player(0.0)
	_check(rig.displayed_animation == &"cast_spell" and is_equal_approx(rig.displayed_time, 0.1) and not cast._launched, "Spell wind-up seeks its pose before projectile launch")
	_aim(player.aim.global_position + Vector2(200, 230))
	rig.sync_from_player(0.0)
	_check(rig.committed_direction.is_equal_approx(committed_cast), "Casting aim follows the committed payload rather than a moving pointer")
	cast.physics_update(cast.payload.windup * 0.5)
	rig.sync_from_player(0.0)
	_check(cast._launched and is_equal_approx(rig.displayed_time, 0.2), "Projectile launch lands on the cast release pose exactly")
	cast.physics_update(cast.payload.recovery * 0.5)
	rig.sync_from_player(0.0)
	_check(is_equal_approx(rig.displayed_time, 0.35), "Cast recovery retains the authoritative action timer")
	_check(collision.global_transform.is_equal_approx(body_transform) and hurt_shape.global_transform.is_equal_approx(hurt_transform) and collision.shape == body_shape and weapon.global_position.is_equal_approx(physics_origin), "Bone animation cannot move body collision, hurtbox or physics weapon origin")
	_check(player.health.current_health == health_before and player.energy.current == energy_before, "Visual pose updates cannot mutate HP or energy")
	player.action_state_machine.transition_to(&"ready")
	rig.bind(null)
	var actor_before: Vector2 = player.global_position
	rig.sync_from_player(1.0)
	_check(player.global_position == actor_before and rig._actor_id == 0, "Unbinding drops the actor identity without changing gameplay")
	await _step(30)
	var objects_before: int = 0
	var resources_before: int = 0
	for cycle: int in range(8):
		var disposable: Node2D = RIG_SCENE.instantiate()
		root.add_child(disposable)
		disposable.bind(player)
		disposable.equip(&"hair", texture)
		disposable.sync_from_player(0.1)
		disposable.queue_free()
		await _step(2)
		if cycle == 1:
			objects_before = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			resources_before = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	_check(root.get_children().filter(func(node: Node) -> bool: return node.get_script() == preload("res://scripts/presentation/player_visual_rig.gd")).is_empty(), "Eight standalone rig lifecycles release all transient nodes and bindings")
	var objects_after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_after: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	print("STRESS: visual rig objects=%d->%d resources=%d->%d" % [objects_before, objects_after, resources_before, resources_after])
	_check(objects_after <= objects_before and resources_after <= resources_before, "Repeated rig churn has no object or Resource growth after warm-up")
	rig.bind(player)
	rig.set_physics_process(true)
	player.controls_enabled = true
	player.set_physics_process(true)


func _aim(location: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_canvas_transform() * location
	root.push_input(motion, true)
	player.aim.sample_cursor()

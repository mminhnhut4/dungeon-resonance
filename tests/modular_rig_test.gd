extends "res://tests/survival_test_base.gd"
## Generated rectangles are test fixtures only. No unapproved art enters gameplay.

const RIG_SCENE: PackedScene = preload("res://scenes/actors/player_visual_rig.tscn")


func _initialize() -> void:
	suite = "modular_rig"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.set_physics_process(false)
	player.controls_enabled = false
	var rig: PlayerVisualRig = player.get_node("Visuals") as PlayerVisualRig
	rig.set_physics_process(false)
	rig.set_modular_skin(null) # Exercise opt-in and fallback against the same live actor.
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.6, 0.6, 1.0))
	var texture: Texture2D = ImageTexture.create_from_image(image)
	var skin := ModularCharacterSkin.new()
	skin.id = &"test_only_cutout"
	skin.visual_scale = 1.25
	for slot: StringName in [&"head", &"hair", &"torso", &"hip", &"upper_arm_right", &"forearm_right", &"hand_right", &"thigh_left", &"thigh_right", &"shin_left", &"shin_right", &"foot_left", &"foot_right"]:
		skin.parts.append(_part(slot, slot, texture))
	var body: CollisionShape2D = player.get_node("BodyCollision") as CollisionShape2D
	var hurt: CollisionShape2D = player.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D
	var original_body: Transform2D = body.global_transform
	var original_hurt: Transform2D = hurt.global_transform
	var body_shape: Shape2D = body.shape
	var hurt_shape: Shape2D = hurt.shape
	var weapon_origin: Vector2 = player.equipped_weapon.global_position
	var hp: float = player.health.current_health
	var energy: float = player.energy.current
	var bone_count: int = rig.skeleton.get_bone_count()
	_check(not rig.is_modular_active() and bone_count == 14, "Unapproved cutout skin is opt-in; live Player keeps its confirmed artwork")
	_check(rig.set_modular_skin(skin) and rig.is_modular_active(), "Validated body parts mount as a real cutout skeleton")
	await _step(2)
	_check(rig.skeleton.get_bone_count() == 18 and rig._sprites.size() == 18, "Knees and ankles extend only the cutout instance while legacy eighteen slots stay intact")
	_check(rig._modular_base.size() == skin.parts.size() and not rig.concept_sprite.visible and not rig.body_sprite.visible and rig.body_sprite.self_modulate.a == 0.0, "Separated parts replace the full concept visually without revealing the feedback rectangle")
	var torso: Sprite2D = rig._modular_base[2]
	_check(torso.get_parent() == rig.get_modular_bone(&"torso") and torso.offset == -skin.parts[2].pivot_pixels and torso.scale == skin.parts[2].display_scale, "Each PNG pixel pivot lands on its own bone using immutable author data")
	_check(rig.get_modular_bone(&"shin_right").get_parent() == rig.get_modular_bone(&"thigh_right") and rig.get_modular_bone(&"foot_right").get_parent() == rig.get_modular_bone(&"shin_right"), "Thigh, shin and foot form an articulated leg rather than one rotating sticker")
	_check(rig.get_modular_bone(&"forearm_right").get_parent() == rig.get_modular_bone(&"upper_arm_right") and rig.get_modular_bone(&"hand_right").get_parent() == rig.get_modular_bone(&"forearm_right"), "Upper arm, forearm and hand retain independent elbow and wrist pivots")
	rig.bind(player)
	player.action_state_machine.transition_to(&"ready")
	player.locomotion_state_machine.transition_to(&"idle")
	_aim(player.global_position + Vector2(250, -20))
	rig.sync_from_player(0.0)
	var foot_world: Vector2 = body.to_global(Vector2(0.0, body.shape.get_rect().end.y))
	_check(rig.get_modular_foot_world().is_equal_approx(foot_world), "Cutout scale anchors its authored foot contact to the existing body collision floor")
	rig._seek(&"idle", 0.0)
	var idle_ankle: Transform2D = rig.get_modular_bone(&"foot_right").global_transform
	rig._seek(&"idle", 0.6)
	_check(rig.get_modular_bone(&"foot_right").global_transform.is_equal_approx(idle_ankle) and (rig.get_modular_bone(&"torso") as Bone2D).scale.y > 1.02, "Cutout idle breath expands the torso while ankle contact stays fixed")
	var overlay: Array[ModularCharacterPart] = [_part(&"shirt", &"torso", texture), _part(&"sleeve", &"upper_arm_right", texture)]
	_check(rig.set_equipment_parts(&"armor", overlay) and rig._modular_equipment[&"armor"].size() == 2, "One shirt can attach body and sleeve pieces to different moving joints")
	var shirt: Sprite2D = rig._modular_equipment[&"armor"][0]
	var sleeve: Sprite2D = rig._modular_equipment[&"armor"][1]
	_check(shirt.get_parent() == rig.get_modular_bone(&"torso") and sleeve.get_parent() == rig.get_modular_bone(&"upper_arm_right"), "Clothing follows each body joint instead of duplicating the full body overlay")
	var bad := _part(&"bad", &"../../Combat/WeaponSocket", texture)
	var invalid: Array[ModularCharacterPart] = [bad]
	_check(not rig.set_equipment_parts(&"armor", invalid) and rig._modular_equipment[&"armor"][0] == shirt, "Invalid attachment path rejects atomically without removing the worn shirt")
	_check(not rig.set_equipment_parts(&"unknown", overlay), "Equipment attachment whitelist excludes arbitrary scene branches")
	var duplicate: Array[ModularCharacterPart] = [overlay[0], overlay[0]]
	_check(not rig.set_equipment_parts(&"armor", duplicate), "Duplicate part IDs cannot mount a garment twice")
	var empty_skin := ModularCharacterSkin.new()
	empty_skin.id = &"empty"
	_check(not rig.set_modular_skin(empty_skin) and rig.modular_skin == skin, "Empty skin cannot hide the player or erase the current valid body")
	var glove: Array[ModularCharacterPart] = [_part(&"glove", &"hand_right", texture)]
	_check(rig.set_equipment_parts(&"gloves", glove), "Glove attaches to the real visual wrist")
	var weapon_socket: Node2D = player.get_node("Combat/WeaponSocket") as Node2D
	_check(rig.get_hand_world_position().is_equal_approx(rig.get_modular_bone(&"hand_right").global_position) and not rig.is_ancestor_of(weapon_socket), "Cosmetic hand socket exposes the current pose while gameplay WeaponSocket remains independent")
	var right_position: Vector2 = rig.get_hand_world_position()
	_aim(player.global_position + Vector2(-250, -20))
	rig.sync_from_player(0.0)
	_check(rig.skeleton.scale.x == -1.25 and rig.skeleton.scale.y == 1.25 and rig.get_hand_world_position().x < player.global_position.x and right_position.x > player.global_position.x, "Mouse mirror reflects separated hands once and preserves authored cutout scale")
	_check(rig.get_modular_foot_world().is_equal_approx(foot_world), "Mouse mirroring does not shift the foot contact")
	var hand_before: Vector2 = rig.get_hand_world_position()
	player.locomotion_state_machine.transition_to(&"run")
	player.velocity.x = 320.0
	rig.sync_from_player(0.15)
	_check(rig.displayed_animation == &"run" and rig.get_modular_bone(&"shin_left").rotation > 0.7 and is_zero_approx(rig.get_modular_bone(&"shin_right").rotation), "Run bends alternating knees on the same manually sought cycle")
	_check(not rig.get_hand_world_position().is_equal_approx(hand_before) and shirt.global_transform == torso.global_transform, "Arm swing moves the hand while shirt and body retain the same joint transform")
	var knee_before: float = rig.get_modular_bone(&"shin_left").rotation
	level.combat_feedback._frozen_this_tick = true
	var clock: float = rig.displayed_time
	rig.sync_from_player(0.2)
	_check(rig.displayed_time == clock and rig.get_modular_bone(&"shin_left").rotation == knee_before, "Hit-stop freezes separate knee and elbow poses with the authoritative clock")
	level.combat_feedback.reset_feedback()
	player.locomotion_state_machine.transition_to(&"jump")
	rig.sync_from_player(0.05)
	_check(rig.displayed_animation == &"jump" and rig.get_modular_bone(&"shin_left").rotation > 0.7, "Ascending jump has an explicit tucked-leg pose")
	player.locomotion_state_machine.transition_to(&"fall")
	rig.sync_from_player(0.05)
	_check(rig.displayed_animation == &"fall" and rig.get_modular_bone(&"shin_left").rotation < 0.3, "Falling switches to a distinct extended-leg pose")
	player.locomotion_state_machine.transition_to(&"idle")
	rig.sync_from_player(0.0)
	_check(rig.displayed_animation == &"land" and rig._land_remaining == 0.18, "Air-to-ground transition starts one finite landing compression")
	rig.sync_from_player(0.06)
	_check(rig.get_modular_bone(&"shin_right").rotation > 0.25, "Landing bends both knees during its authored contact beat")
	rig.sync_from_player(0.13)
	_check(rig.displayed_animation == &"idle" and rig._land_remaining == 0.0, "Landing recovers without asynchronous callbacks or repeated retrigger")
	_check(player.health.current_health == hp and player.energy.current == energy, "Presentation consumes no HP, mana or movement resources")
	player.action_state_machine.transition_to(&"dash")
	player.motor.dash_remaining = player.motor.dash_duration * 0.5
	rig.sync_from_player(0.0)
	_check(rig.displayed_animation == &"dash" and is_equal_approx(rig.displayed_time, 0.08), "Dash anticipation follows the motor's remaining action time")
	player.action_state_machine.transition_to(&"ready")
	player.velocity = Vector2.ZERO
	var damage: DamageEvent = _damage(player.hurtbox, 3.0)
	rig._on_visual_hit(damage, DamageResult.new())
	_check(rig._hurt_pose_remaining == 0.0, "Blocked or zero-damage events cannot trigger a false hurt pose")
	player.hurtbox.set_invulnerable(false)
	player.damage_grace_remaining = 0.0
	var damage_result: DamageResult = player.hurtbox.take_damage(damage)
	rig.sync_from_player(0.04)
	_check(damage_result.actual_damage == 3.0 and rig.displayed_animation == &"hurt" and not bool(rig._modular_material.get_shader_parameter("active")) and float(rig._modular_material.get_shader_parameter("flash")) > 0.0 and float(rig._modular_material.get_shader_parameter("flash")) <= 0.25, "Real Hurtbox damage signal starts finite flinch and bounded texture-preserving part tint")
	level.combat_feedback._frozen_this_tick = true
	var hurt_clock: float = rig._hurt_pose_remaining
	rig.sync_from_player(0.5)
	_check(rig._hurt_pose_remaining == hurt_clock, "Hurt reaction cannot expire while the combat frame is frozen")
	level.combat_feedback.reset_feedback()
	player.equipped_weapon.equip(Player.SWORD)
	player.action_state_machine.transition_to(&"attack")
	player.equipped_weapon.advance(Player.SWORD.combo_steps[0].windup_seconds * 0.5)
	rig.sync_from_player(0.0)
	_check(rig.displayed_animation == &"attack_slash_1" and is_equal_approx(rig.displayed_time, 0.1) and not player.equipped_weapon.hitbox.active, "Committed attack pose takes precedence over cosmetic hurt and never opens an early hitbox")
	player.action_state_machine.transition_to(&"ready")
	player.equipped_weapon.equip(preload("res://data/weapons/unarmed.tres"))
	player.action_state_machine.transition_to(&"attack")
	player.equipped_weapon.advance(player.equipped_weapon.definition.combo_steps[0].windup_seconds * 0.5)
	rig.sync_from_player(0.0)
	_check(rig.displayed_animation == &"punch" and is_equal_approx(rig.displayed_time, 0.1), "Unarmed moveset seeks its own punch pose on the existing wind-up clock")
	player.action_state_machine.transition_to(&"ready")
	rig._hurt_pose_remaining = 0.0
	player.resonance_controller.reset_runtime()
	player.action_state_machine.transition_to(&"cast_spell")
	var cast: PlayerCastState = player.action_state_machine.current_state as PlayerCastState
	cast.physics_update(cast.payload.windup * 0.5)
	rig.sync_from_player(0.0)
	_check(rig.displayed_animation == &"cast_spell" and is_equal_approx(rig.displayed_time, 0.1), "Separated sleeves and hands cast from the unchanged spell payload clock")
	player.action_state_machine.transition_to(&"dead")
	rig.sync_from_player(0.15)
	_check(rig.displayed_animation == &"dead" and rig._modular_base.all(func(sprite: Sprite2D) -> bool: return sprite.visible), "Dead action takes precedence and keeps the cutout body visible for the defeat screen")
	rig.sync_from_player(1.0)
	_check(rig.displayed_time == 0.4 and rig.get_node("Skeleton2D/Root").rotation > 1.1, "Death pose settles once without looping or deleting the player actor")
	_check(rig.get_modular_visual_bounds().end.y <= foot_world.y + 0.001, "Settled corpse and worn garments remain entirely above the existing physical floor contact")
	var safe: bool = true
	for clip: StringName in [&"jump", &"fall", &"land", &"dash", &"hurt", &"dead", &"punch"]:
		var animation: Animation = rig.animation_player.get_animation(clip)
		for index: int in animation.get_track_count():
			safe = safe and animation.track_get_type(index) == Animation.TYPE_VALUE and String(animation.track_get_path(index)).begins_with("Skeleton2D/")
	_check(safe, "All seven new clips contain visual value tracks and no damage or physics callbacks")
	_check(body.global_transform == original_body and hurt.global_transform == original_hurt and body.shape == body_shape and hurt.shape == hurt_shape and player.equipped_weapon.global_position == weapon_origin, "Cutout, outfit, jump, dash, flinch and death never change collision shapes or physics origins")
	rig.clear_equipment_parts(&"gloves")
	_check(not rig._modular_equipment.has(&"gloves") and rig._modular_equipment[&"armor"].size() == 2, "Unequipping gloves leaves the shirt and independent body attachments intact")
	_check(skin.parts[2].texture == texture and skin.parts[2].display_scale == Vector2.ONE * 0.5 and skin.visual_scale == 1.25, "Animations and equipping do not mutate shared PNG or part definitions")
	player.action_state_machine.transition_to(&"ready")
	rig.bind(player)
	rig.sync_from_player(0.0)
	_check(rig.get_modular_foot_world().is_equal_approx(foot_world), "Fresh live pose clears the cosmetic corpse lift and restores its authored foot anchor")
	_check(rig.set_modular_skin(null) and not rig.is_modular_active() and rig.concept_sprite.visible, "Clearing the opt-in skin restores the previously approved full concept")
	await _step(3)
	_check(rig.skeleton.get_bone_count() == 14 and rig._modular_base.is_empty() and rig._modular_equipment.is_empty(), "Cutout teardown releases extended joints and worn visual attachments")
	await _test_lifetimes(skin)
	player.action_state_machine.transition_to(&"ready")
	player.equipped_weapon.equip(Player.SWORD)
	rig.bind(player)
	rig.set_physics_process(true)
	player.set_physics_process(true)
	player.controls_enabled = true


func _test_lifetimes(skin: ModularCharacterSkin) -> void:
	var objects_before: int = 0
	var resources_before: int = 0
	var complete: bool = true
	for cycle: int in 8:
		var disposable: PlayerVisualRig = RIG_SCENE.instantiate() as PlayerVisualRig
		root.add_child(disposable)
		disposable.bind(player)
		disposable.set_physics_process(false)
		complete = disposable.set_modular_skin(skin) and complete
		var same: PlayerVisualRig = RIG_SCENE.instantiate() as PlayerVisualRig
		root.add_child(same)
		complete = same.set_modular_skin(skin) and complete
		var empty: Array[ModularCharacterPart] = []
		disposable.set_equipment_parts(&"gloves", empty)
		complete = disposable._modular_base[0] != same._modular_base[0] and same._modular_equipment.is_empty() and complete
		disposable.queue_free()
		same.queue_free()
		await _step(3)
		if cycle == 1:
			objects_before = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			resources_before = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	_check(complete, "Two actors share immutable skin data while owning independent body and clothing sprite instances")
	var objects_after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_after: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	print("STRESS: modular rig objects=%d->%d resources=%d->%d" % [objects_before, objects_after, resources_before, resources_after])
	_check(objects_after <= objects_before and resources_after <= resources_before, "Eight paired cutout lifecycles release joints, flash materials and attachment nodes after warm-up")


func _part(id: StringName, slot: StringName, texture: Texture2D) -> ModularCharacterPart:
	var part := ModularCharacterPart.new()
	part.id = id
	part.bone_slot = slot
	part.texture = texture
	part.pivot_pixels = Vector2(8.0, 0.0)
	part.display_scale = Vector2.ONE * 0.5
	return part


func _aim(position_world: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_canvas_transform() * position_world
	root.push_input(motion, true)
	player.aim.sample_cursor()

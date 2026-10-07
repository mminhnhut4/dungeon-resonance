extends "res://tests/survival_test_base.gd"
## The actual approved atlas and equipped product loadout, not the legacy PNG fixture.

func _initialize() -> void:
	suite = "starter_character"
	use_neutral_equipment = false
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	var rig: PlayerVisualRig = player.get_node("Visuals") as PlayerVisualRig
	var gear: GearSession = level.gear
	var inventory: GearInventory = gear.inventory
	var socket: Transform2D = player.equipped_weapon.get_parent().transform
	var body: CollisionShape2D = player.get_node("BodyCollision")
	var body_shape: Shape2D = body.shape
	var hurt_shape: Shape2D = player.hurtbox.get_node("CollisionShape2D").shape
	_check(rig.is_modular_active() and rig.modular_skin.id == &"starter_swordsman", "Live Player defaults to the approved modular swordsman")
	_check(not rig.concept_sprite.visible and rig.body_sprite.self_modulate.a == 0.0, "No full-body overlay or legacy box renders over the real parts")
	_check(rig.skeleton.get_bone_count() == 18 and rig._modular_base.size() == 16, "Live cutout has sixteen body attachments and both articulated knees/ankles")
	var alpha: Image = preload("res://assets/sprites/player/modular/starter_parts_atlas.png").get_image()
	_check(alpha.detect_alpha() != Image.ALPHA_NONE and alpha.get_pixel(0, 0).a == 0.0, "Approved PNG stores real transparent background without runtime white masking")
	_check(rig._modular_base.all(func(part: Sprite2D) -> bool: return part.texture is AtlasTexture and part.texture.get_width() > 20 and part.texture.get_height() > 20), "Every body attachment uses a separate authored AtlasTexture region")
	_check(rig._modular_base.all(func(part: Sprite2D) -> bool: return part.get_parent() is Bone2D and part.material == rig._modular_material), "Body parts follow joints and share only this actor's flash material")
	_check(rig.get_modular_foot_world().distance_to(player.global_position) < 0.1, "Authored foot origin stays on the physical floor contact")
	var expected: Dictionary = {&"armor": 6, &"pants": 4, &"boots": 2, &"gloves": 2, &"ring": 1, &"amulet": 1}
	for group: StringName in expected:
		_check(rig._modular_equipment.has(group) and rig._modular_equipment[group].size() == expected[group], "%s mounts its own complete wearable parts" % group)
	gear.equipment_visual.refresh_pose()
	_check(gear.equipment_visual.hand_socket.global_position.distance_to(rig.get_hand_world_position()) < 0.01, "The visible sword socket follows the actual hand bone")
	_check(not gear.equipment_visual.armor_sprite.visible and gear.equipment_visual.accessory_aura.get_child_count() == 0, "Starter clothing uses joint layers and ordinary jewelry emits no aura")
	_check(player.health.maximum_health == 115.0 and player.hurtbox.damage_resolver.armor_rating == 11.0 and player.equipped_weapon.damage_multiplier == 1.2, "Approved starter art carries the confirmed HP/armor/attack loadout")
	var initial: Array[int] = inventory.equipment_uids.duplicate()
	var owned: int = inventory.items.size()
	await _test_active_skin_rebind(rig, gear, expected, initial, owned)
	var others: Array[Sprite2D] = rig._modular_equipment[&"pants"].duplicate()
	_check(inventory.unequip_equipment(EquipmentData.SlotType.ARMOR), "The product shirt can be removed through the inventory ledger")
	_check(not rig._modular_equipment.has(&"armor") and rig._modular_equipment[&"pants"] == others and rig._modular_base.size() == 16, "Removing a shirt exposes the base undershirt and preserves the other body/equipment parts")
	_check(inventory.equip_equipment(initial[EquipmentData.SlotType.ARMOR]) and rig._modular_equipment[&"armor"].size() == 6 and inventory.items.size() == owned, "Re-equipping restores the same six shirt pieces without duplicating gear")
	for slot: int in [EquipmentData.SlotType.PANTS, EquipmentData.SlotType.BOOTS, EquipmentData.SlotType.GLOVES, EquipmentData.SlotType.RING, EquipmentData.SlotType.AMULET]:
		var group: StringName = EquipmentData.SLOT_KINDS[slot]
		inventory.unequip_equipment(slot)
		_check(not rig._modular_equipment.has(group), "Removing %s releases only that wearable layer" % group)
		inventory.equip_equipment(initial[slot])
		_check(rig._modular_equipment[group].size() == expected[group] and inventory.items.size() == owned, "Restoring %s reuses its owned UID and complete parts" % group)
	player.set_physics_process(false)
	rig.set_physics_process(false)
	rig._seek(&"idle", 0.0)
	var boot_transforms: Array[Transform2D] = []
	for boot: Sprite2D in rig._modular_equipment[&"boots"]:
		boot_transforms.append(boot.global_transform)
	rig._seek(&"idle", 0.6)
	var feet_fixed: bool = true
	for index: int in boot_transforms.size():
		feet_fixed = feet_fixed and (rig._modular_equipment[&"boots"][index] as Sprite2D).global_transform.is_equal_approx(boot_transforms[index])
	_check(feet_fixed and rig.get_node("Skeleton2D/Root/Hip").position == Vector2.ZERO, "Real boots keep their exact floor pose through the full idle inhale")
	_check((rig.get_modular_bone(&"torso") as Bone2D).scale.y > 1.02, "Fixing grounded boots preserves breathing in the actual shirt and torso")
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		_aim(player.global_position + direction * 200.0)
		rig.sync_from_player(0.02)
		gear.equipment_visual.refresh_pose()
		_check(gear.equipment_visual.hand_socket.global_position.distance_to(rig.get_hand_world_position()) < 0.01, "Hand and cosmetic socket coincide when aiming " + str(direction))
	var weapon: Weapon = player.equipped_weapon
	_aim(player.global_position + Vector2(180, -50))
	player.action_state_machine.transition_to(&"attack")
	weapon.advance(weapon.definition.combo_steps[0].windup_seconds * 0.5)
	rig.sync_from_player(0.0)
	gear.equipment_visual.refresh_pose()
	_check(rig.displayed_animation == &"attack_slash_1" and not weapon.hitbox.active, "Cutout anticipates the real sword windup before the hitbox opens")
	weapon.advance(weapon._phase_remaining + 0.01)
	rig.sync_from_player(0.0)
	gear.equipment_visual.refresh_pose()
	_check(weapon.hitbox.active and rig.displayed_time >= 0.2 and gear.equipment_visual.hand_socket.global_position.distance_to(rig.get_hand_world_position()) < 0.01, "Active slash keeps bone grip and physical hit window synchronized")
	weapon.cancel_combo()
	player.action_state_machine.transition_to(&"ready")
	rig._hurt_pose_remaining = 0.0
	var tick: DamageEvent = _damage(player.hurtbox, 1.0)
	tick.source_kind = DamageEvent.SourceKind.DOT
	var tick_result: DamageResult = player.hurtbox.take_internal_damage(tick)
	_check(tick_result.actual_damage > 0.0 and rig._hurt_pose_remaining == 0.0, "Damage-over-time drains health without restarting a direct-hit recoil pose")
	_check(body.shape == body_shape and body.position == Vector2(0, -18) and player.hurtbox.get_node("CollisionShape2D").shape == hurt_shape and player.equipped_weapon.get_parent().transform == socket, "Every art/equipment/action change leaves body, Hurtbox and physical WeaponSocket unchanged")
	player.set_physics_process(true)
	rig.set_physics_process(true)
	var objects_before: int = 0
	var resources_before: int = 0
	for cycle: int in 8:
		inventory.unequip_equipment(EquipmentData.SlotType.ARMOR)
		inventory.equip_equipment(initial[EquipmentData.SlotType.ARMOR])
		await _step(4)
		if cycle == 1:
			objects_before = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			resources_before = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var objects_after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_after: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	print("STRESS: starter wardrobe objects=%d->%d resources=%d->%d" % [objects_before, objects_after, resources_before, resources_after])
	_check(objects_after <= objects_before and resources_after <= resources_before and inventory.items.size() == owned, "Eight real-atlas wardrobe cycles release replaced sprites while keeping the same gear ledger")
	player.reset_movement_at(Vector2(780, 640))
	await _step(5)
	player.hurtbox.set_invulnerable(false)
	var lethal: DamageResult = player.hurtbox.take_damage(_damage(player.hurtbox, 999.0))
	await _time(0.5)
	var floor: float = body.to_global(Vector2(0.0, body.shape.get_rect().end.y)).y
	var corpse: Rect2 = rig.get_modular_visual_bounds()
	_check(lethal.killed and rig.displayed_animation == &"dead" and rig.displayed_time == 0.4 and corpse.size.x > corpse.size.y, "Actual atlas and all worn garments settle into one readable non-looping horizontal corpse")
	_check(player.motor.is_grounded() and absf(corpse.end.y - floor) < 0.01 and corpse.position.y < floor and rig._modular_base[0].modulate == Color(0.7, 0.7, 0.7, 1.0), "Settled real corpse touches the physical floor and keeps its readable dungeon tint")
	var settled: Transform2D = rig.skeleton.global_transform
	level.combat_feedback._frozen_this_tick = true
	rig.sync_from_player(0.5)
	_check(rig.skeleton.global_transform.is_equal_approx(settled) and rig.get_modular_visual_bounds().is_equal_approx(corpse) and rig.displayed_time == 0.4, "Hit-stop keeps the actual corpse offset, complete world bounds and settled clock fixed")
	level.combat_feedback.reset_feedback()
	_check(body.shape == body_shape and body.position == Vector2(0, -18) and player.hurtbox.get_node("CollisionShape2D").shape == hurt_shape, "Cosmetic corpse contact leaves body and Hurtbox resources exactly unchanged")


func _test_active_skin_rebind(rig: PlayerVisualRig, gear: GearSession, expected: Dictionary, initial: Array[int], owned: int) -> void:
	var original: ModularCharacterSkin = rig.modular_skin
	var old_layers: Dictionary = _wearable_ids(rig)
	_check(rig.set_modular_skin(original) and rig.is_modular_active(), "Reapplying an active skin completes without changing the modular state")
	_check(_complete_wardrobe(rig, expected), "Same-active-skin replacement immediately restores all six real wearable groups")
	_check(gear.inventory.equipment_uids == initial and gear.inventory.items.size() == owned, "Replacing the picture keeps all seven owned equipment UIDs and ledger entries")
	var new_layers: Dictionary = _wearable_ids(rig)
	var replaced: bool = true
	for group: StringName in expected:
		replaced = replaced and new_layers[group] != old_layers[group]
		for part: Sprite2D in rig._modular_equipment[group]:
			replaced = replaced and part.material == rig._modular_material and part.get_parent() is Bone2D and part.texture is AtlasTexture
	_check(replaced, "Wardrobe remount uses new actor-owned joint sprites and the current skin material")
	for frame: int in 12:
		gear.equipment_visual._process(1.0 / Engine.physics_ticks_per_second)
	_check(_wearable_ids(rig) == new_layers, "Twelve unchanged presentation frames reuse wardrobe sprites without rebuilding layers")
	var alternative: ModularCharacterSkin = original.duplicate(false) as ModularCharacterSkin
	alternative.id = &"test_only_same_atlas_variant"
	_check(rig.set_modular_skin(alternative) and rig.modular_skin == alternative and _complete_wardrobe(rig, expected), "A different active skin Resource also restores worn real-atlas parts immediately")
	_check(rig.set_modular_skin(original) and _complete_wardrobe(rig, expected) and gear.inventory.equipment_uids == initial, "Restoring the approved skin keeps the same complete loadout")
	await _step(3)


func _complete_wardrobe(rig: PlayerVisualRig, expected: Dictionary) -> bool:
	if rig._modular_equipment.size() != expected.size():
		return false
	for group: StringName in expected:
		if not rig._modular_equipment.has(group) or rig._modular_equipment[group].size() != expected[group]:
			return false
	return true


func _wearable_ids(rig: PlayerVisualRig) -> Dictionary:
	var identifiers: Dictionary = {}
	for group: StringName in rig._modular_equipment:
		var instances: Array[int] = []
		for part: Sprite2D in rig._modular_equipment[group]:
			instances.append(part.get_instance_id())
		identifiers[group] = instances
	return identifiers


func _aim(target: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = player.get_canvas_transform() * target
	Input.parse_input_event(event)
	player.aim.sample_cursor()

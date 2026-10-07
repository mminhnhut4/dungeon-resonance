extends "res://tests/survival_test_base.gd"
## Real damage/loot flow through purely cosmetic dummy/chest PNG adapters.


func _initialize() -> void:
	suite = "full_visual_props"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.set_physics_process(false)
	for texture: Texture2D in [PropSpriteSkin.DUMMY_TEXTURE, PropSpriteSkin.CHEST_TEXTURE]:
		var image: Image = texture.get_image()
		_check(image != null and image.detect_alpha() != Image.ALPHA_NONE and image.get_pixel(0, 0).a == 0.0, "Prop PNG has genuine transparent pixels: %s" % texture.resource_path)
		_check(not EnemySpriteArt.alpha_geometry(texture).is_empty(), "Prop PNG supplies nonempty alpha geometry")
	await _test_dummy()
	await _test_chest()
	await _test_lifetimes()


func _test_dummy() -> void:
	var dummy: TrainingDummy = level.dummy_a
	dummy.set_physics_process(false)
	dummy.set_process(false)
	var skin: PropSpriteSkin = dummy.get_node("PropSpriteSkin") as PropSpriteSkin
	skin.set_process(false)
	var collision: CollisionShape2D = dummy.get_node("BodyCollision") as CollisionShape2D
	var hurt_shape: CollisionShape2D = dummy.hurtbox.get_node("CollisionShape2D") as CollisionShape2D
	var body_id: int = collision.shape.get_instance_id()
	var hurt_id: int = hurt_shape.shape.get_instance_id()
	var body_local: Transform2D = collision.transform
	var hurt_local: Transform2D = dummy.hurtbox.transform
	var location: Vector2 = dummy.global_position
	_check(skin.kind == &"dummy" and skin.sprite.texture == PropSpriteSkin.DUMMY_TEXTURE and not dummy.body_visual.visible, "Training Dummy renders supplied PNG instead of its brown polygon")
	_check(not (dummy.get_node("Visuals/Target") as CanvasItem).visible and not (dummy.get_node("Visuals/Stand") as CanvasItem).visible, "Old target ring and stand do not draw through the replacement art")
	_check(is_equal_approx(skin.sprite.scale.y * float((skin.geometry["bounds"] as Rect2i).size.y), 48.0) and skin.get_foot_world().is_equal_approx(dummy.global_position), "Dummy alpha base sits on its unchanged 48px physical body")
	var event: DamageEvent = _damage(dummy.hurtbox, 12.0)
	event.attack_direction = Vector2.RIGHT
	event.knockback = Vector2(200, -70)
	var result: DamageResult = dummy.hurtbox.take_damage(event)
	skin.refresh_skin()
	_check(result.actual_damage == 12.0 and dummy.health.current_health == 108.0 and skin.wobble_count == 1, "Actual DamageEvent changes health and starts exactly one cosmetic wobble")
	_check(skin._material.get_shader_parameter("flash") == 1.0 and dummy.body_visual.color == Color.WHITE, "Dummy PNG reads the existing white impact flash")
	var wobble: Tween = skin.wobble_tween
	wobble.pause()
	wobble.custom_step(0.045)
	_check(is_equal_approx(skin.wobble_angle, 3.0) and skin.get_foot_world().is_equal_approx(dummy.global_position), "Wobble reaches three degrees around the alpha foot pivot")
	_check(dummy.global_position == location and collision.transform == body_local and dummy.hurtbox.transform == hurt_local, "Art rotation cannot rotate, move or scale physical geometry")
	var duplicate: DamageResult = dummy.hurtbox.take_damage(event)
	_check(duplicate.blocked and skin.wobble_count == 1 and skin.wobble_tween == wobble, "Duplicate/blocked damage does not restart the visual Tween")
	var dot: DamageEvent = _damage(dummy.hurtbox, 1.0)
	dot.source_kind = DamageEvent.SourceKind.DOT
	dummy.hurtbox.take_damage(dot)
	_check(skin.wobble_count == 1 and skin.wobble_tween == wobble, "DOT may deal damage without creating another wobble")
	var second: DamageEvent = _damage(dummy.hurtbox, 1.0)
	second.attack_direction = Vector2.LEFT
	dummy.hurtbox.take_damage(second)
	_check(not wobble.is_valid() and skin.wobble_count == 2 and skin.wobble_tween.is_valid(), "A new confirmed hit replaces the prior Tween rather than stacking it")
	level.combat_feedback._frozen_this_tick = true
	skin.refresh_skin()
	_check(not skin.wobble_tween.is_running(), "Existing local hit-stop pauses the dummy wobble")
	level.combat_feedback.reset_feedback()
	skin.refresh_skin()
	_check(skin.wobble_tween.is_running(), "Ending hit-stop resumes the same dummy wobble")
	var active: Tween = skin.wobble_tween
	active.pause()
	active.custom_step(0.25)
	_check(is_zero_approx(skin.wobble_angle) and skin.wobble_tween == null and skin.get_foot_world().is_equal_approx(dummy.global_position), "Completed wobble drops its finished Tween and restores original feet")
	dummy._flash_remaining = 0.08
	dummy._process(0.0)
	skin.refresh_skin()
	_check(skin.sprite.modulate.g < 0.2 and skin._material.get_shader_parameter("flash") == 0.0, "Dummy white flash transitions into its original red flash")
	dummy.set_physics_process(true)
	await _step(3)
	_check(dummy.global_position.x > location.x and skin.get_foot_world().is_equal_approx(dummy.global_position), "Original pending knockback moves both body and its foot-anchored art")
	_check(collision.shape.get_instance_id() == body_id and hurt_shape.shape.get_instance_id() == hurt_id and collision.transform == body_local and dummy.hurtbox.transform == hurt_local, "Knockback preserves collider Resource identity and local Hurtbox transforms")
	dummy.reset_at_home()
	dummy.set_process(true)
	skin.refresh_skin()
	_check(dummy.health.current_health == 120.0 and skin.sprite.modulate == Color.WHITE, "Existing reset refills health and restores untinted imported art")
	skin.set_process(true)


func _test_chest() -> void:
	var chest: TreasureChest = level.secret_chest
	var skin: PropSpriteSkin = chest.get_node("PropSpriteSkin") as PropSpriteSkin
	var loot: LootSpawner = chest.spawner
	loot.quality_enabled = false
	loot.clear()
	chest.large = false
	chest.relic_reward = false
	chest.reset()
	chest.locked = true
	player.reset_movement_at(chest.global_position + Vector2(20, 0))
	skin.refresh_skin()
	_check(skin.kind == &"chest" and skin.sprite.texture == PropSpriteSkin.CHEST_TEXTURE and chest.self_modulate.a == 0.0, "Treasure Chest renders supplied PNG and suppresses its old rectangle drawing")
	_check(is_equal_approx(skin.sprite.scale.y * float((skin.geometry["bounds"] as Rect2i).size.y), 28.0) and skin.get_foot_world().is_equal_approx(chest.global_position), "Chest alpha base remains at the old 28px ground pivot")
	_check(skin.chest_light.color.g > skin.chest_light.color.r and skin.chest_light.color.g > skin.chest_light.color.b and skin.chest_light.energy <= 0.55, "Chest owns one bounded jade green PointLight2D")
	var dropped: int = loot.spawned_total
	_check(not chest.interact() and loot.spawned_total == dropped and not skin.opened_icon.visible, "Locked sprite chest still blocks interaction and drops nothing")
	chest.unlock()
	skin.refresh_skin()
	_check(chest.interact() and loot.spawned_total == dropped + 3, "Opening normal chest still drops two runes and one weapon exactly once")
	skin.refresh_skin()
	_check(skin.opened_icon.visible and skin.sprite.modulate != Color.WHITE and is_equal_approx(skin.chest_light.energy, 0.2), "Opened state reads through a checkmark/tint and subdued light without pretending to animate a lid")
	_check(not chest.interact() and loot.spawned_total == dropped + 3, "Repeated interaction cannot duplicate chest rewards")
	_check(loot.get_children().all(func(item: Node) -> bool: return item is LootPickup), "Prop skin does not create reward copies or change LootPickup entity types")
	chest.reset()
	skin.refresh_skin()
	_check(not skin.opened_icon.visible and skin.sprite.modulate == Color.WHITE and is_equal_approx(skin.chest_light.energy, 0.55), "Room reset restores the same chest sprite and its closed state")
	loot.clear()
	loot.maximum_pickups = 2
	dropped = loot.spawned_total
	chest.interact()
	_check(loot.get_child_count() == 2 and loot.spawned_total == dropped + 2, "Sprite chest obeys the existing LootSpawner cap under constrained capacity")
	loot.clear()
	loot.maximum_pickups = 96
	await _step(3)


func _test_lifetimes() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var objects: int = 0
	var resources: int = 0
	var dummy_hash: String = FileAccess.get_sha256(PropSpriteSkin.DUMMY_TEXTURE.resource_path)
	var chest_hash: String = FileAccess.get_sha256(PropSpriteSkin.CHEST_TEXTURE.resource_path)
	for cycle: int in 10:
		var chamber := Node2D.new()
		holder.add_child(chamber)
		var dummy: TrainingDummy = preload("res://scenes/training_dummy.tscn").instantiate()
		chamber.add_child(dummy)
		dummy.set_process(false)
		dummy.set_physics_process(false)
		var dummy_skin := PropSpriteSkin.new()
		dummy.add_child(dummy_skin)
		var chest := TreasureChest.new()
		chamber.add_child(chest)
		var chest_skin := PropSpriteSkin.new()
		chest.add_child(chest_skin)
		if cycle == 0:
			_check(dummy_skin.sprite.texture == PropSpriteSkin.DUMMY_TEXTURE and chest_skin.sprite.texture == PropSpriteSkin.CHEST_TEXTURE, "Repeated prop instances reuse their imported source PNGs")
			dummy_skin.bind(null)
			chest_skin.bind(null)
			_check(dummy.body_visual.visible and not dummy_skin.sprite.visible and chest.self_modulate.a == 1.0 and not chest_skin.chest_light.enabled, "Unbind restores old adapters and hides replacement sprite/light")
			dummy_skin.bind(dummy)
			chest_skin.bind(chest)
			_check(not dummy.body_visual.visible and dummy_skin.sprite.visible and chest.self_modulate.a == 0.0, "Rebind restores exactly one visual owner per prop")
		dummy.hurtbox.take_damage(_damage(dummy.hurtbox, 1.0))
		var tween: Tween = dummy_skin.wobble_tween
		var light_id: int = chest_skin.chest_light.get_instance_id()
		chamber.queue_free() # Also frees damage text/effects owned by this disposable room.
		await _step(3)
		if cycle == 0:
			_check(not tween.is_valid() and not is_instance_id_valid(light_id), "Prop teardown kills an active Tween and its chest light")
		if cycle == 1:
			objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			resources = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var objects_after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_after: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	print("STRESS props objects=%d->%d resources=%d->%d" % [objects, objects_after, resources, resources_after])
	_check(objects_after <= objects and resources_after <= resources, "Ten dummy/chest lifecycles retain no material, Tween or light growth")
	_check(FileAccess.get_sha256(PropSpriteSkin.DUMMY_TEXTURE.resource_path) == dummy_hash and FileAccess.get_sha256(PropSpriteSkin.CHEST_TEXTURE.resource_path) == chest_hash, "Prop wobble, open and flash preserve all imported PNG bytes")
	holder.queue_free()
	await _step(3)

extends SceneTree
## Sixty real owned variants, ten combat clocks and actual melee/ranged delivery.
var checks: int = 0
var failures: int = 0
var level: Node2D
var player: Player

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	level = preload("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.player
	level.survival.set_enabled(false)
	level.combat_feedback.hit_stop_seconds = 0.0
	for enemy: SlimeEnemy in level.enemies: enemy.ai_enabled = false
	player.energy.enabled = false
	player.controls_enabled = false
	await _step(8)
	var shape: CollisionShape2D = player.get_node("BodyCollision") as CollisionShape2D
	var shape_id: int = shape.shape.get_instance_id()
	var transform_before: Transform2D = shape.transform
	var variants: Array[GearVariantData] = WeaponVariantCatalog.all_variants()
	_check(variants.size() == 60, "Ten approved families expose exactly sixty grade entries")
	_check(WeaponVariantCatalog.variant_for(&"bad", 0) == null and WeaponVariantCatalog.variant_for(WeaponVariantCatalog.IDS[0], 6) == null, "Unknown families and grades are rejected")
	var profiles: Array[StringName] = []
	for family: StringName in WeaponVariantCatalog.IDS:
		var data: EquipmentData = WeaponVariantCatalog.equipment_for(family)
		var moveset: WeaponDefinition = data.moveset
		profiles.append(moveset.visual_profile)
		_check(moveset.base_damage > Player.SWORD.base_damage and moveset.combo_steps.size() >= 2, "Craft family %s exceeds starter damage and owns a combo" % family)
		_check(data.world_sprite_texture is AtlasTexture and data.world_sprite_texture.get_width() > 100, "Family %s mounts its own approved model" % family)
		var held: GearItem
		for grade: int in 6:
			var variant: GearVariantData = WeaponVariantCatalog.variant_for(family, grade)
			held = variant.create_owned(level.gear.inventory)
			_check(variant.valid() and held != null and held.quality == grade and held.equipment_definition == data, "%s grade%d creates its own runtime UID" % [family, grade])
			_check(level.gear.inventory.equip_equipment(held.uid), "%s grade%d equips via the real seven-slot ledger" % [family, grade])
			player.equipped_weapon.start_combo()
			var shot: AttackSnapshot = player.equipped_weapon.snapshot
			_check(shot.weapon_definition == moveset and shot.cosmetic_quality == grade and level.gear.equipment_visual.weapon_sprite.texture == data.world_sprite_texture, "%s grade%d binds model and frozen rarity to the real attack" % [family, grade])
			player.equipped_weapon.cancel_combo()
			level.gear.inventory.unequip_equipment(0)
			level.gear.inventory.items.erase(held.uid)
			level.gear.inventory.changed.emit()
		held = level.gear.inventory.add_equipment(data, GearItem.Quality.VERY_RARE)
		level.gear.inventory.equip_equipment(held.uid)
		player.reset_movement_at(Vector2(450, 640))
		player.controls_enabled = false
		player.aim.direction = Vector2.RIGHT
		player.aim.target_position = Vector2(650, 620)
		level.dummy_a.reset_at_home()
		level.dummy_a.global_position = Vector2(485, 640)
		level.dummy_a.set_physics_process(false)
		level.dummy_b.global_position = Vector2(1100, 640)
		await _step(2)
		var motion := InputEventMouseMotion.new()
		motion.position = player.aim.get_canvas_transform() * Vector2(700, 618)
		root.push_input(motion, true)
		player.aim.sample_cursor()
		var count_before: int = level.spell_executor.spawned_projectiles
		var weapon: Weapon = player.equipped_weapon
		weapon.installed_rune = GearInventory.RUNES[0]
		player.action_state_machine.transition_to(&"attack")
		var committed: AttackSnapshot = weapon.snapshot
		weapon.installed_rune = null
		await _time(moveset.combo_steps[0].windup_seconds + 0.025)
		if moveset.attack_kind == &"melee":
			_check(level.dummy_a.hit_count > 0 and level.dummy_a.last_damage_event.burn_damage > 0, "Family %s really delivers a frozen Fire melee hit" % family)
		else:
			_check(level.spell_executor.spawned_projectiles == count_before + (3 if family == &"world_fan" else 1), "Family %s launches its distinct projectile pattern" % family)
		_check(committed.cosmetic_element == &"fire" and committed.burn_damage > 0 and committed.cosmetic_quality == 2, "Family %s changing live rune cannot change committed hue or grade" % family)
		var pose: Dictionary = WeaponMotionPose.evaluate(moveset.visual_profile, 0, Weapon.Phase.ACTIVE, 0.5)
		_check(is_finite(float(pose["swing"])) and not is_zero_approx(float(pose["lean"])), "Family %s has its own finite manual action pose" % family)
		player.action_state_machine.transition_to(&"ready")
		weapon.cancel_combo()
		level.gear.inventory.unequip_equipment(0)
		level.gear.inventory.items.erase(held.uid)
		level.gear.inventory.changed.emit()
		level.spell_executor.clear_entities()
		await _step(3)
	_check(profiles.size() == 10 and profiles.size() == _unique_count(profiles), "All ten families select distinct visual motion profiles")
	_check(shape.shape.get_instance_id() == shape_id and shape.transform == transform_before, "Sixty model/grade swaps keep Player collider identity and transform")
	var owned: GearItem = level.gear.inventory.add_equipment(WeaponVariantCatalog.equipment_for(&"world_spear"), 2)
	level.gear.inventory.equip_equipment(owned.uid)
	await _step(2)
	_check(player.available_weapons.has(owned.equipment_definition.moveset), "Q rotation includes owned new craft families")
	player.controls_enabled = true
	player.action_state_machine.transition_to(&"attack")
	var previous: WeaponDefinition = player.equipped_weapon.definition
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	root.push_input(key, true)
	Input.parse_input_event(key)
	await _step(2)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key, true)
	Input.parse_input_event(key)
	await _step(2)
	_check(player.equipped_weapon.definition != previous and not player.equipped_weapon.hitbox.active, "Physical Q changes away from a new family and cancels its hit window")
	var bounty: WeaponDefinition = load("res://data/weapons/ancient_sword_bounty.tres") as WeaponDefinition
	_check(bounty.combo_steps.size() == 4 and bounty.combo_steps[3].motion == &"thrust" and bounty.combo_steps[3].lunge_speed > 0, "Vô Danh reward opens a real fourth thrust/lunge")
	level.queue_free()
	await _step(6)
	_check(get_nodes_in_group(&"spell_entities").is_empty(), "Family teardown releases every ranged child")
	await root.get_node("AudioManager").shutdown()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _unique_count(values: Array[StringName]) -> int:
	var distinct: Dictionary = {}
	for value: StringName in values: distinct[value] = true
	return distinct.size()

func _time(seconds: float) -> void: await _step(ceili(seconds * Engine.physics_ticks_per_second))
func _step(frames: int) -> void:
	for index: int in frames: await physics_frame; await process_frame
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

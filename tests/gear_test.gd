extends SceneTree
## Actual aiming/hitboxes, weapon switching, environmental gates and loot.

var level: Node2D
var player: Player
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	level = preload("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.player
	level.survival.set_enabled(false) # Existing fixture isolates its milestone.
	level.combat_feedback.hit_stop_seconds = 0.0
	for enemy: SlimeEnemy in level.enemies:
		enemy.ai_enabled = false
	await _step(5)
	print("GEAR TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	await _test_movesets()
	await _test_environment()
	await _test_loot_and_input()
	level.queue_free()
	await _step(4)
	_check(get_nodes_in_group(&"loot").is_empty() and get_nodes_in_group(&"spell_entities").is_empty(), "Playground teardown frees loot and spells")
	_check(is_equal_approx(Engine.time_scale, 1.0), "Playground teardown preserves global time")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_movesets() -> void:
	var weapon: Weapon = player.equipped_weapon
	_check(weapon.definition == Player.SWORD and weapon.definition.combo_steps.size() == 3, "Playground starts with Ancient Sword three-hit moveset")
	_check(Player.DAGGER.combo_steps.size() == 4 and Player.DAGGER.critical_chance > Player.SWORD.critical_chance, "Dagger defines four attacks and a higher critical probability")
	_check(Player.DAGGER.combo_steps[0].reach < Player.SWORD.combo_steps[0].reach and Player.DAGGER.combo_steps[0].windup_seconds < Player.SWORD.combo_steps[0].windup_seconds, "Dagger has independently authored short reach and fast timing")
	player.reset_movement_at(Vector2(680, 640))
	level.dummy_a.global_position = Vector2(735, 640)
	await _step(3)
	_aim(Vector2(850, 618))
	await _tap(&"attack")
	_check(weapon.phase == Weapon.Phase.WINDUP and weapon.snapshot.stagger_force > 0.0, "Sword commits its own windup and stagger data")
	await _time(0.1)
	_check(level.dummy_a.hit_count > 0, "Sword sector hits a target in its authored reach")
	await _key(KEY_Q)
	_check(weapon.definition == Player.DAGGER and not weapon.hitbox.active and player.action_state_machine.get_state_id() == &"ready", "Physical Q cancels the old swing and equips Dagger cleanly")
	await _key(KEY_Q)
	_check(weapon.definition == Player.SWORD, "Q switches back to Sword")
	await _key(KEY_Q)
	var committed: Array[int] = []
	var recorder: Callable = func(attack: AttackSnapshot) -> void: committed.append(attack.attack_id)
	weapon.attack_committed.connect(recorder)
	await _tap(&"attack")
	for index: int in 3:
		await _time(0.07)
		await _tap(&"attack")
		await _time(0.055)
	await _time(0.25)
	_check(committed.size() == 4 and not weapon.is_attacking(), "Four separate presses complete the Dagger combo")
	_check(committed.size() == 4 and committed[0] != committed[3], "Each Dagger thrust receives an independent attack identity")
	weapon.attack_committed.disconnect(recorder)
	player.reset_movement_at(Vector2(680, 640))
	level.dummy_a.reset_at_home()
	level.dummy_a.global_position = Vector2(744, 640)
	await _step(2)
	await _tap(&"attack")
	await _time(0.1)
	_check(level.dummy_a.hit_count == 0, "Dagger does not hit outside its short thrust reach")
	await _time(0.25)
	level.dummy_a.global_position = Vector2(712, 640)
	level.gear.inventory.equip(3, &"fire")
	await _tap(&"attack")
	var fire_snapshot: AttackSnapshot = weapon.snapshot
	level.gear.inventory.equip(3, &"")
	_check(fire_snapshot.burn_damage > 0.0, "Melee snapshots the weapon rune before windup")
	await _time(0.09)
	_check(level.dummy_a.last_damage_event != null and level.dummy_a.last_damage_event.burn_damage > 0.0, "Removing Fire during windup cannot change the committed hit")
	_check(level.dummy_a.hurtbox.damage_resolver.status_controller.burn_remaining > 0.0, "Weapon Fire uses the normal burn pipeline")
	var hp: float = level.dummy_a.health.current_health
	await _time(0.55)
	_check(level.dummy_a.health.current_health < hp, "Weapon Fire burns over time")
	level.dummy_a.reset_at_home()
	level.dummy_b.reset_at_home()
	level.dummy_a.global_position = Vector2(712, 640)
	level.dummy_b.global_position = Vector2(800, 640)
	level.enemies[0].global_position = Vector2(875, 640)
	level.gear.inventory.equip(3, &"lightning")
	level.spell_executor.chain_hit_count = 0
	await _step(3)
	await _tap(&"attack")
	await _time(0.1)
	_check(level.spell_executor.chain_hit_count == 2 and level.dummy_b.health.current_health < 120.0, "Weapon Lightning chains through at most two nearby recipients")
	level.gear.inventory.equip(3, &"")
	# Deterministic random stream checks the high critical rate without flakiness.
	weapon.critical_rng.seed = 777
	var critical_hits: int = 0
	for index: int in 100:
		weapon.start_combo()
		if weapon.snapshot.critical:
			critical_hits += 1
		weapon.cancel_combo()
	_check(critical_hits >= 20 and critical_hits <= 50, "Dagger deterministic sample produces its high critical rate")
	_check(Player.DAGGER.critical_chance == 0.35 and Player.SWORD.combo_steps[0].reach == 68.0, "Combat never mutates shared moveset resources")


func _test_environment() -> void:
	level.reset_room()
	player.energy.enabled = true
	player.reset_movement_at(Vector2(210, 366))
	player.equipped_weapon.equip(Player.SWORD)
	_aim(Vector2(100, 344))
	await _step(3)
	await _tap(&"attack")
	await _time(0.15)
	_check(level.illusory_wall.hits == 1 and not level.illusory_wall.is_open, "Real sword hit cracks the illusory wall once")
	await _time(0.5)
	await _tap(&"attack")
	await _time(0.15)
	_check(level.illusory_wall.is_open and level.illusory_wall.body_shape.disabled, "Second distinct slash opens the hidden-room collision")
	level.illusory_wall.reset()
	await _step(2)
	player.reset_movement_at(Vector2(210, 366))
	level.set_rune_preset(4)
	_aim(Vector2(100, 344))
	await _tap(&"spell_cast")
	await _time(0.3)
	_check(level.illusory_wall.is_open, "A basic projectile opens the wall in one cast")
	player.reset_movement_at(Vector2(720, 300))
	_aim(Vector2(850, 270))
	level.set_rune_preset(4)
	await _tap(&"spell_cast")
	await _time(0.4)
	_check(not level.bramble_gate.is_open, "Non-Fire magic cannot clear the bramble gate")
	player.reset_movement_at(Vector2(720, 300))
	player.resonance_controller.catalyst_a.install_runes([level.FIRE])
	_aim(Vector2(850, 270))
	await _tap(&"spell_cast")
	await _time(0.4)
	_check(level.bramble_gate.is_open and level.bramble_gate.body_shape.disabled, "Fire projectile burns the bramble collision away")
	level.bramble_gate.reset()
	player.reset_movement_at(Vector2(720, 300))
	level.set_rune_preset(1)
	var payload: SpellSnapshot = player.resonance_controller.commit_cast()
	level.spell_executor.spawn_firestorm(level.bramble_gate.global_position, SpellContext.new(payload))
	await _time(1.2)
	_check(level.bramble_gate.is_open, "Firestorm area explosion also burns environmental gates")
	level.bramble_gate.reset()
	level.gear.inventory.equip(3, &"fire")
	player.reset_movement_at(Vector2(720, 300))
	player.global_position = Vector2(730, 300)
	_aim(Vector2(850, 280))
	await _tap(&"attack")
	await _time(0.15)
	_check(level.bramble_gate.is_open, "Fire-infused sword clears the same environment receiver")
	level.gear.inventory.equip(3, &"")


func _test_loot_and_input() -> void:
	player.reset_movement_at(Vector2(90, 366))
	level.secret_chest.reset()
	var count_before: int = level.gear.loot.spawned_total
	await _key(KEY_E)
	_check(level.secret_chest.is_open and level.gear.loot.spawned_total == count_before + 3, "Physical E opens the chest and emits runes plus a random weapon")
	await _key(KEY_E)
	_check(level.gear.loot.spawned_total == count_before + 3, "Repeated E cannot duplicate chest loot")
	var weapon_drop: LootPickup
	for child: Node in level.gear.loot.get_children():
		var pickup := child as LootPickup
		if pickup.kind == &"weapon":
			weapon_drop = pickup
	_check(weapon_drop != null and weapon_drop.item_id in [&"ancient_sword", &"shadow_dagger"], "Chest weapon choice comes from the supported resource catalog")
	await _time(0.5)
	_check(level.gear.inventory.total_shards() >= 4, "Nearby floating chest loot is attracted and collected")
	await _key(KEY_TAB)
	_check(level.gear.modal.is_open, "Playground supports the same inventory modal")
	await _tap(&"attack")
	_check(not player.equipped_weapon.is_attacking(), "Inventory interactions cannot also trigger melee")
	level.gear.modal.close()
	await _step(3)
	var total: int = level.gear.inventory.total_shards()
	for index: int in 200:
		level.gear.inventory.equip(0, &"fire")
		level.gear.inventory.swap_slots(0, 3)
		level.gear.inventory.swap_slots(0, 3)
		level.gear.inventory.equip(0, &"")
	_check(level.gear.inventory.total_shards() == total, "Two hundred dual-slot cycles cannot duplicate or lose shards")
	_check(not level.gear.inventory.equip(99, &"fire") and not level.gear.inventory.add_rune(&"unknown"), "Unknown rune IDs and slot indices fail safely")
	level.gear.modal.open()
	level.reset_room()
	_check(not level.gear.modal.is_open and is_equal_approx(Engine.time_scale, 1.0) and level.gear.loot.get_child_count() == 0, "Reset while inventory is open restores time and clears loot")


func _aim(world_position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_canvas_transform() * world_position
	root.push_input(event, true)
	player.aim.sample_cursor()


func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _step(1)
	event.pressed = false
	Input.parse_input_event(event)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _step(1)
	Input.action_release(action)


func _time(seconds: float) -> void:
	await _step(ceili(seconds * Engine.physics_ticks_per_second))


func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])


extends SceneTree
## End-to-end alpha run, actual boss attacks, resource economy and teardown.

var run: DungeonRun
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	run = preload("res://scenes/dungeon_run.tscn").instantiate() as DungeonRun
	root.add_child(run)
	current_scene = run
	# Alpha attack/healing contracts use their original neutral controlled loadout.
	preload("res://tests/neutral_equipment_fixture.gd").install(run.gear)
	run.survival.set_enabled(false)
	run.feedback.hit_stop_seconds = 0.0
	await _step(5)
	print("ALPHA TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	await _test_rooms_and_inventory()
	await _test_boss()
	await _test_lifecycle()
	await _test_cleanup()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_rooms_and_inventory() -> void:
	_check(run.room_number == 1 and run.room.locked and run.living_enemies().size() == 3, "Room 1 starts locked with three Slimes")
	_check(not run.advance_room(), "Locked room rejects transition")
	_check(run.gear.inventory.total_shards() == 0, "Run starts without unearned rune shards")
	_freeze_enemies()
	run.player.hurtbox.take_damage(_damage(run.player.hurtbox, 15.0, 2))
	_check(run.player.health.current_health == 85.0 and run.player.hurtbox.invulnerable, "Received damage immediately grants grace immunity")
	var blocked: DamageResult = run.player.hurtbox.take_damage(_damage(run.player.hurtbox, 15.0, 2))
	_check(blocked.blocked and run.player.health.current_health == 85.0, "Same-frame contact cannot stack damage")
	await _time(0.55)
	_check(run.player.hurtbox.invulnerable and run.player.body_sprite.modulate != Color.WHITE, "Damage grace lasts through 0.55s and visibly blinks")
	await _time(0.1)
	_check(not run.player.hurtbox.invulnerable, "Damage grace expires after 0.6s")
	_kill_wave()
	await _step(4)
	_check(not run.room.locked and run.gear.loot.get_child_count() == 6, "Three deaths open the door and spawn three shards plus potions")
	for child: Node in run.gear.loot.get_children():
		var pickup := child as LootPickup
		if pickup.kind == &"rune":
			_check(pickup.collect() and not pickup.collect(), "Shard %s collects exactly once" % pickup.item_id)
	await _step(2)
	var inventory: GearInventory = run.gear.inventory
	_check(inventory.total_shards() == 3 and inventory.bag[&"fire"] == 1 and inventory.bag[&"wind"] == 1 and inventory.bag[&"lightning"] == 1, "First three drops expose every rune without RNG dependence")
	_check(inventory.equip(0, &"fire") and inventory.equip(1, &"wind"), "Owned shards equip into catalyst")
	_check(run.player.resonance_controller.get_recipe().id == &"firestorm", "Equipping immediately resolves Firestorm")
	_check(not inventory.equip(3, &"fire") and not inventory.equip(-1, &"wind"), "Unavailable shards and invalid slots are rejected")
	_check(inventory.swap_slots(0, 3) and run.player.equipped_weapon.installed_rune.id == &"fire", "Dual slot moves Fire from catalyst to weapon")
	_check(run.player.resonance_controller.get_recipe().id == &"wind_bolt" and inventory.total_shards() == 3, "Moving a rune removes it from the catalyst without duplicating it")
	inventory.swap_slots(0, 3)
	var payload: SpellSnapshot = run.player.resonance_controller.commit_cast()
	_check(payload != null and run.player.energy.current == 70.0, "Spell commit consumes 30 energy once")
	var remaining: float = run.player.resonance_controller.cooldown_remaining()
	inventory.swap_slots(0, 3)
	inventory.swap_slots(0, 3)
	_check(run.player.resonance_controller.cooldown_remaining() == remaining and payload.recipe_id == &"firestorm", "Swapping preserves cooldown and in-flight recipe")
	await _key(KEY_TAB)
	_check(run.gear.modal.is_open and is_equal_approx(Engine.time_scale, 0.1) and not run.player.controls_enabled, "Tab opens modal, slows time to 10% and gates controls")
	await _key(KEY_4)
	await _key(KEY_H)
	_check(inventory.slots[3] == &"lightning", "Keyboard assigns owned Lightning to selected weapon slot")
	await _key(KEY_BACKSPACE)
	_check(inventory.slots[3] == &"" and inventory.bag[&"lightning"] == 1, "Removing a rune returns it to the bag")
	run.gear.modal.slots[3].pressed.emit()
	run.gear.modal.rune_buttons[2].pressed.emit()
	_check(inventory.slots[3] == &"lightning", "Mouse button bindings share the same inventory transaction")
	run.gear.modal.close()
	await _step(3)
	_check(is_equal_approx(Engine.time_scale, 1.0) and run.player.controls_enabled, "Closing restores time and controls")
	var hp: float = run.player.health.current_health
	var energy: float = run.player.energy.current
	_check(run.advance_room(), "Cleared Room 1 transitions to Room 2")
	await _step(2)
	_freeze_enemies()
	_check(run.room_number == 2 and run.wave == 1 and run.room.locked, "Room 2 starts wave one locked")
	_check(run.player.health.current_health == hp and inventory.slots[0] == &"fire" and inventory.slots[3] == &"lightning", "HP and both socket types persist across rooms")
	_check(run.player.energy.current >= energy and run.player.resonance_controller.cooldown_remaining() > 0.0, "Transition retains energy and outstanding cooldown")
	_kill_wave()
	await _step(4)
	_freeze_enemies()
	_check(run.wave == 2 and run.living_enemies().size() == 3 and run.room.locked, "Clearing wave one spawns wave two without opening the door")
	_kill_wave()
	await _step(4)
	_check(not run.room.locked and run.advance_room(), "Only clearing both waves allows Room 3")
	await _step(3)
	_check(run.room_number == 3 and run.room.locked and run.boss.health.current_health == 500.0, "Boss arena locks with a 500-HP Golem")
	_check(run.boss_panel.visible and run.boss_name.text.contains("Golem Cổ Bảo"), "Bottom boss UI shows name and health")
	_check(not run.reward_chest.interact() and not run.win(), "Rewards and victory are locked before boss death")


func _test_boss() -> void:
	var boss: BossGolem = run.boss
	boss.ai_enabled = true
	run.player.controls_enabled = false
	run.player.reset_movement_at(Vector2(770, 640))
	boss.global_position = Vector2(890, 640)
	boss.fsm.transition_to(&"sweep")
	await _time(0.4)
	_check(not boss.attack_hitbox.active and run.player.health.current_health == 100.0, "Sweep telegraphs before dealing damage")
	await _time(0.2)
	_check(run.player.health.current_health == 80.0, "Ground sweep hitbox damages grounded Player once")
	run.player.reset_movement_at(Vector2(770, 640))
	boss.fsm.transition_to(&"idle")
	boss.fsm.transition_to(&"sweep")
	await _time(0.35)
	# Hold jump via Input while controls are temporarily enabled.
	run.player.controls_enabled = true
	Input.action_press(&"jump")
	await _step(1)
	Input.action_release(&"jump")
	run.player.jump_held = true
	await _time(0.2)
	_check(run.player.health.current_health == 100.0 and run.player.position.y < 615.0, "Jump clears the low floor sweep")
	run.player.controls_enabled = false
	run.player.reset_movement_at(Vector2(690, 640))
	boss.fsm.transition_to(&"orbs")
	await _time(0.95)
	_check(boss.emitted_orbs == 3 and get_nodes_in_group(&"enemy_hazards").size() == 3, "Orb attack emits exactly three homing projectiles")
	var orb := get_nodes_in_group(&"enemy_hazards")[0] as EnemyHazard
	var direction_before: Vector2 = orb.direction
	run.player.global_position = Vector2(650, 520)
	await _time(0.15)
	_check(not orb.direction.is_equal_approx(direction_before), "Orb steering follows the live Player position")
	_clear_hazards()
	boss.ai_enabled = false
	boss.hurtbox.take_damage(_damage(boss.hurtbox, 250.0))
	_check(boss.phase == 1, "Exactly 50% HP remains Phase 1")
	boss.hurtbox.take_damage(_damage(boss.hurtbox, 1.0))
	_check(boss.phase == 2 and boss.phase_two_count == 1 and run.living_enemies().size() == 3, "Below half triggers Phase 2 and exactly two adds")
	_freeze_enemies()
	_check(is_equal_approx(boss.movement_speed(), 104.0) and boss.wait_seconds() < 0.85, "Phase 2 moves 30% faster with shorter attack delay")
	boss.hurtbox.take_damage(_damage(boss.hurtbox, 1.0))
	_check(boss.phase_two_count == 1 and run.living_enemies().size() == 3, "Further damage cannot repeat the phase summon")
	var event: DamageEvent = _damage(boss.hurtbox, 1.0)
	event.stagger_force = 35.0
	event.stun_seconds = 0.5
	event.burn_damage = 3.0
	event.burn_duration = 1.0
	boss.hurtbox.take_damage(event)
	_check(boss.stagger == 35.0 and not boss.statuses.is_stunned() and boss.statuses.burn_remaining > 0.0, "Boss accepts burn and converts control pressure to stagger")
	event = _damage(boss.hurtbox, 1.0)
	event.root_event_id = boss.stagger_roots.keys()[0]
	event.stagger_force = 35.0
	boss.hurtbox.take_damage(event)
	_check(boss.stagger == 35.0, "One root cast cannot multiply stagger through child hits")
	for index: int in 2:
		event = _damage(boss.hurtbox, 1.0)
		event.stagger_force = 35.0
		boss.hurtbox.take_damage(event)
	_check(boss.fsm.get_state_id() == &"staggered" and not boss.attack_hitbox.active, "Full stagger interrupts attacks and closes hitbox")
	event = _damage(boss.hurtbox, 1.0)
	event.stagger_force = 100.0
	boss.hurtbox.take_damage(event)
	_check(boss.stagger == 0.0 and boss.stagger_resistance == 4.0, "Stagger resistance blocks permanent control loops")
	boss.ai_enabled = true
	await _time(1.1)
	_check(boss.fsm.get_state_id() == &"idle", "Boss resumes after the one-second stagger")
	boss.statuses.clear()
	run.player.reset_movement_at(Vector2(180, 640))
	boss.fsm.transition_to(&"stomp")
	await _time(0.7)
	_check(boss.launched and boss.global_position.y < 590.0, "Phase 2 stomp launches the body upward")
	await _time(0.5)
	_check(boss.shockwave_count == 2 and get_nodes_in_group(&"enemy_hazards").size() == 2, "Landing produces two opposite ground shockwaves")
	var waves: Array[Node] = get_nodes_in_group(&"enemy_hazards")
	_check(waves[0].direction.x * waves[1].direction.x == -1.0, "Shockwaves travel toward opposite room edges")
	await _time(0.15)
	_check(waves[0].position.x != waves[1].position.x, "Shockwaves advance through the arena")
	boss.hurtbox.take_damage(_damage(boss.hurtbox, 999.0))
	await _step(4)
	_check(run.portal_active and not run.reward_chest.locked and not run.room.locked, "Boss defeat unlocks the reward chest, door and portal")
	_check(get_nodes_in_group(&"enemy_hazards").is_empty() and run.living_enemies().is_empty(), "Boss death clears hazards and summoned adds")
	run.player.global_position = run.reward_chest.global_position
	_check(run.reward_chest.interact() and not run.reward_chest.interact(), "Large reward chest opens only once")
	_check(run.win() and run.outcome == &"victory" and run.end_panel.visible, "Activated portal completes the victory flow")
	_check(not run.player.controls_enabled and not run.advance_room(), "Victory blocks further gameplay transitions")


func _test_lifecycle() -> void:
	run.retry()
	await _step(4)
	_freeze_enemies()
	_check(run.room_number == 1 and run.outcome == &"" and run.living_enemies().size() == 3, "Retry restarts Room 1 with fresh enemies")
	_check(run.player.health.current_health == 100.0 and run.gear.inventory.total_shards() == 0 and run.player.energy.current == 100.0, "Retry resets health, run inventory and energy")
	_check(run.player.resonance_controller.get_recipe().id == &"basic" and run.player.resonance_controller.cooldown_remaining() == 0.0, "Retry resets to basic spell and clean cooldown")
	run.player.energy.current = 20.0
	Input.action_press(&"dash")
	await _step(1)
	Input.action_release(&"dash")
	_check(not run.player.motor.is_dashing and not run.player.resonance_controller.can_cast(), "Insufficient energy rejects both dash and spell")
	run.player.energy.reset()
	Input.action_press(&"dash")
	await _step(1)
	Input.action_release(&"dash")
	_check(run.player.motor.is_dashing and run.player.energy.current == 75.0, "Dash commits a single 25-energy cost")
	await _time(0.8)
	_check(run.player.energy.current > 75.0, "Energy regenerates after the authored delay")
	var potion: LootPickup = run.gear.loot.spawn(&"potion", &"health", Vector2(600, 620))
	_check(not potion.collect(), "Full-health potion remains available")
	run.player.hurtbox.take_damage(_damage(run.player.hurtbox, 40.0, 2))
	_check(potion.collect() and run.player.health.current_health == 90.0, "Potion heals thirty HP without exceeding the cap")
	run.gear.modal.open()
	run.player.health.apply_damage(999.0)
	await _step(2)
	_check(run.outcome == &"defeat" and run.end_title.text == "Thất Bại" and run.end_panel.visible, "Lethal damage enters Dead and shows defeat overlay")
	_check(run.player.action_state_machine.get_state_id() == &"dead" and not run.gear.modal.is_open and is_equal_approx(Engine.time_scale, 1.0), "Death closes inventory and restores time scale")
	_check(not run.player.controls_enabled and not run.win(), "Dead Player cannot act or claim victory")
	run.end_panel.get_child(0).get_child(1).pressed.emit()
	await _step(4)
	_check(run.outcome == &"" and run.room_number == 1 and run.player.controls_enabled, "Retry button is bound to a fresh playable run")
	_freeze_enemies()
	for iteration: int in 100:
		run.gear.inventory.add_rune(&"fire")
		run.gear.inventory.equip(0, &"fire")
		run.gear.inventory.swap_slots(0, 3)
		run.gear.inventory.swap_slots(0, 3)
		run.gear.inventory.equip(0, &"")
	_check(run.gear.inventory.total_shards() == 100 and run.gear.inventory.bag[&"fire"] == 100, "Repeated dual-slot operations preserve exact ownership")


func _test_cleanup() -> void:
	_clear_hazards()
	run.gear.loot.clear()
	await _step(4)
	# Warm up pickup resources and signal paths before measuring retained objects.
	await _loot_burst()
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for burst: int in 3:
		await _loot_burst()
		_check(run.gear.loot.get_child_count() == 0, "Loot stress burst %d expires all pickups" % burst)
	_check(int(Performance.get_monitor(Performance.OBJECT_COUNT)) <= objects + 2, "Loot spam retains no pickup Nodes or ownership callbacks")
	_check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= resources + 1, "Loot spam retains no Resource instances")
	print("STRESS alpha loot objects %d -> %d, resources %d -> %d" % [objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)), resources, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
	run.gear.modal.open()
	run.queue_free()
	await _step(4)
	_check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "Scene teardown restores time while inventory is open")
	_check(get_nodes_in_group(&"loot").is_empty() and get_nodes_in_group(&"enemy_hazards").is_empty() and get_nodes_in_group(&"spell_entities").is_empty(), "Run teardown frees loot, hazards and spells")


func _loot_burst() -> void:
	for index: int in 300:
		var pickup: LootPickup = run.gear.loot.spawn(&"rune", &"fire", Vector2(700, 400))
		if pickup != null:
			pickup.life = 0.03
			pickup.automatic = false
	_check(run.gear.loot.get_child_count() <= 96, "Loot emitter respects its 96-pickup cap")
	await _time(0.1)
	await _step(2)


func _freeze_enemies() -> void:
	for enemy: Node2D in run.living_enemies():
		enemy.ai_enabled = false


func _kill_wave() -> void:
	for enemy: Node2D in run.living_enemies():
		enemy.hurtbox.take_damage(_damage(enemy.hurtbox, 999.0))


func _clear_hazards() -> void:
	for node: Node in get_nodes_in_group(&"enemy_hazards"):
		node.queue_free()


func _damage(target: Hurtbox, amount: float, team: int = 1) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = run.player.get_instance_id() if team == 1 else 987654
	event.source_team_id = team
	event.target_id = target.get_actor_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = amount
	return event


func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _step(1)
	event.pressed = false
	Input.parse_input_event(event)


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


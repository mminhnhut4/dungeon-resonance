extends "res://tests/survival_test_base.gd"

func _initialize() -> void:
	suite = "conditions"
	super._initialize()


func test_system() -> void:
	var body: BodyConditionComponent = session.condition
	await _key(KEY_F2)
	_check(body.bleeding and body.cripple_remaining > 4.9, "F2 applies bleeding and crippled leg")
	_check(player.motor.condition_speed_multiplier == 0.6 and player.motor.air_dash_blocked, "Leg wound applies 40% movement loss and air-dash restriction")
	player.global_position = Vector2(780, 300)
	player.motor._contact_valid = false
	_check(not player.motor.can_dash(), "Crippled actor cannot air dash")
	player.reset_movement_at(Vector2(780, 640))
	await _step(4)
	_check(player.motor.can_dash(), "Crippled actor retains grounded dash")
	var hp: float = player.health.current_health
	Input.action_press(&"move_right")
	await _time(1.2)
	Input.action_release(&"move_right")
	_check(body.bleeding and body.bleed_motion > 0.3 and player.health.current_health < hp, "Movement builds bleed severity and deals timed damage")
	_check(not player.hurtbox.invulnerable, "Internal bleeding does not grant contact damage immunity")
	await _time(1.7)
	_check(not body.bleeding and body.bleed_motion == 0.0, "Remaining still for 1.5s automatically bandages the wound")
	body.inflict(&"bleeding")
	level.gear.inventory.consumables[&"bandage"] = 1
	_check(session.use_consumable(&"bandage") and not body.bleeding, "Crafted bandage cures bleeding instantly")
	_check(not session.use_consumable(&"bandage"), "Used bandage cannot be consumed twice")
	body.inflict(&"severe_burn")
	player.health.apply_damage(30.0)
	var restored: float = player.health.heal(20.0)
	_check(restored == 10.0 and player.health.healing_multiplier == 0.5, "Severe burn halves all healing")
	player.resonance_controller.catalyst_a.install_runes([])
	player.resonance_controller.reset_runtime()
	player.energy.reset()
	player.resonance_controller.commit_cast()
	_check(is_equal_approx(player.resonance_controller.cooldown_remaining(), 0.45 * 1.5), "Burn increases committed spell cooldown by fifty percent")
	body.clear()
	_check(player.health.healing_multiplier == 1.0 and player.motor.condition_speed_multiplier == 1.0 and not player.motor.air_dash_blocked, "Clearing conditions restores runtime modifiers")
	body.inflict(&"crippled")
	await _time(5.1)
	_check(body.cripple_remaining == 0.0 and player.motor.condition_speed_multiplier == 1.0, "Leg wound expires after five gameplay seconds")
	var heavy: DamageEvent = _damage(player.hurtbox, 1.0, true)
	player.hurtbox.take_damage(heavy)
	_check(body.bleeding or body.cripple_remaining > 0.0 or body.burn_remaining > 0.0, "A real heavy hit inflicts one body wound")
	body.clear()
	var enemy_body: BodyConditionComponent = level.enemies[0].get_node_or_null("BodyConditionComponent") as BodyConditionComponent
	if enemy_body == null:
		for child: Node in level.enemies[0].get_children():
			if child is BodyConditionComponent:
				enemy_body = child
	_check(enemy_body != null, "Enemies receive their own condition component")
	enemy_body.inflict(&"crippled")
	_check(level.enemies[0].condition_speed_multiplier == 0.6 and player.motor.condition_speed_multiplier == 1.0, "Enemy wound cannot leak into Player movement")
	player.resonance_controller.catalyst_a.install_runes([level.FIRE])
	player.resonance_controller.reset_runtime()
	player.energy.reset()
	player.resonance_controller.commit_cast()
	_check(body.stress > 0.0, "Ancient rune casting increases mental stress")
	body.add_stress(100.0, &"phantoms")
	_check(body.stress == 100.0 and body.break_kind == &"phantoms", "Stress clamps at one hundred and starts a mental break")
	_check(get_nodes_in_group(&"phantoms").size() == 3, "Phantom break spawns three bounded fake targets")
	_check(get_nodes_in_group(&"phantoms").all(func(node: Node) -> bool: return node is Node2D and not node is PhysicsBody2D), "Phantoms have no real health, loot or collision")
	body.clear()
	body.add_stress(100.0, &"berserk")
	_check(player.equipped_weapon.outgoing_multiplier == 1.5, "Berserk grants fifty percent attack damage")
	player.reset_movement_at(Vector2(780, 640))
	player.equipped_weapon.start_combo()
	var berserk_damage: float = player.equipped_weapon.snapshot.base_damage
	hp = player.health.current_health
	player.equipped_weapon.advance(0.4)
	player.equipped_weapon.cancel_combo()
	_check(player.health.current_health == hp - 5.0, "An actual missed swing deals five self damage")
	hp = player.health.current_health
	body._on_swing(true)
	_check(player.health.current_health == hp, "A confirmed hit avoids the Berserk penalty")
	body.break_remaining = 0.01
	await _step(3)
	_check(body.break_kind == &"" and player.equipped_weapon.outgoing_multiplier == 1.0 and berserk_damage >= 15.0, "Mental break ends and restores weapon multiplier")
	await _time(8.1)
	_check(get_nodes_in_group(&"phantoms").is_empty(), "Expired phantom visuals are freed")
	await _key(KEY_C)
	_check(session.panel.is_open and session.panel.details.text.contains("Áp lực"), "C opens wound and crafting details")
	await _key(KEY_TAB)
	_check(not session.panel.is_open and level.gear.modal.is_open, "Inventory and body panels have exclusive control ownership")
	level.gear.modal.close()

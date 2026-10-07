extends "res://tests/survival_test_base.gd"


func _initialize() -> void:
	suite = "relics"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.energy.enabled = false
	var relics: RelicRuntime = level.content.relics
	await _key(KEY_F7)
	_check(relics.owned.size() == 4 and relics.equipped.size() == 3, "F7 grants four independent relics but equips at most three")
	_check(level.illusory_wall.is_open and level.bramble_gate.is_open, "F7 opens both secret environment barriers")
	await _key(KEY_F7)
	_check(relics.owned.size() == 4, "Repeated debug grant cannot duplicate relic ownership")
	_check(not relics.equip(&"unknown", 0) and not relics.equip(&"phantom_mirror", 3), "Invalid relic IDs and fourth slots are rejected")
	player.health.current_health = 80.0
	level.dummy_a.health.current_health = 1.0
	var attack := AttackSnapshot.new()
	attack.source_id = player.get_instance_id()
	attack.attack_id = CombatIds.next_id()
	attack.root_event_id = attack.attack_id
	attack.weapon_definition = Player.SWORD
	attack.base_damage = 10.0
	player.equipped_weapon._on_contact(level.dummy_a.hurtbox, attack)
	_check(player.health.current_health == 82.0, "Bloodstone heals exactly two HP for an actual melee killing blow")
	attack.weapon_definition = load("res://data/weapons/storm_arcane_staff.tres")
	attack.attack_id = CombatIds.next_id()
	attack.root_event_id = attack.attack_id
	level.dummy_a.hurtbox.set_invulnerable(false)
	level.dummy_a.health.current_health = 1.0
	player.equipped_weapon._on_contact(level.dummy_a.hurtbox, attack)
	_check(player.health.current_health == 82.0, "Ranged staff kills cannot trigger melee lifesteal")
	player.reset_movement_at(Vector2(780, -400))
	var motor := player.motor as BuildPlayerMotor
	_check(motor.extra_air_dashes == 1 and motor.can_dash(), "Feather extends the inherited motor interface")
	motor.start_dash(1.0, 1.0)
	motor.end_dash()
	motor.dash_cooldown_remaining = 0.0
	_check(motor.can_dash(), "Feather grants one additional airborne dash")
	motor.start_dash(1.0, 1.0)
	motor.end_dash()
	motor.dash_cooldown_remaining = 0.0
	_check(not motor.can_dash(), "Third airborne dash is blocked before landing")
	player.reset_movement_at(Vector2(780, 640))
	await _step(20)
	_check(motor.air_dashes_used == 0 and motor.can_dash(), "Landing resets the extra dash budget")
	level.content.select_recipe(&"overload")
	var controller: ResonanceController = player.resonance_controller
	controller.reset_runtime()
	var spell: SpellSnapshot = controller.commit_cast()
	_check(spell.damage == 15.0 and spell.explosion_damage == 37.5, "Seal multiplies resonance impact and explosion by twenty-five percent")
	_check(is_equal_approx(controller.cooldown_remaining(), 0.95 * 1.15), "Seal imposes a separate fifteen-percent cooldown cost")
	controller.catalyst_a.install_runes([])
	controller.reset_runtime()
	spell = controller.commit_cast()
	_check(spell.damage == 14.0, "Seal does not boost a basic bolt")
	_check(relics.equip(&"phantom_mirror", 0) and relics.equipped.size() == 3, "Owned fourth relic replaces one passive slot")
	player.reset_movement_at(Vector2(780, 640))
	motor.start_dash(1.0, 1.0)
	player.hurtbox.set_invulnerable(true)
	var event: DamageEvent = _damage(player.hurtbox, 15.0)
	var before: int = relics.dodge_count
	var result: DamageResult = player.hurtbox.take_damage(event)
	_check(result.blocked and relics.dodge_count == before + 1, "A real blocked enemy hit during the first dash frames triggers Perfect Dodge")
	player.hurtbox.take_damage(event)
	_check(relics.dodge_count == before + 1, "Perfect Dodge deduplicates the same enemy root")
	_check(level.spell_executor.get_children().any(func(node: Node) -> bool: return node is PhantomEcho), "Perfect Dodge leaves a visible finite phantom")
	motor.end_dash()
	var explosions: int = level.spell_executor.explosion_count
	await _time(0.5)
	_check(level.spell_executor.explosion_count == explosions + 1 and not level.spell_executor.get_children().any(func(node: Node) -> bool: return node is PhantomEcho), "Phantom explodes once and releases its runtime data")
	player.reset_movement_at(Vector2(780, 640))
	var attacker: SlimeEnemy = level.enemies[0]
	attacker._facing = 1.0
	attacker.global_position = player.global_position - Vector2(26, 0)
	await _step(3)
	motor.start_dash(1.0, 1.0)
	player.hurtbox.set_invulnerable(true)
	await _step(1)
	before = relics.dodge_count
	attacker._start_bite()
	attacker.bite_hitbox.sample_contacts()
	_check(relics.dodge_count == before + 1, "Actual physics hitbox detects a perfectly dodged bite despite invulnerability")
	attacker.bite_hitbox.deactivate()
	motor.end_dash()
	relics.clear_equipped()
	_check(motor.extra_air_dashes == 0 and controller.relic_damage_multiplier == 1.0 and controller.relic_cooldown_multiplier == 1.0, "Removing passives restores all neutral modifiers")
	_check(RelicRuntime.CATALOG[2].magnitude == 0.25 and Player.SWORD.base_damage == 10.0, "Passive effects never mutate shared relic or weapon definitions")

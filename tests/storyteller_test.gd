extends "res://tests/survival_test_base.gd"

func _initialize() -> void:
	suite = "storyteller"
	super._initialize()


func test_system() -> void:
	var director: StorytellerDirector = session.director
	var threat: float = director.threat_points()
	_check(is_equal_approx(threat, 65.0), "Threat preserves 35 base, three shards and Common starter weapon at full HP")
	player.health.apply_damage(50.0)
	_check(director.threat_points() < threat and is_equal_approx(director.threat_points(), 45.5), "Low health reduces scheduled threat budget")
	player.health.reset_health()
	level.gear.inventory.items[level.gear.inventory.equipped_weapon_uid].quality = GearItem.Quality.LEGENDARY
	_check(director.threat_points() > threat and director.threat_points() <= 250.0, "Better gear increases threat within the hard cap")
	_check(not director.trigger(&"unknown"), "Unknown incident cannot begin")
	_check(director.trigger(&"toxic") and not director.trigger(&"eclipse"), "Only one incident may be active")
	_check(session.announcement.text.contains("ĐỘC KHÍ"), "Incident produces a visible warning")
	var hp: float = player.health.current_health
	var enemy_hp: float = level.enemies[0].health.current_health
	await _time(1.1)
	_check(player.health.current_health < hp and level.enemies[0].health.current_health < enemy_hp, "Miasma damages both Player and enemy through Hurtbox")
	_check(session.condition.stress > 0.0, "Remaining in toxic air increases stress")
	player.global_position = director.shrine_position
	hp = player.health.current_health
	await _time(1.1)
	_check(player.health.current_health == hp and director.is_purified(player.global_position), "Purifying altar shelters nearby actors")
	player.global_position = Vector2(780, 640)
	player.resonance_controller.catalyst_a.install_runes([level.WIND])
	player.resonance_controller.reset_runtime()
	player.energy.reset()
	player.resonance_controller.commit_cast()
	_check(director.wind_clear_remaining == 3.0, "Wind cast clears a temporary local pocket")
	hp = player.health.current_health
	await _time(1.1)
	_check(player.health.current_health == hp, "Wind pocket blocks poison during its lifetime")
	director.end_incident()
	_check(director.current_incident == &"" and director.recovery_remaining > 0.0, "Ending restores calm and schedules recovery")
	director.trigger(&"swarm")
	_check(level.enemies[0].enraged and level.enemies[0].attack_rate_multiplier == 1.4 and level.enemies[0].bite_hitbox.collision_mask == 24, "Infestation speeds attacks by 40% and targets both factions")
	_check(level.enemies[0].get_node("Eyes").default_color.r == 1.0, "Manhunter eyes turn red immediately")
	var attacker: SlimeEnemy = level.enemies[0]
	var victim: SlimeEnemy = level.enemies[1]
	attacker.global_position = Vector2(880, 640)
	victim.global_position = Vector2(910, 640)
	attacker._choose_manhunter_target()
	_check(attacker.player == victim, "Manhunter selects the nearest enemy rather than only Player")
	hp = victim.health.current_health
	var attack := AttackSnapshot.new()
	attack.source_id = attacker.get_instance_id()
	attack.attack_id = CombatIds.next_id()
	attack.root_event_id = attack.attack_id
	attacker._bite_contact(victim.hurtbox, attack)
	_check(victim.health.current_health == hp - 15.0, "Enraged bite really damages its former ally")
	director.end_incident()
	_check(not attacker.enraged and attacker.player == player and attacker.hurtbox.team_id == 2, "Incident end restores faction, target and attack rate")
	player.energy.reset()
	player.resonance_controller.catalyst_a.install_runes([level.FIRE])
	player.resonance_controller.reset_runtime()
	var normal: SpellSnapshot = player.resonance_controller.commit_cast()
	director.trigger(&"eclipse")
	player.energy.reset()
	player.resonance_controller.reset_runtime()
	var eclipse: SpellSnapshot = player.resonance_controller.commit_cast()
	_check(is_equal_approx(eclipse.damage, normal.damage * 2.0) and is_equal_approx(eclipse.burn_damage, normal.burn_damage * 2.0), "Eclipse doubles Fire damage and burn at commit")
	level.gear.inventory.equip(3, &"fire")
	player.equipped_weapon.start_combo()
	var melee_damage: float = player.equipped_weapon.snapshot.base_damage
	player.equipped_weapon.cancel_combo()
	director.end_incident()
	player.equipped_weapon.critical_rng.seed = 7
	player.equipped_weapon.start_combo()
	_check(player.equipped_weapon.element_damage_multiplier == 1.0 and melee_damage >= player.equipped_weapon.snapshot.base_damage, "Eclipse also affects weapon elements and restores its modifier")
	player.equipped_weapon.cancel_combo()
	profile.add_souls(100)
	director.trigger(&"smuggler")
	_check(is_instance_valid(session.merchant) and session.merchant.position == Vector2(90, 366), "Temporary smuggler appears in the hidden room")
	_check(session.trade(&"souls") and profile.souls == 85, "Black market trades finite souls for a Masterwork item")
	_check(not session.trade(&"souls") and profile.souls == 85, "Merchant stock cannot be bought twice")
	director.end_incident()
	await _step(2)
	_check(not is_instance_valid(session.merchant), "Smuggler is removed at incident end")
	director.trigger(&"smuggler")
	var maximum: float = player.health.maximum_health
	_check(session.trade(&"blood") and player.health.maximum_health == maximum - 10.0, "Alternate payment spends run maximum health")
	director.end_incident()
	director.style = &"steady"
	director.automatic = true
	director.recovery_remaining = 0.01
	await _step(3)
	_check(director.current_incident == &"toxic", "Steady storyteller starts its predictable cycle automatically")
	director.incident_remaining = 0.01
	await _step(3)
	_check(director.current_incident == &"", "Incident duration expires without lingering effects")
	await _key(KEY_F1)
	_check(director.current_incident in [&"toxic", &"swarm", &"eclipse"], "F1 selects an immediate debug incident")

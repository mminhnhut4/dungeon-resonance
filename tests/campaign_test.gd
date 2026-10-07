extends "res://tests/survival_test_base.gd"


func _initialize() -> void:
	suite = "campaign"
	super._initialize()


func test_system() -> void:
	level.queue_free()
	await _step(4)
	var campaign := preload("res://scenes/linear_campaign.tscn").instantiate() as LinearCampaign
	campaign.profile = profile
	root.add_child(campaign)
	campaign.content.qa_tools_enabled = true # Explicit private fixture capability.
	current_scene = campaign
	preload("res://tests/neutral_equipment_fixture.gd").install(campaign.gear)
	campaign.survival.director.automatic = false
	campaign.feedback.hit_stop_seconds = 0.0
	await _step(20)
	_check(campaign.stage == 1 and campaign.living_enemies().size() == 3 and campaign.room.locked, "Campaign begins at the locked Slime foyer")
	_check(not campaign.advance_room(), "Foyer cannot be skipped before clearing enemies")
	for enemy: Node2D in campaign.living_enemies():
		enemy.ai_enabled = false
		enemy.hurtbox.take_damage(_damage(enemy.hurtbox, 999.0))
	await _step(4)
	_check(not campaign.room.locked, "Foyer clear unlocks the next stage")
	campaign.player.health.current_health = 73.0
	campaign.gear.inventory.add_rune(&"fire")
	campaign.gear.inventory.add_rune(&"ice")
	campaign.gear.inventory.equip_catalyst_set([&"fire", &"ice"])
	campaign.content.relics.acquire(&"gale_feather")
	campaign.content.cycle_weapon()
	var weapon: WeaponDefinition = campaign.player.equipped_weapon.definition
	var uid: int = campaign.gear.inventory.equipped_weapon_uid
	_check(campaign.advance_room() and campaign.stage == 2, "Exit enters a separate exploration stage 1.5")
	await _step(5)
	_check(campaign.player.health.current_health == 73.0 and campaign.player.equipped_weapon.definition == weapon, "Stage transition preserves HP and the equipped weapon")
	_check(campaign.gear.inventory.equipped_weapon_uid == uid and campaign.player.resonance_controller.get_recipe().id == &"thermal_shock", "Stage transition preserves unique item identity and exact rune loadout")
	_check(campaign.content.relics.equipped.size() == 1, "Passive relic slots persist between stages")
	_check(campaign.living_enemies().is_empty() and campaign.secret_chest.relic_reward, "Exploration room contains a guarded relic chest without combat waves")
	campaign.content.unlock_secret()
	campaign.player.relocate(Vector2(90, 366))
	await _step(4)
	_check(campaign.secret_chest.interact(), "Secret chest can be opened after its barriers are cleared")
	_check(campaign.gear.loot.get_children().any(func(node: Node) -> bool: return node.kind == &"relic"), "Secret reward spawns a collectible relic resource")
	var count: int = campaign.gear.loot.spawned_total
	_check(not campaign.secret_chest.interact() and campaign.gear.loot.spawned_total == count, "Secret chest cannot duplicate its loot")
	_check(campaign.advance_room() and campaign.stage == 3, "Exploration exit enters the mutant elite arena")
	await _step(20)
	_check(campaign.living_enemies().size() == 2 and campaign.living_enemies()[0] is MutantSlime, "Elite room instantiates two distinct mutant enemies")
	var mutant := campaign.living_enemies()[0] as MutantSlime
	_check(mutant.health.maximum_health == 120.0 and mutant.health.current_health == 120.0 and mutant.scale == Vector2(2, 2), "Mutant owns doubled geometry and starts with one hundred twenty HP")
	mutant.ai_enabled = false
	mutant.fire_projectile()
	_check(mutant.shots_fired == 1 and get_nodes_in_group(&"enemy_hazards").size() == 1, "Mutant can emit a finite elemental projectile")
	var hazard := get_nodes_in_group(&"enemy_hazards")[0] as EnemyHazard
	campaign.player.hurtbox.sanctuary_safe = false
	campaign.player.hurtbox.set_invulnerable(false)
	campaign.player.damage_grace_remaining = 0.0
	var hp: float = campaign.player.health.current_health
	hazard._hit(campaign.player.hurtbox, hazard.attack)
	_check(campaign.player.health.current_health == hp - 22.0 and (campaign.player.hurtbox.damage_resolver.status_controller as ElementStatusController).poison_count == 1, "Poison mutant projectile resolves Player damage and poison")
	for wave: int in 2:
		for enemy: Node2D in campaign.living_enemies():
			enemy.ai_enabled = false
			enemy.hurtbox.take_damage(_damage(enemy.hurtbox, 999.0))
		await _step(4)
	_check(not campaign.room.locked and profile.souls == 12, "Two mutant waves clear the room and award finite elite souls")
	_check(campaign.advance_room() and campaign.stage == 4 and campaign.boss != null, "Elite exit enters the complete two-phase Golem fight")
	await _step(5)
	campaign.boss.ai_enabled = false
	campaign.boss.hurtbox.take_damage(_damage(campaign.boss.hurtbox, 251.0))
	_check(campaign.boss.phase == 2 and campaign.living_enemies().size() == 3, "Campaign boss starts phase two and summons two adds exactly once")
	campaign.boss.hurtbox.take_damage(_damage(campaign.boss.hurtbox, 999.0))
	await _step(5)
	_check(campaign.portal_active and not campaign.reward_chest.locked and profile.souls == 37, "Boss defeat opens rewards and victory portal, preserving souls")
	_check(campaign.win() and campaign.outcome == &"victory", "Victory portal completes the campaign loop")
	campaign.queue_free()
	await _step(5)
	# The standalone test room also transfers its existing item ledger through F8.
	level = preload("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	level.content.qa_tools_enabled = true # Explicit private fixture capability.
	current_scene = level
	preload("res://tests/neutral_equipment_fixture.gd").install(level.gear)
	level.survival.profile = profile
	level.survival.director.automatic = false
	level.player.health.current_health = 61.0
	level.content.cycle_weapon()
	level.content.select_recipe(&"neurotoxin")
	level.content.relics.acquire(&"phantom_mirror")
	var inventory: GearInventory = level.gear.inventory
	uid = inventory.equipped_weapon_uid
	await _key(KEY_F8)
	await _step(5)
	campaign = current_scene as LinearCampaign
	_check(campaign != null and campaign.stage == 4, "Standalone test F8 loads the boss campaign")
	_check(campaign.player.health.current_health == 61.0 and campaign.gear.inventory == inventory and campaign.gear.inventory.equipped_weapon_uid == uid, "Standalone F8 retains HP and the existing inventory ledger")
	_check(campaign.player.resonance_controller.get_recipe().id == &"neurotoxin" and campaign.content.relics.equipped[0].id == &"phantom_mirror", "Standalone F8 retains exact rune and relic loadout")
	campaign.queue_free()
	await _step(5)
	_check(get_nodes_in_group(&"enemy_hazards").is_empty() and get_nodes_in_group(&"loot").is_empty(), "Campaign teardown frees room hazards and loot")
	# Debug F8 should preserve current run state when jumping within a campaign.
	campaign = preload("res://scenes/linear_campaign.tscn").instantiate() as LinearCampaign
	campaign.profile = profile
	root.add_child(campaign)
	campaign.content.qa_tools_enabled = true # Explicit private fixture capability.
	current_scene = campaign
	preload("res://tests/neutral_equipment_fixture.gd").install(campaign.gear)
	campaign.survival.director.automatic = false
	await _step(5)
	campaign.player.health.current_health = 65.0
	await _key(KEY_F8)
	_check(campaign.stage == 4 and campaign.player.health.current_health == 65.0, "Physical F8 jumps to Boss while retaining HP")
	campaign.queue_free()
	await _step(5)
	await _campaign_cycle()
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for iteration: int in 6:
		await _campaign_cycle()
	print("STRESS content campaign objects %d -> %d, resources %d -> %d" % [objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)), resources, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
	_check(int(Performance.get_monitor(Performance.OBJECT_COUNT)) <= objects + 2, "Repeated content campaigns retain no growing object population")
	_check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= resources + 1, "Repeated content campaigns release item and spell runtime resources")
	_check(get_nodes_in_group(&"spell_entities").is_empty() and get_nodes_in_group(&"loot").is_empty(), "Content room transitions release all spells and pickups")


func _campaign_cycle() -> void:
	var run := preload("res://scenes/linear_campaign.tscn").instantiate() as LinearCampaign
	run.profile = profile
	root.add_child(run)
	run.content.qa_tools_enabled = true # Explicit private fixture capability.
	current_scene = run
	preload("res://tests/neutral_equipment_fixture.gd").install(run.gear)
	run.survival.set_enabled(false)
	run.player.energy.enabled = false
	run.feedback.hit_stop_seconds = 0.0
	run.content.unlock_secret()
	for stage: int in [2, 3, 4]:
		run.enter_stage(stage)
		for enemy: Node2D in run.living_enemies():
			enemy.ai_enabled = false
		for id: StringName in ContentSession.PAIR_IDS:
			run.content.select_recipe(id)
			run.player.resonance_controller.reset_runtime()
			var spell: SpellSnapshot = run.player.resonance_controller.commit_cast()
			run.executor.spawn_cast(spell)
			run.gear.loot.spawn(&"rune", &"ice", Vector2(1000, 640))
		await _step(3)
	run.queue_free()
	await _step(6)

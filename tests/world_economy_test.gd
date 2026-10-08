extends "res://tests/survival_test_base.gd"
## Real atomic save, immutable recipes and one-UID Hub/run ownership.
class FaultProfile extends SanctuaryProfile:
	var fail_write: bool = false
	func _open_writer(path: String) -> FileAccess:
		return null if fail_write else super._open_writer(path)

var bank: FaultProfile
var economy: EconomySession
var carried: GearInventory

func _initialize() -> void:
	suite = "world_economy"
	super._initialize()

func test_system() -> void:
	session.set_enabled(false)
	carried = HubPreparation.starter_inventory()
	bank = FaultProfile.new()
	bank.save_path = "user://verification/world_%d_%d/profile.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	bank.souls = 2000
	bank.coins = 5000
	economy = EconomySession.new()
	economy.initialize(bank, carried)
	economy.persist_safe_inventory = true
	_check(economy.forge_recipes.size() == 40 and economy._save_safe(), "All forty immutable smith recipes register and starter wardrobe commits")
	_test_progression()
	_test_stones()
	_test_forge()
	_test_codec()
	await _test_drops()
	await _test_safe_clicks()
	await _test_flow()
	bank = null
	economy = null
	carried = null

func _test_progression() -> void:
	for id: StringName in WorldProgressionCatalog.UPGRADES:
		var before: int = bank.souls
		bank.fail_write = true
		_check(not economy.buy_upgrade(id) and bank.souls == before and bank.permanent_upgrades[id] == 0, "Failed permanent %s purchase rolls Soul cost and level back" % id)
		bank.fail_write = false
		_check(economy.buy_upgrade(id) and bank.permanent_upgrades[id] == 1, "Permanent %s purchase commits once" % id)
	bank.boss_proofs[&"golem"] = 3
	_check(economy.accept_bounty(&"golem_hunt") and not economy.accept_bounty(&"golem_hunt") and not economy.quote_bounty(&"golem_hunt")["can_claim"], "Bounty starts at acceptance and excludes historical Boss victories")
	bank.fail_write = true
	_check(not bank.record_boss_defeat("new-boss") and bank.boss_proofs[&"golem"] == 3 and not bank.boss_receipts.has("new-boss"), "Boss proof receipt and counter roll back on save failure")
	bank.fail_write = false
	_check(bank.record_boss_defeat("new-boss") and not bank.record_boss_defeat("new-boss") and bank.boss_proofs[&"golem"] == 4, "One Boss receipt cannot advance bounty twice")
	bank.fail_write = true
	_check(not economy.claim_bounty(&"golem_hunt") and not bank.bounty_claimed and not bank.unlocked_weapons.has(&"ancient_sword_bounty"), "Failed bounty reward rolls quest and unlock back")
	bank.fail_write = false
	_check(economy.claim_bounty(&"golem_hunt") and not economy.claim_bounty(&"golem_hunt") and bank.unlocked_weapons.has(&"ancient_sword_bounty"), "Bounty unlocks the four-hit sword variant exactly once")
	var progression := PermanentProgressionComponent.new()
	level.add_child(progression)
	var before_hp: float = player.health.maximum_health
	var before_regen: float = player.energy.regeneration
	var before_mana: float = player.energy.maximum
	var before_energy: float = player.energy.current
	var before_health: float = player.health.current_health
	progression.initialize(level.gear, bank)
	_check(is_equal_approx(player.energy.maximum, before_mana + 10) and player.energy.current == before_energy, "Permanent mana increases capacity without refilling current energy")
	_check(is_equal_approx(player.health.maximum_health, before_hp + 10) and is_equal_approx(player.energy.regeneration, before_regen + 2) and level.gear.inventory.catalyst_capacity == 4 and player.health.current_health == before_health, "Opt-in progression adds capacity/regen without healing or touching movement")
	progression.refresh()
	level.gear.equipment_stats.reset_base_stats()
	_check(is_equal_approx(player.energy.maximum, before_mana + 10), "Repeated refresh and base reset preserve one mana bonus")
	var restored := SanctuaryProfile.new()
	restored.save_path = bank.save_path
	_check(restored.load_profile() and restored.permanent_upgrades[&"max_mana"] == 1, "Purchased mana survives a real cold profile reload")
	_check(is_equal_approx(player.health.maximum_health, before_hp + 10) and level.gear.inventory.catalyst_capacity == 4, "Repeated permanent rebuild cannot stack bonuses")
	progression.queue_free()

func _test_stones() -> void:
	bank.material_stash[&"enhancement_stone_1"] = 125
	_check(economy.combine_stones(1, 25) and economy.combine_stones(2, 5) and economy.combine_stones(3) and bank.material_stash[&"enhancement_stone_1"] == 0 and bank.material_stash[&"enhancement_stone_4"] == 1, "Recursive 125 grade-one stones conserve exactly one grade-four stone")
	_check(not economy.combine_stones(6) and not economy.combine_stones(0) and not economy.combine_stones(1, -1), "No grade-seven stone or negative combining output exists")
	bank.material_stash[&"enhancement_stone_1"] = 20
	bank.material_stash[&"enhancement_stone_2"] = MaterialCatalog.MAX_COUNT
	var previous: Dictionary = bank.material_stash.duplicate()
	_check(not economy.combine_stones(1) and bank.material_stash == previous, "Stone destination cap rejects before consuming five inputs")
	bank.material_stash[&"enhancement_stone_2"] = 20
	bank.fail_write = true
	previous = bank.material_stash.duplicate()
	_check(not economy.combine_stones(1) and bank.material_stash == previous, "Failed stone combine rolls both grades back")
	bank.fail_write = false
	var sword: GearItem = carried.items[carried.equipped_weapon_uid]
	var definition: EquipmentData = sword.equipment_definition
	var base_damage: float = definition.moveset.base_damage
	var factor: float = sword.damage_factor()
	for grade: int in range(1, 7): bank.material_stash[StringName("enhancement_stone_%d" % grade)] = 20
	bank.fail_write = true
	var before_coins: int = bank.coins
	previous = bank.material_stash.duplicate()
	_check(not economy.enhance_item(sword.uid) and sword.enhancement_level == 0 and bank.coins == before_coins and bank.material_stash == previous, "Failed enhancement preserves level, coins and the exact grade-one stone")
	bank.fail_write = false
	for level_index: int in range(1, 13):
		var quote: Dictionary = economy.quote_enhance(sword.uid)
		_check(quote["stone_grade"] == ceili(level_index / 2.0) and economy.enhance_item(sword.uid) and sword.enhancement_level == level_index, "Enhancement +%d consumes the appropriate grade with guaranteed success" % level_index)
	_check(not economy.enhance_item(sword.uid) and sword.quality == GearItem.Quality.COMMON and sword.equipment_definition == definition and definition.moveset.base_damage == base_damage and is_equal_approx(sword.damage_factor(), factor + 0.36), "+12 adds exactly 36% base damage, caps there and preserves shared rarity/moveset")

func _fill_costs(recipe: ForgeRecipe) -> void:
	for id: StringName in recipe.costs(): bank.material_stash[id] = recipe.costs()[id] + 10

func _test_forge() -> void:
	_check(not economy.quote_buy(&"world_saber", 0)["can_buy"] and not economy.quote_forge(&"world_saber_very_rare")["can_forge"], "Unlearned family cannot enter shop or smith bypass")
	_check(bank.learn_blueprint(&"world_saber") and not bank.learn_blueprint(&"world_saber"), "One family blueprint learns once for all four forge qualities")
	_check(economy.buy_weapon(&"common_sword", 0) and economy.buy_weapon(&"world_saber", 1) and not economy.buy_weapon(&"world_saber", 2), "Kael sells basic and learned Common/Rare, never Very Rare+ gear")
	bank.fail_write = true
	var buy_count: int = carried.items.size()
	var buy_coins: int = bank.coins
	_check(not economy.buy_weapon(&"starter_gloves", 1) and carried.items.size() == buy_count and bank.coins == buy_coins, "Failed Common/Rare shop commit restores payment and removes the provisional UID")
	bank.fail_write = false
	var recipe: ForgeRecipe = economy.forge_recipes[&"world_saber_very_rare"]
	_fill_costs(recipe)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var previous_rng: int = rng.state
	var coins: int = bank.coins
	var mats: Dictionary = bank.material_stash.duplicate()
	var count: int = carried.items.size()
	bank.fail_write = true
	var result: Dictionary = economy.forge(recipe.id, rng)
	_check(not result["committed"] and carried.items.size() == count and bank.coins == coins and bank.material_stash == mats and rng.state == previous_rng, "Failed forge disk transaction restores UID ledger, costs and RNG state")
	bank.fail_write = false
	result = economy.forge(recipe.id, rng)
	var item: GearItem = carried.items.get(int(result["uid"]))
	_check(result["committed"] and result["success"] and item != null and item.quality == 2 and item.source == &"crafted" and item.can_equip(), "Smith creates usable Very Rare runtime gear without modifying its definition")
	var divine: ForgeRecipe = economy.forge_recipes[&"world_saber_divine"]
	_fill_costs(divine)
	_check(divine.costs().has(&"origin_divine_stone") and economy.forge_recipes[&"world_saber_legendary"].costs().has(&"origin_divine_stone"), "Legendary and Divine require future-special-Boss origin stone")
	for seed_value: int in range(100):
		rng.seed = seed_value
		if rng.randf() >= 0.5:
			rng.seed = seed_value
			break
	mats = bank.material_stash.duplicate()
	count = carried.items.size()
	result = economy.forge(divine.id, rng)
	var all_consumed: bool = true
	for id: StringName in divine.costs(): all_consumed = all_consumed and bank.material_stash[id] == int(mats[id]) - divine.costs()[id]
	_check(result["committed"] and not result["success"] and carried.items.size() == count and all_consumed and bank.learned_blueprints.has(&"world_saber"), "Divine 50% failure consumes every quoted ingredient while retaining learned recipe")
	bank.material_stash[&"healing_herb"] = 3
	bank.material_stash[&"linen_fiber"] = 2
	bank.material_stash[&"detox_root"] = 2
	bank.material_stash[&"dust"] = 2
	_check(economy.craft_consumable(&"potion") and economy.craft_consumable(&"bandage") and economy.craft_consumable(&"antidote") and carried.consumables[&"potion"] == 1 and carried.consumables[&"bandage"] == 1 and carried.consumables[&"antidote"] == 1, "Survival recipes consume their own farmed ingredients into finite carried bottles/bandages")
	var hp: float = player.health.current_health
	_check(economy.buy_consumable(&"potion") and carried.consumables[&"potion"] == 2 and player.health.current_health == hp, "Potion purchase stores a bottle instead of healing or buying arbitrary IDs")

func _test_codec() -> void:
	var snapshot: Dictionary = GearInventoryCodec.encode(carried)
	var restored: GearInventory = GearInventoryCodec.decode(JSON.parse_string(JSON.stringify(snapshot)))
	_check(restored != null and GearInventoryCodec.encode(restored) == snapshot and restored.items[restored.equipped_weapon_uid].enhancement_level == 12, "Actual safe wardrobe survives JSON round trip with every UID, destination, enhancement and cost ledger")
	_check(CombatIds.next_id() > restored.items.keys().max(), "Deserialized maximum UID reserves the next combat/item identity")
	var malformed: Dictionary = snapshot.duplicate(true)
	malformed["items"].append(malformed["items"][0])
	_check(not GearInventoryCodec.valid(malformed), "Duplicate saved UIDs are rejected before rebuilding ownership")
	malformed = snapshot.duplicate(true)
	malformed["equipment"][1] = malformed["equipment"][0]
	_check(not GearInventoryCodec.valid(malformed), "Saved weapon cannot occupy two destinations or an armor slot")
	malformed = snapshot.duplicate(true)
	malformed["items"][0]["enhancement_level"] = 13
	_check(not GearInventoryCodec.valid(malformed), "Saved +13 cannot bypass the enhancement cap")
	malformed = snapshot.duplicate(true)
	malformed["items"][0]["equipment"] = "res://scripts/actors/player/player.gd"
	_check(not GearInventoryCodec.valid(malformed), "Wardrobe resource paths cannot load scripts outside the immutable equipment catalog")
	malformed = snapshot.duplicate(true)
	malformed["run_coins"] = -1
	_check(not GearInventoryCodec.valid(malformed), "Negative carried coin ledger cannot be loaded or banked")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(bank.save_path))
	payload["hub_inventory"] = {"items": "malformed"}
	_write_json(bank.save_path, payload)
	var reader := SanctuaryProfile.new()
	reader.save_path = bank.save_path
	_check(reader.load_profile() and reader.hub_inventory.is_empty() and reader.hub_inventory_quarantined and reader.souls == bank.souls and reader.learned_blueprints.has(&"world_saber"), "Malformed wardrobe quarantines UIDs while retaining permanent NPC/blueprint/Soul progress")
	_check(not economy._save_safe() and bank.read_only, "A stale writer cannot silently overwrite an externally changed wardrobe fixture")
	_check(bank.load_profile() and economy._save_safe(), "After explicit reload, valid live safe inventory can replace quarantined wardrobe")
	var original_progress: Dictionary = payload["world_progress"].duplicate(true)
	for invalid: Variant in [{"upgrades": {"max_hp": 6}}, {"upgrades": {"rune_capacity": 3}}, {"upgrades": {"mana_regen": 1.5}}, {"blueprints": ["world_staff", "world_staff"]}, {"blueprints": ["../escape"]}, {"boss_proofs": {"golem": -1}}, {"bounty_accepted": "yes"}]:
		payload["world_progress"] = invalid
		var isolated_path: String = bank.save_path.get_base_dir() + "/invalid.json"
		_write_json(isolated_path, payload)
		reader.save_path = isolated_path
		var previous_souls: int = reader.souls
		_check(not reader.load_profile() and reader.souls == previous_souls, "Invalid World optional fields cannot mutate loaded permanent progress: %s" % str(invalid))
	payload["world_progress"] = original_progress

func _write_json(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _test_drops() -> void:
	var table: DropTableResource = preload("res://data/loot/world_drop_table.tres").duplicate(true) as DropTableResource
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var known: Array[StringName] = table.blueprint_ids.duplicate()
	known.erase(&"world_staff")
	_check(table.choose_blueprint(0.004999, rng, known, true) == &"world_staff" and table.choose_blueprint(0.005, rng, known, true) == &"" and table.choose_blueprint(0.0, rng, known, false) == &"", "The complete ten-family blueprint pool uses one 0.5% elite/Boss gate and prioritizes the unknown family")
	_check(table.material_pool(&"bloodwing_bat").has(&"detox_root") and not table.material_pool(&"bloodwing_bat").has(&"armor_scrap") and table.material_pool(&"ancient_guard").has(&"armor_scrap"), "Monster-specific material pools distinguish Bat survival ingredients from Guard salvage")
	var loot := LootSpawner.new()
	loot.player = player
	loot.inventory = carried
	loot.permanent_profile = bank
	loot.drop_table = table
	level.add_child(loot)
	loot.rng.seed = 17
	table.none_chance = 1.0
	table.blueprint_chance_total = 0.0
	loot.enemy_drop(Vector2(100, 640), &"slime")
	_check(loot.get_child_count() == 0, "An unlucky monster can drop absolutely nothing, including no guaranteed Soul or coin")
	table.blueprint_chance_total = 1.0
	loot.enemy_drop(Vector2(100, 640), &"runic_champion", true)
	_check(loot.get_child_count() == 1 and (loot.get_child(0) as LootPickup).kind == &"blueprint", "Blueprint probability is rolled before empty-survival outcome rather than multiplied by 65%")
	loot.clear()
	table.blueprint_chance_total = 0.0
	table.none_chance = 0.0
	loot.enemy_drop(Vector2(100, 640), &"golem", false, true)
	var souls: int = 0
	var origin: bool = false
	for pickup: LootPickup in loot.get_children():
		if pickup.kind == &"soul": souls += pickup.quantity
		origin = origin or pickup.item_id == &"origin_divine_stone"
	_check(souls == 25 and not origin, "Ordinary Golem can yield one finite 25-Soul mote but never a future special-Boss origin stone")
	loot.clear()
	var mote: LootPickup = loot.spawn(&"soul", &"souls", player.position, 3)
	mote.automatic = false
	var before: int = bank.souls
	bank.fail_write = true
	_check(not mote.collect() and bank.souls == before and not mote.collected_once, "Soul pickup retains its one collectible if permanent save fails")
	bank.fail_write = false
	_check(mote.collect() and not mote.collect() and bank.souls == before + 3, "One Soul mote credits permanent progress exactly once on collection")
	await _step(2)
	mote = loot.spawn(&"soul", &"souls", Vector2(100, 640), 3)
	mote.life = 0.01
	mote.automatic = false
	before = bank.souls
	await _step(3)
	_check(not is_instance_valid(mote) and bank.souls == before, "Expired Soul mote releases its owner without direct duplicate awards")
	loot.clear()
	loot.chest_drop(Vector2(100, 640))
	var total: int = 0
	var ordinary_pickups: int = 0
	var chest_runes: Array[StringName] = []
	origin = false
	for pickup: LootPickup in loot.get_children():
		if pickup.kind == &"rune": chest_runes.append(pickup.item_id)
		else:
			ordinary_pickups += 1
			total += pickup.quantity
		origin = origin or pickup.item_id == &"origin_divine_stone" or (pickup.runtime_item != null and pickup.runtime_item.quality >= 2 and pickup.runtime_item.can_equip())
	_check(ordinary_pickups >= 3 and ordinary_pickups <= 5 and total >= 7 and not origin, "Secret chest yields multiple stronger stacks without origin stone or usable high-grade forge bypass")
	_check(chest_runes.size() == 2 and chest_runes.all(func(id: StringName) -> bool: return carried.get_rune(id) != null), "World secret chest restores two existing valid RuneShards without replacing ordinary loot")
	loot.queue_free()
	await _step(2)

func _test_safe_clicks() -> void:
	var persistence := SafeInventoryPersistence.new()
	level.add_child(persistence)
	persistence.initialize(economy)
	var sword_uid: int = carried.equipped_weapon_uid
	bank.fail_write = true
	carried.unequip_equipment(EquipmentData.SlotType.WEAPON)
	_check(carried.equipped_weapon_uid == sword_uid and not bank.last_save_ok, "Failed click-to-unequip save restores committed equipped UID rather than losing safe gear")
	bank.fail_write = false
	carried.unequip_equipment(EquipmentData.SlotType.WEAPON)
	var reader := SanctuaryProfile.new()
	reader.save_path = bank.save_path
	_check(reader.load_profile() and reader.hub_inventory["weapon"] == 0 and carried.equipped_weapon_uid == 0, "Successful normal inventory click persists its destination immediately")
	persistence.queue_free()
	await _step(2)

func _test_flow() -> void:
	var flow := GameFlow.new()
	flow.hub_scene = preload("res://scenes/hub/prologue_hub_room.tscn")
	flow.campaign_scene = preload("res://scenes/world_campaign.tscn")
	flow.world_building_enabled = true
	flow.save_path_override = bank.save_path
	root.add_child(flow)
	await _step(3)
	var hub: PrologueHub = flow.active_scene as PrologueHub
	_check(hub != null and hub.world_building_enabled and hub.gear.inventory.items.values().any(func(item: GearItem) -> bool: return item.enhancement_level == 12), "Cold World Hub reconstructs previously enhanced safe wardrobe")
	var old_profile: SanctuaryProfile = flow.profile
	var failed := FaultProfile.new()
	failed.save_path = old_profile.save_path
	failed.load_profile()
	flow.profile = failed
	hub.profile = failed
	hub.economy.profile = failed
	failed.fail_write = true
	var safe_uids: Array = hub.gear.inventory.items.keys().duplicate()
	flow.start_campaign()
	_check(flow.active_scene == hub and hub.gear.inventory.items.keys() == safe_uids, "Failed run MOVE save blocks launch and preserves every safe Hub UID")
	failed.fail_write = false
	flow.start_campaign()
	await _step(4)
	var run: DungeonRun = flow.active_scene as DungeonRun
	var reader := SanctuaryProfile.new()
	reader.save_path = bank.save_path
	_check(run is WorldCampaign and run.gear.loot.drop_table != null and reader.load_profile() and reader.hub_inventory.is_empty() and run.gear.inventory.items.keys() == safe_uids, "Successful run MOVE clears disk wardrobe before activating the prepared WorldCampaign")
	var previous_souls: int = flow.profile.souls
	var previous_proofs: int = flow.profile.boss_proofs[&"golem"]
	(run as WorldCampaign).enter_stage(4)
	run.boss.health.apply_damage(9999)
	await _step(5)
	_check(run.portal_active and flow.profile.souls == previous_souls and flow.profile.boss_proofs[&"golem"] == previous_proofs + 1, "Actual World Golem defeat records one bounty proof and never grants a direct duplicate Soul award")
	run._boss_defeated()
	await _step(3)
	_check(flow.profile.boss_proofs[&"golem"] == previous_proofs + 1, "Repeated Boss defeat callback cannot mint another proof receipt")
	run.gear.inventory.run_coins = 7
	var before_coins: int = flow.profile.coins
	run.finish(&"victory")
	failed.fail_write = true
	var before_return: Array = run.gear.inventory.items.keys().duplicate()
	flow.show_hub(false)
	_check(flow.active_scene == run and run.gear.inventory.items.keys() == before_return and run.gear.inventory.run_coins == 7 and flow.profile.coins == before_coins, "Failed victory return retains the run UID ledger and coin escrow for one retry")
	failed.fail_write = false
	flow.retry_pending_return()
	await _step(3)
	_check(flow.active_scene is PrologueHub and flow.profile.coins == before_coins + 7 and flow.active_scene.gear.inventory.run_coins == 0 and reader.load_profile() and not reader.hub_inventory.is_empty(), "Victory moves remaining UID ledger back once and banks seven carried coins atomically")
	flow.show_hub(false)
	await _step(2)
	_check(flow.profile.coins == before_coins + 7, "Repeated Hub entry cannot bank the same carried coin stack again")
	flow.start_campaign()
	await _step(2)
	run = flow.active_scene as DungeonRun
	run.gear.inventory.materials[&"crystal"] = 9
	run.gear.inventory.run_coins = 12
	run.finish(&"defeat")
	flow.show_hub(true)
	await _step(3)
	_check(flow.active_scene.gear.inventory.materials[&"crystal"] == 0 and flow.active_scene.gear.inventory.run_coins == 0 and flow.profile.coins == before_coins + 7 and not flow.active_scene.gear.inventory.items.values().any(func(item: GearItem) -> bool: return item.enhancement_level > 0), "Defeat loses carried crafted/enhanced gear and loot while keeping banked coins and materials")
	flow.active_scene.open_station(&"stash")
	_check(flow.active_scene.station_open and MaterialCatalog.IDS.all(func(id: StringName) -> bool: return MaterialCatalog.DISPLAY_NAMES.has(id)), "Expanded fifteen-material stash opens with complete Vietnamese labels")
	flow.active_scene.close_station()
	flow.queue_free()
	await _step(5)


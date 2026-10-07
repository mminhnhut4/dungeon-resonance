extends "res://tests/survival_test_base.gd"
## Real pickup/run ledgers plus faults at the native save commit boundaries.

class FaultProfile extends SanctuaryProfile:
	var fail_stage: StringName = &""
	var failures_left: int = 0

	func fail_once(stage: StringName) -> void:
		fail_stage = stage
		failures_left = 1

	func _open_writer(path: String) -> FileAccess:
		if fail_stage == &"write" and failures_left > 0:
			failures_left -= 1
			return null
		return super._open_writer(path)

	func _copy_file(from_path: String, to_path: String) -> Error:
		if fail_stage == &"backup_copy" and failures_left > 0:
			failures_left -= 1
			return ERR_CANT_CREATE
		return super._copy_file(from_path, to_path)

	func _rename_file(from_path: String, to_path: String) -> Error:
		var matches: bool = (fail_stage == &"commit" and from_path == save_path + ".tmp" and to_path == save_path) or (fail_stage == &"backup_commit" and from_path == save_path + ".bak.tmp" and to_path == save_path + ".bak")
		if matches and failures_left > 0:
			failures_left -= 1
			return ERR_CANT_CREATE
		return super._rename_file(from_path, to_path)

var _pickup: LootPickup
var _pickup_reentry: bool = false
var _profile_changes: int = 0
var _inventory_changes: int = 0
var _reentrant_sale: bool = false
var _economy: EconomySession
var _fixture_directory: String


func _initialize() -> void:
	suite = "economy"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	for enemy: SlimeEnemy in level.enemies:
		enemy.contact_damage_enabled = false
	var inventory: GearInventory = level.gear.inventory
	await _test_pickups(inventory)
	var bank := FaultProfile.new()
	_fixture_directory = "user://verification/economy_%d_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec(), Engine.physics_ticks_per_second]
	bank.save_path = _fixture_directory + "/profile.json"
	bank.souls = 137
	_check(bank.save() and bank.save(), "Economy fixture uses the same atomic profile/backup writer as Soul progress")
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(bank.save_path))
	_check(stored.size() == 7 and not stored.has("coins") and not stored.has("material_stash"), "Zero economy retains the seven-field legacy schema-one layout")
	_economy = EconomySession.new()
	_economy.initialize(bank, inventory)
	bank.changed.connect(_on_profile_changed)
	inventory.changed.connect(_on_inventory_changed)
	inventory.materials[&"crystal"] = 6
	inventory.materials[&"metal"] = 7
	inventory.materials[&"dust"] = 4
	_check(not _economy.deposit(&"unknown", 1) and not _economy.deposit(&"crystal", 0) and not _economy.deposit(&"crystal", -1) and not _economy.deposit(&"crystal", 7), "Invalid ID, nonpositive quantity and unavailable deposit never mutate the run ledger")
	_check(_economy.deposit(&"crystal", 2) and bank.material_stash[&"crystal"] == 2 and inventory.materials[&"crystal"] == 4 and bank.coins == 0, "Deposit transfers exactly two carried crystals into safe storage without minting coins")
	_check(not _reentrant_sale and bank.coins == 0 and _profile_changes == 1, "Changed callbacks cannot recursively turn a deposit into an unexpected merchant sale")
	var expected_bank: Dictionary[StringName, int] = MaterialCatalog.empty_counts()
	expected_bank[&"metal"] = 7
	expected_bank[&"dust"] = 4
	expected_bank[&"crystal"] = 6
	_check(_economy.deposit_all() and bank.material_stash == expected_bank and inventory.materials == MaterialCatalog.empty_counts(), "Deposit-all commits known material counts in one conserving transaction")
	_check(not _economy.deposit_all() and bank.material_stash[&"crystal"] == 6, "Repeated empty deposit cannot duplicate banked materials")
	var loaded := SanctuaryProfile.new()
	loaded.save_path = bank.save_path
	_check(loaded.load_profile() and loaded.material_stash == bank.material_stash and loaded.souls == 137 and loaded.coins == 0, "A fresh profile reloads safe materials while keeping Soul currency independent")
	_check(_economy.withdraw(&"crystal", 2) and bank.material_stash[&"crystal"] == 4 and inventory.materials[&"crystal"] == 2, "Withdrawal deducts the bank before placing the exact amount in the carried ledger")
	_check(not _economy.withdraw(&"crystal", 5) and not _economy.withdraw(&"metal", -1), "Withdrawal refuses missing materials and negative quantities")
	await _test_failed_commits(bank, inventory)
	var quote: Dictionary = _economy.quote_crystal_sale()
	_check(quote.quantity == 4 and quote.unit_price == 5 and quote.total == 20 and quote.can_sell, "Kael receives an explicit four-crystal quote at the prototype five-coin unit price")
	var changes_before: int = _profile_changes
	_check(_economy.sell_all_crystals() and bank.coins == 20 and bank.material_stash[&"crystal"] == 0 and inventory.materials[&"crystal"] == 2 and bank.souls == 137, "Merchant sale consumes only stored crystals and commits twenty coins, without consuming carried crystals or Souls")
	_check(not _economy.sell_all_crystals() and bank.coins == 20 and _profile_changes == changes_before + 1, "Repeated sale cannot grant duplicate payment or publish another successful commit")
	_check(loaded.load_profile() and loaded.coins == 20 and loaded.material_stash[&"crystal"] == 0 and loaded.souls == 137, "Sale proceeds and depleted crystal stash survive a fresh disk reload")
	await _test_gear_repair(bank, inventory)
	await _test_approved_consumables(inventory)
	await _test_seeded_drops()
	_test_dismantle_caps(inventory)
	_economy.hub_access = false
	_check(not _economy.deposit_all() and not _economy.withdraw(&"metal", 1) and not _economy.sell_all_crystals(), "A run-context session cannot access stash transfers or merchant sales")
	_economy.hub_access = true
	inventory.materials[&"crystal"] = 3
	_check(_economy.deposit_all() and bank.material_stash[&"crystal"] == 3, "Materials explicitly brought back and deposited become safe permanent storage")
	inventory.materials[&"crystal"] = 9
	player.hurtbox.set_invulnerable(false)
	player.hurtbox.take_damage(_damage(player.hurtbox, 999.0))
	await _step(3)
	level.gear.reset_inventory()
	_check(player.health.current_health == 0.0 and inventory.materials == MaterialCatalog.empty_counts() and bank.material_stash[&"crystal"] == 3, "Actual death followed by fresh-run reset loses carried materials and preserves deposited storage")
	_check(loaded.load_profile() and loaded.coins == 20 and loaded.material_stash[&"crystal"] == 3 and loaded.souls == 137, "Death does not overwrite safe materials, coin proceeds or persistent Souls on disk")
	await _test_capacity(bank, inventory)
	await _test_schema_loading()
	bank.changed.disconnect(_on_profile_changed)
	inventory.changed.disconnect(_on_inventory_changed)
	_economy = null
	loaded = null
	bank = null
	_cleanup_fixture()


func _test_pickups(inventory: GearInventory) -> void:
	var loot: LootSpawner = level.gear.loot
	loot.clear()
	loot.crystal_drops_enabled = true
	inventory.materials = MaterialCatalog.empty_counts()
	loot.enemy_drop(Vector2(780, 640))
	var crystals: Array[Node] = loot.get_children().filter(func(node: Node) -> bool: return node.kind == &"material" and node.item_id == &"crystal")
	_check(loot.get_child_count() == 3 and crystals.size() == 1 and crystals[0].quantity == 1, "An economy-enabled enemy death drops one crystal alongside the original rune and potion")
	_pickup = crystals[0] as LootPickup
	inventory.changed.connect(_on_pickup_changed)
	_check(_pickup.collect() and _pickup.collected_once and inventory.materials[&"crystal"] == 1, "The real crystal collectible enters the run material ledger exactly once")
	_check(not _pickup_reentry and not _pickup.collect() and inventory.materials[&"crystal"] == 1, "Reentrant inventory callbacks and repeated manual collection cannot duplicate a crystal")
	inventory.changed.disconnect(_on_pickup_changed)
	_pickup = null
	loot.clear()
	_check(loot.spawn(&"material", &"unknown", Vector2.ZERO) == null and loot.spawn(&"material", &"crystal", Vector2.ZERO, 0) == null, "Invalid material ID/quantity never spawns a collectible")
	inventory.materials[&"crystal"] = MaterialCatalog.MAX_COUNT
	var blocked: LootPickup = loot.spawn(&"material", &"crystal", Vector2(780, 640), 3)
	blocked.automatic = false
	_check(not blocked.collect() and not blocked.collected_once and inventory.materials[&"crystal"] == MaterialCatalog.MAX_COUNT, "Capacity rejection retains the same collectible without partial material credit")
	inventory.materials[&"crystal"] = MaterialCatalog.MAX_COUNT - 3
	_check(blocked.collect() and inventory.materials[&"crystal"] == MaterialCatalog.MAX_COUNT and not blocked.collect(), "Retry after making space grants its original stack once")
	loot.clear()
	inventory.materials[&"crystal"] = 0
	var automatic: LootPickup = loot.spawn(&"material", &"crystal", player.global_position + Vector2(-20, 0), 4)
	await _time(0.6)
	_check(not is_instance_valid(automatic) and inventory.materials[&"crystal"] == 4, "The real attraction/automatic pickup clock collects the crystal stack and frees its room owner")
	loot.clear()
	var expired: LootPickup = loot.spawn(&"material", &"crystal", Vector2(1000, 400))
	expired.automatic = false
	expired.life = 0.01
	await _step(4)
	_check(not is_instance_valid(expired) and inventory.materials[&"crystal"] == 4, "Expired uncollected crystals free themselves without granting materials")
	await _test_gear_snapshots(inventory)
	inventory.materials = MaterialCatalog.empty_counts()


func _test_gear_snapshots(inventory: GearInventory) -> void:
	var loot: LootSpawner = level.gear.loot
	var item := GearItem.new()
	item.uid = CombatIds.next_id()
	item.kind = &"weapon"
	item.definition_id = GearInventory.COMMON_SWORD.id
	item.equipment_definition = GearInventory.COMMON_SWORD
	var seeded := RandomNumberGenerator.new()
	seeded.seed = 651
	_check(LootAffixRoller.roll_once(item, seeded, &"drop", true), "Drop gear is rolled once on a unique runtime UID before it becomes a collectible")
	var expected: Dictionary = _loot_fields(item)
	var pickup: LootPickup = loot.spawn_gear(item, Vector2(1100, 640))
	var duplicate: LootPickup = loot.spawn_gear(item, Vector2(1100, 640))
	pickup.automatic = false
	duplicate.automatic = false
	item.broken = false
	item.drop_bonus = 0.08
	item.affix_id = &"crit"
	item.affix_value = 0.04
	_check(_loot_fields(pickup.runtime_item) == expected and pickup.runtime_item != item, "Spawn freezes quality/source/bonus/affix/broken state rather than sharing mutable producer data")
	_check(pickup.collect() and _loot_fields(inventory.items[item.uid]) == expected and inventory.items[item.uid] == pickup.runtime_item, "Collection transfers its exact rolled UID to the authoritative item ledger without rerolling")
	_check(not duplicate.collect() and not duplicate.collected_once and inventory.items[item.uid].broken, "A second world collectible with the same UID cannot duplicate or replace its already-owned gear")
	_check(not inventory.equip_equipment(item.uid) and not LootAffixRoller.roll_once(inventory.items[item.uid], seeded), "Picked-up broken gear cannot equip and a tooltip/collector cannot reroll it")
	inventory.items.erase(item.uid)
	loot.clear()
	await _step(2)


func _test_gear_repair(bank: FaultProfile, inventory: GearInventory) -> void:
	var item: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD, GearItem.Quality.RARE)
	var seeded := RandomNumberGenerator.new()
	seeded.seed = 1009
	LootAffixRoller.roll_once(item, seeded, &"drop", true)
	var before: Dictionary = _loot_fields(item)
	var original_uid: int = inventory.equipped_weapon_uid
	_check(not inventory.equip_equipment(item.uid) and inventory.equipped_weapon_uid == original_uid, "Broken Rare weapon is owned but cannot replace the equipped weapon")
	var quote: Dictionary = _economy.quote_repair(item.uid)
	_check(quote.can_repair and quote.metal == 4 and quote.dust == 2 and not quote.requires_forging, "Restoration quotes a concrete Rare cost from safe storage rather than promising free equipment")
	for stage: StringName in [&"write", &"backup_copy", &"backup_commit", &"commit"]:
		var original: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
		var stored: Dictionary = bank.material_stash.duplicate()
		var signals_before: int = _profile_changes
		bank.fail_once(stage)
		_check(not _economy.repair_item(item.uid) and _loot_fields(item) == before and bank.material_stash == stored, "%s failed repair restores materials and the same broken rolled item" % stage)
		_check(FileAccess.get_file_as_bytes(bank.save_path) == original and _profile_changes == signals_before, "%s failed repair does not persist material consumption or publish success" % stage)
	var restored: Dictionary = before.duplicate()
	restored.broken = false
	var metal_before: int = bank.material_stash[&"metal"]
	var dust_before: int = bank.material_stash[&"dust"]
	_check(_economy.repair_item(item.uid) and _loot_fields(item) == restored and bank.material_stash[&"metal"] == metal_before - 4 and bank.material_stash[&"dust"] == dust_before - 2, "Successful repair consumes the quoted resources once and preserves UID, quality, definition and roll")
	_check(inventory.equip_equipment(item.uid) and not _economy.repair_item(item.uid), "Restored weapon becomes usable and an already-repaired item cannot charge materials twice")
	var reader := SanctuaryProfile.new()
	reader.save_path = bank.save_path
	_check(reader.load_profile() and reader.material_stash == bank.material_stash and reader.coins == 20, "Repair material expense survives reload and does not change the coin account")
	var blank: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD, GearItem.Quality.VERY_RARE)
	LootAffixRoller.roll_once(blank, seeded, &"drop", true)
	_check(_economy.quote_repair(blank.uid).requires_forging and not _economy.repair_item(blank.uid) and not inventory.equip_equipment(blank.uid), "Very Rare drop is an unfinished forging blank; repair cannot bypass the blacksmith crafting requirement")
	blank.broken = false
	_check(not inventory.equip_equipment(blank.uid) and blank.is_forging_blank(), "Removing a blank's broken flag still cannot make a Very Rare drop directly usable")
	var unavailable := GearItem.new()
	_check(not _economy.quote_repair(unavailable.uid).can_repair and not _economy.repair_item(-123), "Missing UIDs cannot manufacture equipment or consume safe materials")
	_economy.hub_access = false
	item.broken = true
	_check(not _economy.repair_item(item.uid) and item.broken, "Equipment restoration is unavailable to a session outside the Hub")
	_economy.hub_access = true
	item.broken = false
	var flags: Dictionary[int, bool] = {}
	for weapon: GearItem in inventory.items.values():
		if weapon.kind == &"weapon":
			flags[weapon.uid] = weapon.broken
			weapon.broken = true
	level.gear.sync_loadout()
	player.switch_weapon()
	_check(player.available_weapons == [GearSession.UNARMED] and player.equipped_weapon.definition == GearSession.UNARMED and inventory.equipped_weapon_uid == 0, "The real Q switch cannot bypass broken/blank equip guards and safely falls back to the unarmed moveset")
	for uid: int in flags:
		inventory.items[uid].broken = flags[uid]
	inventory.equip_equipment(item.uid)
	level.gear.sync_loadout()
	_check(player.equipped_weapon.definition == GearInventory.COMMON_SWORD.moveset and player.available_weapons.has(GearInventory.COMMON_SWORD.moveset), "A restored usable weapon returns to the quick-switch list without rerolling or altering movement")
	_check(not _economy.quote_material_sale(&"metal").can_sell and not _economy.sell_material(&"unknown") and not _economy.sell_material(&"dust"), "Unpriced crafting resources and unknown names cannot mint merchant money")
	bank.material_stash[&"slime_essence"] = 2
	var essence_quote: Dictionary = _economy.quote_material_sale(&"slime_essence")
	_check(essence_quote.unit_price == 3 and essence_quote.total == 6 and essence_quote.can_sell, "Approved Slime Essence has a separate two-item quote at three prototype coins each")
	_check(_economy.sell_material(&"slime_essence") and bank.coins == 26 and bank.material_stash[&"slime_essence"] == 0 and not _economy.sell_material(&"slime_essence"), "Essence sale uses the same atomic one-time merchant transaction")
	# Keep historical crystal assertions independent of the added Essence offer.
	bank.coins = 20
	_check(bank.save(), "Independent repair/Essence fixture commits its final bank state")
	reader = null


func _test_approved_consumables(inventory: GearInventory) -> void:
	var loot: LootSpawner = level.gear.loot
	var status: ElementStatusController = player.hurtbox.damage_resolver.status_controller as ElementStatusController
	inventory.consumables[&"antidote"] = 0
	var pickup: LootPickup = loot.spawn(&"consumable", &"antidote", Vector2(1100, 640), 2)
	_check(pickup.collect() and inventory.consumables[&"antidote"] == 2 and not pickup.collect(), "Approved antidote collectible stores its exact stack in the run bag once")
	_check(not session.use_consumable(&"antidote") and inventory.consumables[&"antidote"] == 2, "An unpoisoned character cannot waste an antidote")
	var ailment: DamageEvent = _damage(player.hurtbox, 1.0)
	ailment.poison_stacks = 2
	ailment.poison_seconds = 4.0
	ailment.burn_damage = 1.0
	ailment.burn_duration = 3.0
	ailment.slow_seconds = 2.0
	status.apply(ailment)
	session.condition.bleeding = true
	session.condition.cripple_remaining = 5.0
	session.condition.burn_remaining = 8.0
	session.condition.stress = 40.0
	var health_before: float = player.health.current_health
	_check(session.use_consumable(&"antidote") and status.poison_count == 0 and status.poison_remaining == 0.0 and status.poison_source == null and inventory.consumables[&"antidote"] == 1, "Antidote consumes one bottle and clears only the poison clock/source")
	_check(status.burn_remaining == 3.0 and status.slow_remaining == 2.0 and session.condition.bleeding and session.condition.cripple_remaining == 5.0 and session.condition.burn_remaining == 8.0 and session.condition.stress == 40.0 and player.health.current_health == health_before, "Poison cure does not heal HP, erase burn/slow, cure wounds or reduce stress")
	_check(not session.use_consumable(&"antidote") and inventory.consumables[&"antidote"] == 1, "An immediate second cure cannot consume an extra bottle")
	status.clear()
	session.condition.clear()
	var bandage: LootPickup = loot.spawn(&"consumable", &"bandage", Vector2(1100, 640))
	var bandages_before: int = inventory.consumables[&"bandage"]
	_check(bandage.collect() and inventory.consumables[&"bandage"] == bandages_before + 1, "Approved bandage pickup enters its existing body-condition consumable path")
	_check(loot.spawn(&"consumable", &"unknown", Vector2.ZERO) == null, "Unapproved consumable names never spawn")
	loot.clear()
	await _step(3)


func _test_seeded_drops() -> void:
	var loot: LootSpawner = level.gear.loot
	loot.prologue_drops_enabled = true
	loot.crystal_drops_enabled = true
	var old_quality: bool = loot.quality_enabled
	loot.quality_enabled = false
	var first: Array[String] = _seeded_drop_trace(8831)
	var second: Array[String] = _seeded_drop_trace(8831)
	_check(first == second and first.any(func(entry: String) -> bool: return entry.begins_with("material:slime_essence")) and first.any(func(entry: String) -> bool: return entry.contains(":broken:")), "Seeded enemy-drop trials reproduce approved Essence and broken-gear results without depending on combat UID allocation")
	_check(first.filter(func(entry: String) -> bool: return entry == "material:crystal:1").size() == 80 and first.filter(func(entry: String) -> bool: return entry == "consumable:potion:1").size() == 80, "Prologue enemy trials retain one crystal and one bagged potion per kill")
	var kinds: Dictionary = {}
	loot.rng.seed = 1109
	for index: int in 160:
		var broken: GearItem = loot._broken_drop()
		kinds[broken.definition_id] = true
		if not broken.broken or broken.quality != GearItem.Quality.COMMON or broken.source != &"drop" or broken.can_equip():
			_check(false, "Every generated broken drop is a Common rolled item requiring restoration")
			break
	_check(kinds.size() == 5, "The approved prototype broken pool reaches sword, dagger, staff, top and gloves without adding high-grade gear")
	var usable: LootPickup = loot.spawn(&"weapon", GearInventory.COMMON_SWORD.id, Vector2(1100, 640))
	usable.automatic = false
	_check(usable.runtime_item != null and usable.runtime_item.can_equip() and usable.runtime_item.source == &"drop" and usable.runtime_item.drop_bonus >= 0.03 and usable.runtime_item.drop_bonus <= 0.08 and usable.runtime_item.loot_rolled, "Usable Common chest loot receives its bounded 3–8% roll at spawn instead of a merchant-neutral item")
	loot.clear()
	loot.prologue_drops_enabled = false
	loot.crystal_drops_enabled = false
	loot.quality_enabled = old_quality
	await _step(4)


func _seeded_drop_trace(seed_value: int) -> Array[String]:
	var loot: LootSpawner = level.gear.loot
	loot.rng.seed = seed_value
	loot.drop_serial = 0
	var trace: Array[String] = []
	for index: int in 80:
		loot.clear()
		loot.enemy_drop(Vector2(1100, 640))
		for pickup: LootPickup in loot.get_children():
			pickup.automatic = false
			var entry: String = "%s:%s:%d" % [pickup.kind, pickup.item_id, pickup.quantity]
			if pickup.runtime_item != null:
				entry += ":broken:%s:%.6f" % [pickup.runtime_item.affix_id, pickup.runtime_item.affix_value]
			trace.append(entry)
	loot.clear()
	return trace


func _loot_fields(item: GearItem) -> Dictionary:
	return {"uid": item.uid, "id": item.definition_id, "definition": item.equipment_definition, "quality": item.quality, "source": item.source, "drop_bonus": item.drop_bonus, "affix_id": item.affix_id, "affix_value": item.affix_value, "broken": item.broken, "loot_rolled": item.loot_rolled}


func _test_dismantle_caps(inventory: GearInventory) -> void:
	var materials_before: Dictionary = inventory.materials.duplicate()
	var spare: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD, GearItem.Quality.RARE)
	inventory.materials[&"metal"] = MaterialCatalog.MAX_COUNT - 4
	inventory.materials[&"dust"] = 10
	var original: Dictionary = inventory.materials.duplicate()
	var signals_before: int = _inventory_changes
	_check(not inventory.dismantle(spare.uid) and inventory.items.get(spare.uid) == spare and inventory.materials == original and _inventory_changes == signals_before, "Metal overflow rejects dismantling before deleting its unique item or emitting a success signal")
	inventory.materials[&"metal"] = 10
	inventory.materials[&"dust"] = MaterialCatalog.MAX_COUNT - 1
	original = inventory.materials.duplicate()
	_check(not inventory.dismantle(spare.uid) and inventory.items.get(spare.uid) == spare and inventory.materials == original, "Dust overflow leaves both output ledgers and the original equipment untouched")
	inventory.materials[&"metal"] = MaterialCatalog.MAX_COUNT - 5
	inventory.materials[&"dust"] = MaterialCatalog.MAX_COUNT - 2
	_check(inventory.dismantle(spare.uid) and not inventory.items.has(spare.uid) and inventory.materials[&"metal"] == MaterialCatalog.MAX_COUNT and inventory.materials[&"dust"] == MaterialCatalog.MAX_COUNT, "Making exact space allows one retry to atomically consume the item and fill both capped material counts")
	_check(not inventory.dismantle(spare.uid) and inventory.materials[&"metal"] == MaterialCatalog.MAX_COUNT and inventory.materials[&"dust"] == MaterialCatalog.MAX_COUNT, "A repeated dismantle cannot credit the consumed UID again")
	var invalid: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD)
	inventory.materials[&"metal"] = -1
	inventory.materials[&"dust"] = 0
	_check(not inventory.dismantle(invalid.uid) and inventory.items.get(invalid.uid) == invalid and inventory.materials[&"metal"] == -1, "Invalid destination state cannot be repaired by silently consuming another item")
	inventory.items.erase(invalid.uid)
	inventory.add_rune(&"fire", GearItem.Quality.RARE)
	var rune_uid: int = 0
	for rune: GearItem in inventory.items.values():
		if rune.kind == &"rune" and rune.definition_id == &"fire" and rune.quality == GearItem.Quality.RARE and not inventory.slot_uids.has(rune.uid):
			rune_uid = rune.uid
	var bag_before: int = inventory.bag[&"fire"]
	inventory.materials[&"metal"] = 0
	inventory.materials[&"dust"] = MaterialCatalog.MAX_COUNT - 2
	_check(not inventory.dismantle(rune_uid) and inventory.items.has(rune_uid) and inventory.bag[&"fire"] == bag_before and inventory.materials[&"dust"] == MaterialCatalog.MAX_COUNT - 2, "Rune dust overflow preserves both the physical UID and the aggregate shard count")
	inventory.materials[&"dust"] = MaterialCatalog.MAX_COUNT - 3
	_check(inventory.dismantle(rune_uid) and not inventory.items.has(rune_uid) and inventory.bag[&"fire"] == bag_before - 1 and inventory.materials[&"dust"] == MaterialCatalog.MAX_COUNT, "Rune retry consumes exactly one shard and reaches the dust cap without overflow")
	inventory.materials.assign(materials_before)


func _test_failed_commits(bank: FaultProfile, inventory: GearInventory) -> void:
	for stage: StringName in [&"write", &"backup_copy", &"backup_commit", &"commit"]:
		var original: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
		var profile_count: int = _profile_changes
		var inventory_count: int = _inventory_changes
		bank.fail_once(stage)
		_check(not _economy.deposit(&"crystal", 1) and bank.material_stash[&"crystal"] == 4 and inventory.materials[&"crystal"] == 2, "%s deposit failure rolls back both carried and stored counts" % stage)
		_check(FileAccess.get_file_as_bytes(bank.save_path) == original and _profile_changes == profile_count and _inventory_changes == inventory_count, "%s failed deposit leaves committed disk data and change signals untouched" % stage)
		bank.fail_once(stage)
		_check(not _economy.withdraw(&"crystal", 1) and bank.material_stash[&"crystal"] == 4 and inventory.materials[&"crystal"] == 2, "%s withdrawal failure restores both ledgers" % stage)
		_check(FileAccess.get_file_as_bytes(bank.save_path) == original and _profile_changes == profile_count and _inventory_changes == inventory_count, "%s failed withdrawal never publishes or persists a material copy" % stage)
		bank.fail_once(stage)
		_check(not _economy.sell_all_crystals() and bank.coins == 0 and bank.material_stash[&"crystal"] == 4, "%s merchant failure restores the entire crystal stack and coin balance" % stage)
		_check(FileAccess.get_file_as_bytes(bank.save_path) == original and _profile_changes == profile_count and _inventory_changes == inventory_count, "%s failed sale changes neither save bytes nor success notifications" % stage)


func _test_capacity(bank: FaultProfile, inventory: GearInventory) -> void:
	bank.material_stash[&"crystal"] = MaterialCatalog.MAX_COUNT
	inventory.materials[&"crystal"] = 1
	_check(not _economy.deposit_all() and not _economy.deposit(&"crystal", 1) and inventory.materials[&"crystal"] == 1 and bank.material_stash[&"crystal"] == MaterialCatalog.MAX_COUNT, "Overflow prevents the whole transfer without partial credit or lost carried material")
	bank.material_stash[&"crystal"] = 2
	bank.coins = MaterialCatalog.MAX_COUNT - 5
	_check(not _economy.quote_crystal_sale().can_sell and not _economy.sell_all_crystals() and bank.material_stash[&"crystal"] == 2 and bank.coins == MaterialCatalog.MAX_COUNT - 5, "Coin-cap overflow disables the full-stack offer rather than consuming crystals for capped payment")
	_check(not MaterialCatalog.valid_count(INF) and not MaterialCatalog.valid_count(NAN) and not MaterialCatalog.valid_count(1.5), "Nonfinite and fractional material/currency quantities are rejected")


func _test_schema_loading() -> void:
	var reader := SanctuaryProfile.new()
	reader.save_path = _fixture_directory + "/schema.json"
	var legacy: Dictionary = {"version": 1, "souls": 31, "weapons": ["ancient_sword", "shadow_dagger"], "discovered": [], "archive": [], "style": "steady", "starting_weapon": "ancient_sword"}
	_write_json(reader.save_path, legacy)
	reader.coins = 123
	reader.material_stash[&"crystal"] = 99
	_check(reader.load_profile() and reader.coins == 0 and reader.material_stash == MaterialCatalog.empty_counts() and reader.souls == 31, "A genuine old schema-one save loads with empty optional economy fields, clearing stale in-memory values")
	for invalid: Dictionary in [{"coins": -1}, {"coins": 1.5}, {"coins": "5"}, {"coins": 1000000}, {"coins": true}, {"material_stash": []}, {"material_stash": {"crystal": -1}}, {"material_stash": {"crystal": 2.5}}, {"material_stash": {"crystal": "2"}}, {"material_stash": {"unknown": 1}}, {"material_stash": {"crystal": 1000000}}]:
		var malformed: Dictionary = legacy.duplicate(true)
		malformed.merge(invalid, true)
		_write_json(reader.save_path, malformed)
		_check(not reader.load_profile() and reader.souls == 31 and reader.coins == 0 and reader.material_stash[&"crystal"] == 0, "Invalid optional economy payload is rejected without changing live progress: %s" % JSON.stringify(invalid))
	var valid: Dictionary = legacy.duplicate(true)
	valid["coins"] = 10
	valid["material_stash"] = {"crystal": 3}
	_write_json(reader.save_path, valid)
	var expected_partial: Dictionary[StringName, int] = MaterialCatalog.empty_counts()
	expected_partial[&"crystal"] = 3
	_check(reader.load_profile() and reader.coins == 10 and reader.material_stash == expected_partial, "Valid partial optional stash loads known counts and fills missing material IDs with zero")
	_check(reader.save() and reader.save(), "Economy extension creates the existing validated recovery backup")
	var invalid_main: Dictionary = valid.duplicate(true)
	invalid_main["coins"] = -50
	_write_json(reader.save_path, invalid_main)
	_check(reader.load_profile() and reader.coins == 10 and reader.material_stash[&"crystal"] == 3, "Malformed economy main recovers the latest validated bank/coin backup")
	reader.coins = -1
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(reader.save_path)
	_check(not reader.save() and FileAccess.get_file_as_bytes(reader.save_path) == bytes, "Invalid in-memory economy cannot overwrite any existing save")
	reader = null


func _on_pickup_changed() -> void:
	if is_instance_valid(_pickup) and _pickup.collect():
		_pickup_reentry = true


func _on_profile_changed() -> void:
	_profile_changes += 1
	if _economy.sell_all_crystals():
		_reentrant_sale = true


func _on_inventory_changed() -> void:
	_inventory_changes += 1


func _write_json(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _cleanup_fixture() -> void:
	for name: String in ["profile", "schema"]:
		for suffix: String in ["", ".tmp", ".bak", ".bak.tmp", ".previous", ".bak.previous"]:
			var path: String = _fixture_directory + "/" + name + ".json" + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(_fixture_directory)

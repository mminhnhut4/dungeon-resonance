extends SceneTree
## Real owner handlers, sealed save faults and cold reload; isolated QA data only.
const Cultivation = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
const RuneService = preload("res://scripts/runtime/rune_learning_service.gd")
var checks: int = 0
var failures: int = 0
var directory: String

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	var actual: String = OS.get_user_data_dir().replace("\\", "/")
	if not qa.is_absolute_path() or not actual.begins_with(qa + "/"):
		print("FAIL: bag_economy requires a dedicated QA user-data root")
		quit(2)
		return
	directory = "user://verification/bag_economy_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	print("BAG_ECONOMY_USER_DIR=" + actual)
	_test_bag_costs()
	_test_bulk_sale()
	_test_bulk_fault_boundaries()
	_test_pending_recovery()
	_test_sort_and_legacy_codec()
	_test_legacy_sales_and_storage()
	print("RESULT bag_economy checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _fixture(label: String) -> Dictionary:
	var bank := SanctuaryProfile.new()
	bank.save_path = directory + "/" + label + "/profile.json"
	bank.coins = 5000
	bank.souls = 100
	for id: StringName in MaterialCatalog.IDS:
		if MaterialCatalog.material_policy(id)["ordinary_transfer"]: bank.material_stash[id] = 100
	_check(bank.save(), label + ": original profile saves")
	_check(bank.commit_cultivation(Cultivation.initial_proposal(Cultivation.new_progress(43), bank.material_stash, bank.souls, bank.boss_proofs)), label + ": actual owner seals profile v2")
	var inventory: GearInventory = HubPreparation.starter_inventory()
	var economy := EconomySession.new()
	economy.initialize(bank, inventory)
	economy.persist_safe_inventory = true
	_check(economy._save_safe(), label + ": exact starting inventory is durable")
	return {"bank": bank, "inventory": inventory, "economy": economy}

func _ledger(f: Dictionary) -> Dictionary:
	var bank: SanctuaryProfile = f["bank"]
	var inv: GearInventory = f["inventory"]
	return {"coins": bank.coins, "souls": bank.souls, "stash": bank.material_stash.duplicate(),
		"inventory": GearInventoryCodec.encode(inv), "positions": inv.equipment_positions.duplicate(),
		"hub_inventory": bank.hub_inventory.duplicate(true), "cultivation": bank.cultivation_progress.duplicate(true),
		"extensions": bank._retained_fields.duplicate(true)}

func _fault_action(f: Dictionary, label: String, action: Callable) -> void:
	var bank: SanctuaryProfile = f["bank"]
	var before: Dictionary = _ledger(f)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	bank._writer.fault_plan = {"write_candidate": true}
	_check(not bool(action.call()), label + ": failed candidate save rejects action")
	_check(_ledger(f) == before and not f["economy"]._busy and not bank.read_only, label + ": failure restores exact bag, costs, positions and profile ledger")
	_check(FileAccess.get_file_as_bytes(bank.save_path) == bytes, label + ": failed save preserves primary bytes")
	_check(bank._writer.fault_plan.is_empty(), label + ": handler reached the real writer fault")

func _cold_matches(f: Dictionary, label: String) -> void:
	var bank: SanctuaryProfile = f["bank"]
	var restored := SanctuaryProfile.new()
	restored.save_path = bank.save_path
	_check(restored.load_profile() and not restored.read_only, label + ": cold profile loads through sealed writer")
	var inv: GearInventory = GearInventoryCodec.decode(restored.hub_inventory)
	_check(inv != null, label + ": cold inventory decodes")
	if inv == null: return
	_check(Writer.canonical(GearInventoryCodec.encode(inv)) == Writer.canonical(GearInventoryCodec.encode(f["inventory"])), label + ": exact UIDs, stats, positions and carried counts survive reload")
	_check(restored.coins == bank.coins and restored.souls == bank.souls and restored.material_stash == bank.material_stash, label + ": wallets and original stash survive reload")

func _test_bag_costs() -> void:
	var f: Dictionary = _fixture("bag_costs")
	var bank: SanctuaryProfile = f["bank"]
	var inv: GearInventory = f["inventory"]
	var ec: EconomySession = f["economy"]
	var stash: Dictionary = bank.material_stash.duplicate()
	var sword: GearItem = inv.items[inv.equipped_weapon_uid]
	var broken: GearItem = inv.add_equipment(GearInventory.COMMON_SWORD, GearItem.Quality.RARE)
	broken.source = &"drop"; broken.loot_rolled = true; broken.broken = true
	broken.drop_bonus = 0.013505235314369202
	broken.affix_id = &"precision"; broken.affix_value = 0.01
	_check(bank.learn_blueprint(&"world_saber"), "Craft fixture knows a real forge blueprint")
	var rune = RuneService.new()
	rune.initialize(ec)
	_check(rune.learn(&"fire"), "Real rune lesson grants initial finite UID using Souls")
	_check(not ec.quote_enhance(sword.uid)["can_enhance"] and not ec.quote_repair(broken.uid)["can_repair"] and not ec.quote_combine_stones(1)["can_combine"] and not ec.quote_forge(&"world_saber_very_rare")["can_forge"] and not ec.quote_consumable(&"potion")["can_craft"] and not rune.quote(&"fire")["can_craft"], "Stocked bank alone cannot fund enhancement, repair, combining, forge, consumable or rune craft")
	for id: StringName in [&"metal", &"dust", &"healing_herb", &"linen_fiber", &"detox_root"]: inv.materials[id] = 100
	inv.materials[&"crystal"] = 10
	inv.materials[&"enhancement_stone_1"] = 11
	inv.materials[&"enhancement_stone_2"] = 4
	_check(ec._save_safe(), "Carried supplies become durable before transactions")
	_test_service_locks(f, sword.uid, broken.uid, rune)
	var coins: int = bank.coins
	_fault_action(f, "Enhance", func() -> bool: return ec.enhance_item(sword.uid))
	_check(ec.enhance_item(sword.uid) and sword.enhancement_level == 1 and inv.materials[&"enhancement_stone_1"] == 10 and bank.coins == coins - 5, "Enhancement consumes one carried stone and five Linh Thach")
	var metal: int = inv.materials[&"metal"]
	var dust: int = inv.materials[&"dust"]
	var repair: Dictionary = ec.quote_repair(broken.uid)
	_fault_action(f, "Repair", func() -> bool: return ec.repair_item(broken.uid))
	_check(ec.repair_item(broken.uid) and inv.items[broken.uid] == broken and not broken.broken and inv.materials[&"metal"] == metal - int(repair["metal"]) and inv.materials[&"dust"] == dust - int(repair["dust"]), "Repair consumes carried ingredients and keeps the same item object/UID")
	_check(broken.drop_bonus == 0.013505235314369202 and broken.affix_id == &"precision" and broken.affix_value == 0.01, "Repair preserves exact float64 drop and affix state")
	_fault_action(f, "Combine", func() -> bool: return ec.combine_stones(1))
	_check(ec.combine_stones(1) and inv.materials[&"enhancement_stone_1"] == 5 and inv.materials[&"enhancement_stone_2"] == 5, "Combining consumes five carried stones and returns one carried stone")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var before_rng: int = rng.state
	_fault_action(f, "Forge", func() -> bool: return bool(ec.forge(&"world_saber_very_rare", rng).get("committed", false)))
	_check(rng.state == before_rng, "Failed forge restores RNG for explicit retry")
	var recipe: ForgeRecipe = ec.forge_recipes[&"world_saber_very_rare"]
	var materials: Dictionary = inv.materials.duplicate()
	coins = bank.coins
	var result: Dictionary = ec.forge(recipe.id, rng)
	var forged: GearItem = inv.items.get(int(result.get("uid", 0)))
	_check(result.get("committed", false) and result.get("success", false) and forged != null and forged.quality == GearItem.Quality.VERY_RARE and forged.can_equip() and bank.coins == coins - recipe.coin_cost, "Real learned forge grants one usable gear UID and charges quoted wallet cost")
	for id: StringName in recipe.costs(): _check(inv.materials[id] == int(materials[id]) - recipe.costs()[id], "Forge consumes carried ingredient: " + String(id))
	for id: StringName in [&"potion", &"bandage", &"antidote"]:
		materials = inv.materials.duplicate()
		var count: int = inv.consumables[id]
		_fault_action(f, "Craft " + String(id), func() -> bool: return ec.craft_consumable(id))
		_check(ec.craft_consumable(id) and inv.consumables[id] == count + 1, "Actual craft creates one carried " + String(id))
		for ingredient: StringName in EconomySession.CONSUMABLE_RECIPES[id]:
			_check(inv.materials[ingredient] == int(materials[ingredient]) - int(EconomySession.CONSUMABLE_RECIPES[id][ingredient]), "Consumable charges carried ingredient: " + String(ingredient))
	var souls: int = bank.souls
	var runes: int = inv.bag[&"fire"]
	dust = inv.materials[&"dust"]
	var crystals: int = inv.materials[&"crystal"]
	_fault_action(f, "Rune craft", func() -> bool: return rune.craft(&"fire"))
	_check(rune.craft(&"fire") and inv.bag[&"fire"] == runes + 1 and inv.materials[&"dust"] == dust - 2 and inv.materials[&"crystal"] == crystals - 1 and bank.souls == souls, "Rune craft charges two carried dust/one crystal and leaves Souls untouched")
	_check(bank.material_stash == stash, "All six services preserve original storage ledger")
	inv.materials[&"enhancement_stone_2"] = MaterialCatalog.MAX_COUNT
	_check(ec._save_safe(), "Destination overflow fixture saves")
	var before: Dictionary = _ledger(f)
	_check(not ec.combine_stones(1) and _ledger(f) == before, "Full carried stone destination rejects without consuming source")
	_check(not ec.combine_stones(0) and not ec.combine_stones(6) and not ec.combine_stones(1, -1), "Invalid stone grades and negative batches cannot mutate bag")
	_cold_matches(f, "Craft services")

func _test_service_locks(f: Dictionary, sword_uid: int, broken_uid: int, rune: RuneLearningService) -> void:
	var bank: SanctuaryProfile = f["bank"]
	var ec: EconomySession = f["economy"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var services: Array[Dictionary] = [
		{"name": "enhance", "quote": func() -> bool: return ec.quote_enhance(sword_uid)["can_enhance"], "act": func() -> bool: return ec.enhance_item(sword_uid)},
		{"name": "repair", "quote": func() -> bool: return ec.quote_repair(broken_uid)["can_repair"], "act": func() -> bool: return ec.repair_item(broken_uid)},
		{"name": "combine", "quote": func() -> bool: return ec.quote_combine_stones(1)["can_combine"], "act": func() -> bool: return ec.combine_stones(1)},
		{"name": "forge", "quote": func() -> bool: return ec.quote_forge(&"world_saber_very_rare")["can_forge"], "act": func() -> bool: return bool(ec.forge(&"world_saber_very_rare", rng).get("committed", false))},
		{"name": "consumable", "quote": func() -> bool: return ec.quote_consumable(&"potion")["can_craft"], "act": func() -> bool: return ec.craft_consumable(&"potion")},
		{"name": "rune", "quote": func() -> bool: return rune.quote(&"fire")["can_craft"], "act": func() -> bool: return rune.craft(&"fire")}
	]
	for service: Dictionary in services: _check(service["quote"].call(), "Service lock fixture is genuinely affordable: " + str(service["name"]))
	for gate: String in ["read_only", "hub_inventory_quarantined", "hub_access", "_busy", "persist_safe_inventory"]:
		if gate in ["read_only", "hub_inventory_quarantined"]: bank.set(gate, true)
		else: ec.set(gate, gate == "_busy")
		var before: Dictionary = _ledger(f)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
		var rng_state: int = rng.state
		for service: Dictionary in services:
			_check(not service["quote"].call() and not service["act"].call() and _ledger(f) == before and FileAccess.get_file_as_bytes(bank.save_path) == bytes and rng.state == rng_state, str(service["name"]) + " respects " + gate + " without material, UID, wallet, write or RNG effects")
		if gate in ["read_only", "hub_inventory_quarantined"]: bank.set(gate, false)
		else: ec.set(gate, gate in ["hub_access", "persist_safe_inventory"])

func _seed_sale(f: Dictionary, protections: bool = false) -> Dictionary:
	var inv: GearInventory = f["inventory"]
	var common: GearItem = inv.add_equipment(GearInventory.COMMON_SWORD)
	var rare: GearItem = inv.add_equipment(GearInventory.STARTER_CLOTHING[0], GearItem.Quality.RARE)
	common.source = &"drop"; common.loot_rolled = true
	rare.source = &"drop"; rare.loot_rolled = true
	inv.materials[&"crystal"] = 3
	inv.materials[&"slime_essence"] = 2
	inv.materials[&"metal"] = 7
	var protected: Array[int] = [inv.equipped_weapon_uid, inv.catalyst_uid]
	protected.append_array(inv.equipment_uids)
	if protections:
		var enhanced: GearItem = inv.add_equipment(GearInventory.COMMON_SWORD)
		enhanced.enhancement_level = 1
		protected.append(enhanced.uid)
		protected.append(inv.add_equipment(GearInventory.COMMON_SWORD, GearItem.Quality.EPIC).uid)
		protected.append(inv.add_equipment(preload("res://data/equipment/ancient_sword_bounty.tres")).uid)
		inv.add_rune(&"fire")
		inv.equip(0, &"fire")
		protected.append(inv.slot_uids[0])
		protected.append(inv.add_item(&"relic", &"gale_feather").uid)
		inv.consumables[&"potion"] = 3
	inv.equipment_grid_uids()
	_check(f["economy"]._save_safe(), "Mixed sale inventory persists before quote")
	return {"eligible": [common.uid, rare.uid], "protected": protected, "common": common, "rare": rare}

func _test_bulk_sale() -> void:
	var f: Dictionary = _fixture("bulk")
	var bank: SanctuaryProfile = f["bank"]
	var inv: GearInventory = f["inventory"]
	var ec: EconomySession = f["economy"]
	var seeded: Dictionary = _seed_sale(f, true)
	var quote: Dictionary = ec.quote_sell_all_bag()
	_check(quote["can_sell"] and quote["item_count"] == 7 and quote["total"] == 36 and quote["equipment_uids"] == seeded["eligible"], "Bulk quote counts five material units and two ordinary gears for exact total36")
	var detached: Dictionary = ec.quote_sell_all_bag()
	detached["materials"][&"crystal"] = 999
	detached["equipment_uids"].clear()
	_check(ec.quote_sell_all_bag() == quote and inv.materials[&"crystal"] == 3, "Editing detached quote cannot alter inventory or next quote")
	var before: Dictionary = _ledger(f)
	_check(not ec.sell_all_bag("") and not ec.sell_all_bag("wrong-signature") and _ledger(f) == before, "Bulk requires exact nonempty accepted signature")
	inv.materials[&"crystal"] += 1
	_check(ec._save_safe(), "Changed bag commits after old preview")
	before = _ledger(f)
	_check(not ec.sell_all_bag(quote["signature"]) and _ledger(f) == before, "Changed material count invalidates previous confirmation")
	quote = ec.quote_sell_all_bag()
	var common: GearItem = seeded["common"]
	common.enhancement_level = 1
	_check(not ec.sell_all_bag(quote["signature"]), "Enhancing quoted gear invalidates bulk plan")
	common.enhancement_level = 0
	for gate: String in ["read_only", "hub_inventory_quarantined", "hub_access", "_busy", "persist_safe_inventory"]:
		if gate in ["read_only", "hub_inventory_quarantined"]: bank.set(gate, true)
		else: ec.set(gate, gate == "_busy")
		before = _ledger(f)
		_check(not ec.quote_sell_all_bag()["can_sell"] and not ec.sell_all_bag(quote["signature"]) and not ec.sort_bag() and _ledger(f) == before, "Bulk and sort respect owner lock: " + gate)
		if gate in ["read_only", "hub_inventory_quarantined"]: bank.set(gate, false)
		else: ec.set(gate, gate in ["hub_access", "persist_safe_inventory"])
	var coins: int = bank.coins
	bank.coins = MaterialCatalog.MAX_COUNT
	before = _ledger(f)
	_check(not ec.quote_sell_all_bag()["can_sell"] and not ec.sell_all_bag(quote["signature"]) and _ledger(f) == before, "Full wallet rejects bulk without deleting UIDs")
	bank.coins = coins
	_check(ec._save_safe(), "Sale fixture restored after lock/cap checks")
	quote = ec.quote_sell_all_bag()
	_fault_action(f, "Bulk sale", func() -> bool: return ec.sell_all_bag(quote["signature"]))
	_check(inv.items[common.uid] == common and inv.items[seeded["rare"].uid] == seeded["rare"], "Failed bulk preserves original GearItem objects")
	var signals: Array[int] = [0, 0]
	var callback: Callable = func() -> void:
		signals[0] += 1
		if ec.sell_all_bag(quote["signature"]): signals[1] += 1
	ec.changed.connect(callback)
	before = _ledger(f)
	_check(ec.sell_all_bag(quote["signature"]) and bank.coins == coins + int(quote["total"]) and signals == [1, 0] and not ec._busy, "Bulk commits once and blocks reentrant callbacks")
	ec.changed.disconnect(callback)
	for uid: int in seeded["eligible"]: _check(not inv.items.has(uid), "Eligible UID removed once: %d" % uid)
	for uid: int in seeded["protected"]:
		if uid != 0: _check(inv.items.has(uid), "Protected equipped/socket/bounty/precious/enhanced UID retained: %d" % uid)
	_check(inv.materials[&"crystal"] == 0 and inv.materials[&"slime_essence"] == 0 and inv.materials[&"metal"] == 7 and inv.consumables[&"potion"] == 3 and bank.souls == before["souls"] and bank.material_stash == before["stash"], "Bulk only exchanges eligible carried goods for Linh Thach")
	before = _ledger(f)
	_check(not ec.sell_all_bag(quote["signature"]) and not ec.quote_sell_all_bag()["can_sell"] and _ledger(f) == before, "Repeated confirmation/protected-only bag cannot grant coins twice")
	_cold_matches(f, "Bulk sale")

func _test_bulk_fault_boundaries() -> void:
	for point: String in ["write_candidate", "write_decision", "rename_decision", "rename_old", "commit"]:
		var f: Dictionary = _fixture("bulk_fault_" + point)
		_seed_sale(f)
		var bank: SanctuaryProfile = f["bank"]
		var ec: EconomySession = f["economy"]
		var before: Dictionary = _ledger(f)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
		var quote: Dictionary = ec.quote_sell_all_bag()
		bank._writer.fault_plan = {point: true}
		_check(not ec.sell_all_bag(quote["signature"]) and not ec._busy and not bank.read_only, point + ": definitive failure aborts bulk")
		_check(_ledger(f) == before and FileAccess.get_file_as_bytes(bank.save_path) == bytes, point + ": items, costs and primary bytes roll back together")
		_cold_matches(f, point + " aborted sale")
		_check(ec.sell_all_bag(ec.quote_sell_all_bag()["signature"]), point + ": explicit retry succeeds once")

func _test_pending_recovery() -> void:
	for point: String in ["after_candidate", "after_decision", "after_old_rename", "after_commit"]:
		var f: Dictionary = _fixture("bulk_pending_" + point)
		_seed_sale(f)
		var bank: SanctuaryProfile = f["bank"]
		var ec: EconomySession = f["economy"]
		var before: Dictionary = _ledger(f)
		var quote: Dictionary = ec.quote_sell_all_bag()
		bank._writer.fault_plan = {point: true}
		_check(not ec.sell_all_bag(quote["signature"]) and bank.read_only and _ledger(f) == before, point + ": uncertain commit quarantines while preserving live preimage")
		var cold := SanctuaryProfile.new()
		cold.save_path = bank.save_path
		_check(cold.load_profile() and not cold.read_only, point + ": cold owner resolves pending journal")
		var loaded: GearInventory = GearInventoryCodec.decode(cold.hub_inventory)
		_check(loaded != null, point + ": resolved UID ledger stays valid")
		if loaded == null: continue
		var committed: bool = point != "after_candidate"
		_check(cold.coins == int(before["coins"]) + (int(quote["total"]) if committed else 0) and cold.material_stash == before["stash"] and cold.souls == before["souls"], point + ": recovered wallet agrees with journal and leaves bank/Souls intact")
		for uid: int in quote["equipment_uids"]: _check(loaded.items.has(uid) != committed, point + ": recovered UID ownership agrees with payment")
		_check(loaded.materials[&"crystal"] == (0 if committed else 3) and loaded.materials[&"slime_essence"] == (0 if committed else 2), point + ": recovered counts agree with payment")

func _test_sort_and_legacy_codec() -> void:
	var f: Dictionary = _fixture("sort")
	var inv: GearInventory = f["inventory"]
	var ec: EconomySession = f["economy"]
	var seeded: Dictionary = _seed_sale(f, true)
	inv.equipment_grid_uids()
	inv.equipment_positions.reverse()
	_check(ec._save_safe(), "Unsorted grid persists before sort")
	var uids: Array[int] = inv.equipment_bag_uids()
	var equipped: Array[int] = inv.equipment_uids.duplicate()
	_fault_action(f, "Sort", func() -> bool: return ec.sort_bag())
	_check(ec.sort_bag() and inv.equipment_bag_uids() == uids and inv.equipment_uids == equipped and inv.items.has(seeded["common"].uid), "Sorting preserves owned/equipped UID sets")
	var positions: Array[int] = inv.equipment_positions.duplicate()
	_check(ec.sort_bag() and inv.equipment_positions == positions, "Repeated sorting is stable")
	_cold_matches(f, "Sorted inventory")
	var encoded: Dictionary = GearInventoryCodec.encode(inv)
	_check(encoded.has("equipment_positions"), "Codec persists explicit grid order")
	var legacy: Dictionary = encoded.duplicate(true)
	legacy.erase("equipment_positions")
	var restored: GearInventory = GearInventoryCodec.decode(legacy)
	_check(GearInventoryCodec.valid(legacy) and restored != null and restored.equipment_bag_uids() == uids, "Older inventory without positions still decodes every UID")
	var duplicate: Dictionary = encoded.duplicate(true)
	duplicate["equipment_positions"] = [uids[0], uids[0]]
	_check(not GearInventoryCodec.valid(duplicate), "Duplicate grid destinations rejected")
	var foreign: Dictionary = encoded.duplicate(true)
	foreign["equipment_positions"] = [GearInventoryCodec.MAX_UID]
	_check(not GearInventoryCodec.valid(foreign), "Unknown grid UID rejected")
	var worn: Dictionary = encoded.duplicate(true)
	worn["equipment_positions"] = [inv.equipped_weapon_uid]
	_check(not GearInventoryCodec.valid(worn), "Equipped UID cannot also occupy bag grid")
	var copied := GearInventory.new()
	GearInventoryCodec.copy_into(copied, inv)
	_check(copied.equipment_positions == positions and GearInventoryCodec.encode(copied) == encoded, "Rollback copy retains explicit grid order and all records")
	var overflow := GearInventory.new()
	for index: int in 23:
		var item: GearItem = overflow.add_item(&"weapon", GearInventory.COMMON_SWORD.id, index % 2)
		item.equipment_definition = GearInventory.COMMON_SWORD
	var before_uids: Array[int] = overflow.equipment_bag_uids()
	overflow.sort_equipment_bag()
	_check(overflow.equipment_positions.size() >= 23 and overflow.equipment_bag_uids() == before_uids and overflow.equipment_positions.all(func(uid: int) -> bool: return overflow.items.has(uid)), "Sort exposes all 23 legacy overflow items without truncating to 20")
	_check(GearInventoryCodec.valid(GearInventoryCodec.encode(overflow)), "Sorted overflow remains valid for persistence")

func _test_legacy_sales_and_storage() -> void:
	var f: Dictionary = _fixture("legacy_sales")
	var bank: SanctuaryProfile = f["bank"]
	var inv: GearInventory = f["inventory"]
	var ec: EconomySession = f["economy"]
	var stash: Dictionary = bank.material_stash.duplicate()
	_check(not ec.quote_material_sale(&"crystal")["can_sell"] and not ec.sell_all_crystals(), "Legacy sale cannot consume crystals present only in storage")
	_check(ec.withdraw(&"crystal", 2) and inv.materials[&"crystal"] == 2 and bank.material_stash[&"crystal"] == 98, "Explicit withdrawal moves exactly two crystals into bag")
	var coins: int = bank.coins
	_check(ec.quote_material_sale(&"crystal")["quantity"] == 2 and ec.sell_all_crystals() and bank.coins == coins + 10 and inv.materials[&"crystal"] == 0 and bank.material_stash[&"crystal"] == 98, "Legacy sale now consumes only withdrawn bag crystals")
	_check(ec.withdraw(&"metal", 3) and ec.deposit(&"metal", 3) and bank.material_stash[&"metal"] == stash[&"metal"] and inv.materials[&"metal"] == 0, "Storage deposit/withdraw still conserve ordinary materials")
	_cold_matches(f, "Storage and legacy sale")

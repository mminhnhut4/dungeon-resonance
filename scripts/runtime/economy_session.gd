class_name EconomySession
extends RefCounted
## Hub-owned transfer/sale transactions. No money is granted by a run pickup.

signal changed
var profile: SanctuaryProfile
var inventory: GearInventory
var hub_access: bool = true
var _busy: bool = false
var persist_safe_inventory: bool = false
var forge_recipes: Dictionary[StringName, ForgeRecipe] = {}
const CONSUMABLE_RECIPES: Dictionary = {&"potion": {&"healing_herb": 3, &"dust": 1}, &"bandage": {&"linen_fiber": 2}, &"antidote": {&"detox_root": 2, &"dust": 1}}


func initialize(permanent: SanctuaryProfile, carried: GearInventory) -> void:
	profile = permanent
	inventory = carried
	for path: String in DirAccess.get_files_at("res://data/forge"):
		if path.ends_with(".tres"):
			var recipe: ForgeRecipe = load("res://data/forge/" + path) as ForgeRecipe
			if recipe != null: register_recipe(recipe)


func _save_safe() -> bool:
	var previous: Dictionary = profile.hub_inventory
	if persist_safe_inventory: profile.hub_inventory = GearInventoryCodec.encode(inventory)
	if profile.save(): return true
	profile.hub_inventory = previous
	return false


func quote_upgrade(id: StringName) -> Dictionary:
	var known: bool = id in WorldProgressionCatalog.UPGRADES
	var level: int = profile.permanent_upgrades.get(id, 0) if profile != null else 0
	var maximum: int = WorldProgressionCatalog.MAX_LEVELS.get(id, 0)
	var cost: int = WorldProgressionCatalog.BASE_COSTS.get(id, 0) * (level + 1)
	return {"id": id, "level": level, "max_level": maximum, "cost": cost, "value": level * WorldProgressionCatalog.VALUES.get(id, 0), "unit": WorldProgressionCatalog.UNITS.get(id, ""), "can_buy": known and hub_access and not _busy and profile != null and level < maximum and profile.souls >= cost}


func buy_upgrade(id: StringName) -> bool:
	var quote: Dictionary = quote_upgrade(id)
	if not quote["can_buy"]: return false
	_busy = true
	var previous_opening: Dictionary = profile.opening_progress
	profile.opening_progress = OpeningProgress.with_event(profile.opening_progress, &"first_upgrade")
	profile.souls -= int(quote["cost"])
	profile.permanent_upgrades[id] += 1
	if not _save_safe():
		profile.souls += int(quote["cost"])
		profile.permanent_upgrades[id] -= 1
		profile.opening_progress = previous_opening
		_busy = false
		return false
	_publish_commit()
	return true


func quote_bounty(id: StringName) -> Dictionary:
	var accepted: bool = profile != null and profile.bounty_accepted
	var claimed: bool = profile != null and profile.bounty_claimed
	var progress: int = maxi(0, profile.boss_proofs[&"golem"] - profile.bounty_start_proofs) if accepted else 0
	var allowed: bool = id == WorldProgressionCatalog.BOUNTY_ID and profile != null and hub_access and not _busy
	return {"id": id, "accepted": accepted, "completed": progress >= 1, "claimed": claimed, "required": 1, "progress": mini(progress, 1), "reward_combo_id": WorldProgressionCatalog.BOUNTY_REWARD, "can_accept": allowed and not accepted, "can_claim": allowed and accepted and not claimed and progress >= 1 and inventory != null and inventory.equipment_bag_uids().size() < GearInventory.EQUIPMENT_BAG_CAPACITY, "can_reclaim": allowed and claimed and profile.unlocked_weapons.has(WorldProgressionCatalog.BOUNTY_REWARD) and _reclaimable_starter() != null}


func _reclaimable_starter() -> GearItem:
	if inventory == null: return null
	# Older saves may already contain a fresh regular starter after losing the
	# reward. Teach its owned sword; never recreate the original bounty UID.
	var starter: GearItem
	for item: GearItem in inventory.items.values():
		if item.definition_id == WorldProgressionCatalog.BOUNTY_REWARD: return null
		if item.equipment_definition == GearInventory.COMMON_SWORD and item.can_equip():
			if starter == null or item.uid == inventory.equipped_weapon_uid: starter = item
	return starter


func reclaim_bounty_moveset(id: StringName) -> bool:
	if not quote_bounty(id)["can_reclaim"]: return false
	_busy = true
	var sword: GearItem = _reclaimable_starter()
	var previous_id: StringName = sword.definition_id
	var previous_definition: EquipmentData = sword.equipment_definition
	var previous_weapons: Array[WeaponDefinition] = inventory.owned_weapons.duplicate()
	sword.equipment_definition = preload("res://data/equipment/ancient_sword_bounty.tres")
	sword.definition_id = WorldProgressionCatalog.BOUNTY_REWARD
	if not inventory.owned_weapons.has(sword.equipment_definition.moveset): inventory.owned_weapons.append(sword.equipment_definition.moveset)
	if not _save_safe():
		sword.definition_id = previous_id
		sword.equipment_definition = previous_definition
		inventory.owned_weapons.assign(previous_weapons)
		_busy = false
		return false
	_publish_commit()
	return true


func accept_bounty(id: StringName) -> bool:
	if not quote_bounty(id)["can_accept"]: return false
	_busy = true
	var previous: int = profile.bounty_start_proofs
	profile.bounty_accepted = true
	profile.bounty_start_proofs = profile.boss_proofs[&"golem"]
	if not _save_safe():
		profile.bounty_accepted = false
		profile.bounty_start_proofs = previous
		_busy = false
		return false
	_publish_commit()
	return true


func claim_bounty(id: StringName) -> bool:
	if not quote_bounty(id)["can_claim"]: return false
	_busy = true
	profile.bounty_claimed = true
	var had_reward: bool = profile.unlocked_weapons.has(WorldProgressionCatalog.BOUNTY_REWARD)
	if not had_reward: profile.unlocked_weapons.append(WorldProgressionCatalog.BOUNTY_REWARD)
	var reward: GearItem = inventory.add_equipment(load("res://data/equipment/ancient_sword_bounty.tres") as EquipmentData)
	reward.source = &"crafted"
	reward.loot_rolled = true
	if not _save_safe():
		profile.bounty_claimed = false
		if not had_reward: profile.unlocked_weapons.erase(WorldProgressionCatalog.BOUNTY_REWARD)
		inventory.items.erase(reward.uid)
		inventory.changed.emit()
		_busy = false
		return false
	_publish_commit()
	return true


func quote_enhance(uid: int) -> Dictionary:
	var item: GearItem = inventory.items.get(uid) if inventory != null else null
	var level: int = item.enhancement_level if item != null else 0
	var next: int = mini(12, level + 1)
	var grade: int = ceili(float(next) / 2.0)
	var stone: StringName = StringName("enhancement_stone_%d" % grade)
	var coins: int = next * 5
	return {"uid": uid, "level": level, "next_level": next, "stone_grade": grade, "stone_id": stone, "coin_cost": coins, "can_enhance": not _busy and hub_access and profile != null and item != null and item.kind == &"weapon" and item.can_equip() and level >= 0 and level < 12 and profile.material_stash.get(stone, 0) >= 1 and profile.coins >= coins}


func enhance_item(uid: int) -> bool:
	var quote: Dictionary = quote_enhance(uid)
	if not quote["can_enhance"]: return false
	_busy = true
	var item: GearItem = inventory.items[uid]
	var stone: StringName = quote["stone_id"]
	profile.material_stash[stone] -= 1
	profile.coins -= int(quote["coin_cost"])
	item.enhancement_level += 1
	if not _save_safe():
		profile.material_stash[stone] += 1
		profile.coins += int(quote["coin_cost"])
		item.enhancement_level -= 1
		_busy = false
		return false
	_publish_commit()
	return true


func quote_combine_stones(grade: int, batches: int = 1) -> Dictionary:
	var source: StringName = StringName("enhancement_stone_%d" % grade)
	var target: StringName = StringName("enhancement_stone_%d" % (grade + 1))
	var valid: bool = grade >= 1 and grade < 6 and batches > 0 and batches <= MaterialCatalog.MAX_COUNT / 5
	return {"grade": grade, "source_id": source, "target_id": target, "input_count": batches * 5 if valid else 0, "output_count": batches if valid else 0, "can_combine": valid and profile != null and hub_access and not _busy and profile.material_stash.get(source, 0) >= batches * 5 and profile.material_stash.get(target, 0) <= MaterialCatalog.MAX_COUNT - batches}


func combine_stones(grade: int, batches: int = 1) -> bool:
	var quote: Dictionary = quote_combine_stones(grade, batches)
	if not quote["can_combine"]: return false
	_busy = true
	var source: StringName = quote["source_id"]
	var target: StringName = quote["target_id"]
	profile.material_stash[source] -= batches * 5
	profile.material_stash[target] += batches
	if not _save_safe():
		profile.material_stash[source] += batches * 5
		profile.material_stash[target] -= batches
		_busy = false
		return false
	_publish_commit()
	return true


func register_recipe(recipe: ForgeRecipe) -> bool:
	if recipe == null or not recipe.valid() or forge_recipes.has(recipe.id): return false
	forge_recipes[recipe.id] = recipe
	return true


func _has_costs(costs: Dictionary) -> bool:
	if profile == null: return false
	for id: StringName in costs:
		if profile.material_stash.get(id, 0) < int(costs[id]): return false
	return true


func quote_forge(id: StringName) -> Dictionary:
	var recipe: ForgeRecipe = forge_recipes.get(id)
	var costs: Dictionary = recipe.costs() if recipe != null else {}
	var allowed: bool = recipe != null and recipe.valid() and profile != null and inventory != null and profile.learned_blueprints.has(recipe.required_blueprint()) and hub_access and not _busy and inventory.equipment_bag_uids().size() < GearInventory.EQUIPMENT_BAG_CAPACITY and profile.coins >= recipe.coin_cost and _has_costs(costs)
	return {"id": id, "blueprint_id": recipe.required_blueprint() if recipe != null else &"", "can_forge": allowed, "coin_cost": recipe.coin_cost if recipe != null else 0, "materials": costs, "quality": recipe.quality if recipe != null else 0, "chance": recipe.success_chance if recipe != null else 0.0}


func forge(id: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var quote: Dictionary = quote_forge(id)
	if not quote["can_forge"] or rng == null: return {"committed": false, "success": false, "uid": 0, "error": "unavailable"}
	_busy = true
	var previous_rng: int = rng.state
	var success: bool = rng.randf() < float(quote["chance"])
	var recipe: ForgeRecipe = forge_recipes[id]
	var item: GearItem
	if success:
		item = inventory.add_equipment(recipe.equipment, recipe.quality)
		item.source = &"crafted"
		item.loot_rolled = true
	profile.coins -= int(quote["coin_cost"])
	for material: StringName in quote["materials"]: profile.material_stash[material] -= int(quote["materials"][material])
	if not _save_safe():
		profile.coins += int(quote["coin_cost"])
		for material: StringName in quote["materials"]: profile.material_stash[material] += int(quote["materials"][material])
		if item != null: inventory.items.erase(item.uid)
		inventory.changed.emit()
		rng.state = previous_rng
		_busy = false
		return {"committed": false, "success": false, "uid": 0, "error": "save_failed"}
	_publish_commit()
	return {"committed": true, "success": success, "uid": item.uid if item != null else 0, "error": ""}


func quote_buy(id: StringName, quality: int) -> Dictionary:
	var basic: bool = id in [&"common_sword", &"starter_top", &"starter_pants", &"starter_boots", &"starter_gloves", &"starter_ring", &"starter_amulet"]
	var valid: bool = WorldProgressionCatalog.valid_id(id) and (basic or id.begins_with("world_")) and ResourceLoader.exists("res://data/equipment/%s.tres" % id) and quality in [GearItem.Quality.COMMON, GearItem.Quality.RARE]
	var cost: int = 20 if quality == GearItem.Quality.COMMON else 40
	return {"id": id, "quality": quality, "coin_cost": cost, "can_buy": valid and not _busy and hub_access and profile != null and inventory != null and (basic or profile.learned_blueprints.has(id)) and profile.coins >= cost and inventory.equipment_bag_uids().size() < GearInventory.EQUIPMENT_BAG_CAPACITY}


func buy_weapon(id: StringName, quality: int) -> bool:
	var quote: Dictionary = quote_buy(id, quality)
	if not quote["can_buy"]: return false
	_busy = true
	var item: GearItem = inventory.add_equipment(load("res://data/equipment/%s.tres" % id) as EquipmentData, quality)
	item.source = &"merchant"
	item.loot_rolled = true
	profile.coins -= int(quote["coin_cost"])
	if not _save_safe():
		profile.coins += int(quote["coin_cost"])
		inventory.items.erase(item.uid)
		inventory.changed.emit()
		_busy = false
		return false
	_publish_commit()
	return true


func quote_consumable(id: StringName) -> Dictionary:
	var costs: Dictionary = CONSUMABLE_RECIPES.get(id, {})
	return {"id": id, "materials": costs, "can_craft": CONSUMABLE_RECIPES.has(id) and inventory != null and not _busy and hub_access and inventory.consumables.get(id, 0) < MaterialCatalog.MAX_COUNT and _has_costs(costs)}


func craft_consumable(id: StringName) -> bool:
	var quote: Dictionary = quote_consumable(id)
	if not quote["can_craft"]: return false
	_busy = true
	for material: StringName in quote["materials"]: profile.material_stash[material] -= int(quote["materials"][material])
	inventory.consumables[id] += 1
	if not _save_safe():
		for material: StringName in quote["materials"]: profile.material_stash[material] += int(quote["materials"][material])
		inventory.consumables[id] -= 1
		_busy = false
		return false
	_publish_commit()
	return true


func quote_buy_consumable(id: StringName) -> Dictionary:
	var price: int = 10 if id == &"potion" else 0
	return {"id": id, "quantity": 1, "coin_cost": price, "can_buy": price > 0 and not _busy and hub_access and profile != null and inventory != null and profile.coins >= price and inventory.consumables.get(id, 0) < MaterialCatalog.MAX_COUNT}


func buy_consumable(id: StringName) -> bool:
	var quote: Dictionary = quote_buy_consumable(id)
	if not quote["can_buy"]: return false
	_busy = true
	profile.coins -= int(quote["coin_cost"])
	inventory.consumables[id] += 1
	if not _save_safe():
		profile.coins += int(quote["coin_cost"])
		inventory.consumables[id] -= 1
		_busy = false
		return false
	_publish_commit()
	return true


func deposit(id: StringName, amount: int) -> bool:
	if not _can_transfer(id, amount) or inventory.materials.get(id, 0) < amount or profile.material_stash[id] > MaterialCatalog.MAX_COUNT - amount:
		return false
	return _transfer(id, amount)


func withdraw(id: StringName, amount: int) -> bool:
	if not _can_transfer(id, amount) or profile.material_stash[id] < amount or inventory.materials.get(id, 0) > MaterialCatalog.MAX_COUNT - amount:
		return false
	return _transfer(id, -amount)


func _can_transfer(id: StringName, amount: int) -> bool:
	return material_capability(id,amount)["transfer_allowed"]

func material_capability(id: StringName, amount: int = 1) -> Dictionary:
	# Detached policy/quote for service cards. The same owner still performs IO.
	var policy: Dictionary = MaterialCatalog.material_policy(id)
	var allowed: bool = policy["ordinary_transfer"] and not _busy and hub_access and profile!=null and not profile.read_only and inventory!=null and amount>0 and amount<=MaterialCatalog.MAX_COUNT
	policy.merge({"id":id,"transfer_allowed":allowed,"can_deposit":allowed and inventory.materials.get(id,0)>=amount and profile.material_stash[id]<=MaterialCatalog.MAX_COUNT-amount,"can_withdraw":allowed and profile.material_stash[id]>=amount and inventory.materials.get(id,0)<=MaterialCatalog.MAX_COUNT-amount})
	return policy


func _transfer(id: StringName, signed_deposit: int) -> bool:
	_busy = true
	profile.material_stash[id] += signed_deposit
	inventory.materials[id] = inventory.materials.get(id, 0) - signed_deposit
	if not _save_safe():
		profile.material_stash[id] -= signed_deposit
		inventory.materials[id] += signed_deposit
		_busy = false
		return false
	_publish_commit()
	return true


func deposit_all() -> bool:
	if _busy or not hub_access or profile == null or profile.read_only or inventory == null:
		return false
	var amounts: Dictionary[StringName, int] = MaterialCatalog.empty_counts()
	var total: int = 0
	for id: StringName in MaterialCatalog.IDS:
		var amount: int = inventory.materials.get(id, 0)
		if MaterialCatalog.material_policy(id)["lineage_bound"] and amount>0: return false
		if not MaterialCatalog.valid_count(amount) or profile.material_stash[id] > MaterialCatalog.MAX_COUNT - amount:
			return false
		amounts[id] = amount
		total += amount
	if total == 0:
		return false
	_busy = true
	for id: StringName in MaterialCatalog.IDS:
		profile.material_stash[id] += amounts[id]
		inventory.materials[id] -= amounts[id]
	if not _save_safe():
		for id: StringName in MaterialCatalog.IDS:
			profile.material_stash[id] -= amounts[id]
			inventory.materials[id] += amounts[id]
		_busy = false
		return false
	_publish_commit()
	return true


func quote_bag_material_sale(id: StringName, amount: int = 1) -> Dictionary:
	var price: int = MaterialCatalog.SELL_PRICES.get(id, 0)
	var owned: int = inventory.materials.get(id, 0) if inventory != null else 0
	var total: int = price * amount
	var valid: bool = price > 0 and MaterialCatalog.valid_count(amount) and amount > 0 and MaterialCatalog.valid_count(owned) and owned >= amount and total <= MaterialCatalog.MAX_COUNT
	return {"id":id, "quantity":amount, "owned":owned, "unit_price":price, "total":total, "can_sell":valid and not _busy and hub_access and profile != null and not profile.read_only and profile.coins <= MaterialCatalog.MAX_COUNT - total}

func sell_bag_material(id: StringName, amount: int = 1) -> bool:
	var quote: Dictionary = quote_bag_material_sale(id, amount)
	if not quote["can_sell"]: return false
	_busy = true
	inventory.materials[id] -= amount
	profile.coins += int(quote["total"])
	if not _save_safe():
		inventory.materials[id] += amount
		profile.coins -= int(quote["total"])
		_busy = false
		return false
	_publish_commit()
	return true

func quote_bag_equipment_sale(uid: int) -> Dictionary:
	var item: GearItem = inventory.items.get(uid) if inventory != null else null
	var eligible: bool = false
	var price: int = 0
	if item != null and item.quality in [GearItem.Quality.COMMON, GearItem.Quality.RARE]:
		var basic: bool = false
		if item.equipment_definition != null:
			var id: StringName = item.equipment_definition.id
			basic = item.equipment_definition == GearInventory.COMMON_SWORD or item.equipment_definition in GearInventory.STARTER_CLOTHING or String(id).begins_with("world_")
		else:
			# These existing monster drops use legacy WeaponDefinition, not EquipmentData.
			basic = item.kind == &"weapon" and item.definition_id in [&"ancient_sword", &"shadow_dagger", &"storm_arcane_staff"] and item.source == &"drop" and item.loot_rolled and item.broken
		var ordinary_source: bool = item.source in [&"", &"drop", &"merchant", &"crafted", &"forge", &"starter"]
		eligible = basic and ordinary_source and inventory.equipment_bag_uids().has(uid) and uid != inventory.catalyst_uid and not inventory.slot_uids.has(uid)
		if eligible:
			price = 5 if item.quality == GearItem.Quality.COMMON else 10
			if item.broken: price = 2 if item.quality == GearItem.Quality.COMMON else 5
	return {"uid":uid, "quantity":1, "eligible":eligible, "total":price, "can_sell":eligible and not _busy and hub_access and profile != null and not profile.read_only and profile.coins <= MaterialCatalog.MAX_COUNT - price}

func sell_bag_equipment(uid: int) -> bool:
	var quote: Dictionary = quote_bag_equipment_sale(uid)
	if not quote["can_sell"]: return false
	_busy = true
	var item: GearItem = inventory.items[uid]
	var positions: Array[int] = inventory.equipment_positions.duplicate()
	inventory.items.erase(uid)
	profile.coins += int(quote["total"])
	if not _save_safe():
		inventory.items[uid] = item
		inventory.equipment_positions.assign(positions)
		profile.coins -= int(quote["total"])
		_busy = false
		return false
	_publish_commit()
	return true

func quote_crystal_sale() -> Dictionary:
	return quote_material_sale(&"crystal")


func quote_material_sale(id: StringName) -> Dictionary:
	var unit_price: int = MaterialCatalog.SELL_PRICES.get(id, 0)
	var quantity: int = profile.material_stash.get(id, 0) if profile != null else 0
	var proceeds: int = quantity * unit_price
	var valid: bool = unit_price > 0 and id in MaterialCatalog.IDS and MaterialCatalog.valid_count(quantity)
	return {"id": id, "quantity": quantity, "unit_price": unit_price, "total": proceeds, "can_sell": valid and profile != null and hub_access and not _busy and quantity > 0 and profile.coins <= MaterialCatalog.MAX_COUNT - proceeds}


func sell_all_crystals() -> bool:
	return sell_material(&"crystal")


func sell_material(id: StringName) -> bool:
	var quote: Dictionary = quote_material_sale(id)
	if not quote["can_sell"]:
		return false
	_busy = true
	var previous_coins: int = profile.coins
	var quantity: int = quote["quantity"]
	profile.coins += int(quote["total"])
	profile.material_stash[id] = 0
	if not _save_safe():
		profile.coins = previous_coins
		profile.material_stash[id] = quantity
		_busy = false
		return false
	_publish_commit()
	return true


func quote_repair(uid: int) -> Dictionary:
	var item: GearItem = inventory.items.get(uid) if inventory != null else null
	var cost: Dictionary[StringName, int] = MaterialCatalog.repair_cost(item.quality if item != null else GearItem.Quality.COMMON)
	var has_materials: bool = profile != null and profile.material_stash.get(&"metal", 0) >= cost[&"metal"] and profile.material_stash.get(&"dust", 0) >= cost[&"dust"]
	var blank: bool = item != null and item.is_forging_blank()
	return {"uid": uid, "metal": cost[&"metal"], "dust": cost[&"dust"], "requires_forging": blank, "can_repair": not _busy and hub_access and item != null and inventory.equipment_slot(uid) >= 0 and item.broken and not blank and has_materials}


func repair_item(uid: int) -> bool:
	var quote: Dictionary = quote_repair(uid)
	if not quote["can_repair"]:
		return false
	_busy = true
	var item: GearItem = inventory.items[uid]
	profile.material_stash[&"metal"] -= int(quote["metal"])
	profile.material_stash[&"dust"] -= int(quote["dust"])
	if not item.repair() or not _save_safe():
		item.broken = true
		profile.material_stash[&"metal"] += int(quote["metal"])
		profile.material_stash[&"dust"] += int(quote["dust"])
		_busy = false
		return false
	_publish_commit()
	return true


func _publish_commit() -> void:
	# Keep the lock through callbacks: one UI click cannot recursively sell again.
	profile.changed.emit()
	if inventory != null:
		inventory.changed.emit()
	changed.emit()
	_busy = false

func quote_social_help(life_owner: NpcWorldState, id: String) -> Dictionary:
	var available: bool = not _busy and hub_access and profile != null and inventory != null and OpeningSocialRuntime.can_help(profile, life_owner, id)
	return {"can_help":available, "material":NpcSocialCatalog.HELP_MATERIAL, "cost":NpcSocialCatalog.HELP_COST}

func help_resident(life_owner: NpcWorldState, id: String) -> bool:
	if not quote_social_help(life_owner,id)["can_help"]: return false
	_busy = true
	var success: bool = OpeningSocialRuntime.help(profile,life_owner,id)
	if success: _publish_commit()
	else: _busy = false
	return success

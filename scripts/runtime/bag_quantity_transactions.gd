class_name BagQuantityTransactions
extends RefCounted
## One quote, one guarded carried-ledger commit for a chosen quantity.
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")

static func quote(owner: EconomySession, kind: StringName, id: StringName, amount: int = 1, quality: int = 0, runes: RuneLearningService = null) -> Dictionary:
	var result: Dictionary = {"kind":kind,"id":id,"quantity":amount,"quality":quality,"can_commit":false,"maximum":0,"coin_cost":0,"total":0,"materials":{},"signature":""}
	if owner == null or not owner._bag_transactions_available(): return result
	var unit: Dictionary = {}
	var allowed: bool = false
	var maximum: int = MaterialCatalog.MAX_COUNT
	var price: int = 0
	var costs: Dictionary = {}
	match kind:
		&"equipment":
			unit = owner.quote_buy(id,quality); allowed = unit["can_buy"]; price = unit["coin_cost"]
			maximum = mini(GearInventory.EQUIPMENT_BAG_CAPACITY-owner.inventory.equipment_bag_uids().size(), GearInventoryCodec.MAX_ITEMS-owner.inventory.items.size())
		&"consumable":
			unit = owner.quote_buy_consumable(id); allowed = unit["can_buy"]; price = unit["coin_cost"]
			maximum = MaterialCatalog.MAX_COUNT-int(owner.inventory.consumables.get(id,0))
		&"consumable_craft":
			unit = owner.quote_consumable(id); allowed = unit["can_craft"]; costs = unit["materials"]
			maximum = MaterialCatalog.MAX_COUNT-int(owner.inventory.consumables.get(id,0))
		&"forge":
			unit = owner.quote_forge(id); allowed = unit["can_forge"]; price = unit["coin_cost"]; costs = unit["materials"]
			maximum = mini(GearInventory.EQUIPMENT_BAG_CAPACITY-owner.inventory.equipment_bag_uids().size(), GearInventoryCodec.MAX_ITEMS-owner.inventory.items.size())
		&"rune_craft":
			if runes == null or runes.economy != owner: return result
			unit = runes.quote(id); allowed = unit["can_craft"]; costs = unit["craft_materials"]
			maximum = GearInventoryCodec.MAX_ITEMS-owner.inventory.items.size()
		&"material_sale":
			unit = owner.quote_bag_material_sale(id); allowed = unit["can_sell"]
			maximum = int(unit["owned"])
			if int(unit["unit_price"]) > 0: maximum = mini(maximum,int((MaterialCatalog.MAX_COUNT-owner.profile.coins)/int(unit["unit_price"])))
		_:
			return result
	if price > 0: maximum = mini(maximum,int(owner.profile.coins/price))
	for material: StringName in costs:
		if int(costs[material]) > 0: maximum = mini(maximum,int(int(owner.inventory.materials.get(material,0))/int(costs[material])))
	result["maximum"] = maxi(0,maximum) if allowed else 0
	if amount < 1 or amount > MaterialCatalog.MAX_COUNT: return result
	result["coin_cost"] = price*amount
	if kind == &"material_sale": result["total"] = int(unit["unit_price"])*amount
	for material: StringName in costs: result["materials"][material] = int(costs[material])*amount
	result["chance"] = unit.get("chance",1.0)
	if kind == &"forge":
		result["quality"] = int(unit["quality"])
		result["blueprint_id"] = unit["blueprint_id"]
	result["can_commit"] = allowed and amount <= maximum
	result["signature"] = Writer.canonical([kind,id,amount,result["quality"],result["coin_cost"],result["total"],result["materials"],owner.profile.coins,GearInventoryCodec.encode(owner.inventory)]).sha256_text()
	return result

static func commit(owner: EconomySession, offer: Dictionary, runes: RuneLearningService = null, rng: RandomNumberGenerator = null) -> Dictionary:
	var failed: Dictionary = {"committed":false,"successes":0,"quantity":0}
	if not offer.has_all(["kind","id","quantity","quality","signature"]): return failed
	if not MaterialCatalog.valid_count(offer["quantity"]) or int(offer["quantity"]) <= 0: return failed
	var current: Dictionary = quote(owner,offer["kind"],offer["id"],int(offer["quantity"]),int(offer["quality"]),runes)
	if not current["can_commit"] or current["signature"] != offer["signature"] or (current["kind"] == &"forge" and rng == null): return failed
	var inventory: GearInventory = owner.inventory
	var items: Dictionary[int,GearItem] = inventory.items.duplicate()
	var materials: Dictionary = inventory.materials.duplicate()
	var consumables: Dictionary = inventory.consumables.duplicate()
	var bag: Dictionary = inventory.bag.duplicate()
	var positions: Array[int] = inventory.equipment_positions.duplicate()
	var coins: int = owner.profile.coins
	var rng_state: int = rng.state if rng != null else 0
	var amount: int = int(current["quantity"])
	var id: StringName = current["id"]
	var successes: int = 0
	owner._busy = true
	owner.profile.coins += int(current["total"])-int(current["coin_cost"])
	for material: StringName in current["materials"]: inventory.materials[material] -= int(current["materials"][material])
	match current["kind"]:
		&"material_sale": inventory.materials[id] -= amount; successes = amount
		&"consumable", &"consumable_craft": inventory.consumables[id] += amount; successes = amount
		&"equipment", &"forge", &"rune_craft":
			for _i: int in amount:
				var item: GearItem
				if current["kind"] == &"rune_craft":
					item = inventory.add_item(&"rune",id,GearItem.Quality.COMMON)
					inventory.bag[id] += 1
				elif current["kind"] == &"forge":
					if rng.randf() >= float(current["chance"]): continue
					var recipe: ForgeRecipe = owner.forge_recipes[id]
					item = inventory.add_equipment(recipe.equipment,recipe.quality,false)
				else:
					item = inventory.add_equipment(load("res://data/equipment/%s.tres" % id) as EquipmentData,int(current["quality"]),false)
				item.source = &"merchant" if current["kind"] == &"equipment" else &"crafted"
				item.loot_rolled = true
				successes += 1
	if not owner._save_safe():
		owner.profile.coins = coins
		inventory.items.assign(items); inventory.materials.assign(materials)
		inventory.consumables.assign(consumables); inventory.bag.assign(bag)
		inventory.equipment_positions.assign(positions)
		if rng != null: rng.state = rng_state
		owner._busy = false
		return failed
	owner._publish_commit()
	return {"committed":true,"successes":successes,"quantity":amount}

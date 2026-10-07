class_name GearInventoryCodec
extends RefCounted
## Only safe-Hub inventories persist. No live Resource/Node is serialized.
const MAX_ITEMS: int = 128
const MAX_UID: int = 2147483647

static func encode(inventory: GearInventory) -> Dictionary:
	inventory._ensure_slots()
	var records: Array[Dictionary] = []
	for item: GearItem in inventory.items.values():
		records.append({"uid": item.uid, "kind": item.kind, "id": item.definition_id, "quality": item.quality, "equipment": item.equipment_definition.resource_path if item.equipment_definition != null else "", "source": item.source, "drop_bonus": item.drop_bonus, "affix_id": item.affix_id, "affix_value": item.affix_value, "broken": item.broken, "loot_rolled": item.loot_rolled, "enhancement_level": item.enhancement_level})
	return {"items": records, "equipment": inventory.equipment_uids.duplicate(), "weapon": inventory.equipped_weapon_uid, "catalyst": inventory.catalyst_uid, "slots": inventory.slot_uids.duplicate(), "materials": inventory.materials.duplicate(), "consumables": inventory.consumables.duplicate(), "run_coins": inventory.run_coins}

static func valid(data: Dictionary) -> bool:
	if data.is_empty(): return true
	if not MaterialCatalog.valid_count(data.get("run_coins", 0)): return false
	if not data.get("items") is Array or data["items"].size() > MAX_ITEMS or not data.get("equipment") is Array or data["equipment"].size() != EquipmentData.SLOT_COUNT or not data.get("slots") is Array or data["slots"].size() != 8 or not data.get("materials") is Dictionary or not data.get("consumables") is Dictionary: return false
	var uids: Dictionary[int, Dictionary] = {}
	for raw: Variant in data["items"]:
		if not raw is Dictionary or not _valid_item(raw) or uids.has(int(raw["uid"])): return false
		uids[int(raw["uid"])] = raw
	var destinations: Array[int] = []
	for slot: int in EquipmentData.SLOT_COUNT:
		var uid: Variant = data["equipment"][slot]
		if not _valid_uid(uid, true): return false
		if int(uid) == 0: continue
		if not uids.has(int(uid)) or destinations.has(int(uid)) or str(uids[int(uid)]["kind"]) != str(EquipmentData.SLOT_KINDS[slot]): return false
		if uids[int(uid)].get("broken", false) or (uids[int(uid)].get("source", "") == "drop" and int(uids[int(uid)]["quality"]) >= GearItem.Quality.VERY_RARE): return false
		destinations.append(int(uid))
	for uid: Variant in data["slots"]:
		if not _valid_uid(uid, true): return false
		if int(uid) == 0: continue
		if not uids.has(int(uid)) or destinations.has(int(uid)) or str(uids[int(uid)]["kind"]) != "rune": return false
		destinations.append(int(uid))
	if not _valid_uid(data.get("weapon", 0), true) or int(data.get("weapon", 0)) != int(data["equipment"][0]) or not _valid_uid(data.get("catalyst", 0), true): return false
	var catalyst: int = int(data.get("catalyst", 0))
	if catalyst > 0 and (not uids.has(catalyst) or str(uids[catalyst]["kind"]) != "catalyst"): return false
	for id: Variant in data["materials"]:
		if StringName(str(id)) not in MaterialCatalog.IDS or not MaterialCatalog.valid_count(data["materials"][id]): return false
	for id: Variant in data["consumables"]:
		if str(id) not in ["potion", "bandage", "antidote", "trap"] or not MaterialCatalog.valid_count(data["consumables"][id]): return false
	return true

static func _valid_uid(value: Variant, zero_allowed: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= (0.0 if zero_allowed else 1.0) and float(value) <= MAX_UID

static func _valid_item(item: Dictionary) -> bool:
	if not _valid_uid(item.get("uid")) or not WorldProgressionCatalog.valid_id(item.get("id")) or not MaterialCatalog.valid_count(item.get("quality")) or int(item["quality"]) > GearItem.Quality.DIVINE or not MaterialCatalog.valid_count(item.get("enhancement_level", 0)) or int(item.get("enhancement_level", 0)) > 12: return false
	var kind: StringName = StringName(str(item.get("kind", "")))
	if kind != &"weapon" and int(item.get("enhancement_level", 0)) > 0: return false
	if kind not in EquipmentData.SLOT_KINDS and kind not in [&"rune", &"catalyst", &"relic"]: return false
	for key: String in ["broken", "loot_rolled"]:
		if item.has(key) and not item[key] is bool: return false
	var source: String = str(item.get("source", ""))
	if source != "" and StringName(source) not in LootAffixRoller.SOURCES: return false
	for key: String in ["drop_bonus", "affix_value"]:
		if not (item.get(key, 0.0) is int or item.get(key, 0.0) is float) or not is_finite(float(item.get(key, 0.0))): return false
	if float(item.get("drop_bonus", 0.0)) < 0.0 or float(item.get("drop_bonus", 0.0)) > 0.08: return false
	var affix: StringName = StringName(str(item.get("affix_id", "")))
	if affix != &"" and (affix not in LootAffixCatalog.IDS or not is_equal_approx(LootAffixCatalog.bounded_value(affix, float(item.get("affix_value", 0.0))), float(item.get("affix_value", 0.0)))): return false
	var id: StringName = StringName(str(item["id"]))
	var equipment: String = str(item.get("equipment", ""))
	if not equipment.is_empty():
		if not equipment.begins_with("res://data/equipment/") or not equipment.ends_with(".tres") or equipment.contains("..") or not ResourceLoader.exists(equipment): return false
		var definition: EquipmentData = load(equipment) as EquipmentData
		return definition != null and definition.id == id and definition.slot_type >= 0 and definition.slot_type < EquipmentData.SLOT_COUNT and EquipmentData.SLOT_KINDS[definition.slot_type] == kind
	if kind == &"weapon": return ResourceLoader.exists("res://data/weapons/%s.tres" % id)
	if kind == &"rune": return id in [&"fire", &"wind", &"lightning", &"ice", &"poison"]
	if kind == &"catalyst": return id == &"starter_catalyst"
	if kind == &"relic": return ResourceLoader.exists("res://data/relics/%s.tres" % id)
	return false

static func decode(data: Dictionary) -> GearInventory:
	if data.is_empty() or not valid(data): return null
	var inventory := GearInventory.new()
	inventory._ensure_slots()
	var largest_uid: int = 0
	for record: Dictionary in data["items"]:
		var item := GearItem.new()
		item.uid = int(record["uid"])
		item.kind = StringName(str(record["kind"]))
		item.definition_id = StringName(str(record["id"]))
		item.quality = int(record["quality"])
		var equipment: String = str(record.get("equipment", ""))
		if not equipment.is_empty(): item.equipment_definition = load(equipment) as EquipmentData
		item.source = StringName(str(record.get("source", "")))
		item.drop_bonus = float(record.get("drop_bonus", 0.0))
		item.affix_id = StringName(str(record.get("affix_id", "")))
		item.affix_value = float(record.get("affix_value", 0.0))
		item.broken = record.get("broken", false)
		item.loot_rolled = record.get("loot_rolled", false)
		item.enhancement_level = int(record.get("enhancement_level", 0))
		inventory.items[item.uid] = item
		largest_uid = maxi(largest_uid, item.uid)
		if item.kind == &"rune": inventory.bag[item.definition_id] += 1
		if item.kind == &"weapon":
			var weapon: WeaponDefinition = item.equipment_definition.moveset if item.equipment_definition != null else load("res://data/weapons/%s.tres" % item.definition_id) as WeaponDefinition
			if not inventory.owned_weapons.has(weapon): inventory.owned_weapons.append(weapon)
	inventory.equipment_uids.assign(data["equipment"])
	inventory.equipped_weapon_uid = int(data["weapon"])
	inventory.catalyst_uid = int(data["catalyst"])
	inventory.slot_uids.assign(data["slots"])
	for index: int in inventory.slot_uids.size():
		var item: GearItem = inventory.items.get(inventory.slot_uids[index])
		if item != null:
			inventory.slots[index] = item.definition_id
			inventory.bag[item.definition_id] -= 1
	for id: StringName in MaterialCatalog.IDS: inventory.materials[id] = int(data["materials"].get(String(id), data["materials"].get(id, 0)))
	for id: StringName in inventory.consumables: inventory.consumables[id] = int(data["consumables"].get(String(id), data["consumables"].get(id, 0)))
	inventory.explicit_weapon_selection = true
	inventory.run_coins = int(data.get("run_coins", 0))
	CombatIds.reserve_through(largest_uid)
	return inventory

static func copy_into(destination: GearInventory, source: GearInventory) -> void:
	var copy: GearInventory = HubPreparation.clone_inventory(source)
	destination.items.assign(copy.items)
	destination.bag.assign(copy.bag)
	destination.slots.assign(copy.slots)
	destination.slot_uids.assign(copy.slot_uids)
	destination.equipment_uids.assign(copy.equipment_uids)
	destination.owned_weapons.assign(copy.owned_weapons)
	destination.materials.assign(copy.materials)
	destination.consumables.assign(copy.consumables)
	destination.equipped_weapon_uid = copy.equipped_weapon_uid
	destination.catalyst_uid = copy.catalyst_uid
	destination.explicit_weapon_selection = copy.explicit_weapon_selection
	destination.run_coins = copy.run_coins
	destination.changed.emit()

class_name GearInventory
extends RefCounted
## One owned-item ledger, seven equipment destinations and separate rune sockets.

signal changed
const RUNES: Array[RuneData] = [preload("res://data/runes/FireRune.tres"), preload("res://data/runes/WindRune.tres"), preload("res://data/runes/LightningRune.tres"), preload("res://data/runes/IceRune.tres"), preload("res://data/runes/PoisonRune.tres")]
var bag: Dictionary[StringName, int] = {&"fire": 0, &"wind": 0, &"lightning": 0, &"ice": 0, &"poison": 0}
var slots: Array[StringName] = [&"", &"", &"", &""] # Catalyst 0..2, weapon 3
var owned_weapons: Array[WeaponDefinition] = []
var items: Dictionary[int, GearItem] = {}
var slot_uids: Array[int] = [0, 0, 0, 0, 0, 0]
var equipped_weapon_uid: int = 0
var equipment_uids: Array[int] = [0, 0, 0, 0, 0, 0, 0]
var explicit_weapon_selection: bool = false
var equipment_positions: Array[int] = []
const EQUIPMENT_BAG_CAPACITY: int = 20
const COMMON_SWORD: EquipmentData = preload("res://data/equipment/common_sword.tres")
const STARTER_CLOTHING: Array[EquipmentData] = [
	preload("res://data/equipment/starter_top.tres"),
	preload("res://data/equipment/starter_pants.tres"),
	preload("res://data/equipment/starter_boots.tres"),
	preload("res://data/equipment/starter_gloves.tres"),
	preload("res://data/equipment/starter_ring.tres"),
	preload("res://data/equipment/starter_amulet.tres"),
]
var catalyst_uid: int = 0
var materials: Dictionary[StringName, int] = MaterialCatalog.empty_counts()
var consumables: Dictionary[StringName, int] = {&"potion": 0, &"bandage": 0, &"antidote": 0, &"trap": 0}
var catalyst_capacity: int = 3
var weapon_capacity: int = 1
var permanent_rune_capacity: int = 0
var run_coins: int = 0
const CATALYST_INDICES: Array[int] = [0, 1, 2, 4, 5]


func add_material(id: StringName, amount: int = 1) -> bool:
	if id not in MaterialCatalog.IDS or amount <= 0 or amount > MaterialCatalog.MAX_COUNT or materials.get(id, 0) > MaterialCatalog.MAX_COUNT - amount:
		return false
	materials[id] = materials.get(id, 0) + amount
	changed.emit()
	return true


func add_consumable(id: StringName, amount: int = 1) -> bool:
	if not consumables.has(id) or amount <= 0 or amount > MaterialCatalog.MAX_COUNT or consumables[id] > MaterialCatalog.MAX_COUNT - amount:
		return false
	consumables[id] += amount
	changed.emit()
	return true


func add_rune(id: StringName, quality: int = GearItem.Quality.COMMON) -> bool:
	if not bag.has(id):
		return false
	bag[id] += 1
	add_item(&"rune", id, quality)
	changed.emit()
	return true


func equip(slot: int, id: StringName) -> bool:
	_ensure_slots()
	if slot < 0 or slot >= slots.size() or (id != &"" and not bag.has(id)):
		return false
	if (slot in [4, 5] and CATALYST_INDICES.find(slot) >= catalyst_capacity) or (slot in [6, 7] and slot - 5 >= weapon_capacity):
		return false
	if slots[slot] == id:
		return true
	if id != &"" and bag[id] <= 0:
		return false
	var old: StringName = slots[slot]
	if old != &"":
		bag[old] += 1
	if id != &"":
		bag[id] -= 1
		slot_uids[slot] = _available_rune_uid(id)
	else:
		slot_uids[slot] = 0
	slots[slot] = id
	changed.emit()
	return true


func swap_slots(a: int, b: int) -> bool:
	_ensure_slots()
	if a < 0 or b < 0 or a >= slots.size() or b >= slots.size():
		return false
	if (a in [4, 5] and CATALYST_INDICES.find(a) >= catalyst_capacity) or (b in [4, 5] and CATALYST_INDICES.find(b) >= catalyst_capacity):
		return false
	if (a in [6, 7] and a - 5 >= weapon_capacity) or (b in [6, 7] and b - 5 >= weapon_capacity):
		return false
	var held: StringName = slots[a]
	slots[a] = slots[b]
	slots[b] = held
	var held_uid: int = slot_uids[a]
	slot_uids[a] = slot_uids[b]
	slot_uids[b] = held_uid
	changed.emit()
	return true


func get_rune(id: StringName) -> RuneData:
	for rune: RuneData in RUNES:
		if rune.id == id:
			return rune
	return null


func catalyst_runes() -> Array[RuneData]:
	var result: Array[RuneData] = []
	for slot: int in CATALYST_INDICES:
		if slot >= slots.size():
			continue
		if slots[slot] != &"":
			result.append(get_rune(slots[slot]))
	return result


func total_shards() -> int:
	var total: int = 0
	for amount: int in bag.values():
		total += amount
	for id: StringName in slots:
		if id != &"":
			total += 1
	return total


func _ensure_slots() -> void:
	while slots.size() < 8:
		slots.append(&"")
	while slot_uids.size() < 8:
		slot_uids.append(0)


func add_item(kind: StringName, id: StringName, quality: int = GearItem.Quality.COMMON) -> GearItem:
	var item := GearItem.new()
	item.uid = CombatIds.next_id()
	item.kind = kind
	item.definition_id = id
	item.quality = clampi(quality, 0, GearItem.Quality.DIVINE)
	if kind == &"weapon" and id == COMMON_SWORD.id:
		item.equipment_definition = COMMON_SWORD
	items[item.uid] = item
	return item


func _available_rune_uid(id: StringName) -> int:
	var best: GearItem
	for item: GearItem in items.values():
		if item.kind == &"rune" and item.definition_id == id and not slot_uids.has(item.uid):
			if best == null or item.quality > best.quality:
				best = item
	return best.uid if best != null else 0


func equip_uid(slot: int, uid: int) -> bool:
	if not items.has(uid) or items[uid].kind != &"rune" or slot_uids.has(uid):
		return false
	if not equip(slot, items[uid].definition_id):
		return false
	slot_uids[slot] = uid
	changed.emit()
	return true


func dismantle(uid: int) -> bool:
	if not items.has(uid) or uid == catalyst_uid or uid == equipped_weapon_uid or equipment_uids.has(uid) or slot_uids.has(uid):
		return false
	var item: GearItem = items[uid]
	if item.kind == &"relic":
		return false
	if item.quality < GearItem.Quality.COMMON or item.quality > GearItem.Quality.DIVINE:
		return false
	var metal_gain: int = 0 if item.kind == &"rune" else 3 + item.quality * 2
	var dust_gain: int = 2 + item.quality if item.kind == &"rune" else 1 + item.quality
	# Check both destinations before consuming the rune count or deleting its UID.
	# A full stash/run ledger must leave the original item available for retry.
	if not MaterialCatalog.valid_count(materials[&"metal"]) or not MaterialCatalog.valid_count(materials[&"dust"]) or materials[&"metal"] > MaterialCatalog.MAX_COUNT - metal_gain or materials[&"dust"] > MaterialCatalog.MAX_COUNT - dust_gain:
		return false
	if item.kind == &"rune":
		if bag[item.definition_id] <= 0:
			return false
		bag[item.definition_id] -= 1
	materials[&"metal"] += metal_gain
	materials[&"dust"] += dust_gain
	items.erase(uid)
	changed.emit()
	return true


func equip_catalyst_set(ids: Array[StringName]) -> bool:
	if ids.size() > catalyst_capacity:
		return false
	var available: Dictionary = bag.duplicate()
	for slot: int in CATALYST_INDICES:
		if slot < slots.size() and slots[slot] != &"":
			available[slots[slot]] += 1
	for id: StringName in ids:
		if not available.has(id) or available[id] <= 0:
			return false
		available[id] -= 1
	for slot: int in CATALYST_INDICES:
		if slot < slots.size():
			equip(slot, &"")
	for index: int in ids.size():
		equip(CATALYST_INDICES[index], ids[index])
	return true


func craft(id: StringName, weapon_uid: int = 0) -> bool:
	var metal: int = 0
	var dust: int = 0
	match id:
		&"upgrade":
			# Advanced weapons are forged by the blacksmith, never upgraded at camp.
			if not items.has(weapon_uid) or items[weapon_uid].kind != &"weapon" or items[weapon_uid].quality >= GearItem.Quality.RARE:
				return false
			metal = 6 + items[weapon_uid].quality * 3
			dust = 4 + items[weapon_uid].quality * 2
		&"potion": dust = 4
		&"bandage": dust = 2
		&"trap": metal = 4
		_: return false
	if materials[&"metal"] < metal or materials[&"dust"] < dust:
		return false
	materials[&"metal"] -= metal
	materials[&"dust"] -= dust
	if id == &"upgrade":
		items[weapon_uid].quality += 1
	else:
		consumables[id] += 1
	changed.emit()
	return true


func equipment_slot(uid: int) -> int:
	var item: GearItem = items.get(uid)
	if item == null:
		return -1
	if item.equipment_definition != null:
		return item.equipment_definition.slot_type
	return EquipmentData.SlotType.WEAPON if item.kind == &"weapon" else -1


func equipment_bag_uids() -> Array[int]:
	var result: Array[int] = []
	for uid: int in items:
		if equipment_slot(uid) >= 0 and uid != equipped_weapon_uid and not equipment_uids.has(uid):
			result.append(uid)
	result.sort()
	return result


func equipment_grid_uids() -> Array[int]:
	var available: Array[int] = equipment_bag_uids()
	if equipment_positions.size() < EQUIPMENT_BAG_CAPACITY:
		equipment_positions.resize(EQUIPMENT_BAG_CAPACITY)
		equipment_positions.fill(0)
	for index: int in equipment_positions.size():
		if not available.has(equipment_positions[index]):
			equipment_positions[index] = 0
	for uid: int in available:
		if equipment_positions.has(uid):
			continue
		var free: int = equipment_positions.find(0)
		if free >= 0:
			equipment_positions[free] = uid
		else:
			# Legacy/debug loot is never deleted. Extra pages expose that overflow.
			equipment_positions.append(uid)
	return equipment_positions.duplicate()


func add_equipment(data: EquipmentData, quality: int = GearItem.Quality.COMMON) -> GearItem:
	if data == null or data.id == &"" or data.slot_type < 0 or data.slot_type >= equipment_uids.size() or equipment_bag_uids().size() >= EQUIPMENT_BAG_CAPACITY:
		return null
	if data.slot_type == EquipmentData.SlotType.WEAPON and data.moveset == null:
		return null
	var item: GearItem = add_item(EquipmentData.SLOT_KINDS[data.slot_type], data.id, quality)
	item.equipment_definition = data
	changed.emit()
	return item


func install_starter_clothing() -> void:
	# Idempotent: existing owned UIDs are reused, and chosen replacements stay on.
	for data: EquipmentData in STARTER_CLOTHING:
		if equipment_uids[data.slot_type] != 0:
			continue
		var owned: GearItem
		for item: GearItem in items.values():
			if item.equipment_definition == data:
				owned = item
				break
		if owned == null:
			owned = add_equipment(data)
		if owned != null:
			equip_equipment(owned.uid)


func equip_equipment(uid: int) -> bool:
	var slot: int = equipment_slot(uid)
	if slot < 0 or slot >= equipment_uids.size() or not items[uid].can_equip():
		return false
	if slot == EquipmentData.SlotType.WEAPON and items[uid].equipment_definition == null and not ResourceLoader.exists("res://data/weapons/%s.tres" % items[uid].definition_id):
		return false
	# A swap returns the old UID to the same ledger; no item is copied/deleted.
	if slot == EquipmentData.SlotType.WEAPON:
		equipped_weapon_uid = uid
		explicit_weapon_selection = true
	equipment_uids[slot] = uid
	changed.emit()
	return true


func unequip_equipment(slot: int) -> bool:
	if slot < 0 or slot >= equipment_uids.size():
		return false
	var uid: int = equipped_weapon_uid if slot == EquipmentData.SlotType.WEAPON else equipment_uids[slot]
	if uid == 0 or equipment_bag_uids().size() >= EQUIPMENT_BAG_CAPACITY:
		return false
	equipment_uids[slot] = 0
	if slot == EquipmentData.SlotType.WEAPON:
		equipped_weapon_uid = 0
		explicit_weapon_selection = true
	changed.emit()
	return true

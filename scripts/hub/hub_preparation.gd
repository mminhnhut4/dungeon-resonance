class_name HubPreparation
extends RefCounted
## Disposable run copies keep UID destinations but never share mutable GearItems.

static func starter_inventory(profile: SanctuaryProfile = null) -> GearInventory:
	var inventory := GearInventory.new()
	var moveset_unlocked: bool = profile != null and profile.bounty_claimed and profile.unlocked_weapons.has(WorldProgressionCatalog.BOUNTY_REWARD)
	var definition: EquipmentData = preload("res://data/equipment/ancient_sword_bounty.tres") if moveset_unlocked else GearInventory.COMMON_SWORD
	# The learned combo belongs to the profile. This fresh plain starter UID
	# never restores a dead sword's quality, enhancement, sockets or affixes.
	var sword: GearItem = inventory.add_equipment(definition)
	inventory.equip_equipment(sword.uid)
	inventory.catalyst_uid = inventory.add_item(&"catalyst", &"starter_catalyst").uid
	inventory.install_starter_clothing()
	return inventory


static func clone_inventory(source: GearInventory) -> GearInventory:
	var copy := GearInventory.new()
	copy.items.clear()
	for original: GearItem in source.items.values():
		var item := GearItem.new()
		item.uid = original.uid
		item.kind = original.kind
		item.definition_id = original.definition_id
		item.quality = original.quality
		item.equipment_definition = original.equipment_definition
		original.copy_loot_state_to(item)
		copy.items[item.uid] = item
	copy.bag.assign(source.bag)
	copy.slots.assign(source.slots)
	copy.slot_uids.assign(source.slot_uids)
	copy.equipment_uids.assign(source.equipment_uids)
	copy.equipment_positions.assign(source.equipment_positions)
	copy.owned_weapons.assign(source.owned_weapons)
	copy.materials.assign(source.materials)
	copy.consumables.assign(source.consumables)
	copy.equipped_weapon_uid = source.equipped_weapon_uid
	copy.catalyst_uid = source.catalyst_uid
	copy.catalyst_capacity = source.catalyst_capacity
	copy.weapon_capacity = source.weapon_capacity
	copy.permanent_rune_capacity = source.permanent_rune_capacity
	copy.run_coins = source.run_coins
	copy.explicit_weapon_selection = true
	return copy


static func reset_starter_equipment(inventory: GearInventory) -> void:
	# Used only to dress an existing safe inventory. Defeat creates a fresh kit.
	for item: GearItem in inventory.items.values():
		if item.equipment_definition == GearInventory.COMMON_SWORD and item.quality == GearItem.Quality.COMMON:
			inventory.equip_equipment(item.uid)
			break
	for definition: EquipmentData in GearInventory.STARTER_CLOTHING:
		for item: GearItem in inventory.items.values():
			if item.equipment_definition == definition:
				inventory.equip_equipment(item.uid)
				break
	for slot: int in inventory.slots.size():
		inventory.equip(slot, &"")


static func clear_carried(inventory: GearInventory) -> void:
	# Ownership moves to the disposable run. Profile stash is a separate ledger.
	inventory.items.clear()
	inventory.owned_weapons.clear()
	inventory.equipment_positions.clear()
	inventory.equipment_uids.fill(0)
	inventory.equipped_weapon_uid = 0
	inventory.catalyst_uid = 0
	inventory.slots.fill(&"")
	inventory.slot_uids.fill(0)
	for id: StringName in inventory.bag:
		inventory.bag[id] = 0
	for id: StringName in inventory.materials:
		inventory.materials[id] = 0
	for id: StringName in inventory.consumables:
		inventory.consumables[id] = 0
	inventory.explicit_weapon_selection = true
	inventory.catalyst_capacity = 3
	inventory.weapon_capacity = 1
	inventory.run_coins = 0
	inventory.changed.emit()

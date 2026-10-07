extends "res://tests/survival_test_base.gd"
## Seven-slot starter ledger, real GUI swaps, independent stats and reset lifetime.

func _initialize() -> void:
	suite = "modular_equipment"
	use_neutral_equipment = false
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	var gear: GearSession = level.gear
	var inventory: GearInventory = gear.inventory
	var screen: InventoryScreen = gear.modal as InventoryScreen
	var socket: Transform2D = player.equipped_weapon.get_parent().transform
	var hurt_shape: Shape2D = player.hurtbox.get_node("CollisionShape2D").shape
	_check(EquipmentData.SLOT_COUNT == 7 and EquipmentData.SlotType.ARMOR == 1 and EquipmentData.SlotType.RING == 2 and EquipmentData.SlotType.AMULET == 3, "Seven slots preserve existing Resource ordinals")
	_check(inventory.equipment_uids.size() == 7 and screen.equipment_buttons.size() == 7, "Inventory and UI expose the same seven equipment destinations")
	_check(inventory.items.size() == 12 and inventory.equipment_bag_uids().size() == 1, "Six neutral starter items join the previous weapon/catalyst/rune ledger without filling the bag")
	var before: Array[int] = inventory.equipment_uids.duplicate()
	_check(before.all(func(uid: int) -> bool: return uid != 0 and inventory.items.has(uid)) and before.size() == _unique_count(before), "Every default equipment slot references one distinct owned UID")
	_check(before.all(func(uid: int) -> bool: return inventory.items[uid].quality == GearItem.Quality.COMMON), "All seven equipped starter items use Common rarity")
	var owned_count: int = inventory.items.size()
	for repeat: int in 4:
		inventory.install_starter_clothing()
	_check(inventory.items.size() == owned_count and inventory.equipment_uids == before, "Installing starter clothing repeatedly neither allocates duplicates nor changes equipped UIDs")
	_check(player.health.maximum_health == 115.0 and player.energy.maximum == 100.0 and player.equipped_weapon.damage_multiplier == 1.2 and player.hurtbox.damage_resolver.armor_rating == 11.0, "Confirmed starter gear grants 115HP, eleven armor and two flat sword damage")
	screen.open()
	await _step(5)
	_check(root.get_visible_rect().encloses(screen.panel.get_global_rect()) and screen.equipment_buttons.all(func(button: Button) -> bool: return screen.panel.get_global_rect().encloses(button.get_global_rect())), "All seven equipment cells fit inside the actual viewport")
	for slot: int in [EquipmentData.SlotType.ARMOR, EquipmentData.SlotType.PANTS, EquipmentData.SlotType.BOOTS, EquipmentData.SlotType.GLOVES, EquipmentData.SlotType.RING, EquipmentData.SlotType.AMULET]:
		var uid: int = inventory.equipment_uids[slot]
		var other_slots: Array[int] = inventory.equipment_uids.duplicate()
		await _click(screen.equipment_buttons[slot], MOUSE_BUTTON_RIGHT)
		other_slots[slot] = 0
		_check(inventory.equipment_uids == other_slots and inventory.equipment_bag_uids().has(uid), "Right click removes only %s and returns its same UID to the bag" % EquipmentData.SLOT_NAMES[slot])
		var bag_index: int = screen.bag_uids.find(uid)
		await _click(screen.bag_buttons[bag_index], MOUSE_BUTTON_LEFT)
		_check(inventory.equipment_uids[slot] == uid and inventory.items.size() == owned_count, "Bag click restores %s without copying or discarding the item" % EquipmentData.SLOT_NAMES[slot])
		_check(not inventory.dismantle(uid), "Equipped %s remains protected from salvage" % EquipmentData.SLOT_NAMES[slot])
	_check(player.equipped_weapon.get_parent().transform == socket and player.hurtbox.get_node("CollisionShape2D").shape == hurt_shape, "Changing all wardrobe/accessory slots preserves physical socket and Hurtbox")
	_test_additional_slot_stats(inventory)
	_test_full_bag_swap(inventory)
	screen.close()
	var previous_uids: Array[int] = inventory.equipment_uids.duplicate()
	gear.reset_inventory()
	await _step(3)
	_check(inventory.equipment_uids.size() == 7 and inventory.equipment_uids.all(func(uid: int) -> bool: return uid > 0 and inventory.items.has(uid)), "Run reset restores all seven starter slots in the rebuilt ledger")
	_check(previous_uids.all(func(uid: int) -> bool: return not inventory.items.has(uid)), "Run reset destroys prior owned UIDs instead of duplicating surviving items")
	_check(inventory.items.size() == 9 and inventory.total_shards() == 0 and inventory.equipment_bag_uids().size() == 1, "Reset contains only two weapons, catalyst and six new starter items; carried run items are gone")
	_check(is_equal_approx(Engine.time_scale, 1.0) and player.controls_enabled, "Equipment workflow restores controls and global time")


func _test_additional_slot_stats(inventory: GearInventory) -> void:
	var baseline: Array[int] = inventory.equipment_uids.duplicate()
	var source_speed: float = player.motor.run_speed
	var fixture_uids: Array[int] = []
	for slot: int in [EquipmentData.SlotType.PANTS, EquipmentData.SlotType.BOOTS, EquipmentData.SlotType.GLOVES]:
		var data := EquipmentData.new()
		data.id = StringName("fixture_modular_%d" % slot)
		data.set("slot_type", slot)
		data.bonus_hp = 5.0
		data.bonus_mana = 3.0
		data.bonus_speed = 0.02
		data.bonus_crit = 0.01
		var item: GearItem = inventory.add_equipment(data)
		fixture_uids.append(item.uid)
		inventory.equip_equipment(item.uid)
	_check(player.health.maximum_health == 125.0 and player.energy.maximum == 109.0, "Pants, boots and gloves replacements all participate in independent capacity modifiers")
	_check(is_equal_approx(player.motor.run_speed, source_speed * 1.06) and is_equal_approx(player.equipped_weapon.equipment_critical_bonus, 0.03), "All three added slots contribute speed and critical modifiers once")
	for repeat: int in 5:
		inventory.changed.emit()
	_check(is_equal_approx(player.motor.run_speed, source_speed * 1.06) and player.health.maximum_health == 125.0, "Repeated refresh does not stack modifiers from newly added slots")
	for slot: int in [EquipmentData.SlotType.PANTS, EquipmentData.SlotType.BOOTS, EquipmentData.SlotType.GLOVES]:
		inventory.equip_equipment(baseline[slot])
	_check(player.health.maximum_health == 115.0 and player.energy.maximum == 100.0 and is_equal_approx(player.motor.run_speed, source_speed) and player.equipped_weapon.equipment_critical_bonus == 0.0, "Swapping the original clothes back restores the confirmed starter modifiers")
	for uid: int in fixture_uids:
		inventory.dismantle(uid)


func _test_full_bag_swap(inventory: GearInventory) -> void:
	var boots: GearItem = inventory.add_equipment(GearInventory.STARTER_CLOTHING[2])
	var retained: int = inventory.equipment_uids[EquipmentData.SlotType.BOOTS]
	var filler: Array[int] = []
	while inventory.equipment_bag_uids().size() < GearInventory.EQUIPMENT_BAG_CAPACITY:
		filler.append(inventory.add_equipment(GearInventory.COMMON_SWORD).uid)
	var count: int = inventory.items.size()
	_check(not inventory.unequip_equipment(EquipmentData.SlotType.BOOTS) and inventory.equipment_uids[EquipmentData.SlotType.BOOTS] == retained, "A full bag prevents boot removal without clearing the equipped UID")
	_check(inventory.equip_equipment(boots.uid) and inventory.equipment_bag_uids().has(retained) and inventory.items.size() == count, "Boot swap into a full bag returns the previous boots without losing or duplicating items")
	inventory.equip_equipment(retained)
	for uid: int in filler:
		inventory.dismantle(uid)
	inventory.dismantle(boots.uid)
	_check(inventory.equipment_bag_uids().size() == 1, "Finite full-bag exercise returns the ledger to its previous wardrobe state")


func _unique_count(values: Array[int]) -> int:
	var unique: Dictionary[int, bool] = {}
	for value: int in values:
		unique[value] = true
	return unique.size()


func _click(button: Button, code: MouseButton) -> void:
	await _step(2)
	var position: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.position = position
	click.button_index = code
	click.pressed = true
	root.push_input(click, true)
	await _step(1)
	click.pressed = false
	root.push_input(click, true)
	await _step(2)

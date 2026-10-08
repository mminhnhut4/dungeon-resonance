extends "res://tests/survival_test_base.gd"
## Confirmed starter stats through real Hurtbox/Resolver and equipment changes.

func _initialize() -> void:
	suite = "armor"
	use_neutral_equipment = false
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	var inventory: GearInventory = level.gear.inventory
	var stats: EquipmentStats = level.gear.equipment_stats
	var resolver: DamageResolver = player.hurtbox.damage_resolver
	var original: Array[int] = inventory.equipment_uids.duplicate()
	_check(player.health.maximum_health == 115.0 and player.health.current_health == 115.0, "A fresh product loadout starts at full 115HP exactly once")
	_check(stats.armor_bonus == 11.0 and resolver.armor_rating == 11.0 and stats.attack_bonus == 2.0, "Starter top, pants and gloves total eleven armor and two flat attack")
	_check(GearInventory.STARTER_CLOTHING[0].bonus_hp == 10.0 and GearInventory.STARTER_CLOTHING[0].bonus_armor == 5.0 and GearInventory.STARTER_CLOTHING[1].bonus_hp == 5.0 and GearInventory.STARTER_CLOTHING[1].bonus_armor == 3.0, "Top and pants definitions contain only their confirmed bonuses")
	_check(GearInventory.STARTER_CLOTHING[3].bonus_armor == 3.0 and GearInventory.STARTER_CLOTHING[3].bonus_atk == 2.0 and GearInventory.STARTER_CLOTHING[2].bonus_hp == 0.0 and GearInventory.STARTER_CLOTHING[4].bonus_hp == 0.0 and GearInventory.STARTER_CLOTHING[5].bonus_hp == 0.0, "Gloves supply confirmed bonuses while boots and jewelry remain neutral")
	_check(is_equal_approx(player.equipped_weapon.damage_multiplier, 1.2) and Player.SWORD.base_damage == 10.0, "Two flat attack makes the ten-base sword deal twelve without mutating its Resource")
	var event: DamageEvent = _damage(player.hurtbox, 15.0)
	var result: DamageResult = player.hurtbox.take_damage(event)
	_check(is_equal_approx(result.actual_damage, 15.0 * 100.0 / 111.0) and is_equal_approx(player.health.current_health, 115.0 - result.actual_damage), "Actual fifteen-damage Hurtbox contact is reduced once by 100/(100+11)")
	_check(event.base_damage == 15.0 and event.source_kind == DamageEvent.SourceKind.DIRECT and event.attack_direction == Vector2.RIGHT, "Armor leaves the caller-owned DamageEvent unchanged")
	var hp: float = player.health.current_health
	result = resolver.resolve(event)
	_check(result.blocked and result.block_reason == &"duplicate" and player.health.current_health == hp, "Duplicate resolver delivery cannot apply armor or damage a second time")
	var blocked: DamageResult = player.hurtbox.take_damage(_damage(player.hurtbox, 15.0))
	_check(blocked.blocked and player.health.current_health == hp, "Existing grace immunity still blocks a second contact after armored damage")
	for kind: int in [DamageEvent.SourceKind.DIRECT, DamageEvent.SourceKind.RESONANCE, DamageEvent.SourceKind.DOT, DamageEvent.SourceKind.ENVIRONMENT]:
		player.health.reset_health()
		var request: DamageEvent = _damage(player.hurtbox, 10.0)
		request.set("source_kind", kind)
		var received: DamageResult = player.hurtbox.take_internal_damage(request)
		_check(is_equal_approx(received.actual_damage, 10.0 * 100.0 / 111.0) and request.base_damage == 10.0, "Source kind %d passes through the same single armor stage without modifying its event" % kind)
	player.health.reset_health()
	var status: ElementStatusController = resolver.status_controller as ElementStatusController
	status.armor_break_remaining = 1.0
	event = _damage(player.hurtbox, 20.0)
	event.physical_damage = true
	result = player.hurtbox.take_internal_damage(event)
	_check(is_equal_approx(result.actual_damage, 20.0 * 1.25 * 100.0 / 111.0) and event.base_damage == 20.0, "Existing armor-break vulnerability is resolved before the one equipment armor stage")
	status.clear()
	for amount: float in [0.0, -10.0, NAN]:
		resolver.armor_rating = amount
		player.health.reset_health()
		result = resolver.resolve(_damage(player.hurtbox, 10.0))
		_check(result.actual_damage == 10.0, "Zero, negative or non-finite armor cannot amplify or invalidate incoming damage")
	resolver.armor_rating = 11.0
	player.health.reset_health()
	player.health.apply_damage(25.0)
	hp = player.health.current_health
	_check(inventory.unequip_equipment(EquipmentData.SlotType.PANTS) and player.health.maximum_health == 110.0 and resolver.armor_rating == 8.0 and player.health.current_health == hp, "Removing pants subtracts its five HP and three armor without healing")
	_check(inventory.unequip_equipment(EquipmentData.SlotType.ARMOR) and player.health.maximum_health == 100.0 and resolver.armor_rating == 3.0 and player.health.current_health == hp, "Removing the top leaves only glove armor and keeps current damage")
	_check(inventory.unequip_equipment(EquipmentData.SlotType.GLOVES) and resolver.armor_rating == 0.0 and player.equipped_weapon.damage_multiplier == 1.0, "Removing gloves removes their armor and attack bonus immediately")
	for slot: int in [EquipmentData.SlotType.ARMOR, EquipmentData.SlotType.PANTS, EquipmentData.SlotType.GLOVES]:
		inventory.equip_equipment(original[slot])
	_check(player.health.maximum_health == 115.0 and player.health.current_health == hp and resolver.armor_rating == 11.0 and player.equipped_weapon.damage_multiplier == 1.2, "Re-equipping the full set restores capacity and defense without free healing")
	for refresh: int in 12:
		inventory.changed.emit()
	_check(player.health.maximum_health == 115.0 and player.health.current_health == hp and resolver.armor_rating == 11.0 and stats.attack_bonus == 2.0, "Repeated gear refresh cannot stack HP, armor or flat attack")
	var screen: InventoryScreen = level.gear.modal as InventoryScreen
	screen.open()
	screen._show_tooltip(original[EquipmentData.SlotType.GLOVES])
	_check("Giáp: +3" in screen.tooltip_body.text and "Sát thương trang bị: +2" in screen.tooltip_body.text, "Glove tooltip displays both confirmed defense and equipment attack bonuses")
	screen.close()
	inventory.unequip_equipment(EquipmentData.SlotType.WEAPON)
	player.equipped_weapon.start_combo()
	_check(player.equipped_weapon.snapshot.base_damage == 7.0 and GearSession.UNARMED.base_damage == 5.0, "Equipped gloves add two flat damage to the five-base unarmed punch")
	player.equipped_weapon.cancel_combo()
	inventory.equip_equipment(original[EquipmentData.SlotType.WEAPON])
	player.health.maximum_health -= 10.0
	stats.refresh()
	_check(player.health.maximum_health == 105.0 and resolver.armor_rating == 11.0, "External run blood-price penalty remains after a gear refresh")
	stats.reset_base_stats()
	_check(player.health.maximum_health == 115.0 and player.health.current_health == hp and resolver.armor_rating == 11.0, "Explicit run base reset removes run penalties without healing or duplicating defense")
	player.health.current_health = 1.0
	var lethal: DamageResult = player.hurtbox.take_internal_damage(_damage(player.hurtbox, 100.0))
	_check(lethal.actual_damage == 1.0 and lethal.killed and player.health.current_health == 0.0, "Armor preserves lethal damage clamping and the actual death pipeline")
	inventory.equip_equipment(original[EquipmentData.SlotType.ARMOR])
	_check(player.health.current_health == 0.0 and player.action_state_machine.get_state_id() == &"dead", "Equipment cannot revive a dead player")
	level.gear.reset_inventory()
	player.reset_movement_at(Vector2(780, 640))
	_check(player.health.current_health == 115.0 and player.health.maximum_health == 115.0 and resolver.armor_rating == 11.0, "An explicit new-run reset restores the full confirmed starter HP and armor")

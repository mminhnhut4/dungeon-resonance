extends "res://tests/survival_test_base.gd"
## Frozen per-UID loot potential through real gear swaps and stat consumers.


func _initialize() -> void:
	suite = "loot_affix"
	use_neutral_equipment = false
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	_test_roll_policy()
	_test_invalid_and_caps()
	await _test_equipment_and_frozen_swaps()
	_test_broken_and_forging()
	_test_clone_boundary()


func _item(quality: int = GearItem.Quality.COMMON) -> GearItem:
	var item := GearItem.new()
	item.uid = CombatIds.next_id()
	item.kind = &"weapon"
	item.definition_id = GearInventory.COMMON_SWORD.id
	item.equipment_definition = GearInventory.COMMON_SWORD
	item.quality = quality
	return item


func _state(item: GearItem) -> Array:
	return [item.uid, item.kind, item.definition_id, item.quality, item.source, item.drop_bonus, item.affix_id, item.affix_value, item.broken, item.loot_rolled]


func _test_roll_policy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 142857
	var first: GearItem = _item()
	_check(LootAffixRoller.roll_once(first, rng), "A valid owned UID rolls its drop properties exactly once")
	var saved: Array = _state(first)
	var rng_state: int = rng.state
	_check(not LootAffixRoller.roll_once(first, rng, &"salvage", true) and _state(first) == saved and rng.state == rng_state, "Repeated roll cannot change source, bonus, affix, damage condition or RNG")
	var repeat_rng := RandomNumberGenerator.new()
	repeat_rng.seed = 142857
	var repeat: GearItem = _item()
	LootAffixRoller.roll_once(repeat, repeat_rng)
	_check(first.drop_bonus == repeat.drop_bonus and first.affix_id == repeat.affix_id and first.affix_value == repeat.affix_value, "The same seed is reproducible without deriving a new roll from hover or UID")
	var ranges_valid: bool = true
	var affixes_valid: bool = true
	for quality: int in range(GearItem.Quality.COMMON, GearItem.Quality.DIVINE + 1):
		var merchant: GearItem = _item(quality)
		LootAffixRoller.roll_once(merchant, rng, &"merchant")
		for sample: int in 48:
			var dropped: GearItem = _item(quality)
			LootAffixRoller.roll_once(dropped, rng)
			var relative: float = dropped.damage_factor() / merchant.damage_factor() - 1.0
			ranges_valid = ranges_valid and relative >= 0.03 - 0.000001 and relative <= 0.08 + 0.000001
			affixes_valid = affixes_valid and LootAffixCatalog.IDS.has(dropped.affix_id) and dropped.affix_value >= LootAffixCatalog.BOUNDS[dropped.affix_id].x and dropped.affix_value <= LootAffixCatalog.BOUNDS[dropped.affix_id].y
		_check(merchant.drop_bonus == 0.0 and merchant.affix_id.is_empty() and not merchant.broken, "Merchant rarity %d remains a neutral same-tier comparison" % quality)
	_check(ranges_valid, "288 seeded weapons keep raw damage exactly 3–8% above the same-tier merchant baseline")
	_check(affixes_valid and LootAffixCatalog.IDS.size() == 5, "Each sampled item has one bounded scalar line and no attack/proc affix")
	var plain: GearItem = _item()
	LootAffixRoller.roll_once(plain, rng, &"drop", false, 0.0)
	_check(plain.affix_id.is_empty() and plain.affix_value == 0.0 and plain.can_equip(), "A no-affix monster drop is immediately usable while keeping its small weapon bonus")
	var clothing: GearItem = _item()
	clothing.kind = &"boots"
	clothing.equipment_definition = GearInventory.STARTER_CLOTHING[2]
	clothing.definition_id = clothing.equipment_definition.id
	LootAffixRoller.roll_once(clothing, rng)
	_check(clothing.drop_bonus == 0.0 and not clothing.affix_id.is_empty(), "Non-weapons receive only the single minor scalar affix, never a damage factor")


func _test_invalid_and_caps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var bad: GearItem = _item()
	var original: Array = _state(bad)
	var rng_state: int = rng.state
	_check(not LootAffixRoller.roll_once(bad, rng, &"unknown") and _state(bad) == original and rng.state == rng_state, "Invalid source leaves the UID and random stream untouched")
	for chance: float in [-1.0, 2.0, NAN]:
		_check(not LootAffixRoller.roll_once(bad, rng, &"drop", false, chance) and not bad.loot_rolled, "Invalid affix probability cannot partially initialize an item")
	bad.uid = 0
	_check(not LootAffixRoller.roll_once(bad, rng), "An unowned UID cannot become a rolled item")
	bad.uid = CombatIds.next_id()
	bad.kind = &"rune"
	_check(not LootAffixRoller.roll_once(bad, rng), "Rune/catalyst proc definitions cannot enter the equipment-affix pipeline")
	bad.kind = &"weapon"
	bad.quality = -1
	_check(not LootAffixRoller.roll_once(bad, rng), "Invalid quality is rejected rather than clamped into a usable drop")
	bad.quality = GearItem.Quality.COMMON
	for amount: float in [NAN, -2.0, INF]:
		bad.drop_bonus = amount
		_check(bad.damage_factor() == 1.0, "Non-finite or negative drop bonus preserves the neutral factor")
	bad.drop_bonus = 5.0
	_check(is_equal_approx(bad.damage_factor(), 1.08), "Malformed oversized damage bonus is capped at eight percent")
	bad.affix_id = &"vitality"
	bad.affix_value = 999.0
	_check(bad.affix_bonus(&"vitality") == 6.0 and bad.affix_bonus(&"ward") == 0.0, "An affix cannot exceed its data cap or simultaneously supply another stat")
	bad.affix_value = NAN
	_check(bad.affix_bonus(&"vitality") == 0.0, "Malformed non-finite affix supplies no runtime power")
	bad.affix_id = &"extra_attack"
	bad.affix_value = 1.0
	_check(bad.affix_bonus(&"extra_attack") == 0.0, "Unknown recursive/damage affix IDs have no fallback behavior")


func _test_equipment_and_frozen_swaps() -> void:
	var inventory: GearInventory = level.gear.inventory
	var stats: EquipmentStats = level.gear.equipment_stats
	var ring_uid: int = inventory.equipment_uids[EquipmentData.SlotType.RING]
	var sword_uid: int = inventory.equipped_weapon_uid
	var baseline_hp: float = player.health.maximum_health
	var baseline_mana: float = player.energy.maximum
	var baseline_speed: float = player.motor.run_speed
	var baseline_armor: float = player.hurtbox.damage_resolver.armor_rating
	var baseline_crit: float = player.equipped_weapon.equipment_critical_bonus
	player.health.apply_damage(20.0)
	player.energy.current = 60.0
	var current_hp: float = player.health.current_health
	var ring: GearItem = inventory.add_equipment(GearInventory.STARTER_CLOTHING[4])
	ring.source = &"drop"
	ring.loot_rolled = true
	for id: StringName in LootAffixCatalog.IDS:
		ring.affix_id = id
		ring.affix_value = LootAffixCatalog.BOUNDS[id].y
		inventory.equip_equipment(ring.uid)
		_check(is_equal_approx(player.health.maximum_health, baseline_hp + (6.0 if id == &"vitality" else 0.0)) and is_equal_approx(player.energy.maximum, baseline_mana + (6.0 if id == &"focus" else 0.0)) and is_equal_approx(player.motor.run_speed, baseline_speed * (1.025 if id == &"stride" else 1.0)) and is_equal_approx(player.hurtbox.damage_resolver.armor_rating, baseline_armor + (2.0 if id == &"ward" else 0.0)) and is_equal_approx(player.equipped_weapon.equipment_critical_bonus, baseline_crit + (0.015 if id == &"precision" else 0.0)), "Equipping %s changes only its own capped runtime scalar" % id)
		_check(player.health.current_health == current_hp and player.energy.current == 60.0 and stats.attack_bonus == 2.0, "Affix %s never heals, refills energy or supplies extra damage" % id)
	for refresh: int in 12:
		inventory.changed.emit()
	_check(is_equal_approx(player.equipped_weapon.equipment_critical_bonus, 0.015) and player.health.maximum_health == baseline_hp, "Repeated refresh cannot stack the single affix")
	inventory.equip_equipment(ring_uid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 981
	var dropped: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD, GearItem.Quality.RARE)
	LootAffixRoller.roll_once(dropped, rng, &"drop", false, 0.0)
	inventory.equip_equipment(dropped.uid)
	var expected: float = 1.1 * (1.0 + dropped.drop_bonus) + 0.2
	_check(is_equal_approx(player.equipped_weapon.damage_multiplier, expected), "GearSession consumes the same-tier drop factor once alongside existing flat attack")
	player.equipped_weapon.start_combo()
	_check(is_equal_approx(player.equipped_weapon.snapshot.base_damage, 10.0 * expected), "A real committed melee snapshot receives the frozen weapon bonus")
	player.equipped_weapon.cancel_combo()
	var frozen: Array = _state(dropped)
	var screen: InventoryScreen = level.gear.modal as InventoryScreen
	screen.open()
	for swap: int in 8:
		screen._show_tooltip(dropped.uid)
		inventory.equip_equipment(sword_uid)
		inventory.equip_equipment(dropped.uid)
	screen.close()
	_check(_state(dropped) == frozen and is_equal_approx(player.equipped_weapon.damage_multiplier, expected), "Hover, modal, swapping and stat refresh cannot reroll an owned UID")
	_check(GearInventory.COMMON_SWORD.moveset.base_damage == 10.0 and GearInventory.COMMON_SWORD.bonus_crit == 0.0 and GearInventory.STARTER_CLOTHING[4].bonus_hp == 0.0, "Loot potential never mutates cached movesets, equipment or starter definitions")
	inventory.equip_equipment(sword_uid)


func _test_broken_and_forging() -> void:
	var inventory: GearInventory = level.gear.inventory
	var rng := RandomNumberGenerator.new()
	rng.seed = 118
	var broken_item: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD, GearItem.Quality.RARE)
	LootAffixRoller.roll_once(broken_item, rng, &"salvage", true)
	var previous: int = inventory.equipped_weapon_uid
	_check(not broken_item.can_equip() and not inventory.equip_equipment(broken_item.uid) and inventory.equipped_weapon_uid == previous, "A broken salvage item cannot replace the equipped weapon")
	var frozen: Array = _state(broken_item)
	_check(broken_item.repair() and broken_item.can_equip() and inventory.equip_equipment(broken_item.uid), "Repair restores use of the same Rare salvage UID")
	frozen[8] = false
	_check(_state(broken_item) == frozen and not broken_item.repair(), "Repair changes only the broken flag and cannot reroll or repeatedly repair")
	inventory.equip_equipment(previous)
	for quality: int in [GearItem.Quality.VERY_RARE, GearItem.Quality.EPIC, GearItem.Quality.LEGENDARY, GearItem.Quality.DIVINE]:
		var blank: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD, quality)
		LootAffixRoller.roll_once(blank, rng, &"drop", true)
		var blank_state: Array = _state(blank)
		_check(blank.is_forging_blank() and not blank.can_equip() and not blank.repair() and not inventory.equip_equipment(blank.uid) and _state(blank) == blank_state, "Drop rarity %d keeps its potential but cannot bypass smith crafting through repair" % quality)
	var legacy: GearItem = _item(GearItem.Quality.LEGENDARY)
	_check(legacy.can_equip() and not legacy.is_forging_blank(), "Existing authored/debug Legendary gear remains usable without a drop source")


func _test_clone_boundary() -> void:
	var source: GearInventory = level.gear.inventory
	var copy: GearInventory = HubPreparation.clone_inventory(source)
	var states_match: bool = true
	var objects_distinct: bool = true
	for uid: int in source.items:
		states_match = states_match and _state(copy.items[uid]) == _state(source.items[uid])
		objects_distinct = objects_distinct and copy.items[uid] != source.items[uid] and copy.items[uid].equipment_definition == source.items[uid].equipment_definition
	_check(states_match and objects_distinct, "Hub preparation copies all frozen per-UID fields into distinct runtime objects with shared immutable definitions")
	var uid: int = source.equipped_weapon_uid
	copy.items[uid].affix_value = 999.0
	copy.items[uid].broken = true
	copy.materials[&"metal"] = 9
	_check(not source.items[uid].broken and source.items[uid].affix_value != 999.0 and source.materials[&"metal"] != 9, "Disposable run changes cannot mutate the home UID or material ledger")

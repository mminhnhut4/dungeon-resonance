extends RefCounted
## Historical tests isolate their original stats with local neutral definitions.
## Production Resources, owned UIDs and equipped visual parts remain unchanged.

static func install(gear: GearSession) -> void:
	if not gear.has_meta(&"neutral_equipment_fixture"):
		gear.set_meta(&"neutral_equipment_fixture", true)
		gear.inventory.changed.connect(_apply.bind(weakref(gear)))
	_apply(weakref(gear))
	gear.player.health.reset_health()


static func _apply(owner_ref: WeakRef) -> void:
	var gear: GearSession = owner_ref.get_ref() as GearSession
	if not is_instance_valid(gear):
		return
	for item: GearItem in gear.inventory.items.values():
		var definition: EquipmentData = item.equipment_definition
		if definition == null or not GearInventory.STARTER_CLOTHING.has(definition):
			continue
		var neutral: EquipmentData = definition.duplicate(false) as EquipmentData
		neutral.bonus_hp = 0.0
		neutral.bonus_armor = 0.0
		neutral.bonus_atk = 0.0
		neutral.bonus_mana = 0.0
		neutral.bonus_speed = 0.0
		neutral.bonus_crit = 0.0
		item.equipment_definition = neutral
	gear.equipment_stats.refresh()
	gear.sync_quality()

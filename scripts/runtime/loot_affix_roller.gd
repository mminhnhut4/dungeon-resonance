class_name LootAffixRoller
extends RefCounted
## Pure per-UID initialization. A collector, tooltip or swap cannot reroll it.
## Callers own drop chances, definitions, rarity and the seeded RNG.

const SOURCES: Array[StringName] = [&"merchant", &"drop", &"salvage", &"crafted"]
const DROP_BONUS_MIN: float = 0.03
const DROP_BONUS_MAX: float = 0.08


static func roll_once(item: GearItem, rng: RandomNumberGenerator, source: StringName = &"drop", broken: bool = false, affix_chance: float = 1.0) -> bool:
	if item == null or rng == null or item.loot_rolled or item.uid <= 0 or item.definition_id.is_empty() or item.kind not in EquipmentData.SLOT_KINDS or source not in SOURCES or item.quality < GearItem.Quality.COMMON or item.quality > GearItem.Quality.DIVINE or not is_finite(affix_chance) or affix_chance < 0.0 or affix_chance > 1.0:
		return false
	item.source = source
	item.broken = broken
	item.drop_bonus = rng.randf_range(DROP_BONUS_MIN, DROP_BONUS_MAX) if source == &"drop" and item.kind == &"weapon" else 0.0
	item.affix_id = &""
	item.affix_value = 0.0
	# Merchant items are the fixed comparison baseline. The caller chooses
	# whether a drop receives one line; there is no quality/proc multiplier.
	if source != &"merchant" and affix_chance > 0.0 and rng.randf() < affix_chance:
		item.affix_id = LootAffixCatalog.IDS[rng.randi_range(0, LootAffixCatalog.IDS.size() - 1)]
		var bounds: Vector2 = LootAffixCatalog.BOUNDS[item.affix_id]
		item.affix_value = rng.randf_range(bounds.x, bounds.y)
	item.loot_rolled = true
	return true

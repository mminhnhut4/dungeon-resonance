class_name GearItem
extends RefCounted
## Unique owned item. Quality changes runtime factors, never cached definitions.

enum Quality { COMMON, RARE, VERY_RARE, EPIC, LEGENDARY, DIVINE }
const NAMES: Array[String] = ["Thường", "Hiếm", "Cực hiếm", "Sử thi", "Huyền thoại", "Thần thánh"]
const COLORS: Array[Color] = [Color("d4d8dc"), Color("67c88a"), Color("67a7ef"), Color("ba82e8"), Color("f0bf63"), Color("f4e9bf")]
var uid: int = 0
var kind: StringName = &"weapon"
var definition_id: StringName = &""
var quality: int = Quality.COMMON
var equipment_definition: EquipmentData
## Rolled once on this UID, never written into its cached EquipmentData.
var source: StringName = &""
var drop_bonus: float = 0.0
var affix_id: StringName = &""
var affix_value: float = 0.0
var broken: bool = false
var loot_rolled: bool = false
var enhancement_level: int = 0


func damage_factor() -> float:
	# Reuse prototype factors. Divine power/recipes are not balanced in this slice.
	var quality_factor: float = [1.0, 1.1, 1.2, 1.2, 1.35, 1.35][clampi(quality, 0, 5)]
	var bonus: float = clampf(drop_bonus, 0.0, 0.08) if kind == &"weapon" and is_finite(drop_bonus) else 0.0
	# Enhancement is additive against base damage, never compounded by quality.
	return quality_factor + quality_factor * bonus + 0.03 * clampi(enhancement_level, 0, 12)


func is_forging_blank() -> bool:
	# Very Rare+ loot preserves its potential rarity but requires the smith.
	# Existing authored/debug/crafted items with no drop source remain unchanged.
	return source == &"drop" and quality >= Quality.VERY_RARE


func can_equip() -> bool:
	return not broken and not is_forging_blank()


func repair() -> bool:
	if not broken or is_forging_blank():
		return false
	broken = false
	return true


func affix_bonus(id: StringName) -> float:
	return LootAffixCatalog.bounded_value(affix_id, affix_value) if can_equip() and affix_id == id else 0.0


func copy_loot_state_to(item: GearItem) -> void:
	item.source = source
	item.drop_bonus = drop_bonus
	item.affix_id = affix_id
	item.affix_value = affix_value
	item.broken = broken
	item.loot_rolled = loot_rolled
	item.enhancement_level = enhancement_level


func bonus_slots() -> int:
	return [0, 1, 1, 1, 2, 2][clampi(quality, 0, 5)]


func proc_chance() -> float:
	return [0.0, 0.12, 0.22, 0.22, 0.35, 0.35][clampi(quality, 0, 5)]

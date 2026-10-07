class_name ForgeRecipe
extends Resource
## Immutable smith input; owned quality/source/affixes remain in GearItem.
@export var id: StringName
@export var blueprint_id: StringName
@export var display_name: String
@export var equipment: EquipmentData
@export_range(2, 5, 1) var quality: int = GearItem.Quality.VERY_RARE
@export var coin_cost: int = 20
@export var material_ids: Array[StringName] = []
@export var material_counts: Array[int] = []
@export_range(0.0, 1.0) var success_chance: float = 1.0

func costs() -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for index: int in material_ids.size():
		if index < material_counts.size(): result[material_ids[index]] = material_counts[index]
	return result

func required_blueprint() -> StringName:
	return blueprint_id if blueprint_id != &"" else equipment.id if equipment != null else &""

func valid() -> bool:
	if not WorldProgressionCatalog.valid_id(id) or equipment == null or equipment.moveset == null or equipment.slot_type != EquipmentData.SlotType.WEAPON or quality < GearItem.Quality.VERY_RARE or quality > GearItem.Quality.DIVINE or not MaterialCatalog.valid_count(coin_cost) or material_ids.is_empty() or material_ids.size() != material_counts.size() or not is_finite(success_chance) or success_chance <= 0.0 or success_chance > 1.0:
		return false
	var seen: Array[StringName] = []
	for index: int in material_ids.size():
		if material_ids[index] not in MaterialCatalog.IDS or material_ids[index] in seen or not MaterialCatalog.valid_count(material_counts[index]) or material_counts[index] == 0: return false
		seen.append(material_ids[index])
	if quality >= GearItem.Quality.LEGENDARY and not seen.has(&"origin_divine_stone"): return false
	return quality != GearItem.Quality.DIVINE or is_equal_approx(success_chance, 0.5)

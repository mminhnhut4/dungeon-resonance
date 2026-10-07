class_name WeaponVariantCatalog
extends RefCounted
## Ten authored families, sixty explicit initial-grade entries, shared models.
const IDS: Array[StringName] = [&"world_saber", &"world_greatsword", &"world_twinblades", &"world_spear", &"world_halberd", &"world_axe", &"world_mace", &"world_chain", &"world_fan", &"world_staff"]
const QUALITY_KEYS: Array[String] = ["common", "rare", "very_rare", "epic", "legendary", "divine"]

static func equipment_for(id: StringName) -> EquipmentData:
	if not IDS.has(id): return null
	return load("res://data/equipment/%s.tres" % id) as EquipmentData

static func variant_for(id: StringName, quality: int) -> GearVariantData:
	if not IDS.has(id) or quality < 0 or quality > 5: return null
	return load("res://data/gear_variants/%s_%s.tres" % [id, QUALITY_KEYS[quality]]) as GearVariantData

static func all_variants() -> Array[GearVariantData]:
	var result: Array[GearVariantData] = []
	for id: StringName in IDS:
		for grade: int in 6:
			result.append(variant_for(id, grade))
	return result


class_name DropTableResource
extends Resource
## One blueprint gate for the whole pool, then pick an unknown recipe first.
@export_range(0.0, 1.0) var blueprint_chance_total: float = 0.005
@export var blueprint_ids: Array[StringName] = []
@export_range(0.0, 1.0) var stone_chance: float = 0.12
@export_range(0.0, 1.0) var none_chance: float = 0.35
@export var regular_souls: int = 1
@export var elite_souls: int = 3
@export var boss_souls: int = 25
@export var material_pools: Dictionary = {
	&"slime": [&"slime_essence", &"healing_herb", &"detox_root"],
	&"runic_slime": [&"slime_essence", &"healing_herb", &"detox_root"],
	&"ancient_guard": [&"metal", &"armor_scrap", &"linen_fiber"],
	&"bloodwing_bat": [&"detox_root", &"healing_herb", &"dust"],
	&"sword_wraith": [&"dust", &"crystal", &"linen_fiber"],
	&"runic_champion": [&"armor_scrap", &"dust", &"crystal", &"metal"],
	&"golem": [&"metal", &"dust", &"crystal", &"armor_scrap"],
}

func material_pool(enemy_type: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var raw: Variant = material_pools.get(enemy_type, material_pools.get(&"slime", []))
	if not raw is Array: return result
	for id: Variant in raw:
		var typed: StringName = StringName(str(id))
		if typed in MaterialCatalog.IDS and typed != &"origin_divine_stone" and not result.has(typed): result.append(typed)
	return result

func choose_blueprint(roll: float, rng: RandomNumberGenerator, known: Array[StringName], eligible: bool) -> StringName:
	if not eligible or rng == null or not is_finite(roll) or roll < 0.0 or roll >= 1.0 or not is_finite(blueprint_chance_total) or blueprint_chance_total < 0.0 or blueprint_chance_total > 1.0 or roll >= blueprint_chance_total: return &""
	var pool: Array[StringName] = []
	var unknown: Array[StringName] = []
	for id: StringName in blueprint_ids:
		if not WorldProgressionCatalog.valid_id(id) or pool.has(id): continue
		pool.append(id)
		if not known.has(id): unknown.append(id)
	if not unknown.is_empty(): pool = unknown
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else &""

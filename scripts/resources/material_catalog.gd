class_name MaterialCatalog
extends RefCounted
## Prototype material economy. These values are data, not final balance.

const IDS: Array[StringName] = [&"metal", &"dust", &"crystal", &"slime_essence", &"enhancement_stone_1", &"enhancement_stone_2", &"enhancement_stone_3", &"enhancement_stone_4", &"enhancement_stone_5", &"enhancement_stone_6", &"origin_divine_stone", &"armor_scrap", &"healing_herb", &"linen_fiber", &"detox_root", &"aptitude_herb", &"aptitude_pill"]
const MAX_COUNT: int = 999999
const CRYSTAL_SELL_PRICE: int = 5
const CRYSTALS_PER_ENEMY: int = 1
const DISPLAY_NAMES: Dictionary = {&"metal": "Mảnh Kim Loại Cổ", &"dust": "Bột Tinh Thể Phép", &"crystal": "Tinh Thạch", &"slime_essence": "Tinh Chất Slime", &"enhancement_stone_1": "Đá Cường Hóa cấp 1", &"enhancement_stone_2": "Đá Cường Hóa cấp 2", &"enhancement_stone_3": "Đá Cường Hóa cấp 3", &"enhancement_stone_4": "Đá Cường Hóa cấp 4", &"enhancement_stone_5": "Đá Cường Hóa cấp 5", &"enhancement_stone_6": "Đá Cường Hóa cấp 6", &"origin_divine_stone": "Bản Nguyên Thần Thạch", &"armor_scrap": "Giáp Phế Liệu", &"healing_herb": "Thảo Dược Hồi Sinh Lực", &"linen_fiber": "Sợi Vải Lanh", &"detox_root": "Rễ Thảo Dược Giải Độc", &"aptitude_herb": "Dược Thảo Dưỡng Căn", &"aptitude_pill": "Đan Dưỡng Căn"}
# Only approved prototype entries are sellable; adding a name never adds a price.
const SELL_PRICES: Dictionary = {&"crystal": CRYSTAL_SELL_PRICE, &"slime_essence": 3}
const ESSENCE_DROP_CHANCE: float = 0.15
const BROKEN_GEAR_DROP_CHANCE: float = 0.15


static func repair_cost(quality: int) -> Dictionary[StringName, int]:
	# Common/Rare restoration only; Very Rare+ drop blanks require forging.
	var tier: int = clampi(quality, GearItem.Quality.COMMON, GearItem.Quality.DIVINE)
	return {&"metal": 2 + tier * 2, &"dust": 1 + tier}


static func empty_counts() -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for id: StringName in IDS: result[id] = 0
	return result

static func material_policy(id: StringName) -> Dictionary:
	var known: bool = id in IDS
	var lineage: bool = id in [&"aptitude_herb",&"aptitude_pill"]
	return {"known":known,"lineage_bound":lineage,"ordinary_transfer":known and not lineage,"art_status":"missing_final" if lineage else "catalog_defined" if known else "unknown"}


static func valid_count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= 0.0 and float(value) <= MAX_COUNT

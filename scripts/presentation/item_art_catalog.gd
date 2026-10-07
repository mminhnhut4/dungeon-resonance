class_name ItemArtCatalog
extends RefCounted
## Existing IDs only; approved item art is shared by ground pickups and UI.

const IDS: Array[StringName] = [&"crystal", &"slime_essence", &"metal", &"dust", &"broken_sword", &"broken_dagger", &"broken_staff", &"broken_top", &"broken_gloves", &"potion", &"bandage", &"antidote"]
const NAMES: Array[String] = ["Tinh Thạch Vụn", "Tinh Chất Slime", "Mảnh Kim Loại Cổ", "Bột Tinh Thể Phép", "Kiếm Mẻ", "Dao Gãy", "Trượng Nứt", "Áo Vải Rách", "Găng Da Sờn", "Thuốc Hồi Máu", "Băng Gạc", "Thuốc Giải Độc"]
const ICONS: Array[Texture2D] = [
	preload("res://assets/ui/items/user_icons_v1/08_resonance_shard.png"),
	preload("res://assets/ui/items/regions/slime_essence.tres"),
	preload("res://assets/ui/items/user_icons_v1/04_iron_ore.png"),
	preload("res://assets/ui/items/regions/dust.tres"),
	preload("res://assets/ui/items/regions/broken_sword.tres"),
	preload("res://assets/ui/items/regions/broken_dagger.tres"),
	preload("res://assets/ui/items/regions/broken_staff.tres"),
	preload("res://assets/ui/items/regions/broken_top.tres"),
	preload("res://assets/ui/items/regions/broken_gloves.tres"),
	preload("res://assets/ui/items/user_icons_v1/03_medicine_flask.png"),
	preload("res://assets/ui/items/regions/bandage.tres"),
	preload("res://assets/ui/items/regions/antidote.tres"),
]
const RUNE_ICONS: Dictionary = {
	&"fire": preload("res://assets/ui/icons/icon_fire.png"),
	&"wind": preload("res://assets/ui/icons/icon_wind.png"),
	&"lightning": preload("res://assets/ui/icons/runes_v1/lightning.png"),
	&"ice": preload("res://assets/ui/icons/runes_v1/ice.png"),
	&"poison": preload("res://assets/ui/icons/runes_v1/poison.png"),
}
const FALLBACK: Texture2D = preload("res://assets/ui/icons/icon_shield.png")
const GEAR_ICON_OVERRIDES: Dictionary = {
	&"ancient_sword": preload("res://assets/ui/items/user_icons_v1/01_iron_jian.png"),
	&"ancient_sword_bounty": preload("res://assets/ui/items/user_icons_v1/01_iron_jian.png"),
}
# Existing six legacy archetypes reuse verified local whole-weapon artwork.
# These are UI/loot lookup aliases, never definition or runtime item mutations.
const LEGACY_WEAPON_ICONS: Dictionary = {
	&"blade_fan": preload("res://assets/sprites/weapons/regions/world_fan.tres"),
	&"blood_spiked_whip": preload("res://assets/sprites/weapons/regions/world_chain.tres"),
	&"demon_greatsword": preload("res://assets/sprites/weapons/regions/world_greatsword.tres"),
	&"gale_dual_daggers": preload("res://assets/sprites/weapons/regions/world_twinblades.tres"),
	&"ritual_staff": preload("res://assets/sprites/weapons/regions/world_staff.tres"),
	&"storm_arcane_staff": preload("res://assets/sprites/weapons/regions/world_staff.tres"),
}
const EXTRA_ICONS: Dictionary = {
	&"enhancement_stone_1": preload("res://assets/ui/items/regions/enhancement_stone_1.tres"),
	&"enhancement_stone_2": preload("res://assets/ui/items/regions/enhancement_stone_2.tres"),
	&"enhancement_stone_3": preload("res://assets/ui/items/regions/enhancement_stone_3.tres"),
	&"enhancement_stone_4": preload("res://assets/ui/items/regions/enhancement_stone_4.tres"),
	&"enhancement_stone_5": preload("res://assets/ui/items/regions/enhancement_stone_5.tres"),
	&"enhancement_stone_6": preload("res://assets/ui/items/regions/enhancement_stone_6.tres"),
	&"origin_divine_stone": preload("res://assets/ui/items/regions/origin_divine_stone.tres"),
	&"coins": preload("res://assets/ui/items/regions/coins.tres"),
	&"armor_scrap": preload("res://assets/ui/items/regions/armor_scrap.tres"),
	&"blueprint": preload("res://assets/ui/items/regions/blueprint.tres"),
	&"healing_herb": preload("res://assets/ui/items/user_icons_v1/05_moonleaf_herb.png"),
	&"linen_fiber": preload("res://assets/ui/items/regions/linen_fiber.tres"),
	&"detox_root": preload("res://assets/ui/items/regions/detox_root.tres"),
}

static func icon(id: StringName) -> Texture2D:
	if LEGACY_WEAPON_ICONS.has(id): return LEGACY_WEAPON_ICONS[id]
	if EXTRA_ICONS.has(id): return EXTRA_ICONS[id]
	var index: int = IDS.find(id)
	return ICONS[index] if index >= 0 else null

static func display_name(id: StringName) -> String:
	var original_index: int = IDS.find(id)
	if original_index >= 0: return NAMES[original_index]
	if MaterialCatalog.DISPLAY_NAMES.has(id): return MaterialCatalog.DISPLAY_NAMES[id]
	if id == &"coins": return "Linh Thạch"
	if id == &"blueprint": return "Bản Vẽ Rèn"
	var index: int = IDS.find(id)
	return NAMES[index] if index >= 0 else String(id)

static func broken_id(item: GearItem) -> StringName:
	if item.kind == &"armor": return &"broken_top"
	if item.kind == &"gloves": return &"broken_gloves"
	var moveset: WeaponDefinition = item.equipment_definition.moveset if item.equipment_definition != null else null
	if moveset == null and ResourceLoader.exists("res://data/weapons/%s.tres" % item.definition_id):
		moveset = load("res://data/weapons/%s.tres" % item.definition_id) as WeaponDefinition
	if moveset != null:
		if moveset.attack_kind != &"melee": return &"broken_staff"
		if String(moveset.id).contains("dagger"): return &"broken_dagger"
	return &"broken_sword"

static func gear_icon(item: GearItem) -> Texture2D:
	if item == null: return null
	if item.broken: return icon(broken_id(item))
	if item.kind == &"weapon" and item.equipment_definition == null and LEGACY_WEAPON_ICONS.has(item.definition_id):
		return LEGACY_WEAPON_ICONS[item.definition_id]
	if item.equipment_definition != null and GEAR_ICON_OVERRIDES.has(item.equipment_definition.id):
		return GEAR_ICON_OVERRIDES[item.equipment_definition.id]
	return item.equipment_definition.icon_texture if item.equipment_definition != null else FALLBACK

static func gear_name(item: GearItem) -> String:
	if item.broken: return display_name(broken_id(item))
	if item.equipment_definition != null: return item.equipment_definition.item_name
	var path: String = "res://data/weapons/%s.tres" % item.definition_id
	if item.kind == &"weapon" and ResourceLoader.exists(path):
		return (load(path) as WeaponDefinition).display_name
	return String(item.definition_id).replace("_", " ")

static func pickup_icon(pickup: LootPickup) -> Texture2D:
	if pickup.kind == &"blueprint": return icon(&"blueprint")
	if pickup.kind == &"soul": return preload("res://assets/presentation/spark.png")
	if pickup.runtime_item != null: return gear_icon(pickup.runtime_item)
	var direct: Texture2D = icon(&"potion" if pickup.kind == &"potion" else pickup.item_id)
	if direct != null: return direct
	return RUNE_ICONS.get(pickup.item_id, FALLBACK) as Texture2D

static func pickup_name(pickup: LootPickup) -> String:
	if pickup.kind == &"soul": return "Tàn Hồn"
	if pickup.kind == &"blueprint":
		var recipe: EquipmentData = WeaponVariantCatalog.equipment_for(pickup.item_id)
		return "Bản Vẽ · " + recipe.item_name if recipe != null else "Bản Vẽ Rèn"
	if pickup.runtime_item != null: return gear_name(pickup.runtime_item)
	if pickup.kind == &"rune" and pickup.inventory != null:
		var rune: RuneData = pickup.inventory.get_rune(pickup.item_id)
		if rune != null: return rune.display_name
	return display_name(&"potion" if pickup.kind == &"potion" else pickup.item_id)

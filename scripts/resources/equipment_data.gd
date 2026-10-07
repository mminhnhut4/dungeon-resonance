class_name EquipmentData
extends Resource
## Shared presentation/stat definition. Owned UID and rarity live in GearItem.

# Preserve the original four serialized ordinals; ARMOR now denotes the top.
enum SlotType { WEAPON, ARMOR, RING, AMULET, PANTS, BOOTS, GLOVES }
const SLOT_COUNT: int = 7
const SLOT_KINDS: Array[StringName] = [&"weapon", &"armor", &"ring", &"amulet", &"pants", &"boots", &"gloves"]
const SLOT_NAMES: Array[String] = ["VŨ KHÍ", "ÁO", "NHẪN", "DÂY CHUYỀN", "QUẦN", "GIÀY", "GĂNG TAY"]
@export var id: StringName
@export var item_name: String
@export_multiline var description: String
@export var slot_type: SlotType = SlotType.WEAPON
@export var icon_texture: Texture2D
@export var world_sprite_texture: Texture2D
## Per-bone outfit layers; pivots/scale are data rather than visual-script guesses.
@export var visual_parts: Array[ModularCharacterPart] = []
@export var moveset: WeaponDefinition
## Authored element identity; socketed runes still belong to runtime inventory.
@export var intrinsic_runes: Array[RuneData] = []
@export var bonus_hp: float = 0.0
@export var bonus_armor: float = 0.0
@export var bonus_mana: float = 0.0
@export var bonus_atk: float = 0.0
## Fraction of base speed / critical probability, not percent points.
@export var bonus_speed: float = 0.0
@export var bonus_crit: float = 0.0
@export var hand_origin: Vector2 = Vector2(375, 362)
@export var displayed_weapon_length: float = 40.0

class_name GearVariantData
extends Resource
## A catalogue entry chooses an initial grade. Mutable grade/+level live on UID.
@export var id: StringName
@export var equipment: EquipmentData
@export_range(0, 5, 1) var quality: int = 0

func valid() -> bool:
	return not id.is_empty() and equipment != null and equipment.moveset != null and quality >= 0 and quality <= 5

func create_owned(inventory: GearInventory) -> GearItem:
	if not valid() or inventory == null: return null
	return inventory.add_equipment(equipment, quality)


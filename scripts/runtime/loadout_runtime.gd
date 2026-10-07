class_name LoadoutRuntime
extends RefCounted
## Unique actor loadout; cooldown ownership survives swapping a catalyst.

var weapon_id: StringName
var catalysts: Array[CatalystRuntime] = []
var cooldowns_by_recipe_id: Dictionary[StringName, float] = {}

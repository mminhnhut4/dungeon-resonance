class_name CatalystDefinition
extends Resource
## Slot limits are authored data; opened slots belong to CatalystRuntime.

@export var id: StringName
@export var display_name: String
@export_range(1, 8, 1) var initial_slots: int = 2
@export_range(1, 8, 1) var maximum_slots: int = 3

class_name RuneDefinition
extends Resource
## A Rune Shard is data, not a Player child node.

@export var id: StringName
@export var display_name: String
@export var tags: Array[StringName] = []
@export var display_color: Color = Color.WHITE

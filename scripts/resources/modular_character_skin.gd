class_name ModularCharacterSkin
extends Resource
## Opt-in cutout skin. The actor owns the mounted sprites; this data stays shared.

@export var id: StringName
@export var parts: Array[ModularCharacterPart] = []
@export_range(0.25, 4.0, 0.05) var visual_scale: float = 1.0
## Foot contact in the authored skeleton's local coordinates, not image pixels.
@export var foot_origin: Vector2 = Vector2(0.0, 8.0)

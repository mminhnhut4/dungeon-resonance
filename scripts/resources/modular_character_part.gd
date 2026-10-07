class_name ModularCharacterPart
extends Resource
## Immutable PNG/AtlasTexture attachment. Pixel pivot lands on its visual bone.

@export var id: StringName
@export var bone_slot: StringName = &"body"
@export var texture: Texture2D
@export var pivot_pixels: Vector2 = Vector2.ZERO
@export var display_scale: Vector2 = Vector2.ONE
@export_range(-16, 16, 1) var draw_order: int = 0
@export var tint: Color = Color.WHITE


func is_valid_part() -> bool:
	return not id.is_empty() and texture != null and pivot_pixels.is_finite() and display_scale.is_finite() and display_scale.x > 0.0 and display_scale.y > 0.0

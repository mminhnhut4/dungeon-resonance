class_name HubNpc
extends Node2D
## Neutral vector preview. No combat/collision/AI portrait ownership.

@export var npc_id: StringName = &""
@export var preview_tint: Color = Color(0.56, 0.58, 0.54)
var portrait: Texture2D
var body: Sprite2D
var alpha_geometry: Dictionary = {}
var _clock: float = 0.0
var _scale: float = 1.0

func _ready() -> void:
	if portrait != null: _build_sprite()

func _process(delta: float) -> void:
	_clock += delta
	if body != null:
		body.scale.y = _scale * (1.0 + sin(_clock * 2.4) * 0.014)

func _draw() -> void:
	if portrait != null: return
	# The plain silhouette deliberately carries no new equipment or authored art.
	draw_set_transform(Vector2(0, -2), 0, Vector2(1, 0.26))
	draw_circle(Vector2.ZERO, 15, Color(0.01, 0.02, 0.02, 0.4))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -38), Vector2(9, -38), Vector2(15, -4), Vector2(-15, -4)]), preview_tint)
	draw_circle(Vector2(0, -48), 9, preview_tint.lightened(0.12))
	draw_line(Vector2(-6, -4), Vector2(-7, 0), preview_tint.darkened(0.2), 5)
	draw_line(Vector2(6, -4), Vector2(7, 0), preview_tint.darkened(0.2), 5)

func set_approved_portrait(texture: Texture2D) -> void:
	portrait = texture
	if is_inside_tree(): _build_sprite()
	queue_redraw()

func _build_sprite() -> void:
	if body == null:
		body = Sprite2D.new()
		body.name = "ApprovedNpcSprite"
		body.centered = false
		body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(body)
	alpha_geometry = EnemySpriteArt.configure(body, portrait, 60.0)
	_scale = body.scale.x

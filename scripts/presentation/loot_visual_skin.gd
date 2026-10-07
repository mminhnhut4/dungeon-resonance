class_name LootVisualSkin
extends Node2D
## Cosmetic only: collection, UID, magnet and floor remain in LootPickup.

var sprite: Sprite2D
var pickup_id: int = 0
var original_label_visible: bool = true

func bind(pickup: LootPickup) -> void:
	pickup_id = pickup.get_instance_id()
	pickup.presentation_skin_active = true
	pickup.queue_redraw()
	original_label_visible = pickup.item_label.visible
	pickup.item_label.text = ItemArtCatalog.pickup_name(pickup) + (" ×%d" % pickup.quantity if pickup.quantity > 1 else "")
	pickup.item_label.add_theme_color_override("font_color", GearItem.COLORS[clampi(pickup.quality, 0, 5)])
	pickup.item_label.visible = false
	sprite = Sprite2D.new()
	sprite.name = "ApprovedItemSprite"
	sprite.texture = ItemArtCatalog.pickup_icon(pickup)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var height: float = 24.0 if pickup.runtime_item != null else 20.0
	if sprite.texture != null: sprite.scale = Vector2.ONE * (height / sprite.texture.get_height())
	if pickup.kind == &"rune" and not ItemArtCatalog.RUNE_ICONS.has(pickup.item_id):
		var rune: RuneData = pickup.inventory.get_rune(pickup.item_id) if pickup.inventory != null else null
		if rune != null: sprite.modulate = rune.display_color
	add_child(sprite)
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	var pickup: LootPickup = instance_from_id(pickup_id) as LootPickup if is_instance_id_valid(pickup_id) else null
	if pickup == null or sprite == null: return
	sprite.position.y = sin(pickup.age * 4.0) * 2.5
	pickup.item_label.visible = pickup.global_position.distance_to(get_global_mouse_position()) < 12.0
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 10), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 10, Color(0.015, 0.03, 0.025, 0.30))
	draw_set_transform(Vector2.ZERO)

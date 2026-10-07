class_name EnemySpriteArt
extends RefCounted
## Shared imported PNG; alpha geometry is cached on the native texture only.

const CACHE_KEY: StringName = &"dungeon_enemy_alpha_bounds_v1"


static func alpha_geometry(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}
	var cached: Dictionary = texture.get_meta(CACHE_KEY, {})
	if not cached.is_empty():
		return cached
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return {}
	if image.is_compressed() and image.decompress() != OK:
		return {}
	image.convert(Image.FORMAT_RGBA8)
	var bounds: Rect2i = image.get_used_rect()
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return {}
	var left: int = image.get_width()
	var right: int = -1
	# Ignore fully transparent padding. Lowest solid pixels anchor feet to ground.
	for y: int in range(maxi(bounds.position.y, bounds.end.y - 4), bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			if image.get_pixel(x, y).a > 0.03:
				left = mini(left, x)
				right = maxi(right, x)
	if right < left:
		left = bounds.position.x
		right = bounds.end.x - 1
	var geometry: Dictionary = {
		"bounds": bounds,
		"foot_pixel": Vector2((left + right + 1) * 0.5, bounds.end.y),
	}
	texture.set_meta(CACHE_KEY, geometry)
	return geometry


static func configure(sprite: Sprite2D, texture: Texture2D, height: float) -> Dictionary:
	var geometry: Dictionary = alpha_geometry(texture)
	if geometry.is_empty():
		return {}
	var bounds: Rect2i = geometry["bounds"]
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE * (height / float(bounds.size.y))
	set_facing(sprite, geometry["foot_pixel"], false)
	return geometry


static func set_facing(sprite: Sprite2D, foot: Vector2, left: bool) -> void:
	sprite.flip_h = left
	sprite.offset = Vector2(-(sprite.texture.get_width() - foot.x) if left else -foot.x, -foot.y)


static func foot_world(sprite: Sprite2D, foot: Vector2) -> Vector2:
	var visible_foot: Vector2 = Vector2(sprite.texture.get_width() - foot.x, foot.y) if sprite.flip_h else foot
	return sprite.to_global(sprite.offset + visible_foot)

class_name ExistingMapRaster
extends Node2D
## One room-owned painted background. Gameplay geometry, clocks, RNG and save
## stay in existing owners; only the known backdrop paint can be hidden.

const MAX_RESIDENT_TEXTURES: int = 8
const PAINT_Z: int = -30
const EXTERIOR_PATHS: Dictionary[StringName, String] = {
	&"o01_p03": "res://assets/environment/exterior/rendered_v2/p03_shrine.png",
	&"o01_p04": "res://assets/environment/exterior/rendered_v2/p04_terraces.png",
	&"o02_b01": "res://assets/environment/exterior/rendered_v2/b01_water.png",
	&"o02_b02": "res://assets/environment/exterior/rendered_v2/b02_square.png",
	&"o02_b03": "res://assets/environment/exterior/rendered_v2/b03_post.png",
	&"o02_b04": "res://assets/environment/exterior/rendered_v2/b04_shipyard.png",
}
const CAMPAIGN_KEYS: Dictionary[int, StringName] = {2: &"campaign_secret", 3: &"campaign_mutants"}
const CAMPAIGN_PATHS: Dictionary[StringName, String] = {
	&"campaign_secret": "res://assets/environment/backgrounds/campaign_secret_v2.png",
	&"campaign_mutants": "res://assets/environment/backgrounds/campaign_mutants_v2.png",
}
const CAMPAIGN_BOUNDS: Rect2 = Rect2(0, 0, 1280, 720)
static var resident_bank: Dictionary[StringName, Texture2D] = {}
static var paint_material: CanvasItemMaterial

var sprite: Sprite2D
var owner_id: int = 0
var image_key: StringName
var covered_bounds: Rect2
var hidden_visuals: Array[Dictionary] = [] # Instance IDs and booleans; no room references.


static func texture_for(key: StringName) -> Texture2D:
	if resident_bank.has(key):
		return resident_bank[key]
	var path: String = EXTERIOR_PATHS.get(key, CAMPAIGN_PATHS.get(key, ""))
	if path.is_empty() or not ResourceLoader.exists(path) or resident_bank.size() >= MAX_RESIDENT_TEXTURES:
		return null
	var texture: Texture2D = load(path) as Texture2D
	if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
		return null
	resident_bank[key] = texture
	return texture


static func attach_exterior(room: ExteriorRoom) -> ExistingMapRaster:
	if not is_instance_valid(room):
		return null
	var texture: Texture2D = texture_for(room.room_id)
	if texture == null:
		_restore_existing(room)
		return null
	var art: ExistingMapRaster = _room_adapter(room)
	if art == null or not art._bind(room, room.bounds, room.room_id, texture):
		return null
	preload("res://scripts/presentation/existing_route_terrain.gd").attach(room)
	# Direct root paint created by ExteriorRoom._background only. In particular,
	# never descend into StaticBody2D paint and never hide water/props/labels.
	for child: Node in room.get_children():
		if child is Polygon2D and child.z_index in [-20, -18]:
			art._hide(child as CanvasItem)
	return art


static func attach_campaign(room: Node2D, stage: int, legacy_scope: Node = null) -> ExistingMapRaster:
	if not is_instance_valid(room):
		return null
	var key: StringName = CAMPAIGN_KEYS.get(stage, &"")
	var texture: Texture2D = texture_for(key)
	if texture == null:
		_restore_existing(room)
		return null
	var art: ExistingMapRaster = _room_adapter(room)
	if art == null or not art._bind(room, CAMPAIGN_BOUNDS, key, texture):
		return null
	# Actual campaign's old backdrop lives under DungeonAtmosphere.room_art,
	# passed by SlicePresentation. No FoyerArt/platform/torch child is hidden.
	var scope: Node = legacy_scope if is_instance_valid(legacy_scope) else room
	if scope is DungeonBackdrop:
		art._hide(scope as CanvasItem)
	for child: Node in scope.find_children("*", "", true, false):
		if child is DungeonBackdrop:
			art._hide(child as CanvasItem)
	return art


static func _room_adapter(room: Node2D) -> ExistingMapRaster:
	var existing: Node = room.get_node_or_null("ExistingMapRaster")
	if existing != null:
		return existing as ExistingMapRaster
	var art := ExistingMapRaster.new()
	art.name = "ExistingMapRaster"
	room.add_child(art)
	return art


static func _restore_existing(room: Node2D) -> void:
	var existing: ExistingMapRaster = room.get_node_or_null("ExistingMapRaster") as ExistingMapRaster
	if existing != null:
		existing.clear()


func _ready() -> void:
	_ensure_sprite()


func _ensure_sprite() -> void:
	z_index = PAINT_Z
	set_process(false)
	set_physics_process(false)
	# ExteriorRoom.configure normally runs before it enters SceneTree. Binding
	# must work there too, and _ready must preserve that prepared Sprite state.
	if sprite != null:
		return
	if paint_material == null:
		paint_material = CanvasItemMaterial.new()
		paint_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite = Sprite2D.new()
	sprite.name = "RenderedExistingBackground"
	sprite.material = paint_material
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	sprite.visible = false
	add_child(sprite)


func _bind(room: Node2D, rectangle: Rect2, key: StringName, texture: Texture2D) -> bool:
	_ensure_sprite()
	clear()
	if not rectangle.position.is_finite() or not rectangle.size.is_finite() or rectangle.size.x <= 0.0 or rectangle.size.y <= 0.0 or sprite == null:
		return false
	owner_id = room.get_instance_id()
	image_key = key
	covered_bounds = rectangle
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	var cover: float = maxf(rectangle.size.x / texture_size.x, rectangle.size.y / texture_size.y)
	var source_size: Vector2 = rectangle.size / cover
	sprite.texture = texture
	# Center-crop preserves the artist's aspect ratio and renders exactly inside
	# the authored camera bounds; no overdraw spills into a neighbouring room.
	sprite.region_rect = Rect2((texture_size - source_size) * 0.5, source_size)
	sprite.scale = Vector2.ONE * cover
	sprite.position = rectangle.get_center()
	sprite.visible = true
	return true


func _hide(item: CanvasItem) -> void:
	var item_id: int = item.get_instance_id()
	for record: Dictionary in hidden_visuals:
		if int(record.id) == item_id:
			return
	hidden_visuals.append({"id": item_id, "visible": item.visible})
	item.visible = false


func clear() -> void:
	for record: Dictionary in hidden_visuals:
		var item_id: int = int(record.id)
		if is_instance_id_valid(item_id):
			var item: CanvasItem = instance_from_id(item_id) as CanvasItem
			if item != null and not item.is_queued_for_deletion():
				item.visible = bool(record.visible)
	hidden_visuals.clear()
	owner_id = 0
	image_key = &""
	covered_bounds = Rect2()
	if sprite != null:
		sprite.visible = false
		sprite.texture = null


func _exit_tree() -> void:
	clear()

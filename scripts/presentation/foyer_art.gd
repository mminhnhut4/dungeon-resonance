class_name FoyerArt
extends Node2D
## Atlas-only foreground skin. Existing physics bodies remain the source of truth.

const JADE_A: AtlasTexture = preload("res://assets/environment/tilesets/regions/foyer_jade_stone_a.tres")
const JADE_B: AtlasTexture = preload("res://assets/environment/tilesets/regions/foyer_jade_stone_b.tres")
const JADE_C: AtlasTexture = preload("res://assets/environment/tilesets/regions/foyer_jade_stone_c.tres")
const FLOOR_STONE: AtlasTexture = preload("res://assets/environment/tilesets/regions/foyer_floor_stone.tres")
const CHAINED_COLUMN: AtlasTexture = preload("res://assets/environment/tilesets/regions/foyer_chained_talisman_column.tres")
const KEY_SHADER: Shader = preload("res://shaders/foyer_stone_key.gdshader")
const LIGHT_TEXTURE: Texture2D = preload("res://assets/presentation/light_radial.png")
const MAX_LIGHTS: int = 8
const PLATFORM_CENTERS: Array[Vector2] = [Vector2(400, 560), Vector2(760, 470), Vector2(1000, 540), Vector2(240, 457), Vector2(140, 374), Vector2(106, 227)]
const PLATFORM_SIZES: Array[Vector2] = [Vector2(150, 20), Vector2(150, 20), Vector2(150, 20), Vector2(150, 22), Vector2(216, 16), Vector2(148, 16)]

var world: Node2D
var decoration: Node2D
var platform_sprites: Array[Sprite2D] = []
var columns: Array[Sprite2D] = []
var lights: Array[PointLight2D] = []
var floor_sprites: Array[Sprite2D] = []
var skinned_bodies: Array[int] = []
var _hidden_visuals: Array[Dictionary] = []
var _jade_material: ShaderMaterial
var _stone_material: ShaderMaterial


func _ready() -> void:
	z_index = 1


func initialize(owner_world: Node2D) -> void:
	rebuild(owner_world)


func rebuild(owner_world: Node2D = null) -> void:
	clear()
	if owner_world != null:
		world = owner_world
	if not is_instance_valid(world):
		return
	_prepare_materials()
	decoration = Node2D.new()
	decoration.name = "AtlasFoyerDecoration"
	add_child(decoration)
	for candidate: Node in world.find_children("*", "StaticBody2D", true, false):
		var body := candidate as StaticBody2D
		if body.has_meta(&"dungeon_architectural_surface"): continue
		if body.collision_layer != 1:
			continue
		var shape_node: CollisionShape2D
		for child: Node in body.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				shape_node = child as CollisionShape2D
				break
		if shape_node == null or shape_node.disabled:
			continue
		var rectangle: RectangleShape2D = shape_node.shape as RectangleShape2D
		var center: Vector2 = world.to_local(shape_node.global_position)
		var index: int = _match_platform(center, rectangle.size)
		if index >= 0:
			_skin_platform(body, center, rectangle.size, index)
		elif _is_floor(center, rectangle.size):
			_skin_floor(body, center, rectangle.size)
	_build_columns()


func _prepare_materials() -> void:
	if _jade_material == null:
		_jade_material = ShaderMaterial.new()
		_jade_material.shader = KEY_SHADER
		_stone_material = ShaderMaterial.new()
		_stone_material.shader = KEY_SHADER
		_stone_material.set_shader_parameter("jade_emission", 0.0)


func _match_platform(center: Vector2, size: Vector2) -> int:
	for index: int in PLATFORM_CENTERS.size():
		# The standalone test room's first step is 2 px lower/thicker than Alpha.
		if center.distance_to(PLATFORM_CENTERS[index]) <= 2.1 and size.distance_to(PLATFORM_SIZES[index]) <= 2.1:
			return index
	return -1


func _is_floor(center: Vector2, size: Vector2) -> bool:
	return absf(center.y - 680.0) < 0.1 and absf(size.y - 80.0) < 0.1 and size.x >= 300.0


func _skin_platform(body: StaticBody2D, center: Vector2, size: Vector2, index: int) -> void:
	_hide_placeholder(body)
	skinned_bodies.append(body.get_instance_id())
	var regions: Array[AtlasTexture] = [JADE_A, JADE_B, JADE_C]
	var height: float = clampf(size.x * 0.24, 28.0, 44.0)
	var sprite: Sprite2D = _sprite(regions[index % regions.size()], Vector2(size.x, height), _jade_material)
	sprite.name = "JadePlatform%d" % index
	# The visible top stays exactly on the collider top; extra bevel sits below it.
	sprite.global_position = world.to_global(center - size * 0.5)
	platform_sprites.append(sprite)
	_add_light(world.to_global(center + Vector2(0, -size.y * 0.5 + height * 0.55)), 0.52, 1.65)


func _skin_floor(body: StaticBody2D, center: Vector2, size: Vector2) -> void:
	_hide_placeholder(body)
	skinned_bodies.append(body.get_instance_id())
	var count: int = ceili(size.x / 109.0)
	var tile_width: float = size.x / float(count)
	for index: int in count:
		var sprite: Sprite2D = _sprite(FLOOR_STONE, Vector2(tile_width + 0.2, size.y), _stone_material)
		sprite.name = "FloorStone%d" % index
		sprite.global_position = world.to_global(center - size * 0.5 + Vector2(index * tile_width, 0))
		floor_sprites.append(sprite)


func _build_columns() -> void:
	for index: int in 2:
		var center := Vector2(1145.0 if index == 0 else 1235.0, 640.0)
		var size := Vector2(48.0, 118.0)
		var sprite: Sprite2D = _sprite(CHAINED_COLUMN, size, _stone_material)
		sprite.name = "DoorTalismanColumn%d" % index
		sprite.flip_h = index == 1
		sprite.global_position = world.to_global(center + Vector2(-size.x * 0.5, -size.y))
		columns.append(sprite)
		_add_light(world.to_global(center + Vector2(0, -72)), 0.58, 1.3)


func _sprite(region: AtlasTexture, size: Vector2, sprite_material: ShaderMaterial) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = region
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = size / region.get_size()
	sprite.material = sprite_material
	decoration.add_child(sprite)
	return sprite


func _add_light(location: Vector2, energy: float, light_scale: float) -> void:
	if lights.size() >= MAX_LIGHTS:
		return
	var light := PointLight2D.new()
	light.name = "JadeCrackLight"
	light.texture = LIGHT_TEXTURE
	light.color = Color(0.30, 1.0, 0.59)
	light.energy = energy
	light.texture_scale = light_scale
	light.shadow_enabled = false
	decoration.add_child(light)
	light.global_position = location
	lights.append(light)


func _hide_placeholder(body: StaticBody2D) -> void:
	for child: Node in body.get_children():
		if child is Polygon2D:
			_hidden_visuals.append({"visual": weakref(child), "visible": child.visible})
			child.visible = false


func clear() -> void:
	for record: Dictionary in _hidden_visuals:
		var visual: Object = (record.visual as WeakRef).get_ref()
		if is_instance_valid(visual):
			(visual as Polygon2D).visible = bool(record.visible)
	_hidden_visuals.clear()
	platform_sprites.clear()
	columns.clear()
	lights.clear()
	floor_sprites.clear()
	skinned_bodies.clear()
	if is_instance_valid(decoration):
		remove_child(decoration)
		decoration.queue_free()
	decoration = null


func _exit_tree() -> void:
	clear()
	world = null

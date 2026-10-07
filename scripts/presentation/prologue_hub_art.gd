class_name PrologueHubArt
extends Node2D
## Approved painted safe world. No collision/hitbox transforms are edited here.

const YARD: Texture2D = preload("res://assets/environment/backgrounds/prologue_courtyard_v1.png")
const HOME: Texture2D = preload("res://assets/environment/backgrounds/player_home_v1.png")
const PROPS: Texture2D = preload("res://assets/environment/props/prologue_props_atlas_v1.png")
const KAEL: Texture2D = preload("res://assets/sprites/npc/kael_side_v2.png")
const LIGHT: Texture2D = preload("res://assets/presentation/light_radial.png")
var hub: PrologueHub
var yard_art: Node2D
var home_art: Node2D
var fire: Campfire
var hidden_visuals: Array[CanvasItem] = []
var original_visibility: Array[bool] = []

func _ready() -> void:
	initialize.call_deferred(get_parent() as PrologueHub)

func initialize(owner_hub: PrologueHub) -> void:
	if hub != null or not is_instance_valid(owner_hub) or not is_instance_valid(owner_hub.player): return
	hub = owner_hub
	hub.presentation.foyer_art.clear()
	hub.presentation.atmosphere.room_art.hide()
	hub.presentation.atmosphere.ambient.color = Color(0.78, 0.84, 0.83)
	hub.presentation.atmosphere.dust.emitting = false
	yard_art = Node2D.new()
	yard_art.name = "ApprovedCourtyardArt"
	hub.yard.add_child(yard_art)
	# Background slice omits the baked house: the interactive facade is separate.
	_region(yard_art, YARD, Rect2(1000, 0, 1172, 602), Vector2(2400, 640), Vector2.ZERO, -20, true)
	_region(yard_art, YARD, Rect2(0, 602, 2172, 122), Vector2(2400, 80), Vector2(0, 640), 1)
	for candidate: Node in hub.yard.find_children("*", "Polygon2D", true, false):
		_hide(candidate as CanvasItem)
	_prop(hub.stations[&"house"], Rect2(85, 45, 643, 526), 188)
	_prop(hub.stations[&"portal"], Rect2(790, 16, 634, 555), 174)
	_prop(hub.stations[&"stash"], Rect2(173, 668, 485, 293), 40)
	_prop(hub.stations[&"blacksmith"], Rect2(829, 647, 566, 315), 43)
	_region(yard_art, PROPS, Rect2(829, 757, 566, 205), Vector2(72, 26), Vector2(1788, 614), 1)
	var kael: Sprite2D = hub.yard.get_node("KaelSprite") as Sprite2D
	kael.centered = false
	EnemySpriteArt.configure(kael, KAEL, 60)
	kael.position = hub.stations[&"merchant"].position
	kael.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_light(hub.stations[&"house"], Vector2(-42, -90), Color(1, 0.62, 0.29), 0.65)
	_light(hub.stations[&"portal"], Vector2(0, -74), Color(0.25, 0.92, 0.73), 0.9)
	fire = Campfire.new()
	fire.name = "CourtyardCampfire"
	fire.position = Vector2(1590, 640)
	hub.yard.add_child(fire)
	home_art = Node2D.new()
	home_art.name = "ApprovedPlayerHomeArt"
	hub.house.add_child(home_art)
	for child: Node in hub.house.get_children():
		if child is Polygon2D: _hide(child as CanvasItem)
	for candidate: Node in hub.house.floor_body.get_children():
		if candidate is Polygon2D: _hide(candidate as CanvasItem)
	_region(home_art, HOME, Rect2(0, 0, HOME.get_width(), HOME.get_height() * 0.80), Vector2(1280, 640), Vector2.ZERO, -20, true)
	_region(home_art, HOME, Rect2(0, HOME.get_height() * 0.80, HOME.get_width(), HOME.get_height() * 0.20), Vector2(1280, 80), Vector2(0, 640), 1)
	# Interaction markers follow visible furniture; the terrain stays unchanged.
	hub.house.bed_point.position.x = 440
	_light(home_art, Vector2(755, 520), Color(1, 0.69, 0.37), 0.72)
	hub.zone_changed.connect(_on_zone)
	_on_zone(&"home" if hub.inside_house else &"yard")

func _region(parent_node: Node, source: Texture2D, rect: Rect2, size: Vector2, location: Vector2, order: int, unshaded: bool = false) -> Sprite2D:
	var region := AtlasTexture.new()
	region.atlas = source
	region.region = rect
	region.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = region
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = size / rect.size
	sprite.position = location
	sprite.z_index = order
	if unshaded:
		var material := CanvasItemMaterial.new()
		material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		sprite.material = material
	parent_node.add_child(sprite)
	return sprite

func _prop(station: Marker2D, rect: Rect2, height: float) -> void:
	var width: float = rect.size.x / rect.size.y * height
	_region(station, PROPS, rect, Vector2(width, height), Vector2(-width * 0.5, -height), -2)
	# Keep the marker readable just above the painted object when nearby.
	for child: Node in station.get_children():
		if child is Label: child.position.y = -height - 24

func _light(parent_node: Node2D, location: Vector2, tint: Color, strength: float) -> void:
	var light := PointLight2D.new()
	light.texture = LIGHT
	light.texture_scale = 1.9
	light.position = location
	light.color = tint
	light.energy = strength
	light.shadow_enabled = false
	parent_node.add_child(light)

func _hide(item: CanvasItem) -> void:
	hidden_visuals.append(item)
	original_visibility.append(item.visible)
	item.hide()

func _on_zone(zone: StringName) -> void:
	if not is_instance_valid(hub): return
	hub.presentation.atmosphere.ambient.color = Color(0.78, 0.72, 0.66) if zone == &"home" else Color(0.78, 0.84, 0.83)

func _process(_delta: float) -> void:
	if not is_instance_valid(hub): return
	for id: StringName in hub.stations:
		var station: Marker2D = hub.stations[id]
		for child: Node in station.get_children():
			if child is Label: child.visible = not hub.inside_house and hub.player.global_position.distance_to(station.global_position) < 180.0
	for marker: Marker2D in [hub.house.entry_point, hub.house.exit_point, hub.house.bed_point]:
		for child: Node in marker.get_children():
			if child is Label:
				child.visible = hub.inside_house and marker != hub.house.entry_point and hub.player.global_position.distance_to(marker.global_position) < 150.0

func _exit_tree() -> void:
	for index: int in hidden_visuals.size():
		if is_instance_valid(hidden_visuals[index]): hidden_visuals[index].visible = original_visibility[index]

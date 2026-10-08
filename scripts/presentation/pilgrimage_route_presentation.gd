class_name PilgrimageRoutePresentation
extends PilgrimagePresentation
## Painted P02/SC01 surfaces only; preserve authored bridge/gate/door markers.

func initialize(owner_room: Node2D, art_pack: PilgrimageArtPack = DEFAULT_PACK) -> void:
	room = owner_room
	pack = art_pack
	terrain = room.get("surface")
	width = float(room.get("width"))
	min_floor = float(room.get("min_y"))
	name = "PilgrimageRoutePresentation"
	geometry_fingerprint = JSON.stringify(Array(terrain))
	original_collisions = static_collision_snapshot(room)
	original_anchors = room.get("anchors").duplicate(true)
	original_interactions = room.get("interactions").duplicate(true)
	_hide_graybox_visuals()
	far_layer = _layer("RoutePaintedBackdrop", -45)
	middle_layer = _layer("RouteDistantStoneAndGrove", -15)
	ground_layer = _layer("AuthoredStoneFaces", -1)
	if pack.alpha_cleanup != null:
		alpha_material = ShaderMaterial.new()
		alpha_material.shader = pack.alpha_cleanup
	if room.get("route_id") == ExteriorRouteCatalog.TUNNEL:
		_corridor_background()
	else:
		_sky()
		_middle_grove()
	_skin_terrain()
	# P01 props, lamp/audio owners and label-distance rules belong to P01 only.
	set_process(true)

func _hide_graybox_visuals() -> void:
	var gate_body: StaticBody2D = room.get("gate") as StaticBody2D
	for child: Node in room.get_children():
		if child is Polygon2D and child.z_index <= -16:
			_hide(child)
		elif child is StaticBody2D and child != gate_body:
			for visual: Node in child.get_children():
				if visual is Polygon2D and visual.color.a > 0.0:
					_hide(visual)
		elif child is Line2D and child.points == terrain:
			_hide(child) # Replace the walkable top, while preserving bridge ropes.

func _middle_grove() -> void:
	# Existing pack details sit behind this room's real heightfield, not P01 props.
	var grove_x: float = width * 0.28
	var ruin_x: float = width * 0.68
	_asset_prop_in_layer(&"middle_grove", Vector2(grove_x, _floor(grove_x) + 230.0), 390.0, middle_layer)
	_asset_prop_in_layer(&"middle_ruin", Vector2(ruin_x, _floor(ruin_x) + 220.0), 300.0, middle_layer)
	middle_layer.modulate = Color(0.65, 0.75, 0.76, 0.78)

func _corridor_background() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	gradient.colors = PackedColorArray([Color("18282d"), Color("2e4140"), Color("394b46")])
	var backdrop := GradientTexture2D.new()
	backdrop.gradient = gradient
	backdrop.width = 8
	backdrop.height = 256
	backdrop.fill_from = Vector2.ZERO
	backdrop.fill_to = Vector2(0, 1)
	_sprite(far_layer, backdrop, Vector2(-1200, min_floor - 800.0), Vector2(width + 2400.0, 1900.0), Color.WHITE, true)
	if pack.terrain_body != null:
		var stone := _sprite(middle_layer, pack.terrain_body, Vector2(-180.0, min_floor - 390.0), Vector2(width + 360.0, 720.0), Color(0.32, 0.39, 0.36, 0.62), true)
		stone.name = "ExistingPackStoneBackdrop"

func _process(delta: float) -> void:
	clock += maxf(0.0, delta)
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null or not is_instance_valid(room): return
	var focus: Vector2 = room.to_local(camera.get_screen_center_position())
	var offset: Vector2 = focus - Vector2(width * 0.5, min_floor - 200.0)
	far_layer.position = offset * (Vector2.ONE - pack.far_scroll_scale)
	middle_layer.position = offset * (Vector2.ONE - pack.middle_scroll_scale)

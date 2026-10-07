class_name PilgrimagePresentation
extends Node2D
## P01 art reads terrain. It never changes collision, travel, actors or progress.
const DEFAULT_PACK: PilgrimageArtPack = preload("res://data/pilgrimage_p01_art.tres")
const LIGHT_TEXTURE: Texture2D = preload("res://assets/presentation/light_radial.png")
const STONE_KEY: Shader = preload("res://shaders/foyer_stone_key.gdshader")
const MAX_LIGHTS: int = 3
var room: Node2D
var pack: PilgrimageArtPack
var terrain: PackedVector2Array
var width: float
var min_floor: float
var far_layer: Node2D
var middle_layer: Node2D
var ground_layer: Node2D
var prop_layer: Node2D
var lights: Array[PointLight2D] = []
var trees: Array[Node2D] = []
var hidden_visuals: Array[Dictionary] = []
var clock: float = 0
var floor_material: ShaderMaterial
var alpha_material: ShaderMaterial
var alpha_sprites: Array[Sprite2D] = []
var grounded_contacts: Array[Dictionary] = []
var geometry_fingerprint: String = ""
var original_collisions: Array[Dictionary] = []
var original_anchors: Dictionary = {}
var original_interactions: Dictionary = {}

func initialize(owner_room: Node2D, art_pack: PilgrimageArtPack = DEFAULT_PACK) -> void:
	room = owner_room
	pack = art_pack
	terrain = room.get("surface")
	width = float(room.get("width"))
	min_floor = float(room.get("min_y"))
	name = "PilgrimagePresentation"
	geometry_fingerprint = JSON.stringify(Array(terrain))
	original_collisions = static_collision_snapshot(room)
	original_anchors = room.get("anchors").duplicate(true)
	original_interactions = room.get("interactions").duplicate(true)
	_hide_graybox_visuals()
	far_layer = _layer("DistantSkyAndMountains",-45)
	middle_layer = _layer("MiddleGroveAndRuins",-15)
	ground_layer = _layer("AuthoredStoneFaces",-1)
	prop_layer = _layer("GroundedProps",-3)
	if pack.alpha_cleanup != null:
		alpha_material = ShaderMaterial.new()
		alpha_material.shader = pack.alpha_cleanup
	_sky()
	_middle_grove()
	_skin_terrain()
	_grounded_props()
	var field_audio := PilgrimageAudio.new()
	add_child(field_audio)
	field_audio.initialize(room as ExteriorRoom)
	set_process(true)

func _layer(label: String, order: int) -> Node2D:
	var layer := Node2D.new()
	layer.name = label
	layer.z_index = order
	add_child(layer)
	return layer

func _hide_graybox_visuals() -> void:
	for child: Node in room.get_children():
		if child is Polygon2D and child.z_index <= -16: _hide(child)
		elif child is StaticBody2D:
			for visual: Node in child.get_children():
				if visual is Polygon2D and visual.color.a > 0: _hide(visual)
		elif child is Polygon2D and (child.z_index in [1,2] or (child.z_index == -1 and child.color.is_equal_approx(Color("536c64")))): _hide(child)
		elif child is Line2D: _hide(child)

func _hide(item: CanvasItem) -> void:
	hidden_visuals.append({"item":weakref(item),"visible":item.visible})
	item.hide()

func _sky() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,0.55,1])
	gradient.colors = PackedColorArray([Color("132a34"),Color("455960"),Color("708080")])
	var sky := GradientTexture2D.new()
	sky.gradient = gradient
	sky.width = 8
	sky.height = 256
	sky.fill_from = Vector2(0,0)
	sky.fill_to = Vector2(0,1)
	_sprite(far_layer,sky,Vector2(-1800,min_floor-1050),Vector2(width+3600,2300),Color.WHITE,true)
	if pack.far_panorama != null:
		var size := Vector2(1800,1800*pack.far_panorama.get_height()/float(pack.far_panorama.get_width()))
		_sprite(far_layer,pack.far_panorama,Vector2(width*0.5,min_floor-240)-size*0.5,size,pack.far_tint,true)
	# Quiet blue mist separates the painted cliffs from the near stone path.
	var haze := GradientTexture2D.new()
	haze.gradient = _fade_gradient(Color(0.42,0.56,0.60,0.16))
	haze.width = 8
	haze.height = 128
	haze.fill_from = Vector2(0,0)
	haze.fill_to = Vector2(0,1)
	_sprite(far_layer,haze,Vector2(-1800,min_floor-260),Vector2(width+3600,400),Color.WHITE,true)

func _middle_grove() -> void:
	if pack.prop_textures.has(&"middle_grove") and pack.prop_textures.has(&"middle_ruin"):
		_asset_prop_in_layer(&"middle_grove",Vector2(850,min_floor+230),430,middle_layer)
		_asset_prop_in_layer(&"middle_ruin",Vector2(1840,min_floor+260),320,middle_layer)
		middle_layer.modulate = Color(0.65,0.75,0.76,0.86)
		return
	if pack.middle_panorama != null:
		_sprite(middle_layer,pack.middle_panorama,Vector2(-600,min_floor-480),Vector2(width+1200,680),Color(0.52,0.65,0.65),true)
	for index: int in 6:
		var x: float = -260+index*490
		var points := PackedVector2Array([Vector2(x,min_floor+520),Vector2(x+120,min_floor-175),Vector2(x+210,min_floor-220),Vector2(x+300,min_floor-140),Vector2(x+420,min_floor+520)])
		_polygon(middle_layer,points,Color(0.13,0.22,0.25,0.50))
	for x: float in [250.0,710.0,1110.0,2180.0]:
		var base: float = _floor(clampf(x,0,width))+80
		var tree := _tree(middle_layer,Vector2(x,base),220,Color("223c3e"),Color("2d4948"))
		tree.modulate.a = 0.75
	# Broken outer-wall rhythm hints at a pilgrimage route without adding a gate.
	for x: float in [550.0,670.0,820.0]:
		var y: float = _floor(x)+18
		_polygon(middle_layer,_rect(Rect2(x,y-65,18,85)),Color("3d5050"))
		_polygon(middle_layer,_rect(Rect2(x-7,y-75,32,12)),Color("52645e"))

func _skin_terrain() -> void:
	if pack.terrain_cap != null and pack.terrain_body != null:
		_skin_painted_terrain()
		return
	floor_material = ShaderMaterial.new()
	floor_material.shader = STONE_KEY
	floor_material.set_shader_parameter("jade_emission",0.15)
	for segment: int in terrain.size()-1:
		var a: Vector2 = terrain[segment]
		var b: Vector2 = terrain[segment+1]
		var tiles: int = ceili((b.x-a.x)/104.0)
		for tile: int in tiles:
			var start: Vector2 = a.lerp(b,float(tile)/tiles)
			var end: Vector2 = a.lerp(b,float(tile+1)/tiles)
			var face := _polygon(ground_layer,PackedVector2Array([start,end,end+Vector2(0,270),start+Vector2(0,270)]),pack.stone_tint)
			face.texture = pack.terrain_texture
			if face.texture != null:
				var size: Vector2 = face.texture.get_size()
				face.uv = PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)])
				face.material = floor_material
			_polygon(ground_layer,PackedVector2Array([start+Vector2(0,85),end+Vector2(0,85),end+Vector2(0,310),start+Vector2(0,310)]),Color(0.035,0.07,0.08,0.65))
	var edge := Line2D.new()
	edge.name = "ExactWalkableTop"
	edge.points = terrain
	edge.width = 2
	edge.default_color = Color("879c88")
	ground_layer.add_child(edge)
	var jumps: Array = room.get("jumps")
	for jump: Dictionary in jumps:
		var landing: Vector2 = jump["landing"]
		var ledge := _polygon(ground_layer,_rect(Rect2(landing+Vector2(-55,0),Vector2(110,24))),Color("6c837d"))
		ledge.texture = pack.terrain_texture
		if ledge.texture != null:
			var size: Vector2 = ledge.texture.get_size()
			ledge.uv = PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)])
			ledge.material = floor_material
		var top := Line2D.new()
		top.points = PackedVector2Array([landing+Vector2(-55,0),landing+Vector2(55,0)])
		top.width = 2
		top.default_color = Color("a3b4a0")
		ground_layer.add_child(top)

func _grounded_props() -> void:
	# One distinctive pine; the open ascent and plateau have their own silhouettes.
	# The separate, dimmer parallax grove belongs to the distant valley.
	for definition: Vector2 in [Vector2(565,300)]:
		var at := Vector2(definition.x,_floor(definition.x))
		if not _asset_prop(&"tree",at,definition.y): _tree(prop_layer,at,definition.y,Color("25332f"),Color("385249"))
	for definition: Vector3 in [Vector3(440,38,20),Vector3(735,60,26),Vector3(1440,44,18),Vector3(2250,55,24)]:
		var at := Vector2(definition.x,_floor(definition.x))
		if not _asset_prop(&"rock",at,definition.z):
			_polygon(prop_layer,PackedVector2Array([at+Vector2(-definition.y*0.5,0),at+Vector2(-definition.y*0.4,-definition.z*0.75),at+Vector2(0,-definition.z),at+Vector2(definition.y*0.45,-definition.z*0.55),at+Vector2(definition.y*0.5,0)]),Color("4d625e"))
			_line(prop_layer,PackedVector2Array([at+Vector2(-definition.y*0.4,-definition.z*0.75),at+Vector2(0,-definition.z)]),Color("778579"),2)
	_lantern(Vector2(980,_floor(980)),104)
	_lantern(Vector2(1330,_floor(1330)),88)
	var bench_at := Vector2(1380,_floor(1380))
	if not _asset_prop(&"bench",bench_at,34):
		_polygon(prop_layer,_rect(Rect2(bench_at+Vector2(-38,-27),Vector2(76,8))),Color("6f6b51"))
		for dx: float in [-28.0,28.0]: _polygon(prop_layer,_rect(Rect2(bench_at+Vector2(dx,-19),Vector2(7,19))),Color("393f35"))
	# Small discarded travel vessels sit behind the walk plane, not on a landing.
	for dx: float in [-7.0,5.0]:
		var at: Vector2 = bench_at+Vector2(51+dx,0)
		_polygon(prop_layer,PackedVector2Array([at+Vector2(-5,0),at+Vector2(-7,-12),at+Vector2(-4,-17),at+Vector2(4,-17),at+Vector2(7,-12),at+Vector2(5,0)]),Color("788375"))
	# A marker/roof sits behind the existing tunnel doorway; its E point is intact.
	var tunnel := Vector2(320,_floor(320))
	if not _asset_prop(&"shrine",tunnel,108):
		for dx: float in [-35.0,30.0]: _polygon(prop_layer,_rect(Rect2(tunnel+Vector2(dx,-80),Vector2(8,80))),Color("66746a"))
		_polygon(prop_layer,PackedVector2Array([tunnel+Vector2(-52,-80),tunnel+Vector2(-34,-94),tunnel+Vector2(0,-104),tunnel+Vector2(34,-94),tunnel+Vector2(52,-80)]),Color("283f42"))
		_line(prop_layer,PackedVector2Array([tunnel+Vector2(-52,-80),tunnel+Vector2(0,-90),tunnel+Vector2(52,-80)]),Color("69867c"),3)

func _asset_prop(kind: StringName, foot: Vector2, height: float) -> bool:
	return _asset_prop_in_layer(kind,foot,height,prop_layer)

func _asset_prop_in_layer(kind: StringName, foot: Vector2, height: float, parent_layer: Node2D) -> bool:
	var texture: Texture2D = pack.prop_textures.get(kind)
	if texture == null: return false
	var size: Vector2 = texture.get_size()
	var scale_factor: float = height/size.y
	if pack.prop_scales.has(kind):
		scale_factor = pack.prop_scales[kind]*height/pack.prop_reference_heights[kind]
	var pivot: Vector2 = pack.prop_foot_pivots.get(kind,Vector2(size.x*0.5,size.y))
	var foot_root := Node2D.new()
	foot_root.name = "Grounded_"+String(kind)
	foot_root.position = foot
	parent_layer.add_child(foot_root)
	var sprite := _sprite(foot_root,texture,Vector2.ZERO,size*scale_factor,Color.WHITE)
	sprite.name = "ArtProp_"+String(kind)
	sprite.offset = -pivot
	if parent_layer == prop_layer and pack.prop_ground_profiles.has(kind):
		var profile: PackedVector2Array = pack.prop_ground_profiles[kind]
		var resting_y: float = -INF
		for contact: Vector2 in profile:
			var local_contact: Vector2 = (contact-pivot)*scale_factor
			resting_y = maxf(resting_y,_floor(clampf(foot.x+local_contact.x,0,width))-local_contact.y)
		# The original stone face occludes buried roots. Two pixels also cover sway.
		foot_root.position.y = resting_y+2.0
		grounded_contacts.append({"root":foot_root,"sprite":sprite,"profile":profile,"pivot":pivot,"kind":kind})
	if pack.alpha_cleanup_enabled and alpha_material != null: sprite.material = alpha_material
	alpha_sprites.append(sprite)
	if kind == &"tree": trees.append(foot_root)
	return true

func show_alpha_cleanup(enabled: bool) -> void:
	for sprite: Sprite2D in alpha_sprites: sprite.material = alpha_material if enabled else null

func _skin_painted_terrain() -> void:
	# One bounded mapping spans the room. The source is not assumed seamless.
	for segment: int in terrain.size()-1:
		_painted_face(terrain[segment],terrain[segment+1],0,14,pack.terrain_cap,pack.terrain_cap.get_height())
		_painted_face(terrain[segment],terrain[segment+1],14,105,pack.terrain_body,91*pack.terrain_body.get_width()/width)
	var edge := Line2D.new()
	edge.name = "ExactWalkableTop"
	edge.points = terrain
	edge.width = 1.7
	edge.default_color = Color("a0a68a")
	ground_layer.add_child(edge)
	var jumps: Array = room.get("jumps")
	for jump: Dictionary in jumps:
		var landing: Vector2 = jump["landing"]
		var a: Vector2 = landing+Vector2(-55,0)
		var b: Vector2 = landing+Vector2(55,0)
		_painted_face(a,b,0,5,pack.terrain_cap,pack.terrain_cap.get_height())
		_painted_face(a,b,5,25,pack.terrain_body,20*pack.terrain_body.get_width()/width)
		_line(ground_layer,PackedVector2Array([a,b]),Color("bbc1a0"),2)

func _painted_face(a: Vector2, b: Vector2, top: float, bottom: float, texture: Texture2D, v_extent: float) -> void:
	var face := _polygon(ground_layer,PackedVector2Array([a+Vector2(0,top),b+Vector2(0,top),b+Vector2(0,bottom),a+Vector2(0,bottom)]),pack.stone_tint)
	face.texture = texture
	var region := Rect2(Vector2.ZERO,texture.get_size())
	if texture is AtlasTexture:
		# Polygon2D UVs address the source texture, unlike a Sprite2D atlas crop.
		var atlas := texture as AtlasTexture
		face.texture = atlas.atlas
		region = atlas.region
	var ax: float = region.position.x+a.x*region.size.x/width
	var bx: float = region.position.x+b.x*region.size.x/width
	var top_v: float = region.position.y
	var bottom_v: float = top_v+minf(v_extent,region.size.y)
	face.uv = PackedVector2Array([Vector2(ax,top_v),Vector2(bx,top_v),Vector2(bx,bottom_v),Vector2(ax,bottom_v)])
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _tree(parent_layer: Node2D, foot: Vector2, height: float, bark: Color, leaves: Color) -> Node2D:
	var tree := Node2D.new()
	tree.position = foot
	parent_layer.add_child(tree)
	_polygon(tree,PackedVector2Array([Vector2(-8,0),Vector2(-5,-height*0.64),Vector2(3,-height*0.77),Vector2(8,-height*0.34),Vector2(12,0)]),bark)
	for index: int in 5:
		var y: float = -height*(0.36+index*0.11)
		var spread: float = height*(0.40-index*0.045)
		_polygon(tree,PackedVector2Array([Vector2(-spread,y+16),Vector2(-spread*0.45,y-27),Vector2(6,y-43),Vector2(spread*0.6,y-23),Vector2(spread,y+13),Vector2(0,y+24)]),leaves.lightened(index*0.013))
	trees.append(tree)
	return tree

func _lantern(foot: Vector2, height: float) -> void:
	if not _asset_prop(&"lantern",foot,height):
		_polygon(prop_layer,_rect(Rect2(foot+Vector2(-3,-height),Vector2(6,height))),Color("4b5b4e"))
		_polygon(prop_layer,_rect(Rect2(foot+Vector2(-13,-height+9),Vector2(26,28))),Color("a38b4d"))
		_polygon(prop_layer,_rect(Rect2(foot+Vector2(-9,-height+13),Vector2(18,19))),Color("efbe65"))
		_line(prop_layer,PackedVector2Array([foot+Vector2(-14,-height+9),foot+Vector2(14,-height+9)]),Color("5f6d50"),4)
	if lights.size() >= MAX_LIGHTS: return
	var light := PointLight2D.new()
	light.texture = LIGHT_TEXTURE
	light.position = foot+Vector2(0,-height+22)
	light.color = Color(1,0.69,0.36)
	light.energy = 0.42
	light.texture_scale = 1.3
	light.shadow_enabled = false
	add_child(light)
	lights.append(light)

func _sprite(parent_layer: Node, texture: Texture2D, at: Vector2, size: Vector2, tint: Color, unshaded: bool = false) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = at
	sprite.scale = size/texture.get_size()
	sprite.modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if unshaded:
		var material := CanvasItemMaterial.new()
		material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		sprite.material = material
	parent_layer.add_child(sprite)
	return sprite

func _polygon(parent_layer: Node, points: PackedVector2Array, tint: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = tint
	polygon.antialiased = true
	parent_layer.add_child(polygon)
	return polygon

func _line(parent_layer: Node, points: PackedVector2Array, tint: Color, thickness: float) -> void:
	var line := Line2D.new()
	line.points = points
	line.default_color = tint
	line.width = thickness
	line.antialiased = true
	parent_layer.add_child(line)

func _floor(x: float) -> float:
	return float(room.call("floor_y",x))

func _rect(rectangle: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rectangle.position,Vector2(rectangle.end.x,rectangle.position.y),rectangle.end,Vector2(rectangle.position.x,rectangle.end.y)])

func _fade_gradient(tint: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,0.5,1])
	gradient.colors = PackedColorArray([Color(tint,0),tint,Color(tint,0)])
	return gradient

func _process(delta: float) -> void:
	clock += delta
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null and is_instance_valid(room):
		var focus: Vector2 = room.to_local(camera.get_screen_center_position())
		var offset: Vector2 = focus-Vector2(width*0.5,min_floor-200)
		far_layer.position = offset*(Vector2.ONE-pack.far_scroll_scale)
		middle_layer.position = offset*(Vector2.ONE-pack.middle_scroll_scale)
	for index: int in trees.size(): trees[index].rotation = sin(clock*0.7+index*1.3)*0.004
	for index: int in lights.size(): lights[index].energy = 0.42+sin(clock*3.1+index)*0.035
	# Keep geometry/debug labels out of the scene until close to a useful marker.
	var hub: Node = room.get_parent()
	var actor: Node2D = hub.get("player") as Node2D if hub != null else null
	if is_instance_valid(actor):
		for child: Node in room.get_children():
			if child is Label and child.has_meta(&"debug_keep"):
				child.visible = absf(room.to_local(actor.global_position).x-(child.position.x+100)) < 170

static func static_collision_snapshot(owner_room: Node2D) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for candidate: Node in owner_room.find_children("*","StaticBody2D",true,false):
		var body := candidate as StaticBody2D
		var shapes: Array[Dictionary] = []
		for child: Node in body.get_children():
			if child is CollisionPolygon2D:
				shapes.append({"points":child.polygon.duplicate(),"transform":child.transform,"one_way":child.one_way_collision,"disabled":child.disabled})
			elif child is CollisionShape2D:
				shapes.append({"shape":child.shape,"transform":child.transform,"one_way":child.one_way_collision,"disabled":child.disabled})
		records.append({"id":body.get_instance_id(),"transform":body.transform,"layer":body.collision_layer,"mask":body.collision_mask,"shapes":shapes})
	return records

func _exit_tree() -> void:
	for record: Dictionary in hidden_visuals:
		var item: Object = (record["item"] as WeakRef).get_ref()
		if is_instance_valid(item): (item as CanvasItem).visible = bool(record["visible"])
	hidden_visuals.clear()
	room = null

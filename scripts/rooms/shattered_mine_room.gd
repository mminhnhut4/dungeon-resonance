extends DungeonRoom
## Private handmade sample. One continuous solid floor; no pits or combat walls.
const WIDTH: float = 5200.0
const ENTRY: Vector2 = Vector2(180, 360)
const LEVER: Vector2 = Vector2(4500, 360)
const SUPPLY: Vector2 = Vector2(5020, 360)
const SURFACE: Array[Vector2] = [Vector2(0,360), Vector2(400,360), Vector2(2000,640), Vector2(2800,640), Vector2(4400,360), Vector2(5200,360)]
const STONE: AtlasTexture = preload("res://assets/environment/tilesets/regions/foyer_floor_stone.tres")
const BACKDROP: Texture2D = preload("res://assets/environment/backgrounds/campaign_secret_v2.png")
const TORCH: SpriteFrames = preload("res://assets/environment/props/campfire/torch_flame_frames_v1.tres")
const LIGHT: Texture2D = preload("res://assets/presentation/light_radial.png")
var shortcut_open: bool = false
var shortcut: StaticBody2D
var lever_label: Label
var terrain_material: ShaderMaterial

func _ready() -> void:
	locked = false
	_build_material()
	for index: int in 4:
		var background := Sprite2D.new()
		background.name = "ExistingCavePaint%d" % index
		background.texture = BACKDROP
		background.centered = false
		background.position = Vector2(index * 1300, 0)
		background.scale = Vector2(1300, 760) / BACKDROP.get_size()
		background.modulate = Color(0.40, 0.48, 0.51)
		background.z_index = -30
		add_child(background)
	var ground_points := PackedVector2Array(SURFACE)
	ground_points.append(Vector2(WIDTH, 850))
	ground_points.append(Vector2(0, 850))
	var ground := StaticBody2D.new()
	ground.name = "ContinuousMineFloor"
	ground.collision_layer = 1
	ground.collision_mask = 0
	ground.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	var collider := CollisionPolygon2D.new()
	collider.polygon = ground_points
	ground.add_child(collider)
	var paint := Polygon2D.new()
	paint.polygon = ground_points
	paint.texture = STONE.atlas
	paint.uv = ground_points
	paint.material = terrain_material
	ground.add_child(paint)
	add_child(ground)
	var edge := Line2D.new()
	edge.points = PackedVector2Array(SURFACE)
	edge.width = 5.0
	edge.default_color = Color("92a89a")
	add_child(edge)
	_block(Vector2(-16, 400), Vector2(32, 900), Color("18232a"))
	_block(Vector2(WIDTH + 16, 400), Vector2(32, 900), Color("18232a"))
	traversal_points = {&"entry": ENTRY, &"descent":Vector2(1200,500), &"combat_west":Vector2(2040,640), &"combat_east":Vector2(2760,640), &"ascent":Vector2(3600,500), &"lever":LEVER, &"supply":SUPPLY}
	_sign(ENTRY + Vector2(-100,-100), "LỐI VỀ CĂN CỨ\nE · Trở về với đồ đang mang")
	_sign(Vector2(750, floor_y(750)-110), "LỐI XUỐNG MỎ →\nĐi bộ theo dốc đá")
	_sign(Vector2(2080,510), "LÒNG MỎ\n3 Slime · nền chiến đấu rộng")
	lever_label = _sign(LEVER + Vector2(-100,-110), "CHỐT CẦU TẮT\nDọn Slime rồi E mở cầu về")
	_sign(Vector2(4750,220), "NHÁNH TIẾP TẾ →\nBột Phép + Tinh Thạch\nThanh Vy dùng để chế bùa đã học")
	for x: float in [260.0, 1600.0, 2520.0, 3680.0, 4620.0]:
		_torch(Vector2(x, floor_y(x)-100))
	queue_redraw()

func _build_material() -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform vec4 region; void fragment(){ vec2 px=UV/TEXTURE_PIXEL_SIZE; vec2 at=region.xy+vec2(1.0)+fract(px/vec2(109.0,95.0))*(region.zw-vec2(2.0)); COLOR=texture(TEXTURE,at*TEXTURE_PIXEL_SIZE)*vec4(0.66,0.76,0.73,1.0); }"
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = shader
	terrain_material.set_shader_parameter("region", Vector4(STONE.region.position.x, STONE.region.position.y, STONE.region.size.x, STONE.region.size.y))

func floor_y(x: float) -> float:
	for index: int in range(SURFACE.size()-1):
		var a: Vector2 = SURFACE[index]
		var b: Vector2 = SURFACE[index+1]
		if x <= b.x:
			return lerpf(a.y, b.y, clampf((x-a.x)/(b.x-a.x),0.0,1.0))
	return SURFACE[-1].y

func set_locked(value: bool) -> void:
	# This sample always permits a retreat at the west entrance.
	locked = value

func open_shortcut() -> bool:
	if shortcut_open: return false
	shortcut_open = true
	shortcut = _block(Vector2(2440,368),Vector2(4080,16),Color("83998a"))
	shortcut.name = "ReturnBridge"
	var shape: CollisionShape2D = shortcut.get_node("Shape") as CollisionShape2D
	shape.one_way_collision = true
	shape.one_way_collision_margin = 4.0
	var paint: Polygon2D = shortcut.get_child(1) as Polygon2D
	paint.texture = STONE.atlas
	paint.uv = paint.polygon
	paint.material = terrain_material
	lever_label.text = "← CẦU TẮT ĐÃ MỞ\nĐi thẳng về cửa mỏ · Nhánh tiếp tế →"
	queue_redraw()
	return true

func _sign(at: Vector2, text: String) -> Label:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_size_override("font_size",17)
	label.add_theme_color_override("font_color",Color("eadcb7"))
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.set_meta(&"debug_keep",true)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _torch(at: Vector2) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.position = at
	sprite.sprite_frames = TORCH
	sprite.scale = Vector2.ONE * 0.075
	add_child(sprite)
	sprite.play(&"burn")
	var light := PointLight2D.new()
	light.position = at
	light.texture = LIGHT
	light.texture_scale = 4.0
	light.energy = 0.7
	light.color = Color("e4c28c")
	light.shadow_enabled = false
	add_child(light)

func _draw() -> void:
	# A simple stone control marker, not a new collectible or mining asset.
	draw_rect(Rect2(LEVER-Vector2(13,38),Vector2(26,38)),Color("536d67"))
	draw_line(LEVER-Vector2(0,28),LEVER+Vector2(-19 if shortcut_open else 19,-57),Color("e2bb70"),5)

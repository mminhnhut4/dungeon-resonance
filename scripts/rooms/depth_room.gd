class_name DepthRoom
extends DungeonRoom
## Independent room layout; every shelf is optional above the continuous combat lane.
const Catalog = preload("res://data/depth_floor_catalog.gd")
const TerrainScript=preload("res://scripts/presentation/depth_terrain_art.gd")
var floor_data: Dictionary
var background: Sprite2D
var fallback: Polygon2D
var raster_bound: bool = false
var surfaces: Array[StaticBody2D] = []
var terrain_art: Node2D
func _ready() -> void:
	assert(Catalog.valid(room_number))
	floor_data = Catalog.floor_data(room_number)
	var palette: Color = floor_data["palette"]
	_build_background(palette)
	var ground: StaticBody2D = _block(Vector2(640,680),Vector2(1280,80),palette.darkened(.45))
	ground.name="DepthCombatFloor"; ground.set_meta(&"dungeon_architectural_surface",true); surfaces.append(ground)
	_block(Vector2(16,360),Vector2(32,720),palette.darkened(.65)).name="DepthWestBoundary"
	_block(Vector2(1264,360),Vector2(32,720),palette.darkened(.65)).name="DepthEastBoundary"
	var shelf_index: int = 0
	for rectangle: Rect2 in floor_data["shelves"]:
		var body: StaticBody2D = _block(rectangle.get_center(),rectangle.size,palette)
		body.name="DepthShelf%d" % shelf_index; body.set_meta(&"dungeon_architectural_surface",true)
		var shape: CollisionShape2D = body.get_node("Shape") as CollisionShape2D
		shape.one_way_collision=true; shape.one_way_collision_margin=4.0
		surfaces.append(body)
		traversal_points[StringName("shelf_%d" % shelf_index)]=Vector2(rectangle.get_center().x,rectangle.position.y)
		shelf_index+=1
	traversal_points[&"entry"]=Catalog.ENTRY; traversal_points[&"exit"]=Catalog.EXIT
	traversal_points[&"return"]=Vector2(640,640)
	if floor_data["secret"]!=Vector2.ZERO: traversal_points[&"high_link"]=floor_data["secret"]
	_skin_surfaces(palette)
	door=_block(Vector2(1190,360),Vector2(24,720),palette.lightened(.15))
	door.name="DepthSealDoor"; door_shape=door.get_node("Shape") as CollisionShape2D
	arrow=Label.new(); arrow.set_meta(&"debug_keep",true); arrow.position=Vector2(990,586); arrow.size=Vector2(190,42)
	arrow.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	arrow.add_theme_font_size_override("font_size",16); add_child(arrow)
	set_locked(true)
func _build_background(palette: Color) -> void:
	fallback=Polygon2D.new(); fallback.name="DepthPaletteFallback"; fallback.z_index=-40
	fallback.polygon=PackedVector2Array([Vector2.ZERO,Vector2(1280,0),Vector2(1280,720),Vector2(0,720)])
	fallback.color=palette.darkened(.75); add_child(fallback)
	# Cosmetic pillars are rooted at y640 and never enter the collision tree.
	for x: float in [70.0,400.0,780.0,1135.0]:
		var pillar:=Polygon2D.new(); pillar.z_index=-30
		pillar.polygon=PackedVector2Array([Vector2(x-18,640),Vector2(x-18,240),Vector2(x+18,240),Vector2(x+18,640)])
		pillar.color=palette.darkened(.6); add_child(pillar)
	bind_raster()
func bind_raster() -> bool:
	var path: String=Catalog.background_path(room_number)
	if not ResourceLoader.exists(path): return false
	var texture: Texture2D=load(path) as Texture2D
	if texture==null or texture.get_width()<=0 or texture.get_height()<=0: return false
	if background==null:
		background=Sprite2D.new(); background.name="DepthRasterBackground"; background.z_index=-25
		background.position=Vector2(640,360); background.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(background)
	background.texture=texture
	var scale_factor: float=maxf(1280.0/texture.get_width(),720.0/texture.get_height())
	background.scale=Vector2.ONE*scale_factor
	raster_bound=true
	return true
func _skin_surfaces(palette: Color) -> void:
	terrain_art=TerrainScript.new(); terrain_art.name="DepthTerrainArt"; add_child(terrain_art)
	terrain_art.rebuild(surfaces,room_number,palette)
func set_locked(value: bool) -> void:
	locked=value
	if is_instance_valid(door_shape): door_shape.set_deferred("disabled",not value)
	if is_instance_valid(door): door.visible=value
	if is_instance_valid(arrow): arrow.text="PHONG ẤN · DỌN ĐỊCH" if value else "E · TẦNG KẾ →" if room_number<Catalog.FLOOR_COUNT else "E · TRỞ VỀ SẢNH →"

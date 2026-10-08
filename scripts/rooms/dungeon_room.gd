class_name DungeonRoom
extends Node2D
## Room geometry and lock own their Nodes; the run owns the persistent Player.

@export var room_number: int = 1
var locked: bool = true
var door: StaticBody2D
var door_shape: CollisionShape2D
var arrow: Label
var traversal_points: Dictionary[StringName,Vector2] = {}
var architecture: DungeonArchitecture


func _ready() -> void:
	_block(Vector2(640, 680), Vector2(1280, 80), Color(0.16, 0.23, 0.29))
	_block(Vector2(16, 360), Vector2(32, 720), Color(0.1, 0.14, 0.19))
	_block(Vector2(1264, 360), Vector2(32, 720), Color(0.1, 0.14, 0.19))
	if room_number < 3:
		# Combat spine stays at y=640. Entry steps are peripheral, and gallery
		# undersides are above the tallest ground actor instead of 70px overhead.
		# Meet the west boundary: the old 18px gap trapped the 20px capsule
		# between the wall and the stair corner after walking off or knockback.
		_shelf(&"WestStair",Rect2(32,534,98,12),true)
		_shelf(&"WestGallery",Rect2(180,444,290 if room_number==1 else 360,16),true)
		_shelf(&"SecretAlcove",Rect2(32,366,300,16),false)
		_shelf(&"SecretRoof",Rect2(32,219,148,16),false)
		_shelf(&"EastStair",Rect2(1092,534,84,12),true)
		_shelf(&"EastGallery",Rect2(790 if room_number==1 else 740,444,330 if room_number==1 else 380,16),true)
		traversal_points = {&"west_stair":Vector2(90,534),&"west_gallery":Vector2(250,444),&"secret_takeoff":Vector2(400,444),&"secret":Vector2(90,366),&"east_stair":Vector2(1130,534),&"east_gallery":Vector2(990,444),&"return":Vector2(640,640)}
		var wall := EnvironmentBarrier.new()
		wall.position = Vector2(164, 300)
		wall.size = Vector2(24, 130)
		add_child(wall)
	door = _block(Vector2(1190, 360), Vector2(24, 720), Color(0.65, 0.22, 0.22))
	door_shape = door.get_node("Shape") as CollisionShape2D
	arrow = Label.new()
	arrow.position = Vector2(1040, 340)
	arrow.add_theme_font_size_override("font_size", 24)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arrow)
	set_locked(true)
	architecture = DungeonArchitecture.new()
	add_child(architecture)
	architecture.initialize(self)

func _shelf(id: StringName, rectangle: Rect2, one_way: bool) -> void:
	var body: StaticBody2D = _block(rectangle.get_center(),rectangle.size,Color("61736e"))
	body.name = String(id)
	body.set_meta(&"dungeon_architectural_surface",true)
	var collider := body.get_node("Shape") as CollisionShape2D
	collider.one_way_collision = one_way
	collider.one_way_collision_margin = 4.0


func set_locked(value: bool) -> void:
	locked = value
	door_shape.set_deferred("disabled", not value)
	door.visible = value
	arrow.text = "CỬA KHÓA" if value else "PHÒNG KẾ →" if room_number < 3 else "CỔNG ĐÃ MỞ →"


func _block(center: Vector2, size: Vector2, color: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	# Run.finish disables room gameplay, but the sibling Player still settles its
	# corpse through the motor. Keep static terrain in physics during that pause.
	body.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.name = "Shape"
	collider.shape = shape
	body.add_child(collider)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([-size * 0.5, Vector2(size.x, -size.y) * 0.5, size * 0.5, Vector2(-size.x, size.y) * 0.5])
	visual.color = color
	body.add_child(visual)
	add_child(body)
	return body

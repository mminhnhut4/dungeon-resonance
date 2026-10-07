class_name TraversalLabRoom
extends Node2D
## QA geometry uses the unchanged motor's common 60/120 Hz envelope.
const IDS: Array[StringName] = [&"qa_traversal_lab_01", &"qa_traversal_lab_02", &"qa_traversal_lab_03"]
const H: float = 115.0
const U: float = 229.0
const SAFE_ANGLE: float = 10.0
var room_id: StringName
var width: float
var surface: PackedVector2Array
var anchors: Dictionary[StringName, Vector2] = {}
var marks: Dictionary[StringName, Vector2] = {}
var gate: StaticBody2D
var gate_visual: Polygon2D
var gate_open: bool = false

func configure(id: StringName, opened: bool) -> bool:
	if id not in IDS: return false
	room_id = id
	gate_open = opened
	name = String(id).to_pascal_case()
	match id:
		IDS[0]:
			width = 2600.0
			surface = PackedVector2Array([Vector2(0,640),Vector2(320,640),Vector2(620,588.25),Vector2(960,588.25),Vector2(1260,640),Vector2(width,640)])
		IDS[1]:
			width = 2400.0
			surface = PackedVector2Array([Vector2(0,640),Vector2(320,640),Vector2(650,582.5),Vector2(1160,582.5),Vector2(1490,640),Vector2(width,640)])
		IDS[2]:
			width = 2000.0
			surface = PackedVector2Array([Vector2(0,640),Vector2(300,640),Vector2(760,560),Vector2(1240,560),Vector2(1700,640),Vector2(width,640)])
	anchors = {&"west": Vector2(150,640), &"east": Vector2(width - 150,640)}
	marks = {&"door_west": Vector2(90,640), &"door_east": Vector2(width - 90,640)}
	var tint := Color("505f67") if id != IDS[2] else Color("465d67")
	_art_rect(Rect2(-1200,-700,width+2400,2400), tint.darkened(0.55), -20)
	for x: float in range(-400, int(width) + 600, 360):
		_art(PackedVector2Array([Vector2(x,650),Vector2(x+240,80),Vector2(x+520,650)]), tint.darkened(0.25), -18)
	var collision_points: PackedVector2Array = surface.duplicate()
	for index: int in range(surface.size()-1,-1,-1): collision_points.append(surface[index] + Vector2(0,60))
	_solid(collision_points, Color("877e62"))
	var route := Line2D.new()
	route.points = surface
	route.width = 3
	route.default_color = Color("edc767")
	add_child(route)
	for id_mark: StringName in marks:
		_sign(marks[id_mark], "E · Cửa QA ←" if id_mark == &"door_west" else "E · Cửa QA →")
	if id == IDS[0]:
		# Optional jump has a 70 px edge gap, +40 px rise, 110 px landing.
		# Conservative standing E(+0.35H) = 164 px, so gap < 0.55E.
		_solid(_rectangle(Rect2(1620,590,110,8)), Color("b0a183"))
		_solid(_rectangle(Rect2(1800,550,110,8)), Color("b0a183"))
		_sign(Vector2(1680,590), "J · Bệ 1 / nền bắt rơi")
		_sign(Vector2(1855,550), "J · +40 px / hở 70 px")
		_sign(Vector2(790,588.25), "LAB01 · ±0.45H · W liên tục")
	elif id == IDS[1]:
		marks[&"gate_lever"] = Vector2(1980,640)
		gate = _solid(_rectangle(Rect2(1740,500,20,140)), Color("699e87"))
		gate_visual = gate.get_child(1) as Polygon2D
		set_gate(opened)
		_sign(Vector2(790,582.5), "LAB02 · 0.50H / dốc hai chiều")
		_sign(Vector2(1980,640), "E · Mở cổng QA từ phía xa")
		_sign(Vector2(1600,640), "Bản cua gấp đặc: chưa đạt, xem diagnostic")
	else:
		anchors[&"checkpoint"] = Vector2(1000,560)
		marks[&"checkpoint"] = anchors[&"checkpoint"]
		_art_rect(Rect2(500,795,1000,15), Color("7c7670"), -13)
		_art_rect(Rect2(-200,735,width+400,400), Color(0.15,0.46,0.60,0.8), -12)
		_art_rect(Rect2(670,500,12,330), Color("b2b7a5"), -10)
		_art_rect(Rect2(655,735,42,4), Color("73d2e0"), -9)
		_art_rect(Rect2(655,626,42,4), Color("bcbc98"), -9)
		_sign(Vector2(1000,560), "E · Mốc khô QA / không hồi, không bank")
		_sign(Vector2(685,560), "Vạch nước hiện tại / dấu lũ cũ")
		_sign(Vector2(1360,640), "Phố thấp ở dưới nước · không bơi")
	return true

func floor_y(x: float) -> float:
	for index: int in surface.size() - 1:
		var a: Vector2 = surface[index]
		var b: Vector2 = surface[index+1]
		if x >= a.x and x <= b.x: return lerpf(a.y,b.y,(x-a.x)/(b.x-a.x))
	return NAN

func valid_anchor(id: StringName) -> bool:
	if not anchors.has(id): return false
	var point: Vector2 = anchors[id]
	return point.x >= 120 and point.x <= width - 120 and absf(point.y - floor_y(point.x)) < 0.1 and absf(floor_y(point.x-50)-floor_y(point.x+50)) < 0.1

func set_gate(opened: bool) -> void:
	gate_open = opened
	if gate == null: return
	gate.collision_layer = 0 if opened else 1
	gate.collision_mask = 0 if opened else 1
	gate_visual.visible = not opened

func _solid(points: PackedVector2Array, color: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	shape.one_way_collision = false
	body.add_child(shape)
	var art := Polygon2D.new()
	art.polygon = points
	art.color = color
	body.add_child(art)
	add_child(body)
	return body

func _art(points: PackedVector2Array, color: Color, order: int) -> void:
	var art := Polygon2D.new()
	art.polygon = points
	art.color = color
	art.z_index = order
	add_child(art)

func _art_rect(rect: Rect2, color: Color, order: int) -> void:
	_art(_rectangle(rect),color,order)

func _rectangle(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

func _sign(point: Vector2, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.position = point + Vector2(-120,-95)
	label.add_theme_color_override("font_color", Color("efeddd"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta(&"debug_keep", true)
	add_child(label)

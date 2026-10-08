class_name ExteriorRoom
extends Node2D
## Solid authored heightfield; optional shelves have a walkable catch floor.
var room_id: StringName
var route_id: StringName
var width: float
var surface: PackedVector2Array
var anchors: Dictionary[StringName,Vector2] = {}
var interactions: Dictionary[StringName,Vector2] = {}
var jumps: Array[Dictionary] = []
var gate: StaticBody2D
var gate_visual: Polygon2D
var gate_open: bool
var min_y: float
var bounds: Rect2
const ROUTE_PRESENTATION: Script = preload("res://scripts/presentation/pilgrimage_route_presentation.gd")

func configure(id: StringName, route: StringName, opened: bool) -> bool:
	var spec: Dictionary = ExteriorRouteCatalog.layout(id,route)
	if spec.is_empty(): return false
	room_id = id
	route_id = route
	gate_open = opened
	name = String(id).to_pascal_case()+ ("Tunnel" if route == ExteriorRouteCatalog.TUNNEL else "")
	var cursor := Vector2(0,_y(float(spec["start"])))
	surface.append(cursor)
	for beat: Vector2 in spec["beats"]:
		var y: float = _y(beat.y)
		var run: float = maxf(beat.x,absf(y-cursor.y)/tan(deg_to_rad(ExteriorRouteCatalog.SAFE_ANGLE))+0.5) if y != cursor.y else beat.x
		cursor = Vector2(cursor.x+run,y)
		surface.append(cursor)
	width = cursor.x
	anchors = {&"west":Vector2(150,surface[0].y),&"east":Vector2(width-150,cursor.y)}
	interactions = {&"door_west":Vector2(90,surface[0].y)}
	if not ExteriorRouteCatalog.link(id,route,&"door_east").is_empty(): interactions[&"door_east"] = Vector2(width-90,cursor.y)
	min_y = surface[0].y
	for point: Vector2 in surface: min_y = minf(min_y,point.y)
	bounds = Rect2(0,min_y-340,width,maxf(2400,min_y+600)-(min_y-340))
	_background()
	var collision_points: PackedVector2Array = surface.duplicate()
	for index: int in range(surface.size()-1,-1,-1): collision_points.append(surface[index]+Vector2(0,70))
	_solid(collision_points,Color("86775a") if ExteriorRouteCatalog.region(id) == &"o01_duong_hanh_huong" else Color("727c77"))
	var line := Line2D.new()
	line.points = surface
	line.width = 3
	line.default_color = Color("e8c46e")
	add_child(line)
	_wall(-20)
	_wall(width+20)
	if route == ExteriorRouteCatalog.TUNNEL:
		gate = _solid(_rect(Rect2(640,surface[0].y-130,20,130)),Color("65a088"))
		gate_visual = gate.get_child(1) as Polygon2D
		set_gate(opened)
		_sign(Vector2(580,surface[0].y),"SC01 · Cổng đường giữ đèn")
		_sign(Vector2(1110,floor_y(1110)),"Hành lang có nền / ramp thật")
	else:
		_author_details()
		SectJourney.author_room(self)
	for key: StringName in interactions:
		if key in [&"door_west",&"door_east"]: _door(interactions[key],"← Lối về" if key == &"door_west" else "Đi tiếp →")
	if room_id == &"o01_p01" and route_id == ExteriorRouteCatalog.MAIN:
		var art := PilgrimagePresentation.new()
		add_child(art)
		art.initialize(self)
	elif room_id == &"o01_p02" and route_id in [ExteriorRouteCatalog.MAIN, ExteriorRouteCatalog.TUNNEL]:
		var art: Node2D = ROUTE_PRESENTATION.new()
		add_child(art)
		art.initialize(self)
	if room_id in SectRouteCatalog.ROOMS:
		var lowest: float=surface[0].y
		for point: Vector2 in surface: lowest=maxf(lowest,point.y)
		bounds=Rect2(0,min_y-540,width,maxf(960,lowest-min_y+900))
		SectRoomArt.attach(self)
	else: preload("res://scripts/presentation/existing_map_raster.gd").attach_exterior(self)
	return true

func _author_details() -> void:
	match room_id:
		&"o01_p01":
			_tunnel_entrance()
			_branch(3,0.35,"J1 · Điểm nhìn cao")
			_sign(Vector2(760,floor_y(760)),"Đèn nghiêng · Bậc đá vỡ")
			_lamp(Vector2(980,floor_y(980)))
		&"o01_p02":
			_branch(3,0.4,"J2 · Vai núi phía trên")
			var bridge_x: float = surface[4].x
			for x: float in [bridge_x+20,bridge_x+330]:
				_art(_rect(Rect2(x,surface[4].y-55,8,85)),Color("a59776"),1)
			var rope := Line2D.new()
			rope.points = PackedVector2Array([Vector2(bridge_x+20,surface[4].y-45),Vector2(bridge_x+180,surface[4].y-35),Vector2(bridge_x+330,surface[4].y-45)])
			rope.default_color = Color("b8aa83")
			rope.width = 3
			add_child(rope)
			_sign(Vector2(bridge_x+160,surface[4].y),"Cầu dây cố định",true)
		&"o01_p03":
			_tunnel_entrance()
			interactions[&"sc01_lever"] = Vector2(1450,floor_y(1450))
			interactions[&"shrine"] = Vector2(1660,floor_y(1660))
			anchors[&"shrine"] = interactions[&"shrine"]
			_art(_rect(Rect2(1280,floor_y(1280)-110,440,110)),Color("655d51"),-1)
			_sign(interactions[&"sc01_lever"],"E · Cơ cấu đường giữ đèn",true)
			_sign(interactions[&"shrine"],"E · Miếu đèn / mốc địa lý",true)
			_lamp(Vector2(1550,floor_y(1550)))
		&"o01_p04":
			var terrace_number: int = 0
			for index: int in [4,8,10]:
				terrace_number += 1
				var point: Vector2 = surface[index]
				_sign(point+Vector2(120,0),"Terrace %d · Đường khô hai chiều" % terrace_number)
			var catch_pad: Vector2 = surface[6]+Vector2(18,0)
			jumps.append({"takeoff":surface[5]+Vector2(-15,0),"landing":catch_pad,"delta_z":surface[5].y-catch_pad.y,"edge_gap":0.0})
			_sign(catch_pad,"J · Cắt dốc / bệ bắt rơi nhìn thấy")
			_sign(Vector2(760,floor_y(760)),"Vai đất cao · Xuống bến")
		&"o02_b01":
			interactions[&"water"] = Vector2(1010,floor_y(1010))
			anchors[&"water"] = interactions[&"water"]
			interactions[&"water_record"] = Vector2(1200,floor_y(1200))
			_art(_rect(Rect2(880,_y(1.6)-80,12,280)),Color("b2b5a0"),-2)
			for z: float in [0.15,1.1]: _art(_rect(Rect2(862,_y(z),48,4)),Color("7ddce1") if z < 1 else Color("dfc988"),-1)
			_sign(interactions[&"water"],"E · Cột nước / mốc khô")
			_sign(interactions[&"water_record"],"E · Đọc dấu lũ")
		&"o02_b02":
			_branch(3,0.4,"Mái nhà · Điểm nhìn phố thấp")
			_sign(Vector2(930,floor_y(930)),"Quảng trường cao · Lối bưu trạm →")
			_art(_rect(Rect2(600,ExteriorRouteCatalog.BASE_Y,800,18)),Color("9b9186"),-13)
		&"o02_b03":
			interactions[&"post_record"] = Vector2(1510,floor_y(1510))
			_art(PackedVector2Array([Vector2(1260,floor_y(1260)-150),Vector2(1480,floor_y(1480)-215),Vector2(1750,floor_y(1750)-150)]),Color("6c594d"),-1)
			_sign(interactions[&"post_record"],"E · Hồ sơ bưu trạm cũ")
			_sign(Vector2(2910,floor_y(2910)),"Kho bên kênh")
		&"o02_b04":
			interactions[&"hanh"] = Vector2(730,floor_y(730))
			interactions[&"shipyard_record"] = Vector2(980,floor_y(980))
			anchors[&"shipyard"] = Vector2(600,floor_y(600))
			var hanh := HubNpc.new()
			hanh.npc_id = &"hanh"
			hanh.preview_tint = Color("b59c76")
			hanh.position = interactions[&"hanh"]
			add_child(hanh)
			_sign(interactions[&"hanh"],"E · Hạnh / thợ đóng thuyền")
			_sign(interactions[&"shipyard_record"],"E · Ghi chép xưởng")
			_art(_rect(Rect2(1160,_y(1.3)-220,14,240)),Color("9e9982"),-1)
			_art(_rect(Rect2(1130,_y(1.3)-220,250,12)),Color("9e9982"),-1)
			_art(PackedVector2Array([Vector2(1400,_y(0)-30),Vector2(1780,_y(0)-30),Vector2(1710,_y(0)+30),Vector2(1460,_y(0)+30)]),Color("766447"),-11)
			_sign(Vector2(width-350,surface[-1].y),"Cầu tàu khô · Chưa mở đường thuyền")

func _tunnel_entrance() -> void:
	interactions[&"tunnel"] = Vector2(320,surface[0].y)
	anchors[&"tunnel"] = Vector2(340,surface[0].y)
	_door(interactions[&"tunnel"],"E · Hầm đường giữ đèn")

func _branch(plateau_end_index: int, rise_h: float, caption: String) -> void:
	var takeoff: Vector2 = surface[plateau_end_index]
	var lift: float = rise_h*ExteriorRouteCatalog.H
	var first := Vector2(takeoff.x+110,takeoff.y-lift)
	var second := first+Vector2(180,-lift)
	_solid(_rect(Rect2(first,Vector2(110,8))),Color("b3a383"))
	_solid(_rect(Rect2(second,Vector2(110,8))),Color("b3a383"))
	jumps.append({"takeoff":takeoff+Vector2(-15,0),"landing":first+Vector2(55,0),"delta_z":lift,"edge_gap":110.0})
	jumps.append({"takeoff":first+Vector2(95,0),"landing":second+Vector2(55,0),"delta_z":lift,"edge_gap":70.0})
	min_y = minf(min_y,second.y)
	bounds.position.y = min_y-340
	bounds.size.y = 2400-bounds.position.y
	_sign(second+Vector2(55,0),caption)

func floor_y(x: float) -> float:
	for index: int in surface.size()-1:
		var a: Vector2 = surface[index]
		var b: Vector2 = surface[index+1]
		if x >= a.x and x <= b.x: return lerpf(a.y,b.y,(x-a.x)/(b.x-a.x))
	return NAN

func dry_anchor(id: StringName) -> bool:
	if not anchors.has(id): return false
	var point: Vector2 = anchors[id]
	return point.is_finite() and point.x >= 60 and point.x <= width-60 and absf(point.y-floor_y(point.x)) < 0.1 and absf(floor_y(point.x-60)-floor_y(point.x+60)) < 0.1

func set_gate(opened: bool) -> void:
	gate_open = opened
	if gate != null:
		gate.collision_layer = 0 if opened else 1
		gate.collision_mask = 0 if opened else 1
		gate_visual.visible = not opened

func _background() -> void:
	var town: bool = ExteriorRouteCatalog.region(room_id) == &"o02_ben_tram"
	_art(_rect(Rect2(-1300,bounds.position.y-600,width+2600,2200)),Color("26383d") if town else Color("252f32"),-20)
	for x: float in range(-600,int(width)+1000,500):
		_art(PackedVector2Array([Vector2(x,2250),Vector2(x+420,min_y-320),Vector2(x+900,2250)]),Color("3b4b4d") if town else Color("354144"),-18)
	if town or room_id == &"o01_p04":
		_art(_rect(Rect2(-400,_y(0.15),width+800,420)),Color(0.16,0.45,0.55,0.75),-12)
	if room_id == &"o01_p02": _art(_rect(Rect2(width*0.6,min_y-240,28,320)),Color("536263"),-16)

func _wall(x: float) -> void:
	_solid(_rect(Rect2(x-20,bounds.position.y,40,bounds.size.y)),Color(0,0,0,0))

func _door(point: Vector2, label: String) -> void:
	_art(_rect(Rect2(point+Vector2(-18,-72),Vector2(36,72))),Color("536c64"),-1)
	_sign(point,label)

func _lamp(point: Vector2) -> void:
	_art(_rect(Rect2(point+Vector2(-3,-90),Vector2(6,90))),Color("a49a74"),1)
	_art(_rect(Rect2(point+Vector2(-11,-90),Vector2(22,16))),Color("d6bb65"),2)

func _solid(points: PackedVector2Array, color: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	var collider := CollisionPolygon2D.new()
	collider.polygon = points
	collider.one_way_collision = false
	body.add_child(collider)
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

func _sign(point: Vector2, caption: String, beside_npc: bool = false) -> void:
	var label := Label.new()
	label.text = caption
	label.position = point+Vector2(-100,-95)
	# Keep these scene signs above resident captions; actors/anchors stay fixed.
	if beside_npc:
		label.position.y -= 75.0
		label.size = Vector2(200,50)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta(&"debug_keep",true)
	add_child(label)

func _rect(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

func _y(z: float) -> float:
	return ExteriorRouteCatalog.BASE_Y-z*ExteriorRouteCatalog.H

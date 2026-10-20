class_name TanDangHomeArt
extends Node2D
## Room-owned scenery only: the walkable floor and officers remain separate owners.
const INK: Color = Color("263532")
const STONE: Color = Color("606e65")
const TIMBER: Color = Color("695442")
const GOLD: Color = Color("d5b66d")

static func attach(room: Node2D) -> Node2D:
	var existing := room.get_node_or_null("TanDangHomeArt") as Node2D
	if existing != null: return existing
	# The caller preloads this script. Its cached resource can instantiate here
	# without requiring this new class name in a copied global-class cache.
	var art: Node2D = (load("res://scripts/presentation/tan_dang_home_art.gd") as Script).new()
	art.name = "TanDangHomeArt"
	art.position.y = float(room.call("floor_y",0.0))
	art.z_index = -4
	room.add_child(art)
	art.call("_title","GateTitle","SƠN MÔN",Vector2(280,-315),280)
	art.call("_title","CourtTitle","SÂN ĐÈN · PHÓ TÔNG CHỦ",Vector2(760,-260),420)
	art.call("_title","HallTitle","CHÍNH ĐIỆN · TÀN ĐĂNG MÔN",Vector2(1630,-380),620)
	return art

func _draw() -> void:
	# Quiet enclosing wall and paving unify all three areas into one walkable room.
	draw_rect(Rect2(0,-205,2200,205),Color("394b44"))
	draw_rect(Rect2(0,-213,2200,9),STONE)
	draw_rect(Rect2(0,-18,2200,18),Color("a19475"))
	for x: int in range(0,2200,160):
		draw_line(Vector2(x,-18),Vector2(x+28,0),Color("706c58"),2)
	_gate()
	_court()
	_hall()
	for x: float in [170.0,430.0,1050.0,1280.0,1940.0]:
		_lantern(Vector2(x,-25))

func _gate() -> void:
	# Open arch: no decorative door slab suggests an inaccessible collision wall.
	for x: float in [170.0,390.0]:
		draw_rect(Rect2(x,-260,30,260),TIMBER)
		draw_rect(Rect2(x-7,-20,44,20),STONE)
	draw_rect(Rect2(160,-270,270,22),GOLD.darkened(.45))
	draw_colored_polygon(PackedVector2Array([Vector2(115,-269),Vector2(185,-294),Vector2(390,-294),Vector2(460,-269),Vector2(420,-251),Vector2(155,-251)]),INK)
	draw_line(Vector2(119,-269),Vector2(455,-269),GOLD,3)

func _court() -> void:
	# Low council bench, notice stand and a single banner distinguish the deputy's court.
	draw_rect(Rect2(555,-74,410,12),STONE)
	for x: float in [580.0,910.0]: draw_rect(Rect2(x,-62,14,62),STONE.darkened(.15))
	draw_rect(Rect2(880,-180,7,180),TIMBER)
	draw_rect(Rect2(884,-178,96,88),Color("8b704b"))
	draw_line(Vector2(900,-158),Vector2(958,-158),GOLD,3)
	draw_line(Vector2(900,-141),Vector2(945,-141),GOLD.darkened(.2),3)
	draw_line(Vector2(900,-124),Vector2(951,-124),GOLD.darkened(.2),3)
	draw_rect(Rect2(540,-232,5,232),TIMBER)
	draw_colored_polygon(PackedVector2Array([Vector2(545,-230),Vector2(595,-230),Vector2(595,-155),Vector2(570,-172),Vector2(545,-155)]),Color("9a673e"))
	draw_circle(Vector2(570,-208),9,GOLD)

func _hall() -> void:
	draw_rect(Rect2(1230,-295,780,295),Color("45584d"))
	draw_rect(Rect2(1260,-265,720,245),Color("526454"))
	draw_rect(Rect2(1450,-250,330,250),INK)
	for x: float in [1280.0,1400.0,1800.0,1920.0]:
		draw_rect(Rect2(x,-280,24,280),TIMBER)
		draw_rect(Rect2(x-5,-30,34,30),STONE)
	draw_rect(Rect2(1240,-305,760,22),GOLD.darkened(.5))
	draw_colored_polygon(PackedVector2Array([Vector2(1160,-302),Vector2(1310,-352),Vector2(1930,-352),Vector2(2075,-302),Vector2(2005,-282),Vector2(1230,-282)]),INK)
	draw_line(Vector2(1165,-302),Vector2(2070,-302),GOLD,4)
	draw_rect(Rect2(1505,-286,220,55),Color("6f5138"))
	draw_line(Vector2(1525,-265),Vector2(1705,-265),GOLD,3)
	for x: float in [1330.0,1860.0]:
		draw_rect(Rect2(x,-210,58,110),INK)
		for bar: int in 3: draw_line(Vector2(x+12+bar*16,-208),Vector2(x+12+bar*16,-102),STONE,3)

func _lantern(at: Vector2) -> void:
	draw_rect(Rect2(at+Vector2(-4,-118),Vector2(8,118)),TIMBER)
	draw_circle(at+Vector2(0,-104),25,Color(0.88,0.64,0.24,.08))
	draw_rect(Rect2(at+Vector2(-11,-115),Vector2(22,29)),GOLD)
	draw_rect(Rect2(at+Vector2(-15,-119),Vector2(30,5)),INK)
	draw_line(at+Vector2(0,-84),at+Vector2(0,-76),GOLD,2)

func _title(node_name: String, caption: String, center: Vector2, width: float) -> void:
	var label := Label.new()
	label.name = node_name
	label.text = caption
	label.position = center-Vector2(width/2,15)
	label.size = Vector2(width,30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color",GOLD)
	label.add_theme_color_override("font_shadow_color",Color("14221e"))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.add_theme_font_size_override("font_size",20)
	add_child(label)

class_name MemberDungeonAtmosphere
extends Node2D
## Bounded background-only canvas VFX; hazard tells remain on their own z4 layer.
const THEMES: Dictionary={9:"echo",10:"forge",11:"roots",12:"archive",13:"mist",14:"water",15:"archive",16:"souls",17:"echo",18:"bell",19:"dust",20:"rain",21:"forge",22:"roots",23:"dust",24:"runes",25:"water",26:"bell",27:"forge",28:"runes",29:"rain",30:"echo"}
var floor_number: int=9
var room_width: float=1280
var palette:=Color("697b9d")
var age: float=0
var theme: String
var particle_budget: int=12
var motif: String
func _ready() -> void:
	z_index=-12;theme=THEMES.get(floor_number,"dust");motif=MemberFloorArtCatalog.definition(floor_number)["motif"]
func _process(delta: float) -> void:age+=delta;queue_redraw()
func _draw() -> void:
	var ink: Color=palette.lightened(.45);ink.a=.24
	_architecture()
	# Authored background architecture; no collisions or actor transforms.
	for index: int in 6:
		var x: float=(index+.5)*room_width/6
		var top: float=180+(index%3)*28
		draw_line(Vector2(x,top),Vector2(x,640),Color(palette.darkened(.35),.4),11)
		draw_line(Vector2(x-25,top),Vector2(x+25,top),ink,3)
	if theme in ["echo","bell"]:
		for index: int in 3:
			var center:=Vector2(room_width*(index+1)/4,300)
			draw_arc(center,58+sin(age*.9+index)*8,0,TAU,40,ink,2)
			draw_arc(center,36,0,TAU,32,Color(ink,.16),1)
	if theme=="roots":
		for index: int in 8:
			var x: float=(index+.5)*room_width/8
			var points:=PackedVector2Array([Vector2(x,80),Vector2(x-18,160),Vector2(x+10,240),Vector2(x-25,330)])
			draw_polyline(points,Color("274237"),5)
	if theme in ["archive","runes"]:
		for index: int in 8:
			var center:=Vector2((index+.5)*room_width/8,270+(index%2)*100)
			draw_rect(Rect2(center-Vector2(15,24),Vector2(30,48)),Color(ink,.18),false,2)
			draw_line(center-Vector2(7,14),center+Vector2(5,13),ink,2)
	if theme=="water":
		for index: int in 5:
			var y: float=693+index*9
			draw_line(Vector2(fposmod(age*20+index*57,140)-140,y),Vector2(room_width,y),Color(.3,.64,.7,.1),2)
	for index: int in particle_budget:
		var x: float=fposmod(index*173.3+age*(5+index%4),room_width)
		var y: float=210+fposmod(index*79.1-age*(8+index%3),350)
		var color: Color=ink
		if theme=="forge":color=Color(.97,.48,.16,.32 if floor_number!=10 else .05)
		elif theme=="souls":color=Color(.61,.78,.9,.28)
		elif theme=="roots":color=Color(.61,.87,.53,.26)
		if theme=="rain":draw_line(Vector2(x,y),Vector2(x-4,y+18),Color(.63,.77,.9,.16),1)
		else:draw_circle(Vector2(x,y),1.3 if theme=="forge" else 1.8,color)
func _glyph(p: Vector2,s: float,c: Color) -> void:
	draw_rect(Rect2(p-Vector2(s*.45,s*.7),Vector2(s*.9,s*1.4)),Color(c,.12))
	draw_line(p+Vector2(-s*.25,-s*.45),p+Vector2(s*.28,s*.42),c,2)
	draw_line(p-Vector2(s*.3,0),p+Vector2(s*.3,0),c,2)
	draw_line(p-Vector2(0,s*.48),p+Vector2(0,s*.55),c,1)
func _bell(p: Vector2,s: float,c: Color) -> void:
	draw_line(p-Vector2(0,115),p-Vector2(0,s),c.darkened(.3),3)
	draw_arc(p,s,PI,TAU,24,c,4);draw_line(p-Vector2(s,0),p+Vector2(s,0),c,5);draw_circle(p+Vector2(0,5),4,c)
func _architecture() -> void:
	var ink:=Color(MemberFloorArtCatalog.definition(floor_number)["tint"]);ink.a=.36
	var dark:=Color(.035,.05,.065,.5)
	match floor_number:
		9:
			for i: int in 5:draw_arc(Vector2(room_width*.52,480-i*73),90+i*14,0,TAU,48,Color(ink,.18),3)
		10,21:
			for i: int in 5:
				var x: float=(i+.5)*room_width/5
				draw_polyline(PackedVector2Array([Vector2(x-70,580),Vector2(x-70,230),Vector2(x+20,230),Vector2(x+20,120)]),dark,18)
				draw_arc(Vector2(x,490),70,PI,TAU,24,ink,6)
				if floor_number==21:draw_arc(Vector2(x,490),58,PI,TAU,24,Color(1,.34,.08,.18+.08*sin(age*2+i)),7)
		11,22:
			for i: int in 9:
				var x: float=(i+.5)*room_width/9
				draw_polyline(PackedVector2Array([Vector2(x,40),Vector2(x-20,180),Vector2(x+20,280),Vector2(x-35,480)]),dark,9)
				for j: int in 4:
					var p:=Vector2(x-15+j%2*35,170+j*70)
					draw_line(p,p+Vector2(-30 if j%2==0 else 30,-26),ink,3)
					if floor_number==11:draw_circle(p,5,Color(.45,.9,.6,.22))
		12,15:
			for i: int in 7:
				var x: float=(i+.5)*room_width/7
				draw_rect(Rect2(x-48,210,96,295),dark)
				for j: int in 4:
					draw_line(Vector2(x-46,230+j*70),Vector2(x+46,230+j*70),ink,3)
					_glyph(Vector2(x+(j%2*30-15),260+j*65),18 if floor_number==12 else 25,ink)
		13:
			for i: int in 9:
				var x: float=(i+.5)*room_width/9
				draw_arc(Vector2(x,470),room_width/20,PI,TAU,18,ink,6)
				draw_line(Vector2(x-room_width/20,470),Vector2(x-room_width/20,610),dark,12)
		14:
			for i: int in 4:
				var c:=Vector2((i+.5)*room_width/4,410)
				draw_rect(Rect2(c-Vector2(76,200),Vector2(152,380)),dark);draw_arc(c,64,0,TAU,32,ink,5)
				for j: int in 8:draw_line(c,c+Vector2.from_angle(j*TAU/8+age*.08)*62,ink,3)
		16:
			for i: int in 8:
				var p:=Vector2((i+.5)*room_width/8,465+i%2*35)
				draw_rect(Rect2(p-Vector2(30,120),Vector2(60,140)),dark);_glyph(p-Vector2(0,70),24,ink)
		17:
			for i: int in 7:
				var c:=Vector2((i+.5)*room_width/7,280+i%2*75)
				draw_arc(c,52,0,TAU,32,ink,4);draw_arc(c,36,0,TAU,24,Color(ink,.2),3);draw_line(c+Vector2(0,52),c+Vector2(0,230),dark,12)
		18:
			_bell(Vector2(room_width*.5,350),110,ink)
		19:
			for i: int in 5:
				var x: float=(i+.5)*room_width/5
				draw_rect(Rect2(x-95,390,170,190),dark)
				draw_polyline(PackedVector2Array([Vector2(x-115,390),Vector2(x-30,315),Vector2(x+8,350),Vector2(x+45,330),Vector2(x+85,390)]),ink,7)
		20:
			draw_polyline(PackedVector2Array([Vector2(80,285),Vector2(room_width*.5,180),Vector2(room_width-80,285)]),dark,16)
			for x: float in [room_width*.2,room_width*.8]:draw_line(Vector2(x,260),Vector2(x,580),dark,12)
		23:
			for i: int in 7:
				var x: float=(i+.5)*room_width/7
				draw_line(Vector2(x,80),Vector2(x,200+i%3*60),ink,14);draw_line(Vector2(x-20,530),Vector2(x+15,365+i%2*55),dark,24)
		24:
			for i: int in 5:
				var c:=Vector2((i+.5)*room_width/5,360)
				draw_rect(Rect2(c-Vector2(65,150),Vector2(130,280)),dark);_glyph(c,60,ink);draw_arc(c,83,0,TAU,32,Color(ink,.15),2)
		25:
			for i: int in 9:draw_line(Vector2(fposmod(age*12+i*37,100)-100,470+i*15),Vector2(room_width,470+i*15),Color(.3,.58,.65,.17),2)
		26:
			for i: int in 5:
				var x: float=(i+.5)*room_width/5
				draw_polyline(PackedVector2Array([Vector2(x-85,580),Vector2(x-85,190),Vector2(x+85,190),Vector2(x+85,580)]),dark,14);_bell(Vector2(x,340),43,ink)
		27:
			for i: int in 6:
				var c:=Vector2((i+.5)*room_width/6,460)
				draw_arc(c,55,0,TAU,28,dark,22);draw_line(c-Vector2(38,55),c+Vector2(38,-55),ink,5);_glyph(c,25,Color(.9,.68,.36,.3))
		28:
			for i: int in 18:
				var p:=Vector2((i+.5)*room_width/18,200+i%3*85)
				draw_line(p-Vector2(0,90),p-Vector2(0,22),ink,1);_glyph(p+Vector2(sin(age+i)*2,0),24,ink)
		29:
			for i: int in 9:
				var p:=Vector2((i+.5)*room_width/9,570-i*36)
				draw_line(p-Vector2(50,0),p+Vector2(30,0),ink,10);draw_line(p-Vector2(40,0),p+Vector2(-30,70),dark,6)
		30:
			var c:=Vector2(room_width*.55,320)
			for i: int in 6:draw_arc(c,55+i*29,0,TAU,56,Color(ink,.24-i*.025),3)
			for i: int in 8:_glyph(c+Vector2.from_angle(i*TAU/8)*170,19,ink)

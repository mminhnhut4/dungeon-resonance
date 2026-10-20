class_name TanDangSealArt
extends RefCounted
## Bounded vector presentation, sought directly from the existing combat clock.
## No nodes, random particles, tweens, collision geometry or gameplay callbacks.

static func progress(phase: String, remaining: float, spec: Dictionary, window: int = 0) -> float:
	var duration: float = float(spec.get(phase,0.0))
	if phase == "tell" and window == 2: duration = float(spec.get("followup_tell",duration))
	return clampf(1.0-remaining/duration,0.0,1.0) if duration > 0.0 else 0.0

static func hands(phase: String, fraction: float, facing: float) -> PackedVector2Array:
	var t: float = smoothstep(0.0,1.0,clampf(fraction,0.0,1.0))
	var front := Vector2(14,-25)
	var back := Vector2(-12,-24)
	if phase == "tell":
		front = front.lerp(Vector2(20,-40),t)
		back = back.lerp(Vector2(16,-33),t)
	elif phase == "active":
		front = Vector2(24+3*sin(t*PI),-34)
		back = Vector2(19,-29)
	elif phase == "recover":
		front = Vector2(24,-34).lerp(front,t)
		back = Vector2(19,-29).lerp(back,t)
	front.x *= facing
	back.x *= facing
	return PackedVector2Array([front,back])

static func draw_keeper(canvas: CanvasItem, phase: String, fraction: float, facing: float) -> void:
	var cloth := Color("514a3c")
	var shadow := Color("282e2d")
	var trim := Color("b6a36b")
	var skin := Color("cba783")
	var pose: PackedVector2Array = hands(phase,fraction,facing)
	canvas.draw_set_transform(Vector2(0,-2),0,Vector2(1,0.25))
	canvas.draw_circle(Vector2.ZERO,15,Color(0.02,0.02,0.02,0.42))
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_line(Vector2(-5,-11),Vector2(-6,0),shadow,6,true)
	canvas.draw_line(Vector2(5,-11),Vector2(7,0),shadow,6,true)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-10,-39),Vector2(10,-39),Vector2(15,-7),Vector2(-15,-7)]),cloth)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-4,-38),Vector2(4,-38),Vector2(7,-8),Vector2(-5,-8)]),shadow)
	canvas.draw_polyline(PackedVector2Array([Vector2(-8,-38),Vector2(1,-27),Vector2(5,-9)]),trim,2,true)
	canvas.draw_line(Vector2(-12,-21),Vector2(12,-21),Color("8b633e"),4,true)
	canvas.draw_line(Vector2(5,-21),Vector2(8,-5),trim,3,true)
	# Sleeves and hands follow the read-only pose; the physical body stays still.
	for index: int in 2:
		var shoulder := Vector2((8 if index == 0 else -8)*facing,-35)
		var hand: Vector2 = pose[index]
		var normal: Vector2 = (hand-shoulder).orthogonal().normalized()*4.0
		canvas.draw_colored_polygon(PackedVector2Array([shoulder-normal,shoulder+normal,hand+normal*0.7,hand-normal*0.7]),cloth.lightened(0.08) if index == 0 else cloth.darkened(0.12))
		canvas.draw_line(hand-normal*0.7,hand+normal*0.7,trim,2,true)
		canvas.draw_circle(hand,2.8,skin)
	canvas.draw_circle(Vector2(0,-48),8,skin)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-8,-49),Vector2(-7,-55),Vector2(1,-58),Vector2(8,-53),Vector2(7,-49),Vector2(2,-53)]),shadow)
	canvas.draw_circle(Vector2(-2,-59),4,shadow)
	canvas.draw_line(Vector2(-7,-58),Vector2(5,-60),trim,1.6,true)
	canvas.draw_line(Vector2(2*facing,-49),Vector2(5*facing,-49),shadow,1.3,true)
	canvas.draw_line(Vector2(2*facing,-43),Vector2(5*facing,-42),Color("e0d1b6"),2,true)
	if phase in ["tell","active"]:
		var palm: Vector2 = pose[0]+Vector2(3*facing,-3)
		var size: float = 3.0+fraction*2.0 if phase == "tell" else 6.0
		canvas.draw_colored_polygon(PackedVector2Array([palm+Vector2(-size,-size),palm+Vector2(size,-size),palm+Vector2(size,size),palm+Vector2(-size,size)]),Color("f4d58b"))
		canvas.draw_line(palm-Vector2(0,size-1),palm+Vector2(0,size-1),Color("82552c"),1.5,true)

static func draw_seal(canvas: CanvasItem, target: Vector2, radius: float, phase: String, fraction: float, facing: float) -> void:
	var amber := Color("ffd17a")
	var ink := Color(0.07,0.05,0.03,0.9)
	if phase == "tell":
		# Outer boundary always matches the existing CircleShape2D radius.
		canvas.draw_circle(target,radius,Color(0.9,0.53,0.14,0.10))
		canvas.draw_arc(target,radius,0,TAU,48,ink,5,true)
		canvas.draw_arc(target,radius,0,TAU,48,amber,2,true)
		if fraction > 0.001: canvas.draw_arc(target,radius,-PI/2,-PI/2+TAU*fraction,48,Color("fff1bd"),4,true)
		canvas.draw_arc(target,radius*0.64,0,TAU,32,Color(amber,0.55),1,true)
		for index: int in 4:
			var axis := Vector2.RIGHT.rotated(index*PI/2)
			canvas.draw_line(target+axis*(radius-6),target+axis*(radius+3),ink,5,true)
			canvas.draw_line(target+axis*(radius-6),target+axis*(radius+3),amber,2,true)
		var origin: Vector2 = hands(phase,fraction,facing)[0]
		canvas.draw_line(origin,target,Color(amber,0.28),1,true)
		_sigil(canvas,target,8+fraction*4,Color(amber,0.65+fraction*0.3))
	elif phase == "active":
		canvas.draw_circle(target,radius,Color(1.0,0.65,0.18,0.35*(1.0-fraction*0.45)))
		canvas.draw_arc(target,radius,0,TAU,48,ink,6,true)
		canvas.draw_arc(target,radius,0,TAU,48,Color("fff0bb"),3,true)
		canvas.draw_line(target+Vector2(0,-radius+4),target+Vector2(0,radius-4),Color(amber,0.65),8,true)
		canvas.draw_line(target+Vector2(0,-radius+4),target+Vector2(0,radius-4),Color("fff7d6"),2,true)
		_sigil(canvas,target,16+fraction*6,Color("ffe4a1"))
		for index: int in 6:
			var direction := Vector2.RIGHT.rotated(index*TAU/6)
			canvas.draw_line(target+direction*(10+fraction*8),target+direction*(radius-4),Color(amber,1.0-fraction*0.5),2,true)
	elif phase == "recover" and fraction < 0.55:
		var fade: float = 1.0-fraction/0.55
		canvas.draw_arc(target,radius*0.76,0,TAU,32,Color(amber,fade*0.55),1,true)
		_sigil(canvas,target+Vector2(0,-fraction*12),10,Color(amber,fade*0.5))

static func _sigil(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	canvas.draw_polyline(PackedVector2Array([center+Vector2(0,-size),center+Vector2(size,0),center+Vector2(0,size),center+Vector2(-size,0),center+Vector2(0,-size)]),color,2,true)
	canvas.draw_line(center+Vector2(-size*0.45,0),center+Vector2(size*0.45,0),color,2,true)
	canvas.draw_line(center+Vector2(0,-size*0.55),center+Vector2(0,size*0.55),color,2,true)

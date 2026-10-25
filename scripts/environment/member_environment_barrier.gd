class_name MemberEnvironmentBarrier
extends EnvironmentBarrier
## Skin only. Parent owns the same collider, damage rules, reset and open puff.
func _draw() -> void:
	if is_open:return
	var r:=Rect2(-size*.5,size)
	if requires_fire:
		draw_rect(r,Color("17291c"))
		for i: int in 3:
			var x: float=-size.x*.35+i*size.x*.35
			var points:=PackedVector2Array()
			for j: int in 12:points.append(Vector2(x+sin(j*1.7+i)*size.x*.2,-size.y*.5+j*size.y/11))
			draw_polyline(points,Color("63763b"),3)
			for j: int in 6:
				var p:=Vector2(x,-size.y*.45+j*size.y/6)
				draw_line(p,p+Vector2(-7 if j%2==0 else 7,-9),Color("afad64"),2)
		# Warm seed identifies the fire-sensitive optional branch.
		draw_arc(Vector2(0,0),8,PI,TAU,12,Color("d89745"),2)
	else:
		draw_rect(r,Color("3a424a"))
		for j: int in maxi(1,ceili(size.y/24)):
			var y: float=-size.y*.5+j*24
			var h: float=minf(23,size.y-j*24)
			draw_rect(Rect2(-size.x*.5+1,y+1,size.x-2,h),Color("687074") if j%2==0 else Color("555f67"))
			draw_line(Vector2(-size.x*.5+2,y+2),Vector2(size.x*.5-2,y+2),Color("919487"),1)
			draw_line(Vector2(-3 if j%2==0 else 6,y),Vector2(-3 if j%2==0 else 6,y+h),Color("343c43"),2)
		var crack:=PackedVector2Array([Vector2(-3,-size.y*.48),Vector2(6,-size.y*.3),Vector2(-7,-size.y*.1),Vector2(3,size.y*.1),Vector2(-4,size.y*.33),Vector2(7,size.y*.47)])
		draw_polyline(crack,Color("101a22"),4)
		if hits>0:draw_polyline(crack,Color("d4bd87"),2)

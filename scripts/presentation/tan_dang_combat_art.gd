class_name TanDangCombatArt
extends RefCounted
## Finite draw commands, read from actual committed windows. No entities/clock.

static func draw_weapon(canvas: CanvasItem, pattern: String, phase: String, fraction: float, direction: Vector2, reach: float, height: float, window: int, tint: Color, displacement: Vector2) -> void:
	var center := Vector2(0,-26)
	var angle: float = direction.angle()
	var ink := Color(0.025,0.035,0.04,0.8)
	if phase == "tell":
		canvas.draw_line(center+direction*8.0,center+direction*reach,Color(tint,0.36),1.5,true)
		var normal: Vector2 = direction.orthogonal()*height*0.35
		canvas.draw_line(center+direction*reach-normal,center+direction*reach+normal,Color(tint,0.55),2.0,true)
		if pattern == "double_cut":
			var side: float = -1.0 if window == 2 else 1.0
			canvas.draw_arc(center,reach*0.72,angle-side*0.9,angle+side*0.5,20,Color(tint,0.35+fraction*0.4),2.0,true)
			for mark: int in clampi(window,1,2): canvas.draw_circle(center+Vector2(-9+mark*8,-26),2.5,Color(tint,0.85))
		else:
			var tip: Vector2 = center+direction*(reach-4.0)
			canvas.draw_line(tip-direction*11.0+direction.orthogonal()*5.0,tip,Color(tint,0.85),2.0,true)
			canvas.draw_line(tip-direction*11.0-direction.orthogonal()*5.0,tip,Color(tint,0.85),2.0,true)
	elif phase == "active":
		if pattern == "double_cut":
			var side: float = -1.0 if window == 2 else 1.0
			var sweep: float = angle+side*lerpf(-1.05,0.75,fraction)
			for trail: int in 3:
				var radius: float = reach*(0.65+0.08*trail)
				canvas.draw_arc(center,radius,sweep-side*0.58,sweep,16,ink,5.0-trail,true)
				canvas.draw_arc(center,radius,sweep-side*0.58,sweep,16,Color(tint,0.9-trail*0.2),3.0-trail*0.5,true)
			canvas.draw_line(center+Vector2.RIGHT.rotated(sweep)*12.0,center+Vector2.RIGHT.rotated(sweep)*reach,Color(1.0,0.97,0.85,0.85),2.0,true)
		else:
			canvas.draw_line(center-direction*9.0,center+direction*reach,ink,7.0,true)
			canvas.draw_line(center-direction*9.0,center+direction*reach,Color(tint,0.75),4.5,true)
			canvas.draw_line(center+direction*8.0,center+direction*reach,Color(1.0,0.97,0.9,0.95),1.8,true)
			if displacement.length_squared() > 0.00001:
				for trail: int in 3:
					var at := Vector2(-signf(direction.x)*(8+trail*5),-2-trail*4)
					canvas.draw_line(at,at-Vector2(signf(direction.x)*(8+fraction*9),0),Color(tint,0.45-trail*0.1),1.4,true)
	elif phase == "recover" and fraction < 0.3:
		canvas.draw_line(center+direction*12.0,center+direction*reach*0.7,Color(tint,(1.0-fraction/0.3)*0.25),1.0,true)

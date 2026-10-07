extends Node2D
## Articulate the existing PNG with finite static UV meshes. Combat owner's clocks
## select poses; this rig never moves a collider or emits a gameplay event.
var torso: Node2D
var head: Node2D
var arm_l: Node2D
var arm_r: Node2D
var hand_l: Node2D
var hand_r: Node2D
var leg_l: Node2D
var leg_r: Node2D
var _rest: Dictionary = {}
var pose: StringName = &"idle"

func build(texture: Texture2D, foot: Vector2, pixel_scale: float, ink: ShaderMaterial) -> void:
	var body_pivot := Vector2(620,550)
	leg_l = _piece(self,"LeftLeg",texture,foot,Vector2(535,800),pixel_scale,ink,[Vector2(448,742),Vector2(615,790),Vector2(640,885),Vector2(600,958),Vector2(628,1155),Vector2(554,1200),Vector2(309,1200),Vector2(323,1090),Vector2(447,1048),Vector2(416,955),Vector2(395,909)])
	leg_r = _piece(self,"RightLeg",texture,foot,Vector2(735,820),pixel_scale,ink,[Vector2(623,792),Vector2(793,737),Vector2(859,867),Vector2(860,985),Vector2(951,1135),Vector2(977,1245),Vector2(731,1250),Vector2(714,1150),Vector2(687,1023),Vector2(651,941)])
	torso = _piece(self,"Torso",texture,foot,body_pivot,pixel_scale,ink,[Vector2(462,290),Vector2(711,255),Vector2(793,403),Vector2(834,728),Vector2(793,805),Vector2(622,861),Vector2(454,768),Vector2(452,578),Vector2(399,440)])
	arm_l = _piece(torso,"LeftShoulder",texture,body_pivot,Vector2(429,375),pixel_scale,ink,[Vector2(349,277),Vector2(403,217),Vector2(453,266),Vector2(506,294),Vector2(481,457),Vector2(428,572),Vector2(323,544),Vector2(329,381)])
	arm_r = _piece(torso,"RightShoulder",texture,body_pivot,Vector2(866,344),pixel_scale,ink,[Vector2(720,242),Vector2(792,124),Vector2(824,221),Vector2(902,145),Vector2(926,252),Vector2(961,224),Vector2(1007,354),Vector2(1032,430),Vector2(990,552),Vector2(889,573),Vector2(797,457)])
	hand_l = _piece(arm_l,"LeftForearm",texture,Vector2(429,375),Vector2(357,548),pixel_scale,ink,[Vector2(305,486),Vector2(385,520),Vector2(430,560),Vector2(398,677),Vector2(365,704),Vector2(391,793),Vector2(379,912),Vector2(218,909),Vector2(209,790),Vector2(222,704),Vector2(256,540)])
	hand_r = _piece(arm_r,"RightForearm",texture,Vector2(866,344),Vector2(965,546),pixel_scale,ink,[Vector2(894,524),Vector2(981,492),Vector2(1058,484),Vector2(1093,582),Vector2(1090,721),Vector2(1080,842),Vector2(1021,925),Vector2(885,934),Vector2(845,822),Vector2(852,740),Vector2(890,700)])
	head = _piece(torso,"HornedHead",texture,body_pivot,Vector2(583,304),pixel_scale,ink,[Vector2(409,214),Vector2(408,52),Vector2(470,30),Vector2(500,150),Vector2(541,121),Vector2(578,59),Vector2(606,120),Vector2(657,80),Vector2(669,120),Vector2(669,10),Vector2(733,7),Vector2(760,199),Vector2(718,277),Vector2(690,329),Vector2(605,368),Vector2(530,367),Vector2(479,318)])
	# Existing floating talismans remain outside the body with a quiet sway.
	var charms: Array[Rect2] = [Rect2(270,45,106,219),Rect2(180,214,123,224),Rect2(116,360,119,231),Rect2(39,602,148,217),Rect2(138,850,124,208),Rect2(943,26,98,233),Rect2(1064,227,110,227),Rect2(1128,484,90,220),Rect2(1001,857,144,220)]
	for index: int in charms.size():
		var r: Rect2=charms[index]
		_piece(self,"Charm%d"%index,texture,foot,r.get_center(),pixel_scale,ink,[r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])

func _piece(parent_node: Node2D, title: String, texture: Texture2D, parent_pivot: Vector2, pivot: Vector2, unit: float, ink: ShaderMaterial, source: Array[Vector2]) -> Node2D:
	var joint := Node2D.new(); joint.name=title; joint.position=(pivot-parent_pivot)*unit
	parent_node.add_child(joint); _rest[joint.get_instance_id()]=joint.position
	var shape := MeshInstance2D.new(); shape.name="PaintedStone"; shape.texture=texture; shape.material=ink
	shape.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mesh_points:=PackedVector2Array(); var vertices:=PackedVector3Array(); var uv_points:=PackedVector2Array()
	for point: Vector2 in source:
		var local: Vector2=(point-pivot)*unit
		mesh_points.append(local); vertices.append(Vector3(local.x,local.y,0.0))
		uv_points.append(point/Vector2(texture.get_size()))
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=uv_points
	arrays[Mesh.ARRAY_INDEX]=Geometry2D.triangulate_polygon(mesh_points)
	var painted_mesh:=ArrayMesh.new()
	painted_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	shape.mesh=painted_mesh; joint.add_child(shape)
	return joint

func seek(state: StringName, time: float, velocity: Vector2, facing: float, flash: float, idle_clock: float, grounded: bool, active: bool) -> void:
	pose=state
	for joint_id: int in _rest:
		if not is_instance_id_valid(joint_id): continue
		var joint: Node2D=instance_from_id(joint_id) as Node2D
		joint.position=_rest[joint_id]; joint.rotation=0.0; joint.scale=Vector2.ONE
	scale.x=-1.0 if facing<0.0 else 1.0
	var gait: float=idle_clock*8.0
	if state==&"idle":
		if absf(velocity.x)>8.0:
			pose=&"walk"; leg_l.rotation=sin(gait)*0.12; leg_r.rotation=-sin(gait)*0.12
			leg_l.position.y-=maxf(0.0,sin(gait))*3.0; leg_r.position.y-=maxf(0.0,-sin(gait))*3.0
			arm_l.rotation=-sin(gait)*0.15; arm_r.rotation=sin(gait)*0.15; torso.position.y-=absf(sin(gait))*1.5
		else:
			head.rotation=sin(idle_clock*1.8)*0.035; arm_l.rotation=sin(idle_clock*1.8)*0.025; arm_r.rotation=-arm_l.rotation
	elif state==&"sweep":
		var prepare: float=smoothstep(0.0,0.5,time)
		# The fist reaches its strike pose at the existing 0.5s contact frame.
		var release: float=smoothstep(0.46,0.5,time)
		var settle: float=smoothstep(0.66,1.1,time)
		arm_r.rotation=lerpf(-1.1*prepare,0.85,release)*(1.0-settle)
		hand_r.rotation=lerpf(-0.55*prepare,-1.45,release)*(1.0-settle)
		arm_l.rotation=0.25*prepare*(1.0-settle); torso.rotation=lerpf(-0.13*prepare,0.12,release)*(1.0-settle)
		head.rotation=-torso.rotation*0.65
		pose=&"sweep_tell" if time<0.5 else &"sweep_active" if active else &"sweep_recovery"
	elif state==&"orbs":
		var gather: float=smoothstep(0.0,0.55,time); var settle: float=1.0-smoothstep(0.9,1.3,time)
		arm_l.rotation=-0.5*gather*settle; hand_l.rotation=-0.85*gather*settle
		arm_r.rotation=0.5*gather*settle; hand_r.rotation=0.85*gather*settle
		torso.scale.y=1.0+sin(time*20.0)*0.025*gather*settle
	elif state==&"stomp":
		var crouch: float=smoothstep(0.0,0.5,time) if time<0.5 else 0.0
		torso.position.y+=crouch*7.0; head.rotation=crouch*0.16
		arm_l.rotation=-0.6*crouch; arm_r.rotation=0.6*crouch
		if not grounded:
			arm_l.rotation=0.85; arm_r.rotation=-0.85; hand_l.rotation=0.45; hand_r.rotation=-0.45
			leg_l.rotation=0.12; leg_r.rotation=-0.12; pose=&"stomp_air"
	elif state==&"recover":
		var settle: float=1.0-smoothstep(0.0,0.45,time)
		torso.position.y+=settle*8.0; head.rotation=settle*0.2; arm_l.rotation=-settle*0.25; arm_r.rotation=settle*0.25
	elif state==&"staggered":
		torso.position.y+=7.0; torso.rotation=-0.16; head.rotation=0.35
		arm_l.rotation=-0.2; arm_r.rotation=0.2; hand_l.rotation=-0.25; hand_r.rotation=0.25
	elif state==&"dead":
		var fall: float=smoothstep(0.0,0.6,time)
		torso.position.y+=fall*25.0; torso.rotation=-fall*0.45; head.rotation=fall*0.7
		arm_l.rotation=-fall*0.6; arm_r.rotation=fall*0.8; leg_l.rotation=fall*0.18; leg_r.rotation=-fall*0.18
	# Ordinary hurt is a small physical recoil, preserving a committed attack.
	if flash>0.0 and state!=&"dead": torso.position.x-=sin(clampf(1.0-flash/0.12,0.0,1.0)*PI)*3.0

func _exit_tree() -> void:
	# The scene owns these nodes. Pose lookup must not keep freed joints as
	# Object-valued dictionary keys during recursive scene disposal.
	_rest.clear()
	torso=null; head=null; arm_l=null; arm_r=null; hand_l=null; hand_r=null; leg_l=null; leg_r=null

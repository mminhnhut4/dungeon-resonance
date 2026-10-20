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
var shin_l: Node2D
var shin_r: Node2D
var boot_l: Node2D
var boot_r: Node2D
var _rest: Dictionary = {}
var pose: StringName = &"idle"
const STRIDE: float = 30.0
const STANCE_SHARE: float = 0.58
const SOLE_L: Vector2 = Vector2(475,1200)
const SOLE_R: Vector2 = Vector2(850,1250)
const RIG_FOOT: Vector2 = Vector2(662.5,1250)
var _unit: float = 1.0
var _sole_offsets: Array[Vector2] = []
var _neutral_feet: Array[Vector2] = []
var _feet_world: Array[Vector2] = []
var _swing_start: Array[Vector2] = []
var _swing_end: Array[Vector2] = []
var _planted: Array[bool] = [true,true]
var _phase: float = 0.0
var _travel: float = 0.0
var _last_root: Vector2
var _last_clock: float = 0.0
var _last_facing: float = 1.0
var _tracked: bool = false
var _was_grounded: bool = false
var _floor_y: float = 0.0
var _last_state: StringName = &""
var _settle_start: Array[Vector2] = []
var stance_error: float = 0.0

func build(texture: Texture2D, foot: Vector2, pixel_scale: float, ink: ShaderMaterial) -> void:
	# Center the painted feet on the existing physical root. Source PNG and the
	# skin's reference pivot remain unchanged; only this read-only visual rig uses
	# the midpoint of its two authored soles instead of the lowest right toe.
	foot=RIG_FOOT
	_unit=pixel_scale
	var body_pivot := Vector2(620,550)
	var left: Array[Vector2]=[Vector2(448,742),Vector2(615,790),Vector2(640,885),Vector2(600,958),Vector2(628,1155),Vector2(554,1200),Vector2(309,1200),Vector2(323,1090),Vector2(447,1048),Vector2(416,955),Vector2(395,909)]
	var right: Array[Vector2]=[Vector2(623,792),Vector2(793,737),Vector2(859,867),Vector2(860,985),Vector2(951,1135),Vector2(977,1245),Vector2(731,1250),Vector2(714,1150),Vector2(687,1023),Vector2(651,941)]
	leg_l=_piece(self,"LeftLeg",texture,foot,Vector2(535,800),pixel_scale,ink,_clip_y(left,985,true))
	shin_l=_piece(leg_l,"LeftShin",texture,Vector2(535,800),Vector2(470,970),pixel_scale,ink,_clip_y(_clip_y(left,940,false),1135,true))
	boot_l=_piece(shin_l,"LeftBoot",texture,Vector2(470,970),Vector2(470,1115),pixel_scale,ink,_clip_y(left,1080,false))
	leg_r=_piece(self,"RightLeg",texture,foot,Vector2(735,820),pixel_scale,ink,_clip_y(right,1000,true))
	shin_r=_piece(leg_r,"RightShin",texture,Vector2(735,820),Vector2(810,985),pixel_scale,ink,_clip_y(_clip_y(right,960,false),1170,true))
	boot_r=_piece(shin_r,"RightBoot",texture,Vector2(810,985),Vector2(805,1150),pixel_scale,ink,_clip_y(right,1110,false))
	# A small static overlap reserve permits bent weight-bearing knees across
	# the existing motor stride; this does not stretch a planted leg at runtime.
	_lengthen_segment(leg_l,shin_l,2.0)
	_lengthen_segment(shin_l,boot_l,2.0)
	_lengthen_segment(leg_r,shin_r,2.0)
	_lengthen_segment(shin_r,boot_r,2.0)
	_sole_offsets=[(SOLE_L-Vector2(470,1115))*pixel_scale,(SOLE_R-Vector2(805,1150))*pixel_scale]
	_neutral_feet=[Vector2((SOLE_L.x-foot.x)*pixel_scale,0),Vector2((SOLE_R.x-foot.x)*pixel_scale,0)]
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

func _clip_y(points: Array[Vector2], line_y: float, above: bool) -> Array[Vector2]:
	var result: Array[Vector2]=[]
	var previous: Vector2=points[-1]
	var previous_inside: bool=previous.y<=line_y if above else previous.y>=line_y
	for point: Vector2 in points:
		var inside: bool=point.y<=line_y if above else point.y>=line_y
		if inside!=previous_inside:
			result.append(previous.lerp(point,(line_y-previous.y)/(point.y-previous.y)))
		if inside:result.append(point)
		previous=point;previous_inside=inside
	return result

func _lengthen_segment(joint: Node2D, next_joint: Node2D, extra: float) -> void:
	var original: Vector2=next_joint.position
	var axis: Vector2=original.normalized()
	next_joint.position+=axis*extra
	_rest[next_joint.get_instance_id()]=next_joint.position
	var piece: MeshInstance2D=joint.get_node("PaintedStone") as MeshInstance2D
	var arrays: Array=piece.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for index: int in vertices.size():
		var point:=Vector2(vertices[index].x,vertices[index].y)
		point+=axis*extra*point.dot(axis)/original.length()
		vertices[index]=Vector3(point.x,point.y,0)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	piece.mesh=mesh # Initialization only. UV/index buffers are unchanged.

func seek(state: StringName, time: float, velocity: Vector2, facing: float, flash: float, idle_clock: float, grounded: bool, active: bool) -> void:
	pose=state
	for joint_id: int in _rest:
		if not is_instance_id_valid(joint_id): continue
		var joint: Node2D=instance_from_id(joint_id) as Node2D
		joint.position=_rest[joint_id]; joint.rotation=0.0; joint.scale=Vector2.ONE
	scale.x=-1.0 if facing<0.0 else 1.0
	var distance: float=global_position.distance_to(_last_root) if _tracked else 0.0
	var elapsed: float=clampf(idle_clock-_last_clock,0.0,0.1)
	var rebased: bool=not _tracked or distance>=32.0 or signf(facing)!=_last_facing or (grounded and not _was_grounded)
	if rebased:_rebase_feet()
	var walking: bool=state==&"idle" and grounded and absf(velocity.x)>8.0 and distance>0.0001 and distance<32.0
	if walking:
		_travel+=absf(global_position.x-_last_root.x)
		_phase=fposmod(_travel/STRIDE,1.0)
	var gait: float=_phase*TAU
	if state==&"idle":
		if walking:
			pose=&"walk"
			arm_l.rotation=-sin(gait)*0.15; arm_r.rotation=sin(gait)*0.15
			torso.position.y-=absf(sin(gait))*0.65
			torso.rotation=sin(gait)*0.025
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
		var fall: float=smoothstep(0.0,0.36,time)
		torso.position.y+=fall*35.0; torso.rotation=-fall*0.70; head.rotation=fall*0.7
		arm_l.rotation=-fall*0.6; arm_r.rotation=fall*0.8; leg_l.rotation=fall*0.18; leg_r.rotation=-fall*0.18
	# Ordinary hurt is a small physical recoil, preserving a committed attack.
	if flash>0.0 and state!=&"dead": torso.position.x-=clampf(flash/0.12,0.0,1.0)*3.0
	# Visual joints solve toward actual world-space stance contacts. The actor's
	# motor/collider, attack clock and static mesh UV buffers are never written.
	leg_l.position.y+=50.0*_unit+2.5+maxf(0.0,torso.position.y-_rest[torso.get_instance_id()].y)*0.4
	leg_r.position.y+=2.5+maxf(0.0,torso.position.y-_rest[torso.get_instance_id()].y)*0.4
	if state!=_last_state:_settle_start=_feet_world.duplicate()
	_update_feet(state,time,walking,grounded,facing,elapsed)
	stance_error=0.0
	for index: int in 2:
		var target: Vector2=to_local(_feet_world[index])
		_solve_leg(leg_l if index==0 else leg_r,shin_l if index==0 else shin_r,boot_l if index==0 else boot_r,target,index)
		if _planted[index]:stance_error=maxf(stance_error,sole_world(index).distance_to(_feet_world[index]))
	_last_root=global_position;_last_clock=idle_clock;_last_facing=signf(facing)
	_was_grounded=grounded;_tracked=true;_last_state=state

func _rebase_feet() -> void:
	_floor_y=global_position.y;_travel=0.0;_phase=0.0
	_feet_world=[to_global(_neutral_feet[0]+Vector2(10,0)),to_global(_neutral_feet[1]+Vector2(5,0))]
	for index: int in 2:_feet_world[index].y=_floor_y
	_swing_start=_feet_world.duplicate();_swing_end=_feet_world.duplicate()
	_settle_start=_feet_world.duplicate();_planted=[true,true]

func _update_feet(state: StringName,time: float,walking: bool,grounded: bool,facing: float,elapsed: float) -> void:
	if not grounded:
		for index: int in 2:
			_feet_world[index]=to_global(_neutral_feet[index]+Vector2(0,-4.0 if state==&"stomp" else 0.0))
			_planted[index]=false
		return
	if absf(global_position.y-_floor_y)>1.0:
		_floor_y=global_position.y
		for index: int in 2:_feet_world[index].y=_floor_y
	for index: int in 2:
		if not walking:
			# Finish a lifted foot on stopping/entering an action. X stays at the
			# last support position; no snap back to a new neutral stance.
			var origin: Vector2=_settle_start[index]
			var settle: float=smoothstep(0.0,0.12,time) if state!=&"idle" else 1.0-exp(-24.0*elapsed)
			_feet_world[index].y=lerpf(origin.y,_floor_y,settle) if state!=&"idle" else lerpf(_feet_world[index].y,_floor_y,settle)
			_planted[index]=absf(_feet_world[index].y-_floor_y)<0.1
			continue
		var u: float=fposmod(_phase+index*0.5,1.0)
		var stance: bool=u<STANCE_SHARE
		if stance:
			if not _planted[index]:_feet_world[index]=_swing_end[index]
			_feet_world[index].y=_floor_y
		else:
			var swing: float=(u-STANCE_SHARE)/(1.0-STANCE_SHARE)
			if _planted[index]:
				_swing_start[index]=_feet_world[index]
				var lead: float=10.0 if index==0 else 5.0
				_swing_end[index]=Vector2(global_position.x+facing*(_neutral_feet[index].x+lead+STRIDE*(1.0-STANCE_SHARE)),_floor_y)
			_feet_world[index]=_swing_start[index].lerp(_swing_end[index],smoothstep(0.0,1.0,swing))
			_feet_world[index].y-=sin(swing*PI)*3.5
		_planted[index]=stance

func _solve_leg(thigh: Node2D,shin: Node2D,boot: Node2D,sole: Vector2,index: int) -> void:
	var first: Vector2=_rest[shin.get_instance_id()]
	var second: Vector2=_rest[boot.get_instance_id()]
	var a: float=first.length();var b: float=second.length()
	var goal: Vector2=sole-_sole_offsets[index]
	var delta: Vector2=goal-thigh.position
	var length: float=clampf(delta.length(),absf(a-b)+0.001,a+b-0.001)
	var axis: float=delta.angle()
	goal=thigh.position+Vector2.from_angle(axis)*length
	var bend: float=acos(clampf((a*a+length*length-b*b)/(2.0*a*length),-1.0,1.0))
	var knee: Vector2=thigh.position+Vector2.from_angle(axis+bend)*a
	thigh.rotation=(knee-thigh.position).angle()-first.angle()
	shin.rotation=(goal-knee).angle()-second.angle()-thigh.rotation
	boot.rotation=-thigh.rotation-shin.rotation

func sole_world(index: int) -> Vector2:
	return (boot_l if index==0 else boot_r).to_global(_sole_offsets[index])

func motion_snapshot() -> Dictionary:
	return {"pose":pose,"travel":_travel,"phase":_phase,"planted":_planted.duplicate(),"left_sole":sole_world(0),"right_sole":sole_world(1),"targets":_feet_world.duplicate(),"stance_error":stance_error,"floor":_floor_y,"stride":STRIDE}

func _exit_tree() -> void:
	# The scene owns these nodes. Pose lookup must not keep freed joints as
	# Object-valued dictionary keys during recursive scene disposal.
	_rest.clear()
	torso=null; head=null; arm_l=null; arm_r=null; hand_l=null; hand_r=null; leg_l=null; leg_r=null
	shin_l=null;shin_r=null;boot_l=null;boot_r=null
	_feet_world.clear();_swing_start.clear();_swing_end.clear();_settle_start.clear()

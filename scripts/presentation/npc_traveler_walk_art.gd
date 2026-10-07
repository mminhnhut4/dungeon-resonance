class_name NpcTravelerWalkArt
extends Node2D
## Native cutout rig; original PNG bytes stay untouched. No life/motor ownership.
const PARTS_ATLAS: Texture2D = preload("res://assets/sprites/npc/traveler_walk_candidate_v1/runtime/traveler_parts_atlas.png")
const MANIFEST: String = "res://assets/sprites/npc/traveler_walk_candidate_v1/manifest.json"
const CALIBRATION: String = "res://assets/sprites/npc/traveler_walk_candidate_v1/rig_calibration_v2.json"
const PIVOT := Vector2(128,272)
const DRAW_SCALE: float = 0.25
const HIT_IDLE_SECONDS: float = 0.16
const SETTLE_SECONDS: float = 0.12
const UPPER_PARTS: Array[String] = ["head","torso","pelvis","luggage","near_upper_arm","near_forearm_hand","far_upper_arm","far_forearm_hand"]
var ground_room: ExteriorRoom
var parts: Dictionary = {}
var definitions: Dictionary = {}
var keys: Array[Dictionary] = []
var calibration: Dictionary
var cycle_distance: float
var distance: float = 0.0
var frame_index: int = -1
var hit_idle_remaining: float = 0.0
var support_roles: Dictionary = {}
var support_anchors: Dictionary = {}
var max_leg_stretch: float = 1.0
var _anchor_segments: Dictionary = {}
var _last_hp: float = NAN
var _last_direction: float = 1.0
var _moving: bool = false
var _total_distance: float = 0.0
var _owner_world := Vector2.ZERO
var _fit: Transform2D
var posture: String = "rest"
var _display_pose: Dictionary = {}
var _rest_from: Dictionary = {}
var _rest_elapsed: float = SETTLE_SECONDS
var _upper_from: Dictionary = {}
var _upper_elapsed: float = SETTLE_SECONDS

func _init() -> void:
	name = "TravelerArticulatedWalkV3"
	visible = false
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	calibration = JSON.parse_string(FileAccess.get_file_as_string(CALIBRATION))
	cycle_distance = float(calibration["cycle_distance_world_px"])
	var fit_xy := Vector2(calibration["body_fit_xy"][0],calibration["body_fit_xy"][1])
	_fit = Transform2D(Vector2(fit_xy.x,0),Vector2(0,fit_xy.y),PIVOT-PIVOT*fit_xy)
	for spec: Dictionary in source["parts_atlas"]["parts"]: definitions[spec["id"]] = spec
	for key: Dictionary in source["keys"]:
		var pose: Dictionary = {}
		for layer: Dictionary in key["layer_transforms"]:
			var m: Array = layer["matrix"]
			pose[layer["part"]] = Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5]))
		keys.append(pose)
	for layer: Dictionary in source["keys"][0]["layer_transforms"]:
		var id: String = layer["part"]
		var spec: Dictionary = definitions[id]
		var rect: Array = spec["atlas_rect"]
		if id.ends_with("shin_foot"):
			var foot: Dictionary = calibration["contact_pixels"][id]
			_sprite(id.trim_suffix("_foot"),Rect2(rect[0],rect[1],rect[2],foot["crop_shin_end_y"]))
			var cut: float = foot["crop_foot_start_y"]
			_sprite(id,Rect2(rect[0],float(rect[1])+cut,rect[2],float(rect[3])-cut),Vector2(0,cut))
		else:
			_sprite(id,Rect2(rect[0],rect[1],rect[2],rect[3]))

func _sprite(id: String, rect: Rect2, offset: Vector2 = Vector2.ZERO) -> void:
	var frame := AtlasTexture.new()
	frame.atlas = PARTS_ATLAS
	frame.region = rect
	frame.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.name = id
	sprite.texture = frame
	sprite.centered = false
	sprite.offset = offset
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	add_child(sprite)
	parts[id] = sprite

func sync(sprite: Sprite2D, idle: Texture2D, mode: String, playing: bool, delta_x: float, delta: float, hp: float, owner_world: Vector2, facing: float = 1.0) -> void:
	if is_finite(_last_hp) and hp < _last_hp-0.001: hit_idle_remaining = HIT_IDLE_SECONDS
	_last_hp = hp
	_owner_world = owner_world
	if delta <= 0.0:
		_rest(sprite,idle,0.0,facing)
		return
	if not playing: return
	hit_idle_remaining = maxf(0.0,hit_idle_remaining-delta)
	if mode not in ["walk","flee"] or hit_idle_remaining > 0.0 or absf(delta_x) <= 0.00001:
		_rest(sprite,idle,delta,facing)
		return
	var direction: float = signf(delta_x)
	if not _moving or direction != _last_direction:
		_upper_from = _display_pose.duplicate()
		_upper_elapsed = 0.0
		_total_distance = 0.0
		_anchor_segments.clear()
		support_anchors.clear()
		max_leg_stretch = 1.0
	_last_direction = direction
	_moving = true
	posture = "walk"
	_owner_world = owner_world
	_total_distance += absf(delta_x)
	distance = fposmod(_total_distance,cycle_distance)
	var phase: float = distance/cycle_distance*8.0
	frame_index = posmod(int(floor(phase+0.000001)),8)
	position = Vector2(-PIVOT.x*DRAW_SCALE*direction,-PIVOT.y*DRAW_SCALE)
	scale = Vector2(DRAW_SCALE*direction,DRAW_SCALE)
	visible = true
	sprite.visible = false
	sprite.texture = idle
	var poses: Dictionary = _interpolated_pose(phase)
	_align(poses,"head","neck","torso","neck")
	_align(poses,"pelvis","waist","torso","waist")
	for side: String in ["near","far"]:
		_align(poses,side+"_forearm_hand","elbow",side+"_upper_arm","elbow")
		_leg(poses,side,phase)
	# Only the upper body settles at start/turn; the proven planted-foot solve stays exact.
	_upper_elapsed = minf(SETTLE_SECONDS,_upper_elapsed+delta)
	var upper_weight: float = smoothstep(0.0,SETTLE_SECONDS,_upper_elapsed)
	for id: String in UPPER_PARTS:
		if _upper_from.has(id): poses[id] = (_upper_from[id] as Transform2D).interpolate_with(poses[id],upper_weight)
	_apply_pose(poses)

func _interpolated_pose(phase: float) -> Dictionary:
	var index: int = posmod(int(floor(phase)),8)
	var weight: float = phase-floor(phase)
	var out: Dictionary = {}
	for id: String in keys[index]:
		var a: Transform2D = keys[index][id]
		var b: Transform2D = keys[(index+1)%8][id]
		out[id] = _fit*a.interpolate_with(b,weight)
	return out

func _point(id: String, label: String) -> Vector2:
	var p: Array = definitions[id]["attachment_points_local"][label]
	return Vector2(p[0],p[1])

func _align(poses: Dictionary, child: String, child_joint: String, parent: String, parent_joint: String) -> void:
	var t: Transform2D = poses[child]
	var parent_t: Transform2D = poses[parent]
	t.origin += parent_t*_point(parent,parent_joint)-t*_point(child,child_joint)
	poses[child] = t

func _leg(poses: Dictionary, side: String, phase: float) -> void:
	var lower: String = side+"_shin_foot"
	var upper: String = side+"_thigh"
	var info: Dictionary = calibration["contact_pixels"][lower]
	var contact := Vector2(info["flat_pixel_local"][0],info["flat_pixel_local"][1])
	var ankle: Vector2 = _point(lower,"ankle")
	var native: Transform2D = poses[lower]
	var foot_t: Transform2D = native
	var offset: float = 0.0 if side=="near" else 4.0
	var foot_phase: float = fposmod(phase-offset,8.0)
	var weight: float = 1.0 if foot_phase<3.0 else (1.0-smoothstep(3.0,4.0,foot_phase) if foot_phase<4.0 else 0.0)
	support_roles[side] = "stance" if weight==1.0 else ("release" if weight>0.0 else "swing")
	if weight>0.0:
		var segment: int = int(floor(_total_distance/(cycle_distance*0.5)+0.000001))
		if _anchor_segments.get(side,-1)!=segment:
			var reference: Transform2D = _fit*keys[0 if side=="near" else 4][lower]
			var leading: Vector2 = reference*contact
			var overshoot: float = fposmod(_total_distance,cycle_distance*0.5)
			var x: float = _owner_world.x-_last_direction*overshoot+_last_direction*(leading.x-PIVOT.x)*DRAW_SCALE
			support_anchors[side] = Vector2(x,_floor_y(x,_owner_world.y))
			_anchor_segments[side] = segment
		var anchor: Vector2 = support_anchors[side]
		var slope: float = (_floor_y(anchor.x+2,anchor.y)-_floor_y(anchor.x-2,anchor.y))/4.0
		var xy: Array = calibration["body_fit_xy"]
		var angle: float = float(info["flat_rotation_radians"])+atan(slope*_last_direction*float(xy[0])/float(xy[1]))
		var source_t: Transform2D = keys[0 if side=="near" else 4][lower]
		var foot_scale: Vector2 = source_t.get_scale()
		var fixed := _fit*Transform2D(angle,foot_scale,0.0,Vector2.ZERO)
		fixed.origin = _world_to_frame(anchor)-fixed.basis_xform(contact)
		foot_t = fixed.interpolate_with(native,1.0-weight)
	poses[lower] = foot_t
	var goal: Vector2 = foot_t*ankle
	var t_upper: Transform2D = poses[upper]
	var hip: Vector2 = t_upper*_point(upper,"hip")
	var seed: Vector2 = t_upper*_point(upper,"knee")
	var l1: float = hip.distance_to(seed)
	var l2: float = (native*_point(lower,"knee")).distance_to(native*ankle)
	var delta_goal: Vector2 = goal-hip
	var reach: float = maxf(0.001,delta_goal.length())
	var stretch: float = maxf(1.0,(reach+0.001)/(l1+l2))
	max_leg_stretch = maxf(max_leg_stretch,stretch)
	l1 *= stretch
	l2 *= stretch
	var axis: Vector2 = delta_goal/reach
	var along: float = clampf((l1*l1+reach*reach-l2*l2)/(2.0*reach),-l1,l1)
	var height: float = sqrt(maxf(0.0,l1*l1-along*along))
	var a: Vector2 = hip+axis*along+axis.orthogonal()*height
	var b: Vector2 = hip+axis*along-axis.orthogonal()*height
	var knee: Vector2 = a if a.distance_squared_to(seed)<=b.distance_squared_to(seed) else b
	poses[upper] = _limb(t_upper,_point(upper,"hip"),_point(upper,"knee"),hip,knee)
	poses[side+"_shin"] = _limb(native,_point(lower,"knee"),ankle,knee,goal)

func _limb(native: Transform2D, a: Vector2, b: Vector2, at: Vector2, end: Vector2) -> Transform2D:
	var u: Vector2 = (b-a).normalized()
	var v: Vector2 = u.orthogonal()
	var out_u: Vector2 = (end-at)/a.distance_to(b)
	var out_v: Vector2 = out_u.normalized().orthogonal()*native.basis_xform(v).length()
	var x: Vector2 = out_u*u.x+out_v*v.x
	var y: Vector2 = out_u*u.y+out_v*v.y
	return Transform2D(x,y,at-x*a.x-y*a.y)

func _floor_y(x: float, fallback: float) -> float:
	if not is_instance_valid(ground_room): return fallback
	return ground_room.global_position.y+ground_room.floor_y(x-ground_room.global_position.x)

func _world_to_frame(p: Vector2) -> Vector2:
	return PIVOT+Vector2((p.x-_owner_world.x)/(_last_direction*DRAW_SCALE),(p.y-_owner_world.y)/DRAW_SCALE)

func contact_world(side: String) -> Vector2:
	var id: String = side+"_shin_foot"
	var p: Array = calibration["contact_pixels"][id]["flat_pixel_local"]
	return (parts[id] as Sprite2D).to_global(Vector2(p[0],p[1]))

func joint_error_world(side: String) -> float:
	var thigh: Sprite2D = parts[side+"_thigh"]
	var shin: Sprite2D = parts[side+"_shin"]
	var foot: Sprite2D = parts[side+"_shin_foot"]
	return maxf(thigh.to_global(_point(side+"_thigh","knee")).distance_to(shin.to_global(_point(side+"_shin_foot","knee"))),shin.to_global(_point(side+"_shin_foot","ankle")).distance_to(foot.to_global(_point(side+"_shin_foot","ankle"))))

func _apply_pose(poses: Dictionary) -> void:
	for id: String in poses: (parts[id] as Sprite2D).transform = poses[id]
	_display_pose = poses.duplicate()

func _rest(sprite: Sprite2D, idle: Texture2D, delta: float, facing: float) -> void:
	if _moving:
		_rest_from = _display_pose.duplicate()
		_rest_elapsed = 0.0
	if _display_pose.is_empty(): _last_direction = -1.0 if facing<0.0 else 1.0
	_moving = false
	_total_distance = 0.0
	distance = 0.0
	frame_index = -1
	posture = "hurt_hold" if hit_idle_remaining>0.0 else "rest"
	visible = true
	sprite.visible = false
	sprite.texture = idle
	position = Vector2(-PIVOT.x*DRAW_SCALE*_last_direction,-PIVOT.y*DRAW_SCALE)
	scale = Vector2(DRAW_SCALE*_last_direction,DRAW_SCALE)
	var poses: Dictionary = _rest_pose()
	_rest_elapsed = minf(SETTLE_SECONDS,_rest_elapsed+delta)
	var weight: float = smoothstep(0.0,SETTLE_SECONDS,_rest_elapsed)
	for id: String in poses:
		if _rest_from.has(id): poses[id] = (_rest_from[id] as Transform2D).interpolate_with(poses[id],weight)
	_apply_pose(poses)
	support_roles.clear()
	support_anchors.clear()
	_anchor_segments.clear()

func _rest_pose() -> Dictionary:
	# A quiet standing posture from the same authored parts, never another costume PNG.
	var poses: Dictionary = {}
	for id: String in keys[0]: poses[id] = _fit*(keys[0][id] as Transform2D).interpolate_with(keys[4][id],0.5)
	_align(poses,"head","neck","torso","neck")
	_align(poses,"pelvis","waist","torso","waist")
	for side: String in ["near","far"]:
		_align(poses,side+"_forearm_hand","elbow",side+"_upper_arm","elbow")
		_rest_leg(poses,side)
	return poses

func _rest_leg(poses: Dictionary, side: String) -> void:
	var lower: String = side+"_shin_foot"
	var upper: String = side+"_thigh"
	var info: Dictionary = calibration["contact_pixels"][lower]
	var contact := Vector2(info["flat_pixel_local"][0],info["flat_pixel_local"][1])
	var native: Transform2D = poses[lower]
	var leading: Vector2 = native*contact
	var x: float = _owner_world.x+_last_direction*(leading.x-PIVOT.x)*DRAW_SCALE
	var anchor := Vector2(x,_floor_y(x,_owner_world.y))
	var slope: float = (_floor_y(x+2,anchor.y)-_floor_y(x-2,anchor.y))/4.0
	var xy: Array = calibration["body_fit_xy"]
	var angle: float = float(info["flat_rotation_radians"])+atan(slope*_last_direction*float(xy[0])/float(xy[1]))
	var source: Transform2D = keys[0 if side=="near" else 4][lower]
	var foot_t := _fit*Transform2D(angle,source.get_scale(),0.0,Vector2.ZERO)
	foot_t.origin = _world_to_frame(anchor)-foot_t.basis_xform(contact)
	poses[lower] = foot_t
	var ankle: Vector2 = _point(lower,"ankle")
	var goal: Vector2 = foot_t*ankle
	var thigh: Transform2D = poses[upper]
	var hip: Vector2 = thigh*_point(upper,"hip")
	var seed: Vector2 = thigh*_point(upper,"knee")
	var l1: float = hip.distance_to(seed)
	var l2: float = (native*_point(lower,"knee")).distance_to(native*ankle)
	var axis: Vector2 = (goal-hip).normalized()
	var reach: float = maxf(0.001,goal.distance_to(hip))
	var stretch: float = maxf(1.0,(reach+0.001)/(l1+l2))
	l1 *= stretch
	l2 *= stretch
	var along: float = clampf((l1*l1+reach*reach-l2*l2)/(2.0*reach),-l1,l1)
	var height: float = sqrt(maxf(0.0,l1*l1-along*along))
	var a: Vector2 = hip+axis*along+axis.orthogonal()*height
	var b: Vector2 = hip+axis*along-axis.orthogonal()*height
	var knee: Vector2 = a if a.distance_squared_to(seed)<=b.distance_squared_to(seed) else b
	poses[upper] = _limb(thigh,_point(upper,"hip"),_point(upper,"knee"),hip,knee)
	poses[side+"_shin"] = _limb(native,_point(lower,"knee"),ankle,knee,goal)

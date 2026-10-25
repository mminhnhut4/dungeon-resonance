class_name OpeningEnemySkillArt
extends Node2D
## Ancient Guard's authored boot/blade accents. Read-only presentation observer.
## Existing GuardBodyFrames owns the sampled art; GuardSweepVFX owns sweep/contact ink.
const MAX_OWNERS: int = 8
const MAX_FOOT_MOTES: int = 3
const FOOT_SECONDS: float = 0.18
const INK: Color = Color(0.16,0.10,0.06)
const BRONZE: Color = Color(0.72,0.37,0.12)
const EDGE: Color = Color(0.94,0.82,0.54)
var actor: BaseEnemy
var body_frames: GuardBodyFrames
var phase: StringName = &""
var progress: float = 0.0
var front_planted: bool = false
var back_planted: bool = false
var front_boot: Vector2 = Vector2.ZERO
var back_boot: Vector2 = Vector2.ZERO
var blade_hand: Vector2 = Vector2.ZERO
var blade_tip: Vector2 = Vector2.ZERO
var moving: bool = false
var step_count: int = 0
var _motes: Array[Dictionary] = []
var _front_was_planted: bool = false
var _back_was_planted: bool = false
var _was_grounded: bool = false
var _last_state: StringName = &""
var _last_state_time: float = -1.0
var _last_clock: float = -1.0

func bind(owner_actor: BaseEnemy, frames: GuardBodyFrames) -> void:
	actor = owner_actor
	body_frames = frames
	name = "AncientGuardSkillArt"
	z_index = 2
	var ink := CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ink.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = ink
	add_to_group(&"opening_enemy_skill_art")
	actor.state_machine.state_changed.connect(_on_actor_state_changed)
	sample(0.0,0.0,actor.is_on_floor())

func _on_actor_state_changed(_previous: StringName, next: StringName) -> void:
	# The body and sweep observers are already connected. Clear a canceled tell
	# synchronously before the accepted hit can freeze the next physics sample.
	if next in [&"hurt",&"dead"]:
		phase = &""
		progress = 0.0
		front_planted = false
		back_planted = false
		moving = false
		_motes.clear()
		_front_was_planted = false
		_back_was_planted = false
		_was_grounded = false
		queue_redraw()
		return
	# Entering a live phase seeks the same committed pose without advancing time.
	sample(0.0,0.0,actor.is_on_floor())

func sample(delta: float, actual_distance: float, grounded: bool) -> void:
	# WorldEnemyVisual calls after body_frames.seek_actor, in the same physics
	# sample. This node has no independent timer/process and cannot lead the pose.
	if not is_instance_valid(actor) or body_frames == null or not body_frames.valid: return
	if is_instance_valid(actor.combat_feedback) and actor.combat_feedback.is_frozen(): return
	var state: StringName = actor.state_machine.get_state_id()
	if not actor.ai_enabled and actor.health.current_health>0.0 and state==_last_state and actor.state_time==_last_state_time and actor.clock==_last_clock: return
	_last_state = state
	_last_state_time = actor.state_time
	_last_clock = actor.clock
	var elapsed: float = maxf(0.0,delta) if actor.ai_enabled or actor.health.current_health<=0.0 else 0.0
	for index: int in range(_motes.size()-1,-1,-1):
		_motes[index]["remaining"] = maxf(0.0,float(_motes[index]["remaining"])-elapsed)
		if float(_motes[index]["remaining"])<=0.0: _motes.remove_at(index)
	var interrupted: bool = state in [&"hurt",&"dead"]
	if interrupted or actual_distance>=32.0: _motes.clear()
	front_boot = body_frames.anchor_local("front_boot_contact")
	back_boot = body_frames.anchor_local("back_boot_contact")
	blade_hand = body_frames.anchor_local("sword_hand")
	blade_tip = body_frames.anchor_local("saber_tip")
	front_planted = grounded and not interrupted and bool(body_frames.frame_data.get("contact_front",false))
	back_planted = grounded and not interrupted and bool(body_frames.frame_data.get("contact_back",false))
	moving = actor.ai_enabled and grounded and actual_distance>0.001 and actual_distance<32.0 and state in [&"patrol",&"chase"] and body_frames.clip_id==&"walk"
	# A plant is an authored boot-contact edge during real grounded translation.
	# Stopped/wall-blocked bodies, falling and relocations cannot manufacture steps.
	if moving and _was_grounded:
		if front_planted and not _front_was_planted: _plant(front_boot)
		if back_planted and not _back_was_planted: _plant(back_boot)
	_front_was_planted = front_planted
	_back_was_planted = back_planted
	_was_grounded = grounded
	phase = state if state in [&"telegraph",&"attack",&"recover"] and actor.attack_kind==&"sweep" and not interrupted else &""
	if phase==&"attack" and not actor.attack_hitbox.active: phase = &""
	var duration: float = actor.definition.windup if phase==&"telegraph" else actor.definition.active if phase==&"attack" else actor.definition.recovery
	progress = clampf(actor.state_time/maxf(0.001,duration),0.0,1.0) if phase!=&"" else 0.0
	queue_redraw()

func _plant(boot: Vector2) -> void:
	# The actor's grounded physical foot is the plane, not a sprite's image edge.
	# Store world space once so dust stays at the plant while the body walks away.
	if _motes.size()>=MAX_FOOT_MOTES: _motes.remove_at(0)
	_motes.append({"world":to_global(Vector2(boot.x,0.0)),"remaining":FOOT_SECONDS,"facing":body_frames.displayed_facing})
	step_count += 1

func _draw() -> void:
	if not is_instance_valid(actor) or body_frames == null or not body_frames.valid: return
	# Two narrow sole contact accents keep the planted weight readable at60px.
	# Joint articulation and common root remain entirely in the existing frames.
	if front_planted: _sole(Vector2(front_boot.x,0.0))
	if back_planted: _sole(Vector2(back_boot.x,0.0))
	for mote: Dictionary in _motes:
		var age: float = 1.0-float(mote["remaining"])/FOOT_SECONDS
		var opacity: float = (1.0-age)*0.38
		var center: Vector2 = to_local(mote["world"])
		var side: float = -float(mote["facing"])
		for index: int in 3:
			var offset := Vector2(side*(2.0+index*2.0+age*5.0),-1.0-age*(1.0+index))
			var tail := Vector2(side*(1.8+age),-0.5)
			draw_line(center+offset,center+offset+tail,Color(BRONZE,opacity*(1.0-index*0.15)),1.0,true)
	if phase==&"": return
	var strength: float = 0.0
	if phase==&"telegraph": strength = 0.15+sin(progress*PI*0.5)*0.55
	elif phase==&"attack" and actor.attack_hitbox.active: strength = 0.8*(1.0-progress*0.45)
	elif phase==&"recover": strength = maxf(0.0,1.0-actor.state_time/0.10)*0.4
	if strength<=0.0: return
	# A short metal edge on the actual authored saber; the sweep's reach and
	# accepted-hit flash remain exclusively in GuardSweepVFX. No target markers.
	var edge_a: Vector2 = blade_hand.lerp(blade_tip,0.62)
	var edge_b: Vector2 = blade_hand.lerp(blade_tip,0.91)
	draw_line(edge_a,edge_b,Color(INK,strength*0.65),2.0,true)
	draw_line(edge_a,edge_b,Color(EDGE,strength),0.8,true)
	if phase==&"telegraph" and progress>0.72:
		var glint: Vector2 = edge_a.lerp(edge_b,0.65)
		var radius: float = (progress-0.72)/0.28*1.6
		draw_line(glint-Vector2(radius,0),glint+Vector2(radius,0),Color(EDGE,strength),0.8,true)
		draw_line(glint-Vector2(0,radius),glint+Vector2(0,radius),Color(EDGE,strength),0.8,true)

func _sole(at: Vector2) -> void:
	draw_line(at+Vector2(-3.4,0.5),at+Vector2(3.4,0.5),Color(INK,0.42),1.4,true)
	draw_line(at+Vector2(-2.2,-0.3),at+Vector2(2.2,-0.3),Color(BRONZE,0.18),0.7,true)

func snapshot() -> Dictionary:
	var world_contacts: Array[Vector2] = []
	for mote: Dictionary in _motes: world_contacts.append(mote["world"])
	return {"actor_id":actor.get_instance_id() if is_instance_valid(actor) else 0,"phase":phase,"progress":progress,"body_clip":body_frames.clip_id if body_frames!=null else &"","body_frame":body_frames.frame_index if body_frames!=null else -1,"front_planted":front_planted,"back_planted":back_planted,"front_boot":front_boot,"back_boot":back_boot,"blade_hand":blade_hand,"blade_tip":blade_tip,"moving":moving,"step_count":step_count,"foot_motes":_motes.size(),"foot_motes_world":world_contacts,"max_foot_motes":MAX_FOOT_MOTES,"max_owners":MAX_OWNERS,"max_draw_commands":17,"lights":0,"audio_voices":0,"damage_emitters":0}

func _exit_tree() -> void:
	if is_instance_valid(actor) and is_instance_valid(actor.state_machine) and actor.state_machine.state_changed.is_connected(_on_actor_state_changed):
		actor.state_machine.state_changed.disconnect(_on_actor_state_changed)
	_motes.clear()
	body_frames = null
	actor = null

class_name GuardSweepVFX
extends Node2D
## Authored Canvas shapes seek the live Guard FSM. No damage, timers or gameplay IDs.
const MAX_OWNERS: int = 8
const IMPACT_SECONDS: float = 0.16
const HAND_PIXEL: Vector2 = Vector2(474, 365) # Approved static guard region, not incoming rig.
const INK: Color = Color(0.16, 0.10, 0.06)
const BRONZE: Color = Color(0.72, 0.37, 0.12)
const EDGE: Color = Color(0.94, 0.82, 0.54)
var actor: BaseEnemy
var presentation: Node2D
var phase: StringName = &""
var progress: float = 0.0
var facing: float = 1.0
var impact_count: int = 0
var impact_remaining: float = 0.0
var impact_world: Vector2 = Vector2.ZERO
var _target_hurt: Hurtbox
var _recent_hits: Dictionary[String, bool] = {}
var _contact_ink: ContactInk

class ContactInk extends Node2D:
	var owner_vfx: GuardSweepVFX
	func _draw() -> void:
		if is_instance_valid(owner_vfx) and owner_vfx.impact_remaining>0.0:
			owner_vfx._draw_contact(self)

func _ready() -> void:
	var ink := CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ink.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = ink
	_contact_ink = ContactInk.new()
	_contact_ink.name = "AcceptedContactInk"
	_contact_ink.owner_vfx = self
	_contact_ink.z_index = 12
	_contact_ink.material = ink
	add_child(_contact_ink)

func bind(owner_guard: BaseEnemy, owner_visual: Node2D) -> void:
	actor = owner_guard
	presentation = owner_visual
	name = "GuardSweepVFX"
	z_index = 1
	process_physics_priority = 20
	add_to_group(&"guard_sweep_vfx")
	_bind_target()
	actor.state_machine.state_changed.connect(_on_actor_state_changed)
	seek_actor()

func _on_actor_state_changed(_previous: StringName,_next: StringName) -> void:
	# Body observer was bound first; use the same just-entered pose/clock.
	seek_actor()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return
	if not actor.ai_enabled and actor.health.current_health > 0.0:
		return
	if is_instance_valid(actor.combat_feedback) and actor.combat_feedback.is_frozen():
		return
	_bind_target()
	impact_remaining = maxf(0.0, impact_remaining - maxf(0.0, delta))
	seek_actor()

func seek_actor() -> void:
	if not is_instance_valid(actor):
		clear_effect()
		return
	var state: StringName = actor.state_machine.get_state_id()
	facing = -1.0 if actor.facing < 0.0 else 1.0
	phase = state if state in [&"telegraph", &"attack", &"recover"] and actor.attack_kind == &"sweep" else &""
	var duration: float = actor.definition.windup if phase == &"telegraph" else actor.definition.active if phase == &"attack" else actor.definition.recovery
	progress = clampf(actor.state_time / maxf(0.001, duration), 0.0, 1.0)
	if phase == &"attack" and not actor.attack_hitbox.active:
		phase = &""
	if state in [&"hurt", &"dead"]:
		clear_effect()
	queue_redraw()
	if is_instance_valid(_contact_ink): _contact_ink.queue_redraw()

func _bind_target() -> void:
	var next: Hurtbox = actor.player.get("hurtbox") as Hurtbox if is_instance_valid(actor) and is_instance_valid(actor.player) else null
	if next == _target_hurt:
		return
	if is_instance_valid(_target_hurt) and _target_hurt.hit_resolved.is_connected(_on_resolved):
		_target_hurt.hit_resolved.disconnect(_on_resolved)
	_target_hurt = next
	if is_instance_valid(_target_hurt):
		_target_hurt.hit_resolved.connect(_on_resolved)

func _on_resolved(event: DamageEvent, result: DamageResult) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(_target_hurt):
		return
	if event.source_id != actor.get_instance_id() or event.source_kind != DamageEvent.SourceKind.DIRECT or not event.physical_damage or result.blocked or result.actual_damage <= 0.0:
		return
	var key: String = "%d:%d:%d" % [event.attack_id, event.hit_window_id, event.target_id]
	if _recent_hits.has(key):
		return
	if _recent_hits.size() >= 16:
		_recent_hits.erase(_recent_hits.keys()[0])
	_recent_hits[key] = true
	impact_count += 1
	impact_remaining = IMPACT_SECONDS
	impact_world = _target_hurt.global_position
	queue_redraw()
	if is_instance_valid(_contact_ink): _contact_ink.queue_redraw()

func hand_local() -> Vector2:
	var authored: GuardBodyFrames = presentation.get("body_frames") as GuardBodyFrames if is_instance_valid(presentation) else null
	if authored != null and authored.valid:
		return to_local(presentation.to_global(authored.anchor_local("sword_hand")))
	# Read the source sprite transform, including its current committed mirror.
	var source: Sprite2D = presentation.get("sprite") as Sprite2D if is_instance_valid(presentation) else null
	if source != null and source.texture is AtlasTexture and source.texture.get_width() == 768:
		var pixel: Vector2 = Vector2(source.texture.get_width() - HAND_PIXEL.x, HAND_PIXEL.y) if source.flip_h else HAND_PIXEL
		return to_local(source.to_global(source.offset + pixel))
	# Legacy static fallback only; authored frames supply their per-pose anchor above.
	return Vector2(facing * 21.0, -18.0)

func blade_tip_local() -> Vector2:
	var authored: GuardBodyFrames = presentation.get("body_frames") as GuardBodyFrames if is_instance_valid(presentation) else null
	if authored != null and authored.valid:
		return to_local(presentation.to_global(authored.anchor_local("saber_tip")))
	return Vector2(facing*70.0,-12.0)

func ribbon_center(amount: float, u: float) -> Vector2:
	var hand: Vector2 = hand_local()
	var authored: GuardBodyFrames = presentation.get("body_frames") as GuardBodyFrames if is_instance_valid(presentation) else null
	var on_blade: bool = authored != null and authored.valid and phase in [&"attack",&"recover"] and hand.y>=-29.0 and hand.y<=-3.0
	var start_x: float = clampf(hand.x*facing,0.0,30.0) if on_blade else clampf(hand.x*facing,10.0,30.0)
	var x: float = lerpf(start_x,91.0,u)
	var y: float
	if on_blade:
		var tip: Vector2=blade_tip_local()
		var tip_x: float=clampf(tip.x*facing,start_x+1.0,90.0)
		# The visible blade supplies the leading direction; energy carries its reach
		# through the remaining existing sweep band without changing the hit shape.
		y=lerpf(hand.y,tip.y,clampf((x-start_x)/(tip_x-start_x),0.0,1.0))
		if x>tip_x: y=lerpf(tip.y,-6.0,(x-tip_x)/(91.0-tip_x))
	else:
		var start_y: float=clampf(hand.y,-25.0,-7.0)
		y=lerpf(start_y,lerpf(-25.0,-6.0,amount),u)+sin(u*PI)*lerpf(-6.0,5.0,amount)
		y=clampf(y,-25.0,-7.0)
	return Vector2(facing*x,clampf(y,-29.0,-3.0))

func ribbon_points(amount: float, width: float = 4.0) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for index: int in 13:
		var u: float = float(index) / 12.0
		var center: Vector2=ribbon_center(amount,u)
		var taper: float = (0.15 + sin(u * PI) * 0.85) * width
		taper=minf(taper,maxf(0.0,minf(center.y+29.0,-3.0-center.y)))
		top.append(center-Vector2(0,taper))
		bottom.append(center+Vector2(0,taper))
	for index: int in range(bottom.size() - 1, -1, -1):
		top.append(bottom[index])
	return top

func _draw() -> void:
	if not is_instance_valid(actor):
		return
	if phase == &"telegraph":
		var strength: float = 0.38 + progress * 0.48
		var outline: PackedVector2Array = ribbon_points(0.0, 1.0 + progress)
		var closed: PackedVector2Array = outline.duplicate()
		closed.append(outline[0])
		draw_polyline(closed, Color(BRONZE, strength), 1.2, true)
		# Physical sweep reaches [-4,92] x [-29,-3]; ruled ends are a tell, no hit.
		for index: int in 6:
			var x: float = lerpf(25.0, 91.0, float(index) / 5.0)
			draw_line(Vector2(facing * x, -1), Vector2(facing * (x - 3), -4 - progress * 3), Color(EDGE, strength), 1.0, true)
		draw_polyline(PackedVector2Array([Vector2(facing * 85, -8), Vector2(facing * 92, -3), Vector2(facing * 85, 2)]), Color(EDGE, strength), 1.4, true)
	elif phase == &"attack":
		_draw_slash(progress, 1.0)
	elif phase == &"recover" and actor.state_time < 0.10:
		_draw_slash(1.0, (1.0 - actor.state_time / 0.10) * 0.5)

func _draw_slash(amount: float, opacity: float) -> void:
	for index: int in range(2, 0, -1):
		var earlier: float = maxf(0.0, amount - index * 0.16)
		draw_colored_polygon(ribbon_points(earlier, 3.0), Color(BRONZE, opacity * (0.18 if index == 2 else 0.30)))
	var shape: PackedVector2Array = ribbon_points(amount, 4.0)
	draw_colored_polygon(shape, Color(INK, opacity * 0.88))
	draw_colored_polygon(ribbon_points(amount, 2.5), Color(BRONZE, opacity * 0.92))
	draw_colored_polygon(ribbon_points(amount, 0.8), Color(EDGE, opacity * 0.95))
	var edge: PackedVector2Array = ribbon_points(amount, 4.0).slice(0, 13)
	draw_polyline(edge, Color(EDGE, opacity * 0.85), 1.0, true)
	# Three separated blade chips sharpen the leading edge without a glow plane.
	for index: int in 3:
		var x: float = 60.0 + index * 11.0
		var start_x: float=clampf(hand_local().x*facing,0.0,30.0)
		var center: Vector2=ribbon_center(amount,(x-start_x)/(91.0-start_x))
		draw_line(center,center+Vector2(facing*5,-2),Color(EDGE,opacity*0.8),1.2,true)

func _draw_contact(canvas: Node2D) -> void:
	var age: float = 1.0 - impact_remaining / IMPACT_SECONDS
	var center: Vector2 = canvas.to_local(impact_world)
	var star := PackedVector2Array()
	for index: int in 12:
		var radius: float = (9.0 if index % 2 == 0 else 2.4) * (0.65 + age * 0.4)
		star.append(center + Vector2.from_angle(index * TAU / 12.0) * radius)
	canvas.draw_colored_polygon(star, Color(BRONZE, (1.0 - age) * 0.95))
	var border: PackedVector2Array = star.duplicate()
	border.append(star[0])
	canvas.draw_polyline(border,Color(INK,(1.0-age)*0.95),1.5,true)
	for index: int in 6:
		var ray: Vector2 = Vector2.from_angle(-2.9 + index * 0.55)
		var point: Vector2 = center + ray * (8.0 + age * 18.0)
		canvas.draw_line(point,point+ray*3.0,Color(INK,1.0-age),2.8,true)
		canvas.draw_line(point,point+ray*3.0,Color(EDGE,1.0-age),1.0,true)

func clear_effect() -> void:
	phase = &""
	progress = 0.0
	impact_remaining = 0.0
	queue_redraw()
	if is_instance_valid(_contact_ink): _contact_ink.queue_redraw()

func snapshot() -> Dictionary:
	return {"phase": phase, "progress": progress, "facing": facing, "impact_count": impact_count, "impact_remaining": impact_remaining, "hand_local": hand_local(), "blade_tip_local":blade_tip_local(),"ribbon_start":ribbon_center(progress,0.0), "ribbon_vertices": 26, "max_draw_commands": 24, "lights": 0, "damage_emitters": 0}

func _exit_tree() -> void:
	if is_instance_valid(actor) and is_instance_valid(actor.state_machine) and actor.state_machine.state_changed.is_connected(_on_actor_state_changed):
		actor.state_machine.state_changed.disconnect(_on_actor_state_changed)
	if is_instance_valid(_target_hurt) and _target_hurt.hit_resolved.is_connected(_on_resolved):
		_target_hurt.hit_resolved.disconnect(_on_resolved)
	_target_hurt = null
	actor = null
	presentation = null
	_recent_hits.clear()
	if is_instance_valid(_contact_ink): _contact_ink.owner_vfx = null

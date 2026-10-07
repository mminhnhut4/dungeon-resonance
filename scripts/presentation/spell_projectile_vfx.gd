class_name SpellProjectileVFX
extends Node2D
## Owner-bound cosmetics only: a short luminous wake and twelve GPU motes.
## No light, damage, collision, proc or gameplay-clock ownership.

const MAX_POINTS: int = 12
const MAX_PARTICLES: int = 12
const MAX_TRAIL_LENGTH: float = 72.0
const POINT_SPACING: float = 5.0
const SPARK_TEXTURE: Texture2D = preload("res://assets/presentation/spark.png")

var particles: GPUParticles2D
var line: Line2D
var tint: Color = Color(0.35, 1.0, 0.81)
var owner_id: int = 0
var feedback_id: int = 0
var tracked_root_id: int = 0
var committed_quality: int = -1 # Legacy spells retain their original twelve motes.
var points := PackedVector2Array()
var _clock: float = 0.0
var _ages := PackedFloat32Array()
var committed_recipe: StringName = &"basic"
var committed_behavior: StringName = &"bolt"


func _ready() -> void:
	name = "SpellTrailVFX"
	z_index = 6 # Above floor/actor ink, below the HUD; no added PointLight.
	var body_ink := CanvasItemMaterial.new()
	body_ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = body_ink
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	line = Line2D.new()
	line.name = "LuminousWake"
	line.top_level = true
	line.width = 6.0
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.material = additive
	add_child(line)
	particles = GPUParticles2D.new()
	particles.name = "TrailMotes"
	particles.emitting = false
	particles.amount = MAX_PARTICLES
	particles.lifetime = 0.20
	particles.fixed_fps = 60
	particles.local_coords = false
	particles.visibility_rect = Rect2(-100.0, -100.0, 200.0, 200.0)
	particles.texture = SPARK_TEXTURE
	particles.material = additive
	var behavior := ParticleProcessMaterial.new()
	behavior.direction = Vector3(-1.0, 0.0, 0.0)
	behavior.spread = 18.0
	behavior.gravity = Vector3.ZERO
	behavior.initial_velocity_min = 12.0
	behavior.initial_velocity_max = 35.0
	behavior.scale_min = 0.25
	behavior.scale_max = 0.55
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	behavior.color_ramp = ramp
	particles.process_material = behavior
	add_child(particles)
	_update_color()
	particles.emitting = DisplayServer.get_name() != "headless"
	if owner_id != 0:
		_sample_owner(0.0)


func bind(projectile: SpellProjectile, combat_feedback: CombatFeedback = null) -> void:
	owner_id = projectile.get_instance_id() if is_instance_valid(projectile) else 0
	feedback_id = combat_feedback.get_instance_id() if is_instance_valid(combat_feedback) else 0
	points.clear()
	_ages.clear()
	_clock = 0.0
	tracked_root_id = 0
	committed_quality = -1
	if owner_id != 0 and projectile.context != null:
		# Store presentation scalars, not a shared mutable definition or context.
		tint = projectile.context.snapshot.color
		tracked_root_id = projectile.context.snapshot.root_id
		committed_recipe = projectile.context.snapshot.recipe_id
		committed_behavior = projectile.context.snapshot.behavior_id
		if projectile.context.snapshot.weapon_family_visual:
			committed_quality = clampi(projectile.context.snapshot.cosmetic_quality, 0, 5)
	_update_color()
	if committed_quality >= 0:
		if particles != null: particles.amount = mini(MAX_PARTICLES, 2 + committed_quality * 2)
		if line != null: line.width = 2.5 + committed_quality * 0.7
	if particles != null:
		particles.emitting = owner_id != 0 and DisplayServer.get_name() != "headless"
	if owner_id != 0 and is_inside_tree():
		_sample_owner(0.0)
	elif line != null:
		line.clear_points()


func _update_color() -> void:
	if particles != null:
		(particles.process_material as ParticleProcessMaterial).color = tint.lerp(Color.WHITE, 0.25)
	if line != null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
		gradient.set_color(1, tint.lerp(Color.WHITE, 0.6))
		line.gradient = gradient


func _physics_process(delta: float) -> void:
	if owner_id == 0 or not is_instance_id_valid(owner_id):
		queue_free()
		return
	var feedback: CombatFeedback
	if feedback_id != 0 and is_instance_id_valid(feedback_id):
		feedback = instance_from_id(feedback_id) as CombatFeedback
	var frozen: bool = feedback != null and feedback.is_frozen()
	particles.speed_scale = 0.0 if frozen else 1.0
	if not frozen:
		_sample_owner(delta)


func _sample_owner(delta: float) -> void:
	if not is_instance_id_valid(owner_id) or line == null:
		return
	var projectile: Node2D = instance_from_id(owner_id) as Node2D
	if projectile == null:
		return
	_clock += delta
	var location: Vector2 = projectile.global_position
	if points.is_empty() or points[points.size() - 1].distance_to(location) >= POINT_SPACING:
		points.append(location)
		_ages.append(_clock)
	while points.size() > MAX_POINTS or (points.size() > 1 and _clock - _ages[0] > 0.20):
		points.remove_at(0)
		_ages.remove_at(0)
	var total_length: float = 0.0
	for index: int in range(points.size() - 1, 0, -1):
		total_length += points[index].distance_to(points[index - 1])
		if total_length > MAX_TRAIL_LENGTH:
			for discard: int in index:
				points.remove_at(0)
				_ages.remove_at(0)
			break
	line.points = points
	queue_redraw()

func _draw() -> void:
	if owner_id == 0: return
	var edge:=Color(0.015,0.025,0.03,0.95)
	var bright:=tint.lerp(Color.WHITE,0.7)
	var shape:=PackedVector2Array()
	if "fire" in str(committed_recipe) or committed_recipe==&"combustion":
		shape=PackedVector2Array([Vector2(17,0),Vector2(2,-7),Vector2(-8,-10),Vector2(-4,-3),Vector2(-17,-3),Vector2(-9,2),Vector2(-14,7),Vector2(2,7)])
	elif "ice" in str(committed_recipe) or committed_recipe in [&"blizzard",&"thermal_shock"]:
		shape=PackedVector2Array([Vector2(17,0),Vector2(0,-9),Vector2(-13,0),Vector2(0,9)])
	elif "lightning" in str(committed_recipe) or committed_recipe in [&"overload",&"charged_slash"]:
		shape=PackedVector2Array([Vector2(18,0),Vector2(1,-3),Vector2(6,-9),Vector2(-18,-2),Vector2(-3,2),Vector2(-7,9)])
	elif "wind" in str(committed_recipe) or committed_behavior==&"arcane_wave":
		for index: int in 3:
			var x: float=-index*7.0
			var arc:=PackedVector2Array([Vector2(x-5,-10),Vector2(x+1,-6),Vector2(x+4,0),Vector2(x+1,6),Vector2(x-5,10)])
			draw_polyline(arc,edge,5.0,true); draw_polyline(arc,tint,2.5,true)
		draw_circle(Vector2(3,0),2.0,bright); return
	elif "poison" in str(committed_recipe):
		for index: int in 3:
			var point: Vector2=Vector2.from_angle(_clock*6.0+index*TAU/3.0)*8.0
			draw_circle(point,5.0,edge); draw_circle(point,3.0,tint)
		draw_circle(Vector2.ZERO,4.0,bright); return
	else:
		shape=PackedVector2Array([Vector2(14,0),Vector2(0,-7),Vector2(-11,0),Vector2(0,7)])
	draw_colored_polygon(shape,tint)
	var outline: PackedVector2Array=shape.duplicate(); outline.append(shape[0])
	draw_polyline(outline,edge,1.8,true)
	draw_line(Vector2(-6,0),Vector2(10,0),bright,2.5,true)


func _exit_tree() -> void:
	owner_id = 0
	feedback_id = 0
	points.clear()
	_ages.clear()

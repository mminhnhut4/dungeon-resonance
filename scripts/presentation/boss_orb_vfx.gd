class_name BossOrbVFX
extends Node2D
## Cosmetic glyph follows its existing homing hazard; no new contact or light.
const MAX_VISUALS: int = 24
const MAX_POINTS: int = 12
const MAX_WAKE_LENGTH: float = 72.0
const POINT_SPACING: float = 2.5
const WAKE_SECONDS: float = 0.20
const MAGENTA: Color = Color(0.95, 0.45, 1.0)
const RASTER = preload("res://scripts/presentation/boss_skill_raster_helper.gd")
var glyph: Sprite2D
var points := PackedVector2Array()
var ages := PackedFloat32Array()
var age: float = 0.0
var heading := Vector2.LEFT
var _owner_id: int = 0
var _initial_life: float = 0.0
var _original_self_modulate: Color = Color.WHITE

func _ready() -> void:
	process_physics_priority = 20
	var ink := CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ink.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = ink

func bind(owner_hazard: Node2D) -> void:
	restore_source()
	if not is_instance_valid(owner_hazard): return
	_owner_id = owner_hazard.get_instance_id()
	_initial_life = float(owner_hazard.get("life"))
	_original_self_modulate = owner_hazard.self_modulate
	owner_hazard.self_modulate.a = 0.0 # Hide only the flat parent draw.
	name = "BossOrbVFX"
	add_to_group(&"boss_orb_vfx")
	visible = true
	if glyph == null:
		glyph = RASTER.make_orb_glyph(self)
	_sample_owner()

func _owner() -> Node2D:
	return instance_from_id(_owner_id) as Node2D if _owner_id != 0 and is_instance_id_valid(_owner_id) else null

func _physics_process(_delta: float) -> void:
	var hazard: Node2D = _owner()
	if hazard == null or hazard.is_queued_for_deletion(): return
	var feedback: CombatFeedback = hazard.get("feedback") as CombatFeedback
	if is_instance_valid(feedback) and feedback.is_frozen(): return
	_sample_owner()

func _sample_owner() -> void:
	var hazard: Node2D = _owner()
	if hazard == null: return
	age = maxf(0.0, _initial_life - float(hazard.get("life")))
	heading = Vector2(hazard.get("direction"))
	RASTER.seek_orb_glyph(glyph, heading, age)
	var head: Vector2 = hazard.global_position
	if points.is_empty() or points[points.size() - 1].distance_to(head) >= POINT_SPACING:
		points.append(head)
		ages.append(age)
	while points.size() > MAX_POINTS or (points.size() > 1 and age - ages[0] > WAKE_SECONDS):
		points.remove_at(0)
		ages.remove_at(0)
	while points.size() > 1 and _wake_length() > MAX_WAKE_LENGTH:
		points.remove_at(0)
		ages.remove_at(0)
	queue_redraw()

func _wake_length() -> float:
	var length: float = 0.0
	for index: int in range(1, points.size()):
		length += points[index].distance_to(points[index - 1])
	return length

func _draw() -> void:
	if _owner() == null: return
	for index: int in range(1, points.size()):
		var p: float = float(index) / float(maxi(1, points.size() - 1))
		var start: Vector2 = to_local(points[index - 1])
		var finish: Vector2 = to_local(points[index])
		var width: float = 0.8 + p * 2.0
		draw_line(start, finish, Color(0.08, 0.025, 0.10, p * 0.7), width + 2.0, true)
		draw_line(start, finish, Color(MAGENTA, p * 0.65), width, true)
	if is_instance_valid(glyph):
		return
	var axis: Vector2 = heading.normalized() if not heading.is_zero_approx() else Vector2.LEFT
	var normal := Vector2(-axis.y, axis.x)
	var pulse: float = 0.92 + sin(age * 11.0) * 0.08
	draw_circle(Vector2.ZERO, 10.5, Color(0.09, 0.025, 0.11, 0.96))
	draw_circle(Vector2.ZERO, 8.0, Color(0.48, 0.10, 0.56, 0.94))
	var angle: float = axis.angle() + age * 4.0
	draw_arc(Vector2.ZERO, 9.0, angle, angle + TAU * 0.76, 24, Color(MAGENTA, 0.95), 1.8, true)
	var glyph := PackedVector2Array([axis * 8.0, axis * 2.0 + normal * 4.5, -axis * 6.0, axis * 2.0 - normal * 4.5])
	draw_colored_polygon(glyph, Color(1.0, 0.80, 0.98, 0.90 * pulse))
	draw_line(-axis * 4.0, axis * 5.0, Color(0.40, 0.04, 0.50), 1.4, true)
	draw_circle(Vector2.ZERO, 2.6, Color(1.0, 0.94, 1.0, pulse))
	for sign_y: float in [-1.0, 1.0]:
		draw_line(normal * sign_y * 6.0 - axis * 2.0, normal * sign_y * 7.5 + axis, Color(MAGENTA.lightened(0.25), 0.9), 1.2, true)

func snapshot() -> Dictionary:
	var hazard: Node2D = _owner()
	return {"owner_id": _owner_id, "head_world": hazard.global_position if hazard != null else Vector2.ZERO, "direction": heading, "age": age, "points": points.size(), "wake_length": _wake_length(), "max_points": MAX_POINTS, "max_wake_length": MAX_WAKE_LENGTH, "max_draw_commands": 30, "lights": 0, "damage_emitters": 0, "impact_emitters": 0}

func restore_source() -> void:
	var hazard: Node2D = _owner()
	if hazard != null: hazard.self_modulate = _original_self_modulate
	_owner_id = 0
	points.clear()
	ages.clear()
	age = 0.0
	visible = false
	if is_in_group(&"boss_orb_vfx"): remove_from_group(&"boss_orb_vfx")

func _exit_tree() -> void:
	restore_source()

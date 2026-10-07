class_name FloatingCombatText
extends Node2D

@export var label: Label
@export var lifetime: float = 0.65
var combat_feedback: CombatFeedback
var _elapsed: float = 0.0
var _velocity: Vector2 = Vector2(0, -110)
var _critical: bool = false
var _presentation_style: StringName = &"legacy"
var _presentation_scale: float = 1.0
var _default_lifetime: float = -1.0
var _random := RandomNumberGenerator.new()


func setup(amount: float, direction: Vector2, feedback: CombatFeedback, critical: bool = false, presentation_style: StringName = &"legacy") -> void:
	if _default_lifetime < 0.0:
		_default_lifetime = lifetime
	lifetime = _default_lifetime
	_critical = critical
	_presentation_style = presentation_style
	_presentation_scale = 1.0
	_elapsed = 0.0
	_random.seed = get_instance_id() * 7919
	label.text = str(roundi(amount)) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount
	label.modulate = Color.WHITE
	label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.07))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 18)
	if critical:
		label.text += "!"
		label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.24))
		label.add_theme_color_override("font_outline_color", Color(0.46, 0.10, 0.06))
		label.add_theme_font_size_override("font_size", 29)
	if presentation_style == &"prologue":
		# The Hub opts into a smaller, restrained profile; dungeon callers keep
		# the existing .65s / font29 critical contract without configuration.
		lifetime = 0.6
		label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.12) if critical else Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_font_size_override("font_size", 18)
		_presentation_scale = 1.4 if critical else 1.0
	_velocity = Vector2(direction.x * 18.0 + _random.randf_range(-16.0, 16.0), _random.randf_range(-120.0, -103.0))
	combat_feedback = feedback
	scale = Vector2.ONE * 1.4 * _presentation_scale
	queue_redraw()


func _process(delta: float) -> void:
	if is_instance_valid(combat_feedback) and combat_feedback.is_frozen():
		return
	_elapsed += delta
	_velocity.y += 240.0 * delta
	position += _velocity * delta
	scale = Vector2.ONE * (1.0 + 0.4 * maxf(0.0, 1.0 - _elapsed / 0.12)) * _presentation_scale
	var shake_angle: float = 0.025 if _presentation_style == &"prologue" else 0.04
	rotation = sin(_elapsed * 75.0) * shake_angle * exp(-_elapsed * 7.0) if _critical else 0.0
	modulate.a = clampf((lifetime - _elapsed) / 0.22, 0.0, 1.0)
	if _elapsed >= lifetime:
		queue_free()


func _draw() -> void:
	if _critical and label != null and _presentation_style != &"prologue":
		# A tiny comic lightning accent, independent of the equipped element.
		draw_polyline(PackedVector2Array([Vector2(29, -17), Vector2(35, -24), Vector2(32, -16), Vector2(37, -17), Vector2(30, -8)]), Color(1.0, 0.79, 0.28), 1.4, true)

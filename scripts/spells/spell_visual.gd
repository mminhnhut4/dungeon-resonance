class_name SpellVisual
extends Node2D
## Small room-owned rings/lightning/death puffs, without external assets.

var color: Color = Color.WHITE
var radius: float = 30.0
var segments: Array[Vector2] = []
var lifetime: float = 0.25
var _age: float = 0.0
var feedback: CombatFeedback
## Opt-in cosmetic receipt. Other rings/lines never acquire a chain label.
## Endpoints are copied world positions; no target survives through this visual.
var chain_ordinal: int = 0


func configure_chain(start: Vector2, end: Vector2, ordinal: int) -> void:
	segments = [start, end]
	chain_ordinal = ordinal if ordinal in [1, 2] else 0


func _ready() -> void:
	add_to_group(&"spell_entities")
	z_index = 20 if chain_ordinal > 0 else 8


func _physics_process(delta: float) -> void:
	if is_instance_valid(feedback) and feedback.is_frozen():
		return
	_age += delta
	modulate.a = 1.0 - _age / lifetime
	if _age >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if segments.is_empty():
		draw_arc(Vector2.ZERO, radius * lerpf(0.3, 1.0, _age / lifetime), 0, TAU, 32, color, 3.0, true)
		for index: int in 6:
			draw_circle(Vector2.from_angle(index * TAU / 6.0) * radius * _age / lifetime, 3.0, color)
	else:
		for index: int in range(0, segments.size() - 1, 2):
			var start: Vector2 = to_local(segments[index])
			var end: Vector2 = to_local(segments[index + 1])
			var middle: Vector2 = (start + end) * 0.5 + Vector2(0, -8)
			draw_polyline(PackedVector2Array([start, middle, end]), color, 3.0, true)
		if chain_ordinal > 0 and segments.size() == 2:
			_draw_chain_endpoint(to_local(segments[0]), to_local(segments[1]))


func _draw_chain_endpoint(start: Vector2, end: Vector2) -> void:
	# Keep the existing immediate hit and .25s fade. Direction and ordinal
	# identify the actual link; they do not claim a particular unlock source.
	var direction: Vector2 = (end - start).normalized()
	if not direction.is_zero_approx():
		var tip: Vector2 = end - direction * 13.0
		var side: Vector2 = direction.orthogonal() * 4.0
		draw_polyline(PackedVector2Array([tip - direction * 7.0 + side, tip, tip - direction * 7.0 - side]), color, 2.0, true)
	# Keep the copied contact point visible; lift its ordinal above the impact
	# burst so the accepted link can be read during the existing short lifetime.
	var marker: Vector2 = end + Vector2(0.0, -34.0)
	draw_circle(end, 3.0, color)
	draw_line(end + Vector2(0.0, -5.0), marker + Vector2(0.0, 11.0), color, 1.5, true)
	draw_circle(marker, 11.0, Color(0.07, 0.05, 0.12, 0.92))
	draw_arc(marker, 11.0, 0.0, TAU, 24, color, 2.0, true)
	var font: Font = ThemeDB.fallback_font
	var label: String = str(chain_ordinal)
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var baseline: Vector2 = marker + Vector2(-width * 0.5, (font.get_ascent(16) - font.get_descent(16)) * 0.5)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

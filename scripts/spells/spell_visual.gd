class_name SpellVisual
extends Node2D
## Small room-owned rings/lightning/death puffs, without external assets.

var color: Color = Color.WHITE
var radius: float = 30.0
var segments: Array[Vector2] = []
var lifetime: float = 0.25
var _age: float = 0.0
var feedback: CombatFeedback


func _ready() -> void:
	add_to_group(&"spell_entities")
	z_index = 8


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

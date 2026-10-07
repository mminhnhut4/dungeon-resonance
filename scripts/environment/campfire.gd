class_name Campfire
extends Node2D

var safe_radius: float = 95.0
var age: float = 0.0
var presentation_skin_active: bool = false


func _ready() -> void:
	add_to_group(&"campfires")
	z_index = 4
	var label := Label.new()
	label.text = "E · LỬA TRẠI"
	label.position = Vector2(-68, -73)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _process(delta: float) -> void:
	age += delta
	queue_redraw()


func _draw() -> void:
	if presentation_skin_active:
		return
	draw_circle(Vector2(0, -10), safe_radius, Color(1.0, 0.55, 0.15, 0.08))
	draw_line(Vector2(-17, -3), Vector2(17, 3), Color(0.55, 0.3, 0.13), 7)
	draw_line(Vector2(-17, 3), Vector2(17, -3), Color(0.55, 0.3, 0.13), 7)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -3), Vector2(-8, -30), Vector2(0, -18), Vector2(6, -42 + sin(age * 8) * 3), Vector2(17, -3)]), Color(1.0, 0.5, 0.08))

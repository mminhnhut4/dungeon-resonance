class_name PlayerAim
extends Node2D
## World-space cursor targeting shared by melee and spell casts.

@export var minimum_aim_distance: float = 4.0
@export var show_direction_marker: bool = true
var target_position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var _cursor_viewport_position: Vector2 = Vector2.ZERO
var _has_cursor_event: bool = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_cursor_viewport_position = (event as InputEventMouse).position
		_has_cursor_event = true


func sample_cursor() -> void:
	var cursor: Vector2 = get_canvas_transform().affine_inverse() * _cursor_viewport_position if _has_cursor_event else get_global_mouse_position()
	if not cursor.is_finite():
		return
	target_position = cursor
	var offset: Vector2 = target_position - global_position
	# Keep the last valid direction when the pointer is exactly on the actor.
	if offset.length_squared() >= minimum_aim_distance * minimum_aim_distance:
		direction = offset.normalized()
	queue_redraw()


func _draw() -> void:
	if not show_direction_marker:
		return
	var local_direction: Vector2 = (to_local(global_position + direction) - to_local(global_position)).normalized()
	var side: Vector2 = local_direction.orthogonal()
	var tip: Vector2 = local_direction * 29.0
	var color := Color(1.0, 0.82, 0.35, 0.9)
	draw_line(local_direction * 17.0, tip, color, 2.0, true)
	draw_line(tip - local_direction * 5.0 + side * 4.0, tip, color, 2.0, true)
	draw_line(tip - local_direction * 5.0 - side * 4.0, tip, color, 2.0, true)

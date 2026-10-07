extends Control

var director: StorytellerDirector


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if director == null or not director.enabled:
		return
	if director.current_incident == &"toxic":
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.28, 0.65, 0.2, 0.16))
	elif director.current_incident == &"eclipse":
		var center: Vector2 = director.player.get_global_transform_with_canvas().origin + Vector2(0, -18)
		for index: int in 48:
			var a: Vector2 = Vector2.from_angle(index * TAU / 48.0)
			var b: Vector2 = Vector2.from_angle((index + 1) * TAU / 48.0)
			draw_colored_polygon(PackedVector2Array([center + a * 175, center + b * 175, center + b * 2200, center + a * 2200]), Color(0.015, 0.01, 0.035, 0.94))

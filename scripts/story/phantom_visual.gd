extends Node2D

var life: float = 8.0
var feedback: CombatFeedback


func _physics_process(delta: float) -> void:
	if is_instance_valid(feedback) and feedback.is_frozen():
		return
	life -= delta
	if life <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var bob: float = sin(life * 6.0) * 9.0
	draw_rect(Rect2(-15, -35 + bob, 30, 35), Color(0.65, 0.35, 1.0, 0.4))
	draw_circle(Vector2(-6, -23 + bob), 3, Color(1, 0.2, 0.7))
	draw_circle(Vector2(6, -23 + bob), 3, Color(1, 0.2, 0.7))

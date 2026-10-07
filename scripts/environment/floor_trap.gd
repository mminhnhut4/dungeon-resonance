extends Node2D

var life: float = 45.0
var spent: bool = false
var source_id: int
var feedback: CombatFeedback


func _ready() -> void:
	add_to_group(&"floor_traps")
	z_index = 4


func _physics_process(delta: float) -> void:
	if is_instance_valid(feedback) and feedback.is_frozen():
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if spent:
		return
	for target: Node in get_tree().get_nodes_in_group(&"enemies"):
		if target.health.current_health <= 0.0 or global_position.distance_to(target.global_position) > 30.0:
			continue
		spent = true
		var event := DamageEvent.new()
		event.source_id = source_id
		event.source_team_id = 1
		event.target_id = target.get_instance_id()
		event.attack_id = CombatIds.next_id()
		event.root_event_id = event.attack_id
		event.hit_window_id = 1
		event.base_damage = 25.0
		event.stun_seconds = 0.5
		target.hurtbox.take_damage(event)
		queue_free()
		break


func _draw() -> void:
	for index: int in 4:
		draw_colored_polygon(PackedVector2Array([Vector2(index * 10 - 20, 0), Vector2(index * 10 - 15, -15), Vector2(index * 10 - 10, 0)]), Color(0.75, 0.8, 0.85))

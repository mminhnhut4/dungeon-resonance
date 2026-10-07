class_name MutantSlime
extends SlimeEnemy

@export var projectile_element: StringName = &"poison"
var ranged_remaining: float = 1.2
var ranged_windup: float = 0.0
var shots_fired: int = 0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not ai_enabled or health.current_health <= 0.0 or statuses.is_stunned() or not is_instance_valid(player):
		return
	if is_instance_valid(combat_feedback) and combat_feedback.is_frozen():
		return
	if ranged_windup > 0.0:
		ranged_windup = maxf(0.0, ranged_windup - delta * statuses.attack_speed_multiplier)
		visual.color = Color(0.75, 0.45, 1.0)
		if ranged_windup <= 0.0:
			fire_projectile()
		return
	ranged_remaining -= delta
	if ranged_remaining <= 0.0 and _can_see_player(300.0):
		ranged_windup = 0.35
		ranged_remaining = 1.8


func fire_projectile() -> void:
	var hazard := EnemyHazard.new()
	hazard.player = player as Player
	if hazard.player == null:
		hazard.free()
		return
	hazard.feedback = combat_feedback
	hazard.source_id = get_instance_id()
	hazard.kind = projectile_element
	hazard.element = projectile_element
	hazard.direction = (player.global_position + Vector2(0, -18) - global_position - Vector2(0, -30)).normalized()
	hazard.position = global_position + Vector2(0, -30)
	get_parent().add_child(hazard)
	shots_fired += 1

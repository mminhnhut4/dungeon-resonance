class_name TrainingDummy
extends CharacterBody2D
## Passive target: shared damage pipeline, hit flash, physical knockback and text.

@export var motor: KnockbackMotor
@export var health: HealthComponent
@export var hurtbox: Hurtbox
@export var body_visual: Polygon2D
@export var stats_label: Label
@export var floating_text_scene: PackedScene
@export var display_name: String = "BIA TẬP"
@export var return_after_seconds: float = 0.7
@export var refill_after_seconds: float = 2.0
@export var death_respawn_seconds: float = 0.8
var combat_feedback: CombatFeedback
var damage_number_spawner: DamageNumberSpawner
var hit_count: int = 0
var total_damage_taken: float = 0.0
var last_damage_event: DamageEvent
var _home_position: Vector2
var _base_color: Color
var _flash_remaining: float = 0.0
var _since_hit: float = 0.0
var _respawn_remaining: float = 0.0
var _measurement_elapsed: float = 0.0


func _ready() -> void:
	_home_position = global_position
	_base_color = body_visual.color
	# One actor-level result stream covers every Hurtbox sharing this resolver.
	hurtbox.damage_resolver.damage_resolved.connect(_on_hit_resolved)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	hurtbox.damage_resolver.status_controller.damage_requested.connect(hurtbox.take_damage)
	_on_health_changed(health.current_health, health.maximum_health)


func _physics_process(delta: float) -> void:
	if is_instance_valid(combat_feedback) and combat_feedback.is_frozen():
		return
	_since_hit += delta
	if hit_count > 0 and _since_hit <= refill_after_seconds:
		_measurement_elapsed += delta
	if health.current_health <= 0.0:
		_respawn_remaining -= delta
		if _respawn_remaining <= 0.0:
			reset_at_home(false)
			return
	elif _since_hit > refill_after_seconds and health.current_health < health.maximum_health:
		health.reset_health()
	if global_position.y > _home_position.y + 120.0:
		reset_at_home(false)
		return
	motor.step(delta, _home_position.x if _since_hit > return_after_seconds else INF)


func _process(delta: float) -> void:
	if is_instance_valid(combat_feedback) and combat_feedback.is_frozen():
		return
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	if _flash_remaining > 0.12:
		body_visual.color = Color.WHITE
	elif _flash_remaining > 0.0:
		body_visual.color = Color(1.0, 0.16, 0.12, 1.0)
	else:
		body_visual.color = _base_color if health.current_health > 0.0 else _base_color.darkened(0.6)
	_on_health_changed(health.current_health, health.maximum_health)


func _on_hit_resolved(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage <= 0.0:
		return
	hit_count += 1
	total_damage_taken += result.actual_damage
	last_damage_event = event
	_since_hit = 0.0
	_flash_remaining = 0.16
	body_visual.color = Color.WHITE
	motor.add_knockback(event.knockback)
	var number_index: int = (hit_count - 1) % 3
	var number_offsets: Array[Vector2] = [Vector2(-22, -130), Vector2(22, -152), Vector2(0, -174)]
	var number_position: Vector2 = global_position + number_offsets[number_index]
	if is_instance_valid(damage_number_spawner):
		damage_number_spawner.spawn_damage(event, result, number_position, combat_feedback)
	else:
		var text := floating_text_scene.instantiate() as FloatingCombatText
		get_parent().add_child(text)
		text.global_position = number_position
		text.setup(result.actual_damage, event.attack_direction, combat_feedback, event.critical)
	_on_health_changed(health.current_health, health.maximum_health)


func _on_health_changed(current: float, maximum: float) -> void:
	stats_label.text = "%s\n%d / %d HP\nDPS %.1f · Tổng %.0f" % [display_name, roundi(current), roundi(maximum), get_dps(), total_damage_taken]


func _on_died() -> void:
	_respawn_remaining = death_respawn_seconds


func reset_at_home(clear_statistics: bool = true) -> void:
	global_position = _home_position
	motor.reset_motion()
	health.reset_health()
	hurtbox.set_invulnerable(false)
	hurtbox.damage_resolver.reset_history()
	hurtbox.damage_resolver.status_controller.clear()
	_flash_remaining = 0.0
	_since_hit = 0.0
	_respawn_remaining = 0.0
	body_visual.color = _base_color
	if clear_statistics:
		hit_count = 0
		total_damage_taken = 0.0
		_measurement_elapsed = 0.0
		last_damage_event = null


func apply_pull(pull_velocity: Vector2) -> void:
	motor.apply_pull(pull_velocity)


func get_dps() -> float:
	return total_damage_taken / maxf(0.1, _measurement_elapsed) if hit_count > 0 else 0.0

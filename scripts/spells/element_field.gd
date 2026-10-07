class_name ElementField
extends Node2D
## Blizzard/miasma share finite area ticks. Ticks cannot spawn child fields.

var executor: SpellExecutor
var context: SpellContext
var age: float = 0.0
var tick_remaining: float = 0.0


func _ready() -> void:
	add_to_group(&"spell_entities")
	z_index = 6


func _physics_process(delta: float) -> void:
	if is_instance_valid(executor.combat_feedback) and executor.combat_feedback.is_frozen():
		return
	age += delta
	tick_remaining -= delta
	if tick_remaining <= 0.0:
		tick_remaining += 0.5
		for target: Hurtbox in executor.nearby_targets(global_position, context.snapshot.effect_radius, context.snapshot.source_team_id):
			var event: DamageEvent = context.snapshot.damage_event(target, CombatIds.next_id(), 2.0, true)
			event.knockback = Vector2.ZERO
			event.consume_poison = false
			event.thermal_shock = false
			target.take_damage(event)
	if age >= context.snapshot.effect_duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, context.snapshot.effect_radius, Color(context.snapshot.color, 0.12))
	draw_arc(Vector2.ZERO, context.snapshot.effect_radius, age, age + TAU * 0.8, 24, context.snapshot.color, 2)

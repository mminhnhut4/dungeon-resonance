class_name PhantomEcho
extends Node2D

var player_id: int
var executor: SpellExecutor
var elapsed: float = 0.0
var damage: float = 22.0
var delay: float = 0.35
var radius: float = 85.0


func _ready() -> void:
	add_to_group(&"spell_entities")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if is_instance_valid(executor.combat_feedback) and executor.combat_feedback.is_frozen():
		return
	elapsed += delta
	if elapsed >= delay:
		var spell := SpellSnapshot.new()
		spell.source_id = player_id
		spell.root_id = CombatIds.next_id()
		spell.origin = global_position
		spell.explosion_damage = damage
		spell.effect_radius = radius
		spell.color = Color(0.65, 0.45, 1.0)
		executor.explode(global_position, SpellContext.new(spell))
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-10, -16, 20, 32), Color(0.65, 0.45, 1.0, 0.7))
	draw_arc(Vector2.ZERO, 30 + elapsed * 100, 0, TAU, 20, Color(0.65, 0.45, 1.0, 0.5), 2)

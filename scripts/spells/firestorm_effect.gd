class_name FirestormEffect
extends Node2D
## One finite vortex per cast; pulls living enemy actors and ends in one blast.

var executor: SpellExecutor
var context: SpellContext
var elapsed: float = 0.0


func _ready() -> void:
	add_to_group(&"spell_entities")
	z_index = 6
	var ink:=CanvasItemMaterial.new(); ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED; material=ink


func _physics_process(delta: float) -> void:
	if executor.combat_feedback.is_frozen():
		return
	elapsed += delta
	var payload: SpellSnapshot = context.snapshot
	for target: Hurtbox in executor.nearby_targets(global_position, payload.effect_radius, payload.source_team_id):
		if target.actor_body.has_method("apply_pull"):
			var offset: Vector2 = global_position - target.actor_body.global_position
			target.actor_body.apply_pull(offset.normalized() * minf(payload.pull_speed, offset.length() * 8.0))
	if elapsed >= payload.effect_duration:
		executor.explode(global_position, context)
		queue_free()
	queue_redraw()


func _draw() -> void:
	if context == null:
		return
	var radius: float = context.snapshot.effect_radius
	var color := Color(1.0, 0.4, 0.08, 0.65)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.2, 0.05, 0.10))
	for strand: int in 3:
		var spiral:=PackedVector2Array()
		for index: int in 25:
			var t: float=index/24.0
			var angle: float=elapsed*6.0+strand*TAU/3.0+t*PI*1.4
			spiral.append(Vector2.from_angle(angle)*radius*(0.12+t*0.84))
		draw_polyline(spiral,Color(0.06,0.025,0.015,0.85),7.0,true)
		draw_polyline(spiral,color,4.0,true)
		draw_polyline(spiral,Color(1.0,0.85,0.35,0.8),1.3,true)

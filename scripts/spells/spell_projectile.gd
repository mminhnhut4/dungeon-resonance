class_name SpellProjectile
extends CharacterBody2D
## Physics-tick projectile: swept World collision, active Hitbox, finite lifespan.

@export var hitbox: Hitbox
var executor: SpellExecutor
var context: SpellContext
var direction: Vector2 = Vector2.RIGHT
var attack_id: int
var _life: float = 2.0
var _hits: int = 0
var _finished: bool = false


func configure(owner_executor: SpellExecutor, cast_context: SpellContext, travel_direction: Vector2) -> void:
	executor = owner_executor
	context = cast_context
	direction = travel_direction.normalized()
	attack_id = CombatIds.next_id()


func _ready() -> void:
	add_to_group(&"spell_entities")
	hitbox.contact_detected.connect(_on_contact)
	var attack := AttackSnapshot.new()
	attack.source_id = context.snapshot.source_id
	attack.source_team_id = context.snapshot.source_team_id
	attack.attack_id = attack_id
	attack.root_event_id = context.snapshot.root_id
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	_life = context.snapshot.lifetime
	if context.snapshot.behavior_id == &"arcane_wave":
		shape.radius = 16.0
	hitbox.activate(attack, shape, Vector2.ZERO)
	rotation = direction.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _finished or executor.combat_feedback.is_frozen():
		return
	_life -= delta
	if _life <= 0.0:
		_finish()
		return
	hitbox.sample_contacts()
	if _finished:
		return
	var collision: KinematicCollision2D = move_and_collide(direction * context.snapshot.speed * delta)
	if collision != null:
		var barrier := collision.get_collider() as EnvironmentBarrier
		if barrier != null:
			executor.primary_hit(barrier.hurtbox, context, attack_id, direction)
		executor.wall_hit(global_position, context)
		_finish()
		return
	hitbox.sample_contacts()


func _on_contact(target: Hurtbox, _attack: AttackSnapshot) -> void:
	if _finished:
		return
	executor.primary_hit(target, context, attack_id, direction)
	_hits += 1
	if context.snapshot.behavior_id == &"firestorm" or context.snapshot.behavior_id == &"overload" or _hits >= context.snapshot.maximum_targets:
		_finish()


func _finish() -> void:
	_finished = true
	hitbox.deactivate()
	queue_free()


func _draw() -> void:
	if context == null:
		return
	var color: Color = context.snapshot.color
	if context.snapshot.behavior_id == &"arcane_wave":
		draw_arc(Vector2(-12, 0), 22, -1.1, 1.1, 14, Color(0.6, 0.75, 1.0), 6)
		return
	if context.snapshot.behavior_id == &"charged_slash":
		draw_colored_polygon(PackedVector2Array([Vector2(-16, -4), Vector2(15, 0), Vector2(-16, 4), Vector2(-8, 0)]), color)
		draw_polyline(PackedVector2Array([Vector2(-10, -2), Vector2(-3, 2), Vector2(10, 0)]), Color.WHITE, 1.5, true)
		return
	if context.snapshot.behavior_id == &"fan_blades":
		draw_colored_polygon(PackedVector2Array([Vector2(-10, -3), Vector2(15, 0), Vector2(-10, 3), Vector2(-7, 0)]), color)
		draw_line(Vector2(-6, 0), Vector2(12, 0), Color(0.9, 0.93, 0.94), 1.2, true)
		return
	draw_line(Vector2(-17, 0), Vector2(3, 0), color.darkened(0.3), 6.0, true)
	draw_circle(Vector2.ZERO, 7.0, color)
	draw_circle(Vector2(2, -1), 3.0, Color.WHITE)

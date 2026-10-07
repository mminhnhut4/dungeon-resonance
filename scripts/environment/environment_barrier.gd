class_name EnvironmentBarrier
extends StaticBody2D
## Both melee and spells enter through a regular enemy-layer Hurtbox.

signal opened
@export var requires_fire: bool = false
@export var size: Vector2 = Vector2(28, 95)
var hits: int = 0
var is_open: bool = false
var health: HealthComponent
var hurtbox: Hurtbox
var body_shape: CollisionShape2D
var resolver: DamageResolver


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	# Preserve supporting terrain when Run.finish pauses the room. Its Hurtbox
	# remains a normal Area2D and is still removed from physics during that pause.
	disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	z_index = 3
	var shape := RectangleShape2D.new()
	shape.size = size
	body_shape = CollisionShape2D.new()
	body_shape.shape = shape
	add_child(body_shape)
	health = HealthComponent.new()
	health.maximum_health = 1000000.0
	add_child(health)
	resolver = DamageResolver.new()
	resolver.health = health
	add_child(resolver)
	hurtbox = Hurtbox.new()
	hurtbox.health = health
	hurtbox.actor_body = self
	hurtbox.damage_resolver = resolver
	hurtbox.team_id = 2
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var receiving_shape := CollisionShape2D.new()
	receiving_shape.shape = shape
	hurtbox.add_child(receiving_shape)
	add_child(hurtbox)
	hurtbox.hit_resolved.connect(_on_hit)
	queue_redraw()


func _on_hit(event: DamageEvent, result: DamageResult) -> void:
	if is_open or result.blocked or event.source_kind == DamageEvent.SourceKind.DOT:
		return
	if requires_fire:
		if event.burn_damage <= 0.0:
			return
	else:
		hits += 1
		if hits < 2 and event.spell_id == &"":
			queue_redraw()
			return
	is_open = true
	body_shape.set_deferred("disabled", true)
	hurtbox.set_invulnerable(true)
	var puff := SpellVisual.new()
	puff.radius = 45.0
	puff.color = Color(1.0, 0.45, 0.12) if requires_fire else Color(0.65, 0.75, 0.95)
	get_parent().add_child(puff)
	puff.global_position = global_position
	opened.emit()
	queue_redraw()


func reset() -> void:
	is_open = false
	hits = 0
	health.reset_health()
	resolver.reset_history()
	body_shape.set_deferred("disabled", false)
	hurtbox.set_invulnerable(false)
	queue_redraw()


func _draw() -> void:
	if is_open:
		return
	var color := Color(0.18, 0.35, 0.17) if requires_fire else Color(0.16, 0.23, 0.29)
	draw_rect(Rect2(-size * 0.5, size), color)
	if requires_fire:
		for index: int in 6:
			var y: float = -size.y * 0.5 + index * size.y / 6
			draw_line(Vector2(-size.x * 0.5, y), Vector2(size.x * 0.5, y + 15), Color(0.6, 0.75, 0.25), 3)
	else:
		for index: int in 4:
			var y: float = -size.y * 0.5 + index * size.y / 4
			draw_line(Vector2(-size.x * 0.5, y), Vector2(size.x * 0.5, y), Color(0.25, 0.31, 0.36), 1)
		if hits > 0:
			draw_line(Vector2(-5, -size.y * 0.3), Vector2(5, size.y * 0.3), Color(0.75, 0.8, 0.9), 2)

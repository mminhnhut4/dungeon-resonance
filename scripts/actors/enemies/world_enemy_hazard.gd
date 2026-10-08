class_name WorldEnemyHazard
extends CharacterBody2D
## Finite room-owned jade projectile / warned slow field, not a proc emitter.

const MAX_HAZARDS: int = 16
const MAX_FIELDS: int = 4
var player: CharacterBody2D
var feedback: CombatFeedback
var source_id: int = 0
var hostile_to_all: bool = false
var kind: StringName = &"jade_bolt"
var direction: Vector2 = Vector2.RIGHT
var age: float = 0.0
var lifetime: float = 3.5
var tick_remaining: float = 0.0
var attack: AttackSnapshot
var hitbox: Hitbox
var trail: PackedVector2Array = []
var emitted_hits: int = 0

func _ready() -> void:
	add_to_group(&"enemy_hazards")
	add_to_group(&"world_enemy_hazards")
	if kind == &"slow_field": add_to_group(&"world_slow_fields")
	z_index = 4
	collision_layer = 0
	collision_mask = 1 if kind == &"jade_bolt" else 0
	var shape := CircleShape2D.new()
	shape.radius = 7.0 if kind == &"jade_bolt" else 64.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	hitbox = ActorCombatRig.hitbox(self, 24 if hostile_to_all else 8)
	hitbox.contact_detected.connect(_hit)
	attack = AttackSnapshot.new()
	attack.source_id = source_id
	attack.source_team_id = 0 if hostile_to_all else 2
	attack.attack_id = CombatIds.next_id()
	attack.root_event_id = attack.attack_id
	if kind == &"jade_bolt": hitbox.activate(attack, shape, Vector2.ZERO)
	lifetime = 3.5 if kind == &"jade_bolt" else 3.0
	preload("res://scripts/presentation/depth_enemy_skill_art.gd").attach_to(self)

func _physics_process(delta: float) -> void:
	if is_instance_valid(feedback) and feedback.is_frozen(): return
	var source: Node = instance_from_id(source_id) as Node if is_instance_id_valid(source_id) else null
	if source == null or source.get("health") == null or source.health.current_health <= 0.0 or not is_instance_valid(player) or player.health.current_health <= 0.0:
		queue_free()
		return
	age += delta
	if age >= lifetime:
		queue_free()
		return
	if kind == &"jade_bolt":
		hitbox.sample_contacts()
		if is_queued_for_deletion(): return
		if move_and_collide(direction * 235.0 * delta) != null:
			queue_free()
			return
		hitbox.sample_contacts()
		trail.append(global_position)
		if trail.size() > 10: trail.remove_at(0)
	else:
		tick_remaining -= delta
		if age >= 0.45 and tick_remaining <= 0.0:
			tick_remaining = 0.65
			if global_position.distance_to(player.global_position) < 64.0:
				var event: DamageEvent = _event(player.hurtbox, CombatIds.next_id())
				event.base_damage = 2.0
				event.slow_multiplier = 0.55
				event.slow_seconds = 0.7
				player.hurtbox.take_damage(event)
	queue_redraw()

func _event(target: Hurtbox, id: int) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = source_id
	event.source_team_id = attack.source_team_id
	event.target_id = target.get_actor_id()
	event.attack_id = id
	event.root_event_id = attack.root_event_id
	event.hit_window_id = 1
	event.attack_direction = direction
	event.allow_resonance = false
	return event

func _hit(target: Hurtbox, _snapshot: AttackSnapshot) -> void:
	var event: DamageEvent = _event(target, attack.attack_id)
	event.base_damage = 12.0
	event.poison_stacks = 1
	event.poison_percent = 0.006
	event.poison_seconds = 3.0
	event.cosmetic_element = &"poison"
	var result: DamageResult = target.take_damage(event)
	if not result.blocked: emitted_hits += 1
	if is_instance_valid(feedback): feedback.on_hit_confirmed(event, result)
	hitbox.deactivate()
	queue_free()

func _draw() -> void:
	if kind == &"slow_field":
		var color := Color(0.35, 0.94, 0.66, 0.48 if age < 0.45 else 0.85)
		draw_circle(Vector2.ZERO, 64, Color(color, 0.10))
		draw_arc(Vector2.ZERO, 64, age, age + TAU, 32, color, 2)
		draw_arc(Vector2.ZERO, 43, -age, TAU - age, 24, color, 1)
		return
	for index: int in range(1, trail.size()):
		draw_line(to_local(trail[index - 1]), to_local(trail[index]), Color(0.3, 0.96, 0.52, float(index) / trail.size() * 0.7), 3)
	draw_circle(Vector2.ZERO, 7, Color(0.42, 1, 0.62))
	draw_circle(Vector2.ZERO, 3, Color(0.88, 1, 0.86))

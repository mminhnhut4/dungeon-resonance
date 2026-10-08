class_name EnemyHazard
extends CharacterBody2D
## Homing orbs and ground waves share a finite enemy DamageEvent emitter.

var player: Player
var feedback: CombatFeedback
var source_id: int
var kind: StringName = &"orb"
var direction := Vector2.LEFT
var life: float = 5.0
var hitbox: Hitbox
var attack: AttackSnapshot
var element: StringName = &""
var hit_reaction: StringName = &""
var reaction_impulse: Vector2 = Vector2.ZERO
const BOSS_ORB_VISUAL: Script = preload("res://scripts/presentation/boss_orb_vfx.gd")


func _ready() -> void:
	add_to_group(&"enemy_hazards")
	collision_layer = 0
	collision_mask = 1
	z_index = 6
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	hitbox = ActorCombatRig.hitbox(self, 8)
	hitbox.contact_detected.connect(_hit)
	attack = AttackSnapshot.new()
	attack.source_id = source_id
	attack.source_team_id = 2
	attack.attack_id = CombatIds.next_id()
	attack.root_event_id = attack.attack_id
	hitbox.activate(attack, shape, Vector2.ZERO)
	if kind == &"orb" and is_instance_valid(player):
		direction = (player.global_position + Vector2(0, -18) - global_position).normalized()
	if kind == &"orb" and source_id != 0 and is_instance_id_valid(source_id):
		var source: Node = instance_from_id(source_id) as Node
		if source is BossGolem and not source.is_queued_for_deletion() and get_tree().get_nodes_in_group(&"boss_orb_vfx").size() < BOSS_ORB_VISUAL.MAX_VISUALS:
			var visual: Node2D = BOSS_ORB_VISUAL.new()
			add_child(visual)
			visual.bind(self)


func _physics_process(delta: float) -> void:
	if is_instance_valid(feedback) and feedback.is_frozen():
		return
	life -= delta
	if life <= 0.0 or not is_instance_valid(player) or player.health.current_health <= 0.0:
		queue_free()
		return
	if kind == &"orb":
		var target: float = (player.global_position + Vector2(0, -18) - global_position).angle()
		direction = Vector2.from_angle(rotate_toward(direction.angle(), target, delta * 1.2))
	hitbox.sample_contacts()
	if is_queued_for_deletion():
		return
	if move_and_collide(direction * (190.0 if kind == &"orb" else 380.0) * delta) != null:
		queue_free()
	else:
		hitbox.sample_contacts()
	queue_redraw()


func _hit(target: Hurtbox, _snapshot: AttackSnapshot) -> void:
	var event := DamageEvent.new()
	event.source_id = source_id
	event.source_team_id = 2
	event.target_id = target.get_actor_id()
	event.attack_id = attack.attack_id
	event.root_event_id = attack.root_event_id
	event.hit_window_id = 1
	event.base_damage = 15.0 if kind == &"orb" else 22.0
	event.attack_direction = direction
	event.hit_reaction = hit_reaction
	event.knockback = reaction_impulse
	if element == &"poison":
		event.poison_stacks = 1
		event.poison_seconds = 4.0
	elif element == &"ice":
		event.slow_multiplier = 0.6
		event.slow_seconds = 2.0
		event.freeze_points = 35.0
	target.take_damage(event)
	hitbox.deactivate()
	queue_free()


func _draw() -> void:
	if kind == &"orb":
		draw_circle(Vector2.ZERO, 10, Color(0.95, 0.45, 1.0))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-15, 10), Vector2(-8, -13), Vector2(0, 0), Vector2(8, -18), Vector2(15, 10)]), Color(1.0, 0.55, 0.16))

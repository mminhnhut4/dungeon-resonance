class_name SpellExecutor
extends Node2D
## Finite spell execution; child effects never invoke this proc path recursively.

@export var projectile_scene: PackedScene
@export var firestorm_scene: PackedScene
@export var maximum_spell_entities: int = 64
var combat_feedback: CombatFeedback
var spawned_projectiles: int = 0
var chain_hit_count: int = 0
var explosion_count: int = 0
signal presentation_burst(position: Vector2, color: Color, element: StringName)
signal presentation_cast(position: Vector2)
signal presentation_contact(position: Vector2, color: Color, direction: Vector2)


func spawn_cast(snapshot: SpellSnapshot) -> void:
	presentation_cast.emit(snapshot.origin)
	var context := SpellContext.new(snapshot)
	var angles: Array[float] = [0.0]
	if snapshot.behavior_id == &"charged_slash":
		angles.assign([-0.25, 0.0, 0.25])
	elif snapshot.behavior_id == &"fan_blades":
		angles.assign([-0.20, 0.0, 0.20])
	for angle: float in angles:
		if get_tree().get_nodes_in_group(&"spell_entities").size() >= maximum_spell_entities:
			break
		var projectile := projectile_scene.instantiate() as SpellProjectile
		projectile.configure(self, context, snapshot.direction.rotated(angle))
		add_child(projectile)
		projectile.global_position = snapshot.origin
		spawned_projectiles += 1


func primary_hit(target: Hurtbox, context: SpellContext, attack_id: int, travel_direction: Vector2) -> void:
	var target_id: int = target.get_actor_id()
	if context.primary_targets.has(target_id):
		return
	context.primary_targets[target_id] = true
	context.visited_targets[target_id] = true
	var payload: SpellSnapshot = context.snapshot
	var event: DamageEvent = payload.damage_event(target, attack_id, payload.damage)
	event.attack_direction = travel_direction
	event.knockback = (travel_direction * 100.0 + Vector2(0, -45)) * payload.knockback_multiplier
	var result: DamageResult = target.take_damage(event)
	if result.blocked:
		return
	if is_instance_valid(combat_feedback):
		combat_feedback.on_hit_confirmed(event, result)
	if not context.effect_triggered:
		context.effect_triggered = true
		if payload.behavior_id == &"firestorm":
			spawn_firestorm(target.global_position, context)
		elif payload.behavior_id == &"overload":
			explode(target.global_position, context, true)
		elif payload.behavior_id in [&"blizzard", &"miasma_cloud"]:
			spawn_field(target.global_position, context)
		elif payload.behavior_id == &"combustion":
			explode(target.global_position, context)
		elif payload.behavior_id == &"frost_venom":
			for nearby: Hurtbox in nearby_targets(target.global_position, payload.effect_radius, payload.source_team_id):
				if nearby == target or context.visited_targets.has(nearby.get_actor_id()):
					continue
				context.visited_targets[nearby.get_actor_id()] = true
				var spread: DamageEvent = payload.damage_event(nearby, CombatIds.next_id(), payload.damage * 0.5, true)
				spread.knockback = Vector2.ZERO
				nearby.take_damage(spread)
				if context.visited_targets.size() >= 3:
					break
	chain_from(target.global_position, context)


func wall_hit(position: Vector2, context: SpellContext) -> void:
	presentation_contact.emit(position, context.snapshot.color, context.snapshot.direction)
	if context.effect_triggered:
		return
	context.effect_triggered = true
	if context.snapshot.behavior_id == &"firestorm":
		spawn_firestorm(position, context)
	elif context.snapshot.behavior_id == &"overload":
		explode(position, context, true)
	elif context.snapshot.behavior_id in [&"blizzard", &"miasma_cloud"]:
		spawn_field(position, context)


func nearby_targets(position: Vector2, radius: float, team: int) -> Array[Hurtbox]:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position)
	query.collision_mask = 16 if team == 1 else 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var contacts: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query, 64)
	var targets: Array[Hurtbox] = []
	var seen: Dictionary[int, bool] = {}
	for contact: Dictionary in contacts:
		var target := contact.collider as Hurtbox
		if target == null or target.health.current_health <= 0.0 or seen.has(target.get_actor_id()):
			continue
		seen[target.get_actor_id()] = true
		targets.append(target)
	targets.sort_custom(func(a: Hurtbox, b: Hurtbox) -> bool: return a.global_position.distance_squared_to(position) < b.global_position.distance_squared_to(position))
	return targets


func chain_from(position: Vector2, context: SpellContext) -> void:
	var previous: Vector2 = position
	while context.remaining_chain > 0:
		var next: Hurtbox
		for target: Hurtbox in nearby_targets(previous, context.snapshot.chain_radius, context.snapshot.source_team_id):
			if not context.visited_targets.has(target.get_actor_id()):
				next = target
				break
		if next == null:
			break
		context.visited_targets[next.get_actor_id()] = true
		context.remaining_chain -= 1
		var event: DamageEvent = context.snapshot.damage_event(next, CombatIds.next_id(), context.snapshot.damage * 0.6, true)
		event.knockback = Vector2.ZERO
		var result: DamageResult = next.take_damage(event)
		if not result.blocked:
			chain_hit_count += 1
			var visual := SpellVisual.new()
			visual.color = Color(0.8, 0.65, 1.0)
			visual.segments = [previous, next.global_position]
			visual.feedback = combat_feedback
			add_child(visual)
		previous = next.global_position


func spawn_firestorm(position: Vector2, context: SpellContext) -> void:
	if get_tree().get_nodes_in_group(&"spell_entities").size() >= maximum_spell_entities:
		return
	var storm := firestorm_scene.instantiate() as FirestormEffect
	storm.executor = self
	storm.context = context
	add_child(storm)
	storm.global_position = position


func explode(position: Vector2, context: SpellContext, critical: bool = false) -> void:
	explosion_count += 1
	var snapshot: SpellSnapshot = context.snapshot
	presentation_burst.emit(position, snapshot.color, &"fire" if snapshot.burn_damage > 0 or snapshot.behavior_id in [&"firestorm", &"overload", &"combustion"] else &"lightning")
	var id: int = CombatIds.next_id()
	var delivered: int = 0
	for target: Hurtbox in nearby_targets(position, snapshot.effect_radius, snapshot.source_team_id):
		if delivered >= 16:
			break
		var event: DamageEvent = snapshot.damage_event(target, id, snapshot.explosion_damage, true)
		event.critical = critical
		event.stun_seconds = snapshot.stun_seconds if critical else 0.0
		if event.stun_seconds > 0.0:
			event.status_ids.append(&"stun")
		event.attack_direction = (target.global_position - position).normalized()
		event.knockback = event.attack_direction * 160.0 + Vector2(0, -65)
		var result: DamageResult = target.take_damage(event)
		if is_instance_valid(combat_feedback):
			combat_feedback.on_hit_confirmed(event, result)
		delivered += 1
	var visual := SpellVisual.new()
	visual.color = snapshot.color
	visual.radius = snapshot.effect_radius
	visual.feedback = combat_feedback
	add_child(visual)
	visual.global_position = position


func clear_entities() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


func spawn_field(position: Vector2, context: SpellContext) -> void:
	if get_tree().get_nodes_in_group(&"spell_entities").size() >= maximum_spell_entities:
		return
	var field := ElementField.new()
	field.executor = self
	field.context = context
	add_child(field)
	field.global_position = position

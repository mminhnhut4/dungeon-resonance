class_name ActorCombatRig
extends RefCounted
## Small scene-construction helper; no retained actors or shared runtime state.

static func build(actor: Node2D, hp: float, size: Vector2, offset: Vector2, team: int) -> Dictionary:
	var health := HealthComponent.new()
	health.name = "Health"
	health.maximum_health = hp
	actor.add_child(health)
	var statuses := ElementStatusController.new()
	statuses.name = "Statuses"
	statuses.health = health
	actor.add_child(statuses)
	var resolver := DamageResolver.new()
	resolver.name = "DamageResolver"
	resolver.health = health
	resolver.status_controller = statuses
	actor.add_child(resolver)
	var hurtbox := Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.actor_body = actor
	hurtbox.health = health
	hurtbox.damage_resolver = resolver
	hurtbox.team_id = team
	hurtbox.collision_layer = 16 if team == 2 else 8
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.position = offset
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	hurtbox.add_child(collider)
	actor.add_child(hurtbox)
	statuses.damage_requested.connect(hurtbox.take_damage)
	return {"health": health, "statuses": statuses, "hurtbox": hurtbox}


static func hitbox(actor: Node2D, mask: int) -> Hitbox:
	var area := Hitbox.new()
	area.name = "AttackHitbox"
	area.collision_mask = mask
	area.collision_layer = 0
	area.monitoring = false
	area.monitorable = false
	var shape := CollisionShape2D.new()
	shape.disabled = true
	area.collision_shape = shape
	area.add_child(shape)
	actor.add_child(area)
	return area

class_name Hurtbox
extends Area2D
## Receiving area, separate from the body's world collision.

signal damage_received(event: DamageEvent)
signal hit_resolved(event: DamageEvent, result: DamageResult)

@export var health: HealthComponent
@export var damage_resolver: DamageResolver
@export var actor_body: Node2D
@export var team_id: int = 0
var invulnerable: bool = false
var sanctuary_safe: bool = false


func set_invulnerable(value: bool) -> void:
	if invulnerable == value:
		return
	invulnerable = value
	# Physics changes are deferred; the logical damage gate is immediate.
	set_deferred("monitorable", not value)


func receive_damage(event: DamageEvent) -> bool:
	return not take_damage(event).blocked


func get_actor_id() -> int:
	return actor_body.get_instance_id() if actor_body != null else get_parent().get_instance_id()


func take_damage(event: DamageEvent) -> DamageResult:
	var result := DamageResult.new()
	if sanctuary_safe or invulnerable:
		result.block_reason = &"invulnerable"
	elif team_id != 0 and event.source_team_id == team_id:
		result.block_reason = &"friendly_fire"
	elif damage_resolver == null:
		result.block_reason = &"missing_resolver"
	else:
		damage_received.emit(event)
		result = damage_resolver.resolve(event)
	if not result.block_reason.is_empty():
		result.blocked = true
	hit_resolved.emit(event, result)
	return result


func take_internal_damage(event: DamageEvent) -> DamageResult:
	# Body DOT/self-penalties bypass contact immunity but retain validation/dedup.
	var result: DamageResult = damage_resolver.resolve(event)
	hit_resolved.emit(event, result)
	return result

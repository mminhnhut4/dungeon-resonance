class_name DamageResolver
extends Node
## Shared pipeline: validate hit, defenses, damage/status, then result notification.

signal damage_resolved(event: DamageEvent, result: DamageResult)

@export var health: HealthComponent
@export var status_controller: StatusController
## Runtime defense. The resolver applies it once to every validated damage kind.
var armor_rating: float = 0.0
var _recent_hits: Dictionary[String, bool] = {}


func resolve(event: DamageEvent) -> DamageResult:
	var result := DamageResult.new()
	if health == null or event.source_id <= 0 or event.attack_id <= 0 or event.hit_window_id <= 0:
		result.block_reason = &"invalid_event"
	elif event.target_id != health.get_parent().get_instance_id() or event.source_id == event.target_id:
		result.block_reason = &"invalid_target"
	elif not is_finite(event.base_damage) or event.base_damage <= 0.0:
		result.block_reason = &"invalid_damage"
	elif health.current_health <= 0.0:
		result.block_reason = &"dead"
	else:
		var key: String = "%d:%d:%d" % [event.source_id, event.attack_id, event.hit_window_id]
		if _recent_hits.has(key):
			result.block_reason = &"duplicate"
		else:
			# Contact emitters also keep their full attack-lifetime hit registry.
			# This bounded receiver cache protects recent duplicate deliveries.
			if _recent_hits.size() >= 256:
				_recent_hits.erase(_recent_hits.keys()[0])
			_recent_hits[key] = true
			var amount: float = status_controller.modify_damage(event) if status_controller != null else event.base_damage
			# Work on the local resolved amount, never overwrite a shared DamageEvent.
			var armor: float = maxf(0.0, armor_rating) if is_finite(armor_rating) else 0.0
			amount *= 100.0 / (100.0 + armor)
			result.actual_damage = health.apply_damage(amount)
			result.killed = health.current_health <= 0.0
			if not result.killed and result.actual_damage > 0.0 and status_controller != null:
				status_controller.apply(event)
	result.blocked = result.actual_damage <= 0.0
	damage_resolved.emit(event, result)
	return result


func reset_history() -> void:
	_recent_hits.clear()

class_name EnemyShieldHealth
extends HealthComponent
## DamageResolver still validates/armors/deduplicates before this damage sink.
## Floating damage counts absorbed shield plus lost HP; statuses can break shields.

signal shield_changed(current: float, maximum: float)
@export var maximum_shield: float = 75.0
var current_shield: float = 0.0

func reset_health() -> void:
	current_shield = maximum_shield
	super.reset_health()
	shield_changed.emit(current_shield, maximum_shield)

func apply_damage(amount: float) -> float:
	if current_health <= 0.0 or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var absorbed: float = minf(amount, current_shield)
	current_shield -= absorbed
	if absorbed > 0.0:
		shield_changed.emit(current_shield, maximum_shield)
	return absorbed + super.apply_damage(amount - absorbed)


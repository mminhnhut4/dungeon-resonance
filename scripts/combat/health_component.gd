class_name HealthComponent
extends Node
## Runtime health belongs to each actor, never to a shared Definition Resource.

signal health_changed(current: float, maximum: float)
signal died

@export var maximum_health: float = 100.0
var current_health: float
var healing_multiplier: float = 1.0
## Optional runtime safety floor. Ordinary actors keep zero; Hub Player uses one.
var minimum_health: float = 0.0


func _ready() -> void:
	reset_health()


func reset_health() -> void:
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)


func apply_damage(amount: float) -> float:
	if current_health <= 0.0 or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var floor_value: float = clampf(minimum_health, 0.0, maximum_health) if is_finite(minimum_health) else 0.0
	var actual: float = minf(amount, maxf(0.0, current_health - floor_value))
	current_health = maxf(0.0, current_health - actual)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		died.emit()
	return actual


func heal(amount: float) -> float:
	if current_health <= 0.0 or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var actual: float = minf(amount * healing_multiplier, maximum_health - current_health)
	current_health += actual
	health_changed.emit(current_health, maximum_health)
	return actual

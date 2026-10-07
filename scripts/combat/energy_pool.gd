class_name EnergyPool
extends Node
## Optional in old test fixtures; enabled by the run and gear playground.

@export var enabled: bool = false
@export var maximum: float = 100.0
@export var regeneration: float = 24.0
var current: float = 100.0
var regeneration_delay: float = 0.0
var feedback: CombatFeedback


func can_spend(amount: float) -> bool:
	return not enabled or current >= amount


func spend(amount: float) -> bool:
	if not can_spend(amount):
		return false
	if enabled:
		current = maxf(0.0, current - amount)
		regeneration_delay = 0.45
	return true


func _physics_process(delta: float) -> void:
	if is_instance_valid(feedback) and feedback.is_frozen():
		return
	regeneration_delay = maxf(0.0, regeneration_delay - delta)
	if regeneration_delay <= 0.0:
		current = minf(maximum, current + regeneration * delta)


func reset() -> void:
	current = maximum
	regeneration_delay = 0.0

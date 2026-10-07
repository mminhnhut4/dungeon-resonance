class_name SafeHubComponent
extends Node
## Health owns the damage clamp, covering direct health penalties as well as DOT.

var health: HealthComponent
var _previous_floor: float = 0.0

func initialize(target: HealthComponent) -> void:
	health = target
	_previous_floor = health.minimum_health
	health.minimum_health = 1.0

func _exit_tree() -> void:
	if is_instance_valid(health):
		health.minimum_health = _previous_floor


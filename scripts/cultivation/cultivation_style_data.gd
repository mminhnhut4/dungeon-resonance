class_name CultivationStyleData
extends Resource
## Immutable candidate tuning; persistence/unlocks belong to progression owner.
@export var id: StringName
@export var display_name: String
@export var energy_cost: float = 12.0
@export var cooldown: float = 3.0
@export var windup: float = 0.08
@export var active: float = 0.09
@export var recovery: float = 0.28
@export var damage: float = 10.0
@export var radius: float = 68.0
@export var tint := Color(0.5, 0.95, 1.0)
@export var counter_window: float = 0.75
@export var placement_range: float = 190.0
@export var activation_range: float = 260.0
@export var maximum_targets: int = 1
@export var mark_arm_seconds: float = 0.35
@export var mark_lifetime: float = 4.0
@export var pulse_cost: float = 8.0
@export var pulse_windup: float = 0.18
@export var pulse_active: float = 0.12
@export var slow_multiplier: float = 1.0
@export var slow_seconds: float = 0.0

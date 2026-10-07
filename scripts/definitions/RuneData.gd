class_name RuneData
extends RuneDefinition
## Authored modifiers; no cooldowns or mutable stacks live in this Resource.

@export var burn_damage: float = 0.0
@export var burn_duration: float = 3.0
@export var burn_interval: float = 0.5
@export var projectile_speed_multiplier: float = 1.0
@export var knockback_multiplier: float = 1.0
@export var maximum_pierced_targets: int = 1
@export var chain_targets: int = 0
@export var chain_radius: float = 150.0
@export var slow_multiplier: float = 1.0
@export var slow_seconds: float = 0.0
@export var freeze_points: float = 0.0
@export var poison_stacks: int = 0
@export var poison_percent: float = 0.01
@export var poison_seconds: float = 4.0

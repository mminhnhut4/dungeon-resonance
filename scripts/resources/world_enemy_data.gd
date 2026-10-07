class_name WorldEnemyData
extends Resource
## Immutable moveset definition. All clocks, HP, shields and target locks are per actor.

enum Moveset { SABER_SWEEP, BAT_DIVE, PHASE_THRUST, SHIELD_FIELD }
@export var id: StringName
@export var display_name: String
@export var moveset: Moveset = Moveset.SABER_SWEEP
@export var maximum_hp: float = 90.0
@export var shield_hp: float = 0.0
@export var body_size: Vector2 = Vector2(32, 50)
@export var visual_height: float = 60.0
@export var patrol_speed: float = 30.0
@export var chase_speed: float = 55.0
@export var aggro_radius: float = 430.0
@export var attack_range: float = 86.0
@export var windup: float = 0.45
@export var active: float = 0.18
@export var recovery: float = 0.55
@export var cooldown: float = 0.8
@export var attack_damage: float = 24.0
@export var flying: bool = false


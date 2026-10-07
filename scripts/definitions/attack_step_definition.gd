class_name AttackStepDefinition
extends Resource
## Authored combo step. Each step declares its own attack commit boundary.

@export var id: StringName
@export var windup_seconds: float = 0.1
@export var active_seconds: float = 0.1
@export var recovery_seconds: float = 0.2
@export var hitbox_shape: Shape2D
## Local offset from the chest-level WeaponSocket, rotated toward the cursor.
@export var hitbox_offset: Vector2 = Vector2(36, 0)
@export var damage_multiplier: float = 1.0
## X is push along the aim direction; Y is additional world-space vertical lift.
@export var knockback: Vector2 = Vector2(140, -60)
## Zero keeps legacy authored rectangular hitboxes. New movesets use reach/angle.
@export var reach: float = 0.0
@export_range(0.0, 180.0) var sweep_angle_degrees: float = 0.0
@export var motion: StringName = &"slash"
@export var stagger_force: float = 0.0
@export var super_armor: bool = false
@export var lunge_speed: float = 0.0
@export var lunge_seconds: float = 0.0
@export var pull_force: float = 0.0

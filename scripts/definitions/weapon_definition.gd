class_name WeaponDefinition
extends Resource
## Shared authored data. There are no weapon level or ATK upgrade fields.

@export var id: StringName
@export var display_name: String
@export var attack_kind: StringName = &"melee"
## Cosmetic motion profile, sampled from this immutable authored family.
@export var visual_profile: StringName = &"legacy"
@export_enum("auto", "swordsman", "mage") var visual_archetype: String = "auto"
@export var base_damage: float = 10.0
@export var combo_steps: Array[AttackStepDefinition] = []
@export var combo_window_seconds: float = 0.22
@export var projectile_scene: PackedScene
@export_range(0.0, 1.0) var critical_chance: float = 0.0
@export var critical_multiplier: float = 1.75
@export var projectile_pattern: StringName = &"basic"
@export var projectile_speed: float = 560.0
@export var projectile_lifetime: float = 2.0
@export var projectile_targets: int = 1

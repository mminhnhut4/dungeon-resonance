class_name ResonanceDefinition
extends Resource
## Exact recipe including repeated rune IDs. Resolver ignores order, not count.

@export var id: StringName
@export var display_name: String
@export var recipe_rune_ids: Array[StringName] = []
@export var effect_scene: PackedScene
@export var maximum_targets: int = 3
@export var maximum_procs_per_attack: int = 1
@export var energy_cost: float = 20.0
@export var cooldown_seconds: float = 3.0
@export var behavior_id: StringName = &"basic"
@export var base_damage: float = 14.0
@export var projectile_speed: float = 560.0
@export var windup_seconds: float = 0.12
@export var recovery_seconds: float = 0.12
@export var effect_radius: float = 110.0
@export var effect_duration: float = 1.0
@export var pull_speed: float = 180.0
@export var explosion_damage: float = 24.0
@export var stun_seconds: float = 0.0
@export var slow_multiplier: float = 1.0
@export var slow_seconds: float = 0.0
@export var freeze_points: float = 0.0
@export var poison_stacks: int = 0
@export var armor_break_seconds: float = 0.0
@export var thermal_shock: bool = false
@export var consume_poison: bool = false
@export var interrupt_seconds: float = 0.0

class_name DamageEvent
extends RefCounted
## Shared damage request for weapon, spell, DOT and environmental damage.

enum SourceKind { DIRECT, RESONANCE, DOT, ENVIRONMENT }

var source_id: int
var target_id: int
var attack_id: int
var hit_window_id: int
var root_event_id: int
var parent_event_id: int
var source_kind: SourceKind = SourceKind.DIRECT
var base_damage: float
var source_team_id: int = 0
var attack_direction: Vector2 = Vector2.RIGHT
var attack_origin: Vector2 = Vector2.ZERO
var aim_position: Vector2 = Vector2.ZERO
## World-space velocity impulse in px/s. Direction is baked in at commit.
var knockback: Vector2 = Vector2.ZERO
var hit_position: Vector2 = Vector2.ZERO
var allow_resonance: bool = false
var status_ids: Array[StringName] = []
var burn_damage: float = 0.0
var burn_duration: float = 0.0
var burn_interval: float = 0.5
var stun_seconds: float = 0.0
var critical: bool = false
var stagger_force: float = 0.0
var spell_id: StringName = &""
var heavy_hit: bool = false
## Explicit source-authored reaction; an empty value preserves legacy hit behavior.
## Supported Player poses: flinch, knockback, kneel, thrown. Never infer from heavy_hit.
var hit_reaction: StringName = &""
## Committed appearance only; the resolver never uses these fields for damage.
var cosmetic_quality: int = 0
var cosmetic_element: StringName = &""
var cosmetic_tint: Color = Color.WHITE
var cosmetic_combo_index: int = 0
var ignore_damage_grace: bool = false
var melee_hit: bool = false
var physical_damage: bool = false
var slow_multiplier: float = 1.0
var slow_seconds: float = 0.0
var freeze_points: float = 0.0
var poison_stacks: int = 0
var poison_percent: float = 0.01
var poison_seconds: float = 4.0
var armor_break_seconds: float = 0.0
var thermal_shock: bool = false
var consume_poison: bool = false
var interrupt_seconds: float = 0.0

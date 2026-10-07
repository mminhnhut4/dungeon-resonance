class_name AttackSnapshot
extends RefCounted
## Frozen-by-convention payload at commit; changing runes cannot change an in-flight hit.

var source_id: int
var attack_id: int
var root_event_id: int
var weapon_definition: WeaponDefinition
var resonance_definition: ResonanceDefinition
var base_damage: float
var hit_window_id: int = 1
var source_team_id: int = 1
var attack_direction: Vector2 = Vector2.RIGHT
var attack_origin: Vector2 = Vector2.ZERO
var aim_position: Vector2 = Vector2.ZERO
var knockback: Vector2 = Vector2.ZERO
var proc_budget: int = 0
var burn_damage: float = 0.0
var burn_duration: float = 0.0
var burn_interval: float = 0.5
var stagger_force: float = 0.0
var critical: bool = false
var slow_multiplier: float = 1.0
var slow_seconds: float = 0.0
var freeze_points: float = 0.0
var poison_stacks: int = 0
var poison_percent: float = 0.01
var poison_seconds: float = 4.0
## Presentation values are sampled once with the attack, never from live gear.
var cosmetic_quality: int = 0
var cosmetic_element: StringName = &"physical"
var cosmetic_tint: Color = Color(0.78, 0.82, 0.8)
var cosmetic_combo_index: int = 0


static func tint_for_element(element: StringName) -> Color:
	match element:
		&"fire": return Color(1.0, 0.4, 0.08)
		&"ice": return Color(0.35, 0.85, 1.0)
		&"poison": return Color(0.55, 1.0, 0.26)
		&"lightning": return Color(0.7, 0.52, 1.0)
		&"wind": return Color(0.6, 0.9, 0.82)
	return Color(0.78, 0.82, 0.8)

class_name SpellSnapshot
extends RefCounted
## Scalar payload frozen at cast commit; shared budgets belong to SpellContext.

var source_id: int
var root_id: int
var source_team_id: int = 1
var origin: Vector2
var target_position: Vector2
var direction: Vector2
var recipe_id: StringName
var behavior_id: StringName
var damage: float = 14.0
var speed: float = 560.0
var lifetime: float = 2.0
var windup: float = 0.12
var recovery: float = 0.12
var maximum_targets: int = 1
var burn_damage: float = 0.0
var burn_duration: float = 0.0
var burn_interval: float = 0.5
var knockback_multiplier: float = 1.0
var chain_targets: int = 0
var chain_radius: float = 150.0
var effect_radius: float = 110.0
var effect_duration: float = 1.0
var pull_speed: float = 180.0
var explosion_damage: float = 24.0
var stun_seconds: float = 0.0
var color: Color = Color(0.5, 0.75, 1.0)
var empowered: bool = false
var cosmetic_quality: int = 0
var cosmetic_element: StringName = &"physical"
var weapon_family_visual: bool = false
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


func damage_event(target: Hurtbox, attack_id: int, amount: float, child: bool = false) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = source_id
	event.source_team_id = source_team_id
	event.target_id = target.get_actor_id()
	event.attack_id = attack_id
	event.hit_window_id = 1
	event.root_event_id = root_id
	event.parent_event_id = root_id if child else 0
	event.source_kind = DamageEvent.SourceKind.RESONANCE if child else DamageEvent.SourceKind.DIRECT
	event.allow_resonance = false
	event.attack_origin = origin
	event.aim_position = target_position
	event.attack_direction = direction
	event.knockback = (direction * 100.0 + Vector2(0, -45)) * knockback_multiplier
	event.hit_position = target.global_position
	event.base_damage = amount
	event.spell_id = recipe_id
	event.critical = empowered
	event.cosmetic_quality = cosmetic_quality
	event.cosmetic_element = cosmetic_element
	event.cosmetic_tint = color
	event.stagger_force = 35.0 if recipe_id != &"" and recipe_id != &"basic" and not recipe_id.ends_with("_bolt") else 5.0
	event.burn_damage = burn_damage
	event.burn_duration = burn_duration
	event.burn_interval = burn_interval
	event.slow_multiplier = slow_multiplier
	event.slow_seconds = slow_seconds
	event.freeze_points = freeze_points
	event.poison_stacks = poison_stacks
	event.poison_percent = poison_percent
	event.poison_seconds = poison_seconds
	event.armor_break_seconds = armor_break_seconds
	event.thermal_shock = thermal_shock
	event.consume_poison = consume_poison
	event.interrupt_seconds = interrupt_seconds
	if burn_damage > 0.0:
		event.status_ids.append(&"burn")
	return event

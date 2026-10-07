class_name WeaponBuildComponent
extends Node
## Additive moveset behavior driven by attack-step data and existing signals.

var player: Player
var last_lunge_id: int = 0


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or player.health.current_health <= 0.0:
		return
	var weapon: Weapon = player.equipped_weapon
	if weapon.phase != Weapon.Phase.ACTIVE or weapon.snapshot == null or weapon._current_step == null:
		return
	var step: AttackStepDefinition = weapon._current_step
	if step.lunge_seconds > 0.0 and last_lunge_id != weapon.snapshot.attack_id:
		last_lunge_id = weapon.snapshot.attack_id
		(player.motor as BuildPlayerMotor).request_impulse(weapon.snapshot.attack_direction * step.lunge_speed, step.lunge_seconds)


func super_armor_active() -> bool:
	var weapon: Weapon = player.equipped_weapon
	return weapon._current_step != null and weapon._current_step.super_armor and weapon.phase in [Weapon.Phase.WINDUP, Weapon.Phase.ACTIVE]


func receive_impact(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or event.source_kind == DamageEvent.SourceKind.DOT or not player.equipped_weapon.definition is WeaponData:
		return
	# Explicit strong reactions own cancellation and impulse once through Player.
	if event.hit_reaction in [&"knockback", &"kneel", &"thrown"]:
		return
	if super_armor_active() and not event.heavy_hit:
		return
	if player.action_state_machine.get_state_id() == &"attack":
		player.action_state_machine.transition_to(&"ready")
	if not event.knockback.is_zero_approx():
		(player.motor as BuildPlayerMotor).request_impulse(event.knockback, 0.12)

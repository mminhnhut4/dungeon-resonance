class_name HitReactionComponent
extends Node
## Finite actor-owned reaction clock. Player ticks it once; the motor owns motion.
## These timings are prototype feel values, not final balance.

const REACTIONS: Array[StringName] = [&"flinch", &"knockback", &"kneel", &"thrown"]
const FLINCH_SECONDS: float = 0.16
const KNOCKBACK_SECONDS: float = 0.24
const KNEEL_SECONDS: float = 0.32
const THROWN_POSE_SECONDS: float = 0.36
const MAX_AIR_SECONDS: float = 1.5
const DOWN_SECONDS: float = 0.14
const GET_UP_SECONDS: float = 0.26
const MIN_DASH_LOCK: float = 0.12
const RECOVERY_PROTECTION: float = 0.18

var player: Player
var is_active: bool = false
var reaction_id: StringName = &""
var pose_id: StringName = &""
var pose_time: float = 0.0
var pose_duration: float = 0.0
var elapsed: float = 0.0
var _phase: StringName = &""
var _phase_time: float = 0.0


func initialize(actor: Player) -> void:
	player = actor
	(actor.motor as BuildPlayerMotor).hit_reaction = self
	clear()


func receive_hit(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage <= 0.0 or result.killed or player.health.current_health <= 0.0:
		return
	if event.source_kind == DamageEvent.SourceKind.DOT or event.ignore_damage_grace or not event.hit_reaction in REACTIONS:
		return
	# Existing moveset super armor still protects against non-heavy interruption.
	var weapon: Weapon = player.equipped_weapon
	if event.hit_reaction != &"flinch" and not event.heavy_hit and weapon._current_step != null and weapon._current_step.super_armor and weapon.phase in [Weapon.Phase.WINDUP, Weapon.Phase.ACTIVE]:
		return
	clear()
	reaction_id = event.hit_reaction
	if reaction_id == &"kneel" and not player.motor.is_grounded():
		reaction_id = &"knockback"
	pose_id = reaction_id
	pose_duration = FLINCH_SECONDS if reaction_id == &"flinch" else KNOCKBACK_SECONDS if reaction_id == &"knockback" else KNEEL_SECONDS if reaction_id == &"kneel" else THROWN_POSE_SECONDS
	is_active = true
	_phase = &"air" if reaction_id == &"thrown" else &"hold"
	if not blocks_controls():
		return
	# Exit Attack/Cast/Dash through their normal FSM lifecycle exactly once.
	player.action_state_machine.transition_to(&"hurt")
	player.motor.jump_buffer_remaining = 0.0
	player.motor.coyote_remaining = 0.0
	var direction_x: float = signf(event.attack_direction.x) if is_finite(event.attack_direction.x) and not is_zero_approx(event.attack_direction.x) else -player.facing_direction
	var impulse: Vector2 = event.knockback
	if not is_finite(impulse.x) or not is_finite(impulse.y) or impulse.is_zero_approx():
		impulse = Vector2(direction_x * (340.0 if reaction_id == &"thrown" else 260.0), -440.0 if reaction_id == &"thrown" else 0.0)
	if reaction_id == &"kneel":
		impulse = Vector2(0.0, maxf(player.velocity.y, 0.0))
	elif reaction_id == &"thrown":
		impulse.y = clampf(impulse.y, -700.0, -120.0)
	else:
		impulse.y = player.velocity.y
	impulse.x = clampf(impulse.x, -700.0, 700.0)
	(player.motor as BuildPlayerMotor).apply_hit_impulse(impulse)


func blocks_controls() -> bool:
	return is_active and reaction_id != &"flinch"


func can_recover_dash() -> bool:
	return blocks_controls() and elapsed + 0.000001 >= MIN_DASH_LOCK


func physics_tick(delta: float) -> void:
	if not is_active:
		return
	elapsed += maxf(0.0, delta)
	_phase_time += maxf(0.0, delta)
	pose_time = minf(pose_duration, pose_time + maxf(0.0, delta))
	if reaction_id == &"thrown":
		if _phase == &"air":
			if (elapsed >= MIN_DASH_LOCK and player.velocity.y >= 0.0 and player.motor.is_grounded()) or _phase_time >= MAX_AIR_SECONDS:
				_phase = &"down"
				_phase_time = 0.0
				pose_time = pose_duration
		elif _phase == &"down" and _phase_time + 0.000001 >= DOWN_SECONDS:
			_phase = &"get_up"
			_phase_time = 0.0
			pose_id = &"get_up"
			pose_time = 0.0
			pose_duration = GET_UP_SECONDS
			_grant_protection(GET_UP_SECONDS + RECOVERY_PROTECTION)
		elif _phase == &"get_up" and _phase_time + 0.000001 >= GET_UP_SECONDS:
			finish()
	elif pose_time + 0.000001 >= pose_duration:
		finish()


func finish() -> void:
	if blocks_controls():
		_grant_protection(RECOVERY_PROTECTION)
	clear()


func recover_into_dash() -> void:
	# The caller validates motor availability and pays energy before reaching here.
	_grant_protection(RECOVERY_PROTECTION)
	clear()


func clear() -> void:
	is_active = false
	reaction_id = &""
	pose_id = &""
	pose_time = 0.0
	pose_duration = 0.0
	elapsed = 0.0
	_phase = &""
	_phase_time = 0.0


func _grant_protection(seconds: float) -> void:
	if is_instance_valid(player) and player.health.current_health > 0.0:
		player.damage_grace_remaining = maxf(player.damage_grace_remaining, seconds)
		player.hurtbox.set_invulnerable(true)

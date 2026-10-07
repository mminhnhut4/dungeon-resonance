class_name ProceduralAnimator
extends RefCounted
## Small presentation clock and pose math. Never owns an actor or physics state.

const WALK_BOB: float = 2.5
const MAX_LEAN: float = 0.13962634 # Eight degrees, in radians.
const WINDUP_SCALE: Vector2 = Vector2(1.35, 0.65)
const AIR_SCALE: Vector2 = Vector2(0.75, 1.3)
const LAND_SCALE: Vector2 = Vector2(1.25, 0.75)

var clock: float = 0.0
var walk_clock: float = 0.0
var bob: float = 0.0
var lean: float = 0.0


func advance_player(delta: float, horizontal_speed: float, run_speed: float, running_on_ground: bool) -> void:
	var elapsed: float = maxf(0.0, delta)
	clock += elapsed
	var ratio: float = clampf(horizontal_speed / maxf(run_speed, 1.0), -1.0, 1.0)
	var moving: bool = running_on_ground and absf(horizontal_speed) > 8.0
	if moving:
		walk_clock += elapsed * lerpf(6.0, 11.0, absf(ratio))
		# Lift away from the floor: the downward half-wave cannot sink the boots.
		bob = -absf(sin(walk_clock)) * WALK_BOB
	else:
		walk_clock = 0.0
		bob = move_toward(bob, 0.0, elapsed * 36.0)
	var target_lean: float = ratio * MAX_LEAN if absf(horizontal_speed) > 8.0 else 0.0
	lean = lerpf(lean, target_lean, 1.0 - exp(-elapsed * 15.0))
	if absf(lean) < 0.0001:
		lean = 0.0


func reset() -> void:
	clock = 0.0
	walk_clock = 0.0
	bob = 0.0
	lean = 0.0


static func breathing_scale(time: float, period: float = 1.2) -> float:
	return 1.0 + (1.0 - cos(TAU * maxf(time, 0.0) / maxf(period, 0.01))) * 0.0175


static func slime_attack_scale(state_time: float, telegraph: float) -> Vector2:
	var time: float = maxf(state_time, 0.0)
	var anticipation: float = minf(0.12, maxf(telegraph, 0.001))
	if time < telegraph:
		return Vector2.ONE.lerp(WINDUP_SCALE, smoothstep(0.0, anticipation, time))
	var attack_time: float = time - telegraph
	if attack_time < 0.12:
		return AIR_SCALE
	return landing_scale(attack_time - 0.12)


static func slime_hop_offset(state_time: float, telegraph: float) -> float:
	var progress: float = (state_time - telegraph) / 0.12
	return -sin(clampf(progress, 0.0, 1.0) * PI) * 6.0 if progress > 0.0 and progress < 1.0 else 0.0


static func landing_scale(landing_time: float) -> Vector2:
	if landing_time >= 0.30:
		return Vector2.ONE
	if landing_time < 0.08:
		return AIR_SCALE.lerp(LAND_SCALE, smoothstep(0.0, 0.08, maxf(0.0, landing_time)))
	var progress: float = clampf((landing_time - 0.08) / 0.22, 0.0, 1.0)
	if progress >= 1.0:
		return Vector2.ONE
	# Elastic ease-out overshoots once before converging; no asynchronous Tween.
	var ease: float = 1.0 - pow(2.0, -10.0 * progress) * cos(progress * TAU / 0.3)
	if progress <= 0.0:
		ease = 0.0
	return LAND_SCALE.lerp(Vector2.ONE, ease)

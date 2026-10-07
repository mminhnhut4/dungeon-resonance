class_name WorldEnemyMotor
extends KnockbackMotor
## One movement owner, sharing the proven grounded motor and finite pull impulse.

func commit_burst(velocity: Vector2) -> void:
	# Telegraph has already committed direction. Burst movement has no acceleration
	# ramp, so its authored short active window can actually reach the target.
	body.velocity = velocity

func step_world(delta: float, desired: Vector2, airborne: bool) -> void:
	if not airborne:
		step(delta, INF, desired.x)
		return
	if not _pending_impulse.is_zero_approx():
		body.velocity += _pending_impulse
		_pending_impulse = Vector2.ZERO
	var target: Vector2 = desired if desired.is_finite() else Vector2.ZERO
	body.velocity = body.velocity.move_toward(target, deceleration * delta)
	if _pull_remaining > 0.0:
		_pull_remaining = maxf(0.0, _pull_remaining - delta)
		body.velocity = _pull_velocity
	body.move_and_slide()

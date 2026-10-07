class_name KnockbackMotor
extends Node
## Sole velocity/move_and_slide owner for a passive physics target.

@export var body: CharacterBody2D
@export var gravity: float = 2250.0
@export var deceleration: float = 1800.0
@export var maximum_horizontal_speed: float = 600.0
var _pending_impulse: Vector2 = Vector2.ZERO
var _pull_velocity: Vector2 = Vector2.ZERO
var _pull_remaining: float = 0.0


func add_knockback(impulse: Vector2) -> void:
	_pending_impulse += impulse


func step(delta: float, return_home_x: float = INF, desired_velocity: float = NAN) -> void:
	if not _pending_impulse.is_zero_approx():
		body.velocity.x = clampf(body.velocity.x + _pending_impulse.x, -maximum_horizontal_speed, maximum_horizontal_speed)
		body.velocity.y = maxf(-350.0, minf(body.velocity.y, 0.0) + _pending_impulse.y)
		_pending_impulse = Vector2.ZERO
	body.velocity.x = move_toward(body.velocity.x, desired_velocity if is_finite(desired_velocity) else 0.0, deceleration * delta)
	if is_finite(return_home_x) and absf(return_home_x - body.global_position.x) > 0.5:
		body.velocity.x = clampf((return_home_x - body.global_position.x) * 10.0, -140.0, 140.0)
	body.velocity.y = minf(body.velocity.y + gravity * delta, 1000.0)
	if _pull_remaining > 0.0:
		_pull_remaining -= delta
		body.velocity.x = _pull_velocity.x
		body.velocity.y += _pull_velocity.y * delta * 8.0
	body.move_and_slide()


func reset_motion() -> void:
	body.velocity = Vector2.ZERO
	_pending_impulse = Vector2.ZERO
	_pull_remaining = 0.0
	_pull_velocity = Vector2.ZERO


func apply_pull(pull_velocity: Vector2) -> void:
	_pull_velocity = pull_velocity
	_pull_remaining = 0.05


func stop_horizontal() -> void:
	body.velocity.x = 0.0


func launch_vertical(speed: float) -> void:
	body.velocity.y = -absf(speed)


func plunge() -> void:
	body.velocity.y = 1000.0

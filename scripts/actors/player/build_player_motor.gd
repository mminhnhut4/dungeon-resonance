class_name BuildPlayerMotor
extends PlayerMotor
## Optional moveset/relic extensions; the base motor and both FSMs are unchanged.

var extra_air_dashes: int = 0
var air_dashes_used: int = 0
var impulse_remaining: float = 0.0
var impulse_velocity: Vector2 = Vector2.ZERO
var hit_reaction: HitReactionComponent


func begin_tick(delta: float, jump_pressed: bool) -> void:
	super.begin_tick(delta, jump_pressed)
	impulse_remaining = maxf(0.0, impulse_remaining - delta)
	if is_grounded() and not is_dashing:
		air_dashes_used = 0


func can_dash() -> bool:
	if extra_air_dashes <= 0:
		return super.can_dash()
	return not is_dashing and dash_cooldown_remaining <= 0.0 and (air_dash_available or air_dashes_used < 1 + extra_air_dashes) and (not air_dash_blocked or is_grounded())


func start_dash(axis: float, facing_direction: float) -> void:
	if not is_grounded():
		air_dashes_used += 1
	super.start_dash(axis, facing_direction)
	if extra_air_dashes > 0 and air_dashes_used < 1 + extra_air_dashes:
		air_dash_available = true


func apply_locomotion(delta: float, axis: float, jump_held: bool, airborne: bool) -> void:
	if is_instance_valid(hit_reaction) and hit_reaction.blocks_controls():
		# No jump-release cut or input acceleration can consume a thrown launch.
		var drag: float = 650.0 if hit_reaction.pose_id == &"thrown" else ground_deceleration
		body.velocity.x = move_toward(body.velocity.x, 0.0, drag * delta)
		var gravity: float = rise_gravity if body.velocity.y < 0.0 else fall_gravity
		body.velocity.y = minf(body.velocity.y + gravity * delta, maximum_fall_speed)
		return
	var original_speed: float = condition_speed_multiplier
	var statuses: StatusController = body.hurtbox.damage_resolver.status_controller
	condition_speed_multiplier *= statuses.movement_multiplier
	super.apply_locomotion(delta, axis, jump_held, airborne)
	condition_speed_multiplier = original_speed
	if impulse_remaining > 0.0 and not is_dashing:
		body.velocity.x = impulse_velocity.x


func request_impulse(velocity: Vector2, seconds: float) -> void:
	impulse_velocity = velocity
	impulse_remaining = maxf(0.0, seconds)


func apply_hit_impulse(velocity: Vector2) -> void:
	# Release a previous attack lunge; use the same world collision body afterward.
	impulse_remaining = 0.0
	impulse_velocity = Vector2.ZERO
	body.velocity = velocity


func reset_motion() -> void:
	super.reset_motion()
	air_dashes_used = 0
	impulse_remaining = 0.0
	impulse_velocity = Vector2.ZERO

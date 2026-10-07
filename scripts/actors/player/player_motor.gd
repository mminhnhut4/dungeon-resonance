class_name PlayerMotor
extends Node
## Sole owner of velocity and move_and_slide(). All durations use physics delta.

@export var body: CharacterBody2D

@export_group("Horizontal movement")
@export var run_speed: float = 320.0
@export var ground_acceleration: float = 2600.0
@export var ground_deceleration: float = 3600.0
@export var turn_acceleration: float = 3600.0
@export var air_acceleration: float = 2000.0
@export var air_deceleration: float = 1600.0

@export_group("Jump")
@export var jump_speed: float = 600.0
@export var rise_gravity: float = 1500.0
@export var fall_gravity: float = 2250.0
@export var maximum_fall_speed: float = 1000.0
@export_range(0.1, 0.9) var jump_release_multiplier: float = 0.45
@export var coyote_duration: float = 0.12
@export var jump_buffer_duration: float = 0.1

@export_group("Dash")
@export var dash_speed: float = 850.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.65
@export var dash_invulnerability_duration: float = 0.1

var coyote_remaining: float = 0.0
var jump_buffer_remaining: float = 0.0
var dash_remaining: float = 0.0
var dash_cooldown_remaining: float = 0.0
var invulnerability_remaining: float = 0.0
var air_dash_available: bool = true
var is_dashing: bool = false
var _dash_direction: float = 1.0
var _jump_cut_applied: bool = false
var _contact_valid: bool = false
var condition_speed_multiplier: float = 1.0
var air_dash_blocked: bool = false


func begin_tick(delta: float, jump_pressed: bool) -> void:
	dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
	dash_remaining = maxf(0.0, dash_remaining - delta)
	invulnerability_remaining = maxf(0.0, invulnerability_remaining - delta)
	jump_buffer_remaining = maxf(0.0, jump_buffer_remaining - delta)
	if is_grounded():
		coyote_remaining = coyote_duration
		if not is_dashing:
			air_dash_available = true
	else:
		coyote_remaining = maxf(0.0, coyote_remaining - delta)
	if jump_pressed:
		jump_buffer_remaining = jump_buffer_duration


func is_grounded() -> bool:
	return _contact_valid and body.is_on_floor()


func try_jump(jump_held: bool) -> bool:
	if is_dashing or jump_buffer_remaining <= 0.0 or coyote_remaining <= 0.0:
		return false
	body.velocity.y = -jump_speed
	coyote_remaining = 0.0
	jump_buffer_remaining = 0.0
	_jump_cut_applied = false
	# A buffered tap that was already released still produces a short jump.
	_cut_jump_if_released(jump_held)
	return true


func apply_locomotion(delta: float, axis: float, jump_held: bool, airborne: bool) -> void:
	if is_dashing:
		return
	var acceleration: float = air_acceleration if airborne else ground_acceleration
	if is_zero_approx(axis):
		acceleration = air_deceleration if airborne else ground_deceleration
	elif body.velocity.x * axis < 0.0:
		acceleration = turn_acceleration
	body.velocity.x = move_toward(body.velocity.x, axis * run_speed * condition_speed_multiplier, acceleration * delta)
	_cut_jump_if_released(jump_held)
	var gravity: float = rise_gravity if body.velocity.y < 0.0 else fall_gravity
	body.velocity.y = minf(body.velocity.y + gravity * delta, maximum_fall_speed)


func _cut_jump_if_released(jump_held: bool) -> void:
	if not jump_held and not _jump_cut_applied and body.velocity.y < 0.0:
		body.velocity.y *= jump_release_multiplier
		_jump_cut_applied = true


func can_dash() -> bool:
	return not is_dashing and dash_cooldown_remaining <= 0.0 and air_dash_available and (not air_dash_blocked or is_grounded())


func start_dash(axis: float, facing_direction: float) -> void:
	assert(can_dash())
	_dash_direction = signf(axis) if not is_zero_approx(axis) else facing_direction
	is_dashing = true
	air_dash_available = false
	dash_remaining = dash_duration
	dash_cooldown_remaining = dash_cooldown
	invulnerability_remaining = minf(dash_invulnerability_duration, dash_duration)
	jump_buffer_remaining = 0.0
	coyote_remaining = 0.0
	apply_dash_motion()


func apply_dash_motion() -> void:
	body.velocity = Vector2(_dash_direction * dash_speed, 0.0)


func end_dash() -> void:
	is_dashing = false
	dash_remaining = 0.0
	invulnerability_remaining = 0.0
	body.velocity.x = clampf(body.velocity.x, -run_speed, run_speed)


func is_invulnerable() -> bool:
	return is_dashing and invulnerability_remaining > 0.0


func move_body() -> void:
	# Exactly one movement call per Player physics tick, including during dash.
	body.move_and_slide()
	_contact_valid = true


func reset_motion() -> void:
	body.velocity = Vector2.ZERO
	coyote_remaining = 0.0
	jump_buffer_remaining = 0.0
	dash_remaining = 0.0
	dash_cooldown_remaining = 0.0
	invulnerability_remaining = 0.0
	air_dash_available = true
	is_dashing = false
	_jump_cut_applied = false
	_contact_valid = false

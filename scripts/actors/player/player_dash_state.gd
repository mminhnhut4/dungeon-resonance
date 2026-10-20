class_name PlayerDashState
extends ActorState
## Motor owns movement; a late attack intent is released only at natural dash expiry.

const ATTACK_BUFFER_SECONDS: float = 0.08
var motor: PlayerMotor
var _buffered_attack: bool = false
var _buffered_definition: WeaponDefinition


func setup(context: Node) -> void:
	super.setup(context)
	motor = context.motor
	if not actor.weapon_changed.is_connected(_on_weapon_changed):
		actor.weapon_changed.connect(_on_weapon_changed)


func enter(_previous_id: StringName) -> void:
	_clear_attack_buffer()
	motor.start_dash(actor.move_axis, actor.facing_direction)


func buffer_attack(pressed: bool, accepts_input: bool) -> void:
	if not accepts_input:
		_clear_attack_buffer()
		return
	if pressed and not _buffered_attack and motor.is_dashing and motor.dash_remaining > 0.0 and motor.dash_remaining <= ATTACK_BUFFER_SECONDS:
		_buffered_attack = true
		_buffered_definition = actor.equipped_weapon.definition


func physics_update(_delta: float) -> void:
	if not actor.controls_enabled or actor.health.current_health <= 0.0:
		_clear_attack_buffer()
	if motor.dash_remaining <= 0.0:
		var counter: bool = _buffered_attack and actor.controls_enabled and actor.health.current_health > 0.0 and not actor.is_queued_for_deletion() and actor.equipped_weapon.definition == _buffered_definition
		# transition_to calls exit/end_dash before Attack enters its full windup.
		# Early wall/hurt/UI/gear/reset exits clear the intent without consuming it.
		(get_parent() as ActorStateMachine).transition_to(&"attack" if counter else &"ready")
	else:
		motor.apply_dash_motion()


func exit(_next_id: StringName) -> void:
	_clear_attack_buffer()
	motor.end_dash()


func _on_weapon_changed(_definition: WeaponDefinition) -> void:
	_clear_attack_buffer()


func _clear_attack_buffer() -> void:
	_buffered_attack = false
	_buffered_definition = null

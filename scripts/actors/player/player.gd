class_name Player
extends CharacterBody2D
## Input + two orthogonal FSMs. Motor is the only component that moves the body.

@export var motor: PlayerMotor
@export var locomotion_state_machine: ActorStateMachine
@export var action_state_machine: ActorStateMachine
@export var equipped_weapon: Weapon
@export var aim: PlayerAim
@export var resonance_controller: ResonanceController
@export var health: HealthComponent
@export var hurtbox: Hurtbox
@export var body_sprite: Sprite2D
@export var controls_enabled: bool = true
@export var combat_feedback: CombatFeedback

signal spell_cast_requested(target_position: Vector2, direction: Vector2)
signal weapon_changed(definition: WeaponDefinition)

var move_axis: float = 0.0
var jump_held: bool = false
var facing_direction: float = 1.0
var _pending_attack: bool = false
var _pending_jump: bool = false
var _pending_dash: bool = false
var _pending_cast: bool = false
var damage_grace_remaining: float = 0.0
var energy: EnergyPool
var gear_switch_enabled: bool = false
var gear_index: int = 0
var _resume_guard: int = 0
var available_weapons: Array[WeaponDefinition] = []
var hit_reaction: HitReactionComponent
const SWORD: WeaponDefinition = preload("res://data/weapons/ancient_sword.tres")
const DAGGER: WeaponDefinition = preload("res://data/weapons/shadow_dagger.tres")


func _ready() -> void:
	add_to_group(&"players")
	available_weapons.assign([SWORD, DAGGER])
	assert(motor != null and motor.body == self)
	motor.reset_motion()
	hit_reaction = get_node_or_null("HitReaction") as HitReactionComponent
	if hit_reaction != null:
		hit_reaction.initialize(self)
	assert(aim != null)
	aim.sample_cursor()
	equipped_weapon.initialize(get_instance_id(), aim)
	health.died.connect(_on_died)
	hurtbox.hit_resolved.connect(_on_hit_resolved)
	energy = EnergyPool.new()
	add_child(energy)
	hurtbox.damage_resolver.status_controller.damage_requested.connect(hurtbox.take_damage)
	locomotion_state_machine.initialize(self)
	action_state_machine.initialize(self)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or _resume_guard > 0:
		return
	_pending_attack = _pending_attack or event.is_action_pressed(&"attack")
	_pending_jump = _pending_jump or event.is_action_pressed(&"jump")
	_pending_dash = _pending_dash or event.is_action_pressed(&"dash")
	_pending_cast = _pending_cast or event.is_action_pressed(&"spell_cast")


func _physics_process(delta: float) -> void:
	aim.sample_cursor()
	var accepts_input: bool = controls_enabled and _resume_guard <= 0
	_resume_guard = maxi(0, _resume_guard - 1)
	move_axis = Input.get_axis(&"move_left", &"move_right") if accepts_input else 0.0
	jump_held = accepts_input and Input.is_action_pressed(&"jump")
	_pending_jump = _pending_jump or (accepts_input and Input.is_action_just_pressed(&"jump"))
	_pending_dash = _pending_dash or (accepts_input and Input.is_action_just_pressed(&"dash"))
	_pending_attack = _pending_attack or (accepts_input and Input.is_action_just_pressed(&"attack"))
	_pending_cast = _pending_cast or (accepts_input and Input.is_action_just_pressed(&"spell_cast"))
	# Sample presses during freeze, but do not advance gameplay clocks or physics.
	if is_instance_valid(combat_feedback) and combat_feedback.is_frozen():
		return
	damage_grace_remaining = maxf(0.0, damage_grace_remaining - delta)
	var jump_pressed: bool = _pending_jump
	var dash_pressed: bool = _pending_dash
	var attack_pressed: bool = _pending_attack
	var cast_pressed: bool = _pending_cast
	_clear_pending_inputs()
	var action_id: StringName = action_state_machine.get_state_id()
	if action_id == &"dead":
		move_axis = 0.0
		jump_held = false
		jump_pressed = false
	if not is_zero_approx(move_axis) and (action_id == &"ready" or action_id == &"attack" or action_id == &"cast_spell"):
		facing_direction = signf(move_axis)
	motor.begin_tick(delta, jump_pressed and not (hit_reaction != null and hit_reaction.blocks_controls()))
	if hit_reaction != null:
		hit_reaction.physics_tick(delta)
	if accepts_input and gear_switch_enabled and action_id not in [&"dead", &"hurt"] and Input.is_action_just_pressed(&"switch_weapon"):
		switch_weapon()
		action_id = &"ready"
	var reaction_dash: bool = action_id == &"hurt" and hit_reaction != null and hit_reaction.can_recover_dash()
	if dash_pressed and (action_id in [&"ready", &"attack", &"cast_spell", &"cultivation_skill"] or reaction_dash) and motor.can_dash() and energy.spend(25.0):
		if reaction_dash:
			hit_reaction.recover_into_dash()
		action_state_machine.transition_to(&"dash")
	elif attack_pressed:
		if action_id == &"ready":
			action_state_machine.transition_to(&"attack")
		elif action_id == &"attack":
			equipped_weapon.request_next()
	elif cast_pressed and action_id == &"ready":
		spell_cast_requested.emit(aim.target_position, aim.direction)
		if resonance_controller.can_cast():
			action_state_machine.transition_to(&"cast_spell")
	action_state_machine.physics_update(delta)
	if action_state_machine.get_state_id() in [&"ready", &"attack", &"cast_spell", &"cultivation_skill"]:
		motor.try_jump(jump_held)
	_update_locomotion_state()
	locomotion_state_machine.physics_update(delta)
	motor.move_body()
	if motor.is_dashing and is_on_wall():
		action_state_machine.transition_to(&"ready")
	_update_locomotion_state()
	hurtbox.set_invulnerable(motor.is_invulnerable() or damage_grace_remaining > 0.0 or health.current_health <= 0.0)
	_update_visuals()
	equipped_weapon.sample_hits()


func _update_locomotion_state() -> void:
	if velocity.y < -0.01:
		locomotion_state_machine.transition_to(&"jump")
	elif not motor.is_grounded():
		locomotion_state_machine.transition_to(&"fall")
	elif absf(velocity.x) > 0.5:
		locomotion_state_machine.transition_to(&"run")
	else:
		locomotion_state_machine.transition_to(&"idle")


func _update_visuals() -> void:
	if body_sprite == null:
		return
	body_sprite.flip_h = facing_direction < 0.0
	if health.current_health <= 0.0:
		body_sprite.modulate = Color(0.35, 0.35, 0.35)
	elif damage_grace_remaining > 0.0:
		body_sprite.modulate = Color(1.0, 0.4, 0.4, 0.35 if fmod(damage_grace_remaining, 0.12) < 0.06 else 1.0)
	elif motor.is_invulnerable():
		body_sprite.modulate = Color(1.5, 1.6, 1.8, 1.0)
	elif motor.is_dashing:
		body_sprite.modulate = Color(0.65, 0.85, 1.2, 1.0)
	else:
		body_sprite.modulate = Color.WHITE


func reset_movement_at(spawn_position: Vector2) -> void:
	if hit_reaction != null:
		hit_reaction.clear()
	action_state_machine.transition_to(&"ready")
	locomotion_state_machine.transition_to(&"idle")
	motor.reset_motion()
	equipped_weapon.cancel_combo()
	_clear_pending_inputs()
	health.reset_health()
	hurtbox.damage_resolver.reset_history()
	hurtbox.damage_resolver.status_controller.clear()
	resonance_controller.reset_runtime()
	damage_grace_remaining = 0.0
	_resume_guard = 0
	energy.reset()
	global_position = spawn_position
	facing_direction = 1.0
	move_axis = 0.0
	jump_held = false
	hurtbox.set_invulnerable(false)
	_update_visuals()


func _clear_pending_inputs() -> void:
	_pending_attack = false
	_pending_jump = false
	_pending_dash = false
	_pending_cast = false


func _on_died() -> void:
	if hit_reaction != null:
		hit_reaction.clear()
	action_state_machine.transition_to(&"dead")
	_clear_pending_inputs()
	hurtbox.set_invulnerable(true)


func _on_hit_resolved(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage <= 0.0:
		return
	if event.ignore_damage_grace:
		return
	damage_grace_remaining = 0.6
	hurtbox.set_invulnerable(true)
	if is_instance_valid(combat_feedback):
		combat_feedback.on_hit_confirmed(event, result)
	if hit_reaction != null:
		hit_reaction.receive_hit(event, result)


func suspend_controls(suspended: bool) -> void:
	controls_enabled = not suspended
	_resume_guard = 2 if not suspended else 0
	_clear_pending_inputs()
	if suspended:
		equipped_weapon.cancel_combo()
		if action_state_machine.get_state_id() not in [&"dead", &"hurt"]:
			action_state_machine.transition_to(&"ready")


func relocate(position_world: Vector2) -> void:
	# Room transition preserves health, energy, loadout and committed cooldowns.
	if hit_reaction != null:
		hit_reaction.clear()
	action_state_machine.transition_to(&"ready")
	locomotion_state_machine.transition_to(&"idle")
	motor.reset_motion()
	equipped_weapon.cancel_combo()
	_clear_pending_inputs()
	global_position = position_world


func switch_weapon() -> void:
	if hit_reaction != null and hit_reaction.blocks_controls():
		return
	if available_weapons.is_empty():
		return
	gear_index = (gear_index + 1) % available_weapons.size()
	action_state_machine.transition_to(&"ready")
	equipped_weapon.equip(available_weapons[gear_index])
	weapon_changed.emit(equipped_weapon.definition)

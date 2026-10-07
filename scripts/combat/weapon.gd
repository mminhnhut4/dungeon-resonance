class_name Weapon
extends Node2D
## Deliver attacks from WeaponDefinition through a shared Hitbox/AttackSnapshot.

signal attack_committed(snapshot: AttackSnapshot)
signal attack_finished(attack_id: int)
signal hit_confirmed(event: DamageEvent, result: DamageResult)

enum Phase { NONE, WINDUP, ACTIVE, RECOVERY, COMBO_WAIT }

@export var definition: WeaponDefinition
@export var hitbox: Hitbox
var phase: Phase = Phase.NONE
var combo_index: int = -1
var snapshot: AttackSnapshot
var _source_id: int
var _aim: PlayerAim
var _phase_remaining: float = 0.0
var _phase_duration: float = 0.0
var _queued_next: bool = false
var _step_finished: bool = true
var _combo_definition: WeaponDefinition
var _current_step: AttackStepDefinition
var installed_rune: RuneData
var critical_rng := RandomNumberGenerator.new()
var effect_executor: SpellExecutor
var rune_context: SpellContext
var damage_multiplier: float = 1.0
var equipment_critical_bonus: float = 0.0
var outgoing_multiplier: float = 1.0
var _step_hit: bool = false
var _did_swing: bool = false
var additional_runes: Array[RuneData] = []
var element_damage_multiplier: float = 1.0
## Runtime appearance grade; GearSession owns it alongside damage_multiplier.
var visual_quality: int = 0
signal swing_resolved(hit_any: bool)


func _ready() -> void:
	critical_rng.randomize()
	hitbox.contact_detected.connect(_on_contact)
	hitbox.deactivate()


func initialize(source_id: int, aim: PlayerAim) -> void:
	_source_id = source_id
	_aim = aim
	assert(_aim != null)
	assert(definition != null and not definition.combo_steps.is_empty())


func is_attacking() -> bool:
	return phase != Phase.NONE


func start_combo() -> void:
	cancel_combo()
	_combo_definition = definition
	_begin_step(0)


func request_next() -> bool:
	if not is_attacking() or combo_index + 1 >= _combo_definition.combo_steps.size():
		return false
	if phase == Phase.COMBO_WAIT:
		_begin_step(combo_index + 1)
	else:
		# Keep only the next press, so holding/spamming cannot prequeue a full run.
		_queued_next = true
	return true


func advance(delta: float) -> void:
	var remaining_delta: float = delta
	while is_attacking() and remaining_delta > 0.000001:
		var spent: float = minf(remaining_delta, _phase_remaining)
		_phase_remaining -= spent
		remaining_delta -= spent
		if _phase_remaining > 0.000001:
			break
		var step: AttackStepDefinition = _current_step
		match phase:
			Phase.WINDUP:
				_did_swing = true
				if _combo_definition.attack_kind == &"melee":
					hitbox.activate(snapshot, _make_shape(step), _make_offset(step))
				else:
					_spawn_ranged()
				_set_phase(Phase.ACTIVE, step.active_seconds)
			Phase.ACTIVE:
				hitbox.deactivate()
				_set_phase(Phase.RECOVERY, step.recovery_seconds)
			Phase.RECOVERY:
				_finish_step()
				if _queued_next and combo_index + 1 < _combo_definition.combo_steps.size():
					_begin_step(combo_index + 1)
				elif combo_index + 1 < _combo_definition.combo_steps.size():
					_set_phase(Phase.COMBO_WAIT, _combo_definition.combo_window_seconds)
				else:
					cancel_combo()
			Phase.COMBO_WAIT:
				cancel_combo()
	queue_redraw()


func _begin_step(index: int) -> void:
	_step_hit = false
	_did_swing = false
	combo_index = index
	_queued_next = false
	_step_finished = false
	var step: AttackStepDefinition = _combo_definition.combo_steps[index]
	_current_step = step
	assert(step.active_seconds > 0.0 and step.hitbox_shape != null)
	assert(step.windup_seconds >= 0.0 and step.recovery_seconds >= 0.0)
	snapshot = AttackSnapshot.new()
	snapshot.source_id = _source_id
	snapshot.attack_id = CombatIds.next_id()
	snapshot.root_event_id = snapshot.attack_id
	snapshot.weapon_definition = _combo_definition
	snapshot.cosmetic_quality = clampi(visual_quality, GearItem.Quality.COMMON, GearItem.Quality.DIVINE)
	snapshot.cosmetic_combo_index = index
	snapshot.base_damage = _combo_definition.base_damage * step.damage_multiplier * damage_multiplier * outgoing_multiplier
	snapshot.stagger_force = step.stagger_force
	var crit_chance: float = clampf(_combo_definition.critical_chance + equipment_critical_bonus, 0.0, 1.0)
	snapshot.critical = crit_chance > 0.0 and critical_rng.randf() < crit_chance
	if snapshot.critical:
		snapshot.base_damage *= _combo_definition.critical_multiplier
	if installed_rune != null:
		snapshot.burn_damage = installed_rune.burn_damage
		snapshot.burn_duration = installed_rune.burn_duration
		snapshot.burn_interval = installed_rune.burn_interval
	for rune: RuneData in additional_runes:
		snapshot.burn_damage = maxf(snapshot.burn_damage, rune.burn_damage)
		snapshot.burn_duration = maxf(snapshot.burn_duration, rune.burn_duration)
	var elemental_runes: Array[RuneData] = additional_runes.duplicate()
	if installed_rune != null:
		elemental_runes.append(installed_rune)
	for rune: RuneData in elemental_runes:
		snapshot.slow_multiplier = minf(snapshot.slow_multiplier, rune.slow_multiplier)
		snapshot.slow_seconds = maxf(snapshot.slow_seconds, rune.slow_seconds)
		snapshot.freeze_points = maxf(snapshot.freeze_points, rune.freeze_points)
		snapshot.poison_stacks = maxi(snapshot.poison_stacks, rune.poison_stacks)
		snapshot.poison_percent = rune.poison_percent
		snapshot.poison_seconds = rune.poison_seconds
	# The same explicit precedence as contact presentation, including Lightning
	# whose chain behavior does not need to carry a stun payload.
	for element: StringName in [&"fire", &"ice", &"poison", &"lightning", &"wind"]:
		if elemental_runes.any(func(rune: RuneData) -> bool: return rune.id == element):
			snapshot.cosmetic_element = element
			break
	snapshot.cosmetic_tint = AttackSnapshot.tint_for_element(snapshot.cosmetic_element)
	if (installed_rune != null and installed_rune.id in [&"fire", &"lightning"]) or additional_runes.any(func(rune: RuneData) -> bool: return rune.id in [&"fire", &"lightning"]):
		snapshot.base_damage *= element_damage_multiplier
		snapshot.burn_damage *= element_damage_multiplier
	# Re-aim each slash when it commits, including a buffered combo step.
	# Its hitbox/VFX then keep that direction through windup, active and recovery.
	_aim.sample_cursor()
	snapshot.attack_origin = global_position
	snapshot.aim_position = _aim.target_position
	snapshot.attack_direction = _aim.direction
	rune_context = null
	var chain_rune: RuneData = installed_rune if installed_rune != null and installed_rune.chain_targets > 0 else null
	for rune: RuneData in additional_runes:
		if rune.chain_targets > 0:
			chain_rune = rune
	if chain_rune != null:
		var payload := SpellSnapshot.new()
		payload.source_id = _source_id
		payload.root_id = snapshot.root_event_id
		payload.origin = global_position
		payload.target_position = snapshot.aim_position
		payload.direction = snapshot.attack_direction
		payload.damage = snapshot.base_damage
		payload.chain_targets = chain_rune.chain_targets
		payload.chain_radius = chain_rune.chain_radius
		rune_context = SpellContext.new(payload)
	snapshot.knockback = snapshot.attack_direction * absf(step.knockback.x) + Vector2(0.0, step.knockback.y)
	if installed_rune != null:
		snapshot.knockback *= installed_rune.knockback_multiplier
	for rune: RuneData in additional_runes:
		snapshot.knockback *= rune.knockback_multiplier
	scale = Vector2.ONE
	global_rotation = snapshot.attack_direction.angle()
	_set_phase(Phase.WINDUP, step.windup_seconds)
	attack_committed.emit(snapshot)


func _set_phase(next_phase: Phase, duration: float) -> void:
	phase = next_phase
	_phase_duration = maxf(0.0, duration)
	_phase_remaining = _phase_duration
	queue_redraw()


func _finish_step() -> void:
	if not _step_finished and snapshot != null:
		_step_finished = true
		if _did_swing and _combo_definition.attack_kind == &"melee":
			swing_resolved.emit(_step_hit)
		attack_finished.emit(snapshot.attack_id)


func cancel_combo() -> void:
	hitbox.deactivate()
	_finish_step()
	phase = Phase.NONE
	combo_index = -1
	snapshot = null
	rune_context = null
	_combo_definition = null
	_current_step = null
	_queued_next = false
	_phase_remaining = 0.0
	queue_redraw()


func sample_hits() -> void:
	if phase == Phase.ACTIVE:
		hitbox.sample_contacts()


func _on_contact(target: Hurtbox, attack: AttackSnapshot) -> void:
	var event := DamageEvent.new()
	event.source_id = attack.source_id
	event.target_id = target.get_actor_id()
	event.attack_id = attack.attack_id
	event.hit_window_id = attack.hit_window_id
	event.root_event_id = attack.root_event_id
	event.source_team_id = attack.source_team_id
	event.base_damage = attack.base_damage
	event.attack_direction = attack.attack_direction
	event.attack_origin = attack.attack_origin
	event.aim_position = attack.aim_position
	event.knockback = attack.knockback
	event.burn_damage = attack.burn_damage
	event.burn_duration = attack.burn_duration
	event.burn_interval = attack.burn_interval
	event.stagger_force = attack.stagger_force
	event.critical = attack.critical
	event.melee_hit = attack.weapon_definition.attack_kind == &"melee"
	event.physical_damage = event.melee_hit
	event.slow_multiplier = attack.slow_multiplier
	event.slow_seconds = attack.slow_seconds
	event.freeze_points = attack.freeze_points
	event.poison_stacks = attack.poison_stacks
	event.poison_percent = attack.poison_percent
	event.poison_seconds = attack.poison_seconds
	event.cosmetic_quality = attack.cosmetic_quality
	event.cosmetic_element = attack.cosmetic_element
	event.cosmetic_tint = attack.cosmetic_tint
	event.cosmetic_combo_index = attack.cosmetic_combo_index
	if _current_step != null and _current_step.pull_force > 0.0:
		event.knockback = (attack.attack_origin + attack.attack_direction * 35.0 - target.global_position).normalized() * _current_step.pull_force
	if event.burn_damage > 0.0:
		event.status_ids.append(&"burn")
	event.hit_position = target.global_position
	event.allow_resonance = attack.resonance_definition != null and attack.proc_budget > 0
	var result: DamageResult = target.take_damage(event)
	if not result.blocked and result.actual_damage > 0.0:
		_step_hit = true
		hit_confirmed.emit(event, result)
		if rune_context != null and is_instance_valid(effect_executor):
			rune_context.visited_targets[target.get_actor_id()] = true
			effect_executor.chain_from(target.global_position, rune_context)


func get_phase_name() -> String:
	return ["Sẵn sàng", "Chuẩn bị", "Ra đòn", "Hồi đòn", "Chờ nối combo"][phase]


func _draw() -> void:
	if phase == Phase.NONE or phase == Phase.COMBO_WAIT or combo_index < 0:
		return
	var step: AttackStepDefinition = _current_step
	if step.reach > 0.0:
		var progress_new: float = 1.0 - _phase_remaining / maxf(_phase_duration, 0.001)
		var tint := Color(1.0, 0.35, 0.1) if snapshot.burn_damage > 0.0 else Color(0.65, 1.0, 0.92)
		tint.a = 1.0 if phase == Phase.ACTIVE else 0.4
		if step.motion == &"thrust":
			draw_line(Vector2(8, 0), Vector2(step.reach * (0.5 + 0.5 * progress_new), 0), tint, 5.0, true)
		else:
			var half: float = deg_to_rad(step.sweep_angle_degrees) * 0.5
			draw_arc(Vector2.ZERO, step.reach, -half, half, 24, tint, 4.0, true)
		return
	var anchor := Vector2(0, step.hitbox_offset.y)
	var shape := step.hitbox_shape as RectangleShape2D
	var reach: float = step.hitbox_offset.x + (shape.size.x * 0.5 if shape != null else 28.0)
	var progress: float = 1.0 - _phase_remaining / maxf(_phase_duration, 0.001)
	var color := Color(0.65, 1.0, 0.92, 1.0) if combo_index < 2 else Color(1.0, 0.76, 0.3, 1.0)
	var angle: float = lerpf(-0.3, 0.3, progress) * (-1.0 if combo_index == 1 else 1.0)
	if phase == Phase.WINDUP:
		angle = -0.6
		color.a = 0.45
	elif phase == Phase.RECOVERY:
		color.a = (1.0 - progress) * 0.5
	if phase == Phase.ACTIVE:
		draw_arc(anchor, reach, -0.3, 0.3, 18, color, 5.0, true)
	draw_line(anchor, anchor + Vector2.from_angle(angle) * reach, color, 3.0, true)
	draw_line(anchor + Vector2(6, -6), anchor + Vector2(6, 6), Color(0.96, 0.68, 0.32, color.a), 3.0, true)


func _make_offset(step: AttackStepDefinition) -> Vector2:
	return Vector2.ZERO if step.reach > 0.0 and step.motion == &"slash" else step.hitbox_offset


func _make_shape(step: AttackStepDefinition) -> Shape2D:
	if step.reach <= 0.0 or step.motion == &"thrust":
		return step.hitbox_shape
	var polygon := ConvexPolygonShape2D.new()
	var points := PackedVector2Array([Vector2.ZERO])
	var half: float = deg_to_rad(step.sweep_angle_degrees) * 0.5
	for index: int in 13:
		points.append(Vector2.from_angle(lerpf(-half, half, index / 12.0)) * step.reach)
	var hull: PackedVector2Array = Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.resize(hull.size() - 1)
	polygon.points = hull
	return polygon


func equip(next_definition: WeaponDefinition) -> void:
	cancel_combo()
	definition = next_definition


func _spawn_ranged() -> void:
	if not is_instance_valid(effect_executor):
		return
	var payload := SpellSnapshot.new()
	payload.source_id = snapshot.source_id
	payload.root_id = snapshot.root_event_id
	payload.origin = global_position
	payload.target_position = snapshot.aim_position
	payload.direction = snapshot.attack_direction
	payload.damage = snapshot.base_damage
	payload.cosmetic_quality = snapshot.cosmetic_quality
	payload.cosmetic_element = snapshot.cosmetic_element
	payload.color = snapshot.cosmetic_tint
	payload.weapon_family_visual = _combo_definition.visual_profile != &"legacy"
	payload.behavior_id = _combo_definition.projectile_pattern
	payload.speed = _combo_definition.projectile_speed
	payload.lifetime = _combo_definition.projectile_lifetime
	payload.maximum_targets = _combo_definition.projectile_targets
	payload.burn_damage = snapshot.burn_damage
	payload.burn_duration = snapshot.burn_duration
	payload.slow_multiplier = snapshot.slow_multiplier
	payload.slow_seconds = snapshot.slow_seconds
	payload.freeze_points = snapshot.freeze_points
	payload.poison_stacks = snapshot.poison_stacks
	payload.poison_percent = snapshot.poison_percent
	payload.poison_seconds = snapshot.poison_seconds
	var runes: Array[RuneData] = additional_runes.duplicate()
	if installed_rune != null:
		runes.append(installed_rune)
	for rune: RuneData in runes:
		payload.speed *= rune.projectile_speed_multiplier
		payload.maximum_targets = maxi(payload.maximum_targets, rune.maximum_pierced_targets)
		payload.chain_targets = maxi(payload.chain_targets, rune.chain_targets)
	effect_executor.spawn_cast(payload)

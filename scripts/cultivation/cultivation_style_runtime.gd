class_name CultivationStyleRuntime
extends Node2D
## Opt-in, actor-owned techniques. No save, unlock grant, gear mutation or motor.
signal technique_committed(id: StringName, root_id: int)
signal technique_finished(id: StringName, reason: StringName)
signal counter_readied(root_id: int)
const DATA: Dictionary = {
	&"cloud_return": preload("res://data/cultivation/cloud_return.tres"),
	&"tether_sigil": preload("res://data/cultivation/tether_sigil.tres")
}
var actor: Player
var learned: Array[StringName] = []
var selected: StringName = &""
var cooldowns: Dictionary = {&"cloud_return": 0.0, &"tether_sigil": 0.0}
var counter_remaining: float = 0.0
var counter_root: int = 0
var mark: CultivationSigil
var hitbox: Hitbox
var last_rejection: StringName = &""
var accepted_hits: int = 0
var _room: Node2D
var _mode: StringName = &""
var _time: float = 0.0
var _root: int = 0
var _target: Vector2
var _direction := Vector2.RIGHT
var _launched: bool = false
var _attempted: bool = false
var _definition: CultivationStyleData
var _recent_dodges: Dictionary[int, bool] = {}
var _initialized: bool = false
var _weapon_definition: WeaponDefinition

func initialize(player: Player, room: Node2D) -> bool:
	if _initialized or player == null or room == null: return false
	var state := CultivationSkillState.new()
	state.state_id = &"cultivation_skill"
	state.name = "CultivationSkill"
	state.runtime = self
	if not player.action_state_machine.register_state(state, player):
		state.free()
		return false
	actor = player
	_initialized = true
	bind_room(room)
	_weapon_definition = actor.equipped_weapon.definition
	hitbox = ActorCombatRig.hitbox(self, 16)
	hitbox.contact_detected.connect(_counter_contact)
	actor.hurtbox.hit_resolved.connect(_observe_dodge)
	actor.action_state_machine.state_changed.connect(_action_changed)
	actor.weapon_changed.connect(_weapon_changed)
	process_physics_priority = 20
	z_index = 8
	return true

func apply_progress_snapshot(ids: Array[StringName], selected_id: StringName) -> bool:
	if ids.size() > 2 or (selected_id != &"" and (not DATA.has(selected_id) or selected_id not in ids)): return false
	var unique: Array[StringName] = []
	for id: StringName in ids:
		if not DATA.has(id) or id in unique: return false
		unique.append(id)
	if selected != selected_id or learned != unique:
		cancel_for_room_transition()
		learned = unique.duplicate()
		selected = selected_id
	return true

func bind_room(room: Node2D) -> void:
	cancel_for_room_transition()
	if is_instance_valid(_room) and _room.tree_exiting.is_connected(cancel_for_room_transition): _room.tree_exiting.disconnect(cancel_for_room_transition)
	_room = room
	if is_instance_valid(_room): _room.tree_exiting.connect(cancel_for_room_transition)

func is_frozen() -> bool:
	return is_instance_valid(actor.combat_feedback) and actor.combat_feedback.is_frozen()

func request_skill(target: Vector2) -> bool:
	last_rejection = &""
	if not _initialized or selected == &"" or selected not in learned: return _reject(&"locked")
	if get_tree().paused or is_frozen() or not actor.controls_enabled or actor._resume_guard > 0 or actor.health.current_health <= 0 or actor.action_state_machine.get_state_id() != &"ready": return _reject(&"busy")
	if not actor.energy.enabled or not is_instance_valid(_room) or _room.is_queued_for_deletion(): return _reject(&"context")
	if not target.is_finite() or not actor.aim.global_position.is_finite() or not actor.aim.direction.is_finite(): return _reject(&"placement")
	var data: CultivationStyleData = DATA[selected]
	var cost: float = data.energy_cost
	var next_mode: StringName
	var next_root: int = CombatIds.next_id()
	if selected == &"cloud_return":
		if actor.equipped_weapon.definition.id != &"ancient_sword": return _reject(&"weapon")
		if counter_remaining <= 0: return _reject(&"dodge_required")
		next_mode = &"counter"
	else:
		if is_instance_valid(mark):
			if not mark.is_armed() or mark.age >= data.mark_lifetime - data.pulse_windup: return _reject(&"mark_not_ready")
			if actor.aim.global_position.distance_to(mark.global_position) > data.activation_range or not clear_line(actor.aim.global_position, mark.global_position): return _reject(&"placement")
			next_mode = &"pulse"
			next_root = mark.root_id
			cost = data.pulse_cost
		else:
			next_mode = &"place"
			var origin: Vector2 = actor.aim.global_position
			if origin.distance_to(target) > data.placement_range or not clear_line(origin, target): return _reject(&"placement")
	if next_mode != &"pulse" and float(cooldowns[selected]) > 0: return _reject(&"cooldown")
	if not actor.energy.spend(cost): return _reject(&"energy")
	if next_mode != &"pulse": cooldowns[selected] = data.cooldown
	_mode = next_mode
	_definition = data
	_time = 0.0
	_root = next_root
	_target = target
	_direction = (target - actor.aim.global_position).normalized()
	if _direction.is_zero_approx(): _direction = actor.aim.direction
	_launched = false
	_attempted = false
	if next_mode == &"counter": counter_remaining = 0.0
	actor.action_state_machine.transition_to(&"cultivation_skill")
	technique_committed.emit(selected, _root)
	return true

func _reject(reason: StringName) -> bool:
	last_rejection = reason
	return false

func advance_skill(delta: float) -> void:
	if not is_instance_valid(_room) or _room.is_queued_for_deletion():
		cancel_for_room_transition()
		return
	_time += delta
	var windup: float = _definition.pulse_windup if _mode == &"pulse" else _definition.windup
	var active: float = _definition.pulse_active if _mode == &"pulse" else _definition.active
	if not _launched and _time >= windup:
		_launched = true
		if _mode == &"place":
			mark = CultivationSigil.new()
			mark.runtime = self
			mark.data = _definition
			mark.root_id = _root
			_room.add_child(mark)
			mark.global_position = _target
		elif _mode == &"pulse":
			if not is_instance_valid(mark) or actor.aim.global_position.distance_to(mark.global_position) > _definition.activation_range or not clear_line(actor.aim.global_position, mark.global_position):
				actor.action_state_machine.transition_to(&"ready")
				return
			mark.begin_pulse()
		else:
			var attack := AttackSnapshot.new()
			attack.source_id = actor.get_instance_id()
			attack.source_team_id = 1
			attack.attack_id = _root
			attack.root_event_id = _root
			attack.attack_direction = _direction
			var shape := RectangleShape2D.new()
			shape.size = Vector2(56, 40)
			hitbox.activate(attack, shape, Vector2(40, 0))
	if _time >= windup + active: hitbox.deactivate()
	if _time >= windup + active + _definition.recovery: actor.action_state_machine.transition_to(&"ready")

func end_skill(next_id: StringName) -> void:
	if is_instance_valid(hitbox): hitbox.deactivate()
	if _mode == &"": return
	var finished_id: StringName = _definition.id
	var finished_mode: StringName = _mode
	var windup: float = _definition.pulse_windup if finished_mode == &"pulse" else _definition.windup
	var active: float = _definition.pulse_active if finished_mode == &"pulse" else _definition.active
	var completed: bool = next_id == &"ready" and _launched and _time >= windup + active + _definition.recovery
	# FSM.current_state still points at this action during exit(). Close the
	# technique first, then notify after transition_to() has installed next_id.
	# A progression observer may revoke/respec here without re-entering exit().
	_mode = &""
	_definition = null
	_launched = false
	_attempted = false
	_time = 0.0
	_root = 0
	if finished_mode == &"pulse" and not completed and is_instance_valid(mark): mark.cancel()
	call_deferred(&"_notify_finished", finished_id, &"completed" if completed else &"cancelled")
	queue_redraw()

func _notify_finished(id: StringName, reason: StringName) -> void:
	technique_finished.emit(id, reason)

func _physics_process(delta: float) -> void:
	if not _initialized or is_frozen(): return
	if actor.equipped_weapon.definition != _weapon_definition:
		_weapon_definition = actor.equipped_weapon.definition
		cancel_for_room_transition()
	for id: StringName in cooldowns: cooldowns[id] = maxf(0.0, float(cooldowns[id]) - delta)
	counter_remaining = maxf(0.0, counter_remaining - delta)
	global_position = actor.aim.global_position
	global_rotation = _direction.angle()
	if hitbox.active: hitbox.sample_contacts()
	queue_redraw()

func _observe_dodge(event: DamageEvent, result: DamageResult) -> void:
	if selected != &"cloud_return" or selected not in learned or counter_remaining > 0 or float(cooldowns[&"cloud_return"]) > 0: return
	if actor.equipped_weapon.definition.id != &"ancient_sword": return
	if not result.blocked or result.block_reason != &"invulnerable" or event.source_kind != DamageEvent.SourceKind.DIRECT or not actor.motor.is_dashing or not actor.motor.is_invulnerable(): return
	if event.source_team_id == 1 or event.root_event_id <= 0 or _recent_dodges.has(event.root_event_id): return
	var source: Node = instance_from_id(event.source_id) as Node if is_instance_id_valid(event.source_id) else null
	if not is_instance_valid(source) or not source.is_in_group(&"enemies") or source.health.current_health <= 0: return
	if not event.physical_damage and not (source is SlimeEnemy and source.global_position.distance_to(actor.global_position) < 100): return
	if _recent_dodges.size() >= 64: _recent_dodges.erase(_recent_dodges.keys()[0])
	_recent_dodges[event.root_event_id] = true
	counter_remaining = DATA[&"cloud_return"].counter_window
	counter_root = event.root_event_id
	counter_readied.emit(counter_root)

func _counter_contact(target: Hurtbox, attack: AttackSnapshot) -> void:
	if _attempted: return
	if not clear_line(global_position, target.global_position): return
	_attempted = true
	hitbox.deactivate()
	var event: DamageEvent = make_event(target, attack, _definition.damage)
	event.physical_damage = true
	event.melee_hit = true
	event.stagger_force = 10
	event.knockback = _direction * 80
	var result: DamageResult = target.take_damage(event)
	if not result.blocked: confirm_hit(event, result)

func make_event(target: Hurtbox, attack: AttackSnapshot, damage: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = attack.source_id
	event.source_team_id = 1
	event.target_id = target.get_actor_id()
	event.attack_id = attack.attack_id
	event.root_event_id = attack.root_event_id
	event.hit_window_id = 1
	event.base_damage = damage
	event.attack_direction = attack.attack_direction
	event.hit_position = target.global_position
	event.allow_resonance = false
	return event

func confirm_hit(event: DamageEvent, result: DamageResult) -> void:
	accepted_hits += 1
	if is_instance_valid(actor.combat_feedback): actor.combat_feedback.on_hit_confirmed(event, result)

func clear_line(origin: Vector2, target: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(origin, target, 1)
	return actor.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func cancel_for_room_transition() -> void:
	if _initialized and actor.action_state_machine.get_state_id() == &"cultivation_skill": actor.action_state_machine.transition_to(&"ready")
	counter_remaining = 0.0
	if is_instance_valid(mark): mark.cancel()
	mark = null

func _action_changed(_previous: StringName, next: StringName) -> void:
	if next in [&"hurt", &"dead"]:
		counter_remaining = 0
		if is_instance_valid(mark): mark.cancel()
		mark = null

func _weapon_changed(_weapon: WeaponDefinition) -> void:
	cancel_for_room_transition()

func _exit_tree() -> void:
	if is_instance_valid(_room) and _room.tree_exiting.is_connected(cancel_for_room_transition): _room.tree_exiting.disconnect(cancel_for_room_transition)
	if not _initialized or not is_instance_valid(actor) or not is_instance_valid(actor.action_state_machine): return
	cancel_for_room_transition()
	if is_instance_valid(actor.hurtbox) and actor.hurtbox.hit_resolved.is_connected(_observe_dodge): actor.hurtbox.hit_resolved.disconnect(_observe_dodge)
	if actor.action_state_machine.state_changed.is_connected(_action_changed): actor.action_state_machine.state_changed.disconnect(_action_changed)
	if actor.weapon_changed.is_connected(_weapon_changed): actor.weapon_changed.disconnect(_weapon_changed)
	actor.action_state_machine.unregister_state(&"cultivation_skill")

func _draw() -> void:
	if not _initialized: return
	if counter_remaining > 0:
		draw_arc(Vector2.ZERO, 22, 0, TAU, 24, Color(0.5, 0.95, 1, counter_remaining / DATA[&"cloud_return"].counter_window), 2)
	if _mode == &"counter":
		draw_arc(Vector2.ZERO, 68, -0.7, 0.7, 18, Color(_definition.tint, 1 if hitbox.active else 0.45), 3)
	elif _mode == &"place":
		draw_line(Vector2.ZERO, to_local(_target), Color(_definition.tint, 0.4), 1)
		draw_arc(to_local(_target), _definition.radius, 0, TAU, 32, Color(_definition.tint, 0.4), 2)

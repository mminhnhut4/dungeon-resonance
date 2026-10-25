class_name TanDangLivingSlime
extends SlimeEnemy
## P01 encounter only. Uses the ordinary slime scene's real body, Health,
## Hurtbox, Hitbox, Status and motor, with a local NPC target policy.

const BITE_DAMAGE: float = 15.0
var resident: CultivatorActor
var _living_phase: String = "idle"
var _phase_time: float = 0.0
var _bite_window: int = 0

func _ready() -> void:
	super._ready()
	name = "TanDangRoadSlime"
	bite_hitbox.collision_mask = 8 | 16
	contact_damage_enabled = false
	_living_phase = "idle"

func enter_state(id: StringName) -> void:
	if id != &"attack":
		super.enter_state(id)
		return
	# The shared slime's attack entry points at `player`, which is null after
	# player hit-aggro expires. This encounter can still attack its resident.
	state_history.append(id)
	if state_history.size() > 64: state_history.pop_front()
	_state_time = 0.0
	var target: Node2D = _living_target()
	if is_instance_valid(target): _facing = -1.0 if target.global_position.x < global_position.x else 1.0
	_bite_started = false

func _forget_player_target() -> void:
	super._forget_player_target()
	_cancel_bite()

func _living_target() -> Node2D:
	if hit_aggro.active() and is_instance_valid(player): return player
	if is_instance_valid(resident) and resident.is_inside_tree() and not resident.is_queued_for_deletion() and resident.get_parent() == get_parent() and resident.health.current_health > 1.0 and resident.world_state.records[resident.stable_id]["mode"] not in ["talk","dead","downed","recovering"]: return resident
	return null

func suspend_encounter() -> void:
	_cancel_bite()
	if is_instance_valid(motor): motor.stop_horizontal()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(health) or health.current_health <= 0.0:
		bite_hitbox.deactivate()
		_state_time += minf(delta,0.1)
		visual.modulate.a = maxf(0.0,1.0-_state_time/0.25)
		if _state_time >= 0.25: queue_free()
		return
	if not ai_enabled or (is_instance_valid(combat_feedback) and combat_feedback.is_frozen()): return
	if hit_aggro.advance(delta): _forget_player_target()
	var step: float = minf(delta,0.1)
	var attack_step: float = step*attack_rate_multiplier*statuses.attack_speed_multiplier
	_state_time += attack_step if state_machine.get_state_id() == &"attack" else step
	_attack_cooldown = maxf(0.0,_attack_cooldown-attack_step)
	_flash_remaining = maxf(0.0,_flash_remaining-step)
	var target: Node2D = _living_target()
	var motion: float = 0.0
	if statuses.is_stunned():
		_cancel_bite()
		if state_machine.get_state_id() != &"hurt": state_machine.transition_to(&"hurt")
	elif _hurt_remaining > 0.0:
		_hurt_remaining = maxf(0.0,_hurt_remaining-step)
		_cancel_bite()
		if _hurt_remaining <= 0.0: state_machine.transition_to(&"chase" if is_instance_valid(target) else &"patrol")
	elif state_machine.get_state_id() == &"hurt":
		state_machine.transition_to(&"chase" if is_instance_valid(target) else &"patrol")
	elif not is_instance_valid(target) or (_living_phase == "idle" and not hit_aggro.active() and (global_position.distance_to(target.global_position) > (aggro_radius if state_machine.get_state_id() == &"patrol" else 260.0) or not _living_line(target))):
		_cancel_bite()
		if state_machine.get_state_id() == &"chase": state_machine.transition_to(&"patrol")
	else:
		var difference: Vector2 = target.global_position-global_position
		if _living_phase == "idle" and absf(difference.x) > 0.1: _facing = signf(difference.x)
		match _living_phase:
			"idle":
				if difference.length() <= attack_range and _attack_cooldown <= 0.0:
					_living_phase = "tell"
					_phase_time = telegraph_seconds
					state_machine.transition_to(&"attack")
				elif difference.length() > attack_range and _has_floor_ahead(_facing):
					motion = _facing*chase_speed
					state_machine.transition_to(&"chase")
			"tell":
				_phase_time = maxf(0.0,_phase_time-attack_step)
				if _phase_time <= 0.0:
					_open_living_bite()
			"active":
				if _has_floor_ahead(_facing): motion = _facing*260.0
				_phase_time = maxf(0.0,_phase_time-attack_step)
				if _phase_time <= 0.0:
					bite_hitbox.deactivate()
					_living_phase = "recover"
					_phase_time = 0.30
					_attack_cooldown = 0.6
			"recover":
				_phase_time = maxf(0.0,_phase_time-attack_step)
				if _phase_time <= 0.0:
					_living_phase = "idle"
					state_machine.transition_to(&"chase")
	motor.step(delta,INF,motion*condition_speed_multiplier*statuses.movement_multiplier)
	if bite_hitbox.active: bite_hitbox.sample_contacts()
	# Exterior P01's ground is around y=1500; the dungeon slime's y>850
	# cleanup is deliberately not inherited. The room lifetime owns disposal.
	if get_parent() is ExteriorRoom and global_position.y > (get_parent() as ExteriorRoom).bounds.end.y: queue_free()
	_update_visuals()

func _living_line(target: Node2D) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-14),target.global_position+Vector2(0,-18),1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _open_living_bite() -> void:
	var attack := AttackSnapshot.new()
	attack.source_id = get_instance_id()
	attack.source_team_id = 2
	attack.attack_id = CombatIds.next_id()
	attack.root_event_id = attack.attack_id
	attack.base_damage = BITE_DAMAGE
	attack.attack_direction = Vector2(_facing,0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40,28)
	bite_hitbox.collision_mask = 8 | 16
	bite_hitbox.activate(attack,shape,Vector2(_facing*26.0,-14))
	_bite_window += 1
	_living_phase = "active"
	_phase_time = 0.12

func _bite_contact(target: Hurtbox, attack: AttackSnapshot) -> void:
	if _living_phase != "active" or not is_instance_valid(target): return
	if target != (resident.hurtbox if is_instance_valid(resident) else null) and target != (player.hurtbox if is_instance_valid(player) else null): return
	var event := DamageEvent.new()
	event.source_id = attack.source_id
	event.source_team_id = attack.source_team_id
	event.target_id = target.get_actor_id()
	event.attack_id = attack.attack_id
	event.root_event_id = attack.root_event_id
	event.hit_window_id = 1
	event.base_damage = attack.base_damage
	event.attack_direction = attack.attack_direction
	event.attack_origin = global_position+Vector2(0,-14)
	event.aim_position = target.global_position
	event.physical_damage = true
	event.melee_hit = true
	event.hit_reaction = &"flinch"
	var result: DamageResult = target.take_damage(event)
	if is_instance_valid(combat_feedback): combat_feedback.on_hit_confirmed(event,result)

func _cancel_bite() -> void:
	if _living_phase == "idle": return
	bite_hitbox.deactivate()
	_living_phase = "idle"
	_phase_time = 0.0
	if state_machine.get_state_id() not in [&"hurt",&"dead"]: state_machine.transition_to(&"patrol")

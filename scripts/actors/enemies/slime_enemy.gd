class_name SlimeEnemy
extends CharacterBody2D
## Passive patrol until aggro; distinct FSM, movement, damage and presentation.

@export var motor: KnockbackMotor
@export var state_machine: ActorStateMachine
@export var health: HealthComponent
@export var hurtbox: Hurtbox
@export var statuses: StatusController
@export var bite_hitbox: Hitbox
@export var visual: Polygon2D
@export var stats: Label
@export var patrol_left: Marker2D
@export var patrol_right: Marker2D
@export var floating_text_scene: PackedScene
@export var ai_enabled: bool = true
@export var patrol_speed: float = 65.0
@export var chase_speed: float = 115.0
@export var aggro_radius: float = 200.0
@export var attack_range: float = 40.0
@export var telegraph_seconds: float = 0.3
@export var contact_damage_enabled: bool = false
var _contact_cooldown: float = 0.0
var condition_speed_multiplier: float = 1.0
var attack_rate_multiplier: float = 1.0
var enraged: bool = false
var is_elite: bool = false
var player: CharacterBody2D
var combat_feedback: CombatFeedback
var damage_number_spawner: DamageNumberSpawner
var _left_x: float
var _right_x: float
var _home: Vector2
var _facing: float = -1.0
var _desired_velocity: float = 0.0
var _state_time: float = 0.0
var _attack_cooldown: float = 0.0
var _hurt_remaining: float = 0.0
var _flash_remaining: float = 0.0
var _bite_started: bool = false
var hit_count: int = 0
var last_damage_event: DamageEvent
var state_history: Array[StringName] = []
var hit_aggro: EnemyHitAggro=EnemyHitAggro.new()


func _ready() -> void:
	_home = global_position
	hit_aggro.bind(self,player)
	_left_x = patrol_left.global_position.x
	_right_x = patrol_right.global_position.x
	state_machine.initialize(self)
	hit_aggro.target_lost.connect(_forget_player_target)
	hurtbox.damage_resolver.damage_resolved.connect(_on_hit)
	health.died.connect(_on_died)
	statuses.damage_requested.connect(hurtbox.take_damage)
	bite_hitbox.contact_detected.connect(_bite_contact)


func _physics_process(delta: float) -> void:
	if not ai_enabled or (is_instance_valid(combat_feedback) and combat_feedback.is_frozen()):
		return
	if hit_aggro.advance(delta): _forget_player_target()
	if hit_aggro.active(): player=hit_aggro.target()
	if is_instance_valid(player) and player.health.current_health<=0.0: _forget_player_target()
	if enraged and not hit_aggro.active() and not hit_aggro.sight_suppressed:
		_choose_manhunter_target()
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta * attack_rate_multiplier * statuses.attack_speed_multiplier)
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	_state_time += delta * (attack_rate_multiplier * statuses.attack_speed_multiplier if state_machine.get_state_id() == &"attack" else 1.0)
	_desired_velocity = 0.0
	state_machine.physics_update(delta)
	if state_machine.get_state_id() in [&"patrol", &"chase"]:
		for entity: Node in get_tree().get_nodes_in_group(&"spell_entities"):
			if entity is ElementField and entity.context.snapshot.behavior_id == &"miasma_cloud" and global_position.distance_to(entity.global_position) < entity.context.snapshot.effect_radius + 30.0:
				var escape: float = signf(global_position.x - entity.global_position.x)
				_desired_velocity = (escape if not is_zero_approx(escape) else -_facing) * chase_speed
	if state_machine.get_state_id() != &"dead":
		motor.step(delta, INF, _desired_velocity * condition_speed_multiplier * statuses.movement_multiplier)
	bite_hitbox.sample_contacts()
	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)
	if contact_damage_enabled and _contact_cooldown <= 0.0 and health.current_health > 0.0 and is_instance_valid(player) and global_position.distance_to(player.global_position) < 25.0:
		var contact := AttackSnapshot.new()
		contact.source_id = get_instance_id()
		contact.attack_id = CombatIds.next_id()
		contact.root_event_id = contact.attack_id
		contact.attack_direction = (player.global_position - global_position).normalized()
		_bite_contact(player.hurtbox, contact)
		_contact_cooldown = 0.6
	if global_position.y > 850.0:
		queue_free()
	_update_visuals()


func enter_state(id: StringName) -> void:
	state_history.append(id)
	if state_history.size() > 64:
		state_history.pop_front()
	_state_time = 0.0
	if id == &"attack":
		_facing = -1.0 if player.global_position.x < global_position.x else 1.0
		_bite_started = false
	elif id == &"dead":
		bite_hitbox.deactivate()
		hurtbox.set_invulnerable(true)
		statuses.clear()
		var puff := SpellVisual.new()
		puff.color = Color(0.4, 1.0, 0.55)
		puff.radius = 28.0
		puff.feedback = combat_feedback
		get_parent().add_child(puff)
		puff.global_position = global_position + Vector2(0, -12)


func tick_state(id: StringName, delta: float) -> void:
	if id == &"dead":
		visual.modulate.a = maxf(0.0, 1.0 - _state_time / 0.25)
		if _state_time >= 0.25:
			queue_free()
		return
	if statuses.is_stunned():
		bite_hitbox.deactivate()
		_desired_velocity = NAN
		if id != &"hurt":
			state_machine.transition_to(&"hurt")
		return
	match id:
		&"patrol":
			if _can_see_player():
				state_machine.transition_to(&"chase")
				return
			if global_position.x <= _left_x:
				_facing = 1.0
			elif global_position.x >= _right_x:
				_facing = -1.0
			elif is_on_wall() or (is_on_floor() and not _has_floor_ahead(_facing)):
				_facing *= -1.0
			_desired_velocity = _facing * patrol_speed
		&"chase":
			if not _can_see_player(260.0):
				state_machine.transition_to(&"patrol")
				return
			var offset: Vector2 = player.global_position - global_position
			_facing = -1.0 if offset.x < 0.0 else 1.0
			if offset.length() <= attack_range and _target_path_clear():
				if _attack_cooldown <= 0.0:
					state_machine.transition_to(&"attack")
			elif not is_on_floor() or _has_floor_ahead(_facing):
				_desired_velocity = _facing * chase_speed
		&"attack":
			if not _bite_started and _state_time >= telegraph_seconds:
				_bite_started = true
				_start_bite()
			if _bite_started and _state_time < telegraph_seconds + 0.12:
				_desired_velocity = _facing * 260.0 if _has_floor_ahead(_facing) else 0.0
			elif _bite_started:
				bite_hitbox.deactivate()
			if _state_time >= telegraph_seconds + 0.42:
				_attack_cooldown = 0.6
				state_machine.transition_to(&"chase" if _can_see_player() else &"patrol")
		&"hurt":
			_desired_velocity = NAN
			_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
			if _hurt_remaining <= 0.0:
				state_machine.transition_to(&"chase" if _can_see_player() else &"patrol")


func _can_see_player(radius: float = -1.0) -> bool:
	if not is_instance_valid(player) or player.health.current_health <= 0.0:
		return false
	if hit_aggro.active(): return true
	if hit_aggro.sight_suppressed: return false
	var range_limit: float = aggro_radius if radius < 0.0 else radius
	if global_position.distance_to(player.global_position) > range_limit:
		return false
	return _target_path_clear()

func _target_path_clear() -> bool:
	if not is_instance_valid(player): return false
	var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -14), player.global_position + Vector2(0, -18), 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _forget_player_target() -> void:
	hit_aggro.forget()
	player=null
	bite_hitbox.deactivate()
	motor.stop_horizontal()
	if health.current_health>0.0 and state_machine.get_state_id() in [&"chase",&"attack"]: state_machine.transition_to(&"patrol")


func _has_floor_ahead(direction: float) -> bool:
	var start: Vector2 = global_position + Vector2(direction * 26.0, -8)
	var ray := PhysicsRayQueryParameters2D.create(start, start + Vector2(0, 42), 1)
	return not get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _start_bite() -> void:
	var attack := AttackSnapshot.new()
	attack.source_id = get_instance_id()
	attack.source_team_id = 0 if enraged else 2
	attack.attack_id = CombatIds.next_id()
	attack.root_event_id = attack.attack_id
	attack.base_damage = 15.0
	attack.attack_direction = Vector2(_facing, 0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 28)
	bite_hitbox.activate(attack, shape, Vector2(_facing * 26.0, -14))


func _bite_contact(target: Hurtbox, attack: AttackSnapshot) -> void:
	var event := DamageEvent.new()
	event.source_id = attack.source_id
	event.source_team_id = 0 if enraged else 2
	event.target_id = target.get_actor_id()
	event.attack_id = attack.attack_id
	event.root_event_id = attack.root_event_id
	event.hit_window_id = 1
	event.base_damage = 15.0
	event.attack_direction = attack.attack_direction
	var result: DamageResult = target.take_damage(event)
	if is_instance_valid(combat_feedback):
		combat_feedback.on_hit_confirmed(event, result)


func _on_hit(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked:
		return
	if hit_aggro.record(event,result): player=hit_aggro.target()
	hit_count += 1
	last_damage_event = event
	_flash_remaining = 0.16
	visual.color = Color.WHITE
	if not event.knockback.is_zero_approx():
		motor.stop_horizontal()
	motor.add_knockback(event.knockback)
	_hurt_remaining = 0.18
	if health.current_health > 0.0:
		state_machine.transition_to(&"hurt")
	if is_instance_valid(combat_feedback):
		combat_feedback.on_hit_confirmed(event, result)
	var number_position: Vector2 = global_position + Vector2(0, -60)
	if is_instance_valid(damage_number_spawner):
		damage_number_spawner.spawn_damage(event, result, number_position, combat_feedback)
	else:
		var text := floating_text_scene.instantiate() as FloatingCombatText
		get_parent().add_child(text)
		text.global_position = number_position
		text.setup(result.actual_damage, event.attack_direction, combat_feedback, event.critical)


func _on_died() -> void:
	hit_aggro.forget()
	player=null
	state_machine.transition_to(&"dead")


func _update_visuals() -> void:
	var id: StringName = state_machine.get_state_id()
	visual.color = Color.WHITE if _flash_remaining > 0.12 else Color(1, 0.2, 0.15) if _flash_remaining > 0.0 else Color(1, 0.82, 0.2) if id == &"attack" and _state_time < telegraph_seconds else Color(0.35, 0.86, 0.5)
	stats.text = "%d HP · %s%s" % [roundi(health.current_health), id.to_upper(), " · STUN" if statuses.is_stunned() else " · BURN" if statuses.burn_remaining > 0.0 else ""]
	$Eyes.default_color = Color(1.0, 0.08, 0.08) if enraged else Color(0.05, 0.16, 0.1)


func _choose_manhunter_target() -> void:
	var best: float = INF
	for candidate: Node in get_tree().get_nodes_in_group(&"enemies") + get_tree().get_nodes_in_group(&"players"):
		if candidate == self or candidate.health.current_health <= 0.0:
			continue
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < best:
			best = distance
			player = candidate as CharacterBody2D


func apply_pull(pull_velocity: Vector2) -> void:
	motor.apply_pull(pull_velocity)


func reset_at_home() -> void:
	var candidate: Player=hit_aggro.preferred_player()
	if is_instance_valid(candidate): player=candidate
	hit_aggro.release()
	hit_aggro=EnemyHitAggro.new()
	hit_aggro.bind(self,player)
	hit_aggro.target_lost.connect(_forget_player_target)
	global_position = _home
	motor.reset_motion()
	health.reset_health()
	statuses.clear()
	hurtbox.damage_resolver.reset_history()
	hurtbox.set_invulnerable(false)
	bite_hitbox.deactivate()
	visual.modulate = Color.WHITE
	_attack_cooldown = 0.0
	_hurt_remaining = 0.0
	_flash_remaining = 0.0
	_facing = -1.0
	_left_x = _home.x + patrol_left.position.x
	_right_x = _home.x + patrol_right.position.x
	_state_time = 0.0
	hit_count = 0
	last_damage_event = null
	state_machine.transition_to(&"patrol")

func _exit_tree() -> void:
	hit_aggro.release()

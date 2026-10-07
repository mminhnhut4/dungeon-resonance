class_name BaseEnemy
extends CharacterBody2D
## New opt-in monster family; no Slime/Player/legacy FSM changes.

signal defeated(enemy: BaseEnemy)
@export var definition: WorldEnemyData
@export var ai_enabled: bool = true
var enemy_type: StringName
var player: CharacterBody2D
var combat_feedback: CombatFeedback
var health: HealthComponent
var statuses: ElementStatusController
var hurtbox: Hurtbox
var motor: WorldEnemyMotor
var state_machine: ActorStateMachine
var attack_hitbox: Hitbox
var visual: WorldEnemyVisual
var is_elite: bool = false
var enraged: bool = false
var condition_speed_multiplier: float = 1.0
var attack_rate_multiplier: float = 1.0
var state_time: float = 0.0
var clock: float = 0.0
var facing: float = -1.0
var locked_direction: Vector2 = Vector2.LEFT
var locked_target: Vector2 = Vector2.ZERO
var attack_kind: StringName = &"sweep"
var flash_remaining: float = 0.0
var attack_cooldown: float = 0.0
var hit_count: int = 0
var attacks_started: int = 0
var state_history: Array[StringName] = []
var _home: Vector2
var _desired: Vector2 = Vector2.ZERO
var _hurt_remaining: float = 0.0
var _death_emitted: bool = false
var _attack_shape: Shape2D
var hit_aggro: EnemyHitAggro=EnemyHitAggro.new()

func _ready() -> void:
	assert(definition != null)
	add_to_group(&"enemies")
	add_to_group(&"world_enemies")
	enemy_type = definition.id
	_home = global_position
	collision_layer = 4
	collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = definition.body_size
	var collider: CollisionShape2D = $BodyCollision as CollisionShape2D
	collider.shape = shape
	collider.position = Vector2(0, -definition.body_size.y * 0.5)
	if definition.shield_hp > 0.0:
		var shield := EnemyShieldHealth.new()
		shield.maximum_shield = definition.shield_hp
		health = shield
	else:
		health = HealthComponent.new()
	health.name = "Health"
	health.maximum_health = definition.maximum_hp
	add_child(health)
	statuses = ElementStatusController.new()
	statuses.name = "Statuses"
	statuses.health = health
	statuses.combat_feedback = combat_feedback
	add_child(statuses)
	var resolver := DamageResolver.new()
	resolver.health = health
	resolver.status_controller = statuses
	resolver.name = "DamageResolver"
	add_child(resolver)
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.actor_body = self
	hurtbox.health = health
	hurtbox.damage_resolver = resolver
	hurtbox.team_id = 2
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.position = collider.position
	var hurt_shape := CollisionShape2D.new()
	hurt_shape.shape = shape
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)
	statuses.damage_requested.connect(hurtbox.take_damage)
	resolver.damage_resolved.connect(_on_hit)
	health.died.connect(_on_died)
	motor = WorldEnemyMotor.new()
	motor.body = self
	add_child(motor)
	attack_hitbox = ActorCombatRig.hitbox(self, 8)
	attack_hitbox.contact_detected.connect(_attack_contact)
	hit_aggro.bind(self,player)
	state_machine = ActorStateMachine.new()
	state_machine.name = "StateMachine"
	for id: StringName in [&"patrol", &"chase", &"telegraph", &"attack", &"recover", &"hurt", &"dead"]:
		var state := WorldEnemyState.new()
		state.name = String(id).to_pascal_case()
		state.state_id = id
		state_machine.add_child(state)
		if id == &"patrol": state_machine.initial_state = state
	add_child(state_machine)
	state_machine.initialize(self)
	hit_aggro.target_lost.connect(_forget_player_target)
	visual = WorldEnemyVisual.new()
	visual.name = "WorldEnemyVisual"
	add_child(visual)
	visual.bind(self)

func _physics_process(delta: float) -> void:
	if is_instance_valid(combat_feedback) and combat_feedback.is_frozen(): return
	if not ai_enabled and health.current_health > 0.0: return
	if hit_aggro.advance(delta): _forget_player_target()
	if hit_aggro.active(): player=hit_aggro.target()
	if is_instance_valid(player) and player.health.current_health<=0.0: _forget_player_target()
	clock += delta
	flash_remaining = maxf(0.0, flash_remaining - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta * attack_rate_multiplier * statuses.attack_speed_multiplier)
	state_time += delta * (attack_rate_multiplier * statuses.attack_speed_multiplier if state_machine.get_state_id() in [&"telegraph", &"attack", &"recover"] else 1.0)
	_desired = Vector2.ZERO
	if enraged and not hit_aggro.active() and not hit_aggro.sight_suppressed: _choose_target()
	state_machine.physics_update(delta)
	if state_machine.get_state_id() != &"dead":
		motor.step_world(delta, _desired * condition_speed_multiplier * statuses.movement_multiplier, definition.flying)
		attack_hitbox.sample_contacts()
	if global_position.y > 900.0 and health.current_health > 0.0:
		health.apply_damage(health.current_health + definition.shield_hp)

func enter_state(id: StringName) -> void:
	state_time = 0.0
	state_history.append(id)
	if state_history.size() > 64: state_history.pop_front()
	if id == &"telegraph":
		locked_target = player.global_position + Vector2(0, -18) if is_instance_valid(player) else global_position + Vector2(facing * 60, -18)
		locked_direction = (locked_target - (global_position + Vector2(0, -22))).normalized()
		facing = -1.0 if locked_direction.x < 0.0 else 1.0
		match definition.moveset:
			WorldEnemyData.Moveset.BAT_DIVE:
				attack_kind = &"dive" if global_position.distance_to(locked_target) <= 225.0 else &"jade_bolt"
			WorldEnemyData.Moveset.PHASE_THRUST: attack_kind = &"phase_thrust"
			WorldEnemyData.Moveset.SHIELD_FIELD: attack_kind = &"slow_field"
			_: attack_kind = &"sweep"
	elif id == &"attack":
		_start_attack()
	elif id == &"recover":
		attack_cooldown = definition.cooldown
	elif id == &"dead":
		attack_hitbox.deactivate()
		hurtbox.set_invulnerable(true)
		statuses.clear()
		motor.reset_motion()
		if not _death_emitted:
			_death_emitted = true
			defeated.emit(self)
		var audio: Node = get_node_or_null("/root/AudioManager")
		if audio != null: audio.stop_owner(self)

func tick_state(id: StringName, delta: float) -> void:
	if id == &"dead":
		if state_time >= 0.30: queue_free()
		return
	if statuses.is_stunned():
		attack_hitbox.deactivate()
		if id != &"hurt":
			_hurt_remaining = 0.18
			state_machine.transition_to(&"hurt")
		_desired = Vector2(NAN, NAN)
		return
	match id:
		&"patrol":
			if _can_see_target():
				state_machine.transition_to(&"chase")
				return
			if global_position.x < _home.x - 95: facing = 1.0
			elif global_position.x > _home.x + 95 or is_on_wall() or (not definition.flying and is_on_floor() and not _has_floor_ahead(facing)): facing *= -1.0
			_desired = Vector2(facing * definition.patrol_speed, sin(clock * 2) * 12 if definition.flying else 0.0)
		&"chase":
			if not _can_see_target(definition.aggro_radius + 100):
				state_machine.transition_to(&"patrol")
				return
			var offset: Vector2 = player.global_position - global_position
			facing = -1.0 if offset.x < 0.0 else 1.0
			if offset.length() <= definition.attack_range and attack_cooldown <= 0.0 and _target_path_clear():
				state_machine.transition_to(&"telegraph")
			elif definition.flying:
				var height: float = 130.0 if definition.moveset == WorldEnemyData.Moveset.BAT_DIVE else 35.0
				var target: Vector2 = player.global_position + Vector2(-facing * 150, -height)
				_desired = (target - global_position).limit_length(definition.chase_speed)
			elif offset.length() > definition.attack_range and _has_floor_ahead(facing):
				# During cooldown, grounded enemies already in range wait for their
				# next tell instead of alternating micro-chase steps at the target.
				_desired.x = facing * definition.chase_speed
		&"telegraph":
			if state_time >= definition.windup: state_machine.transition_to(&"attack")
		&"attack":
			if attack_kind in [&"dive", &"phase_thrust"]:
				_desired = locked_direction * (390.0 if attack_kind == &"dive" else 660.0)
				if is_on_wall(): state_machine.transition_to(&"recover")
			if state_time >= definition.active: state_machine.transition_to(&"recover")
		&"recover":
			if definition.flying:
				_desired = Vector2(0, clampf(_home.y - global_position.y, -100, 100))
			if state_time >= definition.recovery: state_machine.transition_to(&"chase" if _can_see_target() else &"patrol")
		&"hurt":
			_desired = Vector2(NAN, NAN)
			_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
			if _hurt_remaining <= 0.0: state_machine.transition_to(&"chase" if _can_see_target() else &"patrol")

func _start_attack() -> void:
	attacks_started += 1
	if attack_kind in [&"dive", &"phase_thrust"]:
		_desired = locked_direction * (390.0 if attack_kind == &"dive" else 660.0)
		motor.commit_burst(_desired * condition_speed_multiplier * statuses.movement_multiplier)
	if attack_kind in [&"jade_bolt", &"slow_field"]:
		_spawn_hazard(attack_kind)
		return
	var attack := AttackSnapshot.new()
	attack.source_id = get_instance_id()
	attack.source_team_id = 0 if enraged else 2
	attack.attack_id = CombatIds.next_id()
	attack.root_event_id = attack.attack_id
	attack.attack_direction = locked_direction
	attack_hitbox.collision_mask = 8 | (16 if enraged else 0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(96, 26) if attack_kind == &"sweep" else Vector2(42, 32)
	_attack_shape = shape
	attack_hitbox.activate(attack, shape, Vector2(facing * 44, -16) if attack_kind == &"sweep" else Vector2(0, -20))

func _spawn_hazard(kind: StringName) -> void:
	var sources: Array[Node] = get_tree().get_nodes_in_group(&"world_enemy_hazards")
	if sources.size() >= WorldEnemyHazard.MAX_HAZARDS or (kind == &"slow_field" and get_tree().get_nodes_in_group(&"world_slow_fields").size() >= WorldEnemyHazard.MAX_FIELDS): return
	var hazard := WorldEnemyHazard.new()
	hazard.kind = kind
	hazard.player = player
	hazard.source_id = get_instance_id()
	hazard.hostile_to_all = enraged
	hazard.feedback = combat_feedback
	hazard.direction = locked_direction
	var spawn_position: Vector2 = locked_target + Vector2(0, 18) if kind == &"slow_field" else global_position + Vector2(0, -22)
	get_parent().add_child(hazard)
	hazard.global_position = spawn_position

func _attack_contact(target: Hurtbox, attack: AttackSnapshot) -> void:
	var event := DamageEvent.new()
	event.source_id = attack.source_id
	event.source_team_id = attack.source_team_id
	event.target_id = target.get_actor_id()
	event.attack_id = attack.attack_id
	event.root_event_id = attack.root_event_id
	event.hit_window_id = 1
	event.base_damage = definition.attack_damage
	event.attack_direction = attack.attack_direction
	event.physical_damage = true
	event.heavy_hit = attack_kind == &"sweep"
	event.hit_reaction = &"knockback" if attack_kind == &"sweep" else &"flinch"
	event.knockback = Vector2(facing * 150, -65) if attack_kind == &"sweep" else locked_direction * 90
	var result: DamageResult = target.take_damage(event)
	if is_instance_valid(combat_feedback): combat_feedback.on_hit_confirmed(event, result)

func _on_hit(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked: return
	if hit_aggro.record(event,result): player=hit_aggro.target()
	hit_count += 1
	if event.source_kind != DamageEvent.SourceKind.DOT:
		flash_remaining = 0.12
		if health.current_health > 0.0 and (not has_poise() or statuses.is_stunned()):
			motor.stop_horizontal()
			motor.add_knockback(event.knockback)
			_hurt_remaining = 0.18
			state_machine.transition_to(&"hurt")
		if is_instance_valid(combat_feedback): combat_feedback.on_hit_confirmed(event, result)
	var text := preload("res://scenes/effects/floating_combat_text.tscn").instantiate() as FloatingCombatText
	get_parent().add_child(text)
	text.global_position = global_position + Vector2(0, -definition.visual_height - 8)
	text.setup(result.actual_damage, event.attack_direction, combat_feedback, event.critical)

func has_poise() -> bool:
	return definition.moveset == WorldEnemyData.Moveset.SABER_SWEEP and state_machine.get_state_id() == &"attack" and not statuses.is_stunned()

func _on_died() -> void:
	hit_aggro.forget()
	player=null
	state_machine.transition_to(&"dead")

func _can_see_target(radius: float = -1.0) -> bool:
	if not is_instance_valid(player) or player.health.current_health <= 0.0: return false
	if hit_aggro.active(): return true
	if hit_aggro.sight_suppressed: return false
	if global_position.distance_to(player.global_position) > (definition.aggro_radius if radius < 0 else radius): return false
	return _target_path_clear()

func _target_path_clear() -> bool:
	if not is_instance_valid(player): return false
	var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -20), player.global_position + Vector2(0, -18), 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _forget_player_target() -> void:
	hit_aggro.forget()
	player=null
	attack_hitbox.deactivate()
	motor.stop_horizontal()
	if health.current_health>0.0 and state_machine.get_state_id() in [&"chase",&"telegraph",&"attack",&"recover"]: state_machine.transition_to(&"patrol")

func _has_floor_ahead(direction: float) -> bool:
	var start: Vector2 = global_position + Vector2(direction * (definition.body_size.x * 0.5 + 8), -10)
	return not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(start, start + Vector2(0, 50), 1)).is_empty()

func _choose_target() -> void:
	var best: float = INF
	for candidate: Node in get_tree().get_nodes_in_group(&"enemies") + get_tree().get_nodes_in_group(&"players"):
		if candidate == self or candidate.health.current_health <= 0: continue
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < best:
			best = distance
			player = candidate as CharacterBody2D

func apply_pull(value: Vector2) -> void:
	motor.apply_pull(value)

func _exit_tree() -> void:
	hit_aggro.release()
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null: audio.stop_owner(self)

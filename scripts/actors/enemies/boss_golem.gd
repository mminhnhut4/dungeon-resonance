class_name BossGolem
extends CharacterBody2D

signal phase_two_started
signal defeated
var player: Player
var feedback: CombatFeedback
var health: HealthComponent
var statuses: StatusController
var hurtbox: Hurtbox
var attack_hitbox: Hitbox
@onready var motor: KnockbackMotor = $Motor
@onready var fsm: ActorStateMachine = $StateMachine
var phase: int = 1
var stagger: float = 0.0
var stagger_resistance: float = 0.0
var stagger_roots: Dictionary[int, bool] = {}
var state_time: float = 0.0
var desired_speed: float = 0.0
var facing: float = -1.0
var attack_counter: int = 0
var emitted_orbs: int = 0
var launched: bool = false
var attack_started: bool = false
var phase_two_count: int = 0
var shockwave_count: int = 0
var ai_enabled: bool = true
var flash: float = 0.0
var enraged: bool = false
var attack_rate_multiplier: float = 1.0
var condition_speed_multiplier: float = 1.0
var hit_aggro: EnemyHitAggro=EnemyHitAggro.new()


func _ready() -> void:
	var rig: Dictionary = ActorCombatRig.build(self, 500.0, Vector2(76, 100), Vector2(0, -50), 2)
	health = rig.health
	hit_aggro.bind(self,player)
	statuses = rig.statuses
	hurtbox = rig.hurtbox
	statuses.accepts_stun = false
	attack_hitbox = ActorCombatRig.hitbox(self, 8)
	attack_hitbox.contact_detected.connect(_hit_player)
	hurtbox.hit_resolved.connect(_on_hit)
	health.died.connect(_die)
	health.health_changed.connect(_check_phase)
	fsm.initialize(self)
	hit_aggro.target_lost.connect(_forget_player_target)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not ai_enabled or (is_instance_valid(feedback) and feedback.is_frozen()):
		return
	if hit_aggro.advance(delta): _forget_player_target()
	if hit_aggro.active(): player=hit_aggro.target()
	if is_instance_valid(player) and player.health.current_health<=0.0: _forget_player_target()
	if is_instance_valid(feedback):
		statuses.combat_feedback = feedback
	flash = maxf(0.0, flash - delta)
	stagger_resistance = maxf(0.0, stagger_resistance - delta)
	state_time += delta * (attack_rate_multiplier * statuses.attack_speed_multiplier if fsm.get_state_id() in [&"sweep", &"orbs", &"stomp"] else 1.0)
	desired_speed = 0.0
	fsm.physics_update(delta)
	if health.current_health > 0.0:
		motor.step(delta, INF, desired_speed * condition_speed_multiplier * statuses.movement_multiplier)
	attack_hitbox.sample_contacts()
	queue_redraw()


func _check_phase(current: float, _maximum: float) -> void:
	if current > 0.0 and current < 250.0 and phase == 1:
		phase = 2
		phase_two_count += 1
		fsm.transition_to(&"idle")
		phase_two_started.emit()


func movement_speed() -> float:
	return 80.0 * (1.3 if phase == 2 else 1.0)


func wait_seconds() -> float:
	return 0.55 if phase == 2 else 0.85


func enter_state(id: StringName) -> void:
	state_time = 0.0
	attack_started = false
	launched = false
	emitted_orbs = 0
	if is_instance_valid(player):
		facing = signf(player.global_position.x - global_position.x)
		if is_zero_approx(facing):
			facing = -1.0
	if id == &"dead":
		attack_hitbox.deactivate()
		hurtbox.set_invulnerable(true)
		statuses.clear()


func tick_state(id: StringName, _delta: float) -> void:
	match id:
		&"idle":
			if not is_instance_valid(player) or player.health.current_health <= 0.0:
				return
			if absf(player.global_position.x - global_position.x) > 130.0:
				desired_speed = facing * movement_speed()
			if state_time >= wait_seconds() and _target_path_clear():
				var next: StringName = &"sweep" if attack_counter % 2 == 0 else &"orbs"
				if phase == 2 and attack_counter % 3 == 2:
					next = &"stomp"
				attack_counter += 1
				fsm.transition_to(next)
		&"sweep":
			if not attack_started and state_time >= 0.5:
				attack_started = true
				var shape := RectangleShape2D.new()
				shape.size = Vector2(320, 26)
				attack_hitbox.activate(_attack(20.0), shape, Vector2(facing * 130, -13))
			if state_time >= 0.66:
				attack_hitbox.deactivate()
			if state_time >= 1.1:
				fsm.transition_to(&"idle")
		&"orbs":
			while emitted_orbs < 3 and state_time >= 0.55 + emitted_orbs * 0.15:
				_spawn_hazard(&"orb", Vector2(facing, 0))
				emitted_orbs += 1
			if state_time >= 1.3:
				fsm.transition_to(&"idle")
		&"stomp":
			if not launched and state_time >= 0.5:
				launched = true
				motor.launch_vertical(720.0)
			if launched and state_time >= 0.82:
				motor.plunge()
			if launched and state_time > 0.85 and is_on_floor():
				_spawn_hazard(&"wave", Vector2.LEFT)
				_spawn_hazard(&"wave", Vector2.RIGHT)
				shockwave_count += 2
				fsm.transition_to(&"recover")
		&"recover":
			if state_time >= 0.45:
				fsm.transition_to(&"idle")
		&"staggered":
			if state_time >= 1.0:
				fsm.transition_to(&"idle")
		&"dead":
			if state_time >= 0.6:
				queue_free()


func _attack(damage: float) -> AttackSnapshot:
	var attack := AttackSnapshot.new()
	attack.source_id = get_instance_id()
	attack.source_team_id = 2
	attack.attack_id = CombatIds.next_id()
	attack.root_event_id = attack.attack_id
	attack.base_damage = damage
	attack.attack_direction = Vector2(facing, 0)
	return attack


func _hit_player(target: Hurtbox, attack: AttackSnapshot) -> void:
	var event := DamageEvent.new()
	event.source_id = attack.source_id
	event.source_team_id = 0 if enraged else 2
	event.target_id = target.get_actor_id()
	event.attack_id = attack.attack_id
	event.root_event_id = attack.root_event_id
	event.hit_window_id = 1
	event.base_damage = attack.base_damage
	event.heavy_hit = true
	event.hit_reaction = &"knockback"
	event.knockback = attack.attack_direction * 280.0
	event.attack_direction = attack.attack_direction
	target.take_damage(event)


func _spawn_hazard(kind: StringName, direction: Vector2) -> void:
	if not is_instance_valid(player) or get_tree().get_nodes_in_group(&"enemy_hazards").size() >= 24:
		return
	var hazard := EnemyHazard.new()
	hazard.kind = kind
	hazard.direction = direction
	hazard.player = player
	hazard.feedback = feedback
	hazard.source_id = get_instance_id()
	# Only Golem's slam waves launch the Player; other users of EnemyHazard keep
	# their existing behavior instead of inheriting reactions from the wave kind.
	hazard.hit_reaction = &"thrown" if kind == &"wave" else &"flinch"
	hazard.reaction_impulse = Vector2(direction.x * 340.0, -440.0) if kind == &"wave" else Vector2.ZERO
	hazard.position = global_position + Vector2(direction.x * 46, -65 if kind == &"orb" else -13)
	get_parent().add_child(hazard)


func _on_hit(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked:
		return
	if hit_aggro.record(event,result): player=hit_aggro.target()
	flash = 0.12
	if is_instance_valid(feedback):
		feedback.on_hit_confirmed(event, result)
	if health.current_health <= 0.0:
		return
	if event.source_kind != DamageEvent.SourceKind.DOT and stagger_resistance <= 0.0 and event.stagger_force > 0.0 and not stagger_roots.has(event.root_event_id):
		if stagger_roots.size() >= 64:
			stagger_roots.erase(stagger_roots.keys()[0])
		stagger_roots[event.root_event_id] = true
		stagger = minf(100.0, stagger + event.stagger_force)
		if stagger >= 100.0:
			stagger = 0.0
			stagger_resistance = 4.0
			fsm.transition_to(&"staggered")
	var text := preload("res://scenes/effects/floating_combat_text.tscn").instantiate() as FloatingCombatText
	get_parent().add_child(text)
	text.global_position = global_position + Vector2(0, -120)
	text.setup(result.actual_damage, event.attack_direction, feedback, event.critical)


func apply_pull(_pull_velocity: Vector2) -> void:
	pass # Boss remains anchored; elemental hits contribute to its stagger meter.


func _die() -> void:
	hit_aggro.forget()
	player=null
	fsm.transition_to(&"dead")
	defeated.emit()

func _target_path_clear() -> bool:
	if not is_instance_valid(player): return false
	var ray:=PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-50),player.global_position+Vector2(0,-18),1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _forget_player_target() -> void:
	hit_aggro.forget()
	player=null
	attack_hitbox.deactivate()
	motor.stop_horizontal()
	if health.current_health>0.0 and fsm.get_state_id()!=&"dead": fsm.transition_to(&"idle")

func _exit_tree() -> void:
	hit_aggro.release()


func _draw() -> void:
	var id: StringName = fsm.get_state_id() if fsm != null else &"idle"
	var color := Color.WHITE if flash > 0.0 else Color(0.5, 0.46, 0.36) if phase == 1 else Color(0.68, 0.35, 0.25)
	if id == &"dead":
		color.a = maxf(0.0, 1.0 - state_time / 0.6)
	draw_rect(Rect2(-38, -100, 76, 100), color)
	draw_rect(Rect2(-23, -78, 12, 8), Color(1.0, 0.75, 0.2))
	draw_rect(Rect2(11, -78, 12, 8), Color(1.0, 0.75, 0.2))
	if id == &"sweep":
		draw_rect(Rect2(-30 if facing > 0.0 else -290, -26, 320, 26), Color(1.0, 0.35, 0.12, 0.75 if attack_hitbox.active else 0.25))
	elif id == &"stomp":
		draw_circle(Vector2(0, -45), 60, Color(1.0, 0.45, 0.1, 0.22))

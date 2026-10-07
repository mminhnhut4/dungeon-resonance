extends "res://tests/survival_test_base.gd"
## Explicit source-authored hurt through real damage, input, FSM and world physics.

var reaction: HitReactionComponent


func _initialize() -> void:
	suite = "hit_reaction"
	use_neutral_equipment = false
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.energy.enabled = true
	player.energy.regeneration = 0.0
	reaction = player.hit_reaction
	var body: CollisionShape2D = player.get_node("BodyCollision") as CollisionShape2D
	var body_shape: Shape2D = body.shape
	var body_transform: Transform2D = body.transform
	var hurt_shape: Shape2D = player.hurtbox.get_node("CollisionShape2D").shape
	var socket_transform: Transform2D = player.get_node("Combat/WeaponSocket").transform
	_check(reaction != null and player.action_state_machine.current_state is ActorState, "Product Player owns one reaction component and the existing action FSM")
	_check(player.health.maximum_health == 115.0 and player.hurtbox.damage_resolver.armor_rating == 11.0, "New reaction fixture uses the real starter armor and 115 HP")
	await _test_validation()
	await _test_flinch_knockback_kneel()
	await _test_throw_and_auto_get_up()
	await _test_dash_recovery()
	await _test_interrupt_and_modal()
	await _test_super_armor()
	await _test_frozen_and_lifecycle()
	await _test_boss_emitters()
	_check(body.shape == body_shape and body.transform == body_transform and player.hurtbox.get_node("CollisionShape2D").shape == hurt_shape and player.get_node("Combat/WeaponSocket").transform == socket_transform, "Every reaction preserves body/hurtbox resources and gameplay socket transforms")
	await _test_teardown()


func _prepare(position_world: Vector2 = Vector2(780, 640)) -> void:
	for action: StringName in [&"move_left", &"move_right", &"attack", &"spell_cast", &"dash", &"jump", &"switch_weapon"]:
		Input.action_release(action)
	if level.gear.modal.is_open:
		level.gear.modal.close()
	player.set_physics_process(true)
	player.reset_movement_at(position_world)
	player.controls_enabled = true
	level.combat_feedback.reset_feedback()
	await _step(3)


func _hit(kind: StringName, impulse: Vector2 = Vector2.ZERO, amount: float = 3.0) -> DamageEvent:
	var event: DamageEvent = _damage(player.hurtbox, amount)
	event.hit_reaction = kind
	event.knockback = impulse
	player.hurtbox.take_damage(event)
	return event


func _tap_dash() -> void:
	Input.action_press(&"dash")
	await _step(1)
	Input.action_release(&"dash")


func _test_validation() -> void:
	await _prepare()
	var legacy: DamageEvent = _damage(player.hurtbox, 3.0, true)
	player.hurtbox.take_damage(legacy)
	_check(not reaction.is_active and player.action_state_machine.get_state_id() == &"ready", "Legacy heavy_hit alone never infers a knockdown or new input lock")
	await _prepare()
	var blocked: DamageEvent = _damage(player.hurtbox, 3.0)
	blocked.hit_reaction = &"thrown"
	player.hurtbox.set_invulnerable(true)
	_check(player.hurtbox.take_damage(blocked).blocked and not reaction.is_active, "Invulnerable hit never launches or starts a reaction")
	player.hurtbox.set_invulnerable(false)
	blocked.source_team_id = 1
	_check(player.hurtbox.take_damage(blocked).blocked and not reaction.is_active, "Friendly hit never starts a reaction")
	await _prepare()
	var event: DamageEvent = _hit(&"flinch")
	reaction.clear()
	player.hurtbox.set_invulnerable(false)
	_check(player.hurtbox.take_damage(event).blocked and not reaction.is_active, "Duplicate validated attack cannot restart the hurt clock")
	await _prepare()
	event = _damage(player.hurtbox, 3.0)
	event.source_kind = DamageEvent.SourceKind.DOT
	event.hit_reaction = &"thrown"
	event.ignore_damage_grace = true
	var health: float = player.health.current_health
	player.hurtbox.take_internal_damage(event)
	_check(player.health.current_health < health and not reaction.is_active, "DOT still damages through the existing pipeline without a knockdown loop")
	_hit(&"unknown_reaction")
	_check(not reaction.is_active, "Unknown reaction names retain legacy behavior without fallback")
	await _prepare()
	_hit(&"thrown", Vector2.RIGHT * 300.0, 999.0)
	_check(player.action_state_machine.get_state_id() == &"dead" and not reaction.is_active, "Lethal explicit hit enters Dead and never reactivates Hurt")


func _test_flinch_knockback_kneel() -> void:
	await _prepare()
	_hit(&"flinch")
	_check(reaction.is_active and reaction.pose_id == &"flinch" and not reaction.blocks_controls() and player.action_state_machine.get_state_id() == &"ready", "Light flinch has its own finite visual pose without a gameplay movement lock")
	Input.action_press(&"move_right")
	await _time(0.07)
	_check(player.velocity.x > 0.0 and reaction.pose_time > 0.0, "Flinch preserves the responsive run motor")
	Input.action_release(&"move_right")
	await _time(0.15)
	_check(not reaction.is_active, "Light flinch expires without a recovery timer node")
	await _prepare()
	var origin: Vector2 = player.global_position
	_hit(&"knockback", Vector2(280, 0))
	_check(reaction.pose_id == &"knockback" and player.action_state_machine.get_state_id() == &"hurt", "Explicit knockback enters the real Hurt state")
	Input.action_press(&"move_left")
	await _time(0.03)
	_check(player.global_position.x > origin.x and player.velocity.x > 0.0, "Committed knockback direction wins against immediate opposite movement input")
	Input.action_release(&"move_left")
	await _time(0.28)
	_check(not reaction.is_active and player.action_state_machine.get_state_id() == &"ready", "Knockback settles and returns to Ready automatically")
	await _prepare()
	origin = player.global_position
	_hit(&"kneel")
	Input.action_press(&"move_right")
	await _time(0.15)
	_check(reaction.pose_id == &"kneel" and player.global_position.distance_to(origin) < 0.2, "Grounded kneel has a distinct pose and short stationary recovery")
	Input.action_release(&"move_right")
	await _time(0.22)
	_check(not reaction.is_active and player.action_state_machine.get_state_id() == &"ready", "Kneel releases its action lock on the finite prototype duration")


func _test_throw_and_auto_get_up() -> void:
	await _prepare()
	var origin: Vector2 = player.global_position
	_hit(&"thrown", Vector2(340, -440))
	_check(player.velocity.y == -440.0 and reaction.pose_id == &"thrown", "Thrown hit commits a single vertical launch through the motor")
	await _time(0.08)
	_check(player.global_position.y < origin.y - 20.0 and player.velocity.y < -280.0 and not player.motor.is_grounded(), "World physics produces an actual arc and releasing Jump cannot cut it short")
	var reached_get_up: bool = false
	for frame: int in 160:
		await _step(1)
		if reaction.pose_id == &"get_up":
			reached_get_up = true
			break
		if not reaction.is_active:
			break
	_check(reached_get_up and player.motor.is_grounded(), "Landing changes the thrown pose to quick get-up after a brief down phase")
	_check(player.hurtbox.invulnerable and player.damage_grace_remaining >= HitReactionComponent.GET_UP_SECONDS, "Get-up starts a short explicit protection window")
	var health: float = player.health.current_health
	_check(player.hurtbox.take_damage(_damage(player.hurtbox, 3.0)).blocked and player.health.current_health == health, "Get-up protection rejects a follow-up contact hit")
	await _time(0.28)
	_check(not reaction.is_active and player.action_state_machine.get_state_id() == &"ready" and player.hurtbox.invulnerable, "Automatic get-up restores controls with brief remaining protection")
	await _time(0.22)
	_check(not player.hurtbox.invulnerable and player.damage_grace_remaining == 0.0, "Recovery protection expires and cannot create permanent immunity")
	await _prepare(Vector2(1230, 640))
	_hit(&"thrown", Vector2(700, -440))
	await _time(1.1)
	_check(player.global_position.x <= 1240.1 and player.motor.is_grounded() and not reaction.is_active, "Thrown motion respects the room wall and floor instead of teleporting through them")
	await _prepare(Vector2(780, 200))
	_hit(&"kneel")
	_check(reaction.pose_id == &"knockback", "Airborne kneel request resolves to a physically valid knockback pose")
	await _prepare()
	_hit(&"thrown")
	player.set_physics_process(false)
	reaction.physics_tick(HitReactionComponent.MAX_AIR_SECONDS + 0.01)
	reaction.physics_tick(HitReactionComponent.DOWN_SECONDS)
	reaction.physics_tick(HitReactionComponent.GET_UP_SECONDS)
	_check(not reaction.is_active, "A bounded airborne fallback cannot leave Hurt locked forever without a floor")
	player.set_physics_process(true)


func _test_dash_recovery() -> void:
	await _prepare()
	_hit(&"kneel")
	await _tap_dash()
	_check(reaction.is_active and not player.motor.is_dashing and player.energy.current == 100.0, "Dash before the minimum hurt lock neither recovers nor spends energy")
	await _time(0.13)
	await _tap_dash()
	_check(not reaction.is_active and player.action_state_machine.get_state_id() == &"dash" and player.energy.current == 75.0, "Eligible recovery Dash pays the existing 25 energy exactly once")
	_check(player.motor.dash_cooldown_remaining > 0.5 and player.hurtbox.invulnerable, "Recovery Dash uses the existing cooldown and grants short protection")
	await _time(0.19)
	await _tap_dash()
	_check(not player.motor.is_dashing and player.energy.current == 75.0, "Existing Dash cooldown rejects a second recovery dash")
	await _prepare()
	player.energy.current = 20.0
	_hit(&"kneel")
	await _time(0.14)
	await _tap_dash()
	_check(reaction.is_active and not player.motor.is_dashing and player.energy.current == 20.0, "Insufficient energy cannot cancel Hurt or gain a free Dash")
	await _prepare()
	player.motor.dash_cooldown_remaining = 0.7
	_hit(&"kneel")
	await _time(0.14)
	await _tap_dash()
	_check(reaction.is_active and player.energy.current == 100.0, "Recovery honors an already committed Dash cooldown")
	await _prepare()
	_hit(&"thrown", Vector2(320, -440))
	await _time(0.14)
	player.motor.air_dash_blocked = true
	await _tap_dash()
	_check(not player.motor.is_grounded() and reaction.is_active and player.energy.current == 100.0, "Crippled-leg Air Dash restriction also applies to thrown recovery")
	player.motor.air_dash_blocked = false
	await _tap_dash()
	_check(player.motor.is_dashing and not reaction.is_active and player.energy.current == 75.0, "Valid airborne recovery consumes the real air-dash charge")
	_check(not player.motor.air_dash_available, "Recovery cannot create an extra air-dash charge")


func _test_interrupt_and_modal() -> void:
	await _prepare()
	Input.action_press(&"attack")
	await _step(1)
	Input.action_release(&"attack")
	_check(player.equipped_weapon.is_attacking(), "Interrupt fixture has a live attack timeline")
	_hit(&"knockback")
	_check(player.action_state_machine.get_state_id() == &"hurt" and not player.equipped_weapon.is_attacking() and not player.equipped_weapon.hitbox.active, "Hurt exits Attack once and immediately closes its hitbox")
	await _time(0.3)
	_check(not player.equipped_weapon.hitbox.active, "Interrupted wind-up never activates a late phantom hitbox")
	await _prepare()
	Input.action_press(&"spell_cast")
	await _step(1)
	Input.action_release(&"spell_cast")
	var cast: PlayerCastState = player.action_state_machine.current_state as PlayerCastState
	_check(cast != null and cast.payload != null and player.energy.current == 70.0, "Cast fixture commits its ordinary wind-up and 30 energy")
	var cooldown: float = player.resonance_controller.cooldown_remaining()
	var entities: int = get_nodes_in_group(&"spell_entities").size()
	_hit(&"kneel")
	_check(cast.payload == null and player.action_state_machine.get_state_id() == &"hurt" and player.energy.current == 70.0, "Hurt interrupts committed cast without refunding energy")
	await _time(0.15)
	_check(get_nodes_in_group(&"spell_entities").size() == entities and player.resonance_controller.cooldown_remaining() > 0.0 and player.resonance_controller.cooldown_remaining() < cooldown, "Cancelled cast cannot launch and its committed cooldown keeps advancing")
	await _prepare()
	_hit(&"kneel")
	var definition: WeaponDefinition = player.equipped_weapon.definition
	player.switch_weapon()
	_check(player.equipped_weapon.definition == definition and reaction.is_active and player.action_state_machine.get_state_id() == &"hurt", "Direct Q weapon switching cannot escape an active hurt lock")
	var hurt_clock: float = reaction.pose_time
	var before_energy: float = player.energy.current
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F5
	key.pressed = true
	Input.parse_input_event(key)
	await _step(1)
	var released := InputEventKey.new()
	released.physical_keycode = KEY_F5
	released.pressed = false
	Input.parse_input_event(released)
	_check(player.equipped_weapon.definition.id == ContentSession.WEAPON_IDS[level.content.weapon_index], "Actual F5 debug input still switches the authored weapon moveset")
	_check(player.action_state_machine.get_state_id() == &"hurt" and reaction.is_active and reaction.pose_time >= hurt_clock and reaction.pose_time <= hurt_clock + 2.0 / Engine.physics_ticks_per_second and player.energy.current == before_energy, "F5 cannot erase Hurt or replace a paid recovery Dash with free weapon switching")
	level.gear.modal.open()
	_check(level.gear.modal.is_open and not player.controls_enabled and player.action_state_machine.get_state_id() == &"hurt" and reaction.is_active, "Opening inventory suspends controls without deleting an active reaction")
	var original_uid: int = level.gear.inventory.equipped_weapon_uid
	var alternative_uid: int = 0
	for item: GearItem in level.gear.inventory.items.values():
		if item.kind == &"weapon" and item.uid != original_uid:
			alternative_uid = item.uid
			break
	var clock: float = reaction.pose_time
	_check(alternative_uid != 0 and level.gear.inventory.equip_equipment(alternative_uid), "Hurt inventory fixture performs a real owned weapon swap")
	_check(reaction.is_active and reaction.pose_time == clock and player.action_state_machine.get_state_id() == &"hurt", "Click-to-equip sync cannot clear Hurt through a Ready transition")
	_check(level.gear.inventory.unequip_equipment(EquipmentData.SlotType.WEAPON) and player.equipped_weapon.definition.id == &"unarmed" and reaction.is_active and player.action_state_machine.get_state_id() == &"hurt", "Unequipping to fists updates gear without escaping the reaction")
	_check(level.gear.inventory.equip_equipment(original_uid) and reaction.is_active and reaction.pose_time == clock, "Restoring the original weapon preserves the same reaction clock and owned UID")
	level.gear.modal.close()
	await _step(3)
	_check(reaction.is_active and player.action_state_machine.get_state_id() == &"hurt", "Closing inventory preserves the reaction until its own finite clock ends")


func _test_super_armor() -> void:
	await _prepare()
	var original: WeaponDefinition = player.equipped_weapon.definition
	var greatsword: WeaponDefinition = load("res://data/weapons/demon_greatsword.tres") as WeaponDefinition
	player.equipped_weapon.equip(greatsword)
	Input.action_press(&"attack")
	await _step(1)
	Input.action_release(&"attack")
	await _step(1)
	Input.action_press(&"attack")
	await _step(1)
	Input.action_release(&"attack")
	var reached_finisher: bool = false
	for frame: int in 140:
		await _step(1)
		if player.equipped_weapon.combo_index == 1 and player.equipped_weapon.phase == Weapon.Phase.WINDUP:
			reached_finisher = true
			break
	_check(reached_finisher and player.equipped_weapon._current_step.super_armor, "Real Greatsword combo reaches its authored super-armor finisher")
	_hit(&"thrown")
	_check(not reaction.is_active and player.action_state_machine.get_state_id() == &"attack", "Non-heavy explicit interruption respects existing finisher super armor")
	player.hurtbox.set_invulnerable(false)
	var event: DamageEvent = _damage(player.hurtbox, 3.0, true)
	event.hit_reaction = &"knockback"
	player.hurtbox.take_damage(event)
	_check(reaction.is_active and player.action_state_machine.get_state_id() == &"hurt" and not player.equipped_weapon.hitbox.active, "Source-authored heavy interruption can break super armor without inferring other heavy hits")
	player.reset_movement_at(Vector2(780, 640))
	player.equipped_weapon.equip(original)


func _test_frozen_and_lifecycle() -> void:
	await _prepare()
	_hit(&"thrown")
	player.set_physics_process(false)
	var position_world: Vector2 = player.global_position
	var velocity: Vector2 = player.velocity
	var clock: float = reaction.elapsed
	level.combat_feedback._frozen_this_tick = true
	player._pending_dash = true
	player._physics_process(0.25)
	_check(reaction.elapsed == clock and player.global_position == position_world and player.velocity == velocity, "Hit-stop freezes reaction clock and actual body motion together")
	_check(player._pending_dash, "Dash input sampled during hit-stop stays buffered until unfreeze")
	level.combat_feedback.reset_feedback()
	player._pending_dash = false
	player._physics_process(0.13)
	player._pending_dash = true
	player._physics_process(1.0 / Engine.physics_ticks_per_second)
	_check(player.motor.is_dashing and player.energy.current == 75.0 and not player._pending_dash, "Buffered recovery Dash executes once on an eligible unfrozen tick")
	player.set_physics_process(true)
	await _prepare()
	_hit(&"thrown")
	player.relocate(Vector2(900, 640))
	_check(not reaction.is_active and player.action_state_machine.get_state_id() == &"ready" and player.velocity == Vector2.ZERO, "Room relocation clears reaction phases and residual launch velocity")
	_hit(&"kneel")
	player.reset_movement_at(Vector2(780, 640))
	_check(not reaction.is_active and player.damage_grace_remaining == 0.0 and not player.hurtbox.invulnerable, "Retry reset clears reaction and protection without leaking a prior run")
	await _step(3)
	_hit(&"thrown")
	player.health.apply_damage(999.0)
	_check(not reaction.is_active and player.action_state_machine.get_state_id() == &"dead", "Death during flight has priority over auto get-up")
	await _time(0.6)
	_check(player.action_state_machine.get_state_id() == &"dead", "Expired hurt timers cannot resurrect a dead Player")


func _test_boss_emitters() -> void:
	await _prepare()
	var boss: BossGolem = preload("res://scenes/enemies/boss_golem.tscn").instantiate() as BossGolem
	boss.player = player
	boss.feedback = level.combat_feedback
	boss.ai_enabled = false
	level.add_child(boss)
	boss.global_position = Vector2(870, 640)
	var delivered: Array[DamageEvent] = []
	var observer: Callable = func(event: DamageEvent, _result: DamageResult) -> void: delivered.append(event)
	player.hurtbox.hit_resolved.connect(observer)
	boss._hit_player(player.hurtbox, boss._attack(20.0))
	_check(delivered.size() == 1 and delivered[0].hit_reaction == &"knockback" and delivered[0].heavy_hit and reaction.pose_id == &"knockback", "Actual Golem sweep emitter authors explicit knockback independently of heavy_hit")
	await _prepare()
	delivered.clear()
	boss._spawn_hazard(&"wave", Vector2.LEFT)
	var waves: Array[Node] = get_nodes_in_group(&"enemy_hazards")
	var wave: EnemyHazard = waves[0] as EnemyHazard
	_check(wave.hit_reaction == &"thrown" and wave.reaction_impulse.y < 0.0, "Golem's actual slam spawner commits a launched reaction onto its wave")
	wave._hit(player.hurtbox, wave.attack)
	_check(delivered.size() == 1 and delivered[0].hit_reaction == &"thrown" and reaction.pose_id == &"thrown" and player.velocity.y < 0.0, "Actual shockwave damage pipeline starts the thrown arc")
	await _step(2)
	await _prepare()
	delivered.clear()
	var ordinary := EnemyHazard.new()
	ordinary.kind = &"wave"
	ordinary.player = player
	ordinary.source_id = boss.get_instance_id()
	level.add_child(ordinary)
	ordinary._hit(player.hurtbox, ordinary.attack)
	_check(delivered.size() == 1 and delivered[0].hit_reaction == &"" and not reaction.is_active, "Non-Golem hazard users preserve legacy behavior even when their kind is wave")
	player.hurtbox.hit_resolved.disconnect(observer)
	delivered.clear()
	boss.queue_free()
	await _step(3)


func _test_teardown() -> void:
	await _prepare()
	for iteration: int in 30:
		_hit(&"thrown")
		player.reset_movement_at(Vector2(780, 640))
	_check(reaction.get_child_count() == 0 and player.find_children("HitReaction", "", false, false).size() == 1, "Repeated reactions/reset reuse one component and allocate no timer/particle owners")
	_hit(&"thrown")
	var reaction_id: int = reaction.get_instance_id()
	var motor_id: int = player.motor.get_instance_id()
	level.queue_free()
	await _step(4)
	_check(not is_instance_id_valid(reaction_id) and not is_instance_id_valid(motor_id), "Room teardown releases an active reaction component and its motor with Player")

extends "res://tests/survival_test_base.gd"
## Accepted ordinary hits must present at contact, without a fixture render seek.

func _initialize() -> void:
	suite = "boss_hitstop_feedback"
	super._initialize()

func test_system() -> void:
	session.set_enabled(false)
	player.controls_enabled = false
	player.hurtbox.set_invulnerable(true)
	for enemy: SlimeEnemy in level.enemies:
		enemy.contact_damage_enabled = false
	var feedback: CombatFeedback = level.combat_feedback
	feedback.enable_global_hitstop(true)
	feedback.hit_stop_seconds = 0.05
	var boss: BossGolem = preload("res://scenes/enemies/boss_golem.tscn").instantiate()
	boss.position = Vector2(1150, 640)
	boss.feedback = feedback
	boss.player = null
	level.add_child(boss)
	await _step(3)
	var skin: BossGolemSkin = boss.get_node("GolemStoneSkin") as BossGolemSkin
	var material: ShaderMaterial = skin.sprite.material as ShaderMaterial
	var body: CollisionShape2D = boss.get_node("Body") as CollisionShape2D
	var body_shape: Shape2D = body.shape
	var body_transform: Transform2D = body.transform
	var hurt_shape: Shape2D = (boss.hurtbox.get_child(0) as CollisionShape2D).shape
	var hurt_transform: Transform2D = (boss.hurtbox.get_child(0) as CollisionShape2D).transform
	boss.fsm.transition_to(&"sweep")
	await _time(0.28)
	_check(skin.art_rig.pose == &"sweep_tell" and not boss.attack_hitbox.active, "Real sweep is in tell before the ordinary incoming hit")
	var state_before: float = boss.state_time
	var skin_clock_before: float = skin.clock
	var hit: DamageEvent = _ordinary_hit(boss.hurtbox, 2.0)
	var result: DamageResult = boss.hurtbox.take_damage(hit)
	# Do not call refresh_skin here: this is the runtime contact subscription gate.
	_check(result.actual_damage == 2.0 and boss.health.current_health == 498.0 and boss.phase == 1 and boss.fsm.get_state_id() == &"sweep", "Ordinary contact changes only health/flash, without a phase or FSM transition")
	_check(feedback.is_frozen() and is_equal_approx(Engine.time_scale, 0.05) and boss.flash == 0.12, "Real accepted melee starts existing boss hitstop and hurt clock")
	var peak_uniform: float = float(material.get_shader_parameter("flash"))
	_check(peak_uniform > 0.0 and peak_uniform <= 0.12, "Contact immediately publishes bounded hurt flash before any later physics observer")
	_check(skin.core_light.energy == 0.0, "Contact immediately suppresses the peak core illumination")
	_check(boss.state_time == state_before and skin.clock == skin_clock_before and not boss.attack_hitbox.active, "Publishing contact cannot advance state/visual clocks or open damage")
	var held_flash: float = boss.flash
	var held_pose: Transform2D = skin.art_rig.torso.transform
	await _real_time(0.025)
	_check(feedback.is_frozen() and boss.state_time == state_before and boss.flash == held_flash and skin.clock == skin_clock_before and skin.art_rig.torso.transform == held_pose, "Hitstop holds owner clocks and the contact pose together")
	_check(float(material.get_shader_parameter("flash")) == peak_uniform and skin.core_light.energy == 0.0, "Hurt flash and suppressed core stay stable through hitstop")
	result = boss.hurtbox.take_damage(hit)
	_check(result.blocked and boss.health.current_health == 498.0 and boss.flash == held_flash and float(material.get_shader_parameter("flash")) == peak_uniform, "Duplicate blocked contact cannot restart visual or damage clocks")
	await _real_time(0.15)
	await _step(2)
	_check(not feedback.is_frozen() and is_equal_approx(Engine.time_scale, 1.0) and boss.state_time > state_before and boss.flash < held_flash, "Existing real-time deadline resumes combat and naturally decays hurt")
	await _time(0.16)
	_check(boss.flash == 0.0 and float(material.get_shader_parameter("flash")) == 0.0 and skin.core_light.energy > 0.0 and skin.core_light.energy <= 0.32, "Natural hurt expiry restores the bounded phase-one core")
	_check(body.shape == body_shape and body.transform == body_transform and (boss.hurtbox.get_child(0) as CollisionShape2D).shape == hurt_shape and (boss.hurtbox.get_child(0) as CollisionShape2D).transform == hurt_transform, "Contact presentation preserves Body/Hurtbox shape resources and transforms")
	var dot: DamageEvent = _ordinary_hit(boss.hurtbox, 1.0)
	dot.melee_hit = false
	dot.source_kind = DamageEvent.SourceKind.DOT
	result = boss.hurtbox.take_damage(dot)
	_check(result.actual_damage == 1.0 and not feedback.is_frozen(), "DOT keeps existing damage and does not create melee hitstop")
	await _step(2)
	_check(boss.flash > 0.0 and float(material.get_shader_parameter("flash")) > 0.0, "Existing regular physics still presents DOT hurt without a new feedback policy")
	feedback.reset_feedback()
	skin.bind(boss)
	skin.bind(boss)
	_check(_skin_hit_listeners(boss.hurtbox, skin) == 1, "Repeated binding keeps exactly one ordinary incoming-hit listener")
	skin.bind(null)
	_check(_skin_hit_listeners(boss.hurtbox, skin) == 0 and boss.self_modulate.a == 1.0, "Unbinding removes incoming-hit listener and restores source drawing")
	skin.bind(boss)
	_check(_skin_hit_listeners(boss.hurtbox, skin) == 1, "Rebinding restores one listener without duplicates")
	skin.queue_free()
	await _step(2)
	_check(not is_instance_valid(skin) and boss.self_modulate.a == 1.0, "Skin disposal restores the live owner without leaving a callback")
	boss.queue_free()
	await _step(3)
	_check(not is_instance_valid(boss), "Boss and visual resources release on normal owner teardown")
	feedback.reset_feedback()

func _ordinary_hit(target: Hurtbox, amount: float) -> DamageEvent:
	var event: DamageEvent = super._damage(target, amount)
	event.source_id = level.get_instance_id()
	event.melee_hit = true
	event.stagger_force = 0.0
	return event

func _skin_hit_listeners(hurt: Hurtbox, skin: BossGolemSkin) -> int:
	var count: int = 0
	for connection: Dictionary in hurt.hit_resolved.get_connections():
		var callback: Callable = connection["callable"]
		if callback.get_object() == skin and callback.get_method() == &"_on_boss_hit":
			count += 1
	return count

func _real_time(seconds: float) -> void:
	var deadline: int = Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		await process_frame
		OS.delay_msec(2)
	await process_frame

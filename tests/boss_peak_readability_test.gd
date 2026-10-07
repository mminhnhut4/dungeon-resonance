extends "res://tests/survival_test_base.gd"
## Real Hurtbox events and natural Boss ticks; no fixture writes the hurt clock.
## Headless parameters/geometry are evidence of invariants, not visual acceptance.

const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/boss_golem.tscn")

func _damage(target: Hurtbox, amount: float, heavy: bool = false) -> DamageEvent:
	var event: DamageEvent = super._damage(target,amount,heavy)
	event.source_id=level.get_instance_id() # Live fixture owner; no fabricated ObjectDB slot/Player aggro.
	return event


func _initialize() -> void:
	suite = "boss_peak_readability"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.controls_enabled = false
	var original_invulnerable: bool = player.hurtbox.invulnerable
	player.hurtbox.set_invulnerable(true) # Isolate sweep timing from unrelated Player hurt feedback.
	player.set_physics_process(false)
	player.resonance_controller.set_physics_process(false)
	for enemy: SlimeEnemy in level.enemies:
		enemy.contact_damage_enabled = false
	level.combat_feedback.hit_stop_seconds = 0.0
	await _test_phase(1)
	await _test_phase(2)
	player.hurtbox.set_invulnerable(original_invulnerable)
	player.set_physics_process(true)
	player.resonance_controller.set_physics_process(true)


func _test_phase(expected_phase: int) -> void:
	var boss: BossGolem = BOSS_SCENE.instantiate() as BossGolem
	boss.position = Vector2(900, 640)
	boss.player = null # Suppress idle targeting while preserving real physics/flash.
	boss.feedback = level.combat_feedback
	level.add_child(boss)
	await _step(3)
	var skin: BossGolemSkin = boss.get_node("GolemStoneSkin") as BossGolemSkin
	var material: ShaderMaterial = skin.sprite.material as ShaderMaterial
	var body: CollisionShape2D = boss.get_node("Body") as CollisionShape2D
	var hurt: CollisionShape2D = boss.hurtbox.get_child(0) as CollisionShape2D
	var body_shape: Shape2D = body.shape
	var hurt_shape: Shape2D = hurt.shape
	var body_transform: Transform2D = body.transform
	var hurt_transform: Transform2D = hurt.transform
	var sprite_id: int = skin.sprite.get_instance_id()
	var light_id: int = skin.core_light.get_instance_id()
	if expected_phase == 2:
		var threshold: DamageEvent = _damage(boss.hurtbox, 255.0)
		threshold.stagger_force = 0.0
		var threshold_result: DamageResult = boss.hurtbox.take_damage(threshold)
		_check(threshold_result.actual_damage == 255.0 and boss.phase == 2 and boss.phase_two_count == 1, "A real threshold hit enters phase two once without changing damage")
		await _wait_for_flash_end(boss)
	skin.refresh_skin()
	var health_before: float = boss.health.current_health
	var idle_state_time: float = boss.state_time
	var expected_core_color: Color = BossGolemSkin.JADE if expected_phase == 1 else BossGolemSkin.AMBER
	_check(boss.phase == expected_phase and boss.ai_enabled and boss.is_physics_processing(), "Phase%d fixture retains natural Boss physics and AI clock" % expected_phase)
	_check(material != null and material.shader.resource_path == "res://shaders/hit_flash.gdshader" and not bool(material.get_shader_parameter("active")), "Phase%d keeps the shared shader resource with a private bounded uniform" % expected_phase)
	_check(boss.flash == 0.0 and float(material.get_shader_parameter("flash")) == 0.0 and skin.core_light.energy > 0.0 and skin.core_light.energy <= 0.32, "Phase%d idle core is present within the new energy ceiling" % expected_phase)
	_check(skin.core_light.color == expected_core_color and skin.core_light.position.y < -57.0 and skin.core_light.position.y > -61.0, "Phase%d core retains its authored hue and foot-relative pivot" % expected_phase)
	var hit: DamageEvent = _damage(boss.hurtbox, 5.0)
	hit.stagger_force = 0.0
	var result: DamageResult = boss.hurtbox.take_damage(hit)
	skin.refresh_skin()
	_check(result.actual_damage == 5.0 and boss.health.current_health == health_before - 5.0 and is_equal_approx(boss.flash, 0.12), "Phase%d accepted hurt keeps five damage and the original 0.12-second clock" % expected_phase)
	var peak_uniform: float = float(material.get_shader_parameter("flash"))
	_check(peak_uniform > 0.0 and peak_uniform <= 0.12 and not bool(material.get_shader_parameter("active")), "Phase%d peak renders a bounded blend without the opaque white override" % expected_phase)
	_check(skin.core_light.energy == 0.0 and skin.core_light.color == expected_core_color, "Phase%d hurt peak adds no core illumination and retains its phase hue" % expected_phase)
	var peak_clock: float = boss.flash
	var peak_state_time: float = boss.state_time
	var peak_health: float = boss.health.current_health
	skin.refresh_skin()
	skin.refresh_skin()
	_check(boss.flash == peak_clock and boss.state_time == peak_state_time and boss.health.current_health == peak_health and skin.core_light.energy == 0.0, "Phase%d render refresh leaves damage and both gameplay clocks untouched" % expected_phase)
	await _step(2)
	skin.refresh_skin()
	var decayed: float = boss.flash
	var decayed_uniform: float = float(material.get_shader_parameter("flash"))
	_check(decayed > 0.0 and decayed < peak_clock and decayed_uniform > 0.0 and decayed_uniform < peak_uniform and boss.state_time > peak_state_time, "Phase%d actual physics reduces flash while advancing the state clock" % expected_phase)
	_check(skin.core_light.energy > 0.0 and skin.core_light.energy <= 0.32, "Phase%d core naturally returns after the immediate hurt peak" % expected_phase)
	result = boss.hurtbox.take_damage(hit)
	skin.refresh_skin()
	_check(result.blocked and boss.flash == decayed and boss.health.current_health == peak_health and float(material.get_shader_parameter("flash")) == decayed_uniform, "Phase%d duplicate hurt cannot restart flash or deal damage again" % expected_phase)
	var monotonic: bool = true
	var previous_flash: float = boss.flash
	var late_gate_seen: bool = false
	for frame: int in ceili(0.25 * Engine.physics_ticks_per_second):
		if boss.flash <= 0.0:
			break
		await _step(1)
		skin.refresh_skin()
		monotonic = monotonic and boss.flash <= previous_flash and skin.core_light.energy >= 0.0 and skin.core_light.energy <= 0.32
		if boss.flash > 0.0 and boss.flash <= 0.040001:
			late_gate_seen = late_gate_seen or float(material.get_shader_parameter("flash")) == 0.0
		previous_flash = boss.flash
	_check(monotonic and late_gate_seen and boss.flash == 0.0 and float(material.get_shader_parameter("flash")) == 0.0, "Phase%d flash expires monotonically through the unchanged late-flash gate" % expected_phase)
	_check(skin.core_light.energy > 0.0 and skin.core_light.energy <= 0.32 and boss.state_time > idle_state_time and boss.health.current_health == peak_health, "Phase%d natural expiry restores bounded core without healing or pausing combat" % expected_phase)
	await _test_hit_stop(boss, skin, material, expected_phase)
	await _test_warning_windows(boss, skin, expected_phase)
	_check(body.shape == body_shape and hurt.shape == hurt_shape and body.transform == body_transform and hurt.transform == hurt_transform, "Phase%d peak policy preserves Body and Hurtbox resources/local transforms" % expected_phase)
	var lethal: DamageEvent = _damage(boss.hurtbox, boss.health.current_health + 1.0)
	lethal.stagger_force = 0.0
	var lethal_result: DamageResult = boss.hurtbox.take_damage(lethal)
	skin.refresh_skin()
	_check(lethal_result.killed and boss.fsm.get_state_id() == &"dead" and skin.core_light.energy == 0.0, "Phase%d real lethal hit enters death with no added peak core light" % expected_phase)
	await _time(0.30)
	_check(is_instance_valid(boss) and skin.modulate.a > 0.0 and skin.modulate.a < 0.7 and skin.core_light.energy <= 0.18, "Phase%d original death clock fades sprite and bounded core together" % expected_phase)
	await _time(0.45)
	_check(not is_instance_valid(boss) and not is_instance_id_valid(sprite_id) and not is_instance_id_valid(light_id), "Phase%d original death deadline releases sprite and core owners" % expected_phase)
	level.combat_feedback.reset_feedback()


func _test_hit_stop(boss: BossGolem, skin: BossGolemSkin, material: ShaderMaterial, phase: int) -> void:
	level.combat_feedback.hit_stop_seconds = 0.06
	var hit: DamageEvent = _damage(boss.hurtbox, 1.0)
	hit.stagger_force = 0.0
	boss.hurtbox.take_damage(hit)
	skin.refresh_skin()
	var held_flash: float = boss.flash
	var held_state: float = boss.state_time
	var held_skin: float = skin.clock
	var held_uniform: float = float(material.get_shader_parameter("flash"))
	var held_transform: Transform2D = boss.global_transform
	await _step(2)
	_check(level.combat_feedback.is_frozen() and boss.flash == held_flash and boss.state_time == held_state and skin.clock == held_skin and boss.global_transform == held_transform and float(material.get_shader_parameter("flash")) == held_uniform and skin.core_light.energy == 0.0, "Phase%d real accepted-hit stop holds gameplay, sprite clock, flash and zero peak core" % phase)
	await _wait_for_flash_end(boss)
	_check(not level.combat_feedback.is_frozen() and boss.flash == 0.0 and boss.state_time > held_state and skin.core_light.energy > 0.0 and skin.core_light.energy <= 0.32, "Phase%d actual hit-stop deadline resumes clocks and bounded core" % phase)
	level.combat_feedback.hit_stop_seconds = 0.0


func _test_warning_windows(boss: BossGolem, skin: BossGolemSkin, phase: int) -> void:
	boss.fsm.transition_to(&"sweep")
	await _time(0.24)
	_check(skin._state == &"sweep" and not skin._active and not boss.attack_hitbox.active and not boss.attack_started, "Phase%d sweep retains its pre-active warning" % phase)
	await _time(0.29)
	var shape: Shape2D = boss.attack_hitbox._query_shape
	_check(skin._state == &"sweep" and skin._active and boss.attack_hitbox.active and shape is RectangleShape2D and (shape as RectangleShape2D).size == Vector2(320, 26), "Phase%d natural sweep opens the original 320-by-26 contact window" % phase)
	var local_transform: Transform2D = boss.attack_hitbox.transform
	skin.refresh_skin()
	_check(boss.attack_hitbox._query_shape == shape and boss.attack_hitbox.transform == local_transform and skin._active, "Phase%d bounded core refresh cannot move an active sweep Hitbox" % phase)
	await _time(0.16)
	_check(not boss.attack_hitbox.active and not skin._active, "Phase%d natural sweep still closes at the authored window end" % phase)
	await _time(0.50)
	_check(boss.fsm.get_state_id() == &"idle", "Phase%d original sweep recovery returns to idle" % phase)
	boss.fsm.transition_to(&"stomp")
	await _time(0.24)
	_check(skin._state == &"stomp" and not boss.launched and not boss.attack_hitbox.active, "Phase%d stomp still warns before the original launch clock" % phase)
	await _time(0.30)
	_check(boss.launched and skin._state == &"stomp" and not boss.attack_hitbox.active, "Phase%d natural stomp launch remains on its authored clock" % phase)


func _wait_for_flash_end(boss: BossGolem) -> void:
	for frame: int in ceili(0.35 * Engine.physics_ticks_per_second):
		if boss.flash <= 0.0 and not level.combat_feedback.is_frozen():
			return
		await _step(1)

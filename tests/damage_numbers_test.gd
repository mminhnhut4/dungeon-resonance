extends SceneTree
## Actual actor resolvers feed one optional room-owned number presentation.

var room: Node2D
var feedback: CombatFeedback
var spawner: DamageNumberSpawner
var dummy: TrainingDummy
var slime: SlimeEnemy
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	room = Node2D.new()
	root.add_child(room)
	current_scene = room
	feedback = CombatFeedback.new()
	room.add_child(feedback)
	feedback.hit_stop_seconds = 0.0
	spawner = DamageNumberSpawner.new()
	spawner.position = Vector2(17, 23)
	room.add_child(spawner)
	dummy = preload("res://scenes/training_dummy.tscn").instantiate() as TrainingDummy
	room.add_child(dummy)
	dummy.position = Vector2(300, 300)
	dummy.combat_feedback = feedback
	dummy.set_physics_process(false)
	slime = preload("res://scenes/enemies/slime_enemy.tscn").instantiate() as SlimeEnemy
	slime.ai_enabled = false
	room.add_child(slime)
	slime.position = Vector2(500, 300)
	slime.combat_feedback = feedback
	slime.statuses.combat_feedback = feedback
	await _step(2)
	print("DAMAGE NUMBERS TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	await _test_legacy()
	dummy.damage_number_spawner = spawner
	slime.damage_number_spawner = spawner
	await _test_real_hits()
	await _test_blocked()
	await _test_dot()
	await _test_arc_and_hitstop()
	await _test_budget_and_teardown()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _event(target: Hurtbox, amount: float, critical: bool = false) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = 987654
	event.source_team_id = 1
	event.target_id = target.get_actor_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = amount
	event.critical = critical
	event.attack_direction = Vector2.RIGHT
	return event


func _test_legacy() -> void:
	dummy.hurtbox.take_damage(_event(dummy.hurtbox, 7.0, true))
	var texts: Array[Node] = get_nodes_in_group(&"combat_text")
	_check(texts.size() == 1 and spawner.total_spawned == 0, "Unconfigured dungeon actor retains exactly one legacy number")
	var text: FloatingCombatText = texts[0] as FloatingCombatText
	_check(text.lifetime == 0.65 and text.label.text == "7!" and text.label.get_theme_font_size("font_size") == 29, "Legacy critical retains .65s lifetime, font29 and punctuation")
	_check(text.label.get_theme_color("font_outline_color").r > 0.4 and text.get_parent() == room, "Legacy warm outline and actor-parent ownership stay unchanged")
	await _time(0.7)
	_check(get_nodes_in_group(&"combat_text").is_empty(), "Legacy number expires without the optional spawner")
	dummy.reset_at_home()


func _test_real_hits() -> void:
	var event: DamageEvent = _event(dummy.hurtbox, 12.5)
	var result: DamageResult = dummy.hurtbox.take_damage(event)
	_check(result.actual_damage == 12.5 and spawner.total_spawned == 1 and spawner.active_count() == 1, "A real dummy DamageEvent creates exactly one shared number")
	var text: FloatingCombatText = spawner.get_child(0) as FloatingCombatText
	_check(text.label.text == "12.5" and text.get_parent() == spawner, "Shared number shows resolved fractional damage and belongs to the Hub owner")
	_check(text.global_position == dummy.global_position + Vector2(-22, -130), "A translated spawner keeps the number's world-space position")
	_check(text.lifetime == 0.6 and text.label.get_theme_color("font_color") == Color.WHITE and text.label.get_theme_color("font_outline_color") == Color.BLACK, "Prologue normal number is white with black outline and .6s lifetime")
	_check(get_nodes_in_group(&"combat_text").size() == 1, "Optional branch suppresses the legacy number rather than duplicating it")
	_check(spawner.spawn_damage(event, result, Vector2.ZERO, feedback) == null and spawner.active_count() == 1, "Repeated presentation of the same resolved result cannot duplicate its number")
	await _time(0.7)
	_check(spawner.active_count() == 0, "Shared .6s presentation self-cleans after its finite lifetime")
	result = slime.hurtbox.take_damage(_event(slime.hurtbox, 8.0, true))
	text = spawner.get_child(0) as FloatingCombatText
	_check(result.actual_damage == 8.0 and spawner.active_count() == 1 and get_nodes_in_group(&"combat_text").size() == 1, "Real Slime hit also uses one shared number without a legacy duplicate")
	_check(text.label.text == "8!" and text.label.get_theme_font_size("font_size") == 18 and text.scale.is_equal_approx(Vector2.ONE * 1.4 * 1.4), "Prologue critical is exactly 1.4x normal presentation size")
	var critical_color: Color = text.label.get_theme_color("font_color")
	_check(critical_color.r == 1.0 and critical_color.g > 0.6 and critical_color.b < 0.2 and text.label.get_theme_color("font_outline_color") == Color.BLACK, "Prologue critical uses yellow-orange with the same readable black outline")
	await _time(0.7)
	dummy.health.current_health = 3.0
	result = dummy.hurtbox.take_damage(_event(dummy.hurtbox, 999.0))
	text = spawner.get_child(0) as FloatingCombatText
	_check(result.killed and text.label.text == "3", "Lethal number reports remaining HP lost rather than incoming overkill")
	await _clear()
	dummy.reset_at_home()
	slime.reset_at_home()


func _test_blocked() -> void:
	var before: int = spawner.total_spawned
	dummy.hurtbox.set_invulnerable(true)
	var result: DamageResult = dummy.hurtbox.take_damage(_event(dummy.hurtbox, 4.0))
	_check(result.blocked and spawner.total_spawned == before, "Invulnerable contact creates no number")
	dummy.hurtbox.set_invulnerable(false)
	var friendly: DamageEvent = _event(dummy.hurtbox, 4.0)
	friendly.source_team_id = 2
	result = dummy.hurtbox.take_damage(friendly)
	_check(result.blocked and spawner.total_spawned == before, "Friendly contact creates no number")
	result = dummy.hurtbox.take_damage(_event(dummy.hurtbox, -1.0))
	_check(result.blocked and spawner.total_spawned == before, "Invalid negative damage creates no number")
	var valid: DamageEvent = _event(dummy.hurtbox, 4.0)
	dummy.hurtbox.take_damage(valid)
	before = spawner.total_spawned
	result = dummy.hurtbox.take_damage(valid)
	_check(result.blocked and result.block_reason == &"duplicate" and spawner.total_spawned == before, "Receiver's duplicate attack/window remains invisible")
	await _clear()
	dummy.reset_at_home()


func _test_dot() -> void:
	var event: DamageEvent = _event(slime.hurtbox, 1.0)
	event.burn_damage = 2.0
	event.burn_duration = 0.22
	event.burn_interval = 0.1
	var before: int = spawner.total_spawned
	var impacts: int = feedback.impact_count
	slime.hurtbox.take_damage(event)
	await _time(0.26)
	_check(slime.health.current_health == 55.0 and spawner.total_spawned == before + 3, "One direct hit plus two real burn ticks produce three actual-damage numbers")
	_check(feedback.impact_count == impacts + 1, "DOT numbers add no hit-stop or repeated impact feedback")
	var last: DamageEvent = slime.last_damage_event
	_check(last.source_kind == DamageEvent.SourceKind.DOT and last.root_event_id == event.root_event_id and not last.allow_resonance, "Burn number keeps existing child DOT causality and cannot launch resonance")
	await _clear()
	slime.reset_at_home()


func _test_arc_and_hitstop() -> void:
	dummy.hurtbox.take_damage(_event(dummy.hurtbox, 2.0, true))
	var text: FloatingCombatText = spawner.get_child(0) as FloatingCombatText
	text.set_process(false)
	var start: Vector2 = text.position
	var minimum_y: float = start.y
	for frame: int in 14:
		text._process(0.04)
		minimum_y = minf(minimum_y, text.position.y)
	_check(minimum_y < start.y - 10.0 and text.position.y > minimum_y, "Number travels upward, curves and starts falling before expiry")
	_check(absf(text.rotation) > 0.0 and absf(text.rotation) <= 0.025, "Critical text applies only a tiny bounded shake")
	text.setup(2.0, Vector2.RIGHT, feedback, true, &"prologue")
	feedback.hit_stop_seconds = 0.05
	var freeze_event: DamageEvent = _event(dummy.hurtbox, 1.0)
	var freeze_result := DamageResult.new()
	freeze_result.actual_damage = 1.0
	feedback.on_hit_confirmed(freeze_event, freeze_result)
	var before_position: Vector2 = text.position
	var before_scale: Vector2 = text.scale
	text._process(0.1)
	_check(feedback.is_frozen() and text.position == before_position and text.scale == before_scale and text._elapsed == 0.0, "Hit-stop freezes number position, pop and lifetime together")
	feedback.reset_feedback()
	text._process(0.04)
	_check(text._elapsed == 0.04 and text.position.y < before_position.y, "Number resumes its own clock after hit-stop releases")
	text.setup(2.0, Vector2.LEFT, feedback, false)
	_check(text.lifetime == 0.65 and text.label.get_theme_font_size("font_size") == 18 and text.scale == Vector2(1.4, 1.4), "Opt-in presentation can return to neutral legacy defaults without leaking a profile")
	feedback.hit_stop_seconds = 0.0
	await _clear()


func _test_budget_and_teardown() -> void:
	for frame: int in 48:
		dummy.hurtbox.take_damage(_event(dummy.hurtbox, 0.1))
	_check(spawner.active_count() == DamageNumberSpawner.MAX_ACTIVE, "Same-frame damage burst is capped at 32 live presentations")
	await _step(2)
	_check(get_nodes_in_group(&"combat_text").size() == DamageNumberSpawner.MAX_ACTIVE, "Evicted numbers are freed on the next tree flush")
	await _time(0.7)
	_check(spawner.active_count() == 0 and get_nodes_in_group(&"combat_text").is_empty(), "Spam leaves no expired number nodes retained by the owner")
	var objects_before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_before: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for cycle: int in 3:
		for hit: int in 12:
			dummy.hurtbox.take_damage(_event(dummy.hurtbox, 0.1))
		await _time(0.7)
	_check(int(Performance.get_monitor(Performance.OBJECT_COUNT)) <= objects_before, "Repeated finite bursts retain no extra objects after warm-up")
	_check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= resources_before, "Repeated finite bursts retain no extra resources after warm-up")
	print("STRESS: damage numbers objects=%d->%d resources=%d->%d" % [objects_before, int(Performance.get_monitor(Performance.OBJECT_COUNT)), resources_before, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
	dummy.hurtbox.take_damage(_event(dummy.hurtbox, 1.0))
	var number: FloatingCombatText = spawner.get_child(0) as FloatingCombatText
	var owner_id: int = spawner.get_instance_id()
	var number_id: int = number.get_instance_id()
	room.queue_free()
	await _step(3)
	_check(not is_instance_id_valid(owner_id) and not is_instance_id_valid(number_id) and get_nodes_in_group(&"combat_text").is_empty(), "Room teardown owns and releases active numbers immediately")
	_check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "Number presentation never claims global time or pause")


func _clear() -> void:
	spawner.clear_numbers()
	await _step(2)


func _time(seconds: float) -> void:
	await _step(ceili(seconds * Engine.physics_ticks_per_second))


func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", description])

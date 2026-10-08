extends SceneTree
## Shared fixtures only; each system has an independently runnable suite.

var suite: String = ""
var level: Node2D
var player: Player
var session: SurvivalSession
var profile: SanctuaryProfile
var checks: int = 0
var failures: int = 0
## Legacy system gates keep neutral starter stats; new product-loadout tests opt out.
var use_neutral_equipment: bool = true
## Synthetic hits identify one live non-Player owner across scene replacement.
var _damage_source: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	_damage_source = Node2D.new()
	_damage_source.name = "SyntheticDamageFixtureSource"
	_damage_source.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_damage_source)
	profile = SanctuaryProfile.new()
	profile.save_path = "user://verification/%s_%d.json" % [suite, Engine.physics_ticks_per_second]
	level = preload("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	level.content.qa_tools_enabled = true # This isolated fixture uses explicit debug setup APIs.
	current_scene = level
	player = level.player
	if use_neutral_equipment:
		preload("res://tests/neutral_equipment_fixture.gd").install(level.gear)
	session = level.survival
	session.profile = profile
	session.director.automatic = false
	level.combat_feedback.hit_stop_seconds = 0.0
	for enemy: SlimeEnemy in level.enemies:
		enemy.ai_enabled = false
	player.reset_movement_at(Vector2(780, 640))
	await _step(20)
	print("%s TEST: %d physics ticks/s" % [suite.to_upper(), Engine.physics_ticks_per_second])
	await test_system()
	if is_instance_valid(level):
		level.queue_free()
	_damage_source.queue_free()
	await _step(4)
	_damage_source = null
	_check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "System teardown restores global time and pause")
	_check(get_nodes_in_group(&"phantoms").is_empty() and get_nodes_in_group(&"floor_traps").is_empty(), "System teardown releases incident and trap visuals")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func test_system() -> void:
	pass


func _damage(target: Hurtbox, amount: float, heavy: bool = false) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = _damage_source.get_instance_id()
	event.source_team_id = 2 if target.team_id == 1 else 1
	event.target_id = target.get_actor_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = amount
	event.heavy_hit = heavy
	return event


func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _step(2)
	event.pressed = false
	Input.parse_input_event(event)


func _time(seconds: float) -> void:
	await _step(ceili(seconds * Engine.physics_ticks_per_second))


func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

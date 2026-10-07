extends SceneTree
## Actual room integration: casting, statuses, finite procs, enemy FSM and cleanup.

var level: Node2D
var player: Player
var controller: ResonanceController
var executor: SpellExecutor
var dummy: TrainingDummy
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	level = (load("res://scenes/test_level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	player = level.player
	# This historical gate verifies the original 100HP/15-damage enemy baseline.
	preload("res://tests/neutral_equipment_fixture.gd").install(level.gear)
	level.survival.set_enabled(false) # Existing fixture isolates its milestone.
	player.energy.enabled = false # Baseline movement/combat fixture; gear suite covers costs.
	player.equipped_weapon.definition = load("res://data/weapons/training_sword.tres")
	player.gear_switch_enabled = false
	controller = player.resonance_controller
	executor = level.spell_executor
	dummy = level.dummy_a
	await _step(5)
	print("MILESTONE TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	await _test_hud_and_presets()
	await _test_cast_lifetime()
	await _test_rune_effects()
	await _test_resonance_effects()
	await _test_enemy_fsm()
	await _test_spam_cleanup()
	_release_inputs()
	level.queue_free()
	await _step(3)
	_check(get_nodes_in_group(&"spell_entities").is_empty() and get_nodes_in_group(&"combat_text").is_empty(), "Leaving the room frees spells, status-owned feedback and text")
	_check(not paused and is_equal_approx(Engine.time_scale, 1.0), "Teardown preserves global time and pause")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_hud_and_presets() -> void:
	await _prepare()
	_check(level.enemies.size() == 2 and level.enemies[0].health.maximum_health == 60.0, "Room contains two 60-HP Slimes")
	_check(level.debug_hud.slots.size() == 3 and controller.catalyst_a.runtime_state.opened_slots == 3, "HUD and catalyst expose three slots")
	for index: int in 4:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_1 + index
		event.pressed = true
		Input.parse_input_event(event)
		await _step(2)
		event.pressed = false
		Input.parse_input_event(event)
		var expected: Array[StringName] = [&"firestorm", &"overload", &"charged_slash", &"basic"]
		_check(controller.get_recipe().id == expected[index], "Physical key %d equips %s" % [index + 1, expected[index]])
		_check(level.debug_hud.recipe_label.text == controller.get_recipe().display_name, "HUD shows the selected recipe")
	var event: DamageEvent = _damage(player.hurtbox, 15.0)
	event.source_id = level.enemies[0].get_instance_id()
	event.source_team_id = 2
	player.hurtbox.take_damage(event)
	await _step(2)
	_check(level.debug_hud.hp_bar.value == 85.0 and level.debug_hud.hp_label.text.contains("85"), "HP bar reflects resolved Player damage")


func _test_cast_lifetime() -> void:
	await _prepare()
	_aim(player.aim.global_position + Vector2.RIGHT * 180.0)
	var before: int = executor.spawned_projectiles
	await _tap(&"spell_cast")
	_check(player.action_state_machine.get_state_id() == &"cast_spell", "Right-click action enters CastSpell FSM")
	_check(executor.spawned_projectiles == before and controller.cooldown_remaining() > 0.0, "Windup delays spawning and commits cooldown")
	await _until(func() -> bool: return dummy.hit_count > 0)
	_check(dummy.hit_count == 1 and dummy.last_damage_event.base_damage == 14.0, "Basic projectile damages an actual Hurtbox")
	_check(dummy.get_dps() > 0.0 and dummy.total_damage_taken == 14.0, "Training dummy displays measured DPS and total resolved damage")
	_check(dummy.last_damage_event.aim_position.distance_to(player.aim.global_position + Vector2.RIGHT * 180.0) < 0.5, "Projectile retains its world-space cursor target")
	_check(get_nodes_in_group(&"spell_entities").filter(func(node: Node) -> bool: return node is SpellProjectile).is_empty(), "Non-piercing projectile is removed after impact")
	await _prepare()
	await _tap(&"spell_cast")
	await _tap(&"dash")
	_check(player.action_state_machine.get_state_id() == &"dash" and controller.cooldown_remaining() > 0.0, "Dash cancels windup while retaining committed cooldown")
	before = executor.spawned_projectiles
	await _time(0.3)
	_check(executor.spawned_projectiles == before, "Cancelled cast cannot spawn a delayed projectile")
	await _prepare()
	level.set_rune_preset(1)
	await _tap(&"spell_cast")
	var cast_state := player.action_state_machine.current_state as PlayerCastState
	_check(cast_state.payload.recipe_id == &"firestorm", "Cast snapshots the equipped recipe")
	level.set_rune_preset(2)
	level.set_rune_preset(1)
	_check(controller.cooldown_remaining() > 1.0, "Loadout swap does not reset an existing recipe cooldown")
	await _until(func() -> bool: return executor.spawned_projectiles > before)
	var storms: Array[Node] = get_nodes_in_group(&"spell_entities")
	_check(storms.any(func(node: Node) -> bool: return (node is SpellProjectile and node.context.snapshot.recipe_id == &"firestorm") or node is FirestormEffect), "Loadout swap preserves the already committed spell")
	await _prepare(Vector2(1220, 640))
	_aim(player.aim.global_position + Vector2.RIGHT * 200.0)
	await _tap(&"spell_cast")
	await _time(0.4)
	_check(get_nodes_in_group(&"spell_entities").is_empty(), "World wall stops and frees the basic projectile")
	await _prepare()
	Input.action_press(&"spell_cast")
	await _time(1.0)
	Input.action_release(&"spell_cast")
	_check(controller.cast_count == 1, "Holding cast does not repeatedly spawn spells")


func _test_rune_effects() -> void:
	await _prepare()
	controller.catalyst_a.install_runes([level.FIRE])
	await _tap(&"spell_cast")
	await _until(func() -> bool: return dummy.hit_count > 0)
	var hp: float = dummy.health.current_health
	_check(dummy.hurtbox.damage_resolver.status_controller.burn_remaining > 2.5, "Fire impact applies a timed burn")
	await _time(0.6)
	_check(dummy.health.current_health < hp and dummy.last_damage_event.source_kind == DamageEvent.SourceKind.DOT, "Burn DOT resolves through the same damage pipeline")
	_check(not dummy.last_damage_event.allow_resonance and dummy.last_damage_event.burn_damage == 0.0, "DOT cannot recursively apply burn/resonance")
	await _prepare()
	controller.catalyst_a.install_runes([level.WIND])
	level.dummy_b.global_position = Vector2(465, 547)
	level.enemies[0].global_position = Vector2(515, 537)
	await _step(2)
	await _tap(&"spell_cast")
	await _until(func() -> bool: return level.enemies[0].health.current_health < 60.0)
	_check(dummy.health.current_health < 120.0 and level.dummy_b.health.current_health < 120.0 and level.enemies[0].health.current_health < 60.0, "Wind projectile pierces three distinct targets")
	_check(dummy.last_damage_event.knockback.x > 100.0, "Wind increases knockback")
	await _prepare()
	controller.catalyst_a.install_runes([level.LIGHTNING])
	level.dummy_b.global_position = Vector2(465, 547)
	level.enemies[0].global_position = Vector2(515, 537)
	level.enemies[1].global_position = Vector2(565, 537)
	await _step(2)
	await _tap(&"spell_cast")
	await _until(func() -> bool: return executor.chain_hit_count >= 2)
	_check(executor.chain_hit_count == 2 and level.enemies[1].health.current_health == 60.0, "Lightning reaches at most two neighboring targets")
	_check(level.enemies[0].last_damage_event.source_kind == DamageEvent.SourceKind.RESONANCE and not level.enemies[0].last_damage_event.allow_resonance, "Chain child preserves a finite non-recursive source kind")


func _test_resonance_effects() -> void:
	await _prepare()
	level.set_rune_preset(1)
	await _tap(&"spell_cast")
	await _until(func() -> bool: return get_nodes_in_group(&"spell_entities").any(func(node: Node) -> bool: return node is FirestormEffect))
	_check(get_nodes_in_group(&"spell_entities").filter(func(node: Node) -> bool: return node is FirestormEffect).size() == 1, "Fire + Wind creates exactly one vortex")
	await _time(1.3)
	_check(executor.explosion_count == 1 and dummy.health.current_health < 95.0, "Vortex ends with one area explosion")
	_check(not get_nodes_in_group(&"spell_entities").any(func(node: Node) -> bool: return node is FirestormEffect), "Expired vortex frees itself")
	await _prepare()
	var slime: SlimeEnemy = level.enemies[0]
	slime.global_position = Vector2(840, 640)
	slime.ai_enabled = true
	slime.patrol_speed = 0.0
	slime.chase_speed = 0.0
	level.set_rune_preset(1)
	var payload: SpellSnapshot = controller.commit_cast()
	executor.spawn_firestorm(Vector2(800, 640), SpellContext.new(payload))
	await _time(0.2)
	_check(slime.position.x < 825.0, "Vortex physically pulls a Slime toward its center")
	await _prepare()
	level.set_rune_preset(2)
	level.dummy_b.global_position = Vector2(470, 547)
	await _step(2)
	await _tap(&"spell_cast")
	await _until(func() -> bool: return executor.explosion_count > 0)
	_check(dummy.last_damage_event.critical and dummy.last_damage_event.stun_seconds == 0.5, "Overload sends a critical explosion with a 0.5s stun")
	_check(level.dummy_b.health.current_health < 120.0 and dummy.hurtbox.damage_resolver.status_controller.is_stunned(), "Overload damages neighbors and applies stun")
	_check(get_nodes_in_group(&"combat_text").any(func(node: Node) -> bool: return node.label.text.ends_with("!")), "Critical explosion displays emphasized damage text")
	await _prepare()
	level.set_rune_preset(3)
	var before: int = executor.spawned_projectiles
	await _tap(&"spell_cast")
	await _until(func() -> bool: return executor.spawned_projectiles > before)
	_check(executor.spawned_projectiles == before + 3, "Charged Slash emits three branching lightning blades")
	var directions: Array[Vector2] = []
	for node: Node in get_nodes_in_group(&"spell_entities"):
		if node is SpellProjectile:
			directions.append(node.direction)
	_check(directions.size() >= 2 and not directions[0].is_equal_approx(directions[1]), "Branching blades travel along different directions")


func _test_enemy_fsm() -> void:
	await _prepare(Vector2(640, 640))
	var slime: SlimeEnemy = level.enemies[0]
	slime.ai_enabled = true
	slime.player = null
	var start_x: float = slime.position.x
	await _time(0.4)
	_check(slime.position.x < start_x and slime.state_machine.get_state_id() == &"patrol", "Patrol moves without an aggro target")
	await _time(1.0)
	_check(slime.velocity.x > 0.0, "Patrol turns at its left marker")
	slime.global_position = Vector2(600, 640)
	slime._left_x = 0
	slime._right_x = 1200
	slime._facing = -1
	await _time(0.3)
	_check(slime.global_position.x >= 596.0 and slime.velocity.x > 0.0, "Patrol turns before falling off a real ledge")
	slime.global_position = Vector2(1230, 640)
	slime._facing = 1
	await _time(0.4)
	_check(slime.position.x < 1230.0, "Patrol turns at a real wall")
	await _prepare(Vector2(700, 640))
	slime = level.enemies[0]
	slime.ai_enabled = true
	slime.global_position = Vector2(820, 640)
	await _time(0.1)
	_check(slime.state_machine.get_state_id() == &"chase" and slime.velocity.x < 0.0, "Player inside 200px causes Chase")
	await _until(func() -> bool: return slime.state_machine.get_state_id() == &"attack")
	var hp: float = player.health.current_health
	_check(not slime.bite_hitbox.active and slime.visual.color.g > 0.7, "Attack starts with a visible telegraph")
	await _time(0.2)
	_check(player.health.current_health == hp and not slime.bite_hitbox.active, "Telegraph does not deal premature damage")
	await _until(func() -> bool: return player.health.current_health < hp)
	_check(player.health.current_health == hp - 15.0, "Bite causes exactly 15 damage")
	await _time(0.12)
	_check(player.health.current_health == hp - 15.0, "One bite window cannot hit repeatedly")
	var event: DamageEvent = _damage(slime.hurtbox, 5.0)
	event.knockback = Vector2(200, -80)
	slime.hurtbox.take_damage(event)
	_check(slime.state_machine.get_state_id() == &"hurt" and not slime.bite_hitbox.active, "Hurt interrupts the bite and closes its hitbox")
	await _time(0.08)
	_check(slime.velocity.x > 0.0, "Hurt applies physical knockback")
	event = _damage(slime.hurtbox, 1.0)
	event.stun_seconds = 0.5
	slime.hurtbox.take_damage(event)
	await _time(0.35)
	_check(slime.statuses.is_stunned() and slime.state_machine.get_state_id() == &"hurt", "Stun keeps AI in Hurt for its authored duration")
	await _time(0.35)
	_check(not slime.statuses.is_stunned() and slime.state_machine.get_state_id() != &"hurt", "AI resumes after stun expires")
	event = _damage(slime.hurtbox, 1.0)
	event.burn_damage = 3.0
	event.burn_duration = 1.0
	event.burn_interval = 0.5
	slime.hurtbox.take_damage(event)
	hp = slime.health.current_health
	await _time(0.6)
	_check(slime.health.current_health < hp, "Slime receives burn DOT")
	event = _damage(slime.hurtbox, 999.0)
	slime.hurtbox.take_damage(event)
	_check(slime.state_machine.get_state_id() == &"dead" and not slime.bite_hitbox.active, "Lethal hit enters Dead with no active bite")
	await _time(0.35)
	_check(not is_instance_valid(slime), "Dead Slime dissolves and frees its scene")
	level.reset_room()
	await _step(3)
	_check(level.enemies.size() == 2 and is_instance_valid(level.enemies[0]) and level.enemies[0].health.current_health == 60.0, "R restores destroyed Slimes")


func _test_spam_cleanup() -> void:
	await _prepare()
	_aim(player.aim.global_position + Vector2.UP * 200.0)
	var payload: SpellSnapshot = controller.commit_cast()
	payload.origin = Vector2(640, 200)
	payload.direction = Vector2.UP
	# Warm up allocations/resources before comparing retained objects.
	for index: int in 70:
		executor.spawn_cast(payload)
	await _time(2.5)
	var baseline_objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var baseline_resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var memory_samples: Array[int] = []
	for burst: int in 3:
		level.set_rune_preset(burst + 1)
		for index: int in 200:
			controller.reset_runtime()
			var next_payload: SpellSnapshot = controller.commit_cast()
			next_payload.origin = Vector2(640, 200)
			next_payload.direction = Vector2.UP
			executor.spawn_cast(next_payload)
		_check(get_nodes_in_group(&"spell_entities").size() <= executor.maximum_spell_entities, "Spam burst %d respects the active entity cap" % (burst + 1))
		await _time(2.5)
		_check(get_nodes_in_group(&"spell_entities").is_empty(), "Spam burst %d frees all expired projectiles" % (burst + 1))
		memory_samples.append(int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	_check(int(Performance.get_monitor(Performance.OBJECT_COUNT)) <= baseline_objects + 5, "Repeated spam does not retain projectile/context Nodes or RefCounted objects")
	_check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= baseline_resources + 2, "Repeated spam does not retain hitbox Shape Resources")
	print("STRESS retained memory samples (bytes): %s" % [memory_samples])
	print("STRESS objects baseline=%d final=%d resources baseline=%d final=%d" % [baseline_objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)), baseline_resources, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
	await _prepare()
	level.set_rune_preset(1)
	await _tap(&"spell_cast")
	await _until(func() -> bool: return dummy.hit_count > 0)
	level.reset_room()
	await _step(3)
	_check(get_nodes_in_group(&"spell_entities").is_empty() and dummy.hurtbox.damage_resolver.status_controller.burn_remaining == 0.0, "R clears active effects, projectiles and burn clocks")
	_check(dummy.get_dps() == 0.0 and dummy.total_damage_taken == 0.0, "R resets DPS measurement")


func _prepare(position: Vector2 = Vector2(365, 547)) -> void:
	_release_inputs()
	level.reset_room()
	level.combat_feedback.hit_stop_seconds = 0.0
	executor.chain_hit_count = 0
	executor.explosion_count = 0
	controller.cast_count = 0
	level.set_rune_preset(4)
	for enemy: SlimeEnemy in level.enemies:
		enemy.ai_enabled = false
		enemy.patrol_speed = 65.0
		enemy.chase_speed = 115.0
		enemy.player = player
	player.reset_movement_at(position)
	await _step(4)
	_aim(player.aim.global_position + Vector2.RIGHT * 180.0)


func _damage(target: Hurtbox, amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = player.get_instance_id()
	event.source_team_id = 1
	event.target_id = target.get_actor_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = amount
	return event


func _aim(world_position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_canvas_transform() * world_position
	root.push_input(event, true)
	player.aim.sample_cursor()


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _step(1)
	Input.action_release(action)


func _release_inputs() -> void:
	for action: StringName in [&"attack", &"spell_cast", &"jump", &"dash", &"move_left", &"move_right", &"reset_player", &"preset_firestorm", &"preset_overload", &"preset_charged", &"preset_basic"]:
		Input.action_release(action)


func _until(predicate: Callable, seconds: float = 1.5) -> void:
	for frame: int in ceili(seconds * Engine.physics_ticks_per_second):
		if predicate.call():
			return
		await _step(1)


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



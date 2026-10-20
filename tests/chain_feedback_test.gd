extends SceneTree
## Synthetic target placement only. Exercises the actual executor, Hurtbox,
## resolver and visual consumer; native readability needs a separate earned-save run.
var checks: int = 0
var failures: int = 0
var room: Node2D
var executor: SpellExecutor
var source: Node2D
var targets: Array[TrainingDummy] = []
var results: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\", "/").begins_with(qa + "/"):
		print("FAIL: isolated QA data root required"); quit(2); return
	room = Node2D.new()
	room.position = Vector2(300, 320) # Nonzero transform tests world-space endpoints.
	root.add_child(room)
	source = Node2D.new(); room.add_child(source)
	executor = SpellExecutor.new(); room.add_child(executor)
	for index: int in 3:
		var dummy: TrainingDummy = preload("res://scenes/training_dummy.tscn").instantiate() as TrainingDummy
		dummy.position = Vector2(index * 100.0, 0)
		room.add_child(dummy)
		dummy.set_physics_process(false) # Declared stationary query fixture, not gameplay footage.
		dummy.hurtbox.hit_resolved.connect(_observe)
		targets.append(dummy)
	await _step(3)
	await _accepted_links()
	await _rejected_links()
	await _nonchain_results()
	await _budget()
	await _copied_endpoints_and_lifetime()
	var final_visual := SpellVisual.new()
	final_visual.configure_chain(Vector2(10, 20), Vector2(90, 20), 1)
	executor.add_child(final_visual)
	var weak_visual: WeakRef = weakref(final_visual)
	var weak_executor: WeakRef = weakref(executor)
	room.queue_free(); await _step(3)
	_check(weak_visual.get_ref() == null and weak_executor.get_ref() == null and get_nodes_in_group(&"spell_entities").is_empty(), "Room teardown frees the marker and executor without retained target references")
	print("RESULT ChainFeedback checks=%d failures=%d hz=%d" % [checks, failures, Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)


func _observe(event: DamageEvent, result: DamageResult) -> void:
	results.append({"target":event.target_id, "root":event.root_event_id, "parent":event.parent_event_id, "source":event.source_kind, "recursive":event.allow_resonance, "damage":result.actual_damage, "blocked":result.blocked})


func _payload(links: int = 2) -> SpellSnapshot:
	var payload := SpellSnapshot.new()
	payload.source_id = source.get_instance_id()
	payload.root_id = CombatIds.next_id()
	payload.origin = targets[0].hurtbox.global_position - Vector2(60, 0)
	payload.direction = Vector2.RIGHT
	payload.damage = 10.0
	payload.chain_targets = links
	payload.chain_radius = 150.0
	payload.recipe_id = &"visual_contract_fixture"
	payload.behavior_id = &"basic"
	return payload


func _reset() -> void:
	executor.clear_entities(); await _step(3)
	for target: TrainingDummy in targets:
		target.health.minimum_health = 0.0
		target.reset_at_home()
	results.clear()
	await _step(2)


func _visuals() -> Array[SpellVisual]:
	var found: Array[SpellVisual] = []
	for child: Node in executor.get_children():
		if child is SpellVisual: found.append(child as SpellVisual)
	return found


func _accepted_links() -> void:
	await _reset()
	var payload: SpellSnapshot = _payload()
	var context := SpellContext.new(payload)
	var count_before: int = executor.chain_hit_count
	executor.primary_hit(targets[0].hurtbox, context, CombatIds.next_id(), Vector2.RIGHT)
	var visuals: Array[SpellVisual] = _visuals()
	_check(results.size() == 3 and executor.chain_hit_count == count_before + 2 and context.remaining_chain == 0, "Real primary contact still resolves two bounded chain hits immediately")
	_check(is_equal_approx(targets[0].health.current_health, 110.0) and is_equal_approx(targets[1].health.current_health, 114.0) and is_equal_approx(targets[2].health.current_health, 114.0), "Primary10 and child6 damage remain unchanged by presentation")
	_check(visuals.size() == 2 and visuals[0].chain_ordinal == 1 and visuals[1].chain_ordinal == 2, "Only the two accepted chain consumers create ordinal1/2 markers")
	if visuals.size() == 2:
		for index: int in 2:
			_check(visuals[index].segments == [targets[index].hurtbox.global_position, targets[index + 1].hurtbox.global_position] and visuals[index].lifetime == 0.25 and visuals[index].z_index == 20, "Marker keeps actual world-space hop/lifetime and paints above the impact burst: %d" % (index + 1))
	_check(results.all(func(value: Dictionary) -> bool: return value["root"] == payload.root_id and not value["recursive"]), "Every hit retains the shared root and recursion guard")
	_check(results.size() >= 2 and results[1]["parent"] == payload.root_id and results[1]["source"] == DamageEvent.SourceKind.RESONANCE and context.visited_targets.size() == 3, "The visual does not replace the child event or visited-target ledger")
	var events_before: int = results.size()
	executor.primary_hit(targets[0].hurtbox, context, CombatIds.next_id(), Vector2.RIGHT)
	_check(results.size() == events_before and _visuals().size() == 2, "Repeated primary contact cannot replay damage or chain markers")


func _rejected_links() -> void:
	await _reset()
	# The logical gate applies immediately, before deferred monitorability changes.
	targets[1].hurtbox.set_invulnerable(true)
	var count_before: int = executor.chain_hit_count
	executor.primary_hit(targets[0].hurtbox, SpellContext.new(_payload(1)), CombatIds.next_id(), Vector2.RIGHT)
	_check(_visuals().is_empty() and executor.chain_hit_count == count_before and targets[1].health.current_health == 120.0, "Blocked neighbor receives neither damage nor a false endpoint confirmation")
	await _reset()
	targets[1].health.minimum_health = targets[1].health.maximum_health
	executor.primary_hit(targets[0].hurtbox, SpellContext.new(_payload(1)), CombatIds.next_id(), Vector2.RIGHT)
	_check(results.any(func(value: Dictionary) -> bool: return value["target"] == targets[1].get_instance_id() and value["damage"] == 0.0) and _visuals().is_empty(), "Actual zero-loss health-floor result cannot produce a successful chain marker")
	await _reset()
	targets[1].health.apply_damage(999.0)
	executor.primary_hit(targets[0].hurtbox, SpellContext.new(_payload(1)), CombatIds.next_id(), Vector2.RIGHT)
	_check(_visuals().is_empty() and targets[2].health.current_health == 120.0, "Dead nearest neighbor is excluded and no visual invents an out-of-radius hop")


func _nonchain_results() -> void:
	await _reset()
	var payload: SpellSnapshot = _payload(0)
	executor.primary_hit(targets[0].hurtbox, SpellContext.new(payload), CombatIds.next_id(), Vector2.RIGHT)
	_check(targets[0].health.current_health == 110.0 and _visuals().is_empty(), "A direct hit without links creates no chain cue")
	payload.explosion_damage = 4.0
	executor.explode(targets[1].hurtbox.global_position, SpellContext.new(payload))
	var visuals: Array[SpellVisual] = _visuals()
	_check(visuals.size() == 1 and visuals[0].chain_ordinal == 0 and visuals[0].segments.is_empty() and visuals[0].radius == payload.effect_radius, "Real explosion keeps its unlabelled ring despite RESONANCE child damage")
	var dot: DamageEvent = payload.damage_event(targets[1].hurtbox, CombatIds.next_id(), 1.0, true)
	dot.source_kind = DamageEvent.SourceKind.DOT
	_check(targets[1].hurtbox.take_damage(dot).actual_damage == 1.0 and _visuals().size() == 1 and visuals[0].chain_ordinal == 0, "A real DOT result cannot relabel the existing ring as a chain")
	var ordinary_line := SpellVisual.new()
	ordinary_line.segments = [Vector2(10, 10), Vector2(40, 10)]
	executor.add_child(ordinary_line)
	_check(ordinary_line.chain_ordinal == 0 and ordinary_line.lifetime == 0.25 and ordinary_line.z_index == 8, "Legacy line callers remain opt-out and keep their existing lifetime/layer")


func _budget() -> void:
	await _reset()
	for index: int in executor.maximum_spell_entities:
		var visual := SpellVisual.new()
		visual.lifetime = 2.0
		executor.add_child(visual)
	var count_before: int = executor.chain_hit_count
	executor.primary_hit(targets[0].hurtbox, SpellContext.new(_payload()), CombatIds.next_id(), Vector2.RIGHT)
	_check(get_nodes_in_group(&"spell_entities").size() == 64 and _visuals().all(func(value: SpellVisual) -> bool: return value.chain_ordinal == 0), "Saturated existing64 budget drops cosmetic confirmations without allocating extra nodes")
	_check(executor.chain_hit_count == count_before + 2 and targets[1].health.current_health == 114.0 and targets[2].health.current_health == 114.0, "Visual saturation never suppresses either accepted child hit")


func _copied_endpoints_and_lifetime() -> void:
	await _reset()
	executor.primary_hit(targets[0].hurtbox, SpellContext.new(_payload(1)), CombatIds.next_id(), Vector2.RIGHT)
	var visuals: Array[SpellVisual] = _visuals()
	_check(visuals.size() == 1, "One accepted hop creates exactly one existing SpellVisual node")
	if visuals.is_empty(): return
	var points: Array[Vector2] = visuals[0].segments.duplicate()
	var marker_ref: WeakRef = weakref(visuals[0])
	targets[1].global_position += Vector2(500, 100)
	targets[1].queue_free()
	await _step(2)
	_check(is_instance_valid(visuals[0]) and visuals[0].segments == points and visuals[0].chain_ordinal == 1, "Moving/freeing the struck actor cannot move or invalidate copied marker endpoints")
	await _step(ceili(0.35 * Engine.physics_ticks_per_second))
	_check(marker_ref.get_ref() == null and get_nodes_in_group(&"spell_entities").is_empty(), "Marker expires through the unchanged SpellVisual lifetime without actor ownership")


func _step(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", label])

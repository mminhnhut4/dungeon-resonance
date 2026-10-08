extends "res://tests/survival_test_base.gd"
## Real Boss socket/hazard/contact with cosmetic bounds and lifetime checks.
var received: Array[Dictionary] = []

func _initialize() -> void:
	suite = "boss_orb_vfx"
	super._initialize()

func test_system() -> void:
	session.set_enabled(false)
	player.controls_enabled = false
	player.hurtbox.set_invulnerable(true)
	for enemy: SlimeEnemy in level.enemies:
		enemy.contact_damage_enabled = false
	var boss: BossGolem = preload("res://scenes/enemies/boss_golem.tscn").instantiate()
	boss.position = Vector2(1150, 640)
	boss.feedback = level.combat_feedback
	level.add_child(boss)
	await _step(3)
	player.reset_movement_at(Vector2(870, 640))
	boss.player = player
	boss.fsm.transition_to(&"orbs")
	await _time(0.40)
	var skin: BossGolemSkin = boss.get_node("GolemStoneSkin") as BossGolemSkin
	_check(boss.emitted_orbs == 0 and skin._state == &"orbs" and skin._state_time < 0.55, "Existing gather seal precedes its first physical orb")
	while boss.emitted_orbs == 0 and boss.state_time < 1.0:
		await _step(1)
	var orbs: Array[EnemyHazard] = _owned_orbs(boss.get_instance_id())
	_check(orbs.size() == 1 and boss.state_time >= 0.55, "Existing 0.55-second socket release emits its first real orb")
	if orbs.is_empty():
		boss.queue_free()
		return
	var orb: EnemyHazard = orbs[0]
	var shape: Shape2D = orb.hitbox._query_shape
	var root_id: int = orb.attack.root_event_id
	var body_transform: Transform2D = (orb.get_child(0) as CollisionShape2D).transform
	var visual: Node2D = orb.get_node_or_null("BossOrbVFX") as Node2D
	_check(visual != null and orb.self_modulate.a == 0.0, "Boss-owned live orb replaces the flat legacy circle with its visible glyph")
	if visual == null:
		print("BASELINE: Boss socket emits EnemyHazard with legacy flat circle only; flight checks skipped")
		boss.queue_free()
		for item: EnemyHazard in orbs: item.queue_free()
		await _step(3)
		return
	_check(visual.material is CanvasItemMaterial and (visual.material as CanvasItemMaterial).light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED and (visual.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_MIX, "Orb body/wake use normal unshaded ink with no light pass")
	var socket_delta: float = orb.global_position.distance_to(boss.global_position + Vector2(boss.facing * 46.0, -65.0))
	_check(socket_delta <= 190.0 / Engine.physics_ticks_per_second * 3.0, "Glyph begins at the real socket within finite physics-step travel")
	var position_before: Vector2 = orb.global_position
	await _time(0.20)
	var sample: Dictionary = visual.call("snapshot")
	_check(orb.global_position != position_before and int(sample["points"]) > 1 and int(sample["points"]) <= 12 and float(sample["wake_length"]) <= 72.001, "Real flight builds a finite twelve-point, 72px wake")
	_check(Vector2(sample["head_world"]).is_equal_approx(orb.global_position) and Vector2(sample["direction"]).is_equal_approx(orb.direction), "Glyph head and heading read actual homing body position/direction")
	_check(is_equal_approx(float(sample["age"]), 5.0 - orb.life) and int(sample["lights"]) == 0 and int(sample["damage_emitters"]) == 0 and int(sample["impact_emitters"]) == 0, "Flight detail reads hazard life and creates no gameplay/contact/light emitter")
	_check(orb.hitbox._query_shape == shape and (shape as CircleShape2D).radius == 9.0 and orb.attack.root_event_id == root_id and (orb.get_child(0) as CollisionShape2D).transform == body_transform, "Visual attachment preserves original nine-pixel Hitbox, root and collision transform")
	paused = true
	var paused_position: Vector2 = orb.global_position
	var paused_life: float = orb.life
	var paused_sample: Dictionary = visual.call("snapshot")
	await _process_steps(3)
	_check(orb.global_position == paused_position and orb.life == paused_life and visual.call("snapshot") == paused_sample, "Tree pause holds flight body, lifetime and wake together")
	paused = false
	level.combat_feedback.hit_stop_remaining = 0.08
	await _step(2)
	paused_position = orb.global_position
	paused_life = orb.life
	paused_sample = visual.call("snapshot")
	await _step(2)
	_check(orb.global_position == paused_position and orb.life == paused_life and visual.call("snapshot") == paused_sample, "Existing local hitstop holds homing movement and visual wake")
	level.combat_feedback.reset_feedback()
	while boss.emitted_orbs < 3 and boss.state_time < 1.0:
		await _step(1)
	boss.ai_enabled = false
	_check(boss.emitted_orbs == 3 and _owned_orbs(boss.get_instance_id()).size() == 3, "Visuals keep the existing three-shot release without adding a hazard")
	player.hurtbox.hit_resolved.connect(_observe)
	player.hurtbox.set_invulnerable(false)
	var impact_before: int = level.presentation.impact_count
	var visual_id: int = visual.get_instance_id()
	for tick: int in Engine.physics_ticks_per_second * 3:
		if not received.is_empty(): break
		await _step(1)
	_check(not received.is_empty() and float(received[0]["damage"]) == 15.0 and int(received[0]["source"]) == boss.get_instance_id(), "Physical orb contact retains its fifteen damage and Boss source")
	_check(level.presentation.impact_count == impact_before + 1, "Accepted contact uses exactly the existing generic impact adapter")
	await _step(3)
	_check(not is_instance_id_valid(visual_id), "Real contact frees the glyph and wake with its hazard")
	player.hurtbox.set_invulnerable(true)
	for hazard: Node in get_nodes_in_group(&"enemy_hazards"): hazard.queue_free()
	await _step(3)
	await _scope_caps_and_cleanup(boss)
	boss.queue_free()
	await _step(3)
	_check(get_nodes_in_group(&"boss_orb_vfx").is_empty(), "Room-owned test cleanup releases all orb visual slots")

func _scope_caps_and_cleanup(boss: BossGolem) -> void:
	var foreign: EnemyHazard = _hazard(level.get_instance_id(), &"orb")
	var wave: EnemyHazard = _hazard(boss.get_instance_id(), &"wave")
	var orphan: EnemyHazard = _hazard(0, &"orb")
	_check(not foreign.has_node("BossOrbVFX") and not wave.has_node("BossOrbVFX") and not orphan.has_node("BossOrbVFX"), "Only live Boss-owned orbs receive this presentation")
	foreign.queue_free(); wave.queue_free(); orphan.queue_free()
	await _step(2)
	var samples: Array[EnemyHazard] = []
	for index: int in 26:
		samples.append(_hazard(boss.get_instance_id(), &"orb"))
	_check(get_nodes_in_group(&"boss_orb_vfx").size() == 24 and not samples[25].has_node("BossOrbVFX") and samples[25].self_modulate.a == 1.0, "Twenty-four visual slots retain visible legacy fallback beyond the cap")
	var survivor: EnemyHazard = samples[0]
	var visual: Node2D = survivor.get_node("BossOrbVFX") as Node2D
	visual.queue_free()
	await _step(2)
	_check(is_instance_valid(survivor) and survivor.self_modulate.a == 1.0 and not survivor.has_node("BossOrbVFX"), "Removing the visual alone restores the still-live original glyph")
	for hazard: EnemyHazard in samples: hazard.queue_free()
	await _step(3)
	_check(get_nodes_in_group(&"boss_orb_vfx").is_empty(), "Hazard disposal releases capped cosmetic children without retained Nodes")
	var expiring: EnemyHazard = _hazard(boss.get_instance_id(), &"orb")
	var expiring_visual_id: int = expiring.get_node("BossOrbVFX").get_instance_id()
	expiring.life = 0.02
	await _time(0.08)
	_check(not is_instance_valid(expiring) and not is_instance_id_valid(expiring_visual_id), "Existing hazard deadline frees its visual without a second lifetime timer")
	var sibling_room := Node2D.new()
	root.add_child(sibling_room)
	var sibling_boss: BossGolem = preload("res://scenes/enemies/boss_golem.tscn").instantiate()
	sibling_boss.ai_enabled = false
	sibling_room.add_child(sibling_boss)
	var survivor_orb := EnemyHazard.new()
	survivor_orb.source_id = sibling_boss.get_instance_id()
	survivor_orb.player = player
	survivor_orb.feedback = level.combat_feedback
	survivor_orb.position = Vector2(1300, 250)
	sibling_room.add_child(survivor_orb)
	var survivor_visual_id: int = survivor_orb.get_node("BossOrbVFX").get_instance_id()
	sibling_boss.queue_free()
	await _step(2)
	_check(is_instance_valid(survivor_orb) and is_instance_id_valid(survivor_visual_id) and survivor_orb.hitbox.active, "Source Boss disposal preserves the original still-live hazard lifetime")
	sibling_room.queue_free()
	await _step(3)
	_check(not is_instance_valid(survivor_orb) and not is_instance_id_valid(survivor_visual_id), "Intact sibling-room disposal releases the orb and cosmetic wake together")

func _hazard(source: int, kind: StringName) -> EnemyHazard:
	var hazard := EnemyHazard.new()
	hazard.source_id = source
	hazard.kind = kind
	hazard.player = player
	hazard.feedback = level.combat_feedback
	hazard.position = Vector2(1300, 250)
	level.add_child(hazard)
	return hazard

func _owned_orbs(source: int) -> Array[EnemyHazard]:
	var items: Array[EnemyHazard] = []
	for node: Node in get_nodes_in_group(&"enemy_hazards"):
		if node is EnemyHazard and (node as EnemyHazard).source_id == source and (node as EnemyHazard).kind == &"orb":
			items.append(node as EnemyHazard)
	return items

func _observe(event: DamageEvent, result: DamageResult) -> void:
	if not result.blocked and result.actual_damage > 0.0:
		received.append({"damage": result.actual_damage, "source": event.source_id, "root": event.root_event_id})

func _process_steps(count: int) -> void:
	for tick: int in count: await process_frame

extends "res://tests/depth_actor_test.gd"
## Focused actual floor-owned field/projectile skin and emitter invariants.
const SKIN: Script = preload("res://scripts/presentation/depth_enemy_skill_art.gd")

func _enemy(floor_id: int) -> void:
	if floor_id not in [2, 4]: return
	var enemy: BaseEnemy = await _fresh_enemy(floor_id)
	if floor_id == 2: hero.reset_movement_at(Vector2(1000, 640))
	enemy.state_machine.transition_to(&"telegraph")
	enemy.state_machine.transition_to(&"attack")
	var owned: Array[WorldEnemyHazard] = []
	for candidate: Node in get_nodes_in_group(&"world_enemy_hazards"):
		if candidate.source_id == enemy.get_instance_id(): owned.append(candidate)
	_check(owned.size() == 1, "Floor%d existing cast emits exactly one actual hazard" % floor_id)
	if owned.is_empty(): return
	var hazard: WorldEnemyHazard = owned[0]
	_check(hazard.has_node("DepthEnemySkillArt"), "Floor%d production ready hook already attached the floor skin" % floor_id)
	var visual: Node2D = hazard.get_node_or_null("DepthEnemySkillArt")
	_check(visual != null and hazard.self_modulate.a == 0.0, "Floor%d actual hazard binds its floor skin and suppresses only self draw" % floor_id)
	if visual == null: return
	var shape: CircleShape2D = (hazard.get_child(0) as CollisionShape2D).shape
	var shape_id: int = shape.get_instance_id()
	var root_id: int = hazard.attack.root_event_id
	var start: Dictionary = visual.snapshot()
	_check(start.radius == (64.0 if floor_id == 4 else 7.0) and start.lifetime == (3.0 if floor_id == 4 else 3.5) and start.center_world == hazard.global_position, "Floor%d paint reads real radius/lifetime/center" % floor_id)
	_check(start.element == (&"fire" if floor_id == 4 else &"poison") and start.stage == (RenderedSpellArt.FIELD if floor_id == 4 else RenderedSpellArt.PROJECTILE) and visual.layers[0].texture == RenderedSpellArt.cell(start.stage, start.element), "Floor%d uses the actual matching rendered field/projectile paint" % floor_id)
	_check(visual.get_child_count() == 2 and start.layers == 2 and start.lights == 0 and start.damage_emitters == 0 and start.impact_emitters == 0 and not SKIN.attach_to(hazard), "Floor%d skin has finite two layers, no emitter/light and no duplicate attachment" % floor_id)
	if floor_id == 4:
		_check(not start.active and hero.health.current_health == 100, "Forge field warns on the existing0.45s clock without premature damage")
		feedback.hit_stop_seconds = 0.08
		var accepted: Array[Dictionary] = []
		var field_observer: Callable = func(event: DamageEvent, result: DamageResult) -> void:
			if event.root_event_id == root_id and not result.blocked and result.actual_damage > 0:
				accepted.append({"damage": result.actual_damage, "frozen": feedback.is_frozen(), "active": visual.snapshot().active, "age": visual.snapshot().age, "owner_age": hazard.age})
		hero.hurtbox.hit_resolved.connect(field_observer)
		for tick: int in Engine.physics_ticks_per_second:
			await _step(1)
			if not accepted.is_empty(): break
		hero.hurtbox.hit_resolved.disconnect(field_observer)
		_check(accepted.size() == 1 and accepted[0].frozen and accepted[0].active and accepted[0].age == accepted[0].owner_age, "First accepted forge tick seeks active paint on the same frozen contact clock")
		_check(visual.snapshot().active and hero.health.current_health == 98.0 and hero.hurtbox.damage_resolver.status_controller.slow_remaining > 0, "Forge paint activates with the unchanged actual2damage/slow tick")
		feedback.reset_feedback()
		feedback.hit_stop_seconds = 0.0
	else:
		var position: Vector2 = hazard.global_position
		await _time(0.10)
		_check(hazard.global_position != position and visual.snapshot().age == hazard.age and is_equal_approx(visual.rotation, hazard.direction.angle()), "Spore paint travels on the existing direction and owner age")
	_check(shape.get_instance_id() == shape_id and hazard.attack.root_event_id == root_id and shape.radius == start.radius, "Floor%d skin leaves collider/root payload identity unchanged" % floor_id)
	feedback.hit_stop_remaining = 0.10
	await _step(1)
	var frozen: Dictionary = visual.snapshot()
	var owner_age: float = hazard.age
	await _step(2)
	_check(feedback.is_frozen() and hazard.age == owner_age and visual.snapshot() == frozen, "Floor%d existing hitstop holds owner clock and paint together" % floor_id)
	feedback.reset_feedback()
	var visual_id: int = visual.get_instance_id()
	if floor_id == 4:
		await _time(3.05)
		_check(not is_instance_id_valid(visual_id), "Forge field expiry frees its two paint layers with the real owner")
	else:
		var accepted: Array[Dictionary] = []
		var source_id: int = enemy.get_instance_id()
		var observer: Callable = func(event: DamageEvent, result: DamageResult) -> void:
			if event.source_id == source_id and not result.blocked:
				accepted.append({"damage": result.actual_damage, "poison": event.poison_stacks, "root": event.root_event_id})
		hero.hurtbox.hit_resolved.connect(observer)
		for tick: int in Engine.physics_ticks_per_second * 3:
			await _step(1)
			if not accepted.is_empty(): break
		hero.hurtbox.hit_resolved.disconnect(observer)
		_check(accepted.size() == 1 and accepted[0].damage == 12.0 and accepted[0].poison == 1 and accepted[0].root == root_id, "Spore painted flight retains its actual12damage/poison/root contact")
		await _step(3)
		_check(not is_instance_id_valid(visual_id), "Spore real contact frees the existing hazard and paint")

func _boss() -> void:
	var foreign: WorldEnemyHazard = WorldEnemyHazard.new()
	foreign.source_id = hero.get_instance_id()
	foreign.player = hero
	foreign.kind = &"slow_field"
	arena.add_child(foreign)
	_check(not SKIN.attach_to(foreign) and foreign.self_modulate.a == 1.0, "Foreign old hazard keeps its existing presentation")
	foreign.queue_free()
	await _step(3)

func _lifetimes() -> void:
	await _wipe()
	_check(get_nodes_in_group(&"depth_enemy_skill_art").is_empty(), "Room cleanup releases every new cosmetic budget slot")
	var enemy: BaseEnemy = await _fresh_enemy(2)
	var hazards: Array[WorldEnemyHazard] = []
	for index: int in 17:
		var hazard := WorldEnemyHazard.new()
		hazard.source_id = enemy.get_instance_id()
		hazard.player = hero
		hazard.direction = Vector2.RIGHT
		hazard.position = Vector2(1600, 400)
		arena.add_child(hazard)
		if not hazard.has_node("DepthEnemySkillArt"): SKIN.attach_to(hazard)
		hazards.append(hazard)
	_check(get_nodes_in_group(&"depth_enemy_skill_art").size() == 16 and not hazards[16].has_node("DepthEnemySkillArt") and hazards[16].self_modulate.a == 1.0, "Sixteen cosmetic slots are bounded and overflow keeps the existing draw")
	var retained: WorldEnemyHazard = hazards[0]
	var original: float = retained.age
	retained.get_node("DepthEnemySkillArt").queue_free()
	await _step(1)
	_check(retained.self_modulate.a == 1.0 and retained.age >= original and retained.hitbox.active, "Removing only the skin restores parent art and leaves its gameplay owner alive")
	enemy.queue_free()
	await _step(3)
	_check(get_nodes_in_group(&"world_enemy_hazards").is_empty() and get_nodes_in_group(&"depth_enemy_skill_art").is_empty(), "Source death clears every hazard and its finite child slots")

extends "res://tests/survival_test_base.gd"
## Real commit clocks/contact events plus finite GPU cosmetic ownership.

func _initialize() -> void:
	suite = "combat_polish"
	super._initialize()


func test_system() -> void:
	player.controls_enabled = false
	player.energy.enabled = false
	var presentation: SlicePresentation = level.presentation
	var weapon: Weapon = player.equipped_weapon
	var trail: WeaponTrail = presentation.trail
	var hit_origin: Transform2D = player.hurtbox.global_transform
	var definitions: Array[WeaponDefinition] = [
		preload("res://data/weapons/ancient_sword.tres"),
		preload("res://data/weapons/demon_greatsword.tres"),
		preload("res://data/weapons/gale_dual_daggers.tres"),
		preload("res://data/weapons/blood_spiked_whip.tres"),
	]
	for definition: WeaponDefinition in definitions:
		weapon.equip(definition)
		weapon.start_combo()
		trail.refresh_visual()
		_check(not trail.crescent.visible and not weapon.hitbox.active, "%s keeps its bright crescent out of the wind-up telegraph" % definition.id)
		var step: AttackStepDefinition = definition.combo_steps[0]
		weapon.advance(step.windup_seconds + step.active_seconds * 0.7)
		trail.refresh_visual()
		_check(weapon.hitbox.active and trail.crescent.visible and trail.crescent_vertex_count == 66, "%s shows one bounded crescent during the authored Active window" % definition.id)
		var transform: Transform2D = weapon.hitbox.global_transform
		var shape: Shape2D = weapon.hitbox._query_shape
		var progress: float = trail.crescent_progress
		var direction: Vector2 = weapon.snapshot.attack_direction
		trail.refresh_visual()
		_check(is_equal_approx(trail.crescent_progress, progress) and Vector2.from_angle(trail.crescent.global_rotation).is_equal_approx(direction), "%s silver arc freezes with the committed weapon clock and aim" % definition.id)
		_check(weapon.hitbox.global_transform.is_equal_approx(transform) and weapon.hitbox._query_shape == shape and player.hurtbox.global_transform.is_equal_approx(hit_origin), "%s cosmetic meshes leave active hitbox and Player hurtbox unchanged" % definition.id)
		weapon.cancel_combo()
		_check(not trail.crescent.visible and trail._snapshot == null, "%s cancel releases the crescent and its snapshot immediately" % definition.id)
	weapon.equip(preload("res://data/weapons/storm_arcane_staff.tres"))
	weapon.start_combo()
	weapon.advance(weapon.definition.combo_steps[0].windup_seconds + 0.01)
	trail.refresh_visual()
	_check(not trail.crescent.visible, "Ranged staff keeps its cast presentation without inventing a melee hitbox")
	weapon.cancel_combo()
	level.spell_executor.clear_entities()
	await _step(3)
	await _test_contacts(presentation)
	await _test_projectile_wake(presentation)
	await _test_wall_contacts(presentation)
	await _test_budgets_and_cleanup(presentation)


func _test_contacts(presentation: SlicePresentation) -> void:
	var dummy: TrainingDummy = level.dummy_a
	var melee: DamageEvent = _damage(dummy.hurtbox, 3.0)
	melee.melee_hit = true
	melee.physical_damage = true
	melee.burn_damage = 1.0
	melee.burn_duration = 0.5
	melee.attack_direction = Vector2.RIGHT
	var before: int = presentation.impact_count
	var result: DamageResult = dummy.hurtbox.take_damage(melee)
	var burst: ImpactBurst = presentation.impacts.get_child(presentation.impacts.get_child_count() - 1) as ImpactBurst
	_check(result.actual_damage == 3.0 and presentation.impact_count == before + 1, "Resolved melee contact creates exactly one spark owner without changing damage")
	_check(burst.element == &"fire" and burst.melee_sparks and burst.flash.color == Color(1, 0.4, 0.08), "Fire melee preserves the elemental flash while warm metal sparks mark contact")
	_check((burst.particles.process_material as ParticleProcessMaterial).color == Color(1, 0.66, 0.16), "Melee hit sparks are golden orange GPU particles")
	dummy.hurtbox.take_damage(melee)
	_check(presentation.impact_count == before + 1, "A duplicate blocked melee event cannot repeat its VFX")
	var spell: DamageEvent = _damage(dummy.hurtbox, 2.0)
	spell.spell_id = &"basic"
	spell.attack_direction = Vector2.LEFT
	before = presentation.impact_count
	var basic_result: DamageResult = dummy.hurtbox.take_damage(spell)
	burst = presentation.impacts.get_child(presentation.impacts.get_child_count() - 1) as ImpactBurst
	_check(not basic_result.blocked and basic_result.actual_damage == 2.0 and presentation.impact_count == before + 1 and burst.spell_recipe_id == spell.spell_id and burst.element == &"physical", "Accepted basic contact retains its neutral appearance and creates one finite owner")
	_check(burst.particles.one_shot and burst.particles.amount <= 16 and burst.duration <= 0.5, "Basic target contact keeps bounded particles and a finite owner lifetime")
	# Controlled committed payload exercises the real accepted-contact path;
	# it is not a claim that a human performed a natural cast.
	var payload := SpellSnapshot.new()
	payload.source_id = player.get_instance_id()
	payload.root_id = CombatIds.next_id()
	payload.recipe_id = &"fire_bolt"
	payload.behavior_id = &"fire_bolt"
	payload.damage = 2.0
	payload.direction = Vector2.LEFT
	payload.origin = dummy.hurtbox.global_position + Vector2(64, 0)
	payload.color = Color(1, 0.4, 0.08)
	var context := SpellContext.new(payload)
	var attack_id: int = CombatIds.next_id()
	var health_before: float = dummy.health.current_health
	before = presentation.impact_count
	level.spell_executor.primary_hit(dummy.hurtbox, context, attack_id, payload.direction)
	var accepted: DamageEvent = dummy.last_damage_event
	burst = presentation.impacts.get_child(presentation.impacts.get_child_count() - 1) as ImpactBurst
	_check(accepted.root_event_id == payload.root_id and accepted.source_id == payload.source_id and accepted.attack_id == attack_id and accepted.spell_id == payload.recipe_id and health_before - dummy.health.current_health == payload.damage and presentation.impact_count == before + 1, "Actual accepted spell damage publishes one contact for the current committed root")
	var painted: Sprite2D = burst.get_node_or_null("RenderedCore") as Sprite2D
	var crop: AtlasTexture = painted.texture as AtlasTexture if painted != null else null
	_check(painted != null and painted.visible and painted.modulate.a > 0 and crop != null and crop.atlas == RenderedSpellArt.sheet and crop.atlas.resource_path == RenderedSpellArt.SHEET_PATH and crop.filter_clip and crop.region.position.y >= crop.atlas.get_height() * 0.5 and crop.region.end.y <= crop.atlas.get_height() * 0.75, "Elemental accepted contact binds visible resident PNG contact paint with clipped atlas edges")
	_check(burst.spell_recipe_id == payload.recipe_id and burst.direction == payload.direction and burst.global_position.is_equal_approx(dummy.hurtbox.global_position) and burst._art_layers.size() <= 2 and burst.particles.amount <= 16 and burst.duration <= 0.5, "Painted contact stays at the accepted location and direction within layer, particle and lifetime budgets")
	var painted_owner_id: int = burst.get_instance_id()
	var painted_light_id: int = burst.flash.get_instance_id()
	var painted_sprite_id: int = painted.get_instance_id() if painted != null else 0
	before = presentation.impact_count
	var blocked: DamageResult = dummy.hurtbox.take_damage(accepted)
	level.spell_executor.primary_hit(dummy.hurtbox, context, attack_id, payload.direction)
	_check(blocked.blocked and blocked.block_reason == &"duplicate" and presentation.impact_count == before and health_before - dummy.health.current_health == payload.damage, "Blocked replay and repeated root contact cannot create extra paint or damage")
	before = presentation.impact_count
	var dot: DamageEvent = _damage(dummy.hurtbox, 1.0)
	dot.source_kind = DamageEvent.SourceKind.DOT
	dot.spell_id = &"fire_bolt"
	dummy.hurtbox.take_damage(dot)
	_check(presentation.impact_count == before, "Burn DOT stays silent instead of multiplying shader or particle impacts")
	await _time(0.7)
	_check(presentation.impacts.get_child_count() == 0, "Target contact sparks and lights expire independently of GPU finished")
	_check(not is_instance_id_valid(painted_owner_id) and not is_instance_id_valid(painted_light_id) and not is_instance_id_valid(painted_sprite_id) and RenderedSpellArt.sheet != null and RenderedSpellArt.cells.size() <= 20, "Finite painted contact releases its sprites and light while the bounded atlas remains resident")


func _test_projectile_wake(presentation: SlicePresentation) -> void:
	var payload := SpellSnapshot.new()
	payload.source_id = player.get_instance_id()
	payload.root_id = CombatIds.next_id()
	payload.recipe_id = &"basic"
	payload.behavior_id = &"basic"
	payload.origin = Vector2(500, 140)
	payload.direction = Vector2.RIGHT
	payload.color = Color(0.3, 0.85, 1.0)
	level.spell_executor.spawn_cast(payload)
	presentation._scan()
	var projectile: SpellProjectile = level.spell_executor.get_child(0) as SpellProjectile
	projectile.set_physics_process(false)
	var wake: SpellProjectileVFX = projectile.get_node("SpellTrailVFX") as SpellProjectileVFX
	wake.set_physics_process(false)
	_check(wake != null and wake.get_parent() == projectile and wake.tracked_root_id == payload.root_id, "Projectile cosmetic wake belongs to the exact committed cast")
	_check(wake.particles.amount == 12 and not wake.particles.local_coords and wake.particles.lifetime <= 0.2, "Spell trail uses twelve short-lived world-space GPU particles")
	_check(wake.tint == payload.color and projectile.context.snapshot == payload, "Trail snapshots presentation color without replacing the damage payload")
	var hit_shape: Shape2D = projectile.hitbox._query_shape
	for index: int in 30:
		projectile.global_position += Vector2(8, 0)
		wake._physics_process(1.0 / Engine.physics_ticks_per_second)
	_check(wake.points.size() <= SpellProjectileVFX.MAX_POINTS and wake.line.points.size() > 1, "A moving projectile builds a bounded luminous tail")
	var length: float = 0.0
	for index: int in range(1, wake.points.size()):
		length += wake.points[index].distance_to(wake.points[index - 1])
	_check(length <= SpellProjectileVFX.MAX_TRAIL_LENGTH and wake.line.points[wake.line.points.size() - 1].is_equal_approx(projectile.global_position), "World-space trail ends at the projectile and stays under seventy-two pixels")
	# Set the real feedback latch through its public hit-confirmation path.
	# Writing only remaining time does not make the current physics tick frozen.
	var confirmed := DamageEvent.new()
	confirmed.attack_id = CombatIds.next_id()
	confirmed.root_event_id = confirmed.attack_id
	var confirmed_result := DamageResult.new()
	confirmed_result.actual_damage = 1.0
	level.combat_feedback.hit_stop_seconds = 0.05
	level.combat_feedback.on_hit_confirmed(confirmed, confirmed_result)
	var frozen_points: PackedVector2Array = wake.points.duplicate()
	wake._physics_process(0.03)
	_check(wake.particles.speed_scale == 0 and wake.points == frozen_points, "Projectile motes and wake honor the same local hit-stop as spell movement")
	level.combat_feedback.reset_feedback()
	level.combat_feedback.hit_stop_seconds = 0.0
	wake._physics_process(0.01)
	_check(wake.particles.speed_scale == 1 and projectile.hitbox._query_shape == hit_shape, "Resuming cosmetic particles leaves the projectile hit shape intact")
	var wake_id: int = wake.get_instance_id()
	var particles_id: int = wake.particles.get_instance_id()
	level.spell_executor.clear_entities()
	await _step(3)
	_check(not is_instance_id_valid(wake_id) and not is_instance_id_valid(particles_id) and presentation.projectile_vfx_owners.is_empty(), "Projectile disposal releases its GPU wake and owner registry")


func _test_wall_contacts(presentation: SlicePresentation) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector2(960, 130)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 120)
	collision.shape = shape
	wall.add_child(collision)
	level.add_child(wall)
	await _step(2)
	var before: int = presentation.impact_count
	var payload := SpellSnapshot.new()
	payload.source_id = player.get_instance_id()
	payload.root_id = CombatIds.next_id()
	payload.recipe_id = &"basic"
	payload.behavior_id = &"basic"
	payload.origin = Vector2(920, 130)
	payload.direction = Vector2.RIGHT
	level.spell_executor.spawn_cast(payload)
	await _time(0.15)
	_check(level.spell_executor.get_child_count() == 0 and presentation.impact_count == before + 1, "An actual swept spell collision with stone produces one finite wall impact")
	var impact: ImpactBurst = presentation.impacts.get_child(presentation.impacts.get_child_count() - 1) as ImpactBurst
	_check(impact.element == &"spell_contact" and absf(impact.global_position.x - 960) < 30, "Wall contact particles originate at the physical projectile collision")
	var actor_location: Vector2 = player.global_position
	player.global_position = Vector2(912, 152)
	player.velocity = Vector2.ZERO
	player.aim._has_cursor_event = true
	player.aim._cursor_viewport_position = root.get_canvas_transform() * Vector2(1100, 130)
	var weapon: Weapon = player.equipped_weapon
	weapon.equip(preload("res://data/weapons/ancient_sword.tres"))
	weapon.start_combo()
	weapon.advance(weapon.definition.combo_steps[0].windup_seconds + 0.02)
	before = presentation.impact_count
	presentation._physics_process(0.0)
	presentation._physics_process(0.0)
	_check(presentation.impact_count == before + 1 and weapon.hitbox.active, "Melee probes the authored active shape against stone once per committed swing")
	weapon.cancel_combo()
	player.global_position = actor_location
	wall.queue_free()
	await _time(0.7)
	_check(presentation.impacts.get_child_count() == 0, "Melee and spell wall sparks clean up on the same finite clock")


func _test_budgets_and_cleanup(presentation: SlicePresentation) -> void:
	await _wake_batch(presentation)
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for cycle: int in 4:
		await _wake_batch(presentation)
		if cycle == 0:
			objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			resources = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	print("STRESS combat_polish objects %d -> %d, resources %d -> %d" % [objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)), resources, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
	_check(int(Performance.get_monitor(Performance.OBJECT_COUNT)) == objects and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) == resources, "Repeated trail and spark teardown returns to warmed object and Resource counts")
	for index: int in 32:
		var payload := SpellSnapshot.new()
		payload.source_id = player.get_instance_id()
		payload.root_id = CombatIds.next_id()
		payload.origin = Vector2(500, 140)
		payload.direction = Vector2.RIGHT
		level.spell_executor.spawn_cast(payload)
	presentation._scan()
	_check(presentation.projectile_vfx_owners.size() == SlicePresentation.MAX_PROJECTILE_TRAILS and presentation.light_owners.size() == SlicePresentation.MAX_PROJECTILE_LIGHTS, "Projectile spam caps cosmetic wakes at twenty-four and light owners at twelve independently")
	for index: int in 50:
		presentation.spawn_impact(Vector2(500, 140), Color.WHITE, &"spell_contact")
	_check(presentation.impacts.get_child_count() == SlicePresentation.MAX_IMPACTS and presentation.impacts.get_children().filter(func(burst: ImpactBurst) -> bool: return burst.flash.enabled).size() <= SlicePresentation.MAX_IMPACT_LIGHTS, "Golden/jade spell sparks preserve twenty-four impact and eight flash-light budgets")
	level.spell_executor.clear_entities()
	await _time(0.7)
	_check(presentation.projectile_vfx_owners.is_empty() and presentation.light_owners.is_empty() and presentation.impacts.get_child_count() == 0, "Spam cleanup releases all projectile, trail, impact and light owners")


func _wake_batch(presentation: SlicePresentation) -> void:
	for index: int in 20:
		var payload := SpellSnapshot.new()
		payload.source_id = player.get_instance_id()
		payload.root_id = CombatIds.next_id()
		payload.origin = Vector2(500, 140)
		payload.direction = Vector2.RIGHT
		level.spell_executor.spawn_cast(payload)
	presentation._scan()
	for index: int in 30:
		var burst: ImpactBurst = presentation.spawn_impact(Vector2(500, 140), Color.WHITE, &"spell_contact")
		burst.set_process(false)
		burst._process(0.5)
	level.spell_executor.clear_entities()
	root.get_node("AudioManager").stop_owner(presentation)
	await _step(5)

extends "res://tests/survival_test_base.gd"
## Actual I -> physical projectile contact -> painted contact/field bindings.
## Sprite/resource assertions are not native visual or frame-time acceptance.

const ART = preload("res://scripts/presentation/rendered_spell_art.gd")
var accepted: Dictionary[int, bool] = {}


func _initialize() -> void:
	suite = "rendered_spell_art"
	super._initialize()


func test_system() -> void:
	var warmed_cue: Node2D = level.presentation.cast_cue
	_check(ART.sheet != null and ART.cells.size() == 20 and warmed_cue.get_child_count() == 2 and not warmed_cue.visible, "Room initialization loads finite hidden seal layers before the first combat input")
	session.set_enabled(false)
	player.energy.enabled = false
	player.hurtbox.set_invulnerable(true)
	for enemy: SlimeEnemy in level.enemies:
		enemy.contact_damage_enabled = false
		enemy.global_position = Vector2(1300, 640)
	_check(ART.available(), "Actual imported rendered PNG is available, rather than vector fallback")
	if not ART.available():
		return
	var sheet: Texture2D = ART.sheet
	var crops: Array[AtlasTexture] = ART.cells.duplicate()
	_check(sheet.get_width() == 1402 and sheet.get_height() == 1122 and crops.size() == 20, "Actual 1402x1122 atlas owns exactly twenty resident phase/element crops")
	var valid: bool = true
	for crop: AtlasTexture in crops:
		valid = valid and crop.atlas == sheet and crop.filter_clip and Rect2(Vector2.ZERO, Vector2(sheet.get_width(), sheet.get_height())).encloses(crop.region)
	_check(valid, "All fractional crops stay inside the real sheet and clip neighbouring cells")
	var phases_distinct: bool = true
	for element: StringName in ART.ELEMENTS:
		for stage: int in 4:
			phases_distinct = phases_distinct and ART.cell(stage, element) == crops[stage * 5 + ART.ELEMENTS.find(element)]
	_check(phases_distinct, "Five elements bind their own actual seal, flight, contact and field cells")
	var target: SlimeEnemy = level.enemies[0]
	target.set_physics_process(false)
	target.health.maximum_health = 100000.0
	target.hurtbox.hit_resolved.connect(_record_contact)
	for recipe: StringName in ContentSession.PAIR_IDS:
		await _test_pair(recipe, target)
	await _test_detach_owner_ink()
	level.spell_executor.clear_entities()
	await _step(4)
	_check(ART.sheet == sheet and ART.cells == crops, "Repeated real casts reuse the same sheet and twenty crops without growing a per-cast resource cache")
	_check(level.presentation.projectile_vfx_owners.is_empty() and level.presentation.field_vfx_owners.is_empty(), "Explicit clear releases all rendered projectile/field owners")
	var visual_ids: Array[int] = []
	for visual: Node in level.find_children("Rendered*", "Sprite2D", true, false):
		visual_ids.append(visual.get_instance_id())
	level.queue_free()
	await _step(3)
	var released: bool = true
	for visual_id: int in visual_ids:
		released = released and not is_instance_id_valid(visual_id)
	_check(released and get_nodes_in_group(&"spell_entities").is_empty(), "Room teardown releases all painted layers while keeping only finite resident atlas resources")


func _test_pair(recipe: StringName, target: SlimeEnemy) -> void:
	level.spell_executor.clear_entities()
	await _step(3)
	target.global_position = Vector2(980, 640)
	target.health.reset_health()
	target.statuses.clear()
	player.reset_movement_at(Vector2(680, 640))
	player.action_state_machine.transition_to(&"ready")
	_check(level.content.select_recipe(recipe), "Owned runtime equip resolves " + str(recipe))
	player.resonance_controller.reset_runtime()
	level.combat_feedback.reset_feedback()
	await _step(6)
	var motion := InputEventMouseMotion.new()
	motion.position = player.aim.get_canvas_transform() * target.hurtbox.global_position
	motion.global_position = motion.position
	root.push_input(motion, true)
	await _step(2)
	await _key(KEY_I)
	var state: PlayerCastState = player.action_state_machine.current_state as PlayerCastState
	var root_id: int = state.payload.root_id if state != null and state.payload != null else 0
	var cue: Node2D = level.presentation.cast_cue
	_check(root_id > 0 and cue.visible and cue.root_id == root_id and _painted(cue, ART.CAST, recipe), "Actual windup displays both committed rendered elements for " + str(recipe))
	var projectile: SpellProjectile
	for frame: int in 80:
		projectile = _projectile(root_id)
		if projectile != null:
			break
		await _step(1)
	await _step(1)
	projectile = _projectile(root_id)
	var wake: SpellProjectileVFX = projectile.get_node_or_null("SpellTrailVFX") as SpellProjectileVFX if projectile != null else null
	_check(wake != null and wake.tracked_root_id == root_id and _painted(wake, ART.PROJECTILE, recipe) and projectile.self_modulate.a == 0.0 and wake.get_node("RenderedCore").is_visible_in_tree(), "Travelling painted pair replaces legacy owner ink without hiding its child for " + str(recipe))
	if projectile != null and wake != null:
		var shape: Shape2D = projectile.hitbox._query_shape
		var body: Sprite2D = wake.get_node("RenderedCore") as Sprite2D
		var leading_quad: float = body.position.x + body.texture.get_width() * body.scale.x * 0.5
		_check(shape is CircleShape2D and leading_quad > 0.0 and leading_quad <= (shape as CircleShape2D).radius + 4.0 and body.position.x < -20.0, "Rendered leading quad stays within four pixels of authored collision front; body trails behind " + str(recipe))
		var life: float = projectile._life
		var position_before: Vector2 = projectile.global_position
		wake._sample_owner(0.0)
		wake._sample_owner(0.0)
		_check(is_equal_approx(projectile._life, life) and projectile.global_position == position_before and projectile.hitbox.active and projectile.hitbox._query_shape == shape and shape is CircleShape2D, "Manual art seek preserves the active physical flight clock/position for " + str(recipe))
		if recipe == &"firestorm":
			var event: DamageEvent = _damage(target.hurtbox, 1.0)
			event.source_id = level.get_instance_id() # A live QA owner; enemy aggro resolves the source.
			level.combat_feedback.hit_stop_seconds = 0.08
			var result: DamageResult = target.hurtbox.take_damage(event)
			level.combat_feedback.on_hit_confirmed(event, result)
			var clock: float = wake._clock
			var core: Sprite2D = wake.get_node("RenderedCore") as Sprite2D
			var painted_scale: Vector2 = core.scale
			await _step(2)
			_check(level.combat_feedback.is_frozen() and projectile.global_position == position_before and is_equal_approx(projectile._life, life) and is_equal_approx(wake._clock, clock) and core.scale == painted_scale and wake.particles.speed_scale == 0.0, "Actual accepted-hit hitstop freezes flight, painted body and existing motes together")
			level.combat_feedback.reset_feedback()
			level.combat_feedback.hit_stop_seconds = 0.0
	for frame: int in 120:
		if accepted.has(root_id):
			break
		await _step(1)
	var burst: ImpactBurst
	for child: Node in level.presentation.impacts.get_children():
		if child is ImpactBurst and child.spell_recipe_id == recipe and not child.is_queued_for_deletion():
			burst = child as ImpactBurst
			break
	_check(accepted.has(root_id) and burst != null and _painted(burst, ART.CONTACT, recipe), "Accepted physical damage calls the exact rendered contact pair for " + str(recipe))
	if recipe in [&"firestorm", &"blizzard", &"miasma_cloud"]:
		await _step(3)
		var field: Node2D
		for child: Node in level.spell_executor.get_children():
			if (child is ElementField or child is FirestormEffect) and child.context.snapshot.root_id == root_id:
				field = child as Node2D
				break
		var skin: Node2D = field if field is FirestormEffect else field.get_node_or_null("ElementFieldVFX") as Node2D if field != null else null
		_check(skin != null and _painted(skin, ART.FIELD, recipe), "Secondary effect uses the exact painted field pair for " + str(recipe))
		if skin != null:
			var elapsed: float = field.elapsed if field is FirestormEffect else field.age
			var radius: float = field.context.snapshot.effect_radius
			if field is FirestormEffect: field.refresh_art()
			else: skin.refresh_visual()
			var core: Sprite2D = skin.get_node("RenderedCore") as Sprite2D
			var painted_width: float = core.texture.get_width() * core.scale.x
			_check(absf(painted_width - radius * 2.0) <= radius * 0.055 and is_equal_approx(field.elapsed if field is FirestormEffect else field.age, elapsed), "Painted field scale follows live damage radius without advancing its clock for " + str(recipe))


func _test_detach_owner_ink() -> void:
	level.spell_executor.clear_entities()
	await _step(3)
	level.content.select_recipe(&"fire_bolt")
	player.resonance_controller.reset_runtime()
	var payload: SpellSnapshot = player.resonance_controller.commit_cast()
	payload.origin = Vector2(250, 180)
	payload.direction = Vector2.RIGHT
	level.spell_executor.spawn_cast(payload)
	var projectile: SpellProjectile = _projectile(payload.root_id)
	projectile.self_modulate = Color(0.8, 0.9, 1.0, 0.72)
	await _step(2)
	var wake: SpellProjectileVFX = projectile.get_node("SpellTrailVFX") as SpellProjectileVFX
	var life: float = projectile._life
	var location: Vector2 = projectile.global_position
	projectile.remove_child(wake)
	wake.queue_free()
	_check(projectile.self_modulate == Color(0.8, 0.9, 1.0, 0.72) and projectile.hitbox.active and is_equal_approx(projectile._life, life) and projectile.global_position == location, "Removing only the painted child restores the exact prior owner ink without stopping gameplay flight")
	level.spell_executor.clear_entities()
	await _step(3)


func _painted(owner: Node2D, phase: int, recipe: StringName) -> bool:
	if owner == null:
		return false
	var core: Sprite2D = owner.get_node_or_null("RenderedCore") as Sprite2D
	var echo: Sprite2D = owner.get_node_or_null("RenderedPairEcho") as Sprite2D
	var elements: Array[StringName] = ART.elements_for(recipe)
	return core != null and echo != null and core.visible and echo.visible and core.texture == ART.cell(phase, elements[0]) and echo.texture == ART.cell(phase, elements[1]) and core.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED and core.modulate.a > 0.0 and echo.modulate.a > 0.0


func _projectile(root_id: int) -> SpellProjectile:
	for child: Node in level.spell_executor.get_children():
		if child is SpellProjectile and child.context.snapshot.root_id == root_id and not child.is_queued_for_deletion():
			return child as SpellProjectile
	return null


func _record_contact(event: DamageEvent, result: DamageResult) -> void:
	if not result.blocked and result.actual_damage > 0.0 and event.source_kind == DamageEvent.SourceKind.DIRECT:
		accepted[event.root_event_id] = true

extends "res://tests/survival_test_base.gd"
## Binding, real input/contact, causal ownership and finite clocks. Headless
## assertions do not certify native readability or a natural playthrough.

var accepted_roots: Dictionary[int, bool] = {}


func _initialize() -> void:
	suite = "element_field_readability"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.energy.enabled = false
	player.hurtbox.set_invulnerable(true)
	for enemy: SlimeEnemy in level.enemies:
		enemy.contact_damage_enabled = false
		enemy.global_position = Vector2(1300, 640)
	await _test_cancel_and_blocked()
	await _test_real_cast(&"blizzard")
	await _test_real_cast(&"miasma_cloud")
	await _test_budget_and_room_scope()
	await _test_room_teardown()


func _test_cancel_and_blocked() -> void:
	_check(level.content.select_recipe(&"blizzard"), "Owned QA inventory equips the real Blizzard recipe")
	player.resonance_controller.reset_runtime()
	await _key(KEY_I)
	var cue: Node2D = level.presentation.cast_cue
	_check(cue.visible, "Field cast uses the bound windup cue before release")
	await _key(KEY_SHIFT)
	_check(not cue.visible and level.spell_executor.get_child_count() == 0 and player.resonance_controller.cooldown_remaining() > 0.0, "Cancelling the unreleased field cast hides its cue, spawns no field and retains cooldown")
	await _time(0.6)
	player.resonance_controller.reset_runtime()
	var payload: SpellSnapshot = player.resonance_controller.commit_cast()
	var target: Hurtbox = level.enemies[0].hurtbox
	target.set_invulnerable(true)
	level.spell_executor.primary_hit(target, SpellContext.new(payload), CombatIds.next_id(), Vector2.RIGHT)
	_check(level.spell_executor.get_child_count() == 0, "Blocked primary contact cannot spawn a Blizzard field or field VFX")
	target.set_invulnerable(false)


func _test_real_cast(recipe: StringName) -> void:
	level.spell_executor.clear_entities()
	await _step(2)
	var target: SlimeEnemy = level.enemies[0]
	target.set_physics_process(false)
	target.global_position = Vector2(980, 640)
	target.health.maximum_health = 100000.0
	target.health.reset_health()
	target.statuses.clear()
	if not target.hurtbox.hit_resolved.is_connected(_record_contact):
		target.hurtbox.hit_resolved.connect(_record_contact)
	player.reset_movement_at(Vector2(680, 640))
	player.action_state_machine.transition_to(&"ready")
	_check(level.content.select_recipe(recipe), "Actual inventory/session resolves exact recipe " + str(recipe))
	player.resonance_controller.reset_runtime()
	level.combat_feedback.reset_feedback()
	await _step(8)
	var aim_event := InputEventMouseMotion.new()
	aim_event.position = player.aim.get_canvas_transform() * target.hurtbox.global_position
	aim_event.global_position = aim_event.position
	root.push_input(aim_event, true)
	await _step(2)
	var hp_before: float = target.health.current_health
	await _key(KEY_I)
	_check(level.presentation.cast_cue.visible, "Actual I input enters field windup for " + str(recipe))
	var field: ElementField
	for frame: int in 100:
		field = _first_field()
		if field != null:
			break
		await _step(1)
	_check(field != null and target.health.current_health < hp_before, "Projectile physical accepted contact creates the field for " + str(recipe))
	if field == null:
		return
	await _step(2)
	level.presentation._scan()
	var visual: Node2D = field.get_node_or_null("ElementFieldVFX") as Node2D
	_check(visual != null, "Runtime node-added adapter binds one drawn field child for " + str(recipe))
	if visual == null:
		return
	visual.refresh_visual()
	var payload: SpellSnapshot = field.context.snapshot
	_check(visual.style_id == recipe and visual.tracked_root_id == payload.root_id and accepted_roots.has(payload.root_id), "Field skin follows the root accepted by the physical target for " + str(recipe))
	_check(visual.tint == payload.color and is_equal_approx(visual.radius, payload.effect_radius) and is_equal_approx(visual.elapsed, field.age), "Field tint, radius and motion seek the committed payload and live clock for " + str(recipe))
	var glow: PointLight2D = field.get_node_or_null("ResonanceGlow") as PointLight2D
	_check(glow != null and glow.color == payload.color, "The existing budgeted field light uses the committed color for " + str(recipe))
	_check(visual.find_children("*", "CollisionObject2D", true, false).is_empty() and visual.find_children("*", "PointLight2D", true, false).is_empty() and visual.find_children("*", "GPUParticles2D", true, false).is_empty(), "Field presentation creates no gameplay collider, new light or particle owner for " + str(recipe))
	var age_before: float = field.age
	var hp_after: float = target.health.current_health
	visual.refresh_visual()
	visual.refresh_visual()
	_check(is_equal_approx(field.age, age_before) and is_equal_approx(target.health.current_health, hp_after), "Repeated visual seeking cannot advance the field or deal damage for " + str(recipe))
	var old_tint: Color = visual.tint
	var old_root: int = visual.tracked_root_id
	player.aim._cursor_viewport_position = Vector2.ZERO
	level.content.select_recipe(&"miasma_cloud" if recipe == &"blizzard" else &"blizzard")
	visual.refresh_visual()
	_check(visual.style_id == recipe and visual.tint == old_tint and visual.tracked_root_id == old_root, "Changing loadout and aim cannot retarget an existing field skin for " + str(recipe))
	var hit: DamageEvent = _damage(target.hurtbox, 1.0)
	hit.source_id = level.get_instance_id()
	level.combat_feedback.hit_stop_seconds = 0.08
	var result: DamageResult = target.hurtbox.take_damage(hit)
	level.combat_feedback.on_hit_confirmed(hit, result)
	var frozen_age: float = field.age
	await _step(2)
	visual.refresh_visual()
	_check(level.combat_feedback.is_frozen() and is_equal_approx(field.age, frozen_age) and is_equal_approx(visual.elapsed, frozen_age), "Hitstop freezes field mechanics and drawn motion together for " + str(recipe))
	level.combat_feedback.reset_feedback()
	level.combat_feedback.hit_stop_seconds = 0.0
	var field_id: int = field.get_instance_id()
	var visual_id: int = visual.get_instance_id()
	await _time(payload.effect_duration + 0.2)
	_check(not is_instance_id_valid(field_id) and not is_instance_id_valid(visual_id) and level.presentation.field_vfx_owners.is_empty(), "Authored field lifetime frees its child and owner registry for " + str(recipe))
	target.global_position = Vector2(1300, 640)


func _record_contact(event: DamageEvent, result: DamageResult) -> void:
	if not result.blocked and result.actual_damage > 0.0 and event.source_kind == DamageEvent.SourceKind.DIRECT:
		accepted_roots[event.root_event_id] = true


func _first_field() -> ElementField:
	for child: Node in level.spell_executor.get_children():
		if child is ElementField and not child.is_queued_for_deletion():
			return child as ElementField
	return null


func _fixture_payload() -> SpellSnapshot:
	player.resonance_controller.reset_runtime()
	var payload: SpellSnapshot = player.resonance_controller.commit_cast()
	payload.origin = Vector2(250, 180)
	payload.direction = Vector2.RIGHT
	return payload


func _test_budget_and_room_scope() -> void:
	level.spell_executor.clear_entities()
	await _step(2)
	level.content.select_recipe(&"miasma_cloud")
	for index: int in 4:
		level.spell_executor.spawn_cast(_fixture_payload())
	await _step(1)
	for index: int in 26:
		level.spell_executor.wall_hit(Vector2(250, 180), SpellContext.new(_fixture_payload()))
	await _step(2)
	level.presentation._scan()
	var total: int = level.presentation.projectile_vfx_owners.size() + level.presentation.field_vfx_owners.size()
	_check(total == SlicePresentation.MAX_PROJECTILE_TRAILS and level.presentation.field_vfx_owners.size() < 26, "Projectile wakes and field skins share the existing 24-owner room cap")
	_check(level.presentation.light_owners.size() <= SlicePresentation.MAX_PROJECTILE_LIGHTS and get_nodes_in_group(&"spell_entities").size() <= level.spell_executor.maximum_spell_entities, "Field polish keeps the existing light and gameplay entity caps")
	var outsider := Node2D.new()
	root.add_child(outsider)
	var foreign := ElementField.new()
	foreign.executor = level.spell_executor
	foreign.context = SpellContext.new(_fixture_payload())
	outsider.add_child(foreign)
	foreign.global_position = Vector2(250, 180)
	await _step(2)
	level.presentation._scan()
	_check(not foreign.has_node("ElementFieldVFX") and not foreign.has_node("ResonanceGlow"), "Room adapter cannot bind a foreign field even when it shares the global spell group")
	outsider.queue_free()
	level.spell_executor.clear_entities()
	await _step(3)
	_check(level.presentation.field_vfx_owners.is_empty() and level.presentation.projectile_vfx_owners.is_empty() and level.presentation.light_owners.is_empty(), "Explicit room entity clear releases all drawn field/wake/light registries")


func _test_room_teardown() -> void:
	level.content.select_recipe(&"miasma_cloud")
	level.spell_executor.wall_hit(Vector2(250, 180), SpellContext.new(_fixture_payload()))
	await _step(2)
	var field: ElementField = _first_field()
	var visual: Node = field.get_node("ElementFieldVFX")
	var field_id: int = field.get_instance_id()
	var visual_id: int = visual.get_instance_id()
	level.queue_free()
	await _step(3)
	_check(not is_instance_id_valid(field_id) and not is_instance_id_valid(visual_id) and get_nodes_in_group(&"spell_entities").is_empty(), "Whole-room teardown frees field skins without retaining their causal owners")

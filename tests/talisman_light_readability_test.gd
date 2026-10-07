extends "res://tests/survival_test_base.gd"
## Render-only radial-light suppression preserves real spell and impact owners.

const BOSS: PackedScene = preload("res://scenes/enemies/boss_golem.tscn")
var boss: BossGolem
var presentation: SlicePresentation


func _initialize() -> void:
	suite = "talisman_light_readability"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.controls_enabled = false
	player.energy.enabled = false
	player.set_physics_process(false)
	player.resonance_controller.set_physics_process(false)
	level.gear.set_process(false)
	level.dummy_a.set_physics_process(false)
	level.dummy_b.set_physics_process(false)
	for enemy: SlimeEnemy in level.enemies:
		enemy.contact_damage_enabled = false
	presentation = level.presentation
	var catalyst: Catalyst = player.resonance_controller.catalyst_a
	var original_runes: Array[RuneData] = catalyst.runtime_state.installed_runes.duplicate()
	var original_slots: int = catalyst.runtime_state.opened_slots
	var definition_slots: int = catalyst.definition.initial_slots
	var inventory_uids: Array = level.gear.inventory.items.keys().duplicate()
	boss = BOSS.instantiate() as BossGolem
	boss.ai_enabled = false
	boss.position = Vector2(1050, 640)
	level.add_child(boss)
	boss.set_physics_process(false)
	await _step(3)
	presentation._scan()
	_check(presentation.bound_actors.has(boss.get_instance_id()) and presentation._protected_actor_centers().size() == 2, "Only the live Player and Boss enter the radial light guard")
	await _test_projectile_guard()
	await _test_field_guard()
	await _test_resolved_contacts()
	await _test_spam_and_lifetime()
	catalyst.runtime_state.opened_slots = original_slots
	catalyst.install_runes(original_runes)
	player.resonance_controller.reset_runtime()
	_check(catalyst.runtime_state.installed_runes == original_runes and catalyst.runtime_state.opened_slots == original_slots and catalyst.definition.initial_slots == definition_slots and level.gear.inventory.items.keys() == inventory_uids, "Fixture restores runtime runes and capacity while preserving shared definitions and owned UIDs")


func _commit(recipe: StringName, location: Vector2) -> SpellSnapshot:
	var controller: ResonanceController = player.resonance_controller
	var definition: ResonanceDefinition
	for candidate: ResonanceDefinition in controller.recipes:
		if candidate.id == recipe:
			definition = candidate
			break
	var runes: Array[RuneData] = []
	for rune_id: StringName in definition.recipe_rune_ids:
		for rune: RuneData in GearInventory.RUNES:
			if rune.id == rune_id:
				runes.append(rune)
	var catalyst: Catalyst = controller.catalyst_a
	catalyst.runtime_state.opened_slots = 5
	_check(catalyst.install_runes(runes) and controller.get_recipe() == definition, "Fixture installs the real RuneData multiset for %s" % recipe)
	controller.reset_runtime()
	var payload: SpellSnapshot = controller.commit_cast()
	_check(payload != null and payload.recipe_id == recipe, "Real commit resolves the exact %s recipe" % recipe)
	payload.origin = location
	payload.direction = Vector2.RIGHT
	return payload


func _guard_radius(light: PointLight2D) -> float:
	return float(maxi(light.texture.get_width(), light.texture.get_height())) * light.texture_scale * 0.5 + SlicePresentation.ACTOR_LIGHT_MARGIN


func _test_projectile_guard() -> void:
	var payload: SpellSnapshot = _commit(&"fire_bolt", Vector2(300, 120))
	level.spell_executor.spawn_cast(payload)
	var projectile: SpellProjectile = level.spell_executor.get_child(0) as SpellProjectile
	projectile.set_physics_process(false)
	await _step(1)
	presentation._scan()
	var glow: PointLight2D = projectile.get_node("ResonanceGlow") as PointLight2D
	var shape: Shape2D = projectile.hitbox.collision_shape.shape
	var context: SpellContext = projectile.context
	var lifetime: float = projectile._life
	var cooldown: float = player.resonance_controller.cooldown_remaining()
	_check(shape != null, "The real projectile Hitbox publishes its authored collision shape before the invariant snapshot")
	_check(glow.enabled and is_equal_approx(glow.energy, 1.7) and is_equal_approx(glow.texture_scale, 2.3) and glow.color == payload.color, "Far projectile keeps its committed color and original illumination")
	_check(projectile.material is CanvasItemMaterial and (projectile.material as CanvasItemMaterial).light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "Light suppression preserves Original17 unshaded projectile ink without importing the separate batch framework")
	var radius: float = _guard_radius(glow)
	_check(is_equal_approx(radius, 211.2), "128px projectile radial support plus the 64px body guard determines clearance")
	projectile.global_position = player.hurtbox.global_position + Vector2.LEFT * (radius + 1.0)
	presentation._refresh_spell_lighting()
	_check(glow.enabled, "Projectile light remains enabled beyond its real texture support and body margin")
	projectile.global_position = player.hurtbox.global_position + Vector2.LEFT * (radius - 1.0)
	presentation.scan_remaining = 100.0
	presentation._process(0.0)
	_check(not glow.enabled and is_equal_approx(glow.energy, 1.7), "Per-render refresh suppresses an approaching projectile without waiting for the 80ms scan")
	projectile.global_position = boss.hurtbox.global_position + Vector2(38.6, 0)
	presentation._refresh_spell_lighting()
	_check(not glow.enabled, "The measured 38.6px Boss overlap cannot emit a ResonanceGlow")
	projectile.global_position = Vector2(300, 120)
	presentation._process(0.0)
	_check(glow.enabled and is_equal_approx(glow.energy, 1.7) and glow.color == payload.color, "Moving clear of both actors restores the same far-field glow")
	for index: int in 100:
		presentation._refresh_spell_lighting()
	_check(projectile.context == context and projectile.context.snapshot == payload and projectile.hitbox.collision_shape.shape == shape and projectile.hitbox.active and projectile._life == lifetime and player.resonance_controller.cooldown_remaining() == cooldown, "Repeated cosmetic refresh leaves committed context, collider, hitbox, lifetime and cooldown unchanged")
	glow.scale = Vector2(2.0, 0.5)
	projectile.global_position = player.hurtbox.global_position + Vector2.LEFT * (radius + 50.0)
	presentation._refresh_spell_lighting()
	_check(not glow.enabled, "Texture support also covers a widened cosmetic light transform")
	glow.scale = Vector2.ONE
	glow.transform = Transform2D(Vector2(1, 0), Vector2(2, 1), Vector2.ZERO)
	var sheared_radius: float = (1.0 + sqrt(2.0)) * float(glow.texture.get_width()) * glow.texture_scale * 0.5 + SlicePresentation.ACTOR_LIGHT_MARGIN
	projectile.global_position = player.hurtbox.global_position + Vector2.LEFT * (sheared_radius - 1.0)
	presentation._refresh_spell_lighting()
	_check(not glow.enabled, "A sheared radial light is suppressed at the exact singular-value support beyond either basis length")
	projectile.global_position = player.hurtbox.global_position + Vector2.LEFT * (sheared_radius + 1.0)
	presentation._refresh_spell_lighting()
	_check(glow.enabled, "Sheared light remains enabled just beyond its exact radial support and body margin")
	glow.transform = Transform2D.IDENTITY
	level.spell_executor.clear_entities()
	await _step(3)
	_check(presentation.light_owners.is_empty() and presentation.projectile_vfx_owners.is_empty(), "Projectile teardown releases all light and trail registry entries")


func _test_field_guard() -> void:
	var payload: SpellSnapshot = _commit(&"firestorm", Vector2(300, 120))
	level.spell_executor.wall_hit(payload.origin, SpellContext.new(payload))
	var field: FirestormEffect = level.spell_executor.get_child(0) as FirestormEffect
	field.set_physics_process(false)
	await _step(2)
	presentation._scan()
	var glow: PointLight2D = field.get_node("ResonanceGlow") as PointLight2D
	var context: SpellContext = field.context
	var elapsed: float = field.elapsed
	_check(glow.enabled and is_equal_approx(glow.texture_scale, 3.5) and is_equal_approx(glow.energy, 1.7), "Far committed Firestorm keeps its original field light")
	_check(is_equal_approx(_guard_radius(glow), 288.0), "Field clearance includes its 224px radial support rather than a fixed 180px cutoff")
	field.global_position = player.hurtbox.global_position + Vector2.LEFT * 250.0
	presentation._process(0.0)
	_check(not glow.enabled, "A field 250px from the Player is suppressed because its radial support reaches the body")
	field.global_position = Vector2(300, 120)
	presentation._process(0.0)
	_check(glow.enabled and field.context == context and field.elapsed == elapsed and field.context.snapshot == payload and field.is_in_group(&"spell_entities"), "Restoring far-field light preserves the Firestorm gameplay owner and clock")
	level.spell_executor.clear_entities()
	await _step(3)
	presentation.rebuild()
	await _step(2)


func _test_resolved_contacts() -> void:
	var payload: SpellSnapshot = _commit(&"fire_bolt", boss.hurtbox.global_position)
	var hp: float = boss.health.current_health
	var before: int = presentation.impact_count
	level.spell_executor.primary_hit(boss.hurtbox, SpellContext.new(payload), CombatIds.next_id(), Vector2.RIGHT)
	var second: SpellSnapshot = _commit(&"fire_bolt", boss.hurtbox.global_position)
	level.spell_executor.primary_hit(boss.hurtbox, SpellContext.new(second), CombatIds.next_id(), Vector2.RIGHT)
	_check(boss.health.current_health == hp - payload.damage - second.damage and presentation.impact_count == before + 2, "Two real accepted spell hits retain their authored damage and impact callbacks")
	var contact: ImpactBurst = presentation.impacts.get_child(presentation.impacts.get_child_count() - 1) as ImpactBurst
	var previous: ImpactBurst = presentation.impacts.get_child(presentation.impacts.get_child_count() - 2) as ImpactBurst
	_check(not contact.flash.enabled and not previous.flash.enabled, "Both coincident Boss contact lights are suppressed immediately at spawn")
	_check(is_equal_approx(contact.flash.energy, contact.peak_light_energy) and contact.remaining == contact.duration and contact.particles.amount > 0 and (contact.material as CanvasItemMaterial).light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "Suppression preserves finite impact ink, particle owner and authored fade clock")
	contact._process(0.01)
	presentation._refresh_spell_lighting()
	_check(not contact.flash.enabled and contact.flash.energy > 0.0 and contact.remaining < contact.duration, "Impact energy fade cannot re-enable a spatially suppressed light")
	var player_impact: ImpactBurst = presentation.spawn_impact(player.hurtbox.global_position, Color.WHITE, &"spell_contact")
	_check(not player_impact.flash.enabled, "The same spawn guard protects the Player body")
	await _time(0.7)
	_check(presentation.impacts.get_child_count() == 0, "Suppressed contact owners still expire on their finite clock")


func _test_spam_and_lifetime() -> void:
	var previous_hz: int = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 120
	for index: int in 40:
		var payload: SpellSnapshot = _commit(&"fire_bolt", Vector2(300, 120))
		level.spell_executor.spawn_cast(payload)
		level.spell_executor.get_child(level.spell_executor.get_child_count() - 1).set_physics_process(false)
	presentation._scan()
	_check(level.spell_executor.get_child_count() == 40 and presentation.light_owners.size() == SlicePresentation.MAX_PROJECTILE_LIGHTS and presentation.projectile_vfx_owners.size() == SlicePresentation.MAX_PROJECTILE_TRAILS, "120Hz spell pressure retains forty gameplay owners within the existing twelve light and twenty-four trail caps")
	for index: int in 100:
		presentation.spawn_impact(Vector2(150, 100), Color.WHITE, &"physical")
	var live: int = presentation.impacts.get_children().filter(func(burst: ImpactBurst) -> bool: return burst.flash.enabled).size()
	_check(presentation.impacts.get_child_count() == SlicePresentation.MAX_IMPACTS and live == SlicePresentation.MAX_IMPACT_LIGHTS, "Far impact pressure retains twenty-four owners and at most eight enabled flashes")
	var budgeted: ImpactBurst = presentation.impacts.get_child(0) as ImpactBurst
	_check(not budgeted.flash.enabled, "The oldest retained impact has already exhausted its light budget")
	var original_player_position: Vector2 = player.global_position
	player.global_position += Vector2(150, 100) - player.hurtbox.global_position
	presentation.scan_remaining = 100.0
	presentation._process(0.0)
	_check(presentation.impacts.get_children().all(func(burst: ImpactBurst) -> bool: return not burst.flash.enabled), "Per-render actor movement suppresses every overlapping impact before the next scan")
	player.global_position = original_player_position
	presentation._process(0.0)
	_check(not budgeted.flash.enabled and presentation.impacts.get_children().all(func(burst: ImpactBurst) -> bool: return not burst.flash.enabled), "Neither actor departure nor refresh resurrects a budgeted or suppressed impact light")
	level.spell_executor.clear_entities()
	presentation.rebuild()
	await _step(3)
	_check(presentation.light_owners.is_empty() and presentation.projectile_vfx_owners.is_empty() and presentation.impacts.get_child_count() == 0, "Entity clear and room rebuild release every spell, trail and impact light owner")
	var boss_id: int = boss.get_instance_id()
	boss.queue_free()
	await _step(3)
	_check(not presentation.bound_actors.has(boss_id) and presentation._protected_actor_centers().size() == 1, "Boss disposal removes its spatial guard without retaining a freed actor")
	Engine.physics_ticks_per_second = previous_hz

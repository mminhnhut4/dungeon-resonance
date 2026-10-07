extends "res://tests/survival_test_base.gd"
## Actual equipped quality/runes, immutable commits and finite cosmetic owners.


func _initialize() -> void:
	suite = "combat_visuals"
	use_neutral_equipment = false
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.controls_enabled = false
	player.set_physics_process(false)
	player.energy.enabled = false
	var gear: GearSession = level.gear
	var weapon: Weapon = player.equipped_weapon
	var trail: WeaponTrail = level.presentation.trail
	var body: CollisionShape2D = player.get_node("BodyCollision")
	var body_shape: Shape2D = body.shape
	var body_transform: Transform2D = body.transform
	var hurt_shape: Shape2D = player.hurtbox.get_node("CollisionShape2D").shape
	var socket_transform: Transform2D = weapon.get_parent().transform
	var owned: GearItem = gear.inventory.items[gear.inventory.equipped_weapon_uid]
	_check(player.health.maximum_health == 115.0 and weapon.visual_quality == GearItem.Quality.COMMON, "Product starter stats and Common visual grade reach the real Weapon")
	for quality: int in range(6):
		owned.quality = quality
		gear.sync_quality()
		weapon.start_combo()
		var step: AttackStepDefinition = weapon.definition.combo_steps[0]
		trail.refresh_visual()
		_check(weapon.snapshot.cosmetic_quality == quality and trail.committed_quality == quality, "Quality %d captures the equipped runtime grade at attack commit" % quality)
		_check(trail.art_enabled and trail.slash_sprite.texture is AtlasTexture and trail.slash_sprite.texture.resource_path == WeaponTrail.SLASH_PATHS[quality], "Quality %d selects its distinct approved 512px AtlasTexture cell" % quality)
		_check(not trail.slash_sprite.visible and not weapon.hitbox.active, "Quality %d does not show its painted slash or hitbox during wind-up" % quality)
		weapon.advance(step.windup_seconds + step.active_seconds * 0.5)
		trail.refresh_visual()
		_check(trail.slash_sprite.visible and weapon.hitbox.active and float(trail._material.get_shader_parameter("opacity")) == 0.0 and float(trail._crescent_material.get_shader_parameter("opacity")) == 0.0 and trail.crescent_ink.self_modulate.a == 0.0, "Quality %d renders one art slash without a second bright mesh or ink pass" % quality)
		_check(trail.get_children().filter(func(child: Node) -> bool: return child is Light2D).size() == 1 and trail.blade_light.enabled == (quality >= GearItem.Quality.RARE) and trail.get_children().all(func(child: Node) -> bool: return not child is GPUParticles2D), "Quality %d keeps one tiny owned blade light, disabled for a plain Common sword, with no slash particle spam" % quality)
		weapon.cancel_combo()
	owned.quality = GearItem.Quality.COMMON
	gear.sync_quality()
	_test_committed_elements(gear, weapon, trail, owned)
	_test_combo_sweep(weapon, trail)
	_check(body.shape == body_shape and body.transform.is_equal_approx(body_transform) and player.hurtbox.get_node("CollisionShape2D").shape == hurt_shape and weapon.get_parent().transform.is_equal_approx(socket_transform), "Every art grade, rune and combo retains BodyCollision, Hurtbox and WeaponSocket")
	await _test_contacts_and_lifetime(level.presentation, weapon, trail)
	weapon.cancel_combo()
	trail.bind(null)
	_check(trail._snapshot == null and trail.slash_sprite.texture == null and not trail.slash_sprite.visible, "Unbinding releases the committed art texture and snapshot immediately")
	trail.bind(weapon)


func _test_committed_elements(gear: GearSession, weapon: Weapon, trail: WeaponTrail, owned: GearItem) -> void:
	for element: StringName in [&"fire", &"wind", &"lightning", &"ice", &"poison"]:
		gear.inventory.add_rune(element)
		gear.inventory.equip(3, element)
		weapon.start_combo()
		var committed: AttackSnapshot = weapon.snapshot
		var step: AttackStepDefinition = weapon.definition.combo_steps[0]
		weapon.advance(step.windup_seconds + step.active_seconds * 0.5)
		trail.refresh_visual()
		_check(committed.cosmetic_element == element and committed.cosmetic_tint == AttackSnapshot.tint_for_element(element) and trail.tint == committed.cosmetic_tint and trail.blade_light.enabled and trail.blade_light.color == committed.cosmetic_tint, "%s slash/light hue comes from the committed rune, including chain-only Lightning" % element)
		var texture: Texture2D = trail.slash_sprite.texture
		var transform: Transform2D = trail.slash_sprite.transform
		var progress: float = trail.art_progress
		var query: Shape2D = weapon.hitbox._query_shape
		var hit_transform: Transform2D = weapon.hitbox.global_transform
		gear.inventory.equip(3, &"")
		owned.quality = GearItem.Quality.DIVINE
		gear.sync_quality()
		player.aim._has_cursor_event = true
		player.aim._cursor_viewport_position = Vector2.ZERO
		player.aim.sample_cursor()
		trail.refresh_visual()
		_check(weapon.snapshot == committed and committed.cosmetic_quality == GearItem.Quality.COMMON and trail.slash_sprite.texture == texture and trail.tint == committed.cosmetic_tint, "%s in-flight art survives rune removal and quality changes without recoloring" % element)
		_check(trail.slash_sprite.transform.is_equal_approx(transform) and trail.art_progress == progress and weapon.hitbox._query_shape == query and weapon.hitbox.global_transform.is_equal_approx(hit_transform), "%s hit-stop clock freezes both art pose and original query shape/aim" % element)
		weapon.cancel_combo()
		owned.quality = GearItem.Quality.COMMON
		gear.sync_quality()
	weapon.start_combo()
	_check(weapon.snapshot.cosmetic_element == &"physical" and weapon.snapshot.cosmetic_quality == GearItem.Quality.COMMON, "The next committed attack uses the now-empty rune slot and restored Common grade")
	weapon.cancel_combo()


func _test_combo_sweep(weapon: Weapon, trail: WeaponTrail) -> void:
	weapon.start_combo()
	for combo: int in range(3):
		var step: AttackStepDefinition = weapon.definition.combo_steps[combo]
		weapon.advance(step.windup_seconds + 0.06)
		trail.refresh_visual()
		_check(trail.art_sweep_degrees == WeaponTrail.COMBO_SWEEP_DEGREES[combo] and trail.slash_sprite.flip_v == (combo == 1) and absf(trail.slash_sprite.rotation) < 0.001, "Combo %d follows its 100/130/160-degree cosine arc and alternates the second sweep" % (combo + 1))
		if combo < 2:
			weapon.advance(step.active_seconds - 0.06 + step.recovery_seconds)
			weapon.request_next()
	weapon.cancel_combo()
	_check(not trail.slash_sprite.visible and trail.slash_sprite.texture == null and not trail.blade_light.enabled and not weapon.hitbox.active, "Combo cancellation retires painted art, blade light and existing damage window together")
	weapon.equip(preload("res://data/weapons/shadow_dagger.tres"))
	weapon.start_combo()
	weapon.advance(weapon.definition.combo_steps[0].windup_seconds + 0.02)
	trail.refresh_visual()
	_check(not trail.art_enabled and trail.ribbon.visible and trail.vertex_count == 66, "A short thrust keeps its authored mesh fallback instead of becoming a sweeping sword slash")
	weapon.cancel_combo()
	weapon.equip(preload("res://data/weapons/ancient_sword.tres"))


func _test_contacts_and_lifetime(presentation: SlicePresentation, weapon: Weapon, trail: WeaponTrail) -> void:
	var dummy: TrainingDummy = level.dummy_a
	weapon.visual_quality = GearItem.Quality.LEGENDARY
	weapon.installed_rune = preload("res://data/runes/LightningRune.tres")
	weapon.start_combo()
	var committed: AttackSnapshot = weapon.snapshot
	weapon._on_contact(dummy.hurtbox, committed)
	_check(dummy.last_damage_event.cosmetic_quality == GearItem.Quality.LEGENDARY and dummy.last_damage_event.cosmetic_element == &"lightning" and dummy.last_damage_event.cosmetic_tint == committed.cosmetic_tint, "DamageEvent carries the same committed grade/Lightning hue used by the slash")
	var live_contact: ImpactBurst = presentation.impacts.get_child(presentation.impacts.get_child_count() - 1) as ImpactBurst
	_check(live_contact.cosmetic_quality == GearItem.Quality.LEGENDARY and live_contact.element == &"lightning" and live_contact.tint == committed.cosmetic_tint, "The real SlicePresentation adapter uses the committed grade/element for contact, including chain-only Lightning")
	weapon.cancel_combo()
	weapon.installed_rune = null
	weapon.visual_quality = GearItem.Quality.COMMON
	for quality: int in [GearItem.Quality.COMMON, GearItem.Quality.DIVINE]:
		var burst: ImpactBurst = presentation.spawn_impact(Vector2(520, 610), Color.WHITE, &"physical", Vector2.RIGHT)
		burst.configure_combat(quality, quality == GearItem.Quality.DIVINE)
		burst.enable_melee_sparks()
		var behavior: ParticleProcessMaterial = burst.particles.process_material
		_check(burst.particles.amount == (10 if quality == GearItem.Quality.COMMON else 14) and behavior.spread <= 48.0 and behavior.direction.x < 0.0, "Quality %d impact stays a narrow directional fan of 10–14 mineral sparks" % quality)
		_check(is_equal_approx(behavior.scale_min * burst.particles.texture.get_width(), 3.0) and is_equal_approx(behavior.scale_max * burst.particles.texture.get_width(), 7.0), "Quality %d normalizes the large art cell to readable 3–7px sparks" % quality)
		_check(burst.particles.texture is AtlasTexture and burst.particles.texture.resource_path == ImpactBurst.MINERAL_SPARK_PATH and not burst.particles.emitting, "Quality %d uses the approved diamond spark texture with no headless GPU emission" % quality)
		_check(burst.get_children().all(func(child: Node) -> bool: return not child is Sprite2D and not child is CollisionObject2D), "Quality %d impact introduces no paper/leaves/debris sprites or collision" % quality)
	await _time(0.7)
	_check(presentation.impacts.get_child_count() == 0, "All contacts expire on the finite owner clock without waiting for GPU completion")
	for index: int in range(50):
		presentation.spawn_impact(Vector2(520, 610), Color.WHITE, &"physical")
	_check(presentation.impacts.get_child_count() == 24 and presentation.impacts.get_children().filter(func(burst: ImpactBurst) -> bool: return burst.flash.enabled).size() <= 8, "Spam keeps the existing 24 owners and eight live impact-light budgets")
	await _time(0.7)
	_check(presentation.impacts.get_child_count() == 0 and not trail.slash_sprite.visible, "Spam teardown releases every impact owner and retains no active slash")
	var common_finisher: ImpactBurst = presentation.spawn_impact(Vector2(520, 610), Color.WHITE, &"physical", Vector2.RIGHT)
	common_finisher.configure_combat(GearItem.Quality.COMMON, true, 2)
	common_finisher.enable_melee_sparks()
	_check(common_finisher.ground_crack == null and common_finisher.shockwave == null and common_finisher.particles.amount == 10, "A Common critical finisher stays basic and never promotes itself into Epic effects")
	var finisher: ImpactBurst = presentation.spawn_impact(Vector2(520, 610), Color.WHITE, &"physical", Vector2.RIGHT)
	finisher.configure_combat(GearItem.Quality.EPIC, false, 2)
	finisher.enable_melee_sparks()
	finisher.set_process(false)
	var finisher_id: int = finisher.get_instance_id()
	var decal_id: int = finisher.ground_crack.get_instance_id()
	var warp_id: int = finisher.shockwave.get_instance_id()
	_check(finisher.ground_crack.texture.resource_path == ImpactBurst.GROUND_CRACK_PATH and finisher.duration == 1.0 and (finisher.shockwave.mesh as QuadMesh).size == Vector2(96, 96), "An Epic third-hit contact owns one small painted mineral decal and localized 96px warp")
	finisher._process(0.13)
	_check(not finisher.shockwave.visible and finisher.ground_crack.modulate.a > 0.0 and finisher.remaining > 0.0, "The localized shockwave expires after 0.12s while its ground mark keeps fading")
	finisher._process(0.4)
	_check(finisher.flash.energy == 0.0 and finisher.ground_crack.modulate.a > 0.0, "A fading decal does not extend its hit spark or impact light beyond 0.48s")
	finisher._process(0.5)
	await _step(3)
	_check(not is_instance_id_valid(finisher_id) and not is_instance_id_valid(decal_id) and not is_instance_id_valid(warp_id), "The one-second finisher owner releases its decal, localized shader and mesh together")

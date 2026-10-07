extends "res://tests/survival_test_base.gd"
## Real live status clocks, actor-local materials, finite particles and RPG feedback.


func _init() -> void:
	suite = "affliction_visuals"
	use_neutral_equipment = false


func test_system() -> void:
	var visual: ElementAfflictionVFX = player.get_node_or_null("ElementAfflictionVFX") as ElementAfflictionVFX
	_check(visual != null, "Player presentation mounts live affliction adapter")
	if visual == null:
		return
	var status: ElementStatusController = player.hurtbox.damage_resolver.status_controller as ElementStatusController
	var rig: PlayerVisualRig = player.get_node("Visuals") as PlayerVisualRig
	_check(visual.burn.amount == 9 and visual.poison.amount == 7, "Two persistent GPU emitters have bounded 9/7 particles")
	_check(visual.burn.texture is AtlasTexture and visual.poison.texture is AtlasTexture, "Burn and poison use approved transparent atlas regions")
	_check(visual.burn.texture != visual.poison.texture and visual.burn.texture.get_height() > 100, "Distinct painted flame and mist stamps are loaded")
	_check(not visual.burn_visible and not visual.poison_visible, "Healthy starter kit has no condition aura")
	_check(visual.material_count > 0 and visual._materials.has(rig._modular_material), "One actor-local material covers every body/clothing segment")
	var geometry: Transform2D = player.get_node("BodyCollision").transform
	var hurt_geometry: Transform2D = player.hurtbox.transform
	var hp: float = player.health.current_health
	var fire: DamageEvent = _damage(player.hurtbox, 1.0)
	fire.burn_damage = 1.0
	fire.burn_duration = 0.9
	fire.burn_interval = 0.25
	var result: DamageResult = player.hurtbox.take_damage(fire)
	_check(not result.blocked and status.burn_remaining > 0.0, "Resolved real damage applies burn through the original status pipeline")
	visual.refresh_visual()
	_check(visual.burn_visible and not visual.poison_visible, "Burn immediately enables only orange flame presentation")
	_check(is_equal_approx(float(rig._modular_material.get_shader_parameter("status_strength")), 0.2), "Burn adds restrained material tint independently of hit flash")
	_check(not bool(rig._modular_material.get_shader_parameter("active")) and float(rig._modular_material.get_shader_parameter("flash")) > 0.0 and float(rig._modular_material.get_shader_parameter("flash")) <= 0.25, "Bounded all-part contact tint preserves condition color and texture detail")
	_check(player.health.current_health < hp and player.health.current_health > hp - 1.0, "Starter armor still resolves direct damage exactly once")
	var poison_hit: DamageEvent = _damage(player.hurtbox, 1.0)
	poison_hit.poison_stacks = 2
	poison_hit.poison_seconds = 0.9
	poison_hit.poison_percent = 0.005
	player.hurtbox.set_invulnerable(false)
	player.damage_grace_remaining = 0.0
	player.hurtbox.take_damage(poison_hit)
	visual.refresh_visual()
	_check(visual.poison_visible and visual.burn_visible, "Poison and burn coexist without replacing either gameplay clock")
	_check(status.poison_count == 2, "Visual adapter does not invent additional poison stacks")
	var burn_clock: float = status.burn_remaining
	var poison_clock: float = status.poison_remaining
	var hp_after: float = player.health.current_health
	for repeat: int in 15:
		visual.refresh_visual()
	_check(is_equal_approx(status.burn_remaining, burn_clock) and is_equal_approx(status.poison_remaining, poison_clock), "Refreshing presentation never advances authoritative status clocks")
	_check(is_equal_approx(player.health.current_health, hp_after), "Refreshing presentation never applies duplicate DOT")
	var materials_before: int = visual.material_count
	rig.set_modular_skin(rig.modular_skin)
	await _step(4)
	_check(visual._materials.has(rig._modular_material) and visual.material_count == materials_before, "Skin remount rebinds condition tint to new actor-local material")
	_check(visual.burn_visible and visual.poison_visible, "Changing skin preserves live burn/poison states")
	_check(player.get_node("BodyCollision").transform == geometry and player.hurtbox.transform == hurt_geometry, "Affliction visuals do not alter collision transforms")
	level.combat_feedback.hit_stop_remaining = 0.04
	level.combat_feedback._frozen_this_tick = true
	visual.refresh_visual()
	_check(visual.burn.speed_scale == 0.0 and visual.poison.speed_scale == 0.0, "Hit-stop freezes both condition particle simulations")
	level.combat_feedback.reset_feedback()
	visual.refresh_visual()
	_check(visual.burn.speed_scale == 1.0 and visual.poison.speed_scale == 1.0, "Particle simulations resume after hit-stop")
	await _time(1.1)
	visual.refresh_visual()
	_check(not visual.burn_visible and not visual.poison_visible and status.poison_count == 0, "Both visual conditions end with the real finite status clocks")
	_check(float(rig._modular_material.get_shader_parameter("status_strength")) == 0.0, "Expired status restores the original outfit palette")
	_check(not visual.burn.emitting and not visual.poison.emitting, "Expired and headless emitters are not left running")
	var child_count: int = visual.get_child_count()
	var objects_before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_before: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for cycle: int in 12:
		status.apply(fire)
		status.apply(poison_hit)
		visual.refresh_visual()
		status.clear()
		visual.refresh_visual()
		await _step(1)
	_check(visual.get_child_count() == child_count and child_count == 2, "Repeated conditions reuse the same two finite emitters")
	_check(int(Performance.get_monitor(Performance.OBJECT_COUNT)) <= objects_before, "Repeated burn/poison leave no retained objects after warm-up")
	_check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= resources_before, "Repeated burn/poison leave no retained resources after warm-up")
	print("STRESS: affliction objects=%d->%d resources=%d->%d" % [objects_before, int(Performance.get_monitor(Performance.OBJECT_COUNT)), resources_before, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
	var atmosphere: DungeonAtmosphere = level.presentation.atmosphere
	_check(atmosphere.quiet_motes.amount == 5, "Quiet idle dust adds only five subdued particles")
	_check(atmosphere.vignette_layer.layer == 1 and atmosphere.vignette_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Vignette affects world corners without intercepting UI input")
	_check(atmosphere.glow_environment.environment.background_canvas_max_layer == 0 and atmosphere.glow_environment.environment.glow_hdr_threshold < 1.0, "Compatibility SDR glow stays below UI CanvasLayers")
	_check(is_equal_approx(atmosphere.player_mote.texture.get_width() * atmosphere.player_mote.texture_scale * 0.5, 160.0), "Soft player light has approximately 160px radius")
	var text: FloatingCombatText = preload("res://scenes/effects/floating_combat_text.tscn").instantiate() as FloatingCombatText
	level.add_child(text)
	text.setup(12.0, Vector2.RIGHT, level.combat_feedback)
	_check(text.label.text == "12" and text.scale == Vector2(1.4, 1.4), "Normal damage text pops in at 1.4 scale")
	_check(text.label.get_theme_font_size("font_size") == 18 and text.label.get_theme_constant("outline_size") == 4, "Normal damage uses compact silver type and dark outline")
	text.setup(25.0, Vector2.LEFT, level.combat_feedback, true)
	_check(text.label.text == "25!" and text.label.get_theme_font_size("font_size") == 29, "Critical damage has roughly 1.6x type and an accent")
	_check(text.label.get_theme_color("font_outline_color").r > 0.4, "Critical damage has a warm red outline")
	await _time(0.7)
	_check(not is_instance_valid(text), "Stylized damage text keeps its finite lifetime")
	player.health.apply_damage(999.0)
	visual.refresh_visual()
	_check(not visual.burn_visible and not visual.poison_visible, "Death cancels both condition presentations")

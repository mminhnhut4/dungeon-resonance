extends "res://tests/survival_test_base.gd"
## Integration gates: cosmetic listeners, budgets, rune snapshots and scene lifetime.

func _initialize() -> void:
	suite = "polish"
	super._initialize()

func test_system() -> void:
	var presentation: SlicePresentation = level.presentation
	var audio: Node = root.get_node("AudioManager")
	var atmosphere: DungeonAtmosphere = presentation.atmosphere
	_check(atmosphere.ambient.color.b > atmosphere.ambient.color.r and atmosphere.ambient.color.r < 0.5, "World ambient is a dark blue-purple CanvasModulate")
	_check(atmosphere.glow_environment.environment.glow_enabled and atmosphere.glow_environment.environment.background_mode == Environment.BG_CANVAS, "World canvas has real SDR glow in the Compatibility renderer")
	_check(atmosphere.glow_environment.environment.background_canvas_max_layer == 0 and atmosphere.glow_environment.environment.glow_hdr_threshold < 1.0, "Glow excludes UI CanvasLayers and uses an SDR threshold")
	_check(atmosphere.torches.size() == 4 and atmosphere.player_mote.texture != null, "Room has four warm torches and an independent Player light")
	_check(atmosphere.dust is GPUParticles2D and atmosphere.dust.amount == 72, "Ambient ash owns a bounded GPU particle emitter")
	_check(not atmosphere.dust.emitting, "Headless fixture does not wait on GPU simulation")
	_check(DungeonAtmosphere.TORCH.get_frame_count(&"burn") == 4 and DungeonAtmosphere.TORCH.get_animation_loop(&"burn"), "PNG torch SpriteFrames contains four looping frames")
	_check(player.body_sprite.texture.resource_path.ends_with(".png"), "Player Sprite2D loads a standard PNG without Aseprite")
	_check(presentation.bound_actors.size() == 5, "Presentation binds Player, two dummies and two Slimes once")
	var before_count: int = presentation.bound_actors.size()
	for attempt: int in 5:
		presentation._scan()
	_check(presentation.bound_actors.size() == before_count, "Repeated scans do not duplicate actor listeners")
	var before: int = presentation.impact_count
	var dummy: TrainingDummy = level.dummy_a
	var event: DamageEvent = _damage(dummy.hurtbox, 7)
	event.burn_damage = 2
	event.burn_duration = 1
	var result: DamageResult = dummy.hurtbox.take_damage(event)
	_check(result.actual_damage == 7 and presentation.impact_count == before + 1, "Resolved fire hit produces one VFX without changing damage")
	var impact: ImpactBurst = presentation.impacts.get_child(0) as ImpactBurst
	_check(impact.element == &"fire" and impact.flash.color == Color(1, 0.4, 0.08), "Impact tint follows DamageEvent fire payload")
	before = presentation.impact_count
	dummy.hurtbox.take_damage(event)
	_check(presentation.impact_count == before, "Blocked duplicate damage cannot repeat hit flash or sound")
	var dot: DamageEvent = _damage(dummy.hurtbox, 1)
	dot.source_kind = DamageEvent.SourceKind.DOT
	dummy.hurtbox.take_damage(dot)
	_check(presentation.impact_count == before, "DOT applies damage without repeated impact/audio bursts")
	for element: StringName in [&"ice", &"poison", &"lightning"]:
		var elemental: DamageEvent = _damage(dummy.hurtbox, 1)
		if element == &"ice":
			elemental.freeze_points = 10
		elif element == &"poison":
			elemental.poison_stacks = 1
		else:
			elemental.stun_seconds = 0.1
		dummy.hurtbox.take_damage(elemental)
		_check((presentation.impacts.get_child(presentation.impacts.get_child_count() - 1) as ImpactBurst).element == element, "Resolved %s payload selects its own particle style" % element)
	level.combat_feedback.hit_stop_seconds = 0.05
	level.combat_feedback.on_hit_confirmed(event, result)
	_check(level.combat_feedback.hit_stop_remaining == 0.05 and presentation.impacts.get_child_count() > 0, "Impact coexists with the original 50ms hit-stop and camera shake")
	level.combat_feedback.reset_feedback()
	level.combat_feedback.hit_stop_seconds = 0
	await _time(0.7)
	_check(presentation.impacts.get_child_count() == 0, "Finite impacts expire without waiting for GPU finished signal")
	for index: int in 100:
		presentation.spawn_impact(Vector2(500, 500), Color.WHITE, &"physical")
	_check(presentation.impacts.get_child_count() == SlicePresentation.MAX_IMPACTS, "A burst of hits obeys the twenty-four impact budget")
	_check(presentation.impacts.get_children().filter(func(burst: ImpactBurst) -> bool: return burst.flash.enabled).size() <= SlicePresentation.MAX_IMPACT_LIGHTS, "Particle spam retains at most eight lit impact flashes")
	await _time(0.7)
	_check(presentation.impacts.get_child_count() == 0, "Budgeted VFX burst releases every Node and light")
	player.energy.enabled = false
	level.set_rune_preset(0)
	player.resonance_controller.reset_runtime()
	var spell: SpellSnapshot = player.resonance_controller.commit_cast()
	spell.origin = Vector2(520, 230)
	spell.direction = Vector2.RIGHT
	level.spell_executor.spawn_cast(spell)
	presentation._scan()
	_check(presentation.light_owners.size() == 1, "Firestorm projectile owns a spatial PointLight2D")
	var projectile: SpellProjectile = level.spell_executor.get_child(0) as SpellProjectile
	var glow: PointLight2D = projectile.get_node("ResonanceGlow") as PointLight2D
	_check(glow.color == spell.color and glow.energy > 1, "Projectile glow uses the committed rune snapshot")
	level.set_rune_preset(1)
	_check(projectile.context.snapshot == spell and glow.color == spell.color, "Rune swapping cannot change an in-flight projectile or its light")
	level.spell_executor.clear_entities()
	await _step(3)
	_check(presentation.light_owners.is_empty(), "Projectile teardown removes light owner bookkeeping")
	for index: int in 40:
		var visual := SpellVisual.new()
		visual.lifetime = 1
		level.spell_executor.add_child(visual)
	presentation._scan()
	_check(presentation.light_owners.size() == SlicePresentation.MAX_PROJECTILE_LIGHTS, "Spam obeys the twelve projectile-light budget")
	level.spell_executor.clear_entities()
	await _step(3)
	_check(presentation.light_owners.is_empty(), "Spell spam releases all attached light resources")
	var sounds: int = presentation.sfx_count
	presentation._on_action(&"ready", &"dash")
	_check(presentation.sfx_count == sounds + 1 and audio.get_active_voice_count() > 0, "Dash transition emits one spatial cue")
	sounds = presentation.sfx_count
	player.equipped_weapon.equip(preload("res://data/weapons/demon_greatsword.tres"))
	player.equipped_weapon.start_combo()
	await _step(1)
	_check(presentation.sfx_count == sounds, "Sword wind-up does not prematurely play the swing cue")
	player.equipped_weapon.advance(0.35)
	presentation._process(0)
	_check(presentation.sfx_count == sounds + 1 and presentation.trail.style_id == &"greatsword", "Active greatsword swing emits its cue with the correct luminous trail")
	player.equipped_weapon.cancel_combo()
	var light_id: int = atmosphere.ambient.get_instance_id()
	var room_id: int = atmosphere.room_art.get_instance_id()
	presentation.rebuild(true)
	await _step(3)
	_check(atmosphere.ambient.get_instance_id() == light_id and not is_instance_id_valid(room_id), "Room rebuild preserves one CanvasModulate and frees old décor")
	_check((atmosphere.room_art.get_child(0) as DungeonBackdrop).boss_room, "Boss rebuild selects its ritual-arena backdrop")
	_check(audio.get_active_voice_count() == 0, "Room rebuild drains its spatial audio owner")
	level.queue_free()
	await _step(5)
	_check(audio.get_active_voice_count() == 0, "Dungeon teardown retains no audio voices")
	await _presentation_cycle()
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for cycle: int in 8:
		await _presentation_cycle()
	print("STRESS polish objects %d -> %d, resources %d -> %d" % [objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)), resources, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
	_check(int(Performance.get_monitor(Performance.OBJECT_COUNT)) <= objects + 2, "Repeated lit rooms retain no growing object population")
	_check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= resources + 1, "Repeated lit rooms retain no growing resource population")
	_check(audio.get_active_voice_count() == 0, "Hub/dungeon churn releases all spatial sound owners")

func _presentation_cycle() -> void:
	var flow := preload("res://scenes/game_flow.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/polish_cycle.json"
	root.add_child(flow)
	current_scene = flow
	flow.start_campaign()
	var run := flow.active_scene as LinearCampaign
	run.survival.director.automatic = false
	run.player.energy.enabled = false
	for stage: int in [1, 2, 3, 4]:
		run.enter_stage(stage)
		for enemy: Node2D in run.living_enemies():
			enemy.ai_enabled = false
		run.presentation.spawn_impact(Vector2(300, 600), Color.CORAL, &"fire")
		run.presentation._on_action(&"ready", &"dash")
		await _step(3)
	(flow.active_scene as DungeonRun).finish(&"defeat")
	flow.show_hub(true)
	await _step(4)
	flow.queue_free()
	await _step(5)

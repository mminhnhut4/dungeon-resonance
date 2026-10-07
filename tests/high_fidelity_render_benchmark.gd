extends SceneTree
## High-fidelity GPU stress sample; wall-clock render, no headless/fixed-fps.

var target_fps: int = 60
var foyer_sample: bool = false
var output_prefix: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fps="):
			target_fps = int(argument.trim_prefix("--fps="))
		elif argument == "--foyer":
			foyer_sample = true
		elif argument.begins_with("--output-prefix="):
			output_prefix = argument.trim_prefix("--output-prefix=")
	Engine.max_fps = target_fps
	Engine.physics_ticks_per_second = target_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	call_deferred("_run")


func _run() -> void:
	var campaign := preload("res://scenes/linear_campaign.tscn").instantiate() as LinearCampaign
	var audio: Node = root.get_node("AudioManager")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("DungeonSFX"), true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), true)
	campaign.profile = SanctuaryProfile.new()
	campaign.profile.save_path = "user://verification/render_polish_%d.json" % target_fps
	campaign.initial_stage = 1 if foyer_sample else 4
	root.add_child(campaign)
	campaign.content.qa_tools_enabled = true # Explicit private fixture capability.
	current_scene = campaign
	campaign.survival.director.automatic = false
	if not foyer_sample:
		campaign.survival.director.trigger(&"eclipse")
	campaign.feedback.hit_stop_seconds = 0.0
	campaign.player.suspend_controls(true)
	campaign.player.health.maximum_health = 100000.0
	campaign.player.health.current_health = 100000.0
	campaign.player.energy.enabled = false
	campaign.player.relocate(Vector2(510, 640))
	var event := DamageEvent.new()
	event.source_id = campaign.player.get_instance_id()
	event.source_team_id = 1
	event.target_id = campaign.boss.get_instance_id() if is_instance_valid(campaign.boss) else 0
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = 251.0
	if is_instance_valid(campaign.boss):
		campaign.boss.hurtbox.take_damage(event)
	var condition_event := DamageEvent.new()
	condition_event.source_id = campaign.get_instance_id()
	condition_event.target_id = campaign.player.get_instance_id()
	condition_event.source_team_id = 2
	condition_event.source_kind = DamageEvent.SourceKind.ENVIRONMENT
	condition_event.attack_id = CombatIds.next_id()
	condition_event.root_event_id = condition_event.attack_id
	condition_event.hit_window_id = 1
	condition_event.base_damage = 0.01
	condition_event.burn_damage = 0.01
	condition_event.burn_interval = 1.0
	condition_event.burn_duration = 12.0
	condition_event.poison_stacks = 2
	condition_event.poison_percent = 0.000001
	condition_event.poison_seconds = 12.0
	campaign.player.damage_grace_remaining = 0.0
	campaign.player.hurtbox.set_invulnerable(false)
	var condition_result: DamageResult = campaign.player.hurtbox.take_damage(condition_event)
	if condition_result.blocked:
		print("FAIL: Benchmark condition fixture was rejected: ", condition_result.block_reason)
		campaign.queue_free()
		for frame: int in 4:
			await process_frame
		await audio.shutdown()
		quit(1)
		return
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	var measured_start: int = 0
	var next_cast: float = 0.0
	var next_loot: float = 0.0
	var next_swing: float = 0.0
	var next_impact: float = 0.0
	var next_foot_dust: float = 0.0
	var next_ghost: float = 0.0
	var next_mark: float = 0.0
	var peak_dash_ghosts: int = 0
	var peak_movement_marks: int = 0
	var peak_ground_cracks: int = 0
	var peak_warp_owners: int = 0
	var frame_ms: Array[float] = []
	var peak_entities: int = 0
	var peak_loot: int = 0
	var peak_draw_calls: int = 0
	var physics_peak_ms: float = 0.0
	var casts: int = 0
	var swings: int = 0
	var peak_impacts: int = 0
	var peak_lights: int = 0
	var peak_impact_lights: int = 0
	var peak_voices: int = 0
	var peak_projectile_trails: int = 0
	var peak_foot_dust: int = 0
	while Time.get_ticks_usec() - start < 8000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var elapsed: float = (now - start) / 1000000.0
		# Throughput fixture only: gear/recipe changes must not end the sample.
		campaign.player.health.maximum_health = 100000.0
		campaign.player.health.current_health = 100000.0
		if is_instance_valid(campaign.boss):
			campaign.boss.health.current_health = 249.0
		if campaign.living_enemies().size() < 3:
			campaign._spawn_slime(Vector2(750, 640))
		if elapsed >= next_cast:
			campaign.content.select_recipe(ContentSession.PAIR_IDS[casts % 10])
			var controller: ResonanceController = campaign.player.resonance_controller
			controller.reset_runtime()
			var snapshot: SpellSnapshot = controller.commit_cast()
			if snapshot != null:
				snapshot.origin = Vector2(510, 570)
				snapshot.direction = Vector2.from_angle(sin(elapsed * 2.0) * 0.35)
				campaign.executor.spawn_cast(snapshot)
			casts += 1
			next_cast = elapsed + 0.1
		if elapsed >= next_loot:
			var loot: LootPickup = campaign.gear.loot.spawn(&"rune", &"poison", Vector2(1000, 635))
			if loot != null:
				loot.life = 1.5
				loot.automatic = false
			next_loot = elapsed + 0.1
		if elapsed >= next_swing:
			campaign.player.equipped_weapon.equip(campaign.survival.weapon_definition(ContentSession.WEAPON_IDS[swings % 4]))
			campaign.player.equipped_weapon.visual_quality = swings % 6
			campaign.player.equipped_weapon.start_combo()
			swings += 1
			next_swing = elapsed + 0.9
		campaign.player.equipped_weapon.advance((now - previous) / 1000000.0)
		if elapsed >= next_impact:
			var burst: ImpactBurst = campaign.presentation.spawn_impact(Vector2(850, 620), Color(1, 0.4, 0.1), &"fire", Vector2.RIGHT)
			burst.configure_combat((swings - 1) % 6, true, 2)
			burst.enable_melee_sparks()
			next_impact = elapsed + 0.05
		if elapsed >= next_foot_dust:
			campaign.presentation.spawn_foot_dust(campaign.player.global_position, Vector2.RIGHT)
			next_foot_dust = elapsed + 0.1
		if elapsed >= next_ghost:
			campaign.presentation.movement_vfx.spawn_afterimage(campaign.player)
			next_ghost = elapsed + 0.03
		if elapsed >= next_mark:
			var movement: MovementVFX = campaign.presentation.movement_vfx
			movement.spawn_mark(MovementVFX.TAKEOFF, campaign.player.global_position, 0.10, 0.22, 0.28)
			movement.spawn_mark(MovementVFX.LANDING, campaign.player.global_position + Vector2(24, 0), 0.11, 0.24, 0.36)
			movement.spawn_skid(campaign.player.global_position, Vector2.RIGHT * 200.0)
			next_mark = elapsed + 0.08
		peak_dash_ghosts = maxi(peak_dash_ghosts, campaign.presentation.movement_vfx.ghosts.get_child_count())
		peak_movement_marks = maxi(peak_movement_marks, campaign.presentation.movement_vfx.marks.get_child_count())
		peak_ground_cracks = maxi(peak_ground_cracks, campaign.presentation.impacts.get_children().filter(func(burst: ImpactBurst) -> bool: return is_instance_valid(burst.ground_crack)).size())
		peak_warp_owners = maxi(peak_warp_owners, campaign.presentation.impacts.get_children().filter(func(burst: ImpactBurst) -> bool: return is_instance_valid(burst.shockwave) and burst.shockwave.visible).size())
		peak_foot_dust = maxi(peak_foot_dust, campaign.presentation.foot_dust.get_child_count())
		peak_impacts = maxi(peak_impacts, campaign.presentation.impacts.get_child_count())
		peak_impact_lights = maxi(peak_impact_lights, campaign.presentation.impacts.get_children().filter(func(burst: ImpactBurst) -> bool: return burst.flash.enabled).size())
		peak_lights = maxi(peak_lights, campaign.presentation.light_owners.size())
		peak_projectile_trails = maxi(peak_projectile_trails, campaign.presentation.projectile_vfx_owners.size())
		peak_voices = maxi(peak_voices, audio.get_active_voice_count())
		peak_entities = maxi(peak_entities, get_nodes_in_group(&"spell_entities").size())
		peak_loot = maxi(peak_loot, get_nodes_in_group(&"loot").size())
		peak_draw_calls = maxi(peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if elapsed >= 2.0:
			if measured_start == 0:
				measured_start = now
			else:
				frame_ms.append((now - previous) / 1000.0)
			physics_peak_ms = maxf(physics_peak_ms, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		previous = now
	var measured_seconds: float = (Time.get_ticks_usec() - measured_start) / 1000000.0
	frame_ms.sort()
	var average_fps: float = frame_ms.size() / measured_seconds
	var p95_ms: float = frame_ms[mini(frame_ms.size() - 1, int(frame_ms.size() * 0.95))]
	var art_hud: ArtHUD = campaign.presentation.art_hud
	var conditions: ElementAfflictionVFX = campaign.player.get_node("ElementAfflictionVFX") as ElementAfflictionVFX
	var present_assets: Array[String] = ["32-layer modular Player", "PNG Slimes"]
	if is_instance_valid(campaign.boss):
		present_assets.append("PNG Golem")
	if campaign.room.find_children("*", "CharacterBody2D", true, false).any(func(node: Node) -> bool: return node is TrainingDummy):
		present_assets.append("PNG training dummy")
	if get_nodes_in_group(&"chests").any(func(node: Node) -> bool: return campaign.room.is_ancestor_of(node)):
		present_assets.append("PNG treasure chest")
	var result: Dictionary = {
		"engine": Engine.get_version_info().string,
		"adapter": RenderingServer.get_video_adapter_name(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"window_size": str(DisplayServer.window_get_size()),
		"target_render_fps": target_fps,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"warmup_seconds": 2,
		"measurement_seconds": measured_seconds,
		"average_render_fps": average_fps,
		"p95_frame_ms_including_cap_wait": p95_ms,
		"peak_physics_ms": physics_peak_ms,
		"peak_spell_entities": peak_entities,
		"peak_loot": peak_loot,
		"peak_draw_calls": peak_draw_calls,
		"peak_impact_vfx": peak_impacts,
		"peak_impact_lights": peak_impact_lights,
		"peak_projectile_lights": peak_lights,
		"peak_projectile_trails": peak_projectile_trails,
		"peak_trail_particles": peak_projectile_trails * SpellProjectileVFX.MAX_PARTICLES,
		"peak_dash_afterimages": peak_dash_ghosts,
		"player_burn_particles_active": conditions.burn_visible and conditions.burn.emitting,
		"player_poison_particles_active": conditions.poison_visible and conditions.poison.emitting,
		"peak_movement_marks": peak_movement_marks,
		"peak_ground_cracks": peak_ground_cracks,
		"peak_local_distortion_owners": peak_warp_owners,
		"peak_foot_dust_owners": peak_foot_dust,
		"peak_foot_dust_particles": peak_foot_dust * 4,
		"procedural_player_pose": campaign.player.get_node("Visuals").get("concept_dynamics") != null,
		"weighted_audio_bus": AudioServer.get_bus_index("SFX_Combat") >= 0,
		"hitstop_enabled_for_measurement": false,
		"peak_spatial_voices": peak_voices,
		"art_hud_visible": is_instance_valid(art_hud) and art_hud.player_panel.visible,
		"player_hp_texture_progress": is_instance_valid(art_hud) and art_hud.hp_bar is TextureProgressBar,
		"boss_hp_texture_progress": is_instance_valid(art_hud) and art_hud.boss_hp is TextureProgressBar,
		"ambient_gpu_particles": campaign.presentation.atmosphere.dust.amount,
		"torch_lights": campaign.presentation.atmosphere.torches.size(),
		"lighting_enabled": campaign.presentation.atmosphere.ambient.visible,
		"canvas_glow_enabled": campaign.presentation.atmosphere.glow_environment.environment.glow_enabled,
		"scenario": ("Foyer + jade stone Atlas platforms/columns" if foyer_sample else "Phase-2 Golem + 2 Slimes + Eclipse") + ", " + ", ".join(present_assets) + ", procedural poses and projected actor shadows, ornate PNG ArtHUD with TextureProgressBar HP/energy, SDR canvas glow, PNG torches + Player light + 72 ambient GPU ash particles, 10 alternating spells/s with finite GPU particle wakes, 20 GPU impact bursts/s, four movesets cycling six painted rarity crescents, real Player burn/poison emitters, five concurrent 32-layer afterimages, eight movement marks, high-tier critical finisher cracks and localized distortion, 10 finite loot/s and 10 four-mote foot puffs/s. Weighted spatial mixer active with SFX bus muted. Player/Boss HP held and hit-stop disabled for throughput measurement; real dash/hitstop/reactions verified separately in gameplay tests and GPU previews; cosmetic owner spawning here deliberately exceeds normal movement cadence.",
	}
	var directory: String = ProjectSettings.globalize_path("res://docs/verification")
	var prefix: String = "art_foyer_render" if foyer_sample else "polish_render"
	if not output_prefix.is_empty():
		prefix = output_prefix
	var file: FileAccess = FileAccess.open(directory.path_join("%s_%d.json" % [prefix, target_fps]), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("RENDER BENCHMARK ", JSON.stringify(result))
	var passed: bool = conditions.burn_visible and conditions.poison_visible and peak_dash_ghosts == MovementVFX.MAX_GHOSTS and peak_movement_marks == MovementVFX.MAX_MARKS and peak_ground_cracks > 0 and peak_warp_owners > 0 and peak_draw_calls > 0 and average_fps >= target_fps * 0.95 and p95_ms <= 1000.0 / target_fps * 1.4
	campaign.queue_free()
	for frame: int in 4:
		await process_frame
	await audio.shutdown()
	quit(0 if passed else 1)

extends SceneTree
## Real GPU sample of the approved Hub. Never use headless/fixed-fps for FPS.
## Forced cast reset/disabled costs are a throughput fixture, not gameplay.

const WARMUP_SECONDS: float = 2.0
const SAMPLE_SECONDS: float = 6.0
const DRAIN_SECONDS: float = 3.0
var target_fps: int = 60
var failed_casts: int = 0
var casts: int = 0
var loot_spawned: int = 0
var impacts_spawned: int = 0
var recipe_ids: Array[StringName] = []


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fps="):
			target_fps = int(argument.trim_prefix("--fps="))
	if DisplayServer.get_name() == "headless" or target_fps not in [60, 120]:
		print("FAIL: Prologue render benchmark requires a real renderer and --fps=60 or 120")
		quit(1)
		return
	Engine.max_fps = target_fps
	Engine.physics_ticks_per_second = target_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	call_deferred("_run")


func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	var flow: GameFlow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	# Private process-specific path: no load/save against the user's campaign.
	flow.save_path_override = "user://verification/prologue_render_%d_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec(), target_fps]
	root.add_child(flow)
	current_scene = flow
	for frame: int in 15:
		await process_frame
	var hub: PrologueHub = flow.active_scene as PrologueHub
	var art: PrologueHubArt = hub.get_node("PrologueHubArt") as PrologueHubArt
	var fire: CampfireVisualSkin = art.fire.get_node_or_null("CampfireVisualSkin") as CampfireVisualSkin if art.fire != null else null
	if fire == null or not is_instance_valid(fire.flame) or not is_instance_valid(fire.light):
		print("FAIL: Approved Hub art and animated/lighted campfire must be mounted before measurement")
		flow.queue_free()
		for frame: int in 4:
			await process_frame
		await audio.shutdown()
		quit(1)
		return
	hub.player.suspend_controls(true)
	hub.player.energy.enabled = false
	hub.feedback.enable_global_hitstop(false)
	hub.feedback.hit_stop_seconds = 0.0
	hub.player.relocate(Vector2(1590, 640))
	var camera: Camera2D = hub.player.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	for rune: RuneData in GearInventory.RUNES:
		hub.gear.inventory.add_rune(rune.id)
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	var measured_start: int = 0
	var next_cast: float = 0.0
	var next_loot: float = 0.0
	var next_impact: float = 0.0
	var frame_ms: Array[float] = []
	var peak_entities: int = 0
	var peak_loot: int = 0
	var peak_impacts: int = 0
	var peak_impact_lights: int = 0
	var peak_projectile_lights: int = 0
	var peak_projectile_trails: int = 0
	var peak_spatial_voices: int = 0
	var peak_draw_calls: int = 0
	var peak_physics_ms: float = 0.0
	var peak_objects: int = 0
	var peak_resources: int = 0
	var fire_frames: Dictionary[int, bool] = {}
	var fire_audio_observed: bool = false
	var warm_objects: int = 0
	var warm_resources: int = 0
	while Time.get_ticks_usec() - start < int((WARMUP_SECONDS + SAMPLE_SECONDS) * 1000000.0):
		await process_frame
		var now: int = Time.get_ticks_usec()
		var elapsed: float = (now - start) / 1000000.0
		if elapsed >= next_cast:
			_spawn_cast(hub, elapsed)
			next_cast += 0.2
		if elapsed >= next_loot:
			var id: StringName = MaterialCatalog.IDS[loot_spawned % MaterialCatalog.IDS.size()]
			var loot: LootPickup = hub.gear.loot.spawn(&"material", id, Vector2(1690 + (loot_spawned % 5) * 20, 635))
			if loot != null:
				loot.life = 1.5
				loot.automatic = false
				loot_spawned += 1
			next_loot += 0.1
		if elapsed >= next_impact:
			var burst: ImpactBurst = hub.presentation.spawn_impact(Vector2(1715 + sin(elapsed * 3.0) * 55.0, 625), Color(1.0, 0.56, 0.18), &"fire", Vector2.RIGHT)
			burst.configure_combat(GearItem.Quality.COMMON)
			burst.enable_melee_sparks()
			audio.play_weighted_event(&"melee_impact", burst.global_position, hub.presentation)
			impacts_spawned += 1
			next_impact += 0.05
		fire_frames[fire.flame.frame] = true
		fire_audio_observed = fire_audio_observed or (fire.sound_deadline > Time.get_ticks_msec() and audio.get_active_voice_count() > 0)
		peak_entities = maxi(peak_entities, get_nodes_in_group(&"spell_entities").size())
		peak_loot = maxi(peak_loot, hub.gear.loot.get_child_count())
		peak_impacts = maxi(peak_impacts, hub.presentation.impacts.get_child_count())
		peak_impact_lights = maxi(peak_impact_lights, hub.presentation.impacts.get_children().filter(func(burst: ImpactBurst) -> bool: return burst.flash.enabled).size())
		peak_projectile_lights = maxi(peak_projectile_lights, hub.presentation.light_owners.size())
		peak_projectile_trails = maxi(peak_projectile_trails, hub.presentation.projectile_vfx_owners.size())
		peak_spatial_voices = maxi(peak_spatial_voices, audio.get_active_voice_count())
		peak_draw_calls = maxi(peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		peak_objects = maxi(peak_objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
		peak_resources = maxi(peak_resources, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
		if elapsed >= WARMUP_SECONDS:
			if measured_start == 0:
				measured_start = now
				warm_objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
				warm_resources = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
			else:
				frame_ms.append((now - previous) / 1000.0)
			peak_physics_ms = maxf(peak_physics_ms, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		previous = now
	var measured_seconds: float = (Time.get_ticks_usec() - measured_start) / 1000000.0
	frame_ms.sort()
	var average_fps: float = frame_ms.size() / maxf(0.001, measured_seconds)
	var p95_ms: float = frame_ms[mini(frame_ms.size() - 1, int(frame_ms.size() * 0.95))] if not frame_ms.is_empty() else INF
	# Stop new work and observe natural expiry. Do not clear pools to fake cleanup.
	var drain_start: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - drain_start < int(DRAIN_SECONDS * 1000000.0):
		await process_frame
	var remaining_entities: int = get_nodes_in_group(&"spell_entities").size()
	var remaining_loot: int = hub.gear.loot.get_child_count()
	var remaining_impacts: int = hub.presentation.impacts.get_child_count()
	var remaining_voices: int = audio.get_active_voice_count()
	var hud: ArtHUD = hub.presentation.art_hud
	var result: Dictionary = {
		"engine": Engine.get_version_info().string,
		"adapter": RenderingServer.get_video_adapter_name(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"window_size": str(DisplayServer.window_get_size()),
		"target_render_fps": target_fps,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"warmup_seconds": WARMUP_SECONDS,
		"measurement_seconds": measured_seconds,
		"average_render_fps": average_fps,
		"p95_frame_ms_including_cap_wait": p95_ms,
		"peak_physics_ms": peak_physics_ms,
		"peak_draw_calls": peak_draw_calls,
		"casts_committed": casts,
		"failed_casts": failed_casts,
		"recipes": recipe_ids,
		"loot_spawned": loot_spawned,
		"manual_impacts_spawned": impacts_spawned,
		"peak_spell_entities": peak_entities,
		"peak_loot": peak_loot,
		"peak_impact_vfx": peak_impacts,
		"peak_impact_lights": peak_impact_lights,
		"peak_projectile_lights": peak_projectile_lights,
		"peak_projectile_trails": peak_projectile_trails,
		"peak_spatial_voices": peak_spatial_voices,
		"warm_objects": warm_objects,
		"warm_resources": warm_resources,
		"peak_objects": peak_objects,
		"peak_resources": peak_resources,
		"natural_drain_seconds": DRAIN_SECONDS,
		"entities_after_drain": remaining_entities,
		"loot_after_drain": remaining_loot,
		"impacts_after_drain": remaining_impacts,
		"projectile_lights_after_drain": hub.presentation.light_owners.size(),
		"projectile_trails_after_drain": hub.presentation.projectile_vfx_owners.size(),
		"spatial_voices_after_drain": remaining_voices,
		"objects_after_drain": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources_after_drain": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"campfire_animated_frames_observed": fire_frames.size(),
		"campfire_particles_active": fire.embers.emitting and fire.embers.is_visible_in_tree(),
		"campfire_light_active": fire.light.enabled and fire.light.is_visible_in_tree(),
		"campfire_audio_active_observed": fire_audio_observed,
		"lighting_enabled": hub.presentation.atmosphere.ambient.visible,
		"canvas_glow_enabled": hub.presentation.atmosphere.glow_environment.environment.glow_enabled,
		"art_hud_visible": is_instance_valid(hud) and hud.player_panel.visible,
		"player_hp_texture_progress": is_instance_valid(hud) and hud.hp_bar is TextureProgressBar,
		"player_modular_active": (hub.player.get_node("Visuals") as PlayerVisualRig).is_modular_active(),
		"hitstop_enabled_for_measurement": false,
		"master_bus_muted_private_fixture": true,
		"scenario": "Actual PrologueGameFlow -> approved painted courtyard/house/props + side-view Kael, 32-layer starter Player at active campfire (1590,640), animated flame/8 GPU embers/warm light and real ambient crackle voice. 10 finite material loot/s, 20 Common melee impact bursts/s with real weighted mixer voices and 5 casts/s alternating basic/Firestorm/Charged Slash. Real recipe installation and commit snapshots; cast cooldown reset and energy costs disabled only in this throughput fixture. Player input suspended, no fixed-fps or headless simulation. Master muted only in this private benchmark process. Two-second warmup/six-second render sample, then three seconds without spawns to observe finite owner expiry; this does not establish a long-term memory-leak proof or final game balance."
	}
	var passed: bool = average_fps >= target_fps * 0.95 and p95_ms <= 1000.0 / target_fps * 1.4 and peak_draw_calls > 0 and failed_casts == 0 and recipe_ids.size() == 3 and fire_frames.size() >= 2 and fire.light.enabled and fire.embers.emitting and fire_audio_observed and peak_entities <= hub.executor.maximum_spell_entities and peak_loot <= 18 and peak_impacts <= SlicePresentation.MAX_IMPACTS and peak_impact_lights <= SlicePresentation.MAX_IMPACT_LIGHTS and peak_projectile_lights <= SlicePresentation.MAX_PROJECTILE_LIGHTS and peak_projectile_trails <= SlicePresentation.MAX_PROJECTILE_TRAILS and peak_spatial_voices <= audio.max_voices and remaining_entities == 0 and remaining_loot == 0 and remaining_impacts == 0 and hub.presentation.light_owners.is_empty() and hub.presentation.projectile_vfx_owners.is_empty() and remaining_voices <= 1
	result["passed"] = passed
	var directory: String = ProjectSettings.globalize_path("res://docs/verification")
	var file: FileAccess = FileAccess.open(directory.path_join("prologue_hub_render_%d.json" % target_fps), FileAccess.WRITE)
	if file == null:
		print("FAIL: Cannot write Prologue benchmark JSON")
		passed = false
	else:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	print("RENDER BENCHMARK ", JSON.stringify(result))
	if not passed:
		print("FAIL: Prologue render sample failed FPS/active-art/budget/natural-expiry acceptance")
	flow.queue_free()
	for frame: int in 4:
		await process_frame
	await audio.shutdown()
	quit(0 if passed else 1)


func _spawn_cast(hub: PrologueHub, elapsed: float) -> void:
	var ids: Array[StringName] = []
	match casts % 3:
		1: ids.assign([&"fire", &"wind"])
		2: ids.assign([&"wind", &"lightning"])
	if not hub.gear.inventory.equip_catalyst_set(ids):
		failed_casts += 1
		return
	var controller: ResonanceController = hub.player.resonance_controller
	controller.reset_runtime()
	var snapshot: SpellSnapshot = controller.commit_cast()
	if snapshot == null:
		failed_casts += 1
		return
	if not recipe_ids.has(snapshot.recipe_id):
		recipe_ids.append(snapshot.recipe_id)
	snapshot.origin = hub.player.global_position + Vector2(0, -40)
	snapshot.direction = Vector2.from_angle(0.35 + sin(elapsed * 2.0) * 0.1)
	snapshot.target_position = snapshot.origin + snapshot.direction * 150.0
	hub.executor.spawn_cast(snapshot)
	casts += 1

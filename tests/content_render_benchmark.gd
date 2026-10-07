extends SceneTree
## Real GPU / wall-clock sample. Run without --headless or --fixed-fps.

var target_fps: int = 60


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fps="):
			target_fps = int(argument.trim_prefix("--fps="))
	Engine.max_fps = target_fps
	Engine.physics_ticks_per_second = target_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	call_deferred("_run")


func _run() -> void:
	var campaign := preload("res://scenes/linear_campaign.tscn").instantiate() as LinearCampaign
	campaign.profile = SanctuaryProfile.new()
	campaign.profile.save_path = "user://verification/render_content_%d.json" % target_fps
	campaign.initial_stage = 4
	root.add_child(campaign)
	campaign.content.qa_tools_enabled = true # Explicit private fixture capability.
	current_scene = campaign
	campaign.survival.director.automatic = false
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
	event.target_id = campaign.boss.get_instance_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = 251.0
	campaign.boss.hurtbox.take_damage(event)
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	var measured_start: int = 0
	var next_cast: float = 0.0
	var next_loot: float = 0.0
	var frame_ms: Array[float] = []
	var peak_entities: int = 0
	var peak_loot: int = 0
	var peak_draw_calls: int = 0
	var physics_peak_ms: float = 0.0
	var casts: int = 0
	while Time.get_ticks_usec() - start < 8000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var elapsed: float = (now - start) / 1000000.0
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
		"scenario": "Phase-2 Golem + 2 Slimes, Eclipse, ten alternating recipes at 10 casts/s and 10 finite loot/s. Player HP/energy and Boss HP held for the benchmark; hit-stop disabled.",
	}
	var directory: String = ProjectSettings.globalize_path("res://docs/verification")
	var file: FileAccess = FileAccess.open(directory.path_join("content_render_%d.json" % target_fps), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("RENDER BENCHMARK ", JSON.stringify(result))
	var passed: bool = peak_draw_calls > 0 and average_fps >= target_fps * 0.9 and p95_ms <= 1000.0 / target_fps * 1.5
	campaign.queue_free()
	for frame: int in 4:
		await process_frame
	quit(0 if passed else 1)

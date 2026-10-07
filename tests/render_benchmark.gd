extends SceneTree
## Wall-clock graphical smoke/benchmark. Never use --fixed-fps with this script.

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
	var level := (load("res://scenes/test_level.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(level)
	current_scene = level
	level.player.controls_enabled = false
	level.survival.set_enabled(false)
	level.player.energy.enabled = false
	level.combat_feedback.hit_stop_seconds = 0.0
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	var next_shot: float = 0.0
	var next_reset: float = 3.0
	var frame_ms: Array[float] = []
	var measured_frames: int = 0
	var peak_entities: int = 0
	var physics_peak_ms: float = 0.0
	var measured_start: int = 0
	while Time.get_ticks_usec() - start < 8000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var elapsed: float = (now - start) / 1000000.0
		if elapsed >= next_shot:
			var index: int = int(elapsed * 10.0)
			level.set_rune_preset(index % 3 + 1)
			var controller: ResonanceController = level.player.resonance_controller
			controller.reset_runtime()
			var snapshot: SpellSnapshot = controller.commit_cast()
			snapshot.origin = Vector2(730, 590)
			snapshot.direction = Vector2.from_angle(sin(elapsed * 2.0) * 0.8)
			level.spell_executor.spawn_cast(snapshot)
			next_shot = elapsed + 0.1
		if elapsed >= next_reset:
			level.reset_room()
			next_reset += 3.0
		peak_entities = maxi(peak_entities, get_nodes_in_group(&"spell_entities").size())
		if elapsed >= 2.0:
			if measured_start == 0:
				measured_start = now
			else:
				frame_ms.append((now - previous) / 1000.0)
				measured_frames += 1
			physics_peak_ms = maxf(physics_peak_ms, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		previous = now
	var measured_seconds: float = (Time.get_ticks_usec() - measured_start) / 1000000.0
	frame_ms.sort()
	var average_fps: float = measured_frames / measured_seconds
	var p95_ms: float = frame_ms[mini(frame_ms.size() - 1, int(frame_ms.size() * 0.95))]
	var result: Dictionary = {
		"engine": Engine.get_version_info().string,
		"adapter": RenderingServer.get_video_adapter_name(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"window_size": str(DisplayServer.window_get_size()),
		"target_render_fps": target_fps,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"measurement_seconds": measured_seconds,
		"average_render_fps": average_fps,
		"p95_frame_ms_including_cap_wait": p95_ms,
		"peak_physics_ms": physics_peak_ms,
		"peak_spell_entities": peak_entities,
		"scenario": "2 Slimes, 2 dummies, mixed spells emitted every 0.1s; room reset every 3s; 2s warmup + 6s sample",
	}
	var directory: String = ProjectSettings.globalize_path("res://docs/verification")
	DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess = FileAccess.open(directory.path_join("render_%d.json" % target_fps), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("RENDER BENCHMARK ", JSON.stringify(result))
	var passed: bool = average_fps >= target_fps * 0.9 and p95_ms <= 1000.0 / target_fps * 1.5
	level.queue_free()
	await process_frame
	await process_frame
	quit(0 if passed else 1)

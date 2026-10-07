extends SceneTree
## Exercises voice ownership and synthesized PCM without playing a room.

const AUDIO_SCRIPT: GDScript = preload("res://scripts/audio/audio_manager.gd")
var manager: Node
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	manager = AUDIO_SCRIPT.new()
	root.add_child(manager)
	var quit_policy: bool = auto_accept_quit
	manager.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(not manager._handles_window_quit and auto_accept_quit == quit_policy and not manager._quit_requested, "A private audio service cannot intercept or change the window-close policy")
	if OS.get_cmdline_user_args().has("--silent-output"):
		AudioServer.set_bus_mute(AudioServer.get_bus_index(manager.bus_name), true)
	print("AUDIO TEST: %d physics ticks/s, driver=%s" % [Engine.physics_ticks_per_second, AudioServer.get_driver_name()])
	_check(manager.get_active_voice_count() == 0, "Audio service has no autoplay, music or initial voice")
	var signatures: Array[int] = []
	for cue: StringName in manager.CUES:
		var stream: AudioStreamWAV = manager.get_cue_stream(cue)
		_check(stream != null and stream.format == AudioStreamWAV.FORMAT_16_BITS and not stream.stereo, "%s provides standard mono 16-bit PCM" % cue)
		_check(stream.get_length() > 0.1 and stream.get_length() < 0.5 and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s is a finite one-shot cue" % cue)
		var pcm: PackedByteArray = stream.data
		var squared_sum: float = 0.0
		var peak: float = 0.0
		for index: int in range(pcm.size() / 2):
			var sample: float = float(pcm.decode_s16(index * 2)) / 32767.0
			peak = maxf(peak, absf(sample))
			squared_sum += sample * sample
		var rms: float = sqrt(squared_sum / float(pcm.size() / 2))
		_check(rms > 0.015 and peak < 0.86 and pcm.decode_s16(0) == 0 and pcm.decode_s16(pcm.size() - 2) == 0, "%s has non-silent, unclipped PCM with click-free endpoints" % cue)
		signatures.append(hash(pcm))
	_check(signatures.size() == 5 and not signatures.any(func(value: int) -> bool: return signatures.count(value) > 1), "Five cues have distinct deterministic waveforms")
	if OS.get_cmdline_user_args().has("--export-audio"):
		_export_preview()
	_check(AudioServer.get_bus_index(manager.bus_name) >= 0 and manager.bus_name != &"Master", "SFX uses its own quiet bus without modifying Master")
	var first_room := Node2D.new()
	var second_room := Node2D.new()
	root.add_child(first_room)
	root.add_child(second_room)
	var voice: AudioStreamPlayer2D = manager.play_event(&"sword_swing", Vector2(123, 456), first_room)
	_check(voice != null and voice.global_position == Vector2(123, 456) and voice.max_distance > 0.0, "Sound emitter uses the requested world position and distance attenuation")
	_check(voice.pitch_scale >= 0.9 and voice.pitch_scale <= 1.1 and voice.bus == manager.bus_name, "Playback pitch stays within plus/minus ten percent")
	_check(voice.playing if AudioServer.get_driver_name() != "Dummy" else not voice.playing, "Real drivers begin playback while Dummy driver keeps only a finite silent emitter")
	_check(manager.play_event(&"missing_cue", Vector2.ZERO, first_room) == null and manager.play_event(&"dash", Vector2(INF, 0), first_room) == null, "Unknown cues and non-finite spatial positions cannot spawn voices")
	var pitches: Array[float] = []
	for index: int in range(160):
		voice = manager.play_event(&"dash", Vector2(index, 20), first_room)
		pitches.append(voice.pitch_scale)
	_check(manager.get_active_voice_count() == manager.max_voices and manager.get_child_count() >= manager.max_voices, "Burst of 160 cues remains capped at sixteen live voices")
	_check(pitches.min() >= 0.9 and pitches.max() <= 1.1 and pitches.max() - pitches.min() > 0.1, "Successive cues vary pitch while respecting the exact bounds")
	await _step(3)
	_check(manager.get_child_count() <= manager.max_voices, "Replaced voices release their Node and stream after deferred deletion")
	manager.stop_all()
	await _step(2)
	voice = manager.play_event(&"aggro", Vector2.ZERO, first_room)
	manager.play_event(&"spell_explosion", Vector2.ZERO, second_room)
	manager.stop_owner(first_room)
	_check(manager.get_active_voice_count() == 1, "Stopping one room does not stop another room's cue")
	await _step(2)
	_check(not is_instance_valid(voice), "Explicit owner stop releases the spatial emitter")
	second_room.queue_free()
	await _step(3)
	_check(manager.get_active_voice_count() == 0 and manager.get_child_count() == 0, "Room deletion automatically releases voices without retaining owner Nodes")
	voice = manager.play_event(&"hurt", Vector2.ZERO, first_room)
	voice.finished.emit()
	await _step(2)
	_check(manager.get_active_voice_count() == 0 and not is_instance_valid(voice), "Finished notification releases the voice exactly once")
	voice = manager.play_event(&"spell_explosion", Vector2.ZERO, first_room)
	voice.stop()
	var wall_start: int = Time.get_ticks_msec()
	Engine.time_scale = 0.1
	while Time.get_ticks_msec() - wall_start < 850:
		await process_frame
	Engine.time_scale = 1.0
	await _step(2)
	_check(manager.get_active_voice_count() == 0 and not is_instance_valid(voice), "Wall-clock fallback frees stopped audio even during slow-motion or missing finished signals")
	var detached_room := Node2D.new()
	_check(manager.play_event(&"dash", Vector2.ZERO, detached_room) == null, "Detached room owners cannot register new voices")
	detached_room.free()
	for cycle: int in range(8):
		var transient_room := Node2D.new()
		root.add_child(transient_room)
		for index: int in range(25):
			manager.play_event(&"sword_swing", Vector2.ZERO, transient_room)
		transient_room.queue_free()
		await _step(3)
	_check(manager.get_active_voice_count() == 0 and manager.get_child_count() == 0, "Eight room churn cycles leave no retained emitter or owner entry")
	manager.enabled = false
	_check(manager.play_event(&"dash", Vector2.ZERO, first_room) == null, "Audio can be muted by disabling service without changing gameplay")
	manager.enabled = true
	manager.play_event(&"dash", Vector2.ZERO, first_room)
	await manager.shutdown()
	_check(not manager.enabled and manager.get_active_voice_count() == 0, "Graceful shutdown prevents new cues and drains the real audio mixer")
	manager.queue_free()
	first_room.queue_free()
	await _step(3)
	_check(not is_instance_valid(manager), "Service teardown releases cached streams and all pending voices")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _step(frames: int) -> void:
	for frame: int in range(frames):
		await physics_frame
		await process_frame


func _export_preview() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio"))
	var montage := PackedByteArray()
	var silence := PackedByteArray()
	silence.resize(int(manager.SAMPLE_RATE * 0.35) * 2)
	silence.fill(0)
	for cue: StringName in manager.CUES:
		var stream: AudioStreamWAV = manager.get_cue_stream(cue)
		montage.append_array(stream.data)
		montage.append_array(silence)
	var preview := AudioStreamWAV.new()
	preview.format = AudioStreamWAV.FORMAT_16_BITS
	preview.mix_rate = manager.SAMPLE_RATE
	preview.stereo = false
	preview.loop_mode = AudioStreamWAV.LOOP_DISABLED
	preview.data = montage
	var error: Error = preview.save_to_wav("res://assets/audio/polish_sfx_preview.wav")
	print("AUDIO PREVIEW: save status %d, %.2f seconds" % [error, preview.get_length()])


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

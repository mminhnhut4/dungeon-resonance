extends SceneTree
## Finite offline campfire PCM, shared voice budget and saved mixer custody.

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
	var ambient: int = AudioServer.get_bus_index(&"Ambient")
	var master: int = AudioServer.get_bus_index(&"Master")
	var original_master_mute: bool = AudioServer.is_bus_mute(master)
	if OS.get_cmdline_user_args().has("--silent-output"):
		AudioServer.set_bus_mute(master, true)
	var original_gain: float = AudioServer.get_bus_volume_db(ambient)
	var original_mute: bool = AudioServer.is_bus_mute(ambient)
	AudioServer.set_bus_volume_db(ambient, -23.0)
	AudioServer.set_bus_mute(ambient, true)
	var configured_mix: Array[Dictionary] = _mix_snapshot()
	manager = AUDIO_SCRIPT.new()
	root.add_child(manager)
	print("CAMPFIRE AUDIO TEST: %d physics ticks/s, driver=%s" % [Engine.physics_ticks_per_second, AudioServer.get_driver_name()])
	_check(_mix_snapshot() == configured_mix and manager.get_active_voice_count() == 0, "Private fire service preserves live mixer preferences and starts without autoplay")
	var stream: AudioStreamWAV = manager.get_fire_stream()
	_check(stream != null and stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == 22050 and not stream.stereo, "Campfire has a standard offline mono 16-bit PCM stream")
	_check(is_equal_approx(stream.get_length(), 2.4) and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Fire is a finite 2.4-second segment that its nearby adapter renews")
	_check(manager.get_fire_stream() == stream and manager.CUES.size() == 5 and manager.WEIGHTED_CUES.size() == 9, "Fire waveform is cached separately without expanding legacy cue contracts")
	var pcm: PackedByteArray = stream.data
	var peak: float = 0.0
	var square_sum: float = 0.0
	for sample_index: int in range(int(pcm.size() * 0.5)):
		var sample: float = float(pcm.decode_s16(sample_index * 2)) / 32767.0
		peak = maxf(peak, absf(sample))
		square_sum += sample * sample
	var rms: float = sqrt(square_sum / float(pcm.size() * 0.5))
	print("FIRE PCM: rms=%.5f peak=%.5f duration=%.2f" % [rms, peak, stream.get_length()])
	_check(rms > 0.015 and rms < 0.12 and peak > 0.10 and peak < 0.70, "Soft hiss and individual crackles are non-silent with unclipped PCM headroom")
	_check(pcm.decode_s16(0) == 0 and pcm.decode_s16(pcm.size() - 2) == 0, "Fire starts and ends on zero samples without a hard click")
	_check(_window_rms(pcm, 0.0, 0.025) < _window_rms(pcm, 0.2, 0.8) * 0.55 and _window_rms(pcm, 2.375, 2.4) < _window_rms(pcm, 1.6, 2.2) * 0.55, "Short attack and release fades soften finite segment boundaries")
	if OS.get_cmdline_user_args().has("--export-audio"):
		var status: Error = stream.save_to_wav("res://docs/verification/campfire_crackle_preview.wav")
		_check(status == OK, "Campfire audition WAV exports successfully")
	var owner := Node2D.new()
	var other_owner := Node2D.new()
	root.add_child(owner)
	root.add_child(other_owner)
	var fire: AudioStreamPlayer2D = manager.play_fire_ambience(Vector2(320, 640), owner)
	_check(fire != null and fire.stream == stream and fire.bus == &"Ambient" and fire.global_position == Vector2(320, 640), "One spatial fire emitter uses the Ambient bus at its world origin")
	_check(fire.max_distance == 380.0 and is_equal_approx(fire.attenuation, 1.6) and fire.max_polyphony == 1 and is_equal_approx(fire.volume_db, -7.0), "Fire stays local and quiet without independent polyphony")
	_check(fire.pitch_scale >= 0.96 and fire.pitch_scale <= 1.04, "Fire applies only the restrained .96–1.04 pitch variation")
	var legacy: AudioStreamPlayer2D = manager.play_event(&"swing", Vector2.ZERO, owner)
	var weighted: AudioStreamPlayer2D = manager.play_weighted_event(&"melee_impact", Vector2.ZERO, other_owner)
	_check(legacy.bus == &"DungeonSFX" and legacy.max_distance == 1350.0 and is_equal_approx(legacy.attenuation, 1.35) and legacy.pitch_scale >= 0.9 and legacy.pitch_scale <= 1.1, "Legacy cue retains its original route, distance and pitch")
	_check(weighted.bus == &"SFX_Combat" and weighted.max_distance == 1350.0 and weighted.pitch_scale >= 0.88 and weighted.pitch_scale <= 1.12, "Weighted combat keeps its independent existing route and pitch")
	_check(manager.play_event(&"fire_crackle", Vector2.ZERO, owner) == null and manager.play_weighted_event(&"fire_crackle", Vector2.ZERO, owner) == null, "Ambient fire cannot accidentally enter either combat cue API")
	var unattached := Node2D.new()
	_check(manager.play_fire_ambience(Vector2(INF, 0), owner) == null and manager.play_fire_ambience(Vector2.ZERO, unattached) == null, "Invalid origin and detached owner cannot allocate a fire voice")
	unattached.free()
	manager.enabled = false
	_check(manager.play_fire_ambience(Vector2.ZERO, owner) == null, "Disabled audio rejects ambient fire like other sounds")
	manager.enabled = true
	var pitches: Array[float] = []
	for index: int in 64:
		fire = manager.play_fire_ambience(Vector2(index, 640), owner)
		pitches.append(fire.pitch_scale)
		if index % 3 == 0:
			manager.play_weighted_event(&"landing", Vector2.ZERO, owner)
	_check(pitches.min() >= 0.96 and pitches.max() <= 1.04 and pitches.max() - pitches.min() > 0.06, "Repeated renewals stay within the small pitch range without a fixed repetition")
	_check(manager.get_active_voice_count() == 16, "Ambient, legacy and weighted combat share the same sixteen-voice cap")
	await _step(3)
	_check(manager.get_child_count() == 16, "Burst replacement frees displaced fire emitters on the next tree flush")
	manager.stop_all()
	await _step(2)
	manager.play_fire_ambience(Vector2.ZERO, owner)
	manager.play_weighted_event(&"landing", Vector2.ZERO, other_owner)
	manager.stop_owner(owner)
	_check(manager.get_active_voice_count() == 1, "Stopping a hidden or distant campfire leaves another owner's combat cue intact")
	manager.stop_all()
	await _step(2)
	manager.play_fire_ambience(Vector2.ZERO, other_owner)
	root.remove_child(other_owner)
	_check(manager.get_active_voice_count() == 0, "Detaching the room/home owner prunes its fire immediately")
	other_owner.queue_free()
	await _step(3)
	_check(manager.get_child_count() == 0, "Owner departure leaves no audio child nodes after cleanup")
	fire = manager.play_fire_ambience(Vector2.ZERO, owner)
	fire.stop() # Headless has no finished signal; the deadline must still work.
	var previous_scale: float = Engine.time_scale
	Engine.time_scale = 0.1
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 2800:
		await process_frame
	Engine.time_scale = previous_scale
	await _step(2)
	_check(manager.get_active_voice_count() == 0 and not is_instance_valid(fire), "Fire expires in wall time even during inventory slowdown without a finished signal")
	await _mixer_drain()
	var objects_before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_before: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for cycle: int in 8:
		var transient := Node2D.new()
		root.add_child(transient)
		for event_index: int in 20:
			manager.play_fire_ambience(Vector2.ZERO, transient)
		transient.queue_free()
		await _step(3)
	_check(manager.get_active_voice_count() == 0 and manager.get_child_count() == 0, "Repeated campfire room churn retains no voices or owner records")
	await _mixer_drain()
	_check(int(Performance.get_monitor(Performance.OBJECT_COUNT)) <= objects_before and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= resources_before, "Finite fire renewals reuse cached PCM without retaining extra objects or resources")
	print("STRESS: campfire audio objects=%d->%d resources=%d->%d" % [objects_before, int(Performance.get_monitor(Performance.OBJECT_COUNT)), resources_before, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
	manager.play_fire_ambience(Vector2.ZERO, owner)
	await manager.shutdown()
	_check(not manager.enabled and manager.get_active_voice_count() == 0 and manager.play_fire_ambience(Vector2.ZERO, owner) == null, "Mixer shutdown drains fire and prevents adapter renewals")
	root.remove_child(manager)
	_check(manager.get_fire_stream() == null and manager._streams.is_empty() and manager._weighted_streams.is_empty(), "Service exit releases the fire cache alongside legacy stream caches")
	manager.queue_free()
	owner.queue_free()
	await _step(3)
	_check(_mix_snapshot() == configured_mix and is_equal_approx(Engine.time_scale, 1.0), "Teardown preserves Ambient preferences and global time")
	AudioServer.set_bus_volume_db(ambient, original_gain)
	AudioServer.set_bus_mute(ambient, original_mute)
	AudioServer.set_bus_mute(master, original_master_mute)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _window_rms(pcm: PackedByteArray, first_seconds: float, last_seconds: float) -> float:
	var first: int = int(first_seconds * 22050)
	var last: int = mini(int(last_seconds * 22050), int(pcm.size() * 0.5))
	var sum_squares: float = 0.0
	for sample_index: int in range(first, last):
		var sample: float = float(pcm.decode_s16(sample_index * 2)) / 32767.0
		sum_squares += sample * sample
	return sqrt(sum_squares / maxi(1, last - first))


func _mix_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(AudioServer.bus_count):
		var effect_ids: Array[int] = []
		for slot: int in range(AudioServer.get_bus_effect_count(index)):
			effect_ids.append(AudioServer.get_bus_effect(index, slot).get_instance_id())
		result.append({"name": AudioServer.get_bus_name(index), "send": AudioServer.get_bus_send(index), "gain": AudioServer.get_bus_volume_db(index), "mute": AudioServer.is_bus_mute(index), "solo": AudioServer.is_bus_solo(index), "effects": effect_ids})
	return result


func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame


func _mixer_drain() -> void:
	# WASAPI releases stopped decoder playback objects on its next mix boundary,
	# independently of fixed-fps fast simulation. Measure only after that drain.
	if AudioServer.get_driver_name() == "Dummy":
		return
	var deadline: int = Time.get_ticks_msec() + ceili(1000.0 * maxf(0.08, AudioServer.get_output_latency() * 2.0))
	while Time.get_ticks_msec() < deadline:
		await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

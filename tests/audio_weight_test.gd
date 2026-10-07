extends SceneTree
## Real PCM, route isolation, capped mixed hooks and room-owned cleanup.

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
	print("AUDIO WEIGHT TEST: %d physics ticks/s, driver=%s" % [Engine.physics_ticks_per_second, AudioServer.get_driver_name()])
	var master: int = AudioServer.get_bus_index(&"Master")
	var sfx: int = AudioServer.get_bus_index(&"SFX")
	var combat: int = AudioServer.get_bus_index(&"SFX_Combat")
	var ambient: int = AudioServer.get_bus_index(&"Ambient")
	var legacy: int = AudioServer.get_bus_index(&"DungeonSFX")
	_check(master == 0 and sfx > master and combat > sfx and ambient > master and legacy > combat, "Every audio route exists in legal downstream order")
	if mini(sfx, mini(combat, mini(ambient, legacy))) < 0:
		quit(1)
		return
	_check(AudioServer.get_bus_send(sfx) == &"Master" and AudioServer.get_bus_send(combat) == &"SFX" and AudioServer.get_bus_send(legacy) == &"SFX_Combat" and AudioServer.get_bus_send(ambient) == &"Master", "Combat and legacy SFX share gain control while Ambient stays independent")
	var limiter_count: int = 0
	var limiter: AudioEffectHardLimiter
	for index: int in range(AudioServer.get_bus_effect_count(master)):
		var effect: AudioEffect = AudioServer.get_bus_effect(master, index)
		if effect is AudioEffectHardLimiter:
			limiter_count += 1
			limiter = effect as AudioEffectHardLimiter
	_check(limiter_count == 1 and limiter != null and limiter.ceiling_db <= -0.3 and is_zero_approx(limiter.pre_gain_db), "Master has one safety limiter with a negative ceiling and no extra pre-gain")
	var original_master_gain: float = AudioServer.get_bus_volume_db(master)
	var original_sfx_gain: float = AudioServer.get_bus_volume_db(sfx)
	var original_sfx_mute: bool = AudioServer.is_bus_mute(sfx)
	var original_combat_mute: bool = AudioServer.is_bus_mute(combat)
	AudioServer.set_bus_volume_db(master, -3.0)
	AudioServer.set_bus_volume_db(sfx, -17.0)
	AudioServer.set_bus_mute(sfx, true)
	AudioServer.set_bus_mute(combat, true)
	var configured_mix: Array[Dictionary] = _mix_snapshot()
	manager = AUDIO_SCRIPT.new()
	root.add_child(manager)
	manager._ensure_audio_routes()
	manager._ensure_audio_routes()
	_check(_mix_snapshot() == configured_mix, "Repeated setup and private services preserve live gains, mute, sends and effect identities")
	_check(manager.get_active_voice_count() == 0 and manager._weighted_streams.size() == 9, "Weight synthesis is cached at startup without autoplay or layered voice nodes")
	var signatures: Array[int] = []
	for cue: StringName in manager.WEIGHTED_CUES:
		var stream: AudioStreamWAV = manager.get_weighted_cue_stream(cue)
		_check(stream != null and stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == 22050 and not stream.stereo and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s is a finite standard mono PCM stream" % cue)
		var stats: Dictionary = _pcm_stats(stream.data)
		_check(stream.get_length() >= 0.15 and stream.get_length() <= 0.43 and float(stats["rms"]) > 0.015 and float(stats["peak"]) <= 0.851 and stream.data.decode_s16(0) == 0 and stream.data.decode_s16(stream.data.size() - 2) == 0, "%s is audible, bounded and click-free at both endpoints" % cue)
		_check(manager.get_weighted_cue_stream(cue) == stream, "%s reuses a cached waveform for every attack" % cue)
		signatures.append(hash(stream.data))
	_check(not signatures.any(func(value: int) -> bool: return signatures.count(value) > 1), "Nine action and impact cues have distinct waveforms")
	var weighted_swing: AudioStreamWAV = manager.get_weighted_cue_stream(&"sword_swing")
	var old_swing: AudioStreamWAV = manager.get_cue_stream(&"sword_swing")
	var weighted_low: float = _low_band_energy(weighted_swing.data)
	var old_low: float = _low_band_energy(old_swing.data)
	_check(weighted_low > old_low * 2.0 and weighted_swing.data.size() == old_swing.data.size(), "A sword gains measurable low-frequency body without an extra emitter or longer action timing")
	var impact: AudioStreamWAV = manager.get_weighted_cue_stream(&"melee_impact")
	var boss_impact: AudioStreamWAV = manager.get_weighted_cue_stream(&"boss_impact")
	_check(_window_rms(impact.data, 0.05, 0.13) > 0.03 and boss_impact.get_length() > impact.get_length() and _window_rms(boss_impact.data, 0.16, 0.28) > 0.015, "Impact contains a bass tail, and boss impact has a distinct longer body")
	var room := Node2D.new()
	var other_room := Node2D.new()
	root.add_child(room)
	root.add_child(other_room)
	var voice: AudioStreamPlayer2D = manager.play_weighted_event(&"melee_impact", Vector2(320, 160), room)
	_check(voice != null and voice.bus == &"SFX_Combat" and voice.global_position == Vector2(320, 160) and voice.stream == impact and voice.max_polyphony == 1, "One spatial emitter carries the pre-mixed impact on the combat bus")
	var legacy_voice: AudioStreamPlayer2D = manager.play_event(&"swing", Vector2.ZERO, room)
	_check(legacy_voice != null and legacy_voice.bus == &"DungeonSFX" and legacy_voice.pitch_scale >= 0.9 and legacy_voice.pitch_scale <= 1.1 and legacy_voice.stream == old_swing, "Legacy callers retain exact cue, bus and pitch contracts")
	_check(manager.play_weighted_event(&"missing", Vector2.ZERO, room) == null and manager.play_weighted_event(&"jump", Vector2(INF, 0), room) == null, "Invalid weighted requests cannot create emitters")
	var pitches: Array[float] = []
	for index: int in range(160):
		voice = manager.play_weighted_event(&"boss_impact", Vector2(index, 0), room)
		pitches.append(voice.pitch_scale)
	_check(pitches.min() >= 0.88 and pitches.max() <= 1.12 and pitches.max() - pitches.min() > 0.18, "Weighted actions vary pitch across the requested bounded range")
	_check(manager.get_active_voice_count() == 16, "Legacy and weighted events share the same sixteen-voice ceiling")
	await _step(3)
	_check(manager.get_child_count() <= 16, "A mixed 160-event burst releases displaced emitter nodes")
	manager.stop_all()
	await _step(2)
	manager.play_weighted_event(&"landing", Vector2.ZERO, room)
	manager.play_weighted_event(&"boss_impact", Vector2.ZERO, other_room)
	manager.stop_owner(room)
	_check(manager.get_active_voice_count() == 1, "Stopping a room removes its weighted sounds without touching another room")
	other_room.queue_free()
	await _step(3)
	_check(manager.get_active_voice_count() == 0 and manager.get_child_count() == 0, "Deleting the other room clears emitter and scalar owner records")
	voice = manager.play_weighted_event(&"boss_impact", Vector2.ZERO, room)
	voice.stop()
	var original_time_scale: float = Engine.time_scale
	Engine.time_scale = 0.1
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 800:
		await process_frame
	Engine.time_scale = original_time_scale
	await _step(2)
	_check(manager.get_active_voice_count() == 0 and not is_instance_valid(voice), "Weighted audio expires in wall time during inventory slow motion even without finished")
	for cycle: int in range(10):
		var transient := Node2D.new()
		root.add_child(transient)
		for index: int in range(20):
			manager.play_weighted_event(&"jump" if index % 2 == 0 else &"melee_impact", Vector2.ZERO, transient)
		transient.queue_free()
		await _step(3)
	_check(manager.get_active_voice_count() == 0 and manager.get_child_count() == 0, "Ten mixed room churn cycles retain no voices or owner records")
	if OS.get_cmdline_user_args().has("--export-audio"):
		_export_preview()
	manager.play_weighted_event(&"boss_impact", Vector2.ZERO, room)
	await manager.shutdown()
	_check(not manager.enabled and manager.get_active_voice_count() == 0 and manager.play_weighted_event(&"jump", Vector2.ZERO, room) == null, "Mixer shutdown drains weighted sounds and rejects new requests")
	manager.queue_free()
	room.queue_free()
	await _step(3)
	_check(not is_instance_valid(manager) and _mix_snapshot() == configured_mix, "Private teardown preserves saved routes and live mixer settings")
	AudioServer.set_bus_volume_db(master, original_master_gain)
	AudioServer.set_bus_volume_db(sfx, original_sfx_gain)
	AudioServer.set_bus_mute(sfx, original_sfx_mute)
	AudioServer.set_bus_mute(combat, original_combat_mute)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _mix_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(AudioServer.bus_count):
		var effect_ids: Array[int] = []
		var effect_enabled: Array[bool] = []
		for slot: int in range(AudioServer.get_bus_effect_count(index)):
			effect_ids.append(AudioServer.get_bus_effect(index, slot).get_instance_id())
			effect_enabled.append(AudioServer.is_bus_effect_enabled(index, slot))
		result.append({"name": AudioServer.get_bus_name(index), "send": AudioServer.get_bus_send(index), "gain": AudioServer.get_bus_volume_db(index), "mute": AudioServer.is_bus_mute(index), "solo": AudioServer.is_bus_solo(index), "bypass": AudioServer.is_bus_bypassing_effects(index), "effects": effect_ids, "enabled": effect_enabled})
	return result


func _pcm_stats(pcm: PackedByteArray) -> Dictionary:
	var squared_sum: float = 0.0
	var peak: float = 0.0
	var count: int = int(pcm.size() * 0.5)
	for index: int in range(count):
		var sample: float = float(pcm.decode_s16(index * 2)) / 32767.0
		squared_sum += sample * sample
		peak = maxf(peak, absf(sample))
	return {"rms": sqrt(squared_sum / maxi(1, count)), "peak": peak}


func _window_rms(pcm: PackedByteArray, from_seconds: float, to_seconds: float) -> float:
	var squared_sum: float = 0.0
	var first: int = int(from_seconds * 22050)
	var last: int = mini(int(to_seconds * 22050), int(pcm.size() * 0.5))
	for index: int in range(first, last):
		var sample: float = float(pcm.decode_s16(index * 2)) / 32767.0
		squared_sum += sample * sample
	return sqrt(squared_sum / maxi(1, last - first))


func _low_band_energy(pcm: PackedByteArray) -> float:
	# A small deterministic DFT measurement of body frequencies, not a replica
	# of the synthesis formula. Original sword noise remains the control cue.
	var count: int = mini(2646, int(pcm.size() * 0.5))
	var energy: float = 0.0
	for frequency: float in [50.0, 75.0, 100.0, 125.0, 150.0, 175.0]:
		var real_part: float = 0.0
		var imaginary_part: float = 0.0
		for index: int in range(count):
			var sample: float = float(pcm.decode_s16(index * 2)) / 32767.0
			var angle: float = TAU * frequency * float(index) / 22050.0
			real_part += sample * cos(angle)
			imaginary_part += sample * sin(angle)
		energy += (real_part * real_part + imaginary_part * imaginary_part) / float(count * count)
	return energy


func _export_preview() -> void:
	var montage := PackedByteArray()
	var silence := PackedByteArray()
	silence.resize(7718 * 2)
	silence.fill(0)
	for cue: StringName in manager.WEIGHTED_CUES:
		montage.append_array(manager.get_weighted_cue_stream(cue).data)
		montage.append_array(silence)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = montage
	var error: Error = stream.save_to_wav("res://docs/verification/weighted_sfx_preview.wav")
	print("WEIGHTED AUDIO PREVIEW: save status %d, %.2f seconds" % [error, stream.get_length()])


func _step(frames: int) -> void:
	for frame: int in range(frames):
		await physics_frame
		await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

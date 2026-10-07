extends Node
## Offline, one-shot spatial SFX. Runtime voices hold owner IDs, never room Nodes.

signal shutdown_complete

const SAMPLE_RATE: int = 22050
const CUES: Array[StringName] = [&"sword_swing", &"dash", &"spell_explosion", &"aggro", &"hurt"]
const CUE_SECONDS: Dictionary = {
	&"sword_swing": 0.19, &"dash": 0.24, &"spell_explosion": 0.42,
	&"aggro": 0.35, &"hurt": 0.16,
}
const CUE_DB: Dictionary = {
	&"sword_swing": -3.0, &"dash": -5.0, &"spell_explosion": -2.0,
	&"aggro": -5.0, &"hurt": -4.0,
}
const WEIGHTED_CUES: Array[StringName] = [
	&"sword_swing", &"dash", &"spell_explosion", &"aggro", &"hurt",
	&"jump", &"landing", &"melee_impact", &"boss_impact",
]
const WEIGHTED_SECONDS: Dictionary = {
	&"jump": 0.16, &"landing": 0.20, &"melee_impact": 0.24, &"boss_impact": 0.40,
}
const WEIGHTED_DB: Dictionary = {
	&"sword_swing": -3.0, &"dash": -5.0, &"spell_explosion": -2.0,
	&"aggro": -5.0, &"hurt": -4.0, &"jump": -5.0, &"landing": -4.0,
	&"melee_impact": -2.0, &"boss_impact": -1.0,
}
const COMBAT_BUS: StringName = &"SFX_Combat"
const FIRE_AMBIENT_BUS: StringName = &"Ambient"
const FIRE_SECONDS: float = 2.4

@export_range(1, 32, 1) var max_voices: int = 16
@export var bus_name: StringName = &"DungeonSFX"
@export_range(-40.0, 0.0, 1.0) var bus_volume_db: float = -10.0
@export var enabled: bool = true

var _streams: Dictionary = {}
var _weighted_streams: Dictionary = {}
var _fire_stream: AudioStreamWAV
var _voices: Dictionary = {}
var _next_voice_id: int = 1
var _created_bus: bool = false
var _created_route_names: Array[StringName] = []
var _installed_master_limiter: AudioEffectHardLimiter
var _pitch_rng := RandomNumberGenerator.new()
var _handles_window_quit: bool = false
var _previous_auto_accept_quit: bool = true
var _quit_requested: bool = false
var _external_bank := PilgrimageSoundBank.new()
var _material_hits: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pitch_rng.randomize()
	# Only the actual autoload owns the application's close policy. A private
	# test/service instance cannot intercept the scene tree's quit requests.
	_handles_window_quit = get_path() == NodePath("/root/AudioManager")
	if _handles_window_quit:
		_previous_auto_accept_quit = get_tree().auto_accept_quit
		get_tree().auto_accept_quit = false
		_ensure_audio_routes()
	_ensure_bus()
	for cue: StringName in CUES:
		_streams[cue] = _synthesize(cue)
	for cue: StringName in WEIGHTED_CUES:
		_weighted_streams[cue] = _synthesize_weighted(cue)
	_fire_stream = _synthesize_fire()


func _process(_delta: float) -> void:
	_prune_voices()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _handles_window_quit:
		request_quit()


func request_quit() -> void:
	if _quit_requested or not is_inside_tree():
		return
	_quit_requested = true
	await shutdown()
	if is_inside_tree():
		get_tree().quit()


func play_event(kind: StringName, origin: Vector2, lifetime_owner: Node = null) -> AudioStreamPlayer2D:
	var cue: StringName = _canonical_cue(kind)
	if not _streams.has(cue):
		return null
	return _play_voice(cue, _streams[cue] as AudioStreamWAV, origin, lifetime_owner, bus_name, 0.9, 1.1, float(CUE_DB[cue]))


func play_weighted_event(kind: StringName, origin: Vector2, lifetime_owner: Node = null) -> AudioStreamPlayer2D:
	# The legacy API retains its exact pitch/bus contract. New presentation hooks
	# use click + body PCM mixed once at startup, still only one capped emitter.
	var cue: StringName = _canonical_cue(kind)
	if not _weighted_streams.has(cue):
		return null
	var route: StringName = COMBAT_BUS if AudioServer.get_bus_index(COMBAT_BUS) >= 0 else bus_name
	return _play_voice(cue, _weighted_streams[cue] as AudioStreamWAV, origin, lifetime_owner, route, 0.88, 1.12, float(WEIGHTED_DB[cue]))


func play_fire_ambience(origin: Vector2, lifetime_owner: Node = null) -> AudioStreamPlayer2D:
	# A finite spatial segment; the nearby campfire adapter owns renewal. Keep
	# it off combat cue lists and respect the existing Ambient mixer settings.
	if AudioServer.get_bus_index(FIRE_AMBIENT_BUS) < 0:
		return null
	return _play_voice(&"fire_crackle", _fire_stream, origin, lifetime_owner, FIRE_AMBIENT_BUS, 0.96, 1.04, -7.0, 380.0, 1.6)


func get_fire_stream() -> AudioStreamWAV:
	return _fire_stream

func play_external_event(kind: StringName, origin: Vector2, lifetime_owner: Node, allow_candidate: bool = false) -> AudioStreamPlayer2D:
	if not enabled or not is_inside_tree() or not origin.is_finite() or not is_instance_valid(lifetime_owner) or not lifetime_owner.is_inside_tree(): return null
	var spec: Dictionary = _external_bank.definition(kind,allow_candidate)
	if spec.is_empty(): return null
	var route: StringName = spec["bus"]
	if AudioServer.get_bus_index(route) < 0: return null
	var priority: int = 90 if kind == &"parry.metal" else 65 if kind == &"contact.metal" else 10 if route == FIRE_AMBIENT_BUS else 20
	return _play_voice(kind,_external_bank.pick(kind,_pitch_rng),origin,lifetime_owner,route,1.0,1.0,spec["gain"],2400.0 if kind == &"wind" else 900.0,1.35,priority)

func play_material_result(material: StringName, outcome: StringName, hit_token: int, origin: Vector2, lifetime_owner: Node) -> AudioStreamPlayer2D:
	# Caller passes the resolved outcome, never an animation or speculative block.
	if not enabled or not is_inside_tree() or not origin.is_finite() or material != &"metal" or outcome not in [&"contact",&"parry"] or hit_token <= 0 or not is_instance_valid(lifetime_owner) or not lifetime_owner.is_inside_tree(): return null
	_prune_voices()
	var key: String = "%d:%d" % [lifetime_owner.get_instance_id(),hit_token]
	if _material_hits.has(key):
		var previous: Dictionary = _material_hits[key]
		if previous["outcome"] == &"parry" or outcome == &"contact": return null
		_release_voice(int(previous["voice_id"])) # Parry replaces a queued contact.
	var voice: AudioStreamPlayer2D = play_external_event(StringName(String(outcome)+".metal"),origin,lifetime_owner)
	if voice != null:
		while _material_hits.size() >= 128: _material_hits.erase(_material_hits.keys()[0])
		_material_hits[key] = {"outcome":outcome,"owner_id":lifetime_owner.get_instance_id(),"voice_id":_next_voice_id-1,"expires":Time.get_ticks_msec()+4000}
	return voice

func _play_voice(cue: StringName, stream: AudioStream, origin: Vector2, lifetime_owner: Node, route: StringName, pitch_min: float, pitch_max: float, volume_db: float, audible_distance: float = 1350.0, distance_attenuation: float = 1.35, priority: int = 50) -> AudioStreamPlayer2D:
	if not enabled or not is_inside_tree() or stream == null or not origin.is_finite():
		return null
	if lifetime_owner != null and (not is_instance_valid(lifetime_owner) or not lifetime_owner.is_inside_tree()):
		return null
	_prune_voices()
	while _voices.size() >= maxi(1, max_voices):
		var victim: int = int(_voices.keys()[0])
		for candidate: int in _voices:
			if int(_voices[candidate]["priority"]) < int(_voices[victim]["priority"]): victim = candidate
		if priority < int(_voices[victim]["priority"]): return null
		_release_voice(victim)
	var voice_id: int = _next_voice_id
	_next_voice_id += 1
	var voice := AudioStreamPlayer2D.new()
	voice.name = "SFX_%s_%d" % [cue, voice_id]
	voice.stream = stream
	voice.bus = route
	voice.volume_db = volume_db
	voice.pitch_scale = _pitch_rng.randf_range(pitch_min, pitch_max)
	voice.max_distance = audible_distance
	voice.attenuation = distance_attenuation
	voice.panning_strength = 0.65
	voice.max_polyphony = 1
	voice.autoplay = false
	add_child(voice)
	voice.global_position = origin
	var lifetime_msec: int = ceili(1000.0 * voice.stream.get_length() / voice.pitch_scale) + 200
	_voices[voice_id] = {
		"player": voice,
		"owner_id": lifetime_owner.get_instance_id() if lifetime_owner != null else 0,
		"deadline": Time.get_ticks_msec() + lifetime_msec,
		"priority":priority,
	}
	voice.finished.connect(_on_voice_finished.bind(voice_id), CONNECT_ONE_SHOT)
	# Dummy/headless has no output device. Keep the emitter lifetime observable,
	# but do not allocate decoder playback objects for a mixer that cannot play.
	if AudioServer.get_driver_name() != "Dummy":
		voice.play()
	return voice


func stop_owner(lifetime_owner: Node) -> void:
	if not is_instance_valid(lifetime_owner):
		return
	var owner_id: int = lifetime_owner.get_instance_id()
	for key: String in _material_hits.keys():
		if _material_hits[key]["owner_id"] == owner_id: _material_hits.erase(key)
	for voice_id: int in _voices.keys():
		if int(_voices[voice_id]["owner_id"]) == owner_id:
			_release_voice(voice_id)


func stop_all() -> void:
	_material_hits.clear()
	for voice_id: int in _voices.keys():
		_release_voice(voice_id)


func shutdown() -> void:
	# A real audio mixer runs on its own thread and releases stopped playbacks
	# on a mix boundary. Call this before quitting while an SFX is still playing.
	enabled = false
	stop_all()
	if is_inside_tree() and AudioServer.get_driver_name() != "Dummy":
		var deadline: int = Time.get_ticks_msec() + ceili(1000.0 * maxf(0.08, AudioServer.get_output_latency() * 2.0))
		while is_inside_tree() and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
	shutdown_complete.emit()


func get_active_voice_count() -> int:
	_prune_voices()
	return _voices.size()


func get_cue_stream(kind: StringName) -> AudioStreamWAV:
	return _streams.get(_canonical_cue(kind)) as AudioStreamWAV


func get_weighted_cue_stream(kind: StringName) -> AudioStreamWAV:
	return _weighted_streams.get(_canonical_cue(kind)) as AudioStreamWAV


func _canonical_cue(kind: StringName) -> StringName:
	if kind == &"swing":
		return &"sword_swing"
	if kind == &"spell":
		return &"spell_explosion"
	return kind


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var bus_index: int = AudioServer.bus_count
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, COMBAT_BUS if AudioServer.get_bus_index(COMBAT_BUS) >= 0 else &"Master")
	AudioServer.set_bus_volume_db(bus_index, bus_volume_db)
	_created_bus = true
	_created_route_names.append(bus_name)


func _ensure_audio_routes() -> void:
	# The configured layout normally supplies these. Fallback only adds missing
	# buses and a missing safety stage; never resets live mute/gain/send/effects.
	_add_missing_route(&"SFX", &"Master", -10.0)
	_add_missing_route(COMBAT_BUS, &"SFX", 0.0)
	_add_missing_route(&"Ambient", &"Master", -18.0)
	var master: int = AudioServer.get_bus_index(&"Master")
	if master < 0:
		return
	for index: int in range(AudioServer.get_bus_effect_count(master)):
		var effect: AudioEffect = AudioServer.get_bus_effect(master, index)
		if effect is AudioEffectHardLimiter or effect is AudioEffectCompressor or effect.is_class("AudioEffectLimiter"):
			return
	_installed_master_limiter = AudioEffectHardLimiter.new()
	_installed_master_limiter.ceiling_db = -0.8
	_installed_master_limiter.pre_gain_db = 0.0
	_installed_master_limiter.release = 0.09
	AudioServer.add_bus_effect(master, _installed_master_limiter)


func _add_missing_route(route: StringName, send: StringName, volume_db: float) -> void:
	if AudioServer.get_bus_index(route) >= 0:
		return
	var index: int = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, route)
	AudioServer.set_bus_send(index, send)
	AudioServer.set_bus_volume_db(index, volume_db)
	_created_route_names.append(route)


func _prune_voices() -> void:
	var now: int = Time.get_ticks_msec()
	for key: String in _material_hits.keys():
		if now >= int(_material_hits[key]["expires"]) or not is_instance_id_valid(int(_material_hits[key]["owner_id"])): _material_hits.erase(key)
	for voice_id: int in _voices.keys():
		var record: Dictionary = _voices[voice_id]
		var voice: AudioStreamPlayer2D = record["player"] as AudioStreamPlayer2D
		var owner_id: int = int(record["owner_id"])
		var lifetime_owner: Object = instance_from_id(owner_id) if owner_id != 0 else null
		var owner_gone: bool = owner_id != 0 and (
			not is_instance_valid(lifetime_owner) or not lifetime_owner is Node
			or not (lifetime_owner as Node).is_inside_tree()
		)
		if owner_gone or not is_instance_valid(voice) or now >= int(record["deadline"]):
			_release_voice(voice_id)


func _on_voice_finished(voice_id: int) -> void:
	_release_voice(voice_id)


func _release_voice(voice_id: int) -> void:
	if not _voices.has(voice_id):
		return
	var voice: AudioStreamPlayer2D = _voices[voice_id]["player"] as AudioStreamPlayer2D
	_voices.erase(voice_id)
	if is_instance_valid(voice):
		voice.stop()
		voice.stream = null
		voice.queue_free()


func _exit_tree() -> void:
	stop_all()
	_streams.clear()
	_weighted_streams.clear()
	_fire_stream = null
	if _handles_window_quit:
		get_tree().auto_accept_quit = _previous_auto_accept_quit
	_handles_window_quit = false
	# Remove only additions owned by this instance. Saved/user buses survive.
	for index: int in range(_created_route_names.size() - 1, -1, -1):
		var route: StringName = _created_route_names[index]
		var bus_index: int = AudioServer.get_bus_index(route)
		if bus_index >= 0:
			AudioServer.remove_bus(bus_index)
	_created_route_names.clear()
	if _installed_master_limiter != null:
		var master: int = AudioServer.get_bus_index(&"Master")
		if master >= 0:
			for index: int in range(AudioServer.get_bus_effect_count(master) - 1, -1, -1):
				if AudioServer.get_bus_effect(master, index) == _installed_master_limiter:
					AudioServer.remove_bus_effect(master, index)
		_installed_master_limiter = null
	_created_bus = false


func _synthesize_fire() -> AudioStreamWAV:
	var sample_count: int = ceili(FIRE_SECONDS * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var fire_rng := RandomNumberGenerator.new()
	fire_rng.seed = 617203
	var warm_noise: float = 0.0
	var body_noise: float = 0.0
	var pop_energy: float = 0.0
	for index: int in range(sample_count):
		var time: float = float(index) / SAMPLE_RATE
		var noise: float = fire_rng.randf_range(-1.0, 1.0)
		warm_noise = lerpf(warm_noise, noise, 0.015)
		body_noise = lerpf(body_noise, noise, 0.06)
		pop_energy *= 0.992
		if fire_rng.randf() < 0.0006:
			pop_energy = maxf(pop_energy, fire_rng.randf_range(0.10, 0.34))
		var breathing: float = 0.82 + sin(time * 2.3) * 0.12 + sin(time * 7.2) * 0.06
		var value: float = (warm_noise * 0.6 + body_noise * 0.25 + (noise - body_noise) * (0.012 + pop_energy)) * breathing
		var fade_in: float = clampf(time / 0.09, 0.0, 1.0)
		var fade_out: float = clampf((FIRE_SECONDS - time - 1.0 / SAMPLE_RATE) / 0.12, 0.0, 1.0)
		pcm.encode_s16(index * 2, roundi(clampf(value * fade_in * fade_out, -0.7, 0.7) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = pcm
	return stream


func _synthesize(cue: StringName) -> AudioStreamWAV:
	var duration: float = float(CUE_SECONDS[cue])
	var sample_count: int = ceili(duration * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = int(CUES.find(cue) + 1) * 94531
	var filtered_noise: float = 0.0
	var phase: float = 0.0
	for index: int in range(sample_count):
		var time: float = float(index) / SAMPLE_RATE
		var progress: float = float(index) / float(sample_count - 1)
		var noise: float = noise_rng.randf_range(-1.0, 1.0)
		filtered_noise = lerpf(filtered_noise, noise, 0.21)
		var attack: float = clampf(time / 0.006, 0.0, 1.0)
		var tail: float = clampf((duration - time - 1.0 / SAMPLE_RATE) / 0.025, 0.0, 1.0)
		var envelope: float = attack * tail * pow(1.0 - progress, 1.2)
		var value: float = 0.0
		match cue:
			&"sword_swing":
				phase += TAU * lerpf(1250.0, 230.0, progress) / SAMPLE_RATE
				value = (noise - filtered_noise) * 0.5 + sin(phase) * 0.12
			&"dash":
				phase += TAU * lerpf(430.0, 90.0, progress) / SAMPLE_RATE
				value = filtered_noise * 0.9 + sin(phase) * 0.1
			&"spell_explosion":
				phase += TAU * lerpf(185.0, 48.0, progress) / SAMPLE_RATE
				value = sin(phase) * 0.47 + filtered_noise * 0.7 + noise * 0.12 * exp(-time * 35.0)
			&"aggro":
				phase += TAU * (lerpf(150.0, 80.0, progress) + sin(time * 70.0) * 13.0) / SAMPLE_RATE
				value = sin(phase) * 0.37 + sin(phase * 2.07) * 0.15 + filtered_noise * 0.35
			&"hurt":
				phase += TAU * lerpf(410.0, 120.0, progress) / SAMPLE_RATE
				value = sin(phase) * 0.3 + noise * 0.35 * exp(-time * 20.0)
		var sample: int = roundi(clampf(value * envelope, -0.85, 0.85) * 32767.0)
		pcm.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = pcm
	return stream


func _synthesize_weighted(cue: StringName) -> AudioStreamWAV:
	if cue == &"dash" or cue == &"aggro":
		return _streams[cue] as AudioStreamWAV
	var base: AudioStreamWAV = _streams.get(cue) as AudioStreamWAV
	var base_pcm: PackedByteArray = base.data if base != null else PackedByteArray()
	var duration: float = base.get_length() if base != null else float(WEIGHTED_SECONDS[cue])
	var sample_count: int = int(base_pcm.size() * 0.5) if base != null else ceili(duration * SAMPLE_RATE)
	var values := PackedFloat32Array()
	values.resize(sample_count)
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = (WEIGHTED_CUES.find(cue) + 1) * 83177
	var phase: float = 0.0
	var filtered_noise: float = 0.0
	var peak: float = 0.0
	for index: int in range(sample_count):
		var time: float = float(index) / SAMPLE_RATE
		var progress: float = float(index) / float(sample_count - 1)
		var noise: float = noise_rng.randf_range(-1.0, 1.0)
		filtered_noise = lerpf(filtered_noise, noise, 0.18)
		var body: float = 0.0
		var frequency: float = 95.0
		var body_gain: float = 0.28
		var decay: float = 24.0
		var click_gain: float = 0.13
		match cue:
			&"spell_explosion":
				frequency = 75.0
				body_gain = 0.16
				decay = 12.0
			&"hurt":
				frequency = 110.0
				body_gain = 0.26
				decay = 23.0
			&"jump":
				frequency = 310.0
				body_gain = 0.24
				decay = 19.0
				click_gain = 0.08
			&"landing":
				frequency = 80.0
				body_gain = 0.40
				decay = 21.0
				click_gain = 0.30
			&"melee_impact":
				frequency = 125.0
				body_gain = 0.58
				decay = 14.0
				click_gain = 0.38
			&"boss_impact":
				frequency = 100.0
				body_gain = 0.72
				decay = 8.0
				click_gain = 0.42
		phase += TAU * lerpf(frequency, frequency * 0.36, progress) / SAMPLE_RATE
		body = sin(phase) * body_gain * exp(-time * decay)
		body += noise * click_gain * exp(-time * 55.0)
		body += filtered_noise * 0.16 * exp(-time * 24.0)
		var envelope: float = clampf(time / 0.0025, 0.0, 1.0) * clampf((duration - time - 1.0 / SAMPLE_RATE) / 0.016, 0.0, 1.0)
		var value: float = body * envelope
		if base != null:
			value += float(base_pcm.decode_s16(index * 2)) / 32767.0
		values[index] = value
		peak = maxf(peak, absf(value))
	# Normalize the pre-mixed transient rather than clipping individual layers.
	var normalization: float = minf(1.0, 0.80 / maxf(peak, 0.001))
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	for index: int in range(sample_count):
		pcm.encode_s16(index * 2, roundi(values[index] * normalization * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = pcm
	return stream

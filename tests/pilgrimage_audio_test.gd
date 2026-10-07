extends SceneTree
## Real bank bytes/cadence, explicit approval gates, shared mixer and room cleanup.
const MANAGER: GDScript = preload("res://scripts/audio/audio_manager.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	AudioServer.set_bus_mute(0,true)
	var manager: Node = MANAGER.new()
	root.add_child(manager)
	var room := Node2D.new()
	root.add_child(room)
	var mixer_before: Array = _mixer()
	manager._ensure_audio_routes()
	manager._ensure_audio_routes()
	_check(_mixer() == mixer_before,"Repeated audio setup preserves every existing gain/mute/send/effect")
	for kind: StringName in [&"contact.metal",&"parry.metal"]:
		var previous: AudioStream
		for index: int in 8:
			var voice: AudioStreamPlayer2D = manager.play_external_event(kind,Vector2(10,20),room)
			var wave := voice.stream as AudioStreamWAV
			_check(wave != null and wave.format == AudioStreamWAV.FORMAT_16_BITS and wave.mix_rate == 44100 and not wave.stereo and wave.loop_mode == AudioStreamWAV.LOOP_DISABLED,"Selected A is original finite mono PCM16 at 44.1kHz")
			_check(wave.data == _source_pcm(wave.resource_path),"Engine decodes the exact selected source PCM without normalization or lossy compression")
			_check(voice.bus == &"SFX_Combat" and voice.pitch_scale == 1 and voice.volume_db == 0 and voice.stream != previous,"Selected A keeps pitch/gain and avoids the previous take")
			previous = voice.stream
		manager.stop_all()
	_check(manager.play_external_event(&"wind",Vector2.ZERO,room) == null and manager.play_external_event(&"footstep.stone",Vector2.ZERO,room) == null,"Unselected outdoor samples are gated off by default")
	_check(manager.play_external_event(&"block.metal",Vector2.ZERO,room,true) == null and manager.play_external_event(&"voice",Vector2.ZERO,room,true) == null,"Block alias, rejected v1 and unapproved vocal cannot play")
	_check(manager.play_external_event(&"contact.metal",Vector2(INF,0),room) == null and manager.play_external_event(&"contact.metal",Vector2.ZERO,null) == null,"Invalid position and missing lifetime owner allocate no voice")
	var hit: AudioStreamPlayer2D = manager.play_material_result(&"metal",&"contact",100,Vector2.ZERO,room)
	_check(hit != null and manager.get_active_voice_count() == 1,"One resolved metal contact emits one owned voice")
	_check(manager.play_material_result(&"metal",&"contact",100,Vector2.ZERO,room) == null and manager.get_active_voice_count() == 1,"Repeated hit callback cannot stack contact")
	_check(manager.play_material_result(&"metal",&"parry",100,Vector2(INF,0),room) == null and hit.stream != null,"An invalid replacement preserves the valid contact")
	var parry: AudioStreamPlayer2D = manager.play_material_result(&"metal",&"parry",100,Vector2.ZERO,room)
	_check(parry != null and hit.stream == null and manager.get_active_voice_count() == 1,"Resolved parry replaces queued contact instead of stacking")
	_check(manager.play_material_result(&"metal",&"contact",100,Vector2.ZERO,room) == null and manager.play_material_result(&"metal",&"parry",100,Vector2.ZERO,room) == null,"Parry outcome remains idempotent")
	for index: int in 64: manager.play_external_event(&"footstep.stone",Vector2.ZERO,room,true)
	_check(manager.get_active_voice_count() == 16 and parry.stream != null,"Shared sixteen-voice budget preserves higher priority parry during foley bursts")
	await _step(3)
	_check(manager.get_child_count() <= 16,"Displaced external emitters release their nodes")
	manager.stop_owner(room)
	_check(manager.get_active_voice_count() == 0 and manager._material_hits.is_empty(),"Owner stop clears voices and scalar hit deduplication")
	var wind: AudioStreamPlayer2D = manager.play_external_event(&"wind",Vector2.ZERO,room,true)
	_check(wind != null and wind.bus == &"Ambient" and wind.stream.get_length() > 0 and manager._voices.values()[0]["deadline"] > Time.get_ticks_msec(),"Explicit outdoor audition has a finite owner/deadline on Ambient")
	room.queue_free()
	await _step(3)
	_check(manager.get_active_voice_count() == 0,"Owner teardown stops decoded samples and ambience")
	manager.queue_free()
	await _step(3)
	await _cadence()
	print("RESULT PilgrimageAudio %d checks, %d failures; physics_hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

func _cadence() -> void:
	var flow := preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/field_audio_%d.json" % Time.get_ticks_usec()
	root.add_child(flow)
	current_scene = flow
	await _step(8)
	var hub := flow.active_scene as ExteriorHub
	hub.enter_exterior(&"o01_p01")
	await _step(5)
	var field := hub.exterior.get_node("PilgrimagePresentation/PilgrimageAudio") as PilgrimageAudio
	_check(not field.candidate_mix_enabled and field.emitted_ambient == 0 and field.emitted_steps == 0,"Real P01 does not silently enable unselected audio candidates")
	field.set_candidate_mix(true)
	await _step(4)
	var before: int = field.emitted_steps
	Input.action_press(&"move_right")
	await _step(Engine.physics_ticks_per_second)
	Input.action_release(&"move_right")
	await _step(4)
	_check(field.emitted_steps > before and field.emitted_ambient == 1,"Actual grounded input walk emits distance-based steps and one finite wind segment")
	await _step(ceili(Engine.physics_ticks_per_second*0.25))
	_check(absf(hub.player.velocity.x) < 0.1 and hub.player.motor.is_grounded(),"Release settles through the actual motor deceleration at either physics rate")
	before = field.emitted_steps
	await _step(12)
	_check(field.emitted_steps == before,"Stationary actor emits no periodic step")
	PlayerTravel.relocate(hub.player,ExteriorHub.ORIGIN+Vector2(1380,hub.exterior.floor_y(1380)))
	await _step(5)
	_check(field.emitted_steps == before,"Room relocation emits no fictitious walking sound")
	hub.gear.modal.open()
	await _step(4)
	_check(field.emitted_steps == before and field.wind_voice == null,"Inventory pauses field footsteps and stops owned ambience")
	hub.gear.modal.close()
	field.set_candidate_mix(false)
	var weak_field: WeakRef = weakref(field)
	hub.enter_exterior(&"o01_p02")
	await _step(5)
	_check(weak_field.get_ref() == null,"Adjacent-room travel releases audio adapter and signal ownership")
	flow.queue_free()
	await _step(5)
	var global_audio: Node = root.get_node("AudioManager")
	global_audio.stop_all()
	_check(global_audio.get_active_voice_count() == 0,"Final teardown leaves no field/NPC voices")

func _mixer() -> Array:
	var rows: Array = []
	for index: int in AudioServer.bus_count:
		var effects: Array = []
		for effect: int in AudioServer.get_bus_effect_count(index): effects.append(AudioServer.get_bus_effect(index,effect).get_instance_id())
		rows.append([AudioServer.get_bus_name(index),AudioServer.get_bus_volume_db(index),AudioServer.is_bus_mute(index),AudioServer.get_bus_send(index),effects])
	return rows

func _source_pcm(path: String) -> PackedByteArray:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var offset: int = 12
	while offset+8 <= bytes.size():
		var count: int = bytes.decode_u32(offset+4)
		if bytes.slice(offset,offset+4).get_string_from_ascii() == "data": return bytes.slice(offset+8,offset+8+count)
		offset += 8+count+(count % 2)
	return PackedByteArray()

func _step(count: int) -> void:
	for tick: int in count: await physics_frame

func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		print("FAIL: "+message)

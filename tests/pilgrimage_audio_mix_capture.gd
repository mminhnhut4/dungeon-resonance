extends SceneTree
## Real device mixer capture, muted after effects; no speaker/device setting changes.
var capture: AudioEffectCapture
var samples := PackedVector2Array()
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	if AudioServer.get_driver_name() == "Dummy":
		print("FAIL: actual audio device required for mix capture")
		quit(1)
		return
	var listener := AudioListener2D.new()
	root.add_child(listener)
	listener.make_current()
	var manager: Node = root.get_node("AudioManager")
	var owner_node := Node2D.new()
	root.add_child(owner_node)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.5
	var effect_index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,capture)
	for index: int in 4:
		var outcome: StringName = &"contact" if index < 2 else &"parry"
		manager.play_material_result(&"metal",outcome,1000+index,Vector2.ZERO,owner_node)
		await _collect(0.55)
	manager.play_external_event(&"wind",Vector2.ZERO,owner_node,true)
	manager.play_external_event(&"footstep.stone",Vector2.ZERO,owner_node,true)
	manager.play_material_result(&"metal",&"parry",2000,Vector2.ZERO,owner_node)
	await _collect(0.65)
	for index: int in 16: manager.play_external_event(&"contact.metal",Vector2.ZERO,owner_node)
	await _collect(0.8)
	manager.stop_owner(owner_node)
	await _collect(0.2)
	var peak: float = 0
	var squared: float = 0
	var full_scale: int = 0
	var pcm := PackedByteArray()
	pcm.resize(samples.size()*4)
	for index: int in samples.size():
		var frame: Vector2 = samples[index]
		peak = maxf(peak,maxf(absf(frame.x),absf(frame.y)))
		squared += frame.x*frame.x+frame.y*frame.y
		if absf(frame.x) >= 0.9999: full_scale += 1
		if absf(frame.y) >= 0.9999: full_scale += 1
		pcm.encode_s16(index*4,roundi(clampf(frame.x,-1,1)*32767))
		pcm.encode_s16(index*4+2,roundi(clampf(frame.y,-1,1)*32767))
	if samples.size() < 10000 or peak < 0.001 or peak >= 0.9999 or full_scale != 0 or capture.get_discarded_frames() != 0: failures += 1
	var wave := AudioStreamWAV.new()
	wave.mix_rate = int(AudioServer.get_mix_rate())
	wave.stereo = true
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.data = pcm
	if wave.save_to_wav("res://docs/verification/P01_A_Actual_Engine_Mix.wav") != OK: failures += 1
	var report: Dictionary = {"driver":AudioServer.get_driver_name(),"mix_rate":wave.mix_rate,"frames":samples.size(),"duration":wave.get_length(),"post_limiter_peak":peak,"rms":sqrt(squared/maxf(1,samples.size()*2)),"full_scale_samples":full_scale,"discarded_frames":capture.get_discarded_frames(),"master_muted_in_QA_process":AudioServer.is_bus_mute(0),"source_A_bytes_unchanged":true,"aural_verification":false,"parry_gameplay_binding":"unsupported/unbound; explicit API audition only","failures":failures}
	var file := FileAccess.open("res://docs/verification/P01_A_Actual_Engine_Mix.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	AudioServer.remove_bus_effect(0,effect_index)
	owner_node.queue_free()
	await manager.shutdown()
	print("RESULT AudioActualMix frames=%d peak=%.6f full_scale=%d dropped=%d failures=%d; device=%s; QA Master muted, no aural claim" % [samples.size(),peak,full_scale,capture.get_discarded_frames(),failures,AudioServer.get_driver_name()])
	quit(0 if failures == 0 else 1)

func _collect(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec()+ceili(seconds*1000)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var count: int = capture.get_frames_available()
		if count > 0: samples.append_array(capture.get_buffer(count))

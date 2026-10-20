extends Node
## QA only: native viewport and this Godot process's Master mix, normal wall time.
## No MovieMaker/fixed delta, OS screen capture, microphone or system loopback.
var folder: String
var started: int=0
var last_capture: int=0
var frames: Array[Dictionary]=[]
var stages: Array[Dictionary]=[]
var capturing: bool=false
var mix: AudioEffectCapture
var samples:=PackedVector2Array()
var effect_index: int=-1
var first_audio_usec: int=0
var stream: FileAccess
var capture_errors: int=0

func begin(path: String) -> void:
	folder=path
	DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
	stream=FileAccess.open(folder.path_join("frame-times.csv"),FileAccess.WRITE);stream.store_line("frame,wall_usec,file")
	mix=AudioEffectCapture.new();mix.buffer_length=3.0
	effect_index=AudioServer.get_bus_effect_count(0);AudioServer.add_bus_effect(0,mix)
	started=Time.get_ticks_usec();capturing=true
	RenderingServer.frame_post_draw.connect(_frame)

func mark(label: String) -> void:
	var item: Dictionary={"label":label,"elapsed":(Time.get_ticks_usec()-started)/1000000.0,"captured_frames":frames.size()}
	stages.append(item);print("NEWCOMER_STAGE "+JSON.stringify(item))

func _process(_delta: float) -> void:
	if capturing:_audio()

func _audio() -> void:
	var available: int=mix.get_frames_available()
	if available<=0:return
	if first_audio_usec==0:first_audio_usec=Time.get_ticks_usec()-roundi(available*1000000.0/AudioServer.get_mix_rate())
	samples.append_array(mix.get_buffer(available))

func _frame() -> void:
	if not capturing:return
	var now: int=Time.get_ticks_usec()
	if now-last_capture<50000:return
	last_capture=now
	var name: String="frames/frame-%06d.jpg"%frames.size()
	var image: Image=get_viewport().get_texture().get_image()
	if image.save_jpg(folder.path_join(name),.95)!=OK:capture_errors+=1
	frames.append({"wall_usec":now-started,"file":name})
	stream.store_line("%d,%d,%s"%[frames.size()-1,now-started,name])
	if frames.size()%20==0:stream.flush()

func finish() -> Dictionary:
	capturing=false
	if RenderingServer.frame_post_draw.is_connected(_frame):RenderingServer.frame_post_draw.disconnect(_frame)
	_audio();var ended: int=Time.get_ticks_usec()
	var peak: float=0;var squared: float=0;var full_scale: int=0
	var pcm:=PackedByteArray();pcm.resize(samples.size()*4)
	for i: int in samples.size():
		var sample: Vector2=samples[i];peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)));squared+=sample.x*sample.x+sample.y*sample.y
		if absf(sample.x)>=.9999:full_scale+=1
		if absf(sample.y)>=.9999:full_scale+=1
		pcm.encode_s16(i*4,roundi(clampf(sample.x,-1,1)*32767));pcm.encode_s16(i*4+2,roundi(clampf(sample.y,-1,1)*32767))
	var wav:=AudioStreamWAV.new();wav.mix_rate=int(AudioServer.get_mix_rate());wav.stereo=true;wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.data=pcm
	var audio_saved: bool=wav.save_to_wav(folder.path_join("game-master.wav"))==OK
	var result: Dictionary={"wall_seconds":(ended-started)/1000000.0,"frames":frames,"stages":stages,"capture_errors":capture_errors,"audio":{"driver":AudioServer.get_driver_name(),"mix_rate":wav.mix_rate,"frames":samples.size(),"seconds":float(samples.size())/wav.mix_rate,"start_offset":(first_audio_usec-started)/1000000.0,"peak":peak,"rms":sqrt(squared/maxi(1,samples.size()*2)),"full_scale_samples":full_scale,"discarded_frames":mix.get_discarded_frames(),"saved":audio_saved,"source":"Only this Godot process Master bus, after game effects; no mic/system loopback","master_muted_for_speakers":AudioServer.is_bus_mute(0)},"method":"Normal real-time engine, viewport sampled about20Hz with actual monotonic timestamps; no MovieMaker/fixed delta/speedup/added holdframes/UI redraw."}
	AudioServer.remove_bus_effect(0,effect_index);mix=null;samples=PackedVector2Array();stream.close();stream=null
	var file:=FileAccess.open(folder.path_join("continuous-capture.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	return result

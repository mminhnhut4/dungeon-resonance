extends "res://tests/newcomer_capture.gd"
## QA instrumentation only. Same real Master audio capture in both passes.
var viewport_enabled: bool=not "--timing-capture-off" in OS.get_cmdline_user_args()
var capture_spans: Array[Dictionary]=[]

func _frame() -> void:
	if not capturing or not viewport_enabled:return
	var now: int=Time.get_ticks_usec()
	if now-last_capture<50000:return
	last_capture=now
	var name: String="frames/frame-%06d.jpg"%frames.size()
	var image: Image=get_viewport().get_texture().get_image()
	var readback_end: int=Time.get_ticks_usec()
	if image.save_jpg(folder.path_join(name),.95)!=OK:capture_errors+=1
	var jpeg_end: int=Time.get_ticks_usec()
	frames.append({"wall_usec":now-started,"file":name})
	stream.store_line("%d,%d,%s"%[frames.size()-1,now-started,name])
	if frames.size()%20==0:stream.flush()
	capture_spans.append({"from_usec":now,"readback_end_usec":readback_end,"jpeg_end_usec":jpeg_end,"to_usec":Time.get_ticks_usec()})

func finish() -> Dictionary:
	var result: Dictionary=super.finish()
	result["capture_spans"]=capture_spans
	return result

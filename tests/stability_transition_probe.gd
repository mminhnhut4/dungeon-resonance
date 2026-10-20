extends SceneTree
## Timing fixture invokes existing room/flow owner directly; NOT gameplay proof.
const Sink=preload("res://tests/stab_timing_sink.gd")
var flow: GameFlow
var checks: int=0
var failures: int=0
var samples: Array[Dictionary]=[]
var transitions: Array[Dictionary]=[]
var phase: String="startup"
var before_usec: int=0
var draw_start: int=0
var draw_ms: float=0.0
func _initialize() -> void:_run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)
func _step(count: int) -> void:
	for _i: int in count:await process_frame;await physics_frame
func _pre() -> void:draw_start=Time.get_ticks_usec()
func _post() -> void:draw_ms=(Time.get_ticks_usec()-draw_start)/1000.0
func _sample() -> void:
	var now: int=Time.get_ticks_usec()
	if before_usec>0:samples.append({"from":before_usec,"to":now,"ms":(now-before_usec)/1000.0,"draw_ms":draw_ms,"phase":phase,"frame":Engine.get_process_frames()})
	before_usec=now
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=120;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	RenderingServer.frame_pre_draw.connect(_pre);RenderingServer.frame_post_draw.connect(_post);process_frame.connect(_sample)
	Sink.events.clear();flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override="user://transition-fixture/profile.json"
	var begun: int=Time.get_ticks_usec();root.add_child(flow);transitions.append({"phase":"startup","call_ms":(Time.get_ticks_usec()-begun)/1000.0});await _step(30)
	var hub: ExteriorHub=flow.active_scene as ExteriorHub
	_check(hub!=null and not flow.qa_tools_enabled,"Actual product Hub with fresh isolated profile, no QA/grants")
	for lap: int in 2:
		for id: StringName in [&"o01_p01",&"o01_p02",&"o01_p03",ExteriorRouteCatalog.HUB]:
			phase="lap%d_"%lap+String(id);await _step(15)
			begun=Time.get_ticks_usec();var ok: bool=hub.return_to_hub() if id==ExteriorRouteCatalog.HUB else hub.enter_exterior(id)
			var ms: float=(Time.get_ticks_usec()-begun)/1000.0
			_check(ok,"Existing room owner commits fixture transition "+phase)
			transitions.append({"phase":phase,"from":begun,"to":Time.get_ticks_usec(),"call_ms":ms});await _step(15)
	phase="campaign_departure";await _step(15);begun=Time.get_ticks_usec();flow.start_campaign();transitions.append({"phase":phase,"from":begun,"to":Time.get_ticks_usec(),"call_ms":(Time.get_ticks_usec()-begun)/1000.0});await _step(30)
	_check(flow.active_scene is DungeonRun,"Product campaign departure remains functional")
	phase="teardown";flow.queue_free();flow=null;await _step(10);root.get_node("AudioManager").stop_all()
	var report: Dictionary={"checks":checks,"failures":failures,"transitions":transitions,"samples":samples,"timing_events":Sink.events.duplicate(true),"engine":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name(),"render_cap":120,"physics_hz":60,"scope":"Explicit timing fixture using normal product owner calls, fresh QA profile and no Player/loot grants, HP/damage/RNG changes. Direct owner room changes are not ordinary gameplay input. No capture readback during measurements; driver/disk caches not cleared."}
	var f:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("transition-metrics.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("METRIC_TRANSITIONS ",JSON.stringify(transitions));print("RESULT TransitionTiming checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

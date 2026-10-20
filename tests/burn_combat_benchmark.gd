extends SceneTree
var flow: GameFlow
var run: DungeonRun
var samples: Array[Dictionary]=[]
var evidence: String
var releases: Dictionary={}
var checks: int=0
var failures: int=0
var draw_start: int=0
var draw_ms: float=0.0
var pass_id: int=0
func _pre_draw() -> void: draw_start=Time.get_ticks_usec()
func _post_draw() -> void: draw_ms=(Time.get_ticks_usec()-draw_start)/1000.0

func _node_seed(node: Node) -> void:
	if node is WorldCampaign: node.run_seed=2544146510965816941

func _initialize() -> void:_run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)
func _step(n: int) -> void:
	for _i: int in n:await physics_frame;await process_frame
func _action(id: StringName,down: bool) -> void:
	var event:=InputEventAction.new();event.action=id;event.pressed=down
	Input.parse_input_event(event)
func _aim() -> void:
	var enemies: Array[Node2D]=run.living_enemies()
	if enemies.is_empty():return
	var target: Node2D=enemies[0]
	var distance: float=INF
	for enemy: Node2D in enemies:
		var d: float=run.player.global_position.distance_squared_to(enemy.global_position)
		if d<distance:target=enemy;distance=d
	var event:=InputEventMouseMotion.new();event.position=target.get_global_transform_with_canvas().origin+Vector2(0,-24)
	root.push_input(event,true)
func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(evidence.path_join(label+".png"))==OK,"Capture "+label)
func _stats(rows: Array[Dictionary]) -> Dictionary:
	var ms: Array[float]=[];var sum: float=0.0;var over25: int=0;var over50: int=0
	for row: Dictionary in rows:
		var value: float=row["frame_ms"];ms.append(value);sum+=value
		if value>25.0:over25+=1
		if value>50.0:over50+=1
	ms.sort()
	if ms.is_empty():return {"samples":0}
	return {"samples":ms.size(),"mean_ms":sum/ms.size(),"p95_ms":ms[mini(ms.size()-1,ceili(ms.size()*0.95)-1)],"p99_ms":ms[mini(ms.size()-1,ceili(ms.size()*0.99)-1)],"max_ms":ms[-1],"over_25_ms":over25,"over_50_ms":over50}
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(DisplayServer.get_name()!="headless" and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Native combat uses isolated profile")
	if failures:quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1)
	root.position=DisplayServer.screen_get_position(root.current_screen)+Vector2i(20,20)
	root.size=Vector2i(1152,648);Engine.max_fps=120;Engine.physics_ticks_per_second=60
	AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");DirAccess.make_dir_recursive_absolute(evidence)
	node_added.connect(_node_seed)
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	RenderingServer.frame_post_draw.connect(_post_draw)
	for i: int in 4:
		pass_id=i
		await _one_pass()
	print("RESULT BurnCombatBenchmark checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)

func _one_pass() -> void:
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override="user://audit/combat_%d.json" % pass_id;root.add_child(flow);await _step(10)
	var hub: PrologueHub=flow.active_scene as PrologueHub
	hub.gear.inventory.add_rune(&"fire");hub.gear.inventory.equip_catalyst_set([&"fire"])
	_check(hub.economy._save_safe(),"Finite Fire rune fixture saved through existing writer")
	var started: int=Time.get_ticks_usec();flow.start_campaign()
	var launch_ms: float=(Time.get_ticks_usec()-started)/1000.0
	await _step(20);run=flow.active_scene as DungeonRun
	_check(run!=null and run.room.locked and not run.living_enemies().is_empty(),"Actual main departure creates locked live combat floor")
	if run==null:quit(2);return
	run.player.health.minimum_health=1.0
	# Only player survival is bounded for this finite diagnostic. Enemy HP, damage,
	# input clocks, energy, hitstop and profile save paths remain product behavior.
	PlayerTravel.relocate(run.player,Vector2(480,640));await _step(15);_aim()
	await _step(1) # No screenshot readback anywhere in this benchmark.
	for _i: int in 90:await process_frame
	var before: int=Time.get_ticks_usec()
	var spans: Array[Dictionary]=[]
	var manager: HitstopManager=run.feedback.hitstop_manager
	var last_request: int=manager.request_count
	if manager.is_active():spans.append({"start":before,"end":manager._deadline_usec})
	for frame: int in 1200:
		await process_frame
		var now: int=Time.get_ticks_usec()
		if manager.request_count!=last_request:
			# Conservative: exclude the entire interval since the previous sample,
			# including requests that began and ended within a slow draw frame.
			spans.append({"start":before,"end":maxi(now,manager._deadline_usec)})
			last_request=manager.request_count
		var burners: int=0;var cpu_burners: int=0
		for enemy: Node2D in run.living_enemies():
			var v: ElementAfflictionVFX=enemy.get_node_or_null("ElementAfflictionVFX") as ElementAfflictionVFX
			if v!=null and v.burn_visible:
				burners+=1
				var cpu: CPUParticles2D=v.get_node_or_null("BurnEmbersCompatibility") as CPUParticles2D
				if cpu!=null and cpu.emitting and cpu.visible:cpu_burners+=1
		var row: Dictionary={"from_usec":before,"to_usec":now,"time_scale":Engine.time_scale,"burners":burners,"cpu_burners":cpu_burners,"request_count":manager.request_count,"deadline":manager._deadline_usec,"frame":frame,"draw_ms":draw_ms,"frame_ms":(now-before)/1000.0,"hitstop":run.feedback.is_frozen(),"enemies":run.living_enemies().size(),"player_hp":run.player.health.current_health,"energy":run.player.energy.current,"action":String(run.player.action_state_machine.get_state_id())}
		samples.append(row);before=now
		for id: StringName in releases.keys():_action(id,false)
		releases.clear()
		if frame%48==0:_aim();_action(&"attack",true);releases[&"attack"]=true
		if frame%120==30:_aim();_action(&"spell_cast",true);releases[&"spell_cast"]=true
		if frame%240==0:_action(&"move_right",true);_action(&"move_left",false)
		if frame%240==100:_action(&"move_right",false);_action(&"move_left",true)
		if frame%240==160:_action(&"move_left",false)
	for id: StringName in [&"attack",&"spell_cast",&"move_right",&"move_left"]:_action(id,false)
	await _step(3)
	await _step(1)
	var normal: Array[Dictionary]=[];var active: Array[Dictionary]=[];var spike_rows: Array[Dictionary]=[]
	for row: Dictionary in samples:
		if not row["hitstop"]:normal.append(row)
		if row["enemies"]>0:active.append(row)
		if row["frame_ms"]>25.0:spike_rows.append(row)
	var report: Dictionary={"engine":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":root.size,"physics_hz":60,"render_cap":120,"seed":run.get("run_seed"),"launch_call_ms":launch_ms,"all":_stats(samples),"non_hitstop":_stats(normal),"live_enemy_frames":_stats(active),"spikes":spike_rows,"samples":samples,"pass_id":pass_id,"cold_process_pass":pass_id==0,"hitstop_intervals":spans,"vsync_mode":DisplayServer.window_get_vsync_mode(),"fixture":"Actual main departure, one granted Fire rune, player minimum HP 1, automated InputEvent actions; no screenshot readback during measurement; audio muted, not listened; no changes to enemy damage/HP, energy, hitstop or save owner."}
	print("METRIC ",JSON.stringify({"all":report["all"],"non_hitstop":report["non_hitstop"],"launch_call_ms":launch_ms}))
	flow.queue_free();await _step(8);root.get_node("AudioManager").stop_all()
	report["checks"]=checks;report["failures"]=failures
	var file:=FileAccess.open(evidence.path_join("burn_combat_%d.json" % pass_id),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	samples.clear();releases.clear()

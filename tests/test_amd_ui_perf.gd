extends SceneTree
## Bounded A/B/HTTP/A drift check. Same opaque pair/seed/Hub route per trial.
## Authentication and disk staging are excluded from the sampled interval.
var checks: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func _run() -> void:
	check(AmdSlotStore.isolated() and DisplayServer.get_name()!="headless","native QA profile")
	Engine.max_fps=120; Engine.physics_ticks_per_second=60
	var identity: Dictionary=AmdSlotStore.read_json("user://amd201-qa-identity.json")
	var user: String=identity["user"]
	var store:=AmdSlotStore.new();var original: Dictionary=store.read_active(user)
	var path: String=original["path"]
	var files: Dictionary={}
	for key: String in ["profile","npc"]:
		var text: String=FileAccess.get_file_as_string(path+(NpcWorldState.NPC_SUFFIX if key=="npc" else ""))
		files[key]={"text":text,"sha256":text.sha256_text()}
	var capsule: Dictionary={"schemaVersion":1,"profileSchema":int(JSON.parse_string(files["profile"]["text"])["version"]),"gameBuild":"synthetic-ui-perf","files":files}
	for label: String in ["before","current","current_http","before_drift"]:
		await trial(label,user,identity["email"],capsule,int(original["baseRevision"]))
	check(store.activate(user,path,int(original["baseRevision"])),"restore original QA routing metadata after trials")
	var output: Dictionary={"checks":checks,"failures":failures,"rows":rows,"scope":"Four 2s render intervals on same native process/engine/120fps cap/60Hz physics, cloned identical profile+NPC/seed/Hub walk. Baseline is exact pre-UI boot source except unique class name. Current HTTP uses actual loopback QA delay, SQLite host; no PG. One bounded observation, no statistical or historical crash-fix claim."}
	var out:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("ui_http_comparison.json"),FileAccess.WRITE);out.store_string(JSON.stringify(output,"\t"));out.close()
	print("RESULT AMD_UI_PERF checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
func trial(label: String,user: String,address: String,capsule: Dictionary,revision: int) -> void:
	var store:=AmdSlotStore.new();var pack:=AmdCapsule.new()
	var path: String=pack.stage(capsule,user,store)
	check(path!="" and store.activate(user,path,revision),label+" identical starting pair staged")
	if path=="":return
	seed(20261030)
	var script: Script=load("res://tests/fixtures/amd_boot_before_ui.gd") if label.begins_with("before") else load("res://scripts/online/amd_boot.gd")
	var subject: Node=script.new();root.add_child(subject)
	# Synthetic UI fixture only: bypass auth for this isolated CPU/render comparison.
	subject.user_id=user;subject.account_email=address
	check(subject._open_account(),label+" cloned normal Hub")
	subject.menu.visible=false
	for index: int in 30:await physics_frame
	var hero: Player=subject.flow.active_scene.player
	check(subject.flow.process_mode==Node.PROCESS_MODE_INHERIT and not paused,label+" unpaused baseline")
	var start: Vector2=hero.global_position
	var max_x: float=start.x
	var samples: Array[float]=[]
	var pending_frames: int=0
	var frozen: int=0
	var response: Array[bool]=[false]
	if label=="current_http":
		subject.api.completed.connect(func(tag: String,_code: int,_data: Dictionary,_problem: String) -> void:
			if tag=="perf":response[0]=true)
		check(subject.api.send("perf","/api/qa/delay"),"actual asynchronous HTTP started")
	var started: int=Time.get_ticks_usec();var previous: int=started
	while Time.get_ticks_usec()-started<2000000:
		var elapsed: int=Time.get_ticks_usec()-started
		Input.action_release(&"move_left");Input.action_release(&"move_right")
		Input.action_press(&"move_right" if elapsed<1000000 else &"move_left")
		await process_frame
		var now: int=Time.get_ticks_usec();samples.append(float(now-previous)/1000.0);previous=now
		max_x=maxf(max_x,hero.global_position.x)
		if label=="current_http" and not response[0]:pending_frames+=1
		if hero.combat_feedback.is_frozen():frozen+=1
	Input.action_release(&"move_left");Input.action_release(&"move_right")
	samples.sort()
	var row: Dictionary={"case":label,"frames":samples.size(),"p50_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*0.95)],"max_ms":samples[-1],"over25ms":samples.filter(func(value: float)->bool:return value>25).size(),"pending_frames":pending_frames,"hitstop_frames":frozen,"start":str(start),"end":str(hero.global_position),"max_x":max_x,"source_profile_sha256":capsule["files"]["profile"]["sha256"]}
	rows.append(row);print("METRIC AMD_UI_PERF ",JSON.stringify(row))
	check(max_x-start.x>100 and hero.resonance_controller.cast_count==0,label+" same motor route, no combat input")
	if label=="current_http":
		check(pending_frames>100,"HTTP pending for measured render frames")
		var deadline: int=Time.get_ticks_msec()+3000
		while not response[0] and Time.get_ticks_msec()<deadline:await process_frame
		check(response[0],"HTTP eventually completed")
	root.remove_child(subject);subject.queue_free()
	for frame: int in 3:await process_frame

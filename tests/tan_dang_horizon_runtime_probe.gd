extends "res://tests/tan_dang_living_runtime_test.gd"
## Explicit QA owner/position fixture, not earned gameplay or native timing proof.
## Same file runs unmodified on baseline7 (--expect-reset) and candidate8.
const LAM: String = "tan_dang_lam_tuoc"
const P01: String = "o01_p01"
const HUB: String = "h00_traveler_hub"
var fixed: bool = false

func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"): quit(2); return
	fixed = not "--expect-reset" in OS.get_cmdline_user_args()
	for cold: bool in [false,true]:
		await _setup_horizon("cold" if cold else "room")
		var life: NpcWorldState = population.state
		_check(life.has_method("advance_living_danger")==fixed,"Probe mode matches owner contract; never pretend a fixture is a baseline fix")
		var enemy: TanDangLivingSlime = _far_threat()
		if not is_instance_valid(enemy): _check(false,"Actual threat exists"); continue
		for _i: int in 180: hub.living._tick_danger(0.1)
		var before: float = _elapsed()
		_check(before>=18.0 and before<18.2 and life.living_view(LAM)["event_phase"]=="danger","Actual adapter accumulates eighteen playable seconds without combat damage")
		# Existing 30s autosave consumer; force its due clock, not a new cadence.
		population.autosave_remaining = 0.0
		population._process(0.0)
		_check(life.last_save_ok,"Existing population autosave succeeds")
		if fixed:
			var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(life.save_path))
			_check(is_equal_approx(float(disk["records"][LAM]["living"]["danger_elapsed"]),before),"Existing autosave includes elapsed without a separate writer")
		var path: String = flow.save_path_override
		if cold:
			flow.queue_free(); current_scene = null
			await _step(6)
			await _open_horizon(path)
			_check(hub.enter_exterior(&"o01_p01",ExteriorRouteCatalog.MAIN,&"west",false),"Cold fixture enters the saved NPC room through the real room API")
		else:
			_check(hub.return_to_hub(false),"Real room boundary checkpoints the existing owner")
			var offroom: float = _elapsed()
			for _i: int in 30: hub.living._process(0.1)
			_check(is_equal_approx(_elapsed(),offroom),"Off-room gameplay never consumes danger time")
			_check(hub.enter_exterior(&"o01_p01",ExteriorRouteCatalog.MAIN,&"west",false),"Real room return does not restart the finite event")
		await _step(3)
		life = population.state
		enemy = _far_threat()
		var after: float = _elapsed()
		_check(after>=before if fixed else after<0.2,"Continuity after "+("cold" if cold else "room")+": expected "+("preserved" if fixed else "verified baseline reset"))
		hub.player.controls_enabled = false
		var paused: float = _elapsed()
		for _i: int in 30: hub.living._process(0.1)
		_check(is_equal_approx(_elapsed(),paused),"Unplayable UI/control pause contributes no danger time")
		hub.player.controls_enabled = true
		for _i: int in 180:
			if life.living_view(LAM)["event_phase"]!="danger": break
			hub.living._tick_danger(0.1)
		var view: Dictionary = life.living_view(LAM)
		_check(view["event_phase"]==("returning" if fixed else "danger"),"Two eighteen-second playable segments exceed one horizon only after the fix")
		print("HORIZON_OBSERVATION "+JSON.stringify({"cold":cold,"fixed":fixed,"before":before,"after":after,"phase":view["event_phase"],"elapsed":_elapsed()}))
		flow.queue_free(); current_scene = null
		await _step(6)
	await _finish()

func _elapsed() -> float:
	if population.state.has_method("advance_living_danger"):
		return float(population.state.living_view(LAM).get("danger_elapsed",0.0))
	return float(hub.living.get("_danger_elapsed"))

func _open_horizon(path: String) -> void:
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path
	root.add_child(flow); current_scene = flow
	hub = flow.active_scene as ExteriorHub
	population = hub.npc_population
	hub.living.set_process(false); population.set_process(false)
	await _step(6)

func _setup_horizon(label: String) -> void:
	await _open_horizon("user://verification/horizon_probe_%s_%d_%d.json"%[label,OS.get_process_id(),Time.get_ticks_usec()])
	var p: TanDangProgress = hub.tan_dang.progress
	for action: String in ["accept","observe_lamp","find_lam","inspect_core","q1_reward","choice_rescue","report_moc","report_lam","q3_reward"]:
		var place: String = "ledger" if action=="accept" else "lamp" if action=="observe_lamp" else "refuge" if action in ["find_lam","inspect_core","choice_rescue"] else TanDangProgress.MOC if action=="report_moc" else LAM if action=="report_lam" else ""
		_action(p,action,place)
	population.refresh_actors()
	var life: NpcWorldState = population.state
	_check(life.start_living_event(p.state()),"Fixture follows canonical post-q3 start")
	for _i: int in 100: life.advance_ticks(1)
	_check(life.transfer_lam(P01) and hub.enter_exterior(&"o01_p01",ExteriorRouteCatalog.MAIN,&"west",false),"Fixture follows actual NPC and player room boundaries")
	await _step(3)
	for _i: int in 100: life.advance_ticks(1)
	_check(life.advance_living_event(LAM,"collecting","danger"),"Fixture starts danger through the existing owner")

func _far_threat() -> TanDangLivingSlime:
	var actor: CultivatorActor = population.actors.get(LAM) as CultivatorActor
	if not is_instance_valid(actor): return null
	actor._spawn_synced = false
	actor.sync_record(false); actor.sync_record(true)
	actor.set_physics_process(false)
	hub.living._tick_danger(0.01)
	actor.stop_living_defense()
	var threat: TanDangLivingSlime = hub.living.enemy
	if not is_instance_valid(threat): return null
	# Declared geometry fixture isolates the already-authored leash horizon;
	# real body remains alive, no health/owner phase is fabricated.
	threat.ai_enabled = false; threat.set_physics_process(false)
	threat.position.x = actor.position.x+310.0
	return threat

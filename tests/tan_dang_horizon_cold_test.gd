extends "res://tests/tan_dang_horizon_runtime_probe.gd"
## Two independent launches in the same isolated QA data root: --prepare, then
## --reopen. Declared canonical-quest fixture, not an earned native save.
const COLD_PATH: String = "user://verification/horizon_cold/profile.json"
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	fixed=true
	if "--prepare" in OS.get_cmdline_user_args():
		if FileAccess.file_exists(COLD_PATH):_check(false,"Prepare requires a fresh isolated QA root");await _finish();return
		# Setup helper uses unique paths; this fixture supplies the known path by
		# preparing once with the exact same owner APIs below.
		await _open_horizon(COLD_PATH)
		var p: TanDangProgress=hub.tan_dang.progress
		for action: String in ["accept","observe_lamp","find_lam","inspect_core","q1_reward","choice_rescue","report_moc","report_lam","q3_reward"]:
			var place: String="ledger" if action=="accept" else "lamp" if action=="observe_lamp" else "refuge" if action in ["find_lam","inspect_core","choice_rescue"] else TanDangProgress.MOC if action=="report_moc" else LAM if action=="report_lam" else ""
			_action(p,action,place)
		population.refresh_actors()
		var life: NpcWorldState=population.state
		_check(life.start_living_event(p.state()),"Canonical cold fixture starts once")
		for _i: int in 100:life.advance_ticks(1)
		_check(life.transfer_lam(P01) and hub.enter_exterior(&"o01_p01",ExteriorRouteCatalog.MAIN,&"west",false),"Canonical cold fixture reaches P01")
		await _step(3)
		for _i: int in 100:life.advance_ticks(1)
		_check(life.advance_living_event(LAM,"collecting","danger"),"Canonical cold fixture enters danger")
		_check(is_instance_valid(_far_threat()),"Cold fixture has an actual live monster")
		for _i: int in 180:hub.living._tick_danger(0.1)
		_check(_elapsed()>=18.0 and _elapsed()<18.2 and life.save(),"First process checkpoints eighteen seconds through the owner")
	else:
		if not "--reopen" in OS.get_cmdline_user_args() or not FileAccess.file_exists(COLD_PATH):_check(false,"Explicit --reopen needs prepared QA root");await _finish();return
		await _open_horizon(COLD_PATH)
		var life: NpcWorldState=population.state
		_check(_elapsed()>=18.0 and _elapsed()<18.2 and life.living_view(LAM)["event_phase"]=="danger","Second process restores elapsed rather than resetting danger")
		_check(hub.enter_exterior(&"o01_p01",ExteriorRouteCatalog.MAIN,&"west",false),"Second process enters actual saved NPC room")
		await _step(3)
		var enemy: TanDangLivingSlime=_far_threat()
		_check(is_instance_valid(enemy) and enemy.health.current_health==60.0,"Elapsed-only change deliberately preserves baseline full-HP threat respawn")
		for _i: int in 180:
			if life.living_view(LAM)["event_phase"]!="danger":break
			hub.living._tick_danger(0.1)
		_check(life.living_view(LAM)["event_phase"]=="returning" and life.living_view(LAM)["outcome"]=="withdrew" and _elapsed()==35.0,"Two processes share one saved horizon and one honest withdrawal")
	await _finish()

extends "res://tests/depth_floor_selection_test.gd"
## Actual GameFlow return transactions; direct stage/health setup isolates the milestone contract.
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if DisplayServer.get_name() != "headless" or not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: isolated headless QA required")
		quit(2)
		return
	path = "user://verification/connected_retreat_%d_%d.json" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	await _open()
	flow.start_campaign()
	await _step(6)
	var run: DepthCampaign = flow.active_scene as DepthCampaign
	_check(run != null and run.is_opening_segment(),"Actual main entry starts connected opening")
	if run == null:
		await _close()
		_finish()
		return
	_prepare_run(run)
	_check(run.enter_stage(4),"Controlled setup enters original Golem stage")
	await _step(4)
	_prepare_run(run)
	run.boss.health.apply_damage(99999)
	await _step(8)
	_check(run.portal_active and not run.has_pending_rewards() and run.advance_room(),"Defeated Golem continues into floor four")
	await _step(4)
	_prepare_run(run)
	await _clear_roster(run)
	_check(not _returned() and not run.room.locked,"Opening return milestone waits until actual return")
	var pickup: LootPickup = run.gear.loot.spawn(&"coins",&"coins",run.player.position,9)
	pickup.automatic = false
	_check(pickup.collect(),"Finite nine-coin QA pickup is carried")
	var carried: int = run.gear.inventory.run_coins
	var old_coins: int = flow.profile.coins
	var ids: Array = run.gear.inventory.items.keys()
	var old_receipts: Array[String] = flow.profile.boss_receipts.duplicate()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	PlayerTravel.relocate(run.player,Catalog.exit_point(1))
	await _step(3)
	flow.profile._writer.fault_plan = {"write_candidate":true}
	_check(run.request_floor_return(),"Cleared depth floor accepts an early return request")
	await _step(4)
	_check(flow.active_scene == run and run.outcome == &"retreat" and flow.return_save_pending,"Failed return retains the same live run for retry")
	_check(not _returned() and flow.profile.coins == old_coins and FileAccess.get_file_as_bytes(path) == bytes and run.gear.inventory.run_coins == carried,"Failed bank rolls back return milestone, bank, exact bytes and carried coins")
	_check(flow.retry_pending_return(),"Existing return retry commits the continuous trip")
	await _step(5)
	_check(flow.active_scene is PrologueHub and _returned(),"Early depth retreat counts as return after this trip's Golem victory")
	_check(flow.profile.coins == old_coins+carried and ids.all(func(uid: Variant) -> bool: return flow.active_scene.gear.inventory.items.has(uid)),"Return preserves all UIDs and banks coins once")
	_check(flow.profile.boss_receipts == old_receipts and int(flow.depth_progress.state()["cleared"]) == 1 and not bool(flow.depth_progress.state()["boss_defeated"]),"Early return does not invent final boss victory or another Golem receipt")
	_check(flow.show_hub() and flow.profile.coins == old_coins+carried and _returned(),"Repeated callback cannot duplicate bank or reset the milestone")
	await _close()
	await _open()
	_check(_returned() and flow.profile.coins == old_coins+carried,"Cold reload retains the committed opening return and bank")
	await _close()
	# Separate synthetic save: historical Golem proof permits a shortcut but is not
	# evidence that this shortcut's early retreat completed the opening trip.
	path = "user://verification/shortcut_retreat_%d_%d.json" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	await _open()
	_check(flow.profile.record_boss_defeat("historical_shortcut_gate") and flow.depth_progress.accept(),"Separate fixture creates historical unlock only")
	_check(not _returned() and flow.start_depth_campaign(1),"Shortcut starts without the opening return milestone")
	await _step(5)
	run = flow.active_scene as DepthCampaign
	_prepare_run(run)
	await _clear_roster(run)
	PlayerTravel.relocate(run.player,Catalog.exit_point(1))
	await _step(3)
	_check(not run.connected_opening and run.request_floor_return(),"Shortcut retains ordinary depth retreat semantics")
	await _step(5)
	_check(flow.active_scene is PrologueHub and not _returned(),"Shortcut retreat cannot falsely grant this-trip opening return")
	await _close()
	_finish()

func _returned() -> bool:
	return flow.profile.opening_progress.get("completed",[]).has("returned_to_hub")

func _finish() -> void:
	print("RESULT connected_depth_retreat checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)
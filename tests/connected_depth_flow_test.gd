extends "res://tests/depth_floor_selection_test.gd"
## Isolated actual main GameFlow fixture. Direct stage navigation and lethal QA damage
## shorten setup; this verifies ownership/transactions, not natural play or visual quality.
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if DisplayServer.get_name() != "headless" or not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: isolated headless QA root required")
		quit(2)
		return
	path = "user://verification/connected_depth_%d_%d.json" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	await _open()
	var hub: PrologueHub = flow.active_scene as PrologueHub
	var prepared_ids: Array = hub.gear.inventory.items.keys()
	flow.start_campaign()
	await _step(6)
	var run: DepthCampaign = flow.active_scene as DepthCampaign
	_check(run != null,"Main dungeon instantiates the connected campaign")
	if run == null:
		await _close()
		_finish()
		return
	_prepare_run(run)
	_check(run.connected_opening and run.is_opening_segment() and run.stage == 1 and run.room_number == 1,"Main entry retains the original opening first room")
	_check(not bool(flow.depth_progress.state()["accepted"]),"Starting opening does not prematurely accept deeper floors")
	_check(prepared_ids.all(func(uid: Variant) -> bool: return run.gear.inventory.items.has(uid)),"Main departure retains exact prepared UIDs")
	_check(not flow._authorize_continuous_depth(run),"Bridge rejects a live uncleared opening")
	_check(run.enter_stage(4),"Explicit QA setup navigates to the existing Golem stage")
	await _step(4)
	_prepare_run(run)
	_check(run.boss != null and run.room_number == 3 and run.is_opening_segment(),"Opening third floor still owns the existing Golem")
	_check(not run.can_continue_to_depth(),"Living Golem cannot open floor four")
	run.boss.health.apply_damage(99999)
	await _step(8)
	_check(run.portal_active and flow.depth_progress.unlocked() and not run.has_pending_rewards(),"Real defeated Golem records its opening proof before continuation")
	var old_receipts: Array[String] = flow.profile.boss_receipts.duplicate()
	var old_proofs: Dictionary = flow.profile.boss_proofs.duplicate(true)
	var owner_id: int = run.get_instance_id()
	var player_id: int = run.player.get_instance_id()
	var gear_id: int = run.gear.get_instance_id()
	var inventory: GearInventory = run.gear.inventory
	# Explicit pending flag represents an already-durable receipt awaiting retry acknowledgement.
	run._proof_pending = true
	_check(not run.advance_room() and not flow._authorize_continuous_depth(run),"Pending opening proof blocks both bridge entry points")
	_check(run.retry_pending_rewards() and not run.has_pending_rewards(),"Existing pending owner retries without minting another Golem receipt")
	_check(flow.profile.boss_receipts == old_receipts,"Opening retry is receipt-idempotent")
	var before_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var before_inventory: Dictionary = GearInventoryCodec.encode(inventory)
	flow.profile._writer.fault_plan = {"write_candidate":true}
	_check(not run.advance_room() and run.is_opening_segment() and run.portal_active,"Failed depth acceptance leaves the Golem return gate usable")
	_check(FileAccess.get_file_as_bytes(path) == before_bytes and GearInventoryCodec.encode(inventory) == before_inventory and not bool(flow.depth_progress.state()["accepted"]),"Failed bridge transaction rolls back exact bytes, UIDs, and acceptance")
	var pickup: LootPickup = run.gear.loot.spawn(&"coins",&"coins",run.player.position,7)
	pickup.automatic = false
	_check(pickup.collect(),"Finite QA coin pickup enters the live carried inventory")
	var carried: int = inventory.run_coins
	run.player.health.current_health = 47.0
	run.player.energy.current = 31.0
	run.player.resonance_controller.loadout_state.cooldowns_by_recipe_id[&"fire_bolt"] = 4.25
	var cooldowns: Dictionary = run.player.resonance_controller.loadout_state.cooldowns_by_recipe_id.duplicate()
	var max_hp: float = run.player.health.maximum_health
	var bank_before: int = flow.profile.coins
	_check(run.advance_room(),"Retry continues from the defeated Golem into floor four")
	_check(flow.active_scene == run and run.get_instance_id() == owner_id and run.player.get_instance_id() == player_id and run.gear.get_instance_id() == gear_id and run.gear.inventory == inventory,"Bridge preserves the exact live campaign, Player, gear and inventory owners")
	_check(run.player.health.current_health == 47.0 and run.player.health.maximum_health == max_hp and run.player.energy.current == 31.0 and run.player.resonance_controller.loadout_state.cooldowns_by_recipe_id == cooldowns,"Bridge does not heal, refill mana, or reset committed cooldowns")
	_check(inventory.run_coins == carried and flow.profile.coins == bank_before,"Mid-run continuation cannot bank or discard carried coins")
	_check(not run.is_opening_segment() and run.room_number == 1 and run.global_floor_number() == 4 and run.room.locked,"Global floor four uses local depth floor one with its own locked roster")
	_check(bool(flow.depth_progress.state()["accepted"]) and int(flow.depth_progress.state()["cleared"]) == 0,"Bridge accepts the existing namespace without granting completion")
	_check(not flow._authorize_continuous_depth(run),"Repeated bridge callback cannot authorize another mid-floor transition")
	await _step(4)
	for number: int in [1,2,3,4]:
		_prepare_run(run)
		_check(run.room_number == number and run.global_floor_number() == number+3,"Connected depth retains local/global mapping for floor %d" % (number+3))
		await _clear_roster(run)
		_check(not run.room.locked and int(flow.depth_progress.state()["cleared"]) == number,"Actual local roster completion saves local floor %d" % number)
		_check(run.advance_room(),"Normal continuation reaches global floor %d" % (number+4))
		await _step(4)
	_prepare_run(run)
	_check(run.room_number == 5 and run.global_floor_number() == 8 and run.boss != null and run.room.locked,"Global floor eight contains the existing local fifth-floor boss")
	run.boss.health.apply_damage(99999)
	await _step(8)
	_check(run.portal_active and bool(flow.depth_progress.state()["boss_defeated"]) and int(flow.depth_progress.state()["cleared"]) == 5,"Final boss uses the unchanged five-floor progress schema")
	_check(flow.profile.boss_receipts == old_receipts and flow.profile.boss_proofs == old_proofs,"Depth completion never duplicates opening Golem proof or receipt")
	_check(not flow._authorize_continuous_depth(run),"Final depth boss portal cannot re-enter the opening bridge authorizer")
	var returned_ids: Array = inventory.items.keys()
	carried = inventory.run_coins
	PlayerTravel.relocate(run.player,Vector2(1240,640))
	await _step(3)
	_check(run.request_floor_return(),"Final return uses the existing expedition return owner")
	await _step(6)
	_check(flow.active_scene is PrologueHub and flow.profile.coins == bank_before+carried,"Final return banks the whole continuous expedition exactly once")
	_check(returned_ids.all(func(uid: Variant) -> bool: return flow.active_scene.gear.inventory.items.has(uid)),"Final return preserves every carried UID")
	_check(flow.show_hub() and flow.profile.coins == bank_before+carried,"Repeated Hub return cannot duplicate coins")
	await _close()
	await _open()
	_check(int(flow.depth_progress.state()["cleared"]) == 5 and bool(flow.depth_progress.state()["boss_defeated"]) and flow.profile.coins == bank_before+carried,"Cold reload retains original local depth schema and bank")
	_check(flow.start_depth_campaign(3),"Lac An shortcut still starts a completed local depth floor")
	await _step(5)
	run = flow.active_scene as DepthCampaign
	_check(run != null and not run.connected_opening and not run.is_opening_segment() and run.room_number == 3 and run.global_floor_number() == 6,"Shortcut maps local floor three to global floor six without replaying opening")
	await _close()
	_finish()

func _finish() -> void:
	print("RESULT connected_depth_flow checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)
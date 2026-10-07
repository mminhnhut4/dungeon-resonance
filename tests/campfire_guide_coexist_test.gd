extends "res://tests/opening_progression_recovery_test.gd"
## Real production camp/inventory handoff on original17; read-only guide plus actual chest/return/death owners.

func _accept(button: Button) -> void:
	button.grab_focus()
	await _step(2)
	for pressed: bool in [true,false]:
		var event := InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = pressed
		root.push_input(event,true)
		await _step(2)

func _map_key() -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_M
		event.keycode = KEY_M
		event.pressed = pressed
		root.push_input(event,true)
		await _step(2)

func _view(screen: InventoryScreen, id: StringName) -> void:
	var profile_bytes := FileAccess.get_file_as_bytes(screen.journal.profile.save_path)
	var carried := JSON.stringify(GearInventoryCodec.encode(screen.inventory))
	await _accept(screen.journal.quest_buttons[id])
	_check(screen.journal.selected_id == id and not screen.journal.objective_label.text.is_empty(),"Guide row selects by actual native input")
	_check(FileAccess.get_file_as_bytes(screen.journal.profile.save_path) == profile_bytes and JSON.stringify(GearInventoryCodec.encode(screen.inventory)) == carried,"Guide inspection changes no save bytes, UID, material or reward")

func _run() -> void:
	var allowed := OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: Requires isolated QA user://");quit(2);return
	var hz: int = 60
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	AudioServer.set_bus_mute(0,true)
	directory = "user://verification/camp_guide_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var flow: GameFlow = await _open("coexist")
	flow.start_campaign()
	await _step()
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	_check(run != null and run.enter_stage(2),"Uses actual current campaign and finite-chest stage")
	var camp: SurvivalPanel = run.survival.panel
	var guide: InventoryScreen = run.gear.modal as InventoryScreen
	_check(camp.session == run.survival and guide.secondary_panel == camp and guide.inventory == run.gear.inventory,"Camp and guide share production inventory and modal binding")
	var before := FileAccess.get_file_as_bytes(flow.profile.save_path)
	var inventory_before := JSON.stringify(GearInventoryCodec.encode(run.gear.inventory))
	guide.open_map()
	await _step()
	_check(guide.is_open and guide.tabs.current_tab == 2 and is_equal_approx(Engine.time_scale,0.1),"Guide acquires existing slow-time owner")
	await _view(guide,&"returned_to_hub")
	camp.open(true)
	await _step()
	_check(camp.is_open and not guide.is_open and is_equal_approx(Engine.time_scale,1.0) and not run.player.controls_enabled,"Opening camp closes guide and transfers control/time ownership")
	await _map_key()
	_check(camp.is_open and not guide.is_open,"Map input cannot open a competing modal while camp owns player controls")
	var presses: Array[int] = [0]
	var observed: Callable = func() -> void: presses[0] += 1
	camp.inventory_button.pressed.connect(observed)
	await _accept(camp.inventory_button)
	camp.inventory_button.pressed.disconnect(observed)
	_check(presses[0] == 1 and not camp.is_open and guide.is_open,"Camp inventory footer performs one actual native handoff")
	await _map_key()
	_check(guide.is_open and guide.tabs.current_tab == 2 and not camp.is_open,"Inventory handoff reaches original17 guide without overlapping camp")
	await _view(guide,&"explored")
	await _view(guide,&"first_upgrade")
	guide.close()
	await _step()
	_check(run.player.controls_enabled and is_equal_approx(Engine.time_scale,1.0),"Closing guide restores gameplay after camp handoff")
	_check(FileAccess.get_file_as_bytes(flow.profile.save_path) == before and JSON.stringify(GearInventoryCodec.encode(run.gear.inventory)) == inventory_before,"Camp/guide read-only round trip allocates no UID or reward and writes no profile")
	# Existing recovery helpers probe a reachable seed; collect the actual finite chest pickups.
	var seed_value: int = await _pair_seed(run)
	_check(seed_value >= 0,"Real finite chest retains a reachable Fire/Wind source")
	if seed_value < 0: await _close(flow);quit(1);return
	run.gear.loot.rng.seed = seed_value
	PlayerTravel.relocate(run.player,run.secret_chest.global_position,PlayerTravel.Kind.INTRA_EXPEDITION)
	_check(run.secret_chest.interact(),"Actual finite chest opens once with camp UI present")
	for pickup: LootPickup in run.gear.loot.get_children():
		pickup.automatic = false
		if pickup.kind == &"rune": _check(pickup.collect(),"Actual rune pickup is collected through the original owner")
	_check(not run.secret_chest.interact(),"Camp UI does not reopen the finite chest")
	_check(run.gear.inventory.equip_catalyst_set([&"fire",&"wind"]),"Actual owned Catalyst set equips after camp handoff")
	guide.open_map()
	await _step()
	await _view(guide,&"returned_to_hub")
	_check("Đúng bộ" in guide.journal.objective_label.text and run.player.resonance_controller.get_recipe().id == &"firestorm","Guide and real Player agree on the collected recipe")
	guide.close()
	await _empty_boss(run)
	_check(run.win() and flow.show_hub(false),"Actual zeroSoul victory return succeeds with new camp UI present")
	await _step()
	_pause(flow)
	_check(flow.profile.souls == 0 and flow.profile.opening_progress["completed"].has("returned_to_hub") and not flow.profile.opening_progress["completed"].has("reward_collected"),"Original17 return receipt survives without fabricated reward")
	var save_path: String = flow.profile.save_path
	await _close(flow)
	flow = await _open("cold",save_path)
	_check(flow.profile.souls == 0 and flow.profile.opening_progress["completed"].has("returned_to_hub"),"Cold reload retains original17 successful-return owner")
	guide = flow.active_scene.gear.modal as InventoryScreen
	guide.open_map()
	await _step()
	await _view(guide,&"returned_to_hub")
	_check("Đúng bộ" in guide.journal.objective_label.text,"Cold-reloaded guide reads banked actual runes")
	guide.close()
	flow.start_campaign()
	await _step()
	flow.active_scene.player.health.apply_damage(9999)
	_check(flow.show_hub(true),"Actual death return uses existing original17 owner")
	await _step()
	_pause(flow)
	guide = flow.active_scene.gear.modal as InventoryScreen
	guide.open_map()
	await _step()
	await _view(guide,&"returned_to_hub")
	_check("Còn thiếu" in guide.journal.objective_label.text and flow.profile.opening_progress["completed"].has("returned_to_hub"),"Death loss is reflected in guide while historical return remains complete")
	guide.close()
	await _close(flow)
	await root.get_node("AudioManager").shutdown()
	print("RESULT CampfireGuideCoexist checks=%d failures=%d hz=%d" % [checks,failures,hz])
	quit(0 if failures == 0 else 1)

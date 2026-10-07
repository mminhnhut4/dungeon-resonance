extends "res://tests/region_entry_card_test.gd"
## Unified map launcher + name-only region frame in actual hub/exterior.
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	capture = OS.get_cmdline_user_args().has("--capture")
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\", "/").begins_with(allowed + "/") or (capture and DisplayServer.get_name() == "headless"):
		print("FAIL: Combined region UI probe requires authorized isolated data and assigned renderer")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute("res://docs/verification/region_entry")
	AudioServer.set_bus_mute(0, true)
	profile = CountingProfile.new()
	profile.save_path = "user://verification/card_ui_%d.json" % OS.get_process_id()
	profile.bounty_accepted = true
	world = preload("res://scenes/hub/exterior_hub_room.tscn").instantiate() as ExteriorHub
	world.profile = profile
	world.world_building_enabled = true
	root.add_child(world)
	current_scene = world
	await _step(10)
	actor = world.player
	card = world.entry_card
	var screen: InventoryScreen = world.gear.modal as InventoryScreen
	for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		await _size(extent)
		if world.outside: world.return_to_hub()
		await _road()
		_check(card.panel.visible and not screen.tracker.visible and screen.map_button.visible, "Hub name-only frame and map launcher coexist without a quest overlay")
		_geometry("combined_tracker_hub_%dx%d" % [extent.x,extent.y])
		_check(not card.panel.get_global_rect().intersects(screen.map_button.get_global_rect()), "Hub frame leaves the map launcher readable")
		await _capture("combined_tracker_hub_%dx%d" % [extent.x,extent.y])
		_check(world.enter_exterior(&"o01_p01"), "Combined fixture uses the actual P01 entry")
		await _step(5)
		await _at(&"door_east")
		_check(card.panel.visible and not screen.tracker.visible and screen.map_button.visible, "East-door frame and map launcher coexist without a quest overlay")
		_geometry("combined_tracker_east_%dx%d" % [extent.x,extent.y])
		_check(not card.panel.get_global_rect().intersects(screen.map_button.get_global_rect()), "East-door frame leaves the map launcher readable")
		await _capture("combined_tracker_east_%dx%d" % [extent.x,extent.y])
	await _size(Vector2i(1280,720))
	world.return_to_hub()
	await _road()
	screen.open_map()
	await _step(3)
	_check(not card.panel.visible and not screen.tracker.visible and screen.is_open and screen.tabs.current_tab == 2, "Unified map modal suppresses the region frame and has no gameplay tracker")
	await _capture("combined_card_inventory_hidden")
	screen.close()
	await _step(3)
	_check(card.panel.visible and not screen.tracker.visible and screen.map_button.visible, "Closing map restores the frame and launcher")
	world.open_npc(NpcCatalog.HEALER)
	world.dialogue.advance()
	await _step(3)
	_check(not card.panel.visible and world.dialogue.is_open, "Actual Thanh Vy dialogue suppresses the region card")
	await _capture("combined_card_dialogue_hidden")
	world.dialogue.close()
	await _road()
	await _key(KEY_ESCAPE,true)
	await _key(KEY_ESCAPE,false)
	_check(not card.panel.visible and not world.outside, "Actual Esc cancels the card without travel")
	await _away()
	await _road()
	_check(card.panel.visible and not screen.tracker.visible and screen.map_button.visible, "Leaving and re-entering restores frame/launcher without a quest overlay")
	_check(TimeScaleClaims.owner_count(self) == 0 and is_equal_approx(Engine.time_scale,1), "Combined views own no gameplay time claim")
	var output: FileAccess = FileAccess.open("res://docs/verification/region_entry/combined_geometry_%d.json" % Engine.physics_ticks_per_second,FileAccess.WRITE)
	if output == null:
		print("FAIL: Combined geometry evidence writer unavailable")
		quit(2)
		return
	output.store_string(JSON.stringify(geometry,"\t"))
	output.close()
	world.queue_free()
	await _step(8)
	_check(not is_instance_valid(card), "Combined fixture releases its card and world")
	print("RESULT RegionUIProbe %d checks, %d failures; actual reviewed UI+card; capture=%s" % [checks,failures,capture])
	quit(0 if failures == 0 else 1)

extends "res://tests/region_entry_card_test.gd"
## Functional Map/Quest QA on real exterior Hub; isolated fixture writes only.
var map_geometry: Array[Dictionary] = []
var screen: InventoryScreen
var journal: QuestJournal
var attacks: int = 0
var captured: int = 0

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	capture = OS.get_cmdline_user_args().has("--capture")
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/") or (capture and DisplayServer.get_name() == "headless"):
		print("FAIL: MapQuest QA requires isolated user:// and an assigned renderer")
		quit(2)
		return
	print("MAP ENV "+JSON.stringify({"display":DisplayServer.get_name(),"user_data":OS.get_user_data_dir(),"executable":OS.get_executable_path()}))
	DirAccess.make_dir_recursive_absolute("res://docs/verification/map_quest")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	AudioServer.set_bus_mute(0,true)
	input_map_before = _input_map()
	profile = CountingProfile.new()
	profile.save_path = "user://verification/map_unused_%d.json" % OS.get_process_id()
	world = preload("res://scenes/hub/exterior_hub_room.tscn").instantiate() as ExteriorHub
	world.profile = profile
	world.world_building_enabled = true
	root.add_child(world)
	current_scene = world
	await _step(10)
	actor = world.player
	card = world.entry_card
	screen = world.gear.modal as InventoryScreen
	journal = screen.journal
	leak_probe = InputLeakProbe.new()
	root.add_child(leak_probe)
	actor.equipped_weapon.attack_committed.connect(func(_snapshot: AttackSnapshot) -> void: attacks += 1)
	profile.opening_progress = OpeningProgress.empty()
	profile.changed.emit()
	var inventory: GearInventory = world.gear.inventory
	var ledger: Dictionary = GearInventoryCodec.encode(inventory)
	var saved: Dictionary = profile.exterior_progress.duplicate(true)
	var opening: Dictionary = profile.opening_progress.duplicate(true)
	var writes: int = profile.saves
	var transitions: int = world.transition_count
	_check(journal.rows.size() == 6 and journal.rows[0]["next"] and journal.rows[0]["id"] == &"explored", "Reads the six canonical milestones in their existing order")
	_check(journal.tracker_text().is_empty() and not screen.tracker.visible, "Gameplay has no persistent quest overlay")
	_check(screen.panel.get_theme_stylebox("panel") is StyleBoxTexture, "Map panel uses shared antique artwork instead of a flat background override")
	_check(journal.objective_label.get_theme_color("font_color") == AntiqueSkin.TEXT, "Map/Quest body inherits the shared readable ivory token")
	_check("Thanh Vy" in str(journal.rows) and "Vô Danh" in str(journal.rows) and journal.graph.known.size() == 1, "Concrete quest instructions identify Hub NPCs without revealing unknown map rooms")
	_check(journal.graph.known.size() == 1 and journal.graph.known.has(ExteriorRouteCatalog.HUB), "New profile shows only the known Hub")
	for room: StringName in ExteriorRouteCatalog.all_rooms():
		var button: Button = journal.graph.buttons[room]
		_check(button.disabled and button.text == "?" and button.tooltip_text.is_empty(), "Unknown room has no revealed name or actionable pin: %s" % room)
	for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		await _size(extent)
		await _road()
		_check(card.panel.visible and _name_only() and not screen.tracker.visible, "Name-only region frame remains eligible at %s" % extent)
		_check(not card.panel.get_global_rect().intersects(screen.map_button.get_global_rect()), "Region frame avoids the map launcher at %s" % extent)
		await _shot("gameplay_frame_%dx%d" % [extent.x,extent.y])
		await _tap_key(KEY_M)
		_check(screen.is_open and screen.tabs.current_tab == 2 and not card.panel.visible, "M opens the unified page and suppresses the region frame at %s" % extent)
		_check(not actor.controls_enabled and is_equal_approx(Engine.time_scale,.1) and TimeScaleClaims.owner_count(self) == 1, "Map uses exactly the existing inventory control/time claim")
		_check(root.gui_get_focus_owner() == journal.quest_buttons[journal.selected_id], "Opening map focuses its selected quest")
		_map_bounds(extent)
		await _shot("map_new_%dx%d" % [extent.x,extent.y])
		journal.extension_rows_provider = _long_rows
		journal.refresh()
		journal.select_quest(&"qa_long")
		await _step(4)
		_check(journal.rows.size() == 7 and journal.objective_label.text.length() > 2000 and journal.objective_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Long Vietnamese detail wraps without data truncation at %s" % extent)
		_check(journal.detail_scroll.get_v_scroll_bar().max_value > journal.detail_scroll.size.y, "Long detail uses its own scroll region at %s" % extent)
		_check(journal.graph.objective_room == &"", "Unknown extension target cannot reveal a map pin")
		journal.detail_scroll.scroll_vertical = 0
		await _tap_key(KEY_PAGEDOWN)
		_check(journal.detail_scroll.scroll_vertical > 0 and journal.selected_id == &"qa_long", "PageDown reads long details without changing quest selection")
		await _tap_key(KEY_PAGEUP)
		_check(journal.detail_scroll.scroll_vertical == 0, "PageUp returns to the start of long details")
		await _axis(JOY_AXIS_RIGHT_Y,.8)
		_check(journal.detail_scroll.scroll_vertical > 0, "Right-stick hold scrolls the long detail independently of gameplay time")
		await _axis(JOY_AXIS_RIGHT_Y,0)
		var scroll_before: int = journal.detail_scroll.scroll_vertical
		var wheel := InputEventMouseButton.new()
		wheel.position = journal.detail_scroll.get_global_rect().get_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel,true)
		await _step(3)
		_check(journal.detail_scroll.scroll_vertical > scroll_before, "Mouse wheel scrolls the long detail in its own region")
		journal.detail_scroll.scroll_vertical = 0
		_map_bounds(extent)
		await _shot("map_long_%dx%d" % [extent.x,extent.y])
		journal.extension_rows_provider = Callable()
		journal.refresh()
		leak_probe.last_pressed = null
		for code: Key in [KEY_E,KEY_J,KEY_I,KEY_SPACE,KEY_SHIFT,KEY_1,KEY_F,KEY_BACKSPACE]: await _tap_key(code)
		_check(attacks == 0 and not actor.equipped_weapon.hitbox.active and world.transition_count == transitions and leak_probe.last_pressed == null, "Map consumes world combat/travel/rune shortcuts before gameplay; attacks=%d transitions=%d last=%s" % [attacks,world.transition_count,str(leak_probe.last_pressed.as_text()) if leak_probe.last_pressed != null else "none"])
		_check(GearInventoryCodec.encode(inventory) == ledger, "Map shortcuts never equip, unequip or alter the UID ledger")
		await _tap_key(KEY_ESCAPE)
		_check(not screen.is_open and actor.controls_enabled and is_equal_approx(Engine.time_scale,1) and screen.map_button.visible and not screen.map_button.has_focus(), "Escape restores gameplay without focusing its visible map launcher")
		_check(card.panel.visible and not screen.tracker.visible, "Closing map restores the name-only frame without a tracker")
		leak_probe.last_pressed = null
		await _tap_key(KEY_SPACE)
		_check(not screen.is_open and leak_probe.last_pressed != null and leak_probe.last_pressed.is_action_pressed(&"jump"), "Space after closing map reaches gameplay jump without reopening the map")
	await _size(Vector2i(1280,720))
	await _click_map()
	_check(screen.is_open and screen.tabs.current_tab == 2, "Actual mouse click opens the map launcher")
	var first: Button = journal.quest_buttons[&"explored"]
	first.grab_focus()
	await _tap_key(KEY_DOWN)
	_check(journal.selected_id == &"golem_defeated", "Keyboard Down navigates canonical quest selection")
	await _tap_key(KEY_LEFT)
	_check(root.gui_get_focus_owner() is Button, "Keyboard navigation reaches an eligible map/quest control")
	await _tap_joy(JOY_BUTTON_B)
	_check(not screen.is_open and actor.controls_enabled, "Controller B closes the same modal")
	await _joy(JOY_BUTTON_BACK,true)
	await _joy(JOY_BUTTON_BACK,true)
	_check(screen.is_open and screen.tabs.current_tab == 2 and TimeScaleClaims.owner_count(self) == 1, "Held View cannot bounce or acquire a second time claim")
	await _joy(JOY_BUTTON_BACK,false)
	first = journal.quest_buttons[&"explored"]
	first.grab_focus()
	await _tap_joy(JOY_BUTTON_DPAD_DOWN)
	_check(journal.selected_id == &"golem_defeated", "Controller D-pad navigates quest selection")
	await _axis(JOY_AXIS_LEFT_Y,.8)
	_check(journal.selected_id == &"reward_collected", "Controller left-stick threshold navigates quest selection")
	await _axis(JOY_AXIS_LEFT_Y,0)
	await _tap_joy(JOY_BUTTON_BACK)
	_check(not screen.is_open and TimeScaleClaims.owner_count(self) == 0, "View closes the map and releases its sole claim")
	screen.open()
	await _step(3)
	_check(screen.tabs.current_tab == 0, "Inventory shortcut keeps its equipment-first contract after a map session")
	await _tap_key(KEY_M)
	_check(screen.tabs.current_tab == 2 and TimeScaleClaims.owner_count(self) == 1, "Inventory-to-map switch reuses its current owner")
	await _tap_key(KEY_TAB)
	_check(not screen.is_open and actor.controls_enabled, "Tab retains inventory cancellation")
	for cycle: int in 8:
		await _tap_key(KEY_M)
		await _tap_key(KEY_M)
	_check(not screen.is_open and TimeScaleClaims.owner_count(self) == 0 and is_equal_approx(Engine.time_scale,1), "Repeated open/close leaves no stale time claim")
	_check(profile.saves == writes and profile.exterior_progress == saved and profile.opening_progress == opening and not FileAccess.file_exists(profile.save_path), "Read-only map sessions never save or modify canonical progress")
	paused = true
	await _tap_key(KEY_M)
	_check(not screen.is_open and paused, "Paused gameplay cannot open a new map")
	paused = false
	await _tap_key(KEY_M)
	paused = true
	await _tap_key(KEY_ESCAPE)
	_check(paused and not screen.is_open and is_equal_approx(Engine.time_scale,1), "An already-open map remains cancelable while paused")
	paused = false
	world.station_open = true
	await _tap_key(KEY_M)
	_check(not screen.is_open, "Station UI blocks the map even before a control-state change")
	world.station_open = false
	world.open_npc(NpcCatalog.HEALER)
	await _tap_key(KEY_M)
	_check(world.dialogue.is_open and not screen.is_open, "Dialogue keeps its existing owner when M is pressed")
	world.dialogue.close()
	actor.health.current_health = 0
	await _tap_key(KEY_M)
	_check(not screen.is_open, "Dead actor cannot open the map")
	actor.health.current_health = actor.health.maximum_health
	await _away()
	_check(world.enter_exterior(&"o01_p01"), "Actual exterior owner commits a discovery")
	await _step(5)
	writes = profile.saves
	saved = profile.exterior_progress.duplicate(true)
	opening = profile.opening_progress.duplicate(true)
	await _tap_key(KEY_M)
	_check(journal.graph.known.size() == 2 and journal.graph.current_room == &"o01_p01" and "Đèn nghiêng" in journal.state_label.text, "Saved P01 discovery and actual exterior context appear on the map")
	_check(not world.return_to_hub() and not world.enter_exterior(&"o01_p02"), "Existing travel API rejects transitions while map owns controls")
	await _mouse_button(journal.graph.buttons[ExteriorRouteCatalog.HUB])
	_check(world.outside and world.exterior.room_id == &"o01_p01" and profile.saves == writes and world.transition_count == transitions+1, "Map-room mouse selection is read-only, never fast travel")
	journal.select_quest(&"golem_defeated")
	(journal.graph.buttons[ExteriorRouteCatalog.HUB] as Button).grab_focus()
	await _tap_joy(JOY_BUTTON_A)
	_check("Khu đã đến" in journal.map_info.text and world.outside and world.transition_count == transitions+1, "Controller A reads a known map node without travel or double commit")
	journal.select_quest(&"golem_defeated")
	await _shot("map_p01_1280x720")
	journal.select_quest(&"golem_defeated")
	_check(journal.graph.objective_room == ExteriorRouteCatalog.HUB, "Unaccepted bounty points to its known Hub contract location")
	profile.bounty_accepted = true
	profile.changed.emit()
	_check("Golem" in journal.objective_label.text and journal.graph.objective_room == &"", "Accepted bounty names its boss without inventing a map position")
	profile.opening_progress = {"version":1,"completed":OpeningProgress.IDS.map(func(id: StringName) -> String: return String(id))}
	profile.changed.emit()
	_check("6 / 6" in journal.state_label.text and "Đã hoàn tất" in journal.state_label.text and not str(journal.rows).contains('"next": true'), "Completed opening preserves all canonical rows and explicit completion")
	journal.select_quest(&"explored")
	_check(journal.graph.objective_room == &"" and "hoàn tất" in journal.map_info.text, "Completed milestone never leaves a pending-objective pin")
	await _shot("map_complete_1280x720")
	profile.opening_progress_quarantined = true
	profile.changed.emit()
	_check(journal.rows.is_empty() and journal.quest_buttons.is_empty() and "Chưa có" in journal.detail_title.text, "Quarantined progress has an explicit empty state without guessing milestones")
	await _shot("map_empty_1280x720")
	profile.opening_progress_quarantined = false
	profile.opening_progress = opening
	profile.exterior_progress_quarantined = true
	profile.changed.emit()
	_check(journal.graph.known.size() == 1 and journal.graph.current_room == &"", "Quarantined geography never reveals saved room names")
	profile.exterior_progress_quarantined = false
	profile.changed.emit()
	journal.context_provider = func() -> Dictionary: return {"room":&"","label":"Hầm ngục · ngoài sơ đồ đường bộ"}
	journal.refresh()
	_check(journal.graph.current_room == &"" and "Hầm ngục" in journal.state_label.text, "Dungeon context cannot falsely mark the last exterior room as current")
	journal.context_provider = screen._map_context
	journal.refresh()
	_check(profile.saves == writes and profile.exterior_progress == saved and GearInventoryCodec.encode(inventory) == ledger, "Discovery/empty/complete projections still leave saves and UID ledger untouched")
	await _tap_key(KEY_ESCAPE)
	await _shot("gameplay_p01_1280x720")
	_check(world.enter_exterior(&"o01_p02",ExteriorRouteCatalog.MAIN,&"west",false), "Prepare existing noncommitting restore context")
	await _step(4)
	# Deliberately stale fixture snapshot: scene context and fog have different owners.
	profile.exterior_progress = saved.duplicate(true)
	profile.changed.emit()
	await _tap_key(KEY_M)
	_check("Cầu dây" in journal.state_label.text and journal.graph.current_room == &"" and profile.exterior_progress == saved, "Current-area label reads the actual scene while fog still reads saved discoveries")
	await _tap_key(KEY_ESCAPE)
	await _save_roundtrip(saved,opening)
	_check(_input_map() == input_map_before, "Map/controller bindings leave the shared InputMap unchanged")
	var detached := QuestJournal.new()
	root.add_child(detached); detached.hide(); detached.bind_progress(profile,inventory)
	var detached_rows: Array[Dictionary] = detached.rows.duplicate(true)
	root.remove_child(detached)
	_check(not profile.changed.is_connected(detached._request_refresh), "Detached journal releases its persistent profile subscription before scene replacement")
	profile.changed.emit(); detached.refresh(); detached.focus_first()
	_check(detached.rows == detached_rows and not detached.is_inside_tree(), "Late profile/deferred focus callbacks do not access a missing viewport")
	root.add_child(detached); profile.changed.emit()
	_check(profile.changed.is_connected(detached._request_refresh) and detached.rows == journal.rows, "Re-entering the tree restores one live read-only profile projection")
	detached.queue_free(); await _step(2)
	var evidence: FileAccess = FileAccess.open("res://docs/verification/map_quest/geometry.json",FileAccess.WRITE)
	evidence.store_string(JSON.stringify(map_geometry,"\t"))
	evidence.close()
	world.queue_free()
	leak_probe.queue_free()
	await _step(8)
	_check(not is_instance_valid(screen) and is_equal_approx(Engine.time_scale,1), "Fixture teardown releases the world/UI and time ownership")
	await root.get_node("AudioManager").shutdown()
	print("RESULT MapQuest %d checks, %d failures; captures=%d" % [checks,failures,captured])
	quit(0 if failures == 0 else 1)

func _long_rows() -> Array[Dictionary]:
	return [{"id":&"qa_long","title":"Ghi chép thử nghiệm: lời hẹn dài bên bậc đá và đường giữ đèn để kiểm tra chữ tiếng Việt", "body":"Ngọn đèn còn cháy bên bậc đá. Hãy đọc dấu nước, cân nhắc lời hẹn và đi tiếp khi đã chuẩn bị. ".repeat(35),"target":&"o02_b04"},{"id":&"explored","title":"Không được ghi đè canon","body":"Bản sao phải bị bỏ qua."}]

func _map_bounds(extent: Vector2i) -> void:
	var bounds: Rect2 = root.get_visible_rect()
	var footer: Control = screen.panel.get_child(0).get_child(1) as Control
	_check(bounds.encloses(screen.panel.get_global_rect()) and bounds.encloses(footer.get_global_rect()), "Map panel and close footer stay in viewport at %s" % extent)
	_check(screen.content_scroll.get_global_rect().encloses(screen.tabs.get_tab_bar().get_global_rect()), "Map tab navigation stays fully visible in the outer scroll area at %s" % extent)
	_check(journal.columns.get_global_rect().encloses(journal.graph.get_global_rect()) and journal.graph.get_global_rect().end.x < journal.quest_scroll.get_global_rect().position.x, "Map stays left of the quest column at %s" % extent)
	_check(screen.content_scroll.get_global_rect().encloses(journal.detail_scroll.get_global_rect()), "Quest details remain in the visible page at %s" % extent)
	_check(screen.content_scroll.get_global_rect().encloses(journal.map_info.get_global_rect()), "Known/unknown target explanation stays fully visible at %s" % extent)
	for button: Button in journal.graph.buttons.values(): _check(journal.graph.get_global_rect().encloses(button.get_global_rect()), "Graph node remains bounded at %s" % extent)
	map_geometry.append({"viewport":str(extent),"panel":str(screen.panel.get_global_rect()),"graph":str(journal.graph.get_global_rect()),"quests":str(journal.quest_scroll.get_global_rect()),"detail":str(journal.detail_scroll.get_global_rect()),"footer":str(footer.get_global_rect())})

func _tap_key(code: Key) -> void:
	await _key(code,true)
	await _key(code,false)

func _tap_joy(button: JoyButton) -> void:
	await _joy(button,true)
	await _joy(button,false)

func _axis(axis: JoyAxis,value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	root.push_input(event,true)
	await _step(2)

func _click_map() -> void:
	await _mouse_button(screen.map_button)

func _mouse_button(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event,true)
	await _step(2)
	event.pressed = false
	root.push_input(event,true)
	await _step(3)

func _shot(name: String) -> void:
	if not capture: return
	await _step(3)
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://docs/verification/map_quest/"+name+".png")
	_check(result == OK,"Actual GPU screenshot saved: "+name)
	if result == OK: captured += 1

func _save_roundtrip(exterior: Dictionary,milestones: Dictionary) -> void:
	var saved_profile := SanctuaryProfile.new()
	saved_profile.save_path = "user://verification/map_roundtrip_%d.json" % OS.get_process_id()
	saved_profile.exterior_progress = exterior.duplicate(true)
	saved_profile.opening_progress = milestones.duplicate(true)
	_check(saved_profile.save(), "Existing profile owner saves fixture discovery/milestones without a new schema")
	var bytes: String = FileAccess.get_file_as_string(saved_profile.save_path)
	var loaded := SanctuaryProfile.new()
	loaded.save_path = saved_profile.save_path
	_check(loaded.load_profile() and MapQuestProjection.known_rooms(loaded).has(&"o01_p01") and MapQuestProjection.rows(loaded).size() == 6, "Cold profile reload restores discoveries and canonical quest projection")
	MapQuestProjection.rows(loaded)
	MapQuestProjection.known_rooms(loaded)
	_check(FileAccess.get_file_as_string(saved_profile.save_path) == bytes, "Reading restored map state does not rewrite its save bytes")

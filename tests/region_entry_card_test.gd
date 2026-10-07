extends SceneTree
## Focused tests on the current P01/NPC baseline; all writable state is isolated.
class CountingProfile extends SanctuaryProfile:
	var saves: int = 0
	var fail_save: bool = false
	func save() -> bool:
		saves += 1
		return not fail_save

class InputLeakProbe extends Node:
	var last_pressed: InputEvent
	func _unhandled_input(event: InputEvent) -> void:
		if event.is_pressed(): last_pressed = event

var checks: int = 0
var failures: int = 0
var world: ExteriorHub
var actor: Player
var profile: CountingProfile
var card: RegionEntryCard
var capture: bool = false
var input_map_before: String
var geometry: Array[Dictionary] = []
var leak_probe: InputLeakProbe

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	capture = OS.get_cmdline_user_args().has("--capture")
	_check(not capture or DisplayServer.get_name() != "headless", "Screenshots require an explicitly assigned GPU process")
	var allowed_root: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	var actual_user: String = OS.get_user_data_dir().replace("\\", "/")
	var isolated: bool = allowed_root.is_absolute_path() and actual_user.begins_with(allowed_root + "/")
	_check(isolated, "user:// is inside the explicitly authorized private QA root")
	if not isolated:
		quit(2)
		return
	print("REGION ENV "+JSON.stringify({"display":DisplayServer.get_name(),"user_data":OS.get_user_data_dir(),"physics_hz":Engine.physics_ticks_per_second}))
	# The full runner invokes this fixture directly rather than its worker wrapper.
	DirAccess.make_dir_recursive_absolute("res://docs/verification/region_entry")
	AudioServer.set_bus_mute(0,true)
	input_map_before = _input_map()
	profile = CountingProfile.new()
	profile.save_path = "user://verification/entry_fixture_%d.json" % Time.get_ticks_usec()
	world = preload("res://scenes/hub/exterior_hub_room.tscn").instantiate() as ExteriorHub
	world.profile = profile
	world.world_building_enabled = true
	root.add_child(world)
	current_scene = world
	leak_probe = InputLeakProbe.new()
	root.add_child(leak_probe)
	await _step(10)
	actor = world.player
	card = world.entry_card
	var inventory: GearInventory = world.gear.inventory
	var ledger: Dictionary = GearInventoryCodec.encode(inventory)
	profile.coins = 73
	actor.health.current_health = 37
	actor.energy.current = 41
	actor.energy.regeneration_delay = 10000
	var saved: Dictionary = profile.exterior_progress.duplicate(true)
	var writes: int = profile.saves
	var count: int = world.transition_count
	await _road()
	_check(card.panel.visible and card.destination["room"] == &"o01_p01" and card.title_label.text == "Đèn nghiêng và bậc đá", "Road approach shows only its actual linked area name before E")
	_check(_name_only(), "Frame contains exactly one area-name Label; no images, descriptions, status or key hints")
	var frame_style: StyleBoxFlat = card.panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(frame_style.border_color == RegionEntryCard.RED and frame_style.corner_radius_top_left == 0 and card.title_label.get_theme_color("font_color") == RegionEntryCard.TEXT, "Rectangular antique frame retains lacquer-red border and warm gold text")
	var worst_background: Color = RegionEntryCard.INK.lerp(Color.WHITE,0.03)
	_check(_contrast(RegionEntryCard.TEXT,worst_background) >= 7.0, "Area name has at least 7:1 contrast even over a white world behind the 97-percent panel")
	await _step(8)
	_check(profile.saves == writes and profile.exterior_progress == saved and world.transition_count == count and not world.outside, "Approach/wait never commits discovery or auto-travels")
	_check(actor.controls_enabled and is_equal_approx(Engine.time_scale,1) and TimeScaleClaims.owner_count(self) == 0 and root.gui_get_focus_owner() == null, "Preview acquires no focus, control suspension or time claim")
	_check(_mouse_transparent(card.panel), "Every preview Control ignores mouse input and cannot claim keyboard focus")
	_check(not world.prompt.visible and _name_only(), "Visible frame contains no duplicate interaction hint")
	for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		await _size(extent)
		await _road()
		_geometry("hub_p01_%dx%d" % [extent.x,extent.y])
		await _capture("hub_p01_%dx%d" % [extent.x,extent.y])
	await _key(KEY_ESCAPE,true)
	await _key(KEY_ESCAPE,false)
	_check(leak_probe.last_pressed == null, "Visible-card Esc is consumed before gameplay unhandled input")
	_check(not card.panel.visible and world.prompt.visible and not world.outside and profile.saves == writes, "Esc dismisses without travel, save or modal ownership")
	await _step(4)
	_check(not card.panel.visible, "Dismissal stays in effect while still at the same doorway")
	await _away()
	await _road()
	_check(card.panel.visible, "Leaving range and returning restores the card")
	await _joy(JOY_BUTTON_B,true)
	await _joy(JOY_BUTTON_B,false)
	_check(leak_probe.last_pressed == null, "Visible-card B is consumed before gameplay unhandled input")
	_check(not card.panel.visible and not world.outside, "Controller B dismisses the visible doorway preview")
	# E remains available after dismissal through the original router.
	await _key(KEY_E,true)
	_check(leak_probe.last_pressed == null, "Original portal E is consumed before gameplay unhandled input")
	_check(world.outside and world.exterior.room_id == &"o01_p01" and world.transition_count == count+1 and profile.saves == writes+1, "Original real E routing still commits exactly one transition after dismissal")
	await _key(KEY_E,true)
	_check(world.transition_count == count+1, "Held E cannot bounce through the newly loaded doorway")
	await _key(KEY_E,false)
	await _at(&"door_west")
	_check(card.panel.visible and card.destination["room"] == ExteriorRouteCatalog.HUB and card.title_label.text == "Căn Cứ Lữ Khách" and _name_only(), "Return door shows only its actual Hub area name")
	_geometry("p01_hub")
	await _capture("p01_hub")
	await _joy(JOY_BUTTON_X,true)
	_check(leak_probe.last_pressed == null, "Visible-card X is consumed before gameplay unhandled input")
	_check(not world.outside and world.transition_count == count+2, "Controller X uses the existing guarded station dispatch")
	await _joy(JOY_BUTTON_X,true)
	_check(world.transition_count == count+2, "Held X cannot bounce through the new road")
	await _joy(JOY_BUTTON_X,false)
	await _road()
	_check(card.title_label.text == "Đèn nghiêng và bậc đá" and _name_only() and profile.exterior_progress["discovered_rooms"].has("o01_p01"), "Visited area keeps the same name-only frame; discovery stays in the existing ledger")
	profile.fail_save = true
	saved = profile.exterior_progress.duplicate(true)
	var position: Vector2 = actor.global_position
	await _key(KEY_E,true)
	await _key(KEY_E,false)
	_check(not world.outside and profile.exterior_progress == saved and actor.global_position.distance_to(position) < 2 and card.panel.visible, "Failed save retains room/ledger/position and a usable preview")
	profile.fail_save = false
	world.reject_next_load = true
	await _key(KEY_E,true)
	await _key(KEY_E,false)
	_check(not world.outside and card.panel.visible and world.transition_count == count+2, "Rejected load retains its current room and preview")
	# No airborne preview or input dispatch.
	actor.relocate(world.stations[&"exterior_road"].global_position+Vector2(0,-60))
	await _step(1)
	_check(not card.panel.visible and not actor.motor.is_grounded(), "Airborne approach hides the grounded-only preview")
	await _joy(JOY_BUTTON_X,true)
	await _joy(JOY_BUTTON_X,false)
	_check(not world.outside, "Controller X cannot bypass the standing-ground travel guard")
	await _road()
	world.gear.modal.open()
	await _step(2)
	_check(not card.panel.visible and world.gear.modal.is_open, "Inventory owns its UI and hides the doorway preview")
	await _joy(JOY_BUTTON_X,true)
	await _joy(JOY_BUTTON_X,false)
	_check(not world.outside and world.gear.modal.is_open, "Preview X cannot transition under the inventory modal")
	world.gear.modal.close()
	await _step(3)
	_check(card.panel.visible and actor.controls_enabled, "Closing inventory restores the same eligible preview")
	world.station_open = true
	await _step(2)
	_check(not card.panel.visible, "Station UI suppresses the card")
	world.station_open = false
	world.dialogue.open("Kiểm tra",["Một cuộc thoại đang sở hữu đầu vào."],[])
	await _step(2)
	_check(not card.panel.visible, "Dialogue suppresses the card even before a controls change")
	world.dialogue.close()
	await _step(3)
	paused = true
	for tick: int in 3: await process_frame
	_check(not card.panel.visible and not world.outside, "Paused tree hides the always-processing card without travel")
	paused = false
	await _step(3)
	_check(card.panel.visible, "Resume restores the eligible doorway preview")
	actor.health.current_health = 0
	await _step(2)
	_check(not card.panel.visible, "Dead actor cannot display an actionable travel card")
	actor.health.current_health = 37
	await _step(3)
	# Repeat nonmodal open/cancel cycles without rebuilding the card.
	# The reviewed inventory UI deliberately restores focus to its open button.
	var focus_before_cycles: Control = root.gui_get_focus_owner()
	for cycle: int in 5:
		await _away()
		await _road()
		await _key(KEY_ESCAPE,true)
		await _key(KEY_ESCAPE,false)
	_check(world.entry_card == card and TimeScaleClaims.owner_count(self) == 0 and root.gui_get_focus_owner() == focus_before_cycles and is_equal_approx(Engine.time_scale,1), "Repeated approaches/cancels retain one card and preserve existing focus without input/time ownership")
	await _away()
	await _road()
	await _key(KEY_E,true)
	await _key(KEY_E,false)
	# A stale card must not route X into an NPC that has just become nearer.
	await _at(&"door_west")
	# Offset within range: a zero-distance door wins ties in the original API.
	PlayerTravel.relocate(actor,actor.global_position+Vector2(35,0))
	await _step(5)
	var npc: NpcPilotActor = world.npc_population.actors["pilot_traveler"]
	var old_position: Vector2 = npc.global_position
	npc.global_position = actor.global_position
	_check(String(world.nearest_station()) == "pilot_traveler", "Stale-card fixture gives the NPC strictly nearer precedence")
	var old_transition: int = world.transition_count
	await _joy(JOY_BUTTON_X,true)
	_check(not world.dialogue.is_open and world.transition_count == old_transition, "Stale preview X cannot open a newly nearer NPC or change region")
	await _joy(JOY_BUTTON_X,false)
	npc.global_position = old_position
	await _step(2)
	PlayerTravel.relocate(actor,npc.global_position)
	await _step(4)
	_check(not card.panel.visible and String(world.nearest_station()) == "pilot_traveler", "Current NPC precedence removes the door card")
	await _key(KEY_E,true)
	await _key(KEY_E,false)
	_check(world.dialogue.is_open and world.npc_population.talking_id == "pilot_traveler" and not card.panel.visible, "Existing E still opens the actual pilot NPC dialogue")
	world.dialogue.close()
	await _step(3)
	# Test every authored outgoing door without revealing anything but its entrance.
	await _size(Vector2i(800,600))
	for room: StringName in ExteriorRouteCatalog.ROOMS:
		_check(world.enter_exterior(room,ExteriorRouteCatalog.MAIN,&"west",false), "Prepare current room %s" % room)
		await _step(5)
		for door: StringName in [&"door_west",&"door_east"]:
			var target: Dictionary = ExteriorRouteCatalog.link(room,ExteriorRouteCatalog.MAIN,door)
			if target.is_empty(): continue
			await _at(door)
			_check(card.panel.visible and card.destination == target and card.title_label.text == _expected_name(target["room"],target["route"]), "Linked area name displayed at %s/%s" % [room,door])
			_geometry("%s_%s" % [room,door])
			await _capture("%s_%s" % [room,door])
			if room == &"o01_p02" and door == &"door_west":
				_check(target["room"] == &"o01_p01" and target["anchor"] == &"east" and card.title_label.text == "Đèn nghiêng và bậc đá" and _name_only(), "P02 west door targets P01 east with only its name and no misleading entrance image")
			if target["room"] != &"o01_p01" and target["room"] != ExteriorRouteCatalog.HUB:
				_check(_name_only(), "Graybox destination shows only its name without image, discovery state, threat or reward")
	_check(world.enter_exterior(&"o01_p01",ExteriorRouteCatalog.MAIN,&"west",false), "Prepare tunnel doorway")
	await _step(5)
	await _at(&"tunnel")
	_check(card.panel.visible and card.title_label.text == "Đường giữ đèn" and _name_only(), "Tunnel frame shows only its route name without shortcut or discovery claims")
	_geometry("p01_tunnel")
	await _capture("p01_tunnel")
	await _size(Vector2i(800,600))
	card.title_label.text = "Đường núi cổ qua thung lũng và dòng sông phía bắc"
	await _step(5)
	_check(card.title_label.get_line_count() > 1 and _name_only(), "Long Vietnamese area name wraps without adding any secondary text")
	_geometry("long_text_800x600")
	await _capture("long_text_800x600")
	_check(_input_map() == input_map_before, "Runtime action map and keyboard/controller contracts were not edited")
	_check(world.player == actor and world.gear.inventory == inventory and GearInventoryCodec.encode(inventory) == ledger and actor.health.current_health == 37 and actor.energy.current == 41 and profile.coins == 73, "Preview/travel preserve actor, item IDs/UID ledger, health, energy and economy")
	var output := FileAccess.open("res://docs/verification/region_entry/geometry.json",FileAccess.WRITE)
	if output == null:
		print("FAIL: Region geometry evidence writer unavailable")
		quit(2)
		return
	output.store_string(JSON.stringify(geometry,"\t"))
	output.close()
	world.queue_free()
	await _step(8)
	_check(not is_instance_valid(card) and TimeScaleClaims.owner_count(self) == 0 and is_equal_approx(Engine.time_scale,1), "Private fixture cleanup releases card, modal and time claims")
	print("RESULT RegionEntry %d checks, %d failures; GPU screenshots=%s" % [checks,failures,str(capture)])
	quit(0 if failures == 0 else 1)

func _road() -> void:
	PlayerTravel.relocate(actor,world.stations[&"exterior_road"].global_position)
	await _step(5)

func _away() -> void:
	PlayerTravel.relocate(actor,Vector2(1000,640))
	await _step(5)
	_check(not card.panel.visible and card.current_key.is_empty(), "Leaving portal range clears the preview/dismissal")

func _at(id: StringName) -> void:
	var point: Vector2 = world.exterior.interactions[id]
	PlayerTravel.relocate(actor,ExteriorHub.ORIGIN+point)
	await _step(5)

func _size(extent: Vector2i) -> void:
	root.size = extent
	root.content_scale_size = extent
	await _step(5)

func _geometry(case_name: String) -> void:
	var rect: Rect2 = card.panel.get_global_rect()
	var extent: Vector2 = root.get_visible_rect().size
	var foot: Vector2 = root.get_canvas_transform()*actor.global_position
	var actor_rect := Rect2(foot+Vector2(-23,-66),Vector2(46,66))
	geometry.append({"case":case_name,"viewport":str(extent),"panel":str(rect),"actor":str(actor_rect),"title_lines":card.title_label.get_line_count(),"area_name":card.title_label.text})
	# get_global_rect() can round width340 to340.0001 after native canvas transforms.
	# Only width allows a0.001px epsilon; viewport enclosure and all overlaps stay strict.
	_check(Rect2(Vector2.ZERO,extent).encloses(rect) and rect.size.x <= 340.001 and rect.size.y < extent.y-90, "Preview stays inside the PC viewport: "+case_name)
	_check(not rect.intersects(actor_rect), "Preview leaves the actual player's body/feet readable: "+case_name)
	_check(not rect.intersects(RegionEntryCard.HUD_SAFE_RECT), "Preview leaves the existing health/rune HUD readable: "+case_name)
	var title_rect: Rect2 = card.title_label.get_global_rect()
	_check(title_rect.position.x >= rect.position.x+41 and title_rect.end.x <= rect.end.x-41 and title_rect.position.y >= rect.position.y+21 and title_rect.end.y <= rect.end.y-21, "Wrapped area name stays clear of ornamental corners and border: "+case_name)
	var screen: InventoryScreen = world.gear.modal as InventoryScreen
	for control: Control in [screen.open_button,screen.tracker]:
		if is_instance_valid(control) and control.is_visible_in_tree():
			_check(not rect.intersects(control.get_global_rect()), "Frame leaves actual inventory button/quest tracker readable: "+case_name)
	print("REGION CASE "+case_name+" panel="+str(rect)+" actor="+str(actor_rect))

func _mouse_transparent(node: Node) -> bool:
	if node is Control and (node.mouse_filter != Control.MOUSE_FILTER_IGNORE or node.focus_mode != Control.FOCUS_NONE): return false
	for child: Node in node.get_children():
		if not _mouse_transparent(child): return false
	return true

func _name_only() -> bool:
	return card.get_child_count() == 1 and card.panel.get_child_count() == 1 and card.panel.get_child(0) == card.title_label

func _expected_name(room: StringName, route: StringName) -> String:
	if room == ExteriorRouteCatalog.HUB: return "Căn Cứ Lữ Khách"
	if route == ExteriorRouteCatalog.TUNNEL: return "Đường giữ đèn"
	return ExteriorRouteCatalog.TITLES[ExteriorRouteCatalog.ROOMS.find(room)]

func _contrast(foreground: Color, background: Color) -> float:
	var front: float = _luminance(foreground)
	var back: float = _luminance(background)
	return (maxf(front,back)+0.05)/(minf(front,back)+0.05)

func _luminance(color: Color) -> float:
	var linear := Vector3.ZERO
	for index: int in 3:
		var component: float = color[index]
		linear[index] = component/12.92 if component <= 0.04045 else pow((component+0.055)/1.055,2.4)
	return linear.dot(Vector3(0.2126,0.7152,0.0722))

func _input_map() -> String:
	var result: Dictionary = {}
	for action: StringName in InputMap.get_actions():
		var events: Array[String] = []
		for event: InputEvent in InputMap.action_get_events(action): events.append(event.as_text())
		result[String(action)] = events
	return JSON.stringify(result)

func _key(code: Key, pressed: bool) -> void:
	if code == KEY_E:
		if pressed: Input.action_press(&"interact")
		else: Input.action_release(&"interact")
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event,true)
	await _step(2)

func _joy(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	# Update the physical held-button latch as well as routing a genuine event.
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step(2)

func _capture(case_name: String) -> void:
	if not capture: return
	await _step(3)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://docs/verification/region_entry/"+case_name+".png") == OK,"Captured actual GPU viewport: "+case_name)

func _step(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame

func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		print("FAIL: "+message)

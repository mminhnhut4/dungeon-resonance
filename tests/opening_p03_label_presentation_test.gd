extends SceneTree
## Focused cosmetic contract. Product travel/relocations are fixture setup,
## not walking proof. E is delivered through actual viewport input.
var flow: GameFlow
var hub: ExteriorHub
var checks: int = 0
var failures: int = 0
var observations: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/").to_lower()
	if not _check(qa.is_absolute_path() and OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"),"Isolated QA profile required"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/p03_labels_%d.json" % Time.get_ticks_usec()
	root.add_child(flow)
	current_scene = flow
	await _frames(12)
	hub = flow.active_scene as ExteriorHub
	if _check(hub != null and hub.enter_exterior(&"o01_p03"),"Existing product owner constructs P03 fixture"):
		await _frames(5)
		await _exercise()
	flow.queue_free()
	current_scene = null
	await _frames(6)
	root.get_node("AudioManager").stop_all()
	_check(get_nodes_in_group(&"npc_pilot_actor").is_empty() and is_equal_approx(Engine.time_scale,1.0),"Fixture teardown releases actors and modal time claims")
	var file := FileAccess.open("user://opening_p03_label_presentation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"stations":observations,"proof":"Product fixture placements only; real nearest target, bottom prompt and E input; no traversal claim"},"\t"))
	file.close()
	print("RESULT OpeningP03Labels checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

func _exercise() -> void:
	var room: ExteriorRoom = hub.exterior
	var hidden_e: int = 0
	var directions: int = 0
	for child: Node in room.find_children("*","Label",true,false):
		var label: Label = child as Label
		if label.text.begins_with("E ·"):
			hidden_e += 1
			_check(not label.visible,"P03 world E label is hidden: "+label.text)
		elif label.text in ["← Lối về","Đi tiếp →"]:
			directions += 1
			_check(label.visible,"Directional door label remains visible: "+label.text)
	_check(hidden_e == 6 and directions == 2,"Only the six P03 station/refuge E captions are suppressed; both direction signs remain")
	var actor_id: int = hub.player.get_instance_id()
	var inventory: Dictionary = GearInventoryCodec.encode(hub.gear.inventory)
	var hp: float = hub.player.health.current_health
	var energy: float = hub.player.energy.current
	var record: Node2D = room.get_node("TanDangRecord") as Node2D
	_check(record.z_index == -1 and record.position == room.interactions[TanDangJourney.REFUGE],"P03 record retains its canonical position and draws behind actors")
	for id: String in [TanDangProgress.LAM,TanDangProgress.DU]:
		var resident: CultivatorActor = hub.npc_population.actors.get(id) as CultivatorActor
		_check(resident != null and resident.caption.visible and not resident.caption.text.is_empty(),"Resident name/activity caption remains visible: "+id)
		_check(resident != null and resident.z_index == 0 and record.z_index < resident.z_index,"P03 board cannot cover the resident's hands/body: "+id)
	for key: StringName in [TanDangJourney.REFUGE,&"sect_register",&"shrine",&"sc01_lever"]:
		PlayerTravel.relocate(hub.player,room.to_global(room.interactions[key]))
		hub.door_latched = false
		await _frames(4)
		_check(hub.nearest_station() == key and hub.player.motor.is_grounded(),"Fixture selects actual nearest station: "+String(key))
		_check(hub.prompt.is_visible_in_tree() and hub.prompt.text.begins_with("E ·"),"Selected station retains its visible bottom E prompt: "+String(key))
		if key == TanDangJourney.REFUGE:
			_check(hub.prompt.text.contains("Trú ẩn"),"Refuge bottom prompt still identifies the hidden world caption's target")
		elif key == &"sc01_lever":
			_check(hub.prompt.text.contains("Mở cổng"),"Lever bottom prompt still identifies its own action")
		elif key == &"shrine":
			_check(hub.prompt.text.contains("Ghi mốc"),"Shrine bottom prompt still identifies its own action")
		observations.append({"station":key,"nearest":hub.nearest_station(),"prompt":hub.prompt.text,"position":hub.player.global_position})
		await _key(KEY_E)
		if key == &"sc01_lever":
			_check(hub.profile.exterior_progress["sc01_open"],"Physical E still opens SC01 through its durable owner")
		else:
			_check(hub.dialogue.is_open and not hub.player.controls_enabled,"Physical E still opens the selected station modal: "+String(key))
			if key == TanDangJourney.REFUGE:
				_check(hub.tan_dang.context == key,"Refuge modal retains the canonical station context")
			elif key == &"sect_register":
				_check(hub.sect_journey.context == key,"Sect register modal retains the canonical station context")
			await _key(KEY_ESCAPE)
			_check(not hub.dialogue.is_open and hub.player.controls_enabled and is_equal_approx(Engine.time_scale,1.0),"Escape restores normal E routing and time claims")
	_check(not hub.tan_dang.progress.state()["accepted"] and hub.player.get_instance_id() == actor_id and GearInventoryCodec.encode(hub.gear.inventory) == inventory and hub.player.health.current_health == hp and hub.player.energy.current == energy,"Reading station labels/modals grants no story progress and preserves Player/gear/HP/energy")
	# An unrelated main room and the valid P02 tunnel retain visible E signs.
	for key: StringName in [&"o01_p01",&"o01_p02"]:
		var other := ExteriorRoom.new()
		var route: StringName = ExteriorRouteCatalog.MAIN if key == &"o01_p01" else ExteriorRouteCatalog.TUNNEL
		_check(other.configure(key,route,false),"Non-target route fixture constructs")
		other._sign(Vector2(500,640),"E · Fixture station")
		var label: Label = other.get_child(other.get_child_count()-1) as Label
		_check(label.visible,"E visibility remains unchanged outside P03 main: "+String(key)+"/"+String(route))
		other.free()
	# Pure visual fixtures cover the explicit exception without adding props to
	# the real product room or changing any authored interaction/collider.
	for key: StringName in [&"o01_p01",&"o01_p03"]:
		var parent := ExteriorRoom.new()
		parent.room_id = key
		parent.route_id = ExteriorRouteCatalog.MAIN
		for lantern: bool in [false,true]:
			var at := Vector2(1320,640)
			var marker: Node2D = TanDangJourney._marker(parent,at,"E · Fixture marker",lantern)
			var expected_z: int = -1 if key == &"o01_p03" and not lantern else 0
			_check(marker.z_index == expected_z and marker.position == at,"Draw-order exception leaves non-P03 records and every lantern unchanged: %s lantern=%s" % [key,lantern])
		parent.free()

func _key(code: Key) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await _frames(1)
	await _frames(2)

func _frames(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame

func _check(passed: bool, message: String) -> bool:
	checks += 1
	if not passed:
		failures += 1
		print("FAIL: "+message)
	return passed

extends SceneTree
## Fresh product story smoke: actual walk input, ordinary doors and focused UI.
## No fixture warps, direct travel calls, quest grants, combat bypass or AI edits.
var flow: GameFlow
var hub: ExteriorHub
var checks: int = 0
var failures: int = 0
var segments: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var walked_ticks: int = 0
var walked_distance: float = 0.0
var path: String
var blocked_at: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").to_lower().trim_suffix("/")
	if not _check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"),"Isolated walkthrough QA storage"):
		quit(2)
		return
	path = "user://verification/tan_dang_walkthrough_%d_%d.json" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	if not _check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".npc_v1.json"),"Fresh product profile and NPC sidecar"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path
	root.add_child(flow)
	current_scene = flow
	await _frames(12)
	hub = flow.active_scene as ExteriorHub
	var completed: bool = await _walkthrough()
	_release_motion()
	var final_state: Dictionary = hub.tan_dang.progress.state() if is_instance_valid(hub) and hub.tan_dang != null else {}
	flow.queue_free()
	current_scene = null
	await _frames(6)
	root.get_node("AudioManager").stop_all()
	_check(is_equal_approx(Engine.time_scale,1.0),"Teardown releases modal time claims")
	var file := FileAccess.open("user://tan_dang_walkthrough_%d.json" % Engine.physics_ticks_per_second,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"completed":completed,"blocked_at":blocked_at,"physics_hz":Engine.physics_ticks_per_second,"walked_ticks":walked_ticks,"walked_seconds":float(walked_ticks)/Engine.physics_ticks_per_second,"walked_distance":walked_distance,"segments":segments,"checkpoints":checkpoints,"final_quest":final_state,"proof":"fresh product; continuous Input movement; ordinary E doors; focused buttons + Enter; no fixture warps or direct grants"},"\t"))
	file.close()
	print("RESULT tan_dang_walkthrough checks=%d failures=%d hz=%d walked_ticks=%d distance=%.2f completed=%s" % [checks,failures,Engine.physics_ticks_per_second,walked_ticks,walked_distance,completed])
	quit(0 if completed and failures == 0 else 1)

func _walkthrough() -> bool:
	if not _check(hub != null and not hub.outside and hub.player.position.distance_to(Vector2(430,640))<2.0 and hub.player.motor.is_grounded(),"Unmodified product opening spawn at430,640"):
		return false
	var player_id: int = hub.player.get_instance_id()
	var gear: Dictionary = GearInventoryCodec.encode(hub.gear.inventory)
	var hp: float = hub.player.health.current_health
	var energy: float = hub.player.energy.current
	var coins: int = flow.profile.coins
	var souls: int = flow.profile.souls
	if not _check(not flow.qa_tools_enabled and not hub.tan_dang.progress.state()["accepted"],"Default product settings and unaccepted story"):
		return false
	if not await _interact(TanDangJourney.LEDGER): return false
	if not await _choose(&"td_accept"): return false
	if not _check(hub.tan_dang.progress.state()["accepted"],"Ledger UI accepts the quest"): return false
	if not await _close_dialogue(): return false
	if not await _interact(TanDangJourney.LAMP): return false
	if not await _choose(&"td_observe_lamp"): return false
	if not _check("lamp" in hub.tan_dang.progress.state()["discoveries"],"Lamp UI records missing core"): return false
	if not await _close_dialogue(): return false
	if not await _door(&"exterior_road",&"o01_p01"): return false
	if not await _door(&"door_east",&"o01_p02"): return false
	if not await _door(&"door_east",&"o01_p03"): return false
	if not await _interact(TanDangJourney.REFUGE): return false
	for choice: StringName in [&"td_find_lam",&"td_inspect_core",&"td_q1_reward"]:
		if not await _choose(choice): return false
	if not _check(hub.tan_dang.progress.state()["contribution"] == 2,"Walking to actual refuge completes all three evidence facts"): return false
	if not await _choose(&"td_choice_rescue"): return false
	if not _check(hub.dialogue.pending_choice == &"td_choice_rescue" and hub.tan_dang.progress.state()["choice"] == "","Rescue requires the real confirmation UI"): return false
	hub.dialogue.confirm_button.grab_focus()
	await _key(KEY_ENTER)
	if not _check(hub.tan_dang.progress.state()["choice"] == "rescue" and hub.tan_dang.progress.alive(TanDangProgress.DU),"Enter on confirmation commits rescue through product owners"): return false
	if not await _close_dialogue(): return false
	if not await _door(&"door_west",&"o01_p02"): return false
	if not await _door(&"door_west",&"o01_p01"): return false
	if not await _door(&"door_west",ExteriorRouteCatalog.HUB): return false
	if not _check(hub.tan_dang.progress.state()["lamp"] == "broken" and hub.npc_population.actors.has(TanDangProgress.LAM) and hub.npc_population.actors.has(TanDangProgress.DU),"Ordinary west doors return to canonical living refuge residents at Hub"): return false
	if not await _interact(StringName(TanDangProgress.MOC)): return false
	if not await _choose(&"td_report_moc"): return false
	if not await _close_dialogue(): return false
	if not await _interact(StringName(TanDangProgress.LAM)): return false
	for choice: StringName in [&"td_report_lam",&"td_q3_reward"]:
		if not await _choose(choice): return false
	if not _check(hub.tan_dang.progress.state()["contribution"] == 6 and hub.tan_dang.progress.state()["membership"] == "guest","Guest naturally reports both people and earns all three quest rewards"): return false
	if not await _choose(&"td_recipe"): return false
	if not _check(hub.dialogue.pending_choice == &"td_recipe","Book purchase shows real confirmation"): return false
	hub.dialogue.confirm_button.grab_focus()
	await _key(KEY_ENTER)
	if not _check(hub.tan_dang.progress.known_recipe() and hub.tan_dang.progress.state()["contribution"] == 0,"Confirmed book grants existing firestorm at six contribution"): return false
	if not await _choose(&"td_support"): return false
	if not _check(hub.tan_dang.progress.state()["support_claimed"],"Actual support choice exposes current cultivation guidance"): return false
	if not await _choose(&"td_decline"): return false
	if not await _close_dialogue(): return false
	if not _check(hub.tan_dang.progress.state()["membership"] == "guest" and hub.tan_dang.progress.state()["declined"],"Player remains an independent guest after full rewards"): return false
	return _check(hub.player.get_instance_id() == player_id and GearInventoryCodec.encode(hub.gear.inventory) == gear and hub.player.health.current_health == hp and hub.player.energy.current == energy and flow.profile.coins == coins and flow.profile.souls == souls,"Continuous story travel preserves actual Player, carried gear/UIDs, HP/energy, coins and Souls")

func _room_key() -> StringName:
	return hub.exterior.room_id if hub.outside and is_instance_valid(hub.exterior) else ExteriorRouteCatalog.HUB

func _station_x(key: StringName) -> float:
	if not hub.outside and hub.stations.has(key): return hub.stations[key].global_position.x
	if hub.npc_population.actors.has(String(key)): return hub.npc_population.actors[String(key)].global_position.x
	if hub.outside and hub.exterior.interactions.has(key): return hub.exterior.to_global(hub.exterior.interactions[key]).x
	return NAN

func _walk_to(key: StringName) -> bool:
	var target_x: float = _station_x(key)
	if not _check(is_finite(target_x),"Authored walk destination exists: "+String(key)): return false
	var room_key: StringName = _room_key()
	var start: Vector2 = hub.player.global_position
	var previous: Vector2 = start
	var stationary: int = 0
	var max_step: float = 0.0
	var budget: int = ceili((absf(target_x-start.x)/200.0+5.0)*Engine.physics_ticks_per_second)
	for tick: int in budget:
		var dx: float = target_x-hub.player.global_position.x
		var speed: float = absf(hub.player.velocity.x)
		var stopping_distance: float = speed*speed/(2.0*hub.player.motor.ground_deceleration)+3.0
		_release_motion()
		if absf(dx)>maxf(4.0,stopping_distance): Input.action_press(&"move_right" if dx>0.0 else &"move_left")
		await _frames(1)
		walked_ticks += 1
		var displacement: float = hub.player.global_position.distance_to(previous)
		walked_distance += displacement
		max_step = maxf(max_step,displacement)
		stationary = stationary+1 if displacement<0.05 and absf(dx)>16.0 else 0
		if _room_key()!=room_key or displacement>40.0 or hub.player.health.current_health<=0.0:
			blocked_at = "%s:%s unexpected room/fall relocation/death" % [room_key,key]
			_check(false,blocked_at)
			break
		previous = hub.player.global_position
		if absf(target_x-previous.x)<=5.0 and absf(hub.player.velocity.x)<1.0 and hub.player.motor.is_grounded(): break
		if stationary>Engine.physics_ticks_per_second:
			blocked_at = "%s:%s physical obstruction at%s" % [room_key,key,hub.player.global_position]
			_check(false,blocked_at)
			break
	_release_motion()
	await _frames(4)
	var reached: bool = absf(hub.player.global_position.x-target_x)<=8.0 and hub.player.motor.is_grounded() and _room_key()==room_key
	segments.append({"room":room_key,"station":key,"start":start,"end":hub.player.global_position,"target_x":target_x,"max_continuous_frame_step":max_step,"reached":reached})
	if not reached and blocked_at.is_empty(): blocked_at = "%s:%s walk budget exhausted" % [room_key,key]
	return _check(reached,"Continuous walk reaches "+String(room_key)+":"+String(key))

func _interact(key: StringName) -> bool:
	if not await _walk_to(key): return false
	if not _check(hub.nearest_station()==key,"Actual nearest E target is "+String(key)): return false
	await _key(KEY_E)
	checkpoints.append({"room":_room_key(),"interaction":key,"position":hub.player.global_position,"quest":hub.tan_dang.progress.state()})
	return _check(hub.dialogue.is_open and not hub.player.controls_enabled,"Physical E opens "+String(key))

func _door(key: StringName, destination: StringName) -> bool:
	if not await _walk_to(key): return false
	if not _check(hub.nearest_station()==key,"Actual nearest door is "+String(key)): return false
	var count_before: int = hub.transition_count
	await _key(KEY_E)
	await _frames(6)
	checkpoints.append({"door":key,"destination":_room_key(),"position":hub.player.global_position})
	return _check(_room_key()==destination and hub.transition_count==count_before+1,"Physical E uses one ordinary door to "+String(destination))

func _choose(id: StringName) -> bool:
	if not _check(hub.dialogue.is_open,"Choice has an actual open modal: "+String(id)): return false
	for page_step: int in 60:
		if not hub.dialogue.is_typing() and hub.dialogue.page_index==hub.dialogue.pages.size()-1: break
		await _key(KEY_E)
	var button: Button = hub.dialogue.choice_list.get_node_or_null("Choice_"+String(id)) as Button
	if not _check(button != null and button.is_visible_in_tree() and not button.disabled,"Actual enabled story button: "+String(id)): return false
	button.grab_focus()
	await _key(KEY_ENTER)
	return true

func _close_dialogue() -> bool:
	await _key(KEY_ESCAPE)
	return _check(not hub.dialogue.is_open and hub.player.controls_enabled,"Escape closes modal and restores normal controls")

func _key(code: Key) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await _frames(1)
	await _frames(2)

func _release_motion() -> void:
	for action: StringName in [&"move_left",&"move_right",&"jump",&"dash"]: Input.action_release(action)

func _frames(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame

func _check(passed: bool, message: String) -> bool:
	checks += 1
	if not passed:
		failures += 1
		if blocked_at.is_empty(): blocked_at = message
		print("FAIL: "+message)
	return passed

extends SceneTree
## Actual authored traversal, existing controls, one session, additive save.
class FailedCommitProfile extends SanctuaryProfile:
	var reject_commit: bool = false
	func _replace_file(temporary: String, target: String) -> bool:
		if reject_commit: return false
		return super._replace_file(temporary,target)
	func _rename_file(source: String, target: String) -> Error:
		# The common v2 journal publishes through the actual rename primitive.
		if reject_commit and source == save_path + ".tmp" and target == save_path: return ERR_CANT_CREATE
		return super._rename_file(source, target)

var checks: int = 0
var failures: int = 0
var flow: GameFlow
var world: ExteriorHub
var actor: Player
var inventory: GearInventory
var owned: Array
var gpu: bool = false
var first_walk_seconds: float = 0
var shortcut_walk_seconds: float = 0
var main_sc01_segment_seconds: float = 0
var walked_ticks: int = 0
var input_snapshot: Dictionary = {}
var last_recipe_clock: float = 10000.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	gpu = DisplayServer.get_name() != "headless"
	if gpu:
		root.size = Vector2i(1152,648)
		root.content_scale_size = Vector2i(1280,720)
		AudioServer.set_bus_mute(0,true)
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/exterior_route_%d_%d.json" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	root.add_child(flow)
	current_scene = flow
	await _step(12)
	world = flow.active_scene as ExteriorHub
	actor = world.player
	inventory = world.gear.inventory
	owned = inventory.items.keys()
	world.feedback.hit_stop_seconds = 0
	flow.profile.coins = 700
	inventory.run_coins = 13
	inventory.changed.emit()
	actor.health.current_health = 37
	actor.energy.current = 41
	actor.energy.regeneration_delay = 10000
	_check(not world.outside and ExteriorRouteCatalog.ROOMS.size() == 8, "Main integrates H00 plus eight authored outside room IDs")
	_check(actor.motor.run_speed == 320 and actor.floor_snap_length == 1 and actor.health.minimum_health == 1 and actor.collision_layer == 2 and actor.collision_mask == 1, "Quiet prototype retains motor, safe preparation and World-only actor collision mask")
	PlayerTravel.relocate(actor,world.stations[&"exterior_road"].global_position)
	await _step(5)
	actor.motor.dash_cooldown_remaining = 0.9
	actor.motor.air_dash_available = false
	(actor.motor as BuildPlayerMotor).air_dashes_used = 1
	actor.resonance_controller.loadout_state.cooldowns_by_recipe_id[&"basic_bolt"] = 10000
	actor.damage_grace_remaining = 0.32
	await _press_e(true)
	_check(input_snapshot["dash"] == 0.9 and not input_snapshot["air_available"] and input_snapshot["used_air_dashes"] == 1 and input_snapshot["recipe"] == 10000 and input_snapshot["grace"] == 0.32, "Actual road relocation immediately preserves committed motor/recipe/grace clocks before natural grounded ticks")
	_check(world.outside and world.exterior.room_id == &"o01_p01", "Actual H00 road E enters P01 without a dungeon expedition")
	_check(flow.active_scene == world and not flow.active_scene is DungeonRun, "Ordinary exterior travel retains its current GameFlow session")
	var held_room: StringName = world.exterior.room_id
	await _press_e(true)
	_check(world.exterior.room_id == held_room, "Held E cannot bounce through a newly loaded door")
	await _press_e(false)
	# Closed physical tunnel, before the far-side lever has been reached.
	await _walk_to(320)
	await _key_e()
	_check(world.exterior.route_id == ExteriorRouteCatalog.TUNNEL and not world.exterior.gate_open, "Tunnel doorway loads actual P02 corridor, not a P03 teleport")
	await _walk_to(1100)
	_check(actor.global_position.x-ExteriorHub.ORIGIN.x < 640, "Closed SC01 collider physically blocks the corridor")
	await _capture("exterior_sc01_closed")
	await _walk_to(90)
	await _key_e()
	_check(world.exterior.room_id == &"o01_p01" and world.exterior.route_id == ExteriorRouteCatalog.MAIN, "Closed corridor still has a dry walking return to P01")
	var main_begin: int = walked_ticks
	for index: int in ExteriorRouteCatalog.ROOMS.size():
		_check(world.exterior.room_id == ExteriorRouteCatalog.ROOMS[index], "Actual ordered room arrival %s" % ExteriorRouteCatalog.ROOMS[index])
		_validate_geometry()
		if index == 2:
			await _walk_to(320)
			main_sc01_segment_seconds = float(walked_ticks-main_begin)/Engine.physics_ticks_per_second
		if gpu:
			if index == 3:
				var terrace_number: int = 0
				for point_index: int in [4,8,10]:
					terrace_number += 1
					await _walk_to(world.exterior.surface[point_index].x+120)
					await _capture("exterior_p04_terrace_%d" % terrace_number)
			else:
				var viewpoints: Array[float] = [1400,2630,1550,0,1030,930,1510,760]
				await _walk_to(viewpoints[index])
				await _capture("exterior_%s_landmark" % world.exterior.room_id)
		await _walk_to(world.exterior.width-90)
		_check(actor.motor.is_grounded() and absf(actor.global_position.y-world.exterior.surface[-1].y) < 2, "Full W walks east without jump/dash: %s" % world.exterior.room_id)
		_check_identity()
		await _capture("exterior_%s_east" % world.exterior.room_id)
		if index < ExteriorRouteCatalog.ROOMS.size()-1:
			await _key_e()
	first_walk_seconds = float(walked_ticks-main_begin)/Engine.physics_ticks_per_second
	_check(flow.profile.exterior_progress["discovered_rooms"].size() == 8, "Discoveries are stable IDs, once per logical room")
	# Hanh is a neutral prototype anchor; dialogue is not a relationship/AI grant.
	await _walk_to(730)
	await _key_e()
	_check(world.dialogue.is_open and not flow.profile.exterior_progress["notes"].has("hanh_encounter"), "Meeting opens real dialogue without prematurely committing a record")
	await _capture("exterior_hanh_dialogue")
	world.dialogue.close()
	await _step(2)
	_check(not flow.profile.exterior_progress["notes"].has("hanh_encounter") and world.pending_note == &"", "Cancel leaves Hanh encounter record uncommitted")
	await _key_e()
	_finish_dialogue()
	world.dialogue.select_choice(&"exterior_note_hanh_encounter")
	await _step(2)
	_check(flow.profile.exterior_progress["notes"].has("hanh_encounter") and actor.controls_enabled, "Confirmed record saves once and releases modal ownership")
	_check(TimeScaleClaims.owner_count(self) == 0, "Dialogue confirmation/cancel leaves no time claim")
	# Walk the complete route back, including all three refined P04 descents.
	for index: int in range(7,-1,-1):
		_check(world.exterior.room_id == ExteriorRouteCatalog.ROOMS[index], "Return route room %s" % ExteriorRouteCatalog.ROOMS[index])
		if index == 2:
			await _walk_to(1450)
			await _key_e()
			_check(flow.profile.exterior_progress["sc01_open"], "Far-side P03 lever commits persistent SC01 without reward/banking")
			var saved: String = FileAccess.get_file_as_string(flow.profile.save_path)
			_check(world.open_sc01() and FileAccess.get_file_as_string(flow.profile.save_path) == saved, "SC01 lever is idempotent")
		await _walk_to(90)
		_check(actor.motor.is_grounded() and absf(actor.global_position.y-world.exterior.surface[0].y) < 2, "Full W walks west without jump/dash: %s" % world.exterior.room_id)
		_check_identity()
		await _key_e()
	_check(not world.outside and flow.active_scene == world, "Actual O02->O01->H00 full walking roundtrip returns to one original Hub")
	_check(actor.health.current_health == 37 and actor.energy.current == 41 and flow.profile.coins == 700 and inventory.run_coins == 13, "Complete route has no heal, energy refill, escrow bank or starter award")
	# Optional J1/J2: repeated whole-foot landings with actual jump input.
	for room: StringName in [&"o01_p01",&"o01_p02",&"o01_p04",&"o02_b02"]:
		_check(world.enter_exterior(room), "Prepare optional branch fixture %s" % room)
		await _step(5)
		for jump: Dictionary in world.exterior.jumps:
			for repeat: int in (1 if gpu else 3):
				PlayerTravel.relocate(actor,ExteriorHub.ORIGIN+jump["takeoff"])
				await _step(5)
				var view: Rect2 = root.get_visible_rect()
				var transform: Transform2D = root.get_canvas_transform()*world.exterior.global_transform
				var landing: Vector2 = jump["landing"]
				_check(view.has_point(transform*(landing+Vector2(-18,-36))) and view.has_point(transform*(landing+Vector2(70,0))), "Whole-foot landing and headroom are visible at actual takeoff camera: %s" % room)
				await _jump_to(jump["landing"])
				var local: Vector2 = actor.global_position-ExteriorHub.ORIGIN
				_check(actor.motor.is_grounded() and absf(local.y-jump["landing"].y) < 2 and absf(local.x-jump["landing"].x) <= 44, "Actual optional whole-foot jump %s repeat %d" % [room,repeat])
		await _capture("exterior_%s_high_branch" % room)
	# The opened shortcut requires actual walking through a shorter corridor.
	world.enter_exterior(&"o01_p03",ExteriorRouteCatalog.MAIN,&"tunnel")
	await _step(5)
	world.door_latched = false
	await _key_e()
	_check(world.exterior.route_id == ExteriorRouteCatalog.TUNNEL and world.exterior.gate_open and world.exterior.gate.collision_layer == 0, "Opened SC01 loads far end of a physical walkable corridor")
	var shortcut_begin: int = walked_ticks
	await _walk_to(90)
	shortcut_walk_seconds = float(walked_ticks-shortcut_begin)/Engine.physics_ticks_per_second
	await _capture("exterior_sc01_open")
	await _key_e()
	_check(world.exterior.room_id == &"o01_p01" and shortcut_walk_seconds < main_sc01_segment_seconds, "SC01 traverses corridor and shortens measured P03-P01 main segment")
	await _walk_to(320)
	await _key_e()
	await _walk_to(world.exterior.width-90)
	await _key_e()
	_check(world.exterior.room_id == &"o01_p03", "Physical shortcut also walks east to P03")
	await _walk_to(1660)
	await _key_e()
	_check(flow.profile.exterior_progress["anchor_id"] == "shrine", "Shrine commits geographic return anchor without rest/bank")
	_check(world.dialogue.is_open and not actor.controls_enabled, "Actual shrine courier register owns dialogue after geographic checkpoint")
	world.dialogue.close()
	await _step(2)
	_check(actor.controls_enabled and TimeScaleClaims.owner_count(self) == 0, "Closing shrine courier register releases controls before anchor reload")
	var location: Vector2 = actor.global_position
	var geography: Dictionary = flow.profile.exterior_progress.duplicate(true)
	world.reject_next_load = true
	_check(not world.enter_exterior(&"o02_b01") and actor.global_position == location and flow.profile.exterior_progress == geography, "Preflight load failure preserves current room/actor/geography")
	_check(not world.enter_exterior(&"unknown_room") and not world.enter_exterior(&"o01_p01",ExteriorRouteCatalog.TUNNEL), "Unknown typed room/route rejects before commit")
	world.gear.modal.open()
	_check(not world.enter_exterior(&"o02_b01") and world.gear.modal.is_open, "Inventory owns its modal until explicitly closed")
	world.gear.modal.close()
	_check(flow.profile.save(), "Save all current permanent geography and safe ledger")
	_check(flow.profile.load_profile() and world.restore_exterior_anchor(), "Same-session load restores validated geographic anchor")
	await _step(4)
	_check(actor.global_position.distance_to(ExteriorHub.ORIGIN+world.exterior.anchors[&"shrine"]) < 2 and world.player == actor and world.gear.inventory == inventory, "Anchor load retains actor/ledger at dry floor")
	_check(flow.profile.exterior_progress["sc01_open"] and flow.profile.exterior_progress["notes"].has("hanh_encounter"), "Profile load preserves SC01 and confirmed record by stable IDs")
	_check(actor.health.current_health == 37 and actor.energy.current == 41 and inventory.items.keys() == owned and inventory.run_coins == 13, "Anchor load cannot create HP/energy/UID/escrow credit")
	await _save_cases()
	_check_identity()
	_release()
	flow.queue_free()
	await _step(8)
	_check(TimeScaleClaims.owner_count(self) == 0 and is_equal_approx(Engine.time_scale,1), "Complete authored fixture teardown releases time claims")
	print("EXTERIOR_ROUTE_TIMING "+JSON.stringify({"physics_hz":Engine.physics_ticks_per_second,"full_outward_w_seconds":first_walk_seconds,"main_sc01_segment_seconds":main_sc01_segment_seconds,"sc01_corridor_seconds":shortcut_walk_seconds,"subjective_playtest":"NOT_RUN","literal_stacked_hairpins":"SUPERSEDED by user option1; not PASS","npc_ai_permadeath_sect":"NOT_RUN; not enabled"}))
	print("RESULT ExteriorRoute %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _validate_geometry() -> void:
	var room: ExteriorRoom = world.exterior
	var safe: bool = true
	for index: int in room.surface.size()-1:
		var delta: Vector2 = room.surface[index+1]-room.surface[index]
		safe = safe and absf(rad_to_deg(atan2(delta.y,delta.x))) <= 10.0
	_check(safe and room.dry_anchor(&"west") and room.dry_anchor(&"east"), "Actual collider profile uses measured <=10-degree slopes and dry wide entries")
	for jump: Dictionary in room.jumps:
		_check(float(jump["delta_z"]) <= 0.65*115 and float(jump["edge_gap"]) <= 0.75*158.24, "Optional gap/rise fits conservative measured E(+0.45H) bound")

func _save_cases() -> void:
	var rejected := FailedCommitProfile.new()
	rejected.save_path = flow.profile.save_path
	_check(rejected.load_profile(), "Prepare real profile commit failure injection")
	var previous_profile: SanctuaryProfile = world.profile
	world.profile = rejected
	rejected.reject_commit = true
	var prior: Dictionary = rejected.exterior_progress.duplicate(true)
	var position: Vector2 = actor.global_position
	_check(not world.enter_exterior(&"o02_b01") and rejected.exterior_progress == prior and actor.global_position == position, "Actual atomic file replacement failure rolls back exterior state before travel")
	world.profile = previous_profile
	var legacy := SanctuaryProfile.new()
	legacy.save_path = "user://verification/exterior_legacy_%d.json" % Time.get_ticks_usec()
	_write(legacy.save_path,JSON.stringify({"version":1,"souls":0,"weapons":[],"discovered":[],"archive":[]}))
	_check(legacy.load_profile() and not legacy.exterior_progress["sc01_open"] and legacy.exterior_progress["discovered_rooms"].is_empty(), "Old v1 without extension defaults to no unearned shortcut/discovery")
	_check(legacy.save() and not JSON.parse_string(FileAccess.get_file_as_string(legacy.save_path)).has("exterior_progress"), "Unused v1 geography remains absent; global schema not bumped")
	var encoded: Dictionary = GearInventoryCodec.encode(inventory)
	var malformed: Dictionary = {"version":1,"hub_inventory":encoded,"exterior_progress":{"version":1,"room_id":"fake"}}
	_write(legacy.save_path,JSON.stringify(malformed))
	_check(legacy.load_profile() and legacy.exterior_progress_quarantined and GearInventoryCodec.valid(legacy.hub_inventory), "Malformed geography quarantines independently without restoring an old UID ledger")
	_write(legacy.save_path,JSON.stringify({"version":1,"exterior_progress":{"version":2}}))
	var future: String = FileAccess.get_file_as_string(legacy.save_path)
	_check(not legacy.load_profile() and not legacy.save() and FileAccess.get_file_as_string(legacy.save_path) == future, "Future independently-versioned extension cannot be overwritten by older build")
	var saved_progress: Dictionary = flow.profile.exterior_progress.duplicate(true)
	_check(not ExteriorProgress.valid({"version":1,"room_id":"o01_p01","region_id":"o02_ben_tram","route_id":"main","anchor_id":"west","discovered_rooms":[],"notes":[],"sc01_open":false}), "Typed room/region relationships reject malformed data")
	_check(ExteriorProgress.valid(saved_progress), "Current geographic payload has validated IDs and bounded lists")

func _check_identity() -> void:
	var clock: float = float(actor.resonance_controller.loadout_state.cooldowns_by_recipe_id[&"basic_bolt"])
	_check(world.player == actor and world.gear.inventory == inventory and inventory.items.keys() == owned and actor.health.current_health == 37 and actor.energy.current == 41 and inventory.run_coins == 13 and flow.profile.coins == 700 and clock <= last_recipe_clock and clock > 0, "Walking/door preserves actor, UIDs, HP/energy, unbanked escrow and monotonic recipe clock")
	last_recipe_clock = clock

func _walk_to(x: float) -> void:
	var target: float = ExteriorHub.ORIGIN.x+x
	var direction: int = 1 if target > actor.global_position.x else -1
	var action: StringName = &"move_right" if direction > 0 else &"move_left"
	Input.action_press(action)
	var duration: int = int(world.exterior.width/320+5)*Engine.physics_ticks_per_second
	for tick: int in duration:
		await _step(1)
		walked_ticks += 1
		if direction*(actor.global_position.x-target) >= 0: break
	Input.action_release(action)
	await _step(int(0.2*Engine.physics_ticks_per_second))

func _jump_to(point: Vector2) -> void:
	Input.action_press(&"move_right")
	Input.action_press(&"jump")
	for tick: int in Engine.physics_ticks_per_second:
		await _step(1)
		if actor.global_position.x-ExteriorHub.ORIGIN.x >= point.x: break
	Input.action_release(&"move_right")
	await _step(Engine.physics_ticks_per_second)
	Input.action_release(&"jump")
	await _step(3)

func _finish_dialogue() -> void:
	while world.dialogue.page_index < world.dialogue.pages.size()-1:
		world.dialogue.advance()
		world.dialogue.advance()
	world.dialogue.advance()

func _press_e(pressed: bool) -> void:
	if pressed: Input.action_press(&"interact")
	else: Input.action_release(&"interact")
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event,true)
	input_snapshot = {"dash":actor.motor.dash_cooldown_remaining,"air_available":actor.motor.air_dash_available,"used_air_dashes":(actor.motor as BuildPlayerMotor).air_dashes_used,"recipe":actor.resonance_controller.loadout_state.cooldowns_by_recipe_id.get(&"basic_bolt",0),"grace":actor.damage_grace_remaining}
	await _step(2)

func _key_e() -> void:
	await _press_e(true)
	await _press_e(false)

func _capture(file_name: String) -> void:
	if not gpu: return
	await _step(3)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://docs/verification/"+file_name+".png") == OK,"Actual authored GPU screenshot: %s" % file_name)

func _write(path: String, contents: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(contents)
	file.close()

func _release() -> void:
	for id: StringName in [&"move_left",&"move_right",&"jump",&"dash",&"interact"]: Input.action_release(id)

func _step(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame

func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		print("FAIL: "+message)

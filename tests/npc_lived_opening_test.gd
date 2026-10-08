extends SceneTree
## Bounded schedules, old tombstones and continuous local presentation.
var checks: int = 0
var failures: int = 0
var prefix: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	var user_dir: String = ProjectSettings.globalize_path("user://").replace("\\","/")
	print("NPC_LIVED_USER_DIR=" + user_dir)
	# Parent sets a private custom user directory before invoking this suite.
	var allowed_root: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if not allowed_root.is_absolute_path() or not user_dir.begins_with(allowed_root + "/"):
		print("FAIL: Dedicated QA user directory required before any save write")
		quit(1)
		return
	prefix = "user://verification/npc_lived_%d_%d" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	_schedules()
	_migrate_and_resume()
	await _presentation_and_cleanup()
	print("RESULT npc_lived_opening checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

func _schedules() -> void:
	var state := NpcWorldState.new()
	var twin := NpcWorldState.new()
	var visited: Dictionary = {}
	var phase: Dictionary = {}
	for id: String in NpcPilotCatalog.IDS:
		visited[id] = {}
		phase[state.records[id]["mode"]] = true
	_check(phase.size() >= 3, "Initial residents have varied walking, working and resting phases")
	var bounds_ok: bool = true
	for _index: int in 1200:
		state.advance_ticks(1)
		twin.advance_ticks(1)
		for id: String in NpcPilotCatalog.IDS:
			var record: Dictionary = state.records[id]
			var stop: Dictionary = NpcPilotCatalog.stop(id,int(record["schedule_index"]))
			if record["mode"] in ["work","rest"] and is_equal_approx(record["x"],stop["x"]): visited[id][int(record["schedule_index"])] = true
			bounds_ok = bounds_ok and int(record["remaining"]) <= 12
	_check(state.snapshot() == twin.snapshot() and NpcWorldState.valid(state.snapshot()), "Five minutes of authored time remains deterministic and valid")
	_check(bounds_ok,"Ordinary stops last at most three seconds instead of uniform eight-second waits")
	for id: String in NpcPilotCatalog.IDS:
		_check(visited[id].size() == NpcPilotCatalog.SCHEDULES[id].size(), "%s reaches each purposeful stop" % id)
	var traveler_stops: Array = NpcPilotCatalog.SCHEDULES["pilot_traveler"]
	_check(traveler_stops[0]["x"] == 380.0 and traveler_stops[2]["x"] == 1380.0,"P01 traveler visits existing shrine roof and bench surroundings")
	for mode: String in ["walk","work","rest","flee"]:
		var id: String = "pilot_pilgrim"
		state.records[id]["mode"] = mode
		state.records[id]["remaining"] = 7 if mode in ["work","rest"] else 0
		var before: Dictionary = state.records[id].duplicate(true)
		_check(state.begin_talk(id), "Talk interrupts %s" % mode)
		var talking: Dictionary = state.records[id].duplicate(true)
		for _index: int in 20: state.advance_ticks(8)
		_check(state.records[id] == talking, "Talk freezes %s route and remaining stop" % mode)
		state.end_talk(id)
		_check(state.records[id] == before, "Close resumes exact %s route without reset" % mode)

func _migrate_and_resume() -> void:
	var state := NpcWorldState.new()
	state.save_path = prefix + "_migrate.json"
	var legacy: Dictionary = state.snapshot()
	legacy["npc_schema"] = 1
	legacy["tick"] = 90
	legacy["records"].erase("pilot_bridge_keeper")
	for new_id: String in NpcPilotCatalog.CULTIVATOR_IDS: legacy["records"].erase(new_id)
	for id: String in NpcPilotCatalog.LEGACY_IDS:
		var record: Dictionary = legacy["records"][id]
		record.erase("schedule_index")
		record.erase("interrupted")
		record.erase("legacy_death")
		if id == "pilot_traveler":
			record["x"] = 700.0
			record["target"] = 870.0
	var old: Dictionary = legacy["records"]["pilot_traveler"]
	old["mode"] = "dead"
	old["hp"] = 0.0
	old["episode"] = 2
	old["trust"] = -9
	old["fear"] = 30
	old["death"] = {"event_id":"pilot_traveler:2","killer_id":"player","tick":80,"room":"o01_p01","context":"explicit_execution"}
	_check(NpcWorldState.valid(legacy),"Actual schema-one shape with five old identities remains readable")
	DirAccess.make_dir_recursive_absolute(state.save_path.get_base_dir())
	var file := FileAccess.open(state.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var original_bytes: String = FileAccess.get_file_as_string(state.save_path)
	_check(state.load_state() and not state.read_only and state.records.size() == 8,"Validated v1 durably adds bridge and two cultivator identities exactly once")
	var migrated: Dictionary = state.records["pilot_traveler"].duplicate(true)
	_check(migrated["legacy_death"] == old["death"] and ["trust","fear","debt","greeted","x","target","episode","room"].all(func(field: String) -> bool: return migrated[field] == old[field]),"Migration preserves every old historical death, relation, coordinate and episode")
	_check(migrated["mode"] == "recovering" and migrated["hp"] == 1 and migrated["death"].is_empty(),"New policy withdraws the same old identity without erasing its history")
	_check(FileAccess.get_file_as_string(state.save_path + ".bak") == original_bytes and FileAccess.get_file_as_string(state.save_path + ".pre_nonlethal_v1.json") == original_bytes,"Migration retains both rotating and immutable original-byte backups")
	_check(state.save() and NpcWorldState.valid(state.snapshot()) and state.snapshot()["npc_schema"] == 3,"Subsequent save uses schema3 through the existing owner writer")
	_check(FileAccess.get_file_as_string(state.save_path + ".pre_nonlethal_v1.json") == original_bytes,"Ordinary backup rotation never replaces the immutable migration source")
	var loaded := NpcWorldState.new()
	loaded.save_path = state.save_path
	_check(loaded.load_state() and loaded.snapshot() == state.snapshot(),"New schedule cursors and archived tombstone survive cold reload")
	for _index: int in 100: loaded.advance_ticks(8)
	_check(loaded.records["pilot_traveler"]["legacy_death"] == old["death"] and loaded.records["pilot_traveler"]["hp"] == 1 and loaded.records["pilot_traveler"]["mode"] == "recovering","Migrated history remains exact while elapsed time cannot heal the resident")
	var id: String = "pilot_bridge_keeper"
	var before: Dictionary = state.records[id].duplicate(true)
	_check(state.begin_talk(id) and state.save(),"Save can capture a bridge resident interrupted mid-walk")
	loaded = NpcWorldState.new()
	loaded.save_path = state.save_path
	_check(loaded.load_state() and loaded.records[id] == before,"Cold reload releases talk and resumes its exact scheduled trip")
	state.end_talk(id)
	state.receive_hit(id,1.0,0.0)
	var token: String = state.decision_token(id)
	_check(not state.decide(id,token,true) and not state.decide(id,token,true,true) and state.records[id]["mode"] == "recovering","No legacy execution confirmation can finish the new injury")
	loaded = NpcWorldState.new()
	loaded.save_path = state.save_path
	_check(loaded.load_state() and loaded.records[id]["mode"] == "recovering" and loaded.records["pilot_traveler"]["mode"] == "recovering","New and legacy injuries both wait for an expedition return")
	var malformed: Dictionary = state.snapshot()
	malformed["records"]["pilot_pilgrim"]["schedule_index"] = 99
	_check(not NpcWorldState.valid(malformed),"Unknown schedule cursor cannot reach actors or replace a save")
	malformed = state.snapshot()
	malformed["records"].erase("pilot_bridge_keeper")
	_check(not NpcWorldState.valid(malformed),"Missing current record is quarantined instead of recreating a resident")

func _presentation_and_cleanup() -> void:
	var flow := preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = prefix + "_profile.json"
	root.add_child(flow)
	current_scene = flow
	await _step(8)
	var hub := flow.active_scene as ExteriorHub
	var population: NpcPopulation = hub.npc_population
	population.set_process(false)
	var player_id: int = hub.player.get_instance_id()
	var owned: Array = hub.gear.inventory.items.keys()
	var weak_actors: Array[WeakRef] = []
	var cues: Array[StringName] = []
	population.cue_requested.connect(func(_id: String,_cue: StringName,_at: Vector2,_owner: Node) -> void: cues.append(_cue))
	await _close_hit_flee(hub,population)
	# Retain all six civilian motion/no-retaliation contracts. Cultivators have
	# their own real combat suite, rather than inheriting a civilian-only claim.
	for id: String in NpcPilotCatalog.SCHEMA_TWO_IDS:
		var spec: Dictionary = NpcPilotCatalog.definition(id)
		_check(hub.enter_exterior(StringName(spec["room"]),&"main",&"west",false),"Ordinary travel enters resident room %s" % id)
		await _step(3)
		var actor: NpcPilotActor = population.actors[id]
		weak_actors.append(weakref(actor))
		population.state.records[id] = NpcPilotCatalog.initial_record(id)
		actor.sync_record(false)
		population.accumulator = 0.0
		var geometry: Array[Dictionary] = PilgrimagePresentation.static_collision_snapshot(hub.exterior)
		var safe: bool = true
		var moving_frames: int = 0
		var walk_frames: int = 0
		var max_dx: float = 0.0
		var max_floor_error: float = 0.0
		var dt: float = 1.0 / Engine.physics_ticks_per_second
		for _index: int in Engine.physics_ticks_per_second * 12:
			var previous: Vector2 = actor.position
			var mode_before: String = population.state.records[id]["mode"]
			var target_before: float = float(population.state.records[id]["target"])
			var approaching: bool = mode_before == "walk" and absf(previous.x-target_before) > 0.001
			population._process(dt)
			var dx: float = absf(actor.position.x-previous.x)
			max_dx = maxf(max_dx,dx)
			max_floor_error = maxf(max_floor_error,absf(actor.position.y-hub.exterior.floor_y(actor.position.x)))
			safe = safe and dx <= float(spec["speed"])*dt+0.001 and is_equal_approx(actor.position.y,hub.exterior.floor_y(actor.position.x))
			if approaching:
				walk_frames += 1
				if dx > 0.00001: moving_frames += 1
				safe = safe and (actor.position.x-previous.x)*(target_before-previous.x) >= -0.00001
		print("NPC_MOTION id=%s moving=%d walk_frames=%d max_dx=%.6f allowed=%.6f floor_error=%.6f" % [id,moving_frames,walk_frames,max_dx,float(spec["speed"])*dt,max_floor_error])
		_check(safe and moving_frames >= walk_frames-2,"%s moves on render frames without 4Hz jumps, overshoot or floating feet" % id)
		_check(geometry == PilgrimagePresentation.static_collision_snapshot(hub.exterior) and not _has_blocking_body(actor),"Resident animation leaves route geometry unchanged and never adds a blocking body")
		for stop: Dictionary in NpcPilotCatalog.SCHEDULES[id]:
			_check(is_finite(hub.exterior.floor_y(stop["x"])) and stop["x"] > 90 and stop["x"] < hub.exterior.width-90,"Authored %s stop has real dry floor away from exits" % id)
		if id == "pilot_bridge_keeper":
			_check(float(spec["left"]) > hub.exterior.surface[4].x and float(spec["right"]) < hub.exterior.surface[5].x,"Bridge resident stays on the existing bridge plateau")
		var player_hp: float = hub.player.health.current_health
		var hit := DamageEvent.new()
		hit.source_id = hub.player.get_instance_id()
		hit.target_id = actor.get_instance_id()
		hit.source_team_id = 1
		hit.attack_id = CombatIds.next_id()
		hit.hit_window_id = 1
		hit.root_event_id = hit.attack_id
		hit.base_damage = 5.0
		hit.attack_origin = actor.global_position + Vector2(-35,0)
		var result: DamageResult = actor.hurtbox.take_damage(hit)
		_check(result.actual_damage > 0 and population.state.records[id]["mode"] == "flee","Shared damage resolver makes %s flee after a nonlethal hit" % id)
		var flee_safe: bool = true
		for _index: int in Engine.physics_ticks_per_second*2:
			var previous_x: float = actor.position.x
			population._process(dt)
			flee_safe = flee_safe and actor.position.x >= previous_x-0.001 and actor.position.x-previous_x <= float(spec["speed"])*1.8*dt+0.001
		_check(flee_safe and hub.player.health.current_health == player_hp and population.state.records[id]["fear"] == 6,"%s withdraws continuously away from the hit without retaliation" % id)
		var tick_before: int = population.state.tick
		var at_before: Vector2 = actor.position
		var pose_before: float = actor._pose_clock
		var cue_before: int = cues.size()
		(hub.gear.modal as InventoryScreen).open()
		for _index: int in 30: population._process(dt)
		_check(population.state.tick == tick_before and actor.position == at_before and actor._pose_clock == pose_before and cues.size() == cue_before,"%s inventory pause freezes travel, pose clock and cues" % id)
		(hub.gear.modal as InventoryScreen).close()
		tick_before = population.state.tick
		at_before = actor.position
		pose_before = actor._pose_clock
		paused = true
		for _index: int in 30: population._process(dt)
		_check(population.state.tick == tick_before and actor.position == at_before and actor._pose_clock == pose_before,"Scene pause freezes %s without catch-up" % id)
		paused = false
	_check(hub.player.get_instance_id() == player_id and hub.gear.inventory.items.keys() == owned,"Schedules and room visits preserve the Player and inventory UID owner")
	for _cycle: int in 6:
		for room: StringName in [&"o01_p01",&"o01_p02",&"o01_p03"]:
			hub.enter_exterior(room,&"main",&"west",false)
			await _step(3)
			var expected: int = 2 if room in [&"o01_p01",&"o01_p02"] else 1
			_check(get_nodes_in_group(&"npc_pilot_actor").size() == expected and population.actors.size() == expected,"Repeat visit keeps the exact authored actor count for %s" % room)
		hub.enter_exterior(&"o01_p02",&"guard_corridor",&"west",false)
		await _step(3)
		_check(population.actors.is_empty() and get_nodes_in_group(&"npc_pilot_actor").is_empty(),"Corridor never gets a duplicate bridge resident")
		hub.return_to_hub(false)
		await _step(3)
	_check(weak_actors.all(func(ref: WeakRef) -> bool: return ref.get_ref() == null),"Travel releases all previously observed room actors")
	flow.queue_free()
	await _step(5)
	_check(get_nodes_in_group(&"npc_pilot_actor").is_empty(),"Full teardown releases all resident presentations")

func _step(count: int) -> void:
	for _index: int in count: await physics_frame

func _close_hit_flee(hub: ExteriorHub,population: NpcPopulation) -> void:
	_check(hub.enter_exterior(&"o01_p01",&"main",&"west",false),"Close-hit regression uses a real P01 actor and Hurtbox")
	await _step(3)
	var id: String = "pilot_traveler"
	var actor: NpcPilotActor = population.actors[id]
	var spec: Dictionary = NpcPilotCatalog.definition(id)
	var dt: float = 1.0/Engine.physics_ticks_per_second
	for travel_direction: int in [-1,1]:
		for attack_side: int in [-1,1]:
			population.state.records[id] = NpcPilotCatalog.initial_record(id)
			var record: Dictionary = population.state.records[id]
			record["schedule_index"] = 0 if travel_direction == -1 else 1
			record["target"] = NpcPilotCatalog.stop(id,int(record["schedule_index"]))["x"]
			population.accumulator = 0.0
			actor.sync_record(false)
			var tick_before: int = population.state.tick
			for _index: int in roundi(Engine.physics_ticks_per_second*0.2): population._process(dt)
			var record_x: float = float(record["x"])
			var actor_x: float = actor.position.x
			var cursor_before: int = int(record["schedule_index"])
			_check(record["mode"] == "walk" and population.state.tick == tick_before and absf(actor_x-record_x) > 8.0 and is_equal_approx(actor.hurtbox.global_position.x,actor.global_position.x),"Walking %d has a real interpolated actor/Hurtbox between decision ticks" % travel_direction)
			var hit := DamageEvent.new()
			hit.source_id = hub.player.get_instance_id()
			hit.target_id = actor.get_instance_id()
			hit.source_team_id = 1
			hit.attack_id = CombatIds.next_id()
			hit.hit_window_id = 1
			hit.root_event_id = hit.attack_id
			hit.base_damage = 5.0
			hit.attack_origin = actor.global_position+Vector2(attack_side*3.0,0)
			var result: DamageResult = actor.hurtbox.take_damage(hit)
			var expected_edge: float = float(spec["right"] if attack_side == -1 else spec["left"])
			print("NPC_CLOSE_HIT hz=%d walk=%d hit_side=%d record_x=%.3f actor_x=%.3f origin_x=%.3f flee_target=%.3f expected=%.3f" % [Engine.physics_ticks_per_second,travel_direction,attack_side,record_x,actor_x,hit.attack_origin.x-actor.room.global_position.x,record["target"],expected_edge])
			_check(result.actual_damage > 0 and record["mode"] == "flee" and float(record["target"]) == expected_edge,"Close hit from side %d while walking %d chooses retreat away from actual contact" % [attack_side,travel_direction])
			_check(population.state.tick == tick_before and float(record["x"]) == record_x and int(record["schedule_index"]) == cursor_before,"Contact samples actor position without moving the authoritative schedule or clock")
			var away: bool = true
			for _index: int in roundi(Engine.physics_ticks_per_second*0.5):
				var previous_x: float = actor.position.x
				population._process(dt)
				var dx: float = actor.position.x-previous_x
				away = away and dx*(-attack_side) > 0.0 and absf(dx) <= float(spec["speed"])*1.8*dt+0.001 and is_equal_approx(actor.position.y,actor.room.floor_y(actor.position.x))
			_check(away,"Close hit on side %d while walking %d retreats continuously with bounded speed and dry feet" % [attack_side,travel_direction])

func _has_blocking_body(node: Node) -> bool:
	if node is PhysicsBody2D: return true
	for child: Node in node.get_children():
		if _has_blocking_body(child): return true
	return false

func _check(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)

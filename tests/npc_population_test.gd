extends SceneTree
## Actual sidecar persistence, shared DamageEvent, existing travel and UI routing.
class FaultIo extends SanctuaryProfile:
	var reject: bool = false
	func _replace_file(temporary: String, target: String) -> bool:
		return false if reject else super._replace_file(temporary, target)

class InterruptedIo extends SanctuaryProfile:
	var main_path: String
	func _rename_file(from_path: String, to_path: String) -> Error:
		if to_path == main_path and from_path in [main_path + ".tmp", main_path + ".previous"]: return ERR_CANT_CREATE
		return super._rename_file(from_path, to_path)

var checks: int = 0
var failures: int = 0
var path_prefix: String
var flow: GameFlow
var hub: ExteriorHub
var cues: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	path_prefix = "user://verification/npc_population_%d_%d" % [Engine.physics_ticks_per_second, Time.get_ticks_usec()]
	print("NPC_POPULATION_USER_DIR=" + ProjectSettings.globalize_path("user://"))
	_pure_simulation()
	_persistence_and_decisions()
	await _integration()
	print("RESULT npc_population checks=%d failures=%d hz=%d" % [checks, failures, Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

func _pure_simulation() -> void:
	var first := NpcWorldState.new()
	var second := NpcWorldState.new()
	var observed: Dictionary = {}
	for id: String in NpcPilotCatalog.IDS: observed[id] = {}
	for index: int in 600:
		first.advance_ticks(1)
		second.advance_ticks(1)
		for id: String in NpcPilotCatalog.IDS: observed[id][first.records[id]["mode"]] = true
	_check(first.snapshot() == second.snapshot(), "Same authored inputs and 600 in-game ticks produce identical snapshots")
	_check(NpcWorldState.valid(first.snapshot()), "Longer authored schedules stay within validated room bounds")
	for id: String in NpcPilotCatalog.IDS:
		_check(observed[id].has("walk") and observed[id].has("rest") and observed[id].has("work"), "%s visibly transitions walk/work/rest" % id)
		_check(NpcPilotCatalog.definition(id)["room"] == first.records[id]["room"], "%s retains assigned region ownership" % id)
	var copied: Dictionary = first.snapshot()
	copied["records"][NpcPilotCatalog.IDS[0]]["trust"] = 70
	_check(first.records[NpcPilotCatalog.IDS[0]]["trust"] == 0, "Snapshot cannot mutate registry or shared definitions")
	var before: int = first.tick
	first.advance_ticks(9999)
	_check(first.tick - before == 8, "Catch-up work is capped to eight simulation ticks")
	var malformed: Dictionary = first.snapshot()
	malformed["records"][NpcPilotCatalog.IDS[0]]["x"] = NAN
	_check(not NpcWorldState.valid(malformed), "Non-finite coordinates cannot enter save or region actors")
	malformed = first.snapshot()
	malformed["records"]["invented_id"] = malformed["records"][NpcPilotCatalog.IDS[0]]
	_check(not NpcWorldState.valid(malformed), "Unknown or duplicate identities cannot inflate population")
	var hazard := NpcWorldState.new()
	hazard.save_path = path_prefix + "_hazard.json"
	hazard.receive_hit(NpcPilotCatalog.IDS[0], 35, 0, false)
	_check(hazard.records[NpcPilotCatalog.IDS[0]]["fear"] == 6 and hazard.records[NpcPilotCatalog.IDS[0]]["trust"] == 0, "Unknown attacker or environmental harm creates fear without falsely blaming Player")

func _persistence_and_decisions() -> void:
	var state := NpcWorldState.new()
	state.save_path = path_prefix + "_state.json"
	_check(state.load_state() and state.save(), "A legacy profile needs no NPC schema migration")
	var id: String = NpcPilotCatalog.IDS[0]
	_check(state.begin_talk(id) and state.greet(id), "A first greeting records a modest relationship event")
	_check(not state.greet(id) and state.records[id]["trust"] == 1, "Repeated greeting cannot farm affinity")
	var interrupted := NpcWorldState.new()
	interrupted.save_path = state.save_path
	_check(interrupted.load_state() and interrupted.records[id]["mode"] == "walk", "Reload resumes the interrupted schedule while preserving the greeting")
	state.end_talk(id)
	state.receive_hit(id, 1, 0)
	var token: String = state.decision_token(id)
	_check(not token.is_empty() and state.records[id]["mode"] == "downed", "Lethal combat stops at a living DOWNED record")
	var downed: Dictionary = state.records[id].duplicate(true)
	for _index: int in 50: state.advance_ticks(8)
	_check(state.records[id] == downed, "No offscreen timer executes a downed NPC")
	_check(not state.decide(id, "stale", false) and not state.decide(id, token, true), "Stale choice and unconfirmed kill cannot commit")
	var fault := FaultIo.new()
	state.io = fault
	fault.reject = true
	_check(not state.decide(id, token, true, true) and state.records[id]["mode"] == "downed", "Failed disk commit rolls back execution and death record")
	fault.reject = false
	_check(state.decide(id, token, false), "Explicit spare persists recovery")
	_check(state.records[id]["debt"] == 1 and state.records[id]["fear"] == 6 and state.records[id]["trust"] == -1, "Spare adds goodwill without erasing fear or guaranteeing friendship")
	_check(not state.decide(id, token, false) and state.records[id]["debt"] == 1, "Repeated decision cannot duplicate relationship events")
	for _index: int in 10: state.advance_ticks(8)
	_check(state.records[id]["mode"] == "walk" and state.records[id]["hp"] == 20, "Recovery uses in-game time and returns at half health")
	state.receive_hit(id, 1, 0)
	token = state.decision_token(id)
	_check(state.decide(id, token, true, true), "Fresh explicit confirmed execution creates permanent death")
	var death: Dictionary = state.records[id].duplicate(true)
	_check(not state.decide(id, token, true, true) and state.records[id] == death, "Death event is idempotent")
	var loaded := NpcWorldState.new()
	loaded.save_path = state.save_path
	var load_ok: bool = loaded.load_state()
	_check(load_ok and loaded.snapshot() == state.snapshot(), "Round-trip preserves stable IDs, death and relationship state")
	for _index: int in 20: loaded.advance_ticks(8)
	_check(loaded.records[id] == death, "Permanent death cannot heal, move or respawn offscreen")
	var corrupt := FileAccess.open(state.save_path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	var quarantined := NpcWorldState.new()
	quarantined.save_path = state.save_path
	_check(not quarantined.load_state() and quarantined.read_only and not quarantined.save(), "Corrupt main is quarantined and never replaced with an older alive backup")
	_check(FileAccess.get_file_as_string(state.save_path) == "{broken", "Quarantine preserves broken evidence for manual recovery")
	var future := NpcWorldState.new()
	future.save_path = path_prefix + "_future.json"
	var future_data: Dictionary = future.snapshot()
	future_data["npc_schema"] = 3
	var future_file := FileAccess.open(future.save_path, FileAccess.WRITE)
	future_file.store_string(JSON.stringify(future_data))
	future_file.close()
	_check(not future.load_state() and not future.save(), "Future schema remains untouched")
	var interrupted_commit := NpcWorldState.new()
	interrupted_commit.save_path = path_prefix + "_interrupted_commit.json"
	interrupted_commit.save()
	interrupted_commit.receive_hit(id, 1, 0)
	var interrupted_io := InterruptedIo.new()
	interrupted_io.main_path = interrupted_commit.save_path
	interrupted_commit.io = interrupted_io
	_check(not interrupted_commit.decide(id, interrupted_commit.decision_token(id), true, true) and interrupted_commit.records[id]["mode"] == "downed", "Failed final rename and failed rollback still report uncommitted living decision")
	var uncertain := NpcWorldState.new()
	uncertain.save_path = interrupted_commit.save_path
	_check(not uncertain.load_state() and uncertain.read_only and not uncertain.save(), "Cold load quarantines uncommitted Kill tmp instead of silently applying it")
	var missing_main := NpcWorldState.new()
	missing_main.save_path = path_prefix + "_missing_main.json"
	DirAccess.copy_absolute(state.save_path + ".bak", missing_main.save_path + ".bak")
	_check(not missing_main.load_state() and missing_main.read_only, "Missing main with historical backup cannot create a fresh alive population")

func _integration() -> void:
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path_prefix + "_profile.json"
	root.add_child(flow)
	current_scene = flow
	await _step(8)
	hub = flow.active_scene as ExteriorHub
	var population: NpcPopulation = hub.npc_population
	population.cue_requested.connect(func(_id: String, _cue: StringName, _at: Vector2, _owner: Node) -> void: cues += 1)
	_check(population != null and population.state.records.size() == 6 and population.actors.is_empty(), "H00 owns one bounded registry but zero pilot scene actors")
	var player_id: int = hub.player.get_instance_id()
	var owned: Array = hub.gear.inventory.items.keys()
	hub.player.health.current_health = 37
	hub.player.energy.current = 41
	hub.player.energy.regeneration_delay = 10000
	_check(hub.enter_exterior(&"o01_p01", &"main", &"west", false), "Pilot uses ordinary authored exterior travel")
	await _step(8)
	_check(population.actors.size() == 1 and _actor_count() == 1, "P01 has exactly its one assigned traveler")
	var id: String = NpcPilotCatalog.IDS[0]
	var pilot: NpcPilotActor = population.actors[id]
	_check(is_equal_approx(pilot.position.y, hub.exterior.floor_y(pilot.position.x)), "Actor feet follow actual authored dry heightfield")
	_check(pilot.caption.is_visible_in_tree(),"NPC identity/activity remain visible when the general debug overlay is off")
	var position_before: Vector2 = pilot.position
	await _step(Engine.physics_ticks_per_second * 2)
	_check(pilot.position.x > position_before.x and cues > 0, "Real manager ticks move the traveler and emit bounded presentation/audio hooks")
	PlayerTravel.relocate(hub.player, pilot.global_position)
	await _step(3)
	await _key_e()
	_check(hub.dialogue.is_open and population.state.records[id]["mode"] == "talk", "Actual E opens living NPC conversation")
	_check(not hub.player.controls_enabled, "Conversation locks combat controls")
	var paused_tick: int = population.state.tick
	await _step(Engine.physics_ticks_per_second)
	_check(population.state.tick == paused_tick, "World time stops for dialogue instead of creeping at modal time scale")
	for _page_step: int in hub.dialogue.pages.size()*2:
		if hub.dialogue.page_index == hub.dialogue.pages.size()-1 and not hub.dialogue.is_typing(): break
		hub.dialogue.advance()
	hub.dialogue.select_choice(&"pilot_greet")
	await _step(3)
	_check(population.state.records[id]["greeted"] and hub.player.controls_enabled, "Actual dialogue choice persists greeting and releases input")
	(hub.gear.modal as InventoryScreen).open()
	paused_tick = population.state.tick
	await _step(Engine.physics_ticks_per_second)
	_check(population.state.tick == paused_tick, "Inventory pauses NPC simulation")
	(hub.gear.modal as InventoryScreen).close()
	# Resolve real physics-query contacts via the existing weapon.
	population.set_process(false)
	pilot.sync_record(false)
	PlayerTravel.relocate(hub.player, pilot.global_position + Vector2(-35, 0))
	await _step(4)
	var mouse := InputEventMouseMotion.new()
	mouse.position = hub.player.get_canvas_transform() * (pilot.global_position + Vector2(0, -25))
	Input.parse_input_event(mouse)
	await _step(1)
	var hp_before: float = pilot.health.current_health
	Input.action_press(&"attack")
	await _step(1)
	Input.action_release(&"attack")
	await _step(Engine.physics_ticks_per_second)
	_check(pilot.health.current_health < hp_before and population.state.records[id]["mode"] == "flee", "Existing committed melee hits the NPC Hurtbox and triggers local fleeing")
	var lethal: DamageResult = pilot.hurtbox.take_damage(_event(pilot, 9999, DamageEvent.SourceKind.DIRECT))
	_check(not lethal.blocked and not lethal.killed and pilot.health.current_health == 1 and population.state.records[id]["mode"] == "downed", "Shared resolver returns living defeat without kill rewards")
	pilot.sync_record(false)
	_check(absf(pilot.caption.get_global_transform().get_rotation()) < 0.001 and pilot.caption.global_position.y < pilot.global_position.y-80,"Downed pose keeps the interaction caption upright above the NPC")
	for kind: int in [DamageEvent.SourceKind.DIRECT, DamageEvent.SourceKind.RESONANCE, DamageEvent.SourceKind.DOT, DamageEvent.SourceKind.ENVIRONMENT]:
		var blocked: DamageResult = pilot.hurtbox.take_internal_damage(_event(pilot, 9999, kind))
		_check(blocked.blocked and not blocked.killed and pilot.health.current_health == 1, "Damage kind %d cannot finish downed NPC even through internal delivery" % kind)
	var companion: DamageEvent = _event(pilot, 9999, DamageEvent.SourceKind.DIRECT)
	companion.source_team_id = 1
	companion.source_id = root.get_instance_id()
	_check(pilot.hurtbox.take_damage(companion).blocked, "Companion-like team delivery cannot silently execute downed NPC")
	var debt_before: int = population.state.records[id]["debt"]
	var token: String = population.state.decision_token(id)
	_check(hub.enter_exterior(&"o01_p02", &"main", &"west", false), "Player can leave a downed NPC without auto-execution")
	await _step(3)
	_check(population.actors.size() == 1 and population.actors.has("pilot_bridge_keeper") and not population.actors.has(id) and _actor_count() == 1, "Travel detaches traveler and exposes only the bridge's stable resident")
	_check(hub.enter_exterior(&"o01_p02", &"guard_corridor", &"west", false), "Existing locked corridor is unchanged")
	await _step(3)
	_check(population.actors.is_empty() and not hub.exterior.gate_open, "NPC population never spawns past a closed route gate")
	_check(hub.enter_exterior(&"o01_p01", &"main", &"west", false), "Return to pilot region succeeds")
	await _step(3)
	pilot = population.actors[id]
	_check(_actor_count() == 1 and population.state.decision_token(id) == token and pilot.health.current_health == 1, "A-B-A restores one downed identity with unchanged decision token")
	PlayerTravel.relocate(hub.player, pilot.global_position)
	await _step(4)
	_check(population.interact(id), "Downed NPC exposes explicit choice on approach")
	hub.dialogue.advance()
	_check(hub.dialogue.choices[0]["id"] == &"pilot_spare" and hub.dialogue.pages[0].contains("vĩnh viễn"), "Safe spare is first and permanent consequence is visible")
	hub.dialogue.select_choice(&"pilot_ask_kill")
	_check(hub.dialogue.is_open and population.kill_confirmation and population.state.records[id]["mode"] == "downed", "First Kill opens a separate confirmation, preserving living state")
	_check(not hub.player.controls_enabled and not hub.enter_exterior(&"o01_p02"), "Kill confirmation retains modal combat and travel lock")
	hub.dialogue.advance()
	hub.dialogue.select_choice(&"pilot_cancel_kill")
	hub.dialogue.advance()
	hub.dialogue.select_choice(&"pilot_spare")
	await _step(3)
	_check(population.state.records[id]["mode"] == "recovering" and population.state.records[id]["debt"] == debt_before + 1, "Actual UI spare commits once and starts recovery")
	for _index: int in 10: population.state.advance_ticks(8)
	pilot.sync_record(false)
	pilot.hurtbox.take_damage(_event(pilot, 9999, DamageEvent.SourceKind.DIRECT))
	_check(population.interact(id), "Another defeat gets its own decision episode")
	hub.dialogue.advance()
	hub.dialogue.select_choice(&"pilot_ask_kill")
	hub.dialogue.advance()
	hub.dialogue.select_choice(&"pilot_confirm_kill")
	await _step(3)
	_check(population.state.records[id]["mode"] == "dead" and population.actors.is_empty() and _actor_count() == 0, "Actual confirmed execution commits one tombstone and removes presentation")
	_check(hub.player.get_instance_id() == player_id and hub.gear.inventory.items.keys() == owned and hub.player.health.current_health == 37 and hub.player.energy.current == 41, "NPC travel and choices preserve Player/session/UID/HP/energy without rewards")
	population.set_process(true)
	for room_id: StringName in ExteriorRouteCatalog.ROOMS:
		hub.enter_exterior(room_id, &"main", &"west", false)
		await _step(3)
		_check(_actor_count() <= 1, "No duplicate local representation after entering %s" % room_id)
		for local_id: String in population.actors:
			_check(population.state.records[local_id]["room"] == String(room_id), "Current actor belongs to current room %s" % room_id)
	hub.return_to_hub(false)
	await _step(3)
	_check(_actor_count() == 0, "Hub return cleans pilot actors and room audio ownership")
	var sidecar: String = population.state.save_path
	flow.queue_free()
	await _step(4)
	var cold := NpcWorldState.new()
	cold.save_path = sidecar
	_check(cold.load_state() and cold.records[id]["mode"] == "dead", "Full scene teardown and cold load do not resurrect executed identity")
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path_prefix + "_profile.json"
	root.add_child(flow)
	current_scene = flow
	await _step(8)
	hub = flow.active_scene as ExteriorHub
	hub.enter_exterior(&"o01_p01", &"main", &"west", false)
	await _step(3)
	_check(hub.npc_population.state.records[id]["mode"] == "dead" and _actor_count() == 0, "Actual new GameFlow and revisited room cannot duplicate or resurrect a dead actor")
	hub.enter_exterior(&"o01_p03", &"main", &"west", false)
	await _step(3)
	population = hub.npc_population
	population.set_process(false)
	var pilgrim_id: String = "pilot_pilgrim"
	population.state.records[pilgrim_id]["x"] = 1710.0
	population.state.records[pilgrim_id]["mode"] = "rest"
	population.state.records[pilgrim_id]["remaining"] = 32
	population.actors[pilgrim_id].sync_record(false)
	PlayerTravel.relocate(hub.player,ExteriorHub.ORIGIN+hub.exterior.interactions[&"shrine"])
	await _step(3)
	hub._process(0)
	population._process(0)
	_check(hub.nearest_station() == &"shrine" and hub.prompt.text.contains("mốc địa lý"),"NPC nearby cannot replace the prompt for the closer shrine interaction")
	PlayerTravel.relocate(hub.player,population.actors[pilgrim_id].global_position)
	await _step(3)
	hub._process(0)
	population._process(0)
	_check(hub.nearest_station() == StringName(pilgrim_id) and hub.prompt.text.contains("Người hành hương"),"The nearest NPC prompt matches the actual E destination")
	var corrupt_live := FileAccess.open(population.state.save_path,FileAccess.WRITE)
	corrupt_live.store_string("{broken-live")
	corrupt_live.close()
	_check(not population.state.save() and population.state.read_only,"A newly corrupt NPC sidecar enters quarantine during the live session")
	_check(population.nearest_id(1000).is_empty() and not population.interact(pilgrim_id),"Live quarantine cannot offer interaction or a new NPC decision")
	population._process(0)
	await _step(3)
	_check(population.actors.is_empty() and _actor_count() == 0 and FileAccess.get_file_as_string(population.state.save_path) == "{broken-live","Live quarantine removes scene actors and preserves corrupt evidence")
	flow.queue_free()
	await _step(4)

func _event(pilot: NpcPilotActor, damage: float, kind: int) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = hub.player.get_instance_id()
	event.target_id = pilot.get_instance_id()
	event.source_team_id = 1
	event.attack_id = CombatIds.next_id()
	event.hit_window_id = 1
	event.root_event_id = event.attack_id
	event.source_kind = kind as DamageEvent.SourceKind
	event.base_damage = damage
	event.attack_origin = hub.player.global_position
	return event

func _actor_count() -> int:
	return get_nodes_in_group(&"npc_pilot_actor").size()

func _key_e() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await _step(1)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	await _step(1)

func _step(count: int) -> void:
	for _index: int in count: await physics_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)

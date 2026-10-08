extends SceneTree
## Real rooms, Player, query Hitbox contacts and runtime actor clocks; isolated save.
var capture: bool = false
var checks: int = 0
var failures: int = 0
var flow: GameFlow
var hub: ExteriorHub
var population: NpcPopulation
var path_prefix: String
var _last_result: DamageResult
var _last_event: DamageEvent
var _received_attack_ids: Array[int] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg=="--native-approved": capture=true
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	path_prefix = "user://verification/cultivator_%d_%d" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path_prefix+"_profile.json"
	root.add_child(flow)
	current_scene = flow
	await _step(8)
	hub = flow.active_scene as ExteriorHub
	population = hub.npc_population
	_check(population.actors.is_empty(),"No cultivator spawns inside H00")
	for id: String in CultivatorCatalog.IDS:
		await _exercise_cultivator(id)
	await _quarantine_active_strike()
	_check(NpcWorldState.valid(population.state.snapshot()),"Runtime patrol/combat records remain schema-valid")
	hub.return_to_hub(false)
	await _step(4)
	_check(get_nodes_in_group(&"npc_pilot_actor").is_empty(),"Hub travel removes every room-owned NPC")
	var sidecar: String = population.state.save_path
	flow.queue_free()
	await _step(6)
	var cold := NpcWorldState.new()
	cold.save_path = sidecar
	_check(cold.load_state(),"Cold load accepts the saved NPC sidecar")
	for id: String in CultivatorCatalog.IDS:
		_check(cold.records[id]["mode"] == "recovering" and cold.records[id]["hp"] == 1.0 and cold.records[id]["trust"] < 0,"Cold load preserves withdrawal and memory for "+id)
	print("RESULT cultivator_patrol checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

func _exercise_cultivator(id: String) -> void:
	var spec: Dictionary = NpcPilotCatalog.definition(id)
	if id in NpcPilotCatalog.SECT_STEWARD_IDS:
		_check(hub.sect_journey.progress.record(SectRouteCatalog.faction(StringName(spec["room"])),"accept"),"Fixture accepts only the steward entrance quest")
	_check(hub.enter_exterior(StringName(spec["room"]),&"main",&"west",false),"Enter authored room for "+id)
	await _step(6)
	_check(population.actors.has(id),"Population selects the authored cultivator subclass")
	if not population.actors.has(id): return
	var actor: CultivatorActor = population.actors[id] as CultivatorActor
	_check(actor != null and actor.player == hub.player,"Subclass binds the existing Player and registry")
	if actor == null: return
	var start_x: float = actor.position.x
	# The other resident's offscreen schedule may already be resting on arrival.
	for _index: int in _frames(4.0):
		if absf(actor.position.x-start_x) > 1.0: break
		await _step(1)
	_check(absf(actor.position.x-start_x) > 1.0 and actor.combat_phase == "idle" and actor.accepted_strikes == 0,"Neutral cultivator resumes its bounded patrol without attacking: "+id)
	_check(is_equal_approx(actor.position.y,hub.exterior.floor_y(actor.position.x)),"Patrol feet remain on the actual road heightfield")
	var own_id: int = actor.get_instance_id()
	PlayerTravel.relocate(hub.player,actor.global_position+Vector2(-48,0))
	await _step(3)
	hub.player.health.current_health = hub.player.health.maximum_health
	hub.player.hurtbox.hit_resolved.connect(_observe_player_hit)
	actor.hurtbox.invulnerable = true
	await _probe(actor,hub.player,1.0)
	_check(_last_result != null and _last_result.blocked and actor.combat_phase == "idle","Blocked physical contact never provokes self-defense")
	actor.hurtbox.invulnerable = false
	var other_source := Node2D.new()
	hub.exterior.add_child(other_source)
	other_source.global_position = hub.player.global_position
	var trust_before: int = population.state.records[id]["trust"]
	await _probe(actor,other_source,1.0)
	_check(_last_result != null and _last_result.actual_damage > 0.0 and actor.combat_phase == "idle" and population.state.records[id]["trust"] == trust_before,"A live team-1 bystander is not attributed to Player")
	other_source.queue_free()
	# The normal equipped weapon also reaches the actual neutral Hurtbox.
	PlayerTravel.relocate(hub.player,actor.global_position+Vector2(-32,0))
	await _step(3)
	var mouse := InputEventMouseMotion.new()
	mouse.position = hub.player.get_canvas_transform()*(actor.global_position+Vector2(0,-25))
	Input.parse_input_event(mouse)
	await _step(1)
	if capture:
		var camera:=hub.player.get_node("Camera2D") as Camera2D
		camera.reset_smoothing(); camera.force_update_scroll()
	await _capture(id+"_patrol")
	var hp_before: float = actor.health.current_health
	Input.action_press(&"attack")
	await _step(1)
	Input.action_release(&"attack")
	await _step(_frames(0.35))
	_check(actor.health.current_health < hp_before and actor.combat_phase != "idle" and actor.reason.contains("Tự vệ"),"Actual committed Player melee causes reasoned self-defense")
	# Separate query windows share a root: both can damage, only one cause is remembered.
	var root_id: int = CombatIds.next_id()
	await _probe(actor,hub.player,1.0,root_id)
	var remembered_trust: int = population.state.records[id]["trust"]
	var remembered_fear: int = population.state.records[id]["fear"]
	await _probe(actor,hub.player,1.0,root_id)
	_check(_last_result.actual_damage > 0.0 and population.state.records[id]["trust"] == remembered_trust and population.state.records[id]["fear"] == remembered_fear,"Multiple accepted contacts from one root create one remembered cause")
	var duplicate_attack: int = _last_event.attack_id
	var duplicate_hp: float = actor.health.current_health
	await _probe(actor,hub.player,1.0,root_id,duplicate_attack)
	_check(_last_result.blocked and _last_result.block_reason == &"duplicate" and actor.health.current_health == duplicate_hp and population.state.records[id]["trust"] == remembered_trust,"Repeated physical delivery is rejected without extra injury or memory")
	PlayerTravel.relocate(hub.player,actor.global_position+Vector2(-48,0))
	await _wait_phase(actor,"tell",3.0)
	_check(actor.combat_phase == "tell" and not actor.strike_hitbox.active,"Visible tell precedes the damaging window")
	await _capture(id+"_tell")
	var cancelled_id: int = actor._strike.attack_id if actor._strike != null else 0
	await _probe(actor,hub.player,1.0)
	_check(actor.combat_phase == "hurt" and not actor.strike_hitbox.active and actor._strike == null,"Accepted injury immediately cancels the committed strike")
	var strikes_before: int = actor.accepted_strikes
	for _index: int in _frames(4.0):
		if actor.accepted_strikes > strikes_before: break
		await _step(1)
	_check(actor.accepted_strikes > strikes_before and hub.player.health.current_health < hub.player.health.maximum_health,"Self-defense active Hitbox physically damages the existing Player")
	await _capture(id+"_counterstrike")
	_check(cancelled_id > 0 and cancelled_id not in _received_attack_ids,"Cancelled strike cannot leak damage from an old snapshot")
	await _wait_phase(actor,"tell",3.0)
	(hub.gear.modal as InventoryScreen).open()
	await _step(3)
	var paused_position: Vector2 = actor.position
	var paused_clock: float = actor.phase_remaining
	var paused_hp: float = hub.player.health.current_health
	await _step(_frames(0.5))
	_check(actor.position == paused_position and is_equal_approx(actor.phase_remaining,paused_clock) and not actor.strike_hitbox.active and hub.player.health.current_health == paused_hp,"Inventory pauses movement/clocks and cancels damage windows")
	(hub.gear.modal as InventoryScreen).close()
	PlayerTravel.relocate(hub.player,hub.exterior.global_position+Vector2(float(spec["left"])-150.0,hub.exterior.floor_y(float(spec["left"])-150.0)))
	await _step(5)
	_check(actor.combat_phase == "idle" and not actor.strike_hitbox.active and actor.reason.contains("ngừng"),"Leaving the patrol leash cancels pursuit and damage")
	_check(actor.position.x >= float(spec["left"]) and actor.position.x <= float(spec["right"]) and is_equal_approx(actor.position.y,hub.exterior.floor_y(actor.position.x)),"Combat never leaves its safe grounded bounds")
	# Re-entering the same road preserves identity memory, never an in-flight strike.
	hub.player.hurtbox.hit_resolved.disconnect(_observe_player_hit)
	_check(hub.enter_exterior(&"o01_p03",&"main",&"west",false),"Leaving the combat room succeeds")
	await _step(4)
	_check(not is_instance_id_valid(own_id),"Room teardown frees the cultivator and owned hitbox")
	_check(hub.enter_exterior(StringName(spec["room"]),&"main",&"west",false),"Return to the assigned patrol room")
	await _step(5)
	actor = population.actors[id] as CultivatorActor
	_check(actor.combat_phase == "idle" and actor._strike == null and population.state.records[id]["trust"] < 0,"Scene return preserves memory without restoring a stale attack")
	PlayerTravel.relocate(hub.player,actor.global_position+Vector2(-40,0))
	await _step(3)
	var final_actor_id: int = actor.get_instance_id()
	await _probe(actor,hub.player,9999.0)
	_check(_last_result != null and not _last_result.killed and population.state.records[id]["hp"] == 1.0 and population.state.records[id]["mode"] == "recovering","Lethal-strength physical hit leaves living withdrawal at HP 1")
	await _step(4)
	_check(not population.actors.has(id) and not is_instance_id_valid(final_actor_id),"Withdrawal removes the local fighter and pending attack")
	for _tick: int in 8: population.state.advance_ticks(8)
	_check(population.state.records[id]["mode"] == "recovering","Elapsed patrol time alone cannot recover a withdrawn NPC")
	_check(hub.player.health.minimum_health == 1.0,"Existing SafeHub Player floor remains unchanged")

func _quarantine_active_strike() -> void:
	_check(hub.enter_exterior(&"o01_p01",&"main",&"west",false),"Enter real room for quarantine contact fixture")
	await _step(4)
	# A separate registry isolates the fault from the durable population under test.
	var state := NpcWorldState.new()
	var actor := CultivatorActor.new()
	actor.stable_id = CultivatorCatalog.IDS[0]
	actor.npc_id = StringName(actor.stable_id)
	actor.world_state = state
	actor.room = hub.exterior
	actor.player = hub.player
	actor.bind_road_idle_art()
	hub.exterior.add_child(actor)
	actor.sync_record(true)
	PlayerTravel.relocate(hub.player,actor.global_position+Vector2(-48,0))
	await _step(3)
	await _probe(actor,hub.player,1.0)
	await _wait_phase(actor,"tell",2.0)
	_check(actor.combat_phase == "tell","Quarantine fixture reaches tell through accepted physical injury")
	# Move behind the committed strike so its first active sample really misses.
	PlayerTravel.relocate(hub.player,actor.global_position+Vector2(48,0))
	await _wait_phase(actor,"active",2.0)
	_check(actor.combat_phase == "active" and actor.strike_hitbox.active,"Quarantine begins during a real active window")
	var before: float = hub.player.health.current_health
	state.read_only = true
	PlayerTravel.relocate(hub.player,actor.global_position+Vector2(-48,0))
	await _step(3)
	_check(not actor.strike_hitbox.active and actor._strike == null and actor.combat_phase == "idle" and hub.player.health.current_health == before,"Quarantine cancels the live strike before a new physical contact can damage Player")
	actor.queue_free()
	await _step(3)

func _probe(actor: CultivatorActor, source: Node2D, damage: float, root_id: int = 0, attack_id: int = 0) -> void:
	_last_result = null
	_last_event = null
	var attack := AttackSnapshot.new()
	attack.source_id = source.get_instance_id()
	attack.source_team_id = 1
	attack.attack_id = CombatIds.next_id() if attack_id == 0 else attack_id
	attack.root_event_id = attack.attack_id if root_id == 0 else root_id
	attack.base_damage = damage
	attack.attack_origin = source.global_position
	var probe: Hitbox = ActorCombatRig.hitbox(hub.exterior,16)
	probe.contact_detected.connect(func(target: Hurtbox, snapshot: AttackSnapshot) -> void:
		if target != actor.hurtbox: return
		var event := DamageEvent.new()
		event.source_id = snapshot.source_id
		event.source_team_id = snapshot.source_team_id
		event.target_id = target.get_actor_id()
		event.attack_id = snapshot.attack_id
		event.root_event_id = snapshot.root_event_id
		event.hit_window_id = snapshot.hit_window_id
		event.attack_origin = snapshot.attack_origin
		event.base_damage = snapshot.base_damage
		_last_event = event
		_last_result = target.take_damage(event)
	)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30,54)
	probe.activate(attack,shape,actor.position+Vector2(0,-26))
	await _step(1)
	probe.sample_contacts()
	probe.sample_contacts()
	probe.deactivate()
	probe.queue_free()
	# No await here: inspect the accepted result before registry withdrawal cleanup.

func _observe_player_hit(event: DamageEvent, result: DamageResult) -> void:
	if result.actual_damage > 0.0: _received_attack_ids.append(event.attack_id)

func _wait_phase(actor: CultivatorActor, phase: String, seconds: float) -> void:
	for _index: int in _frames(seconds):
		if actor.combat_phase == phase: return
		await _step(1)

func _frames(seconds: float) -> int:
	return int(ceil(seconds*Engine.physics_ticks_per_second))

func _step(count: int) -> void:
	for _index: int in count: await physics_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+message)

func _capture(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join(label+".png"))

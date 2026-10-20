extends SceneTree
## Isolated canonical quest plus real P01 actor/slime bodies and hit pipelines.
var checks: int = 0
var failures: int = 0
var flow: GameFlow
var hub: ExteriorHub
var population: NpcPopulation

func _initialize() -> void:
	Engine.physics_ticks_per_second = 120 if "--hz=120" in OS.get_cmdline_user_args() else 60
	_run.call_deferred()

func _run() -> void:
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: isolated DUNGEON_QA_DATA_ROOT required"); quit(2); return
	var path: String = "user://verification/tan_dang_living_runtime_%d_%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path
	root.add_child(flow)
	current_scene = flow
	await _step(8)
	hub = flow.active_scene as ExteriorHub
	population = hub.npc_population
	_check(is_instance_valid(hub.living) and is_instance_valid(population) and population.state.active_room == TanDangLivingCatalog.HUB,"One living component uses the loaded hub's canonical population")
	# Keep the automatic runtime from racing the explicit owner setup below.
	hub.living.set_process(false)
	var progress: TanDangProgress = hub.tan_dang.progress
	_action(progress,"accept","ledger")
	_action(progress,"observe_lamp","lamp")
	_action(progress,"find_lam","refuge")
	_action(progress,"inspect_core","refuge")
	_action(progress,"q1_reward")
	_action(progress,"choice_rescue","refuge")
	_action(progress,"report_moc",TanDangProgress.MOC)
	_action(progress,"report_lam",TanDangProgress.LAM)
	_action(progress,"q3_reward")
	population.refresh_actors()
	var life: NpcWorldState = population.state
	_check(progress.state()["rewards"].has("q3") and progress.alive(TanDangProgress.LAM) and life.records[TanDangProgress.LAM]["room"] == TanDangLivingCatalog.HUB,"Durable q3 rescue leaves a living Lâm in the hub")
	_check(life.start_living_event(progress.state()),"Actual q3 owner begins Lâm's finite route")
	var du: CultivatorActor = population.actors.get(TanDangProgress.DU) as CultivatorActor
	_check(is_instance_valid(du),"Rescued Dư is physically present for a proximity greeting")
	if not is_instance_valid(du): await _finish(); return
	hub.player.global_position = du.global_position+Vector2(400.0,0.0)
	hub.living.set_process(true)
	await _step(8)
	_check(not life.living_view(TanDangProgress.DU)["acknowledged"]["quest_help"],"Distant Player cannot claim Dư's remembered rescue")
	hub.player.global_position = du.global_position+Vector2(60.0,0.0)
	await _step(12)
	_check(du.greeting_hint.contains("chỗ trú") and not life.living_view(TanDangProgress.DU)["acknowledged"]["quest_help"],"Nearby Dư speaks the specific rescue before its durable receipt")
	await _step(190)
	_check(life.living_view(TanDangProgress.DU)["acknowledged"]["quest_help"],"Three seconds of actual close, calm presence acknowledges rescue exactly once")
	hub.living.set_process(false)
	for _i: int in 100:
		if float(life.records[TanDangProgress.LAM]["x"]) <= 750.0: break
		life.advance_ticks(1)
	_check(float(life.records[TanDangProgress.LAM]["x"]) <= 750.0 and life.records[TanDangProgress.LAM]["room"] == TanDangLivingCatalog.HUB,"Active hub clock moves Lâm to the door without remote handoff")
	_check(life.transfer_lam(TanDangLivingCatalog.P01),"Only the door endpoint transfers Lâm to P01")
	_check(hub.enter_exterior(&"o01_p01",ExteriorRouteCatalog.MAIN,&"west",false),"Real P01 room loads after the door handoff")
	await _step(6)
	for _i: int in 100:
		var rec: Dictionary = life.records[TanDangProgress.LAM]
		if is_equal_approx(float(rec["x"]),500.0) and int(rec["remaining"]) == 0: break
		life.advance_ticks(1)
	_check(life.advance_living_event(TanDangProgress.LAM,"collecting","danger"),"Finite work at the real P01 target enters danger only after its clock")
	var actor: CultivatorActor = population.actors.get(TanDangProgress.LAM) as CultivatorActor
	_check(is_instance_valid(actor),"Loaded P01 owns the real Lâm actor")
	if not is_instance_valid(actor): await _finish(); return
	# Fixture has advanced the owner clock without rendering those intermediate
	# frames; resync once at the saved target before testing live contact.
	actor._spawn_synced = false
	actor.sync_record(false)
	actor.sync_record(true)
	hub.living.set_process(true)
	await _step(8)
	var enemy: TanDangLivingSlime = hub.living.enemy
	_check(is_instance_valid(enemy) and enemy.get_parent() == hub.exterior and enemy.health.maximum_health == 60.0 and enemy.bite_hitbox.collision_mask == 24,"Event uses one real, standard-health slime with NPC and player contact channels")
	if not is_instance_valid(enemy): await _finish(); return
	_check(enemy.chase_speed == 115.0 and enemy.aggro_radius == 200.0 and enemy.attack_range == 40.0 and enemy.telegraph_seconds == 0.3 and TanDangLivingSlime.BITE_DAMAGE == 15.0,"Event slime keeps the existing chase, reach, tell and bite strength")
	_check(enemy.get_node_or_null("SlimeSpriteSkin") is SlimeSpriteSkin and not enemy.visual.visible,"Event-local enemy uses the existing painted Slime sprite")
	if actor.living_enemy == null: actor.request_living_defense(enemy)
	_check(actor.living_enemy == enemy,"Actual NPC defense is active before an authority-lock interruption")
	# A drawn-away or disposed monster ends only this encounter. Neither case
	# may retarget Lâm's strike onto a nearby, unharming Player.
	var safe_hp: float = hub.player.health.current_health
	var original_enemy_position: Vector2 = enemy.position
	enemy.ai_enabled = false
	enemy.position.x = actor.position.x+250.0
	actor._physics_process(0.016)
	_check(actor.combat_phase == "idle" and actor.living_enemy == null and actor.reason.contains("Yêu thú") and not actor.reason.contains("Bạn"),"Out-of-leash monster ends the NPC defense without blaming Player")
	_check(life.karma(TanDangProgress.LAM)["grievance"] == "" and hub.player.health.current_health == safe_hp,"Monster leash loss produces no Player injury or grievance")
	enemy.position = original_enemy_position
	_check(actor.request_living_defense(enemy),"The same living monster can be defended against again if it returns")
	actor.stop_living_defense()
	var expired: TanDangLivingSlime = TanDangLivingRuntime.SLIME_SCENE.instantiate() as TanDangLivingSlime
	expired.position = original_enemy_position
	expired.player = hub.player
	expired.resident = actor
	expired.combat_feedback = hub.feedback
	expired.ai_enabled = false
	hub.exterior.add_child(expired)
	_check(actor.request_living_defense(expired),"A separate real monster can own the transient NPC target")
	expired.free()
	_check(actor._combat_target() == null,"Freed monster target cannot fall through to Player")
	actor._physics_process(0.016)
	_check(actor.combat_phase == "idle" and actor.living_enemy == null and actor.reason.contains("Yêu thú") and hub.player.health.current_health == safe_hp and life.karma(TanDangProgress.LAM)["grievance"] == "","Expired monster ends defense without Player contact or grievance")
	_check(actor.request_living_defense(enemy),"Lâm resumes the original physical encounter after transient target checks")
	enemy.ai_enabled = true
	_check(life.save(),"Capture the exact finite owner bytes before quarantine fixture")
	var finite_before: Dictionary = life.snapshot()
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(life.save_path)
	enemy.suspend_encounter()
	enemy._open_living_bite()
	_check(enemy.bite_hitbox.active,"Fixture opens a real bite window before authority is lost")
	life.read_only = true
	hub.living._process(0.016)
	_check(not enemy.ai_enabled and not enemy.bite_hitbox.active and actor.living_enemy == null and actor.combat_phase == "idle","Read-only life instantly suspends bite and local NPC defense")
	_check(life.snapshot() == finite_before and FileAccess.get_file_as_bytes(life.save_path) == bytes_before,"Quarantine suspension publishes no provisional finite fact or file byte")
	life.read_only = false
	hub.living._process(0.016)
	if actor.living_enemy == null: actor.request_living_defense(enemy)
	enemy.suspend_encounter()
	enemy._open_living_bite()
	# The preceding unlocked adapter tick legitimately advances schema8 elapsed.
	# The lock must preserve its own boundary snapshot, not the earlier clock.
	finite_before = life.snapshot()
	life.compound_locked = true
	hub.living._process(0.016)
	_check(not enemy.ai_enabled and not enemy.bite_hitbox.active and actor.living_enemy == null,"Pending compound authority also prevents a local contact")
	_check(life.snapshot() == finite_before and FileAccess.get_file_as_bytes(life.save_path) == bytes_before,"Compound lock leaves owner state and durable bytes exactly unchanged")
	life.compound_locked = false
	hub.living._process(0.016)
	var hp_before: float = float(life.records[TanDangProgress.LAM]["hp"])
	var enemy_before: float = enemy.health.current_health
	for _i: int in 180:
		if not is_instance_valid(enemy) or life.living_view(TanDangProgress.LAM)["event_phase"] != "danger" or actor.accepted_strikes > 0 or float(life.records[TanDangProgress.LAM]["hp"]) < hp_before: break
		await _step(1)
	_check(actor.accepted_strikes > 0 or float(life.records[TanDangProgress.LAM]["hp"]) < hp_before,"Encounter produces an accepted physical NPC strike or monster bite")
	_check(life.karma(TanDangProgress.LAM)["grievance"] == "" and enemy.health.current_health <= enemy_before,"Monster combat does not invent Player harm or heal the threat")
	if life.living_view(TanDangProgress.LAM)["event_phase"] == "danger" and is_instance_valid(enemy):
		var hit := DamageEvent.new()
		hit.source_id = hub.player.get_instance_id()
		hit.source_team_id = hub.player.hurtbox.team_id
		hit.target_id = enemy.get_instance_id()
		hit.attack_id = CombatIds.next_id()
		hit.root_event_id = hit.attack_id
		hit.hit_window_id = 1
		hit.base_damage = 500.0
		hit.attack_origin = hub.player.global_position
		hit.attack_direction = Vector2.RIGHT
		var result: DamageResult = enemy.hurtbox.take_damage(hit)
		_check(result.actual_damage > 0.0 and enemy.health.current_health <= 0.0,"Player final blow resolves through the enemy's real Hurtbox and Health (block="+String(result.block_reason)+")")
		await _step(3)
		var view: Dictionary = life.living_view(TanDangProgress.LAM)
		_check(view["help_credited"] and view["outcome"] == "helped" and view["event_phase"] == "returning","Deferred death resolution sees accepted final-blow source before writing help once")
	if life.living_view(TanDangProgress.LAM)["event_phase"] == "returning":
		hub.living.set_process(false)
		for _i: int in 100:
			if float(life.records[TanDangProgress.LAM]["x"]) <= 150.0: break
			life.advance_ticks(1)
		_check(life.transfer_lam(TanDangLivingCatalog.HUB) and hub.return_to_hub(false),"Real owner carries the surviving speaker home through both door endpoints")
		await _step(5)
		for _i: int in 100:
			if life.living_view(TanDangProgress.LAM)["event_phase"] == "done": break
			life.advance_ticks(1)
		_check(life.living_view(TanDangProgress.LAM)["event_phase"] == "done","Lâm finishes the same finite route before telling a listener")
		population.set_process(false)
		# Keep the returned speaker at his real rest stop while Dư follows his
		# own authored route back into earshot. No record coordinate is invented.
		life.set_local_control(TanDangProgress.LAM,true)
		var met_listener: bool = false
		for _i: int in 240:
			var source_record: Dictionary = life.records[TanDangProgress.LAM]
			var listener_record: Dictionary = life.records[TanDangProgress.DU]
			if absf(float(source_record["x"])-float(listener_record["x"])) <= 120.0 and listener_record["mode"] in ["walk","rest","work"]:
				met_listener = true
				break
			life.advance_ticks(1)
		_check(met_listener,"Authored Dư routine reaches the returned speaker without a fixture teleport")
		var returned: CultivatorActor = population.actors.get(TanDangProgress.LAM) as CultivatorActor
		var listener: CultivatorActor = population.actors.get(TanDangProgress.DU) as CultivatorActor
		if is_instance_valid(returned) and is_instance_valid(listener):
			returned._spawn_synced = false
			returned.sync_record(false)
			returned.sync_record(true)
			listener._spawn_synced = false
			listener.sync_record(false)
			listener.sync_record(true)
			_check(returned.global_position.distance_to(listener.global_position) <= 160.0,"A real nearby Lâm/Dư pair permits the calm report fixture")
			for _i: int in 31: hub.living._tick_listeners(0.1)
			_check(life.living_view(TanDangProgress.DU)["heard_materials"] and listener.living_hint.contains("Đã nghe"),"Local listener receives one visible confirmation after the actual report")
			var listener_facts: Dictionary = life.records[TanDangProgress.DU]["living"].duplicate(true)
			var listener_bytes: PackedByteArray = FileAccess.get_file_as_bytes(life.save_path)
			for _i: int in 31: hub.living._tick_listeners(0.1)
			listener._refresh_caption()
			_check(listener.living_hint.is_empty() and not listener.caption.text.contains("Đã nghe"),"Transient report confirmation yields to the resident's real work caption")
			_check(life.records[TanDangProgress.DU]["living"] == listener_facts and FileAccess.get_file_as_bytes(life.save_path) == listener_bytes,"Reading an already-known report and expiring its hint never mutates finite state or save bytes")
	await _far_encounter_fixture()
	await _finish()

func _far_encounter_fixture() -> void:
	# Fresh isolated owner, not a rollback of the first route's durable result.
	flow.queue_free()
	current_scene = null
	await _step(6)
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/tan_dang_living_far_%d_%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	root.add_child(flow)
	current_scene = flow
	await _step(8)
	hub = flow.active_scene as ExteriorHub
	population = hub.npc_population
	hub.living.set_process(false)
	var progress: TanDangProgress = hub.tan_dang.progress
	for action: String in ["accept","observe_lamp","find_lam","inspect_core","q1_reward","choice_rescue","report_moc","report_lam","q3_reward"]:
		var place: String = "ledger" if action == "accept" else "lamp" if action == "observe_lamp" else "refuge" if action in ["find_lam","inspect_core","choice_rescue"] else TanDangProgress.MOC if action == "report_moc" else TanDangProgress.LAM if action == "report_lam" else ""
		_action(progress,action,place)
	population.refresh_actors()
	var life: NpcWorldState = population.state
	_check(life.start_living_event(progress.state()),"Independent second owner starts a fresh finite trip")
	for _i: int in 100:
		if float(life.records[TanDangProgress.LAM]["x"]) <= 750.0: break
		life.advance_ticks(1)
	_check(life.transfer_lam(TanDangLivingCatalog.P01) and hub.enter_exterior(&"o01_p01",ExteriorRouteCatalog.MAIN,&"west",false),"Second encounter uses the actual road handoff")
	await _step(6)
	for _i: int in 100:
		var rec: Dictionary = life.records[TanDangProgress.LAM]
		if is_equal_approx(float(rec["x"]),500.0) and int(rec["remaining"]) == 0: break
		life.advance_ticks(1)
	_check(life.advance_living_event(TanDangProgress.LAM,"collecting","danger"),"Second encounter reaches danger from its own authored work")
	var actor: CultivatorActor = population.actors.get(TanDangProgress.LAM) as CultivatorActor
	if not is_instance_valid(actor): _check(false,"Second Lâm actor exists"); return
	actor._spawn_synced = false
	actor.sync_record(false)
	actor.sync_record(true)
	hub.living._tick_danger(0.016)
	var enemy: TanDangLivingSlime = hub.living.enemy
	if not is_instance_valid(enemy): _check(false,"Second real slime spawns"); return
	enemy.ai_enabled = false
	enemy.position.x = actor.position.x+310.0
	var actor_hp: float = float(life.records[TanDangProgress.LAM]["hp"])
	var player_hp: float = hub.player.health.current_health
	var enemy_hp: float = enemy.health.current_health
	for _i: int in 340: hub.living._tick_danger(0.1)
	_check(life.living_view(TanDangProgress.LAM)["event_phase"] == "danger","Far monster cannot silently complete the route before its finite horizon")
	for _i: int in 20:
		if life.living_view(TanDangProgress.LAM)["event_phase"] != "danger": break
		hub.living._tick_danger(0.1)
	var view: Dictionary = life.living_view(TanDangProgress.LAM)
	_check(view["event_phase"] == "returning" and view["outcome"] == "withdrew" and not view["help_credited"],"Active far-away threat resolves to a bounded honest withdrawal")
	_check(float(life.records[TanDangProgress.LAM]["hp"]) == actor_hp and hub.player.health.current_health == player_hp and enemy.health.current_health == enemy_hp and life.karma(TanDangProgress.LAM)["grievance"] == "","Far-threat fallback inflicts no invented damage, healing or Player grievance")

func _action(progress: TanDangProgress, action: String, place: String = "") -> void:
	var result: Dictionary = progress.apply(action,"",place)
	_check(bool(result.get("ok",false)),"Canonical story action commits: "+action)

func _step(count: int) -> void:
	for _i: int in ceili(float(count)*float(Engine.physics_ticks_per_second)/60.0): await physics_frame

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func _finish() -> void:
	if is_instance_valid(flow): flow.queue_free()
	await _step(6)
	await root.get_node("AudioManager").shutdown()
	print("RESULT tan_dang_living_runtime checks=%d failures=%d physics_hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

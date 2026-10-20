extends "res://tests/tan_dang_flow_test.gd"
## Focused real GameFlow karma evidence, separate from quest-completion coverage.
## Authoritative downed/execution and quest setup are explicit fixtures; living
## injury uses a physical query Hitbox, and aid uses actual E/dialogue choices.
var accepted_probe_injuries: int = 0

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if DisplayServer.get_name() != "headless" or not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: isolated headless QA root required"); quit(2); return
	prefix = "user://verification/tan_dang_karma_%d_%d" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	await _living_grievance()
	await _gratitude_aid()
	print("RESULT TanDangKarmaFlow checks=%d failures=%d hz=%d physical_injuries=%d" % [checks,failures,Engine.physics_ticks_per_second,accepted_probe_injuries])
	quit(0 if failures == 0 else 1)

## Witnessed/unwitnessed murder, interrupted delivery and bounded pursuit
## now belong to part4_causality_runtime_test, using actual sight/reporting.
func _living_grievance() -> void:
	path = prefix+"_living.json"
	await _open()
	hub = flow.active_scene as ExteriorHub
	_check(hub.enter_exterior(&"o01_p03"),"Living-offense fixture enters actual P03")
	await _step(4)
	var id: String = TanDangProgress.LAM
	var fighter: CultivatorActor = hub.npc_population.actors[id] as CultivatorActor
	var life_id: String = NpcWorldState.life_id(id)
	PlayerTravel.relocate(hub.player,fighter.global_position+Vector2(-32,0))
	await _step(3)
	await _physical_injury(fighter)
	await _wait_notice(id,"attacked",2.0)
	var living_hp: float = float(hub.npc_population.state.records[id]["hp"])
	_check(hub.npc_population.state.karma(id)["grievance"] == "attacked" and living_hp == fighter.health.maximum_health-1.0,"A real accepted physical Player hit records living grievance and actual HP")
	_check(id+":attacked" in hub.tan_dang.progress.state()["response_notices"],"Living grievance has its own finite durable report")
	var before: Dictionary = _bytes()
	_check(not hub.tan_dang.progress.apply("assist",id,id).get("ok",false) and _bytes() == before,"An offended living NPC cannot grant aid or write a rejected claim")
	await _close()
	await _open()
	hub = flow.active_scene as ExteriorHub
	_check(hub.enter_exterior(&"o01_p03"),"Cold fixture returns to the same resident room")
	await _step(4)
	fighter = hub.npc_population.actors[id] as CultivatorActor
	PlayerTravel.relocate(hub.player,fighter.global_position+Vector2(-32,0))
	await _world_time(1.2)
	_check(NpcWorldState.life_id(id) == life_id and fighter.health.current_health == living_hp and hub.npc_population.state.karma(id)["grievance"] == "attacked","Cold entry preserves the same living identity, injury and grievance")
	_check(fighter.combat_phase == "idle" and fighter.committed_strikes == 0,"A previously noticed living offense does not auto-loop pursuit after reload")
	await _close()

func _gratitude_aid() -> void:
	path = prefix+"_aid.json"
	await _open()
	hub = flow.active_scene as ExteriorHub
	var progress: TanDangProgress = hub.tan_dang.progress
	# These existing quest commands are explicit setup for karma, not a second
	# claim of physical quest traversal (covered by tan_dang_flow_test).
	for command: Array in [["accept","ledger"],["observe_lamp","lamp"],["find_lam","refuge"],["inspect_core","refuge"],["q1_reward",""],["choice_rescue","refuge"]]:
		_check(progress.apply(str(command[0]),"",str(command[1])).get("ok",false),"Existing quest owner establishes gratitude setup: "+str(command[0]))
	hub.npc_population.refresh_actors()
	await _step(4)
	var life: NpcWorldState = hub.npc_population.state
	_check(life.karma(TanDangProgress.LAM)["helped"] and life.karma(TanDangProgress.LAM)["gratitude"] == 1 and life.karma(TanDangProgress.DU)["rescued"] and life.karma(TanDangProgress.DU)["gratitude"] == 2,"Canonical helpful/rescue facts expose bounded gratitude independent of contribution spending")
	var linen_before: int = int(flow.profile.material_stash.get(&"linen_fiber",0))
	await _at(StringName(TanDangProgress.LAM))
	await _key(root,KEY_E)
	_check(hub.dialogue.is_open and hub.tan_dang.offered.get(&"td_assist",{}).get("enabled",false),"Actual grateful-NPC dialogue offers the existing aid opportunity")
	await _choose(&"td_assist")
	_check(hub.dialogue.pending_choice==&"td_assist" and int(flow.profile.material_stash.get(&"linen_fiber",0))==linen_before,"Aid waits for actual confirmation before consuming its one chance")
	hub.dialogue.confirm_choice();await _step(4)
	_check(int(flow.profile.material_stash.get(&"linen_fiber",0)) == linen_before+2 and life.karma(TanDangProgress.LAM)["assistance_used"],"Real aid choice commits exactly two linen into the existing warehouse")
	_check(hub.dialogue.pages.any(func(line: String) -> bool: return line.contains("KHO CĂN CỨ")),"Aid dialogue accurately names the warehouse destination")
	await _close_dialogue()
	var before: Dictionary = _bytes()
	_check(not progress.apply("assist",TanDangProgress.LAM,TanDangProgress.LAM).get("ok",false) and _bytes() == before,"A repeated grateful-NPC claim has no new materials or write")
	var harmed: CultivatorActor = hub.npc_population.actors[TanDangProgress.DU] as CultivatorActor
	PlayerTravel.relocate(hub.player,harmed.global_position+Vector2(-32,0))
	await _step(3)
	await _physical_injury(harmed)
	_check(life.karma(TanDangProgress.DU)["rescued"] and life.karma(TanDangProgress.DU)["gratitude"] == 2 and life.karma(TanDangProgress.DU)["grievance"] == "attacked","New harm takes priority while preserving the historical rescue and gratitude")
	await _at(StringName(TanDangProgress.DU))
	await _key(root,KEY_E)
	_check(hub.dialogue.is_open and not hub.tan_dang.offered.has(&"td_assist") and hub.dialogue.pages.any(func(line: String) -> bool: return line.contains("vết thương") or line.contains("bị thương")),"Actual offended dialogue remembers injury and offers no aid despite earlier gratitude")
	await _close_dialogue()
	before = _bytes()
	_check(not progress.apply("assist",TanDangProgress.DU,TanDangProgress.DU).get("ok",false) and _bytes() == before and int(flow.profile.material_stash.get(&"linen_fiber",0)) == linen_before+2,"Direct owner also blocks offended aid without hiding or duplicating the earlier reward")
	await _close()
	await _open()
	hub = flow.active_scene as ExteriorHub
	progress = hub.tan_dang.progress
	life = hub.npc_population.state
	_check(life.karma(TanDangProgress.LAM)["assistance_used"] and int(flow.profile.material_stash.get(&"linen_fiber",0)) == linen_before+2,"Cold restore retains the one-time aid and exact warehouse balance")
	_check(life.karma(TanDangProgress.DU)["rescued"] and life.karma(TanDangProgress.DU)["grievance"] == "attacked" and not life.karma(TanDangProgress.DU)["assistance_used"],"Cold restore keeps gratitude, offense and unclaimed aid as separate facts")
	before = _bytes()
	_check(not progress.apply("assist",TanDangProgress.LAM,TanDangProgress.LAM).get("ok",false) and not progress.apply("assist",TanDangProgress.DU,TanDangProgress.DU).get("ok",false) and _bytes() == before,"Neither used nor offended assistance can be replayed after reload")
	await _close()

func _physical_injury(fighter: CultivatorActor) -> void:
	var probe: Hitbox = ActorCombatRig.hitbox(fighter.get_parent() as Node2D,16)
	var attack := AttackSnapshot.new()
	attack.source_id = hub.player.get_instance_id()
	attack.source_team_id = hub.player.hurtbox.team_id
	attack.attack_id = CombatIds.next_id()
	attack.root_event_id = attack.attack_id
	attack.base_damage = 1.0
	attack.attack_origin = hub.player.global_position
	probe.contact_detected.connect(func(target: Hurtbox, snapshot: AttackSnapshot) -> void:
		if target != fighter.hurtbox: return
		var event := DamageEvent.new()
		event.source_id = snapshot.source_id
		event.source_team_id = snapshot.source_team_id
		event.target_id = target.get_actor_id()
		event.attack_id = snapshot.attack_id
		event.root_event_id = snapshot.root_event_id
		event.hit_window_id = snapshot.hit_window_id
		event.base_damage = snapshot.base_damage
		event.attack_origin = snapshot.attack_origin
		event.physical_damage = true
		event.melee_hit = true
		if target.take_damage(event).actual_damage > 0.0: accepted_probe_injuries += 1
	)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20,48)
	probe.activate(attack,shape,(fighter.get_parent() as Node2D).to_local(fighter.global_position+Vector2(0,-26)))
	await _step(1)
	probe.sample_contacts()
	probe.deactivate()
	probe.queue_free()

func _wait_notice(id: String, reason_code: String, seconds: float) -> void:
	for _index: int in int(ceil(seconds*Engine.physics_ticks_per_second)):
		if id+":"+reason_code in hub.tan_dang.progress.state()["response_notices"]: return
		await physics_frame

func _wait_phase_in_world(fighter: CultivatorActor, phase: String, seconds: float) -> void:
	for _index: int in int(ceil(seconds*Engine.physics_ticks_per_second)):
		if not is_instance_valid(fighter) or fighter.combat_phase == phase: return
		await physics_frame

func _world_time(seconds: float) -> void:
	for _index: int in int(ceil(seconds*Engine.physics_ticks_per_second)): await physics_frame

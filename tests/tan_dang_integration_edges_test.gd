extends "res://tests/tan_dang_flow_test.gd"
## Actual GameFlow, actors, modal and journal. All files live in a fresh QA root.
## Relocation and direct owner setup are fixtures, not traversal/physical-hit proof.
const MOC_EDGE: String = TanDangProgress.MOC
const DU_EDGE: String = TanDangProgress.DU

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/") or DisplayServer.get_name() != "headless":
		print("FAIL: dedicated QA root and headless lane required"); quit(2); return
	prefix = "user://verification/tan_dang_edges_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	await _retaliation_edges()
	await _active_hit_notice()
	await _dead_report_navigation()
	await _narrative_truth()
	for stage: String in ["compound_after_decision","compound_cleanup"]:
		await _uncertain_choice(stage)
	await _quarantined_ledger()
	print("RESULT tan_dang_integration_edges checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

func _edge_open(label: String) -> void:
	path = prefix+"_"+label+".json"
	await _open()
	hub = flow.active_scene as ExteriorHub
	hub.tan_dang.set_process(false)
	hub.player.health.minimum_health = 1.0
	_check(hub.tan_dang.progress.available(),label+": real GameFlow owns writable profile/NPC pair")

func _edge_move(x: float) -> void:
	PlayerTravel.relocate(hub.player,Vector2(x,640))
	hub.door_latched = false
	await _step(4)
	_check(hub._can_travel() and hub.player.motor.is_grounded(),"Fixture player is grounded with controls at x%d" % int(x))

func _notice_count(id: String, reason_code: String) -> int:
	return hub.tan_dang.progress.state()["response_notices"].count(id+":"+reason_code)

func _murder(id: String) -> void:
	var owner: NpcWorldState = hub.npc_population.state
	_check(owner.receive_hit(id,1.0,0.0),"Owner accepts explicit fixture injury: "+id)
	# Public-cause setup for AI eligibility only; timed report delivery has its own suite.
	var witnesses: Array[String]=[]
	for other: String in TanDangProgress.NPC_IDS:
		if other!=id and owner.records[other]["mode"] not in ["dead","downed","recovering"] and owner.records[other]["room"]==owner.records[id]["room"]:witnesses.append(other)
	_check(owner.decide(id,owner.decision_token(id),true,true,witnesses),"Owner durably records confirmed murder: "+id)
	for witness: String in witnesses:
		if owner.report_cause(id,"player_murder",witness,owner.records[witness]["room"]):break
	hub.npc_population.refresh_actors()

func _retaliation_edges() -> void:
	await _edge_open("retaliation")
	# Declared Hub witness fixture, not offscreen knowledge or traversal.
	hub.npc_population.state.records[DU_EDGE]["room"]=String(ExteriorRouteCatalog.HUB)
	_check(hub.npc_population.state.save(),"Fixture places DU in the same Hub before the witnessed offense")
	_murder(DU_EDGE)
	# The living Mộc route now reaches x1030; pick a point just beyond its
	# authored lower boundary while still inside the journey's 145px vicinity.
	var outside_x: float = TanDangLivingCatalog.bounds(MOC_EDGE,String(ExteriorRouteCatalog.HUB)).x-50.0
	await _edge_move(outside_x)
	var actor: CultivatorActor = hub.npc_population.actors[MOC_EDGE] as CultivatorActor
	_check(actor.global_position.distance_to(hub.player.global_position) < 145.0 and not actor.can_request_retaliation("player_murder",DU_EDGE),"Repro is inside journey distance but beyond Mộc's authored leash")
	var revision: int = flow.profile.extension_revision(TanDangProgress.SCOPE)
	hub.tan_dang._process(0.6)
	_check(_notice_count(DU_EDGE,"player_murder") == 0 and flow.profile.extension_revision(TanDangProgress.SCOPE) == revision,"Outside actor leash cannot consume murder response receipt")
	_check(actor.combat_phase == "idle","Ineligible nearby actor has no fictional retaliation")
	await _edge_move(920.0)
	hub.tan_dang._process(0.6)
	_check(_notice_count(DU_EDGE,"player_murder") == 1 and actor.combat_phase != "idle","Eligible existing Mộc actor responds to murdered Dư Hành exactly once")
	var remaining: float = actor.aggro_remaining
	revision = flow.profile.extension_revision(TanDangProgress.SCOPE)
	hub.tan_dang._process(0.6)
	_check(flow.profile.extension_revision(TanDangProgress.SCOPE) == revision and is_equal_approx(actor.aggro_remaining,remaining),"Repeated journey check neither duplicates notice nor renews response timer")
	await _close()
	await _edge_open("downed")
	await _edge_move(920.0)
	var owner: NpcWorldState = hub.npc_population.state
	_check(owner.receive_hit(MOC_EDGE,1.0,920.0),"Downed responder fixture uses real persistent injury")
	await _step(2)
	revision = flow.profile.extension_revision(TanDangProgress.SCOPE)
	hub.tan_dang._process(0.6)
	_check(owner.records[MOC_EDGE]["mode"] == "downed" and _notice_count(MOC_EDGE,"attacked") == 0 and flow.profile.extension_revision(TanDangProgress.SCOPE) == revision,"Downed NPC cannot consume its future response opportunity")
	await _close()

func _active_hit_notice() -> void:
	await _edge_open("active_hit")
	await _edge_move(920.0)
	var actor: CultivatorActor = hub.npc_population.actors[MOC_EDGE] as CultivatorActor
	var event := DamageEvent.new()
	event.source_id = hub.player.get_instance_id()
	event.target_id = actor.hurtbox.get_actor_id()
	event.source_team_id = 1
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = 1.0
	event.attack_origin = hub.player.global_position
	var accepted: DamageResult = actor.hurtbox.take_damage(event)
	_check(not accepted.blocked and accepted.actual_damage > 0.0 and actor.combat_phase != "idle","Real Hurtbox/resolver accepts Player damage and starts self-defense")
	await _step(8)
	var remaining: float = actor.aggro_remaining
	_check(remaining > 0.0 and remaining < 20.0,"Existing self-defense timer has naturally elapsed before notice check")
	hub.tan_dang._process(0.6)
	_check(_notice_count(MOC_EDGE,"attacked") == 1,"Already active self-defense can record the same owner's one notice")
	_check(is_equal_approx(actor.aggro_remaining,remaining),"Recording active response does not refresh the twenty-second timer")
	_check(hub.npc_population.state.karma(MOC_EDGE)["grievance"] == "attacked","Response bookkeeping preserves persistent grievance")
	await _close()

func _seed_q1() -> void:
	var progress: TanDangProgress = hub.tan_dang.progress
	for request: Array in [["accept","ledger"],["observe_lamp","lamp"],["find_lam","refuge"],["inspect_core","refuge"],["q1_reward","refuge"]]:
		_check(progress.apply(request[0],"",request[1]).get("ok",false),"Durable prerequisite fixture: "+request[0])

func _dead_report_navigation() -> void:
	await _edge_open("navigation")
	_seed_q1()
	_check(hub.tan_dang.progress.apply("choice_rescue","","refuge").get("ok",false),"Rescue fixture moves living Lâm home through compound owner")
	_murder(MOC_EDGE)
	var target: Dictionary = hub.tan_dang.navigation_target(&"tan_dang_q3")
	_check(target["room"] == ExteriorRouteCatalog.HUB and is_equal_approx(target["point"].x,TanDangJourney.LEDGER_X),"Dead unreported Mộc routes to ledger870 before living Lâm")
	_check(not hub.tan_dang.progress.apply("report_lam","",TanDangProgress.LAM).get("ok",false),"Living Lâm report cannot bypass missing Mộc ledger report")
	_check(hub.tan_dang.progress.apply("report_moc","","ledger").get("ok",false),"Canonical ledger accepts dead Mộc's pending report")
	target = hub.tan_dang.navigation_target(&"tan_dang_q3")
	_check(is_equal_approx(target["point"].x,float(hub.npc_population.state.records[TanDangProgress.LAM]["x"])),"After Mộc report navigator advances to living Lâm")
	await _close()

func _uncertain_choice(stage: String) -> void:
	await _edge_open(stage)
	_seed_q1()
	_check(hub.enter_exterior(&"o01_p03"),"Fault fixture reaches actual P03 interaction")
	await _step(4)
	await _at(TanDangJourney.REFUGE)
	await _key(root,KEY_E)
	await _choose(&"td_choice_gate")
	_check(hub.dialogue.pending_choice == &"td_choice_gate","Fault is armed only after actual irreversible confirmation appears")
	flow.profile._writer.fault_plan = {stage:true}
	hub.dialogue.confirm_choice()
	await _step(3)
	var message: String = "\n".join(hub.dialogue.pages)
	_check(flow.profile.read_only and hub.npc_population.state.read_only and flow.profile.last_commit.get("recovery_required",false),stage+": unresolved durable intent locks both owners")
	_check(message.contains("khôi phục") and (message.contains("có thể") or message.contains("chưa xác định")) and not message.contains("Không nhận thưởng hoặc đổi quyết định"),stage+": actual modal explains uncertainty instead of promising unchanged outcome")
	var before: Dictionary = _bytes()
	_check(not hub.tan_dang.progress.apply("choice_gate","","refuge").get("ok",false) and _bytes() == before,stage+": locked retry cannot write or grant again")
	await _close_dialogue()
	await _close()
	await _open()
	hub = flow.active_scene as ExteriorHub
	hub.tan_dang.set_process(false)
	var progress: TanDangProgress = hub.tan_dang.progress
	_check(progress.available() and progress.state()["choice"] == "gate" and progress.state()["contribution"] == 4 and not progress.alive(DU_EDGE),stage+": cold GameFlow recovers choice, reward and death together")
	_check(progress.state()["rewards"].count("q2") == 1 and not FileAccess.file_exists(path+".decision"),stage+": recovery has one Q2 grant and clears durable intent")
	before = _bytes()
	_check(not progress.apply("choice_gate","","refuge").get("ok",false) and _bytes() == before,stage+": post-recovery replay cannot duplicate grant")
	await _close()

func _speaker_at(speaker: StringName) -> String:
	var journey: TanDangJourney = hub.tan_dang
	var previous_context: StringName = journey.context
	var before: Dictionary = _bytes()
	journey.context = speaker
	var result: String = "\n".join(journey._speaker_lines())
	journey.context = previous_context
	_check(_bytes() == before,"Reading committed narrative is pure: "+String(speaker))
	return result

func _narrative_truth() -> void:
	await _edge_open("narrative_gate")
	_seed_q1()
	_check(hub.tan_dang.progress.apply("choice_gate","","refuge").get("ok",false),"Narrative fixture commits core carried and Du terminal together")
	var spoken: String = _speaker_at(TanDangJourney.REFUGE)
	_check(spoken.contains("thu hồi") and not spoken.contains("Lõi cổ phù ở bên"),"Gate refuge remembers core removal rather than claiming core remains beside Du")
	spoken = _speaker_at(StringName(MOC_EDGE))
	_check(not spoken.contains("Cổng còn sáng") and spoken.contains("lắp"),"Mộc requests installation while carried core leaves lamp weak")
	_check(hub.tan_dang.progress.apply("install_core","","lamp").get("ok",false),"Narrative fixture installs core through canonical receipt")
	spoken = _speaker_at(StringName(MOC_EDGE))
	_check(spoken.contains("Cổng còn sáng"),"Approved lit-gate quote appears only after durable installation")
	await _close()
	await _edge_open("narrative_rescue")
	_seed_q1()
	_check(hub.tan_dang.progress.apply("choice_rescue","","refuge").get("ok",false),"Narrative fixture commits rescue and spent core together")
	spoken = _speaker_at(TanDangJourney.REFUGE)
	_check(spoken.contains("Lõi đã tiêu") and not spoken.contains("Lõi cổ phù ở bên") and hub.tan_dang.progress.state()["core"] == "spent","Rescue refuge accurately records consumed core")
	_murder(DU_EDGE)
	spoken = _speaker_at(TanDangJourney.REFUGE)
	_check(spoken.contains("chết sau") and spoken.contains("Lõi đã tiêu") and hub.tan_dang.progress.state()["choice"] == "rescue" and hub.tan_dang.progress.state()["core"] == "spent","Later death remains distinct from prior rescue and never restores spent core")
	await _close()

func _quarantined_ledger() -> void:
	await _edge_open("quarantine")
	await _close()
	_check(path.begins_with(prefix),"Invalid sidecar injection is confined to fresh QA fixture")
	var file := FileAccess.open(path+".npc_v1.json",FileAccess.WRITE)
	file.store_string('{"npc_schema":999}')
	file.flush()
	file.close()
	await _open()
	hub = flow.active_scene as ExteriorHub
	hub.tan_dang.set_process(false)
	_check(hub.npc_population.state.read_only and hub.npc_population.actors.is_empty(),"Invalid sidecar quarantines actual population instead of spawning defaults")
	await _at(TanDangJourney.LEDGER)
	await _key(root,KEY_E)
	var message: String = "\n".join(hub.dialogue.pages)
	_check(hub.dialogue.is_open and (message.contains("chưa xác minh") or message.contains("chưa xác nhận")),"Quarantined ledger explicitly labels NPC facts unverified")
	_check(not message.contains("Còn sống") and not message.contains("Chưa có oán hận") and not message.contains("Đã chết vĩnh viễn"),"Quarantined defaults never impersonate known life or grievance facts")
	for choice: Dictionary in hub.dialogue.choices:
		if choice["id"] != &"td_later": _check(not choice.get("enabled",true),"Quarantined ledger disables mutation: "+String(choice["id"]))
	await _close_dialogue()
	await _close()

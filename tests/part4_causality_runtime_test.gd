extends "res://tests/tan_dang_karma_flow_test.gd"
## Real GameFlow/UI/resolver, with explicit room/position/downed/defeat fixtures.
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()!="headless":quit(2);return
	prefix="user://verification/part4_runtime_%d_"%Engine.physics_ticks_per_second
	await _no_witness();await _report_interruptions();await _reporter_death();await _zone_interrupt();await _self_report();await _returned_self_report();await _peace_ui()
	await root.get_node("AudioManager").shutdown()
	print("RESULT Part4CausalityRuntime checks=%d failures=%d hz=%d"%[checks,failures,Engine.physics_ticks_per_second]);quit(0 if failures==0 else 1)

func _case(label: String,p03: bool=true) -> void:
	path=prefix+label+".json";await _open();hub=flow.active_scene as ExteriorHub
	hub.player.health.minimum_health=1.0
	hub.feedback.reset_feedback();hub.feedback.enable_global_hitstop(false)
	if p03:_check(hub.enter_exterior(&"o01_p03"),"Declared room fixture uses product transition");await _step(5)

func _execute_du() -> void:
	await _at(StringName(TanDangProgress.DU))
	var life: NpcWorldState=hub.npc_population.state
	_check(life.receive_hit(TanDangProgress.DU,1,1300,true),"Declared downed fixture goes through life owner")
	await _step(3);await _key(root,KEY_E);await _choose(&"pilot_kill_sect")
	_check(hub.dialogue.pending_choice==&"pilot_kill_sect" and life.records[TanDangProgress.DU]["mode"]=="downed","Execution waits for the existing actual confirmation")
	hub.dialogue.confirm_choice();await _step(4);await _close_dialogue()
	_check(life.records[TanDangProgress.DU]["mode"]=="dead" and not hub.npc_population.actors.has(TanDangProgress.DU),"Actual confirmed choice records terminal death and removes only that actor")

func _no_witness() -> void:
	await _case("unseen")
	var lam: CultivatorActor=hub.npc_population.actors[TanDangProgress.LAM] as CultivatorActor
	var du: CultivatorActor=hub.npc_population.actors[TanDangProgress.DU] as CultivatorActor
	var wall:=StaticBody2D.new();wall.collision_layer=1
	var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=Vector2(6,110);shape.shape=rectangle;wall.add_child(shape)
	wall.position=(lam.position+du.position)*0.5+Vector2(0,-55);hub.exterior.add_child(wall);await _step(3)
	await _at(StringName(TanDangProgress.DU))
	_check(hub.npc_population.witnesses_for(TanDangProgress.DU).is_empty(),"Actual world solid blocks eyewitness sight of the execution")
	await _execute_du();await _world_time(4)
	var life: NpcWorldState=hub.npc_population.state
	_check(life.records[TanDangProgress.DU]["causality"]["witnesses"]["player_murder"].is_empty() and life.records[TanDangProgress.DU]["causality"]["reports"].is_empty(),"Unseen death creates neither witness nor public report")
	_check(lam.combat_phase=="idle" and hub.tan_dang.progress.state()["response_notices"].is_empty(),"Uninformed local NPC cannot begin an institutional hunt")
	_check(hub.return_to_hub(),"Ordinary return leaves remote knowledge private");await _step(4);await _at(StringName(TanDangProgress.MOC));await _world_time(1)
	_check((hub.npc_population.actors[TanDangProgress.MOC] as CultivatorActor).combat_phase=="idle","Offscreen MOC does not learn an unwitnessed murder")
	await _close();await _open();hub=flow.active_scene as ExteriorHub
	_check(not hub.tan_dang.progress.alive(TanDangProgress.DU) and hub.npc_population.state.records[TanDangProgress.DU]["causality"]["reports"].is_empty(),"Cold load preserves terminal private fact without inventing reports")
	await _close()

func _report_interruptions() -> void:
	await _case("witness")
	await _execute_du()
	var life: NpcWorldState=hub.npc_population.state
	_check(life.records[TanDangProgress.DU]["causality"]["witnesses"]["player_murder"]==[TanDangProgress.LAM],"Confirmation samples the real visible living witness, not global records")
	await _world_time(1)
	_check(not hub.tan_dang.reporting.is_empty() and life.records[TanDangProgress.DU]["causality"]["reports"].is_empty(),"Reporting has a real incomplete three-second interval")
	var lam: CultivatorActor=hub.npc_population.actors[TanDangProgress.LAM] as CultivatorActor
	# With the living route, a left-origin hit sends Lâm to x1500, outside
	# the x1320 report's 160px radius. Approach from the right so his real
	# retreat ends at x1310 and the intended calm/local reporting interval fits.
	PlayerTravel.relocate(hub.player,lam.global_position+Vector2(32,0));await _step(2);await _physical_injury(lam);await _step(3)
	_check(hub.tan_dang.reporting.is_empty() and life.records[TanDangProgress.DU]["causality"]["reports"].is_empty() and lam.aggro_remaining>0,"A real accepted hit interrupts reporting and starts separate self-defense")
	await _wait_phase_in_world(lam,"idle",24);await _world_time(3.5)
	_check(TanDangCausality.public_in(life.records[TanDangProgress.DU],"player_murder","o01_p03"),"Surviving witness completes local report only after returning to calm")
	_check(lam.is_responding_to(TanDangProgress.DU) and lam.aggro_remaining<=20,"Public case can trigger exactly one reasoned local response on the existing actor")
	var own_karma: Dictionary=life.karma(TanDangProgress.LAM).duplicate()
	await _wait_phase_in_world(lam,"idle",24);var attacks: int=lam.committed_strikes;await _world_time(4)
	_check(lam.combat_phase=="idle" and lam.committed_strikes==attacks and hub.tan_dang.progress.state()["response_notices"].count(TanDangProgress.DU+":player_murder")==1,"Reporting and process ticks cannot restart pursuit indefinitely")
	_check(life.karma(TanDangProgress.LAM)==own_karma,"Institutional response does not copy the victim's murder onto the witness")
	_check(hub.return_to_hub(),"Actual transition ends local pursuit");await _step(4);await _at(StringName(TanDangProgress.MOC));await _world_time(1)
	_check(not TanDangCausality.knows(life.records,TanDangProgress.DU,"player_murder",TanDangProgress.MOC) and (hub.npc_population.actors[TanDangProgress.MOC] as CultivatorActor).combat_phase=="idle","A P03 report is not telepathy to the keeper at Hub")
	_check(get_nodes_in_group(&"npc_pilot_actor").size()==1,"No hunter, duplicate resident or cross-map pursuer is spawned")
	await _close()

func _reporter_death() -> void:
	await _case("dead_reporter");await _execute_du();await _world_time(1)
	var life: NpcWorldState=hub.npc_population.state
	_check(life.receive_hit(TanDangProgress.LAM,1,1300,true),"Declared interrupt downs the sole living witness")
	await _step(3);await _at(StringName(TanDangProgress.LAM));await _key(root,KEY_E);await _choose(&"pilot_kill_sect");hub.dialogue.confirm_choice();await _step(4);await _close_dialogue();await _world_time(4)
	_check(life.records[TanDangProgress.DU]["causality"]["reports"].is_empty() and life.records[TanDangProgress.LAM]["mode"]=="dead","Killed reporter cannot finish pending testimony as a ghost")
	await _close()

func _zone_interrupt() -> void:
	await _case("leave_report");await _execute_du();await _world_time(1)
	_check(hub.return_to_hub(),"Ordinary door interrupts the visible report before completion");await _world_time(4)
	_check(hub.npc_population.state.records[TanDangProgress.DU]["causality"]["reports"].is_empty() and hub.tan_dang.reporting.is_empty(),"No offscreen timer finishes report or moves an NPC across maps")
	await _close();await _open();hub=flow.active_scene as ExteriorHub
	_check(hub.enter_exterior(&"o01_p03"),"Cold return sees the same surviving witness");await _step(4);await _world_time(1)
	_check(hub.npc_population.state.records[TanDangProgress.DU]["causality"]["reports"].is_empty(),"Cold return starts report from zero rather than completing old partial time")
	await _world_time(2.5)
	_check(TanDangCausality.public_in(hub.npc_population.state.records[TanDangProgress.DU],"player_murder","o01_p03"),"Witness may report once after a full new uninterrupted interval")
	await _close()

func _self_report() -> void:
	await _case("self_report",false)
	var moc: CultivatorActor=hub.npc_population.actors[TanDangProgress.MOC] as CultivatorActor
	PlayerTravel.relocate(hub.player,moc.global_position+Vector2(32,0));await _step(3);await _physical_injury(moc)
	PlayerTravel.relocate(hub.player,Vector2(1500,640));await _world_time(1)
	_check(moc.combat_phase=="idle" and not hub.tan_dang.reporting.is_empty(),"Living victim can stop short aggro at its leash and report for itself")
	await _world_time(3)
	var reports: Array=hub.npc_population.state.records[TanDangProgress.MOC]["causality"]["reports"]
	_check(reports.size()==1 and reports[0]["reporter"]==TanDangProgress.MOC and reports[0]["room"]==String(ExteriorRouteCatalog.HUB),"Self-report cites the actual surviving victim and local ledger")
	await _close()

func _peace_ui() -> void:
	await _case("peace",false)
	for command: Array in [["accept","ledger"],["observe_lamp","lamp"],["find_lam","refuge"],["inspect_core","refuge"],["q1_reward",""],["choice_rescue","refuge"],["report_moc",TanDangProgress.MOC],["report_lam",TanDangProgress.LAM],["q3_reward",""]]:
		_check(hub.tan_dang.progress.apply(command[0],"",command[1]).get("ok",false),"Declared completed-rescue setup through existing owner: "+command[0])
	await _close();await _open();hub=flow.active_scene as ExteriorHub
	var life: NpcWorldState=hub.npc_population.state
	_check(life.karma(TanDangProgress.DU)["rescued"] and not life.karma(TanDangProgress.DU)["assistance_used"],"Rescue memory and unclaimed help survive save/load before the next meeting")
	await _at(StringName(TanDangProgress.DU));await _key(root,KEY_E);var before: Dictionary=_bytes();await _choose(&"td_assist")
	_check(hub.dialogue.pending_choice==&"td_assist" and _bytes()==before,"One-time aid is reviewable before confirmation")
	hub.dialogue.cancel_confirmation();_check(_bytes()==before,"Cancel keeps the aid opportunity unused")
	await _choose(&"td_assist");hub.dialogue.confirm_choice();await _step(4);await _close_dialogue()
	var bank: Dictionary=flow.profile.material_stash.duplicate();var fighter: CultivatorActor=hub.npc_population.actors[TanDangProgress.DU] as CultivatorActor
	_check(life.karma(TanDangProgress.DU)["assistance_used"] and bank[&"linen_fiber"]==2,"Next actual meeting grants the existing two linen exactly once")
	await _physical_injury(fighter)
	_check(life.receive_hit(TanDangProgress.DU,1,1300,true),"Declared downed setup follows the actual player injury")
	await _step(3);await _at(StringName(TanDangProgress.DU));await _key(root,KEY_E);await _choose(&"pilot_spare");await _close_dialogue()
	_check(life.records[TanDangProgress.DU]["mode"]=="recovering" and not hub.tan_dang.progress.can_reconcile(TanDangProgress.DU),"Mercy alone cannot immediately buy forgiveness")
	flow.start_run();await _step(8)
	_check(flow.active_scene is DungeonRun,"Actual departure transfers the existing life owner across an expedition")
	(flow.active_scene as DungeonRun).player.health.apply_damage(9999) # Declared defeat fixture, no forged outcome.
	for _i: int in 600:
		if flow.active_scene is ExteriorHub:break
		await physics_frame
	hub=flow.active_scene as ExteriorHub;life=hub.npc_population.state
	_check(life.records[TanDangProgress.DU]["mode"] not in ["dead","downed","recovering"] and hub.tan_dang.progress.can_reconcile(TanDangProgress.DU),"Real committed expedition return enables the spared resident's conditional peace")
	await _at(StringName(TanDangProgress.DU));await _key(root,KEY_E);before=_bytes();await _choose(&"td_reconcile")
	_check(hub.dialogue.pending_choice==&"td_reconcile" and _bytes()==before,"Reconciliation uses the actual confirmation modal without provisional forgiveness")
	hub.dialogue.cancel_confirmation();_check(_bytes()==before,"Cancelled peace preserves grievance and both durable files")
	await _choose(&"td_reconcile");hub.dialogue.confirm_choice();await _step(4);await _close_dialogue()
	fighter=hub.npc_population.actors[TanDangProgress.DU] as CultivatorActor
	_check(life.records[TanDangProgress.DU]["causality"]["reconciled"] and fighter.combat_phase=="idle" and fighter.aggro_remaining==0 and flow.profile.material_stash==bank,"Committed limited peace stops actual aggression but cannot refresh aid")
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	await _key(root,KEY_M);screen.journal.relations_button.pressed.emit();await _step(3)
	_check(screen.journal.selected_id==&"tan_dang_relations" and screen.journal.objective_label.visible and "Đã xác nhận đình chiến" in screen.journal.objective_label.text and "tiêu lõi cứu" in screen.journal.objective_label.text and "bạn đã tha" in screen.journal.objective_label.text,"Actual M relationship journal explains rescue, mercy and limited peace")
	screen.close();await _physical_injury(fighter);await _step(3)
	_check(life.karma(TanDangProgress.DU)["grievance"]=="attacked" and not hub.tan_dang.progress.can_reconcile(TanDangProgress.DU) and life.records[TanDangProgress.DU]["causality"]["peace_used"],"A new real hit breaks peace without renewing the one reconciliation chance")
	await _close();await _open();hub=flow.active_scene as ExteriorHub
	_check(hub.npc_population.state.karma(TanDangProgress.DU)["assistance_used"] and hub.npc_population.state.records[TanDangProgress.DU]["causality"]["peace_used"] and flow.profile.material_stash==bank,"Cold load retains used assistance and exhausted peace without farmable rewards")
	await _close()

func _returned_self_report() -> void:
	await _case("returned_self",false)
	for command: Array in [["accept","ledger"],["observe_lamp","lamp"],["find_lam","refuge"],["inspect_core","refuge"],["q1_reward",""],["choice_rescue","refuge"]]:
		_check(hub.tan_dang.progress.apply(command[0],"",command[1]).get("ok",false),"Declared return setup: "+command[0])
	hub.npc_population.refresh_actors();await _step(4)
	var du: CultivatorActor=hub.npc_population.actors[TanDangProgress.DU] as CultivatorActor
	# The returned victim now really flees: approach from the left so he
	# retreats to x1400 beside his x1385 testimony anchor, rather than x1040.
	# No actor position, witness fact, calm state or report clock is forged.
	PlayerTravel.relocate(hub.player,du.global_position+Vector2(-32,0));await _step(3);await _physical_injury(du)
	PlayerTravel.relocate(hub.player,Vector2(1650,640));await _world_time(1)
	_check(du.combat_phase=="idle" and hub.tan_dang.reporting.get("reporter","")==TanDangProgress.DU,"Returned victim reports personally from its existing courtyard rest anchor after retreat")
	await _world_time(3.3)
	var reports: Array=hub.npc_population.state.records[TanDangProgress.DU]["causality"]["reports"]
	_check(reports.size()==1 and reports[0]["reporter"]==TanDangProgress.DU and reports[0]["room"]==String(ExteriorRouteCatalog.HUB),"Returned rescued victim can publish its own local testimony without teleporting to a ledger")
	await _close()

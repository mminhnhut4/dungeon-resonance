extends SceneTree
## Focused real-scene adapters; manual scaled pulses test 60/120 Hz equivalence.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
var checks: int = 0
var failures: int = 0
var hz: int = 60
var flow: GameFlow

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks+=1
	if not condition: failures+=1; print("FAIL: "+label)
	else: print("PASS: "+label)

func _step(count: int) -> void:
	for _index: int in count: await physics_frame

func _key(code: Key) -> void:
	var event := InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=true
	Input.parse_input_event(event); await _step(2)
	event=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=false
	Input.parse_input_event(event); await _step(2)

func _pulse(session: Node, seconds: int) -> void:
	for _index: int in seconds*hz: session._physics_process(1.0/float(hz))

func _abort_fixture() -> void:
	flow.queue_free(); await _step(3)
	print("RESULT OpeningCultivationGameplay hz=%d checks=%d failures=%d" % [hz,checks,failures])
	quit(1)

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz=int(argument.trim_prefix("--hz="))
	Engine.physics_ticks_per_second=hz
	var fixture_path: String = "user://verification/opening_gameplay_%d_%d_%d/profile.json" % [OS.get_process_id(),Time.get_ticks_usec(),hz]
	var fixture := SanctuaryProfile.new(); fixture.save_path=fixture_path
	fixture.souls=25; fixture.material_stash[&"crystal"]=20; fixture.material_stash[&"dust"]=20
	fixture.material_stash[&"linen_fiber"]=6
	_check(fixture.save(),"Isolated legacy resource fixture saved")
	_check(fixture.commit_cultivation(Model.initial_proposal(Model.new_progress(4),fixture.material_stash,fixture.souls,fixture.boss_proofs)),"Seed four commits before either herb becomes visible")
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override=fixture_path; root.add_child(flow); current_scene=flow
	await _step(12)
	var hub: ExteriorHub = flow.active_scene as ExteriorHub
	var session: Node = flow.cultivation_session
	session.set_physics_process(false)
	_check(hub!=null and session.snapshot()["ready"] and flow.profile.profile_version==2,"Product GameFlow binds persistent cultivation to the existing Hub/player")
	_check(hub.npc_population!=null and FileAccess.file_exists(flow.profile.save_path+".npc_v1.json"),"Actual NPC life owner supplies its durable sidecar")
	_check(session.snapshot()["seed"]==4 and is_instance_valid(session._herb),"No seed reroll on product load; authored courtyard node has a marker")
	var player_id: int = hub.player.get_instance_id()
	hub.player.relocate(Vector2(370,640)); await _step(3)
	_check(hub.nearest_station()==&"aptitude_herb" and hub.interact_station(&"aptitude_herb"),"Existing E interaction harvests the seeded herb through one profile commit")
	_check(flow.profile.material_stash[&"aptitude_herb"]==1 and not is_instance_valid(session._herb) and not session.harvest_near(),"Committed harvest removes marker and cannot repeat")
	var reload := SanctuaryProfile.new(); reload.save_path=fixture_path
	_check(reload.load_profile() and reload.cultivation_progress["seed"]==4 and reload.cultivation_progress["harvested_nodes"].has("h00_courtyard_01"),"Cold profile retains seed, lineage, exhausted node and bank")
	_check(not hub.economy.withdraw(&"aptitude_herb",1),"Lineage-bound aptitude items stay with the common cultivation bank")
	hub.player.relocate(hub.stations[&"training"].global_position); await _step(3)
	hub.open_station(&"training")
	_check(hub.station_open and hub.station_content.find_child("CultivationStartPlayer",true,false)!=null,"Existing training station contains the explicit cultivation panel")
	_check(not session.perform("train",{"actor_id":"player","sessions":8,"target_tick":1000}).get("ok",false),"UI cannot invent elapsed pulses or inject raw training commands")
	_check(session.perform("craft_pill",{"origin_id":"h00_courtyard_01"}).get("ok",false),"Crafting commits dust and herb-to-pill lineage together")
	_check(session.perform("consume",{"actor_id":"player","origin_id":"h00_courtyard_01"}).get("ok",false),"Player explicitly consumes one pill from the shared bank")
	_check(flow.profile.cultivation_progress["actors"]["player"]["aptitude"]==8 and flow.profile.material_stash[&"aptitude_pill"]==0,"One lineage grants eight aptitude once")
	_check(not session.perform("consume",{"actor_id":"player","origin_id":"h00_courtyard_01"}).get("ok",false),"Second consumption cannot claim the same aptitude")
	(hub.station_content.find_child("CultivationStartPlayer",true,false) as Button).pressed.emit()
	_check(not hub.station_open and hub.player.controls_enabled and session.training_actor=="player","Training button releases modal/time claim before beginning gameplay pulses")
	var before: int = flow.profile.material_stash[&"crystal"]
	paused=true; session._physics_process(600.0); paused=false
	_check(flow.profile.material_stash[&"crystal"]==before and session.observed_pulses==0,"Pause grants no offline/catch-up training")
	hub.player.controls_enabled=false; session._physics_process(600.0); hub.player.controls_enabled=true
	_check(flow.profile.material_stash[&"crystal"]==before,"Disabled controls grant no elapsed training")
	hub.player.health.current_health=0.0; session._physics_process(600.0); hub.player.health.reset_health()
	_check(flow.profile.material_stash[&"crystal"]==before,"A dead player cannot advance cultivation")
	var freeze_event := DamageEvent.new(); freeze_event.attack_id=90001; freeze_event.root_event_id=90001; freeze_event.melee_hit=true
	var freeze_result := DamageResult.new(); freeze_result.actual_damage=1.0
	hub.feedback.on_hit_confirmed(freeze_event,freeze_result)
	_check(hub.feedback.is_frozen(),"Actual feedback owner activates hitstop in both local and global backends")
	session._physics_process(600.0); hub.feedback.reset_feedback()
	_check(flow.profile.material_stash[&"crystal"]==before,"Combat hitstop freezes training even with a large supplied delta")
	hub.open_station(&"training"); session._physics_process(600.0); hub.close_station()
	_check(flow.profile.material_stash[&"crystal"]==before,"Station modal contributes no gameplay pulses")
	flow.return_save_pending=true; session._physics_process(600.0); flow.return_save_pending=false
	_check(flow.profile.material_stash[&"crystal"]==before,"Pending shared return/reward save freezes training")
	_pulse(session,2)
	_check(flow.profile.material_stash[&"crystal"]==before-1 and flow.profile.cultivation_progress["actors"]["player"]["trained_ticks"]==8,"Exactly two eligible seconds debit one crystal at the requested physics rate")
	session._physics_process(1000.0)
	_check(flow.profile.material_stash[&"crystal"]==before-2 and flow.profile.cultivation_progress["actors"]["player"]["trained_ticks"]==16,"A stalled frame grants at most the bounded eight pulses")
	session.stop_training()
	var progress_before: Dictionary = flow.profile.cultivation_progress.duplicate(true)
	var fake_event := DamageEvent.new(); fake_event.source_id=player_id; fake_event.target_id=hub.dummy.get_instance_id(); fake_event.attack_id=99999; fake_event.root_event_id=99999; fake_event.melee_hit=true
	var denied := DamageResult.new(); denied.blocked=true; denied.actual_damage=100.0
	hub.player.equipped_weapon.hit_confirmed.emit(fake_event,denied)
	denied.blocked=false; denied.actual_damage=0.0; hub.player.equipped_weapon.hit_confirmed.emit(fake_event,denied)
	denied.actual_damage=5.0; fake_event.source_kind=DamageEvent.SourceKind.DOT; hub.player.equipped_weapon.hit_confirmed.emit(fake_event,denied)
	_check(flow.profile.cultivation_progress==progress_before,"Blocked, zero-damage and DOT results grant no mastery")
	var neutral := NpcPilotActor.new()
	fake_event.source_kind=DamageEvent.SourceKind.DIRECT; fake_event.target_id=neutral.get_instance_id()
	hub.player.equipped_weapon.hit_confirmed.emit(fake_event,denied)
	_check(flow.profile.cultivation_progress==progress_before,"Harming a neutral resident grants no cultivation mastery reward")
	neutral.free()
	hub.feedback.reset_feedback(); hub.feedback.hit_stop_seconds=0.01
	hub.player.relocate(Vector2(575,640)); await _step(5)
	# parse_input_event receives window coordinates, including headless stretch.
	var mouse := InputEventMouseMotion.new(); mouse.position=hub.player.get_viewport().get_final_transform()*hub.player.get_canvas_transform()*(hub.dummy.global_position+Vector2(0,-16)); Input.parse_input_event(mouse)
	var initial_hits: int = hub.dummy.hit_count
	# Inputs can arrive in recovery at either rate. Wait for observed resolved
	# practice hits, with a fixed attempt budget; never inject mastery into saves.
	var practice_attempts: int = 0
	while practice_attempts<16 and (hub.dummy.hit_count<initial_hits+8 or int(flow.profile.cultivation_progress["actors"]["player"]["mastery"])<8):
		practice_attempts+=1
		mouse=InputEventMouseMotion.new(); mouse.position=hub.player.get_viewport().get_final_transform()*hub.player.get_canvas_transform()*(hub.dummy.global_position+Vector2(0,-16)); Input.parse_input_event(mouse)
		await _key(KEY_J); await _step(int(float(hz)*0.75))
	var practice_complete: bool = hub.dummy.hit_count>=initial_hits+8 and int(flow.profile.cultivation_progress["actors"]["player"]["mastery"])>=8
	_check(practice_complete,"Actual input/hitbox/resolver hits grant mastery despite feedback listener hitstop")
	if not practice_complete:
		print("PRACTICE_DIAGNOSTIC ",{"attempts":practice_attempts,"resolved_hits":hub.dummy.hit_count-initial_hits,"mastery":flow.profile.cultivation_progress["actors"]["player"]["mastery"],"target":hub.player.aim.target_position,"aim":hub.player.aim.global_position,"action":hub.player.action_state_machine.get_state_id()})
		await _abort_fixture(); return
	var last_event: DamageEvent = hub.dummy.last_damage_event
	var repeat_result := DamageResult.new(); repeat_result.actual_damage=1.0
	var mastery: int = flow.profile.cultivation_progress["actors"]["player"]["mastery"]
	hub.player.equipped_weapon.hit_confirmed.emit(last_event,repeat_result)
	_check(flow.profile.cultivation_progress["actors"]["player"]["mastery"]==mastery,"Same attack/root cannot grant mastery for a second contact")
	_check(flow.profile.record_opening_event(&"explored") and flow.profile.record_opening_event(&"thanh_vy_met") and flow.profile.record_boss_defeat("opening_qa_golem"),"Existing opening/boss owners feed their three committed observations")
	_check(flow.profile.cultivation_progress["actors"]["player"]["insight_ids"].size()==3,"Cultivation derives all three insights without adding OpeningProgress IDs")
	hub.player.relocate(hub.stations[&"training"].global_position); hub.feedback.reset_feedback(); await _step(3)
	_check(session.start_training("player"),"Player can explicitly begin another training interval")
	_pulse(session,6); session.stop_training()
	_check(flow.profile.cultivation_progress["actors"]["player"]["energy"]>=40 and flow.profile.cultivation_progress["actors"]["player"]["stage"]==0,"Energy/mastery/insights never silently cause a breakthrough")
	hub.open_station(&"training")
	var old_button: Button = hub.station_content.find_child("CultivationBreakthrough_player",true,false) as Button
	var nested_success: Array[bool] = [false]
	var reentrant: Callable = func() -> void:
		if session._busy: nested_success[0]=session.perform("breakthrough",{"actor_id":"player"}).get("ok",false)
	session.ui_changed.connect(reentrant)
	old_button.pressed.emit(); old_button.pressed.emit()
	session.ui_changed.disconnect(reentrant)
	_check(flow.profile.cultivation_progress["actors"]["player"]["stage"]==1 and not nested_success[0],"One quoted button and nested publication can commit only one breakthrough")
	for stage: int in range(1,3):
		var args: Dictionary = {"actor_id":"player"}
		if stage==2:
			var before_branch: PackedByteArray = FileAccess.get_file_as_bytes(flow.profile.save_path)
			_check(not session.perform("breakthrough",args).get("ok",false) and flow.profile.cultivation_abilities()["learned_ids"].is_empty(),"First realm breakthrough requires one explicit technique choice")
			args["branch_id"]="tether_sigil"; flow.profile._writer.fault_plan={"write_candidate":true}
			_check(not session.perform("breakthrough",args).get("ok",false) and flow.profile.cultivation_abilities()["learned_ids"].is_empty() and FileAccess.get_file_as_bytes(flow.profile.save_path)==before_branch,"Realm/technique IO failure preserves Soul cost and locked abilities in one old image")
		_check(session.perform("breakthrough",args).get("ok",false) and flow.profile.cultivation_progress["actors"]["player"]["stage"]==stage+1,"Explicit breakthrough stage %d commits its own gates/cost" % (stage+1))
	_check(flow.profile.souls==20 and flow.profile.boss_proofs[&"golem"]==1,"Final breakthrough spends five Souls and retains the real proof")
	_check(flow.profile.cultivation_abilities()["learned_ids"]==["tether_sigil"] and session.style_binding.runtime.learned==[&"tether_sigil"] and session.style_binding.runtime.selected==&"tether_sigil","Committed realm installs exactly the selected branch on the existing player")
	hub.close_station()
	hub.player.energy.reset(); hub.feedback.reset_feedback(); await _step(5)
	var before_skill_energy: float = hub.player.energy.current
	var style: Node = session.style_binding.runtime
	mouse=InputEventMouseMotion.new(); mouse.position=hub.player.get_viewport().get_final_transform()*hub.player.get_canvas_transform()*(hub.player.aim.global_position+Vector2(100,-20)); Input.parse_input_event(mouse)
	await _key(KEY_G); await _step(int(float(hz)/2.0))
	_check(is_instance_valid(style.mark) and style.selected==&"tether_sigil" and hub.player.energy.current<before_skill_energy,"Actual G input performs the newly learned mark action with existing combat energy")
	var skill_energy: float = hub.player.energy.current
	var skill_cooldown: float = style.cooldowns[&"tether_sigil"]
	_check(PlayerTravel.relocate(hub.player,hub.stations[&"training"].global_position) and not is_instance_valid(style.mark) and is_equal_approx(hub.player.energy.current,skill_energy) and is_equal_approx(style.cooldowns[&"tether_sigil"],skill_cooldown),"Travel cancels transient mark while preserving current combat cost/cooldown")
	await _step(int(ceil(style.cooldowns[&"tether_sigil"]*float(hz)))+4)
	hub.player.energy.reset(); hub.feedback.reset_feedback()
	var modal: InventoryScreen = hub.gear.modal as InventoryScreen
	var guarded_ledger: Dictionary = GearInventoryCodec.encode(hub.gear.inventory)
	var guarded_energy: float = hub.player.energy.current
	await _key(KEY_M)
	_check(modal.is_open and modal.tabs.current_tab==2 and style.cooldowns[&"tether_sigil"]<=0.0,"Map opens while the actual learned G technique is ready")
	await _key(KEY_G); await _key(KEY_F); await _key(KEY_BACKSPACE)
	_check(not is_instance_valid(style.mark) and is_equal_approx(hub.player.energy.current,guarded_energy) and GearInventoryCodec.encode(hub.gear.inventory)==guarded_ledger,"Map consumes G and rune shortcuts without technique cost or exact loadout changes")
	await _key(KEY_ESCAPE)
	_check(not modal.is_open and hub.player.controls_enabled and is_equal_approx(Engine.time_scale,1.0),"Map releases its one control/time owner before gameplay resumes")
	await _key(KEY_G); await _step(int(float(hz)/2.0))
	_check(is_instance_valid(style.mark) and hub.player.energy.current<guarded_energy,"The same learned G technique executes after closing Map")
	PlayerTravel.relocate(hub.player,hub.stations[&"training"].global_position)
	var life_state: NpcWorldState = hub.npc_population.state
	life_state.records["pilot_gatherer"]["mode"]="rest"; life_state.records["pilot_gatherer"]["remaining"]=32
	_check(life_state.save(),"Only the actual life owner checkpoints the isolated exemplar rest")
	hub.open_station(&"training")
	_check(session.perform("enroll",{"enabled":true}).get("ok",false),"One real stable NPC opts into bounded shared-bank sponsorship")
	if not flow.profile.cultivation_progress["actors"].has("pilot_gatherer"):
		await _abort_fixture(); return
	hub.close_station(); _check(session.start_training("pilot_gatherer"),"Alive actual NPC can start its sponsored clock")
	var life_bytes: PackedByteArray = FileAccess.get_file_as_bytes(life_state.save_path)
	_pulse(session,2); session.stop_training()
	_check(flow.profile.cultivation_progress["actors"]["pilot_gatherer"]["energy"]==8 and FileAccess.get_file_as_bytes(life_state.save_path)==life_bytes,"NPC training commits progress/resources without writing a life copy")
	_check(session.start_training("pilot_gatherer"),"A second sponsored interval begins explicitly")
	for _pulse_index: int in 7: session._physics_process(0.25)
	life_state.records["pilot_gatherer"]["mode"]="talk"; hub.open_station(&"training")
	session._physics_process(0.25)
	life_state.records["pilot_gatherer"]["mode"]="rest"; hub.close_station()
	session._physics_process(0.25); session.stop_training()
	_check(flow.profile.cultivation_progress["actors"]["pilot_gatherer"]["energy"]==8,"Talk during a modal discards seven partial NPC pulses before returning to rest")
	life_state.records["pilot_gatherer"]["hp"]=1.0; life_state.records["pilot_gatherer"]["mode"]="downed"; life_state.records["pilot_gatherer"]["episode"]=1
	_check(not session.start_training("pilot_gatherer"),"Unsaved downed live NPC blocks training despite alive primary")
	life_state.records["pilot_gatherer"]["mode"]="recovering"; life_state.records["pilot_gatherer"]["hp"]=1.0
	life_state.records["pilot_gatherer"]["remaining"]=0
	_check(life_state.save() and not session.start_training("pilot_gatherer"),"Withdrawn NPC never advances or heals through cultivation")
	var persisted := SanctuaryProfile.new(); persisted.save_path=fixture_path
	_check(persisted.load_profile() and persisted.cultivation_progress["actors"]["player"]["stage"]==3 and persisted.cultivation_progress["actors"]["pilot_gatherer"]["energy"]==8,"Cold common profile retains completed player and one NPC example")
	_check(hub.player.get_instance_id()==player_id,"Opening loop reuses the existing player and world architecture")
	flow.queue_free(); await _step(3)
	_check(is_equal_approx(Engine.time_scale,1.0),"Scene teardown releases all owned time claims")
	print("RESULT OpeningCultivationGameplay hz=%d checks=%d failures=%d" % [hz,checks,failures])
	quit(0 if failures==0 else 1)

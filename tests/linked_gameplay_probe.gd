extends "res://tests/newcomer_route_probe.gd"
## Continuation of item2's actually played save. No grants/state/RNG/warp fixtures.
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
var hub: ExteriorHub
var snapshots: Array[Dictionary]=[]
var rear_contacts: Array[Dictionary]=[]
var dungeon_links: int=0
var initial_wallets: Vector2i
var before_payload: Dictionary={}
var after_payload: Dictionary={}

func realm() -> int:return int(flow.profile.cultivation_progress["actors"]["player"]["stage"])
func snapshot(label: String) -> void:
	var world: PrologueHub=flow.active_scene as PrologueHub
	var inventory: GearInventory=world.gear.inventory if world!=null else (flow.active_scene as DungeonRun).gear.inventory
	snapshots.append({"label":label,"stage":realm(),"progress":flow.profile.cultivation_progress.duplicate(true),"coins":flow.profile.coins,"souls":flow.profile.souls,"stash":flow.profile.material_stash.duplicate(),"inventory":GearInventoryCodec.encode(inventory)})

func choose_pair(ids: Array[StringName],label: String) -> bool:
	_stage(label);await _key(KEY_TAB);await pause(.7)
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen;var bar: TabBar=screen.tabs.get_tab_bar()
	await _mouse(bar.get_global_transform()*bar.get_tab_rect(1).get_center());await pause(.5)
	for i: int in ids.size():
		await _click(screen.slots[GearInventory.CATALYST_INDICES[i]])
		var index: int=-1
		for j: int in GearInventory.RUNES.size():
			if GearInventory.RUNES[j].id==ids[i]:index=j
		if not _check(index>=0 and hub.gear.inventory.bag[ids[i]]>0 or hub.gear.inventory.slots[GearInventory.CATALYST_INDICES[i]]==ids[i],"The requested rune is genuinely owned before the UI equips it"):return false
		if hub.gear.inventory.slots[GearInventory.CATALYST_INDICES[i]]!=ids[i]:await _click(screen.rune_buttons[index])
	await pause(.6)
	if not _check(hub.player.resonance_controller.catalyst_a.runtime_state.installed_rune_ids==ids,"Actual inventory clicks install the full intended Catalyst multiset"):return false
	screen.content_scroll.ensure_control_visible(screen.foundation_hint);await pause(2)
	_check(screen.foundation_hint.text==FoundationLesson.view(hub.player.resonance_controller)["text"],"Recorded rune lesson matches the current gameplay controller")
	await _shot(label);snapshot(label);await _key(KEY_ESCAPE);return true

func open_training() -> bool:
	if not await _walk(hub.player,hub.stations[&"training"].global_position.x):return false
	await _key(KEY_E);await pause(.7)
	return _check(hub.station_open and hub.current_station==&"training","Actual E opens the existing cultivation station")

func rear_hit(event: DamageEvent,result: DamageResult) -> void:
	if result.blocked or result.actual_damage<=0:return
	rear_contacts.append({"phase":phase,"kind":event.source_kind,"root":event.root_event_id,"damage":result.actual_damage,"allow_resonance":event.allow_resonance})

func cast_at_targets(label: String,expected_links: int) -> bool:
	_stage(label)
	if not await _walk(hub.player,540):return false
	await pause(2.2)
	var controller: ResonanceController=hub.player.resonance_controller
	var chain_before: int=hub.executor.chain_hit_count;var front_before: int=hub.dummy.hit_count;var rear_before: int=rear_contacts.size()
	var aim:=InputEventMouseMotion.new();aim.position=hub.player.get_canvas_transform()*hub.dummy.hurtbox.global_position;root.push_input(aim,true);await _step(3)
	var casts: int=controller.cast_count
	await _key(KEY_I)
	for i: int in 55:
		if hub.dummy.hit_count>front_before and (expected_links==0 or hub.executor.chain_hit_count>chain_before):break
		await _step(1)
	_check(controller.cast_count==casts+1 and hub.dummy.hit_count>front_before,"Actual I input commits one composite cast and hits the front ordinary target")
	_check(hub.executor.chain_hit_count==chain_before+expected_links,"Real target delivery adds exactly the expected bounded link")
	if expected_links==0:_check(rear_contacts.size()==rear_before,"Before breakthrough the rear target outside AOE receives no false hit")
	else:_check(rear_contacts.size()==rear_before+1 and rear_contacts.back()["kind"]==DamageEvent.SourceKind.RESONANCE and not rear_contacts.back()["allow_resonance"],"Rear target receives one real nonrecursive resonance hit")
	var readout: Dictionary=FoundationLesson.view(controller)
	var recorded: Dictionary={"stage":realm(),"recipe":String(controller.get_recipe().id),"links_expected":expected_links,"links_actual":hub.executor.chain_hit_count-chain_before,"view_before":readout["before"],"view_after":readout["after"],"uid":hub.gear.inventory.equipped_weapon_uid,"damage_multiplier":controller.quality_damage_multiplier,"cooldown_multiplier":controller.cooldown_multiplier,"mana_cost":ResonanceController.CAST_ENERGY_COST}
	if expected_links==0:before_payload=recorded
	else:after_payload=recorded
	await _shot(label+"_contact");await pause(1.8);snapshot(label);return true

func real_dungeon() -> bool:
	_stage("real_dungeon_departure")
	if not await _walk(hub.player,hub.stations[&"portal"].global_position.x):return false
	await _key(KEY_E);await _step(12)
	if not _check(flow.active_scene is DungeonRun,"Ordinary physical portal starts an unmodified dungeon"):return false
	var run: DungeonRun=flow.active_scene as DungeonRun
	_check(run.player.resonance_controller.foundation_resonance_enabled and run.player.resonance_controller.get_recipe().id==&"firestorm","Actual new dungeon actor binds earned Truc Co and UI-installed pair")
	bot.run=run;bot.enabled=true;_stage("real_enemies_with_earned_link")
	for i: int in 10800:
		if run.outcome!=&"" or (run.living_enemies().is_empty() and not run.room.locked):break
		await _step(1)
	bot.stop();dungeon_links=run.player.resonance_controller.executor.chain_hit_count
	if not _check(run.outcome==&"" and not run.room.locked,"Actual first-floor combat succeeds without HP/damage/state edits"):return false
	_check(dungeon_links>0,"Existing chain consumer delivered actual links during unmodified enemy combat")
	await _shot("actual_combat_cleared");await pause(2)
	if not await _walk(run.player,1240):return false
	await _key(KEY_E);await pause(.6)
	if not _check(run.floor_exit.is_open,"Actual completed-floor E offers the normal return choice"):return false
	await _click(run.floor_exit.return_button);await _step(16)
	hub=flow.active_scene as ExteriorHub
	return _check(hub!=null and realm()==3 and hub.player.resonance_controller.foundation_resonance_enabled,"Normal return preserves earned realm and active recipe")

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or not "--qa-seed-item2" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	_check(FileAccess.get_sha256(profile_path)==OS.get_environment("LINKED_SOURCE_SHA256"),"Starts from exact byte-identical item2 actually earned save")
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30);hub=flow.active_scene as ExteriorHub
	_check(not flow.qa_tools_enabled and realm()==0 and hub.gear.inventory.materials[&"crystal"]==4 and hub.gear.inventory.materials[&"dust"]==3,"Actual carried crystals/dust and stage zero are inherited from item2 gameplay, no resource fixtures")
	initial_wallets=Vector2i(flow.profile.coins,flow.profile.souls)
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	hub.link_dummy.hurtbox.hit_resolved.connect(rear_hit)
	await power_page("earned_save_needs_training")
	if not await choose_pair([&"wind",&"wind"],"invalid_duplicate_recipe"):await finish_game(false);return
	var energy: float=hub.player.energy.current;var casts: int=hub.player.resonance_controller.cast_count
	_stage("invalid_recipe_refuses_cast");await _key(KEY_I);await pause(.8)
	_check(hub.player.resonance_controller.cast_count==casts and hub.player.energy.current==energy,"Wrong exact pair cannot cast or spend mana")
	if not await choose_pair([&"fire",&"wind"],"valid_pair_before_truc_co"):await finish_game(false);return
	if not await cast_at_targets("before_breakthrough_cast",0):await finish_game(false);return
	_stage("train_with_earned_crystals")
	if not await open_training():await finish_game(false);return
	await _click(hub.station_content.find_child("CultivationStartPlayer",true,false) as Button)
	for i: int in 720:
		if int(flow.profile.cultivation_progress["actors"]["player"]["energy"])>=16:break
		await _step(1)
	_check(int(flow.profile.cultivation_progress["actors"]["player"]["energy"])==16 and hub.gear.inventory.materials[&"crystal"]==2,"Two real closed-panel sessions pay exactly two earned crystals for sixteen cumulative energy")
	if not await open_training():await finish_game(false);return
	var stop: Button=hub.station_content.find_child("CultivationStop",true,false) as Button
	if stop!=null:await _click(stop);await pause(.4)
	for stage: int in [1,2]:
		await _click(hub.station_content.find_child("CultivationBreakthrough_player",true,false) as Button);await pause(.5)
		_check(realm()==stage,"Actual existing breakthrough UI advances exactly one gate")
	_stage("earned_final_breakthrough_offer")
	var offer: Button=hub.station_content.find_child("CultivationBranch_tether_sigil",true,false) as Button
	hub.station_scroll.ensure_control_visible(offer);await pause(2);await _shot("final_breakthrough_offer")
	var dust: int=hub.gear.inventory.materials[&"dust"];var stash: int=flow.profile.material_stash[&"dust"]
	await _click(offer);await pause(.7)
	_check(realm()==3 and hub.gear.inventory.materials[&"dust"]==dust-1 and hub.gear.inventory.materials[&"crystal"]==2 and flow.profile.material_stash[&"dust"]==stash,"Final real UI commit spends one bag dust only; no extra crystal or stash charge")
	_check(Vector2i(flow.profile.coins,flow.profile.souls)==initial_wallets and hub.player.resonance_controller.foundation_resonance_enabled,"Breakthrough keeps both wallets and binds the committed link without a second fee")
	await _key(KEY_ESCAPE);snapshot("earned_truc_co")
	if not await choose_pair([&"fire",&"wind"],"same_pair_after_truc_co"):await finish_game(false);return
	if not await cast_at_targets("after_breakthrough_cast",1):await finish_game(false);return
	_check(before_payload["recipe"]==after_payload["recipe"] and before_payload["uid"]==after_payload["uid"] and before_payload["damage_multiplier"]==after_payload["damage_multiplier"] and before_payload["cooldown_multiplier"]==after_payload["cooldown_multiplier"],"Same weapon/class/pair and multipliers show the earned link rather than a scripted damage buff")
	if not await real_dungeon():await finish_game(false);return
	await power_page("earned_link_next_step");snapshot("final_return");await finish_game(true)

func finish_game(complete: bool) -> void:
	bot.stop();await pause(.3)
	var capture: Dictionary=recorder.finish()
	var state: Dictionary={"checks":checks,"failures":failures,"complete":complete,"source_profile_sha256":OS.get_environment("LINKED_SOURCE_SHA256"),"profile_path":ProjectSettings.globalize_path(profile_path),"profile_sha256":FileAccess.get_sha256(profile_path),"before":before_payload,"after":after_payload,"rear_contacts":rear_contacts,"dungeon_links":dungeon_links,"snapshots":snapshots,"capture":{"wall_seconds":capture["wall_seconds"],"frames":capture["frames"].size(),"audio":capture["audio"]},"scope":"Actual item2 earned save; normal real-time viewport inputs; three breakthrough UI commits, paid cultivation and existing rune inventory. No grants/unlocks/warps/HP/damage/RNG/state fixtures. QA automation, not human research."}
	var file:=FileAccess.open(evidence.path_join("linked-route.json"),FileAccess.WRITE);file.store_string(JSON.stringify(state,"\t",true,true));file.close()
	recorder.queue_free();bot.queue_free();flow.queue_free();current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT LinkedGameplay checks=%d failures=%d complete=%s wall=%.3f"%[checks,failures,complete,capture["wall_seconds"]]);quit(0 if complete and failures==0 else 1)

extends "res://tests/milestone_balance_native.gd"
## Frozen four-policy comparison. Inputs only except identical QA RNG seeds.
class FairBot:
	extends CombatBot
	var policy: String="melee"
	var clock_s: float=0.0
	var cues: Dictionary={}
	var decisions: Array[Dictionary]=[]
	var presses: Dictionary={"attack":0,"spell_cast":0,"dash":0,"jump":0}
	func pulse(id: StringName,reason: String) -> void:
		action(id,true)
		if id!=&"jump":releases.append(id)
		presses[String(id)]+=1
		decisions.append({"tick":tick,"game_s":clock_s,"action":String(id),"reason":reason})
	func _physics_process(delta: float) -> void:
		for id: StringName in releases:action(id,false)
		releases.clear()
		if not enabled or not is_instance_valid(run) or run.outcome!=&"" or not run.player.controls_enabled:return
		if run.feedback.is_frozen():return
		tick+=1;clock_s+=delta
		if tick>=jump_until:action(&"jump",false)
		var enemies: Array[Node2D]=run.living_enemies()
		if enemies.is_empty():action(&"move_left",false);action(&"move_right",false);return
		var target: Node2D=enemies[0]
		for enemy: Node2D in enemies:
			if enemy.global_position.distance_squared_to(run.player.global_position)<target.global_position.distance_squared_to(run.player.global_position):target=enemy
		var difference: Vector2=target.global_position-run.player.global_position
		var aim_event:=InputEventMouseMotion.new()
		aim_event.position=target.get_global_transform_with_canvas()*Vector2(0,-26)
		get_tree().root.push_input(aim_event,true)
		var direction: float=signf(difference.x)
		var move: bool=absf(difference.x)>42.0
		action(&"move_left",move and direction<0);action(&"move_right",move and direction>0)
		var dodge_due: bool=false
		for enemy: Node2D in enemies:
			if not enemy is BaseEnemy:continue
			var id: int=enemy.get_instance_id()
			var state: StringName=enemy.state_machine.get_state_id()
			var visible_cue: bool=state in [&"telegraph",&"attack"] and enemy.global_position.distance_to(run.player.global_position)<170
			if not visible_cue:cues.erase(id);continue
			if not cues.has(id):cues[id]={"seen":clock_s,"handled":false}
			if not cues[id]["handled"] and clock_s-float(cues[id]["seen"])>=0.18:
				cues[id]["handled"]=true
				dodge_due=true
		if policy in ["dodge","tactical"] and dodge_due and run.player.motor.can_dash() and run.player.energy.current>=25:
			if run.player.motor.is_grounded():
				pulse(&"jump","visible cue >=180ms");jump_until=tick+12
			action(&"move_left",direction<0);action(&"move_right",direction>=0)
			pulse(&"dash","visible cue >=180ms")
			return
		var pair_due: bool=policy in ["pair","tactical"] and absf(difference.x)<250 and absf(difference.y)<120 and run.player.resonance_controller.can_cast()
		if pair_due:
			# Reserve a naturally available action slot; attacks otherwise outrank casts.
			if run.player.action_state_machine.get_state_id()==&"ready":pulse(&"spell_cast","pair ready within visible range")
		elif tick%12==0 and absf(difference.x)<105 and absf(difference.y)<100:
			pulse(&"attack","shared 12-tick attack-button cadence")
		if difference.y < -55 and tick%45==0:
			pulse(&"jump","shared elevated-target reach");jump_until=tick+12

var campaign: WorldCampaign
var policy: String="melee"
var seed_value: int=137
var initial: Dictionary={}
var transitions: Array[Dictionary]=[]
var hits: Array[Dictionary]=[]
var pending_hits: Dictionary={}
var player_samples: Array[Dictionary]=[]
var attack_counts: Dictionary={}
var combat_start: int=0
var committed: int=0
var launched: int=0
var cast_entries: int=0
var initial_projectiles: int=0
var combat_end: int=0
var sample_tick: int=0
var recording: bool=false
var capture_result: Dictionary={}
var prepare_pair: bool=false

func _shot(_label: String) -> void:await process_frame
func born(node: Node) -> void:
	if node is WorldCampaign:
		node.run_seed=seed_value;campaign=node
	if (node is BaseEnemy or node is SlimeEnemy) and node.get_parent() is DungeonRoom:
		node.ready.connect(track_enemy.bind(node),CONNECT_ONE_SHOT)

func track_enemy(enemy: Node2D) -> void:
	enemy.state_machine.state_changed.connect(changed.bind(enemy))
	enemy.hurtbox.damage_received.connect(before_hit.bind(enemy))
	enemy.hurtbox.hit_resolved.connect(after_hit.bind(enemy))

func snapshot() -> Dictionary:
	var actor: Player=campaign.player
	var inv: GearInventory=campaign.gear.inventory
	var items: Array[Dictionary]=[]
	for uid: int in inv.equipment_uids+inv.slot_uids+[inv.catalyst_uid]:
		if uid==0:continue
		var item: GearItem=inv.items[uid]
		items.append({"uid":uid,"id":String(item.definition_id),"quality":item.quality,"enhancement":item.enhancement_level,"affix":String(item.affix_id),"drop_bonus":item.drop_bonus})
	var enemies: Array[Dictionary]=[]
	for enemy: Node2D in campaign.living_enemies():
		enemies.append({"id":enemy.get_instance_id(),"role":String(enemy.definition.id) if enemy is BaseEnemy else "runic_slime","x":enemy.position.x,"y":enemy.position.y,"hp":enemy.health.current_health,"state":String(enemy.state_machine.get_state_id())})
	return {"hp":actor.health.current_health,"max_hp":actor.health.maximum_health,"armor":actor.hurtbox.damage_resolver.armor_rating,"mana":actor.energy.current,"x":actor.position.x,"y":actor.position.y,"items":items,"slot_uids":Array(inv.slot_uids),"recipe":String(actor.resonance_controller.get_recipe().id),"cultivation":flow.profile.cultivation_progress.duplicate(true),"enemies":enemies}

func changed(previous: StringName,next: StringName,enemy: Node2D) -> void:
	var id: int=enemy.get_instance_id()
	if next==&"attack":attack_counts[id]=int(attack_counts.get(id,0))+1
	transitions.append({"usec":Time.get_ticks_usec(),"id":id,"role":String(enemy.definition.id) if enemy is BaseEnemy else "runic_slime","from":String(previous),"to":String(next),"x":enemy.position.x,"hero_x":campaign.player.position.x,"hp":enemy.health.current_health})

func before_hit(event: DamageEvent,target: Node2D) -> void:
	pending_hits[str(target.get_instance_id())+":"+str(event.attack_id)]={"state":String(target.state_machine.get_state_id()),"stunned":target.statuses.is_stunned() if target is BaseEnemy else false,"stun_remaining":target.statuses.stun_remaining if target is BaseEnemy else -1}

func after_hit(event: DamageEvent,result: DamageResult,target: Node2D) -> void:
	var key: String=str(target.get_instance_id())+":"+str(event.attack_id)
	hits.append({"usec":Time.get_ticks_usec(),"id":target.get_instance_id(),"kind":event.source_kind,"spell":String(event.spell_id),"damage":result.actual_damage,"blocked":result.blocked,"killed":result.killed,"before":pending_hits.get(key,{}),"after":String(target.state_machine.get_state_id()),"stunned":target.statuses.is_stunned() if target is BaseEnemy else false,"hp":target.health.current_health})
	hits[-1].merge({"source_id":event.source_id,"attack_id":event.attack_id,"root_event_id":event.root_event_id,"parent_event_id":event.parent_event_id,"hit_window_id":event.hit_window_id,"stun_seconds":event.stun_seconds,"interrupt_seconds":event.interrupt_seconds,"status_ids":Array(event.status_ids),"stun_remaining":target.statuses.stun_remaining if target is BaseEnemy else -1,"block_reason":String(result.block_reason),"critical":event.critical})
	pending_hits.erase(key)

func player_hit(event: DamageEvent,result: DamageResult) -> void:
	hits.append({"usec":Time.get_ticks_usec(),"id":0,"kind":event.source_kind,"spell":String(event.spell_id),"damage":result.actual_damage,"blocked":result.blocked,"killed":result.killed,"hp":campaign.player.health.current_health})

func player_changed(_previous: StringName,next: StringName) -> void:
	if next==&"cast_spell":cast_entries+=1

func cast_committed(_attack_id: int) -> void:committed+=1
func cast_launched(_position: Vector2) -> void:launched+=1

func sample() -> void:
	if not is_instance_valid(campaign):return
	sample_tick+=1
	if sample_tick%6==0:player_samples.append({"usec":Time.get_ticks_usec(),"x":campaign.player.position.x,"y":campaign.player.position.y,"hp":campaign.player.health.current_health,"mana":campaign.player.energy.current,"action":String(campaign.player.action_state_machine.get_state_id()),"remaining":campaign.living_enemies().size(),"frozen":campaign.feedback.is_frozen()})

func equip_common_pair() -> bool:
	await _key(KEY_TAB);await _step(4)
	var screen: InventoryScreen=campaign.gear.modal as InventoryScreen
	var bar: TabBar=screen.tabs.get_tab_bar()
	await _mouse(bar.get_global_transform()*bar.get_tab_rect(1).get_center())
	await _click(screen.slots[1]);await _key(KEY_ESCAPE)
	await _key(KEY_C);await _step(4)
	var panel: SurvivalPanel=campaign.survival.panel
	if not _check(panel.is_open and screen.selected_slot==1,"Actual C panel uses selected empty rune slot1"):return false
	var target_index: int=-1
	for index: int in panel.item_list.item_count:
		if int(panel.item_list.get_item_metadata(index))==496:target_index=index
	if not _check(target_index>=0,"Earned Common Lightning496 exists in visible inventory"):return false
	await _mouse(panel.item_list.get_global_rect().position+Vector2(50,24))
	await _key(KEY_HOME)
	for index: int in target_index:await _key(KEY_DOWN)
	if not _check(panel.selected_uid==496,"Keyboard selection chooses exact Common Lightning496"):return false
	await _click(panel.equip_button);await _key(KEY_C);await _step(4)
	return _check(campaign.gear.inventory.slot_uids[0]==113 and campaign.gear.inventory.slot_uids[1]==496 and campaign.player.resonance_controller.get_recipe().id==&"overload","Real UI installs Common Fire113 plus Lightning496 Overload")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--policy="):policy=arg.get_slice("=",1)
		elif arg.begins_with("--seed="):seed_value=int(arg.get_slice("=",1))
	recording="--record" in OS.get_cmdline_user_args()
	prepare_pair="--prepare-pair" in OS.get_cmdline_user_args()
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or policy not in ["melee","pair","dodge","tactical"]:quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	native=true;evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json";start_usec=Time.get_ticks_usec()
	if not _check(FileAccess.get_sha256(profile_path)==OS.get_environment("MINE_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("MINE_SOURCE_NPC"),"Exact earned QA copy; no profile field edits"):quit(2);return
	node_added.connect(born)
	bot=FairBot.new();(bot as FairBot).policy=policy;root.add_child(bot)
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30)
	if recording:
		recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	if OS.get_environment("COMMON_PAIR_SOURCE").is_empty():
		if not await configure_milestone():await finish_trial(false);return
	else:
		loadout_after=actor_snapshot()
		if not _check(loadout_after["recipe"]=="overload","Earned pair preparation already equips exact pair in hub"):await finish_trial(false);return
	var home: ExteriorHub=flow.active_scene as ExteriorHub
	if not await _walk(home.player,home.stations[&"portal"].global_position.x):await finish_trial(false);return
	await _key(KEY_E);await _step(8);campaign=flow.active_scene as WorldCampaign
	if not _check(campaign!=null and campaign.stage==1 and campaign.living_enemies().size()==4,"Ordinary portal enters the same four-enemy opening"):await finish_trial(false);return
	if OS.get_environment("COMMON_PAIR_SOURCE").is_empty():
		if not await equip_common_pair():await finish_trial(false);return
	initial=snapshot()
	var common: bool=true
	for item: Dictionary in initial["items"]:common=common and item["quality"]==0 and item["affix"]=="" and item["drop_bonus"]==0
	var exact: bool=campaign.gear.inventory.slot_uids[0]==113 and campaign.gear.inventory.slot_uids[1]==496 and campaign.gear.inventory.equipped_weapon_uid==1 and campaign.gear.inventory.items[1].enhancement_level==1 and initial["recipe"]=="overload"
	var untouched: bool=true
	for enemy: Dictionary in initial["enemies"]:
		untouched=untouched and enemy["hp"]==({"ancient_guard":90,"bloodwing_bat":70,"runic_slime":60}[enemy["role"]]) and enemy["state"] not in ["telegraph","attack","hurt","recover"]
	if not _check(common and exact and initial["hp"]==115 and initial["armor"]==11 and initial["mana"]==100 and (prepare_pair or (attack_counts.is_empty() and untouched)),"Exact Common sword1+1/Fire113/Lightning496/full HP/mana; measurement starts before attacks"):await finish_trial(false);return
	campaign.player.equipped_weapon.critical_rng.seed=seed_value*101+3
	campaign.player.resonance_controller.quality_rng.seed=seed_value*101+7
	initial["critical_rng_state"]=campaign.player.equipped_weapon.critical_rng.state
	initial["quality_rng_state"]=campaign.player.resonance_controller.quality_rng.state
	campaign.player.hurtbox.hit_resolved.connect(player_hit)
	campaign.player.action_state_machine.state_changed.connect(player_changed)
	campaign.player.resonance_controller.resonance_triggered.connect(cast_committed)
	campaign.player.resonance_controller.executor.presentation_cast.connect(cast_launched)
	initial_projectiles=campaign.player.resonance_controller.executor.spawned_projectiles
	process_frame.connect(sample)
	combat_start=Time.get_ticks_usec();bot.run=campaign;bot.enabled=true
	_stage("frozen_policy_"+policy)
	for index: int in 60*60:
		if campaign.outcome!=&"" or (campaign.living_enemies().is_empty() and not campaign.room.locked):break
		await _step(1)
	bot.stop()
	combat_end=Time.get_ticks_usec()
	if prepare_pair:
		if not _check(campaign.living_enemies().is_empty() and not campaign.room.locked,"Preparation actually clears room before normal return"):await finish_trial(false);return
		if not await _walk(campaign.player,1240):await finish_trial(false);return
		await _key(KEY_E);await _step(4)
		if not _check(campaign.floor_exit.is_open,"Preparation opens normal floor exit"):await finish_trial(false);return
		await _click(campaign.floor_exit.return_button);await _step(16)
		if not _check(flow.active_scene is ExteriorHub and flow.profile.last_save_ok,"Preparation returns and saves earned Common pair normally"):await finish_trial(false);return
	await finish_trial(true)

func finish_trial(valid: bool) -> void:
	bot.stop()
	if recording:capture_result=recorder.finish()
	var result: Dictionary={"valid":valid and failures==0,"checks":checks,"failures":failures,"policy":policy,"seed":seed_value,"initial":initial,"transitions":transitions,"hits":hits,"samples":player_samples,"combat_start_usec":combat_start,"combat_end_usec":Time.get_ticks_usec(),"elapsed_wall_s":float(Time.get_ticks_usec()-combat_start)/1000000.0 if combat_start>0 else 0.0,"elapsed_game_s":(bot as FairBot).clock_s,"presses":(bot as FairBot).presses,"decisions":(bot as FairBot).decisions,"committed":committed,"launched":launched,"attacks":attack_counts,"scope":"Input-only earned Common+1 Fire113/Lightning496; identical QA RNG seeds. Four frozen adaptive policies, same target/move/attack cadence, >=180ms observed cue response. Cultivation history retained, no G. Not human playtest, not exact-input replay. Recorder off unless explicit --record."}
	result["cast_state_entries"]=cast_entries
	result["combat_end_usec"]=combat_end
	result["elapsed_wall_s"]=float(combat_end-combat_start)/1000000.0 if combat_start>0 and combat_end>0 else 0.0
	result["launch_attempts"]=launched
	result.erase("launched")
	if prepare_pair:
		result["preparation"]=true;result["profile_sha256"]=FileAccess.get_sha256(profile_path);result["npc_sha256"]=FileAccess.get_sha256(profile_path+".npc_v1.json")
	if is_instance_valid(campaign):
		result["final"]=snapshot();result["cleared"]=campaign.living_enemies().is_empty() and not campaign.room.locked;result["outcome"]=String(campaign.outcome)
		result["projectiles_spawned"]=campaign.player.resonance_controller.executor.spawned_projectiles-initial_projectiles
		result["terminal_reason"]="clear" if result["cleared"] else "death" if campaign.player.health.current_health<=0 or campaign.outcome==&"defeat" else "timeout" if combat_start>0 else "setup_failure"
	if recording:result["capture"]={"wall_seconds":capture_result["wall_seconds"],"frames":capture_result["frames"].size(),"audio":capture_result["audio"]}
	var file:=FileAccess.open(evidence.path_join("opening-tactics.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	if process_frame.is_connected(sample):process_frame.disconnect(sample)
	if node_added.is_connected(born):node_added.disconnect(born)
	bot.queue_free();flow.queue_free();current_scene=null
	if recording:recorder.queue_free()
	campaign=null;await _step(8);await root.get_node("AudioManager").shutdown()
	if prepare_pair:
		result["pre_exit_npc_sha256"]=result["npc_sha256"]
		result["profile_sha256"]=FileAccess.get_sha256(profile_path);result["npc_sha256"]=FileAccess.get_sha256(profile_path+".npc_v1.json")
		result["hashes_after_scene_teardown"]=true
		file=FileAccess.open(evidence.path_join("opening-tactics.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("RESULT TacticsNative checks=%d failures=%d valid=%s"%[checks,failures,valid])
	quit(0 if valid and failures==0 else 1)

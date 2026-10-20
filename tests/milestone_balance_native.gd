extends "res://tests/floor_supply_gameplay_probe.gd"
## Earned QA copy; remove the high-quality rune through the real inventory UI.
## Source-available Common+1 sword and single learned Common Fire only.
var loadout_before: Dictionary={}
var loadout_after: Dictionary={}
var floor_metrics: Array[Dictionary]=[]
var hit_metrics: Array[Dictionary]=[]
var current_floor: int=0
var enemy_measurements: Dictionary={}

func actor_snapshot() -> Dictionary:
	var hub: ExteriorHub=flow.active_scene as ExteriorHub
	var actor: Player=hub.player
	var inv: GearInventory=hub.gear.inventory
	var active: Array[Dictionary]=[]
	for uid: int in inv.equipment_uids+inv.slot_uids+[inv.catalyst_uid]:
		if uid==0:continue
		var item: GearItem=inv.items[uid]
		active.append({"uid":uid,"id":String(item.definition_id),"quality":item.quality,"enhancement":item.enhancement_level,"affix":String(item.affix_id),"drop_bonus":item.drop_bonus})
	var recipe: ResonanceDefinition=actor.resonance_controller.get_recipe()
	return {"hp":actor.health.maximum_health,"armor":actor.hurtbox.damage_resolver.armor_rating,"mana":actor.energy.maximum,"active_items":active,"inventory":GearInventoryCodec.encode(inv),"recipe":String(recipe.id) if recipe!=null else "none","cultivation":flow.profile.cultivation_progress["actors"]["player"].duplicate(true),"permanent_upgrades":flow.profile.permanent_upgrades.duplicate()}

func configure_milestone() -> bool:
	_stage("remove_legendary_wind_via_inventory")
	loadout_before=actor_snapshot()
	await _key(KEY_TAB);await pause(.4)
	var screen: InventoryScreen=(flow.active_scene as ExteriorHub).gear.modal as InventoryScreen
	var bar: TabBar=screen.tabs.get_tab_bar()
	await _mouse(bar.get_global_transform()*bar.get_tab_rect(1).get_center());await pause(.4)
	await _click(screen.slots[1]);await _key(KEY_BACKSPACE);await pause(.6)
	var inv: GearInventory=screen.inventory
	if not _check(inv.slot_uids[1]==0 and inv.slot_uids[0]==113 and inv.items[744].quality==4,"Real Backspace removes WindLegendary to bag, preserves CommonFire and all owned UIDs"):return false
	await _shot("only_common_fire_equipped");await _key(KEY_ESCAPE);await pause(.4)
	loadout_after=actor_snapshot()
	var all_common: bool=true
	for item: Dictionary in loadout_after["active_items"]:
		all_common=all_common and item["quality"]==0 and item["affix"]=="" and item["drop_bonus"]==0
	return _check(all_common and loadout_after["hp"]==115 and loadout_after["armor"]==11 and loadout_after["mana"]==100 and inv.items[1].enhancement_level==1 and inv.slot_uids.filter(func(uid: int)->bool:return uid>0).size()==1 and loadout_after["recipe"]=="fire_bolt","Measured milestone: only Common gear, sword+1, one Common Fire, HP115 armor11 mana100; no rare affix/proc or pair chain")

func observed_hit(event: DamageEvent,result: DamageResult,enemy_id: int) -> void:
	if result.blocked:return
	var now: int=Time.get_ticks_usec()
	var row: Dictionary={"floor":current_floor,"target":enemy_id,"at_usec":now,"damage":result.actual_damage,"killed":result.killed,"spell":String(event.spell_id),"kind":event.source_kind,"critical":event.critical}
	hit_metrics.append(row)
	if enemy_id==0:return
	var target: Dictionary=enemy_measurements[enemy_id]
	if target["first_hit_usec"]==0:target["first_hit_usec"]=now
	target["hits"]+=1;target["resolved_damage"]+=result.actual_damage
	if result.killed:
		target["death_usec"]=now
		target["first_hit_to_death_seconds"]=float(now-target["first_hit_usec"])/1000000.0

func fight_floor(number: int) -> bool:
	current_floor=number+3
	var dungeon: DepthCampaign=flow.active_scene as DepthCampaign
	var row: Dictionary={"global_floor":current_floor,"started_usec":Time.get_ticks_usec(),"hp_start":dungeon.player.health.current_health,"enemy_count":dungeon.living_enemies().size()}
	if not dungeon.player.hurtbox.hit_resolved.is_connected(observed_hit.bind(0)):
		dungeon.player.hurtbox.hit_resolved.connect(observed_hit.bind(0))
	for enemy: Node2D in dungeon.living_enemies():
		var id: int=enemy.get_instance_id()
		enemy_measurements[id]={"floor":current_floor,"enemy_id":String(enemy.definition.id),"hp":enemy.health.current_health,"first_hit_usec":0,"death_usec":0,"hits":0,"resolved_damage":0.0}
		enemy.hurtbox.hit_resolved.connect(observed_hit.bind(id))
	var ok: bool=await super.fight_floor(number)
	row["ended_usec"]=Time.get_ticks_usec();row["clear_collect_exit_seconds"]=float(row["ended_usec"]-row["started_usec"])/1000000.0
	row["cleared_and_exited"]=ok
	row["hp_after_combat"]=route_snapshots[-1]["hp"] if not route_snapshots.is_empty() else -1
	floor_metrics.append(row)
	return ok

func _run() -> void:
	native=DisplayServer.get_name()!="headless"
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or not native or not "--native-approved" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json";start_usec=Time.get_ticks_usec()
	if not _check(FileAccess.get_sha256(profile_path)==OS.get_environment("MINE_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("MINE_SOURCE_NPC"),"Exact previously earned QA pair before startup; no field editing"):quit(2);return
	bot=CombatBot.new();root.add_child(bot)
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30)
	_check(not flow.qa_tools_enabled and flow.depth_progress.can_start_floor(2),"Prior earned completion enables normal floor4/5 access")
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	if not await configure_milestone():await finish_supply(false);return
	route_snapshot("common_milestone_departure")
	if not await launch_existing():await finish_supply(false);return
	if not await fight_floor(1):await finish_supply(false);return
	if not await fight_floor(2):await finish_supply(false);return
	route_snapshot("common_milestone_return")
	await show_sources("earned_materials_with_common_gear")
	if not await craft_from_bag():await finish_supply(false);return
	await finish_supply(true)

func finish_supply(complete: bool) -> void:
	var f:=FileAccess.open(evidence.path_join("milestone-native.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"complete":complete,"checks":checks,"failures":failures,"before":loadout_before,"milestone":loadout_after,"floors":floor_metrics,"enemies":enemy_measurements,"hits":hit_metrics,"scope":"One input-only Common+1 and CommonFire route on an earned QA copy after real UI removes LegendaryWind. TrucCo history retained but single Fire does not use pair-chain and bot never presses G. No stat/HP/AI/loot/RNG edits, no rare gear equipped. Bot reads exact telegraph states for dodging: not novice human skill, not paired A/B or mean farm time."},"\t"));f.close()
	await super.finish_supply(complete)

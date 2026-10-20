extends "res://tests/part1_first_loop_probe.gd"
## Normal real-time viewport input, fresh save; no grants/unlocks/warps/fixtures.
var recorder: Node
var baseline_observe: bool=false
var observations: Array[Dictionary]=[]

func _walk(player: Player,x: float,maximum_ticks: int=1200) -> bool:
	if flow.active_scene is DungeonRun:
		var run: DungeonRun=flow.active_scene as DungeonRun
		if run.survival.panel.is_open:
			_stage("close_campfire_opened_by_nearby_pickup")
			await pause(1);await _key(KEY_C);await pause(.5)
	return await super._walk(player,x,maximum_ticks)

func _click(button: Button) -> void:
	if button!=null:
		var ancestor: Node=button.get_parent()
		while ancestor!=null:
			if ancestor is ScrollContainer:(ancestor as ScrollContainer).ensure_control_visible(button)
			ancestor=ancestor.get_parent()
		await pause(.3)
	await super._click(button)

func _learn_first_rune(hub: PrologueHub) -> void:
	_stage("learn_first_rune_with_earned_souls")
	if not await _talk(hub,NpcCatalog.HEALER):return
	await _click(hub.dialogue.choice_list.get_node_or_null("Choice_rune_learning") as Button);await pause(1)
	var price: int=int(hub.rune_learning.quote(&"fire")["cost"]);var before: int=flow.profile.souls
	await _click(hub.station_content.find_child("RuneService_fire",true,false) as Button);await pause(1)
	_check(flow.profile.souls==before and hub.gear.inventory.bag[&"fire"]==0,"Learning confirmation does not charge early or grant a preview rune")
	await _click(hub.station_content.find_child("ConfirmPurchase",true,false) as Button);await pause(1.5)
	_check(flow.profile.souls==before-price and hub.gear.inventory.bag[&"fire"]==1,"Actual learned first rune costs the real earned price and yields one owned copy")
	await _key(KEY_ESCAPE);await _key(KEY_TAB);await pause(1)
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen;var bar: TabBar=screen.tabs.get_tab_bar()
	await _mouse(bar.get_global_transform()*bar.get_tab_rect(1).get_center());await pause(1)
	await _click(screen.slots[0]);await _click(screen.rune_buttons[0]);await pause(1.5)
	_check(hub.player.resonance_controller.get_recipe()!=null and hub.gear.inventory.bag[&"fire"]==0,"Actual inventory clicks install the paid rune and resolve a real spell")
	await _shot("first_rune_installed");await _key(KEY_ESCAPE)
	await power_page("first_spell_next_toward_cultivation")

func pause(seconds: float) -> void:
	var end: int=Time.get_ticks_usec()+roundi(seconds*1000000)
	while Time.get_ticks_usec()<end:await process_frame

func _stage(label: String) -> void:
	phase=label
	if recorder!=null:recorder.mark(label)
	print("ROUTE_STAGE "+label)

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(evidence.path_join(label+".png"))==OK,"Native observation captured: "+label)

func power_page(label: String) -> Dictionary:
	var hub: PrologueHub=flow.active_scene as PrologueHub
	_stage(label);await _key(KEY_M);await pause(1)
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	if screen.journal.selected_id!=PowerProgressionGuide.ID:await _click(screen.journal.power_button)
	await pause(2)
	_check(screen.journal.selected_id==PowerProgressionGuide.ID,"Captured actual M screen is the power route, including after reopen")
	var row: Dictionary=PowerProgressionGuide.row(flow.profile,hub.gear.inventory)
	observations.append({"label":label,"row":row,"bounty_accepted":flow.profile.bounty_accepted,"souls":flow.profile.souls,"stash":flow.profile.material_stash.duplicate(),"bag":hub.gear.inventory.materials.duplicate()})
	await _shot(label)
	await _key(KEY_PAGEDOWN);await pause(1)
	await _key(KEY_ESCAPE);return row

func _dialogue_ready(hub: PrologueHub) -> void:
	for i: int in 40:
		if not hub.dialogue.is_open:return
		if hub.dialogue.page_index==hub.dialogue.pages.size()-1 and not hub.dialogue.is_typing():await pause(1.1);return
		await _key(KEY_E);await pause(.35)

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args():quit(2);return
	baseline_observe="--baseline-observe" in OS.get_cmdline_user_args()
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	_check(not FileAccess.file_exists(profile_path),"Profile did not exist before actual fresh product startup")
	bot=CombatBot.new();root.add_child(bot)
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow;flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30)
	var hub: PrologueHub=flow.active_scene as PrologueHub
	_check(not flow.qa_tools_enabled and flow.profile.souls==0 and not flow.profile.bounty_accepted,"Fresh product defaults, no cheat tools/grants/accepted quest")
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence);_stage("fresh_start");await pause(1)
	var first: Dictionary=await power_page("fresh_power")
	if baseline_observe:
		_stage("follow_initial_power_destination")
		if first["power"]["station"]==&"portal":
			await _walk(hub.player,hub.stations[&"portal"].global_position.x);await _key(KEY_E);await _step(8);await pause(2)
			_check(flow.active_scene is DungeonRun and not flow.profile.bounty_accepted,"Baseline power route permits entering dungeon before the quest shown elsewhere is accepted")
			await _shot("baseline_departure_without_bounty")
		await _finish(false);return
	_check(first["power"]["station"]==NpcCatalog.WANDERER,"Fresh M/Power now names the concrete first quest before dungeon")
	_stage("accept_bounty")
	if not await _talk(hub,NpcCatalog.WANDERER):await _finish(false);return
	await _click(hub.dialogue.choice_list.get_node_or_null("Choice_bounty_accept") as Button);await pause(1)
	_check(flow.profile.bounty_accepted,"Actual focused NPC choice accepts the existing quest")
	await _key(KEY_ESCAPE);await power_page("accepted_next_step")
	for attempt: int in 4:
		attempts=attempt+1;hub=flow.active_scene as PrologueHub;_stage("departure_%d"%attempts)
		if not await _walk(hub.player,hub.stations[&"portal"].global_position.x):await _finish(false);return
		await _key(KEY_E);await _step(8)
		if not _check(flow.active_scene is DungeonRun,"Actual E enters the dungeon"):await _finish(false);return
		await _expedition()
		for i: int in 600:
			if flow.active_scene is PrologueHub:break
			await _step(1)
		if not flow.active_scene is PrologueHub:await _finish(false);return
		hub=flow.active_scene as PrologueHub
		var returned: Dictionary=await power_page("returned_%d_next"%attempts)
		if returned["power"]["key"]==&"runes" and returned["power"]["station"]==NpcCatalog.HEALER and hub.gear.inventory.bag[&"fire"]==0 and not hub.rune_learning.quote(&"fire")["learned"]:await _learn_first_rune(hub)
		if PowerProgressionGuide._upgrade(flow.profile,hub.gear.inventory)["ready"]:break
		_stage("another_actual_run_for_real_price")
	hub=flow.active_scene as PrologueHub
	_check(PowerProgressionGuide._upgrade(flow.profile,hub.gear.inventory)["ready"],"Loot earned in actual attempts can pay an existing upgrade")
	var next: Dictionary=await power_page("earned_materials_and_next")
	if next["power"]["key"]==&"bounty":
		_stage("claim_existing_bounty")
		if not await _talk(hub,NpcCatalog.WANDERER):await _finish(false);return
		await _click(hub.dialogue.choice_list.get_node_or_null("Choice_bounty_claim") as Button);await pause(2)
		_check(flow.profile.bounty_claimed,"Existing quest reward claimed once through its actual owner")
		await _key(KEY_ESCAPE);next=await power_page("claimed_next_step")
	_stage("first_upgrade")
	if next["power"]["station"]==NpcCatalog.SMITH:
		if not await _talk(hub,NpcCatalog.SMITH):await _finish(false);return
		await _click(hub.dialogue.choice_list.get_node_or_null("Choice_smith_enhance") as Button);await pause(2)
		var inv: GearInventory=hub.gear.inventory;var uid: int=inv.equipped_weapon_uid
		var offer: Dictionary=hub.economy.quote_enhance(uid);var coins: int=flow.profile.coins;var stones: int=inv.materials[offer["stone_id"]];var damage: float=inv.items[uid].damage_factor()
		await _click(hub.station_content.find_child("EnhanceWeapon_%d"%uid,true,false) as Button);await pause(2)
		_check(inv.items[uid].enhancement_level==1 and inv.items[uid].damage_factor()>damage and flow.profile.coins==coins-int(offer["coin_cost"]) and inv.materials[offer["stone_id"]]==stones-1,"Actual recommended enhancement spends once and increases the same weapon damage")
		await _key(KEY_ESCAPE);await power_page("upgraded_next_toward_foundation");await _finish(true);return
	if not _check(next["power"]["station"]==NpcCatalog.HEALER and next["power"]["key"]==&"upgrade","Actual guide recommends the affordable first improvement"):await _finish(false);return
	if not await _talk(hub,NpcCatalog.HEALER):await _finish(false);return
	var quote: Dictionary=hub.economy.quote_upgrade(&"max_mana");var before: int=flow.profile.souls;var mana: float=hub.player.energy.maximum
	if not _check(quote["can_buy"],"Actual loot pays the actual upgrade quote"):await _finish(false);return
	await _click(hub.dialogue.choice_list.get_node_or_null("Choice_upgrade_max_mana") as Button);await pause(2)
	_check(flow.profile.souls==before and hub.dialogue.confirmation.visible,"Confirmation shows cost without premature spending")
	await _click(hub.dialogue.cancel_button);await pause(.7)
	_check(flow.profile.souls==before and flow.profile.permanent_upgrades[&"max_mana"]==0,"Cancel preserves price and upgrade")
	await _click(hub.dialogue.choice_list.get_node_or_null("Choice_upgrade_max_mana") as Button);await pause(1)
	await _click(hub.dialogue.confirm_button);await pause(2)
	_check(flow.profile.permanent_upgrades[&"max_mana"]==1 and flow.profile.souls==before-int(quote["cost"]) and hub.player.energy.maximum>mana,"Confirmed first improvement spends once and increases real max mana")
	await _key(KEY_ESCAPE);await power_page("upgraded_next_toward_foundation")
	await _finish(true)

func _finish(complete: bool) -> void:
	bot.stop();await pause(.25)
	var state: Dictionary={"checks":checks,"failures":failures,"complete_loop":complete,"baseline_observe":baseline_observe,"attempts":attempts,"observations":observations,"profile_path":ProjectSettings.globalize_path(profile_path),"souls":flow.profile.souls,"upgrades":flow.profile.permanent_upgrades,"opening":flow.profile.opening_objectives(),"inventory":flow.profile.hub_inventory,"profile_sha256":FileAccess.get_sha256(profile_path),"scope":"QA automation from fresh product with viewport input and normal wall-time engine. No grants, unlocks, player warps, HP/damage/loot/AI/state fixtures. Not research on human users."}
	var capture: Dictionary=recorder.finish();state["capture"]={"wall_seconds":capture["wall_seconds"],"audio":capture["audio"],"frames":capture["frames"].size()}
	var file:=FileAccess.open(evidence.path_join("route-result.json"),FileAccess.WRITE);file.store_string(JSON.stringify(state,"\t"));file.close()
	recorder.queue_free();bot.queue_free();flow.queue_free();current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT NewcomerRoute checks=%d failures=%d complete=%s baseline=%s wall=%.3f"%[checks,failures,complete,baseline_observe,capture["wall_seconds"]]);quit(0 if failures==0 and (complete or baseline_observe) else 1)

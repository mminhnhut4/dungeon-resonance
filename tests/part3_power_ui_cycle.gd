extends "res://tests/part3_power_ui_probe.gd"
## UI/sample evidence, with declared resource and second-dummy fixtures only.
var hub: ExteriorHub
var screen: InventoryScreen
var stages: Array[Dictionary]=[]
var chain_contacts: Array[Dictionary]=[]
var profile_path: String="user://part3-ui-cycle/profile.json"
func stage(label: String) -> void:
	var entry: Dictionary={"label":label,"frame":Engine.get_process_frames()}
	stages.append(entry);print("MOVIE_STAGE "+JSON.stringify(entry))
func action(id: StringName, down: bool) -> void:
	var event:=InputEventAction.new();event.action=id;event.pressed=down;Input.parse_input_event(event)
func aim(target: Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=hub.player.get_canvas_transform()*target;root.push_input(motion,true)
func walk(x: float,limit: int=1600) -> bool:
	var last: float=hub.player.global_position.x;var stalled: int=0
	for _i: int in limit:
		var difference: float=x-hub.player.global_position.x
		if absf(difference)<7:
			action(&"move_left",false);action(&"move_right",false);action(&"jump",false);await step(3);return true
		action(&"move_left",difference<0);action(&"move_right",difference>0)
		stalled=stalled+1 if absf(hub.player.global_position.x-last)<0.2 else 0;last=hub.player.global_position.x
		if stalled==30:action(&"jump",true)
		if stalled>=42:action(&"jump",false);stalled=0
		await step(1)
	action(&"move_left",false);action(&"move_right",false);action(&"jump",false)
	check(false,"Actual movement reached requested interaction");return false
func click_scroll(button: Button, scroll: ScrollContainer) -> void:
	if button==null:check(false,"Requested actual UI button exists");return
	scroll.ensure_control_visible(button);await step(3)
	check(scroll.get_global_rect().grow(1).encloses(button.get_global_rect()),"Requested action is inside its real scroll viewport")
	await click(button)
func power(label: String) -> void:
	await key(KEY_M);await step(4)
	if screen.journal.selected_id!=PowerProgressionGuide.ID:await click(screen.journal.power_button)
	screen.journal.detail_scroll.scroll_vertical=0;screen.journal.power_scroll.scroll_vertical=0;await step(3)
	stage(label);await shot(label);await step(120)
	if label in ["08_truc_co_route","11_cold_reload_route"]:
		screen.journal.power_scroll.ensure_control_visible(screen.journal.power_preview)
		screen.journal.detail_scroll.ensure_control_visible(screen.journal.detail_headers[&"reward"])
		await step(4);stage(label+"_reward");await shot(label+"_reward");await step(120)
	await key(KEY_ESCAPE);await step(3)
func npc(id: StringName) -> bool:
	if not await walk(hub.stations[id].global_position.x):return false
	await key(KEY_E);await step(3)
	if not hub.dialogue.is_open or hub.current_npc!=id:check(false,"Actual E opens intended NPC");return false
	for _i: int in 30:
		if hub.dialogue.page_index==hub.dialogue.pages.size()-1 and not hub.dialogue.is_typing():break
		await key(KEY_E)
	return true
func tab(index: int) -> void:
	var bar: TabBar=screen.tabs.get_tab_bar()
	var point: Vector2=bar.get_global_transform()*bar.get_tab_rect(index).get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await step(3)
func open_training() -> bool:
	if not await walk(hub.stations[&"training"].global_position.x):return false
	await key(KEY_E);await step(3)
	check(hub.station_open and hub.current_station==&"training","Actual E opens cultivation station")
	return hub.station_open and hub.current_station==&"training"
func realm() -> int:return int(flow.profile.cultivation_progress["actors"]["player"]["stage"])
func _chain_contact(event: DamageEvent,result: DamageResult) -> void:
	if not result.blocked and result.actual_damage>0:
		chain_contacts.append({"frame":Engine.get_process_frames(),"source_kind":event.source_kind,"root":event.root_event_id,"damage":result.actual_damage,"recursive":event.allow_resonance})
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	var seed_profile:=SanctuaryProfile.new();seed_profile.save_path=profile_path;seed_profile.coins=5
	var kit: GearInventory=HubPreparation.starter_inventory(seed_profile)
	kit.materials[&"crystal"]=2;kit.materials[&"dust"]=1;kit.materials[&"enhancement_stone_1"]=1
	kit.add_rune(&"fire");kit.add_rune(&"wind")
	seed_profile.hub_inventory=GearInventoryCodec.encode(kit);check(seed_profile.save(),"Declared synthetic resources saved before the sample; no stage/insight/mastery grant")
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow;flow.save_path_override=profile_path;root.add_child(flow);await step(14)
	hub=flow.active_scene as ExteriorHub;screen=hub.gear.modal as InventoryScreen
	check(not flow.qa_tools_enabled and realm()==0,"Product flow starts Luyen Khi I with QA gameplay tools disabled")
	await power("01_start_route")
	await key(KEY_TAB);await tab(1);await click(screen.slots[0]);await click(screen.rune_buttons[0]);await click(screen.slots[1]);await click(screen.rune_buttons[1]);await shot("02_runes_equipped");await step(40);await key(KEY_TAB)
	check(hub.player.resonance_controller.get_recipe().id==&"firestorm","Actual inventory clicks equip the existing exact Fire+Wind recipe")
	await power("03_upgrade_route")
	if not await npc(NpcCatalog.SMITH):await finish_cycle();return
	await click_scroll(hub.dialogue.choice_list.get_node_or_null("Choice_smith_enhance") as Button,hub.dialogue.body_scroll);await step(4)
	var uid: int=hub.gear.inventory.equipped_weapon_uid
	await click_scroll(hub.station_content.find_child("EnhanceWeapon_%d"%uid,true,false) as Button,hub.station_scroll);await step(4)
	check(hub.gear.inventory.items[uid].enhancement_level==1 and flow.profile.coins==0 and hub.gear.inventory.materials[&"enhancement_stone_1"]==0,"Actual smith action spends one carried stone/five coins and applies one level")
	stage("04_upgrade_committed");await shot("04_upgrade_committed");await step(40);await key(KEY_ESCAPE)
	if not await npc(NpcCatalog.HEALER):await finish_cycle();return
	await key(KEY_ESCAPE)
	if not await walk(hub.stations[&"exterior_road"].global_position.x):await finish_cycle();return
	await key(KEY_E);await step(10)
	check(hub.outside and flow.profile.opening_progress["completed"].has("explored"),"Actual road interaction earns exploration insight")
	if not hub.outside:await finish_cycle();return
	var exit: Vector2=hub.exterior.to_global(hub.exterior.interactions[&"door_west"])
	if not await walk(exit.x):await finish_cycle();return
	await key(KEY_E);await step(10);check(not hub.outside,"Actual known return door reaches the courtyard")
	if hub.outside:await finish_cycle();return
	for _i: int in 12:
		if int(flow.profile.cultivation_progress["actors"]["player"]["mastery"])>=4:break
		if not await walk(hub.dummy.global_position.x-48):await finish_cycle();return
		aim(hub.dummy.hurtbox.global_position);action(&"attack",true);await step(2);action(&"attack",false);await step(38)
	check(int(flow.profile.cultivation_progress["actors"]["player"]["mastery"])>=4,"Real melee contacts earn four mastery without a progress grant")
	await power("05_training_route")
	await step(140)
	var second: TrainingDummy=preload("res://scenes/training_dummy.tscn").instantiate() as TrainingDummy
	second.position=hub.dummy.position+Vector2(-140,0);second.display_name="BIA TẬP PHỤ";second.combat_feedback=hub.feedback;second.damage_number_spawner=hub.damage_numbers;hub.yard.add_child(second)
	second.hurtbox.damage_resolver.status_controller.combat_feedback=hub.feedback;second.hurtbox.hit_resolved.connect(_chain_contact)
	if not await walk(hub.dummy._home_position.x-80):await finish_cycle();return
	aim(hub.dummy.hurtbox.global_position);var before_chain: int=hub.executor.chain_hit_count
	stage("06_before_breakthrough_cast");await key(KEY_I);await step(50)
	check(not hub.player.resonance_controller.foundation_resonance_enabled and hub.executor.chain_hit_count==before_chain and chain_contacts.is_empty(),"Before breakthrough the same composite cast has no new link")
	await shot("06_before_link")
	if not await open_training():await finish_cycle();return
	await click_scroll(hub.station_content.find_child("CultivationStartPlayer",true,false) as Button,hub.station_scroll)
	for _i: int in 720:
		if int(flow.profile.cultivation_progress["actors"]["player"]["energy"])>=16:break
		await step(1)
	check(int(flow.profile.cultivation_progress["actors"]["player"]["energy"])>=16 and hub.gear.inventory.materials[&"crystal"]==0,"Actual closed-panel training consumes exactly two carried crystals for sixteen cultivation energy")
	if not await open_training():await finish_cycle();return
	var stop: Button=hub.station_content.find_child("CultivationStop",true,false) as Button
	if stop!=null:await click_scroll(stop,hub.station_scroll);await step(4)
	for target_stage: int in [1,2]:
		await click_scroll(hub.station_content.find_child("CultivationBreakthrough_player",true,false) as Button,hub.station_scroll);await step(5)
		check(realm()==target_stage,"Actual button advances exactly one existing cultivation gate")
	for child: Node in hub.station_content.get_children():
		if child is Label and (child as Label).text.begins_with("ĐỘT PHÁ MỞ LIÊN ẤN"):
			hub.station_scroll.ensure_control_visible(child);await step(4);break
	stage("07_final_breakthrough_offer");await shot("07_final_breakthrough_offer");await step(120)
	await click_scroll(hub.station_content.find_child("CultivationBranch_tether_sigil",true,false) as Button,hub.station_scroll);await step(5)
	check(realm()==3 and hub.gear.inventory.materials[&"dust"]==0 and hub.player.resonance_controller.foundation_resonance_enabled,"Real final commit spends one carried dust and unlocks Lien An plus the chosen G branch")
	await key(KEY_ESCAPE);await power("08_truc_co_route")
	if not await walk(hub.dummy._home_position.x-80):await finish_cycle();return
	await step(140);aim(hub.dummy.hurtbox.global_position);before_chain=hub.executor.chain_hit_count
	stage("09_after_breakthrough_cast");await key(KEY_I)
	for _i: int in 120:
		if hub.executor.chain_hit_count>before_chain:break
		await step(1)
	check(hub.executor.chain_hit_count==before_chain+1 and chain_contacts.any(func(c: Dictionary) -> bool:return c["source_kind"]==DamageEvent.SourceKind.RESONANCE and not c["recursive"]),"Same actual cast now delivers one bounded secondary hit with its existing nonrecursive event")
	stage("10_link_contact");await shot("10_link_contact");await step(80)
	flow.queue_free();await step(10)
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow;flow.save_path_override=profile_path;root.add_child(flow);await step(14)
	hub=flow.active_scene as ExteriorHub;screen=hub.gear.modal as InventoryScreen
	check(realm()==3 and hub.player.resonance_controller.foundation_resonance_enabled and hub.gear.inventory.materials[&"dust"]==0 and hub.gear.inventory.materials[&"crystal"]==0 and hub.gear.inventory.items[uid].enhancement_level==1 and flow.profile.coins==0,"Fresh GameFlow reload restores earned stage/link, exact costs and enhanced weapon UID")
	await power("11_cold_reload_route");await finish_cycle()
func finish_cycle() -> void:
	var evidence: String=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	var file:=FileAccess.open(evidence.path_join("ui_cycle.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"stages":stages,"contacts":chain_contacts,"profile_path":ProjectSettings.globalize_path(profile_path),"profile_sha256":FileAccess.get_sha256(profile_path),"scope":"Fresh synthetic save seeded only 5 coins, one enhancement stone, two crystals, one dust and Fire/Wind runes. Existing real M/inventory/NPC/road/melee/training/breakthrough/cast UI/input flow. Added one ordinary scene dummy for link demonstration. No stage/insight/mastery grants, no actor warps or forced skill poses. Muted; MovieMaker is not FPS proof."},"\t"));file.close()
	if is_instance_valid(flow):flow.queue_free();await step(8)
	await root.get_node("AudioManager").shutdown()
	print("RESULT Part3PowerUICycle checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

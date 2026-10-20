extends SceneTree
const Model=preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
class CountingProfile extends SanctuaryProfile:
	var saves: int=0
	func save() -> bool:saves+=1;return true
var checks: int=0
var failures: int=0
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func step(count: int) -> void:
	for _i: int in count:await physics_frame;await process_frame
func need(row: Dictionary,id: StringName) -> Dictionary:
	for entry: Dictionary in row["power"]["requirements"]:
		if entry["id"]==id:return entry
	return {}
func _pure() -> void:
	var profile:=CountingProfile.new();profile.cultivation_progress=Model.new_progress(4)
	var inventory: GearInventory=HubPreparation.starter_inventory(profile)
	var before: String=Writer.canonical({"cult":profile.cultivation_progress,"bank":profile.material_stash,"inv":GearInventoryCodec.encode(inventory),"souls":profile.souls})
	var serial: int=int(get_meta(&"dungeon_combat_serial",0))
	var view: Dictionary=PowerProgressionGuide.row(profile,inventory)
	check(view["power"]["key"]==&"first_quest" and view["power"]["station"]==NpcCatalog.WANDERER and need(view,&"bounty")["missing"]==1,"Fresh player sees the existing quest owner before departure")
	profile.bounty_accepted=true
	view=PowerProgressionGuide.row(profile,inventory)
	check(view["power"]["key"]==&"runes" and need(view,&"fire")["missing"]==1 and need(view,&"wind").is_empty() and view["power"]["station"]==&"portal" and "5 Tàn Hồn" in view["card"]["action"],"Accepted quest leads to one affordable first rune and says how to earn its real price")
	profile.souls=20
	check(PowerProgressionGuide.row(profile,inventory)["power"]["key"]==&"upgrade","A payable strength improvement is offered before demanding another missing rune")
	profile.boss_proofs[&"golem"]=1
	check(PowerProgressionGuide.row(profile,inventory)["power"]["key"]==&"bounty","An earned existing bounty is returned to its owner before a purchase")
	profile.souls=0;profile.boss_proofs[&"golem"]=0
	profile.bounty_accepted=false
	for _i: int in 5:PowerProgressionGuide.row(profile,inventory)
	check(profile.saves==0 and before==Writer.canonical({"cult":profile.cultivation_progress,"bank":profile.material_stash,"inv":GearInventoryCodec.encode(inventory),"souls":profile.souls}) and serial==int(get_meta(&"dungeon_combat_serial",0)),"Repeated power projections allocate no UID, save, reward or progression")
	inventory.add_rune(&"fire");inventory.add_rune(&"wind");inventory.equip(0,&"fire");inventory.equip(1,&"wind")
	check(PowerProgressionGuide.rune_counts(inventory)[&"fire"]==1 and inventory.bag[&"fire"]==0,"Already installed runes count once as carried ownership")
	view=PowerProgressionGuide.row(profile,inventory)
	check(view["power"]["key"]==&"cultivation" and need(view,&"crystal")["need"]==1,"Valid spell advances the route to the current cultivation gate")
	profile.material_stash[&"crystal"]=50;profile.material_stash[&"dust"]=50
	view=PowerProgressionGuide.row(profile,inventory)
	check(need(view,&"crystal")["have"]==0 and need(view,&"crystal")["missing"]==1,"Stored crystal cannot masquerade as a carried training ingredient")
	profile.cultivation_progress["actors"]["player"]["mastery"]=1
	check(PowerProgressionGuide.row(profile,inventory)["power"]["station"]==&"stash","Once mastery is ready, missing carried crystal points to withdrawal")
	inventory.materials[&"crystal"]=1
	check(PowerProgressionGuide.row(profile,inventory)["power"]["station"]==&"training","With carried crystal the same tracked route returns to training")
	inventory.materials[&"enhancement_stone_1"]=1;profile.coins=5
	view=PowerProgressionGuide.row(profile,inventory)
	check(view["power"]["key"]==&"upgrade" and need(view,&"coins")["need"]==5 and need(view,&"enhancement_stone_1")["missing"]==0,"Affordable real enhancement quote becomes the next optional power step")
	inventory.items[inventory.equipped_weapon_uid].enhancement_level=1
	check(PowerProgressionGuide.row(profile,inventory)["power"]["key"]==&"cultivation","Completed enhancement advances back to cultivation rather than demanding another upgrade")
	var actor: Dictionary=profile.cultivation_progress["actors"]["player"]
	actor["stage"]=2;actor["energy"]=16;actor["mastery"]=4;actor["insight_ids"]=["explored","thanh_vy_met"]
	inventory.materials[&"dust"]=0
	view=PowerProgressionGuide.row(profile,inventory)
	check(need(view,&"dust")["need"]==1 and need(view,&"dust")["missing"]==1 and view["power"]["station"]==&"stash","Final breakthrough reads its one dust from bag and points to the real stored supply")
	inventory.materials[&"dust"]=1
	view=PowerProgressionGuide.row(profile,inventory)
	check(view["power"]["station"]==&"training" and "Liên Ấn" in view["card"]["reward"],"Ready final gate shows the actual resonance unlock and returns to training")
	profile.cultivation_progress["config"]["energy_thresholds"]=[12,24,40]
	actor["energy"]=24
	view=PowerProgressionGuide.row(profile,inventory)
	check(need(view,&"crystal")["need"]==2,"Legacy saved tuning quotes two remaining sessions rather than hardcoding new-game thresholds")
	actor["stage"]=3;actor["energy"]=40
	check(FoundationResonance.unlocked(profile),"A valid old Truc Co stage derives the unlock without a new save field")
	view=PowerProgressionGuide.row(profile,inventory)
	check(view["power"]["foundation"] and view["power"]["key"]==&"journey","After completed preparation, the route explains how to try the unlocked link")
	inventory.equip(1,&"")
	view=PowerProgressionGuide.row(profile,inventory)
	check(view["power"]["key"]==&"runes" and view["power"]["spell_ids"]==[&"fire",&"wind"],"After breakthrough a single-rune loadout is guided toward a real composite recipe")
	profile.read_only=true
	check(not FoundationResonance.unlocked(profile) and PowerProgressionGuide.row(profile,inventory)["power"].is_empty(),"Quarantined/read-only progress cannot promise an available transaction or unlock")

func _product() -> void:
	var flow: GameFlow=preload("res://scenes/maps/prologue_hub.tscn").instantiate()
	flow.save_path_override="user://part3-power-guide/profile.json";root.add_child(flow);await step(12)
	var hub: ExteriorHub=flow.active_scene as ExteriorHub
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	var journal: QuestJournal=screen.journal
	var nav: QuestNavigator=screen.get_node("QuestNavigator") as QuestNavigator
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes(flow.profile.save_path)
	screen.open_map();await step(3)
	if journal.selected_id!=PowerProgressionGuide.ID:journal.power_button.pressed.emit();await step(3)
	check(journal.selected_id==PowerProgressionGuide.ID and nav.tracked_id()==PowerProgressionGuide.ID,"Actual map power button selects and tracks the new read-only route")
	check(journal.detail_headers.has(&"requirements") and journal.requirement_list.get_child_count()==1 and journal.power_preview.get_child_count()==3 and nav.state["anchor"]==NpcCatalog.WANDERER,"Actual fresh map shows the first quest count and navigates to its owner")
	check(journal.tracker_text().is_empty() and not screen.tracker.visible,"Power guidance does not add a persistent HUD panel")
	screen.close();await step(3)
	var first_button: int=journal.quest_list.get_child(0).get_instance_id()
	hub.gear.inventory.add_rune(&"fire");hub.gear.inventory.equip(0,&"fire")
	nav.update_navigation()
	check(journal._projection_dirty and journal.quest_list.get_child(0).get_instance_id()==first_button,"Closed UI stays unbuilt while inventory changes invalidate its read-only projection")
	check(nav.state["status"]=="point" and nav.state["anchor"]==&"training","Closed-map navigation recalculates the next cultivation step from the newly equipped spell")
	screen.open_map();await step(3)
	check(journal.selected_id==PowerProgressionGuide.ID,"Reopening M retains the chosen power route instead of replacing it with another mission")
	check(journal.requirement_list.get_child_count()>=4 and journal.quest_list.get_child(0).get_instance_id()!=first_button,"Opening the real map flushes current counts before presenting the next step")
	check(FileAccess.get_file_as_bytes(flow.profile.save_path)!=bytes,"Only the existing inventory transaction owner persisted the actual rune equip")
	screen.close();flow.queue_free();await step(8);await root.get_node("AudioManager").shutdown()

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	Engine.physics_ticks_per_second=120 if "--hz=120" in OS.get_cmdline_user_args() else 60
	AudioServer.set_bus_mute(0,true);_pure();await _product()
	print("RESULT PowerProgressionGuide checks=%d failures=%d hz=%d"%[checks,failures,Engine.physics_ticks_per_second]);quit(0 if failures==0 else 1)

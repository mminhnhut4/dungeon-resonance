extends SceneTree
## Explicit unit/fault fixtures. Never used as gameplay/video evidence.
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int=0
var failures: int=0
var flow: GameFlow
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func step(count: int=4) -> void:
	for i: int in count:await physics_frame;await process_frame
func setup_case(label: String) -> PrologueHub:
	var source:=SanctuaryProfile.new();source.save_path="user://rewards-unit/"+label+".json";source.coins=9;source.souls=12;source.bounty_accepted=true;source.boss_proofs[&"golem"]=1
	var inventory: GearInventory=HubPreparation.starter_inventory(source);source.hub_inventory=GearInventoryCodec.encode(inventory);check(source.save(),"Explicit unit fixture is durably written")
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=source.save_path;root.add_child(flow);await step(14);return flow.active_scene as PrologueHub
func close_case() -> void:
	flow.queue_free();flow=null;await step(8)
func reward_count(inventory: GearInventory) -> int:
	var amount: int=0
	for item: GearItem in inventory.items.values():
		if item.definition_id==WorldProgressionCatalog.BOUNTY_REWARD:amount+=1
	return amount
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	AudioServer.set_bus_mute(0,true)
	var hub: PrologueHub=await setup_case("full")
	while hub.gear.inventory.equipment_bag_uids().size()<GearInventory.EQUIPMENT_BAG_CAPACITY:hub.gear.inventory.add_equipment(GearInventory.COMMON_SWORD,0,false)
	var before: PackedByteArray=FileAccess.get_file_as_bytes(flow.profile.save_path)
	check(not hub.economy.quote_bounty(WorldProgressionCatalog.BOUNTY_ID)["can_claim"] and not hub.economy.claim_bounty(WorldProgressionCatalog.BOUNTY_ID),"A full actual equipment bag refuses the reward before spending or granting")
	check(not flow.profile.bounty_claimed and reward_count(hub.gear.inventory)==0 and before==FileAccess.get_file_as_bytes(flow.profile.save_path) and flow.reward_notice.pending.is_empty(),"Full bag keeps receipt, save bytes and notice empty")
	await close_case();hub=await setup_case("rollback")
	before=FileAccess.get_file_as_bytes(flow.profile.save_path)
	var ledger: String=Writer.canonical(GearInventoryCodec.encode(hub.gear.inventory))
	flow.profile._writer.fault_plan={"write_candidate":true}
	check(not hub.economy.claim_bounty(WorldProgressionCatalog.BOUNTY_ID),"Existing writer fault refuses actual bounty transaction")
	check(not flow.profile.bounty_claimed and reward_count(hub.gear.inventory)==0 and before==FileAccess.get_file_as_bytes(flow.profile.save_path) and Writer.canonical(GearInventoryCodec.encode(hub.gear.inventory))==ledger,"Failed save restores exact item/position ledger and original bytes")
	check(flow.reward_notice.pending.is_empty() and flow.reward_notice.displayed.is_empty(),"A failed reward never displays a successful receipt")
	flow.profile._writer.fault_plan.clear()
	check(hub.economy.claim_bounty(WorldProgressionCatalog.BOUNTY_ID),"Fresh actual claim retries successfully after rollback")
	await step(5)
	check(flow.profile.bounty_claimed and reward_count(hub.gear.inventory)==1 and flow.profile.souls==12 and flow.profile.coins==9,"Exactly one promised weapon, unchanged money and no extra material payout")
	check(flow.reward_notice.displayed==[&"bounty"] and flow.reward_notice.panel.visible and flow.reward_notice.title.text.contains("×1") and flow.reward_notice.body.text.contains("Túi trang bị"),"Post-commit notice shows icon/name/count, destination and use")
	check(flow.reward_notice.item_icon.texture!=null and flow.reward_notice.panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Receipt is illustrated and never intercepts combat input")
	var size: Vector2i=root.size;var logical: Vector2i=root.content_scale_size
	for extent: Vector2i in [Vector2i(1152,648),Vector2i(800,600)]:
		root.size=extent;root.content_scale_size=extent;await step(5)
		check(root.get_visible_rect().grow(1).encloses(flow.reward_notice.panel.get_global_rect()),"Receipt fits its actual logical viewport")
	root.size=size;root.content_scale_size=logical;await step(2)
	check(not hub.economy.claim_bounty(WorldProgressionCatalog.BOUNTY_ID),"Repeated claim is rejected by the unchanged owner")
	flow.profile.changed.emit();await step(2)
	check(flow.reward_notice.displayed.size()==1 and flow.reward_notice.pending.is_empty() and reward_count(hub.gear.inventory)==1,"Repeated publication produces no duplicate notice, item or receipt")
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen;screen.open_map();await step(3)
	var nav: QuestNavigator=screen.get_node("QuestNavigator");nav.track(PowerProgressionGuide.ID)
	screen.journal._choose_quest(OpeningRewardCatalog.ID);await step(3)
	check(screen.journal.reward_list.get_child_count()==1 and not screen.journal.action_button.visible,"Actual M history renders the saved reward and offers no second claim")
	check(nav.tracked_id()==PowerProgressionGuide.ID,"Reading receipt history preserves the current navigation target")
	check(not screen.journal.detail_fields[&"objective"].get_parent().visible and screen.journal.reward_list.visible,"Receipt history starts with the actual illustrated rewards, without generic quest sections")
	screen.journal._choose_quest(PowerProgressionGuide.ID);await step(3)
	check(screen.journal.detail_fields[&"objective"].get_parent().visible and screen.journal.detail_fields[&"requirements"].get_parent().visible and screen.journal.detail_scroll.scroll_vertical==0,"Switching back restores power conditions and starts the newly chosen topic at its top")
	var fresh: Dictionary=OpeningRewardCatalog.bounty(hub.gear.inventory,false)
	check(fresh["balance"].begins_with("Chưa nhận") and not fresh["balance"].contains("không còn"),"Unclaimed preview is not described as a lost reward")
	before=FileAccess.get_file_as_bytes(flow.profile.save_path);var serial: int=int(get_meta(&"dungeon_combat_serial",0))
	for i: int in 5:OpeningRewardCatalog.journal_row(flow.profile,hub.gear.inventory)
	check(before==FileAccess.get_file_as_bytes(flow.profile.save_path) and serial==int(get_meta(&"dungeon_combat_serial",0)),"History projections do not save, spend or allocate UIDs")
	check(OpeningRewardCatalog.source_hint(&"crystal").contains("Golem") and OpeningRewardCatalog.source_hint(&"crystal").contains("rương") and OpeningRewardCatalog.source_hint(&"crystal").contains("ngẫu nhiên"),"Crystal route names its actual chest/Golem pools without guaranteeing loot")
	check(MaterialCatalog.WORLD_CHEST_POOL==[&"metal",&"dust",&"crystal",&"healing_herb",&"linen_fiber",&"detox_root",&"enhancement_stone_1",&"enhancement_stone_2"],"Centralized source catalog preserves exact existing chest pool and RNG order")
	var path: String=flow.profile.save_path;screen.close();await close_case()
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=path;root.add_child(flow);await step(14);hub=flow.active_scene as PrologueHub
	check(flow.profile.bounty_claimed and reward_count(hub.gear.inventory)==1 and flow.reward_notice.pending.is_empty() and flow.reward_notice.displayed.is_empty(),"Cold product load retains earned reward without replaying its toast")
	await close_case();hub=await setup_case("cache")
	flow.profile.material_stash[&"dust"]=MaterialCatalog.MAX_COUNT-1
	check(not hub.exploration.progress.claim()["ok"] and not OpeningExplorationProgress.state_for(flow.profile)["cache_claimed"],"Full stash rejects optional cache without consuming its receipt")
	flow.profile.material_stash[&"dust"]=0;before=FileAccess.get_file_as_bytes(flow.profile.save_path)
	flow.profile._writer.fault_plan={"write_candidate":true}
	check(not hub.exploration.progress.claim()["ok"] and flow.profile.material_stash[&"dust"]==0 and before==FileAccess.get_file_as_bytes(flow.profile.save_path),"Cache writer failure restores exact stash and original save")
	check(flow.reward_notice.pending.is_empty(),"Failed cache does not announce a reward")
	flow.profile._writer.fault_plan.clear();check(hub.exploration.progress.claim()["ok"],"Cache retries through its existing transaction owner")
	await step(4)
	check(flow.profile.material_stash[&"dust"]==OpeningExplorationProgress.REWARD and hub.gear.inventory.materials[&"dust"]==0 and flow.reward_notice.displayed==[&"p03_cache"],"Exactly the existing cache quantity goes to stash and is announced once")
	check(not hub.exploration.progress.claim()["ok"] and flow.profile.material_stash[&"dust"]==OpeningExplorationProgress.REWARD,"Repeated cache interaction cannot duplicate material")
	await close_case();hub=await setup_case("combat_notice")
	var context: Dictionary={"safe":false,"inventory":hub.gear.inventory}
	flow.reward_notice.context_provider=func() -> Dictionary:return context
	var pickup: LootPickup=hub.gear.loot.spawn(&"material",&"crystal",hub.player.global_position,2);pickup.automatic=false
	check(pickup.collect() and not pickup.collect(),"Actual fixture pickup applies once before announcing collection")
	flow.reward_notice.acquired(pickup);await step(4)
	check(not flow.reward_notice.panel.visible and flow.reward_notice.pending.size()==1 and hub.gear.inventory.materials[&"crystal"]==2,"Combat/unsafe context defers notice without losing the collected material")
	context["safe"]=true;await step(4)
	check(flow.reward_notice.panel.visible and flow.reward_notice.title.text.contains("×2") and flow.reward_notice.body.text.contains("Điều tức"),"Safe context shows real collected count and its actual training use")
	context["safe"]=false;await step(2);check(not flow.reward_notice.panel.visible,"A new unsafe/combat state hides an active notice")
	await close_case();hub=await setup_case("broken_hint")
	var broken:=GearItem.new();broken.uid=CombatIds.next_id();broken.kind=&"weapon";broken.definition_id=&"storm_arcane_staff";broken.quality=GearItem.Quality.COMMON;broken.broken=true;broken.loot_rolled=true
	pickup=hub.gear.loot.spawn_gear(broken,hub.player.global_position);pickup.automatic=false
	check(pickup.collect(),"Explicit broken-loot fixture collects into the actual inventory")
	var hint: Dictionary=OpeningRewardCatalog.pickup(pickup,flow.profile,hub.gear.inventory)
	check(hint["destination"].contains("món hỏng") and hint["use"].contains("Sửa: 2 kim loại + 1 Bột Phép") and hint["use"].contains("chưa trang bị được"),"Broken loot reads the actual repair quote instead of promising immediate equip")
	await close_case();await root.get_node("AudioManager").shutdown()
	print("RESULT OpeningRewards checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

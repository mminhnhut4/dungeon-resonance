extends SceneTree
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func step(count: int) -> void:
	for i: int in count:await physics_frame;await process_frame
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("REWARDS_EXPECTED")))
	var original: Dictionary=Writer.read_json(OS.get_environment("REWARDS_ORIGINAL_PROFILE"));var path: String="user://newcomer-item1/profile.json"
	check(expected["complete"] and expected["failures"]==0 and FileAccess.get_sha256(path)==expected["profile_sha256"] and Writer.seal_valid(original),"Only byte-identical actually played item2 save enters cold verification")
	var flow: GameFlow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=path;root.add_child(flow);await step(16)
	var hub: ExteriorHub=flow.active_scene as ExteriorHub
	check(not flow.profile.read_only and not flow.profile.hub_inventory_quarantined,"Actual product accepts the earned profile without quarantine")
	check(Writer.canonical(GearInventoryCodec.encode(hub.gear.inventory))==Writer.canonical(original["hub_inventory"]),"All carried UIDs, affix bits, slots and material counts survive cold load exactly")
	check(flow.profile.coins==int(original["coins"]) and flow.profile.souls==int(original["souls"]),"Both actual wallets survive without a duplicated payout")
	var repaired: GearItem=hub.gear.inventory.items.get(int(expected["repaired_uid"]))
	check(repaired!=null and repaired.can_equip() and not repaired.broken,"Paid repair remains usable on the same UID")
	check(OpeningExplorationProgress.state_for(flow.profile)["cache_claimed"] and hub.gear.inventory.materials[&"crystal"]>0,"One-time receipt and genuinely acquired crystal survive return and cold load")
	check(flow.reward_notice.pending.is_empty() and flow.reward_notice.displayed.is_empty(),"Cold startup never replays old receipt notices")
	var loaded: Dictionary=Writer.read_json(path);check(Writer.seal_valid(loaded),"Post-startup file retains its exact-number seal")
	var prior_meta: Dictionary=original["profile_commit"].duplicate(true);var next_meta: Dictionary=loaded["profile_commit"].duplicate(true)
	var revision_delta: int=int(next_meta["revision"])-int(prior_meta["revision"])
	for id: String in ["revision","seal"]:prior_meta.erase(id);next_meta.erase(id)
	check(revision_delta>=0 and revision_delta<=1 and Writer.canonical(prior_meta)==Writer.canonical(next_meta),"Load bookkeeping changes at most one revision/seal, retaining exact-number metadata")
	original.erase("profile_commit");loaded.erase("profile_commit")
	check(Writer.canonical(original)==Writer.canonical(loaded),"Entire authoritative payload remains unchanged across actual cold startup")
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path);var count: int=OpeningRewardCatalog.received(flow.profile,hub.gear.inventory).size()
	for i: int in 8:check(OpeningRewardCatalog.received(flow.profile,hub.gear.inventory).size()==count,"Repeated history is read-only and stable")
	check(not hub.economy.claim_bounty(WorldProgressionCatalog.BOUNTY_ID) and not hub.exploration.progress.claim()["ok"],"Repeated bounty/cache claims stay unavailable after cold load")
	check(FileAccess.get_file_as_bytes(path)==bytes,"Reading history and refusing repeated rewards does not write, spend or grant")
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen;screen.open_map();await step(3)
	screen.journal._choose_quest(OpeningRewardCatalog.ID);await step(3)
	check(screen.journal.selected_id==OpeningRewardCatalog.ID and screen.journal.reward_list.get_child_count()==count and not screen.journal.action_button.visible,"Actual M journal restores the correct illustrated receipts and no claim action")
	var data:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("cold-verification.json"),FileAccess.WRITE)
	data.store_string(JSON.stringify({"checks":checks,"failures":failures,"receipt_count":count,"revision_delta":revision_delta,"payload_unchanged":Writer.canonical(original)==Writer.canonical(loaded),"repaired_uid":repaired.uid,"crystals":hub.gear.inventory.materials[&"crystal"]},"\t",true,true));data.close()
	screen.close();flow.queue_free();await step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT OpeningRewardsCold checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

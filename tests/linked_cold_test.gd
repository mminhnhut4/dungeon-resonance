extends SceneTree
## New process, exact earned gameplay save; no resource/progression fixtures.
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
	AudioServer.set_bus_mute(0,true)
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("LINKED_EXPECTED")))
	var original: Dictionary=Writer.read_json(OS.get_environment("LINKED_ORIGINAL_PROFILE"));var path: String="user://newcomer-item1/profile.json"
	check(expected["complete"] and expected["failures"]==0 and FileAccess.get_sha256(path)==expected["profile_sha256"] and Writer.seal_valid(original),"Cold input is the exact sealed earned item3 gameplay save")
	var flow: GameFlow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=path;root.add_child(flow);await step(16)
	var hub: ExteriorHub=flow.active_scene as ExteriorHub
	check(not flow.profile.read_only and not flow.profile.hub_inventory_quarantined,"Product loads the earned profile without quarantine")
	check(Writer.canonical(GearInventoryCodec.encode(hub.gear.inventory))==Writer.canonical(original["hub_inventory"]),"Entire carried UID/affix/slot/material ledger survives exactly")
	check(flow.profile.coins==int(original["coins"]) and flow.profile.souls==int(original["souls"]),"Exact money survives without a second payout/fee")
	check(FoundationResonance.unlocked(flow.profile) and hub.player.resonance_controller.foundation_resonance_enabled and FoundationResonance.stage(flow.profile)==3,"Real earned Truc Co derives the link on cold runtime")
	check(Writer.canonical(flow.profile.cultivation_progress)==Writer.canonical(original["cultivation_progress"]),"All earned cultivation counters/receipts remain intact")
	check(flow.profile.cultivation_abilities()["selected_id"]=="tether_sigil" and flow.profile.cultivation_abilities()["learned_ids"]==["tether_sigil"],"Exactly one selected G branch persists; it does not replace Catalyst combat")
	check(hub.player.resonance_controller.get_recipe().id==&"firestorm" and hub.gear.inventory.equipped_weapon_uid==int(expected["after"]["uid"]),"Exact self-installed pair and gear-driven weapon survive return and cold start")
	check(hub.gear.inventory.materials[&"crystal"]==int(original["hub_inventory"]["materials"]["crystal"]) and hub.gear.inventory.materials[&"dust"]==int(original["hub_inventory"]["materials"]["dust"]) and flow.profile.material_stash[&"dust"]==int(original["material_stash"]["dust"]),"Cold load consumes no cultivation/breakthrough bag or stash materials")
	check(flow.reward_notice.pending.is_empty() and flow.reward_notice.displayed.is_empty(),"Previously earned rewards never replay after cold startup")
	var loaded: Dictionary=Writer.read_json(path);check(Writer.seal_valid(loaded),"Cold file keeps exact-number seal")
	var prior_meta: Dictionary=original["profile_commit"].duplicate(true);var next_meta: Dictionary=loaded["profile_commit"].duplicate(true);var revision_delta: int=int(next_meta["revision"])-int(prior_meta["revision"])
	for id: String in ["revision","seal"]:prior_meta.erase(id);next_meta.erase(id)
	check(revision_delta>=0 and revision_delta<=1 and Writer.canonical(prior_meta)==Writer.canonical(next_meta),"At most one load bookkeeping revision/seal, exact-number metadata preserved")
	original.erase("profile_commit");loaded.erase("profile_commit");check(Writer.canonical(original)==Writer.canonical(loaded),"Entire authoritative payload is unchanged by cold startup")
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
	for i: int in 8:
		var lesson: Dictionary=FoundationLesson.view(hub.player.resonance_controller)
		check(lesson["enabled"] and lesson["before"]==0 and lesson["after"]==1,"Repeated projection reports the exact earned enabled link")
	check(not flow.cultivation_session.perform("breakthrough",{"actor_id":"player","branch_id":"cloud_return"}).get("ok",false),"A repeated final branch cannot spend or unlock a second ability")
	check(FileAccess.get_file_as_bytes(path)==bytes,"Reading and rejecting duplicate breakthrough does not write/spend/grant")
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen;screen.open();screen.tabs.current_tab=1;await step(4)
	check(screen.foundation_hint.text==FoundationLesson.view(hub.player.resonance_controller)["text"] and PowerProgressionGuide.row(flow.profile,hub.gear.inventory)["power"]["key"]==&"journey","Cold rune UI and M route agree with actual enabled gameplay")
	var data:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("cold-verification.json"),FileAccess.WRITE);data.store_string(JSON.stringify({"checks":checks,"failures":failures,"revision_delta":revision_delta,"payload_unchanged":Writer.canonical(original)==Writer.canonical(loaded),"stage":3,"recipe":"firestorm","link_enabled":true},"\t",true,true));data.close()
	screen.close();flow.queue_free();await step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT LinkedCold checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

extends SceneTree
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("NEWCOMER_EXPECTED")))
	check(expected["complete_loop"] and expected["failures"]==0,"Only the completed real-input QA save is used; no personal save or fabricated progression fixture")
	var path: String="user://newcomer-item1/profile.json"
	var original: Dictionary=Writer.read_json(OS.get_environment("NEWCOMER_ORIGINAL_PROFILE"))
	check(Writer.seal_valid(original),"Expected earned save is read through the production exact-number/seal reader")
	check(FileAccess.get_sha256(path)==expected["profile_sha256"],"Cold test begins with byte-identical earned QA save")
	var flow: GameFlow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=path;root.add_child(flow)
	for i: int in 12:await physics_frame;await process_frame
	var hub: PrologueHub=flow.active_scene as PrologueHub
	var diagnostic:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("cold-state.json"),FileAccess.WRITE)
	diagnostic.store_string(JSON.stringify({"expected_inventory":original["hub_inventory"],"runtime_inventory":GearInventoryCodec.encode(hub.gear.inventory),"loaded_profile_inventory":flow.profile.hub_inventory},"\t",true,true));diagnostic.close()
	check(not flow.profile.read_only and not flow.profile.hub_inventory_quarantined,"Earned profile loads through actual product without quarantine")
	check(flow.profile.souls==int(expected["souls"]) and flow.profile.coins==int(original["coins"]) and Writer.canonical(flow.profile.permanent_upgrades)==Writer.canonical(expected["upgrades"]),"Cold reload preserves exact currencies and purchased strength")
	check(Writer.canonical(GearInventoryCodec.encode(hub.gear.inventory))==Writer.canonical(original["hub_inventory"]),"Cold reload preserves exact carried counts, item UIDs and enhancement levels against the full-precision persisted source")
	var loaded_bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
	var loaded: Dictionary=Writer.read_json(path)
	check(Writer.seal_valid(loaded),"Cold product save retains a valid full-precision seal")
	var before_commit: Dictionary=original["profile_commit"].duplicate(true);var after_commit: Dictionary=loaded["profile_commit"].duplicate(true)
	var revision_delta: int=int(after_commit["revision"])-int(before_commit["revision"])
	var before_meta: Dictionary=before_commit.duplicate(true);var after_meta: Dictionary=after_commit.duplicate(true)
	for id: String in ["revision","seal"]:before_meta.erase(id);after_meta.erase(id)
	check(revision_delta>=0 and revision_delta<=1 and Writer.canonical(before_meta)==Writer.canonical(after_meta),"Only one load bookkeeping revision/seal may change; exact-number metadata remains identical")
	loaded.erase("profile_commit");original.erase("profile_commit")
	check(Writer.canonical(loaded)==Writer.canonical(original),"Full saved payload survives load unchanged; bookkeeping revision/seal are checked separately")
	diagnostic=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("load-bookkeeping.json"),FileAccess.WRITE);diagnostic.store_string(JSON.stringify({"before":before_commit,"after":after_commit,"payload_unchanged":Writer.canonical(loaded)==Writer.canonical(original)},"\t",true,true));diagnostic.close()
	var last: Dictionary=expected["observations"][-1]["row"]
	for i: int in 8:
		var row: Dictionary=PowerProgressionGuide.row(flow.profile,hub.gear.inventory)
		check(row["power"]["station"]==StringName(last["power"]["station"]) and row["power"]["key"]==StringName(last["power"]["key"]),"Reload keeps the observed next destination")
	check(FileAccess.get_file_as_bytes(path)==loaded_bytes,"Repeated guidance after loading neither spends nor duplicates rewards nor writes progress")
	if flow.profile.bounty_claimed:check(not hub.economy.quote_bounty(WorldProgressionCatalog.BOUNTY_ID)["can_claim"],"Claimed reward is unavailable after cold reload")
	flow.queue_free()
	for i: int in 8:await physics_frame;await process_frame
	await root.get_node("AudioManager").shutdown()
	print("RESULT NewcomerCold checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

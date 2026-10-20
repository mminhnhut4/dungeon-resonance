extends SceneTree
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
const Labels=preload("res://scripts/cultivation/opening_cultivation_labels.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+message)
func step(count: int) -> void:
	for index: int in count:await physics_frame;await process_frame
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	var path: String="user://newcomer-item1/profile.json"
	check(FileAccess.get_sha256(path)==OS.get_environment("POWER_COLD_PROFILE") and FileAccess.get_sha256(path+".npc_v1.json")==OS.get_environment("POWER_COLD_NPC"),"Cold process receives exact sealed post-gameplay QA bytes")
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POWER_COLD_EXPECTED")))
	# Use the sealed profile reader: the summary JSON intentionally has no float-bit table.
	var sealed_source: Dictionary=Writer.read_json(path)
	check(Writer.seal_valid(sealed_source),"Earned source seal and exact-number table validate")
	var flow: GameFlow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=path;root.add_child(flow);await step(12)
	var loaded_hash: String=FileAccess.get_sha256(path)
	var loaded_payload: Dictionary=Writer.read_json(path)
	var source_payload: Dictionary=sealed_source.duplicate(true)
	var source_revision: int=int(source_payload["profile_commit"]["revision"])
	var loaded_revision: int=int(loaded_payload["profile_commit"]["revision"])
	source_payload.erase("profile_commit");loaded_payload.erase("profile_commit")
	check(Writer.canonical(source_payload)==Writer.canonical(loaded_payload) and loaded_revision==source_revision+1,"Normal startup reseals once while preserving the entire earned payload exactly")
	var hub: ExteriorHub=flow.active_scene as ExteriorHub;var actor: Dictionary=flow.profile.cultivation_progress["actors"]["player"]
	check(actor["stage"]==1 and Writer.canonical(actor)==Writer.canonical(expected["actor"]),"Cold load restores the exact actual paid training/stage result")
	check(Writer.canonical(GearInventoryCodec.encode(hub.gear.inventory))==Writer.canonical(sealed_source["hub_inventory"]) and flow.profile.coins==expected["coins"] and flow.profile.souls==expected["souls"],"Cold load preserves exact item numbers, UIDs/materials and both distinct wallets")
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen;screen.open_map();await step(3);screen.journal.select_quest(PowerProgressionGuide.ID);await step(3)
	var row: Dictionary=PowerProgressionGuide.row(flow.profile,hub.gear.inventory)
	check(screen.journal.guide_label.is_visible_in_tree() and screen.journal.guide_label.text==row["power"]["guidance"],"Cold mission UI displays current source/resource guidance")
	check(Labels.breakthrough_action(1) in row["card"]["action"] and "Luyện Khí II → Luyện Khí III" in row["power"]["current"],"Cold next step uses the real next station action and realm")
	screen.close();flow.queue_free();await step(8);await root.get_node("AudioManager").shutdown()
	check(FileAccess.get_sha256(path)==loaded_hash,"Read-only guidance and cold teardown do not rewrite the post-startup earned profile")
	print("RESULT PowerGuidanceCold checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

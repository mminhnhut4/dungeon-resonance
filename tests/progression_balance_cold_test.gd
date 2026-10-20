extends SceneTree
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
const Supply=preload("res://data/floor_supply_catalog.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+message)
func step(n: int) -> void:
	for i: int in n:await physics_frame;await process_frame
func run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	root.unfocusable=true;AudioServer.set_bus_mute(0,true)
	var path: String="user://newcomer-item1/profile.json"
	check(FileAccess.get_sha256(path)==OS.get_environment("BALANCE_COLD_PROFILE") and FileAccess.get_sha256(path+".npc_v1.json")==OS.get_environment("BALANCE_COLD_NPC"),"Cold process starts from exact completed native profile/NPC bytes")
	var sealed: Dictionary=Writer.read_json(path)
	check(Writer.seal_valid(sealed),"Earned native profile seal validates")
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BALANCE_COLD_EXPECTED")))
	var flow: GameFlow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=path;root.add_child(flow);await step(12)
	var loaded: Dictionary=Writer.read_json(path);var stable_hash: String=FileAccess.get_sha256(path)
	var before: Dictionary=sealed.duplicate(true);var after: Dictionary=loaded.duplicate(true)
	var revision: int=before["profile_commit"]["revision"];before.erase("profile_commit");after.erase("profile_commit")
	check(Writer.canonical(before)==Writer.canonical(after) and loaded["profile_commit"]["revision"]==revision+1,"Normal startup reseals once without changing the earned payload")
	var hub: ExteriorHub=flow.active_scene as ExteriorHub
	check(Writer.canonical(GearInventoryCodec.encode(hub.gear.inventory))==Writer.canonical(sealed["hub_inventory"]),"Exact carried materials and all owned UIDs survive cold load")
	var added: Array=expected["craft"]["new_uids"]
	check(added.size()==1 and hub.gear.inventory.items.has(int(added[0])) and hub.gear.inventory.items[int(added[0])].definition_id==&"fire" and hub.gear.inventory.items[int(added[0])].source==&"crafted","The actual newly crafted Fire UID remains owned")
	check(flow.depth_progress.can_start_floor(2) and not flow.depth_progress.can_start_floor(3),"Replay does not grant an uncompleted floor shortcut")
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen;screen.open_map();await step(3)
	screen.journal._toggle_supply();await step(3)
	var board: VBoxContainer=screen.journal.supply_board
	check(Supply.VERSION==2 and board.get("cells").size()==3,"Cold source board retains all three version2 rows")
	screen.close();flow.queue_free();await step(8);await root.get_node("AudioManager").shutdown()
	check(FileAccess.get_sha256(path)==stable_hash,"Read-only board and teardown do not replay source grants or write the profile")
	print("RESULT ProgressionBalanceCold checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

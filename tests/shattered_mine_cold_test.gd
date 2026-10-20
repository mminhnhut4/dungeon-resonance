extends SceneTree
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+message)
func step(n: int) -> void:
	for i: int in n:await physics_frame;await process_frame
func run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	var path: String="user://newcomer-item1/profile.json"
	check(FileAccess.get_sha256(path)==OS.get_environment("MINE_SOURCE_PROFILE") and FileAccess.get_sha256(path+".npc_v1.json")==OS.get_environment("MINE_SOURCE_NPC"),"Exact finalized actual mine gameplay pair before load")
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("MINE_EXPECTED_RESULT")))
	var sealed: Dictionary=Writer.read_json(path)
	check(Writer.seal_valid(sealed),"Existing sealed reader restores exact float64 table")
	var persisted: Dictionary=sealed["hub_inventory"]
	check(expected["complete"] and expected["craft"]["new_uids"].size()==1,"Completed mine trace includes one real craft")
	var flow: GameFlow=preload("res://scenes/maps/shattered_mine_entry.tscn").instantiate();flow.save_path_override=path;root.add_child(flow);current_scene=flow;await step(15)
	var hub: PrologueHub=flow.active_scene as PrologueHub
	check(hub!=null and flow.profile.profile_version==2 and not flow.profile.read_only and not flow.profile.hub_inventory_quarantined,"Cold prototype startup accepts the sealed profile")
	check(flow.npc_life!=null and not flow.npc_life.read_only,"Existing NPC owner accepts its final sidecar")
	var inv: GearInventory=hub.gear.inventory
	check(Writer.canonical(Writer.normalized(GearInventoryCodec.encode(inv)))==Writer.canonical(Writer.normalized(persisted)),"Entire cold inventory equals exact sealed post-craft ledger")
	var uid: int=int(expected["craft"]["new_uids"][0])
	check(inv.items.has(uid) and inv.items[uid].kind==&"rune" and inv.items[uid].definition_id==&"fire" and inv.items[uid].source==&"crafted","The actual crafted Fire UID survives cold load once")
	check(hub.rune_learning.quote(&"fire")["learned"],"Existing rune knowledge survives")
	check(inv.materials[&"dust"]==int(expected["craft"]["after"]["materials"]["dust"]) and inv.materials[&"crystal"]==int(expected["craft"]["after"]["materials"]["crystal"]),"Material spending persists with genuine random loot retained")
	check(not flow.depth_expansion_enabled and flow.depth_progress==null,"Prototype still does not replace or open a numbered floor")
	flow.queue_free();current_scene=null;await step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT ShatteredMineCold checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

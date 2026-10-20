extends SceneTree
## Cold process on the exact earned gameplay files; no seeded branch fixtures.
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
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("STORY_EXPECTED")))
	var original: Dictionary=Writer.read_json(OS.get_environment("STORY_ORIGINAL_PROFILE"));var original_npc: Dictionary=Writer.read_json(OS.get_environment("STORY_ORIGINAL_NPC"));var path: String="user://newcomer-item1/profile.json"
	check(expected["complete"] and expected["failures"]==0 and FileAccess.get_sha256(path)==expected["profile_sha256"] and Writer.seal_valid(original),"Cold profile is byte-identical to the actually played and sealed rescue route")
	check(FileAccess.get_sha256(path+".npc_v1.json")==expected["npc_sha256"] and NpcWorldState.valid(original_npc),"Exact canonical NPC sidecar comes from the same played route")
	var flow: GameFlow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=path;root.add_child(flow);await step(8)
	var hub: ExteriorHub=flow.active_scene as ExteriorHub;var progress: TanDangProgress=hub.tan_dang.progress
	check(not flow.profile.read_only and not hub.npc_population.state.read_only and not flow.profile.hub_inventory_quarantined,"Both existing owners accept the complete earned save without quarantine")
	check(Writer.canonical(GearInventoryCodec.encode(hub.gear.inventory))==Writer.canonical(original["hub_inventory"]),"Every carried UID/affix/slot/material survives actual cold load exactly")
	check(flow.profile.coins==int(original["coins"]) and flow.profile.souls==int(original["souls"]) and Writer.canonical(flow.profile.material_stash)==Writer.canonical(original["material_stash"]),"Exact two wallets and aid storage survive without duplicate reward")
	var s: Dictionary=progress.state()
	check(s["choice"]=="rescue" and s["core"]=="spent" and s["lamp"]=="broken" and s["rewards"]==["q1","q2","q3"] and s["contribution"]==6,"One irreversible rescue/core/gate result and all finite quest receipts survive")
	check(s["recipe_claimed"] and not s["recipe_paid"] and s["membership"]=="guest" and s["declined"],"Existing recipe remains free and independent guest choice stays selected")
	check(FoundationResonance.unlocked(flow.profile) and hub.player.resonance_controller.get_recipe().id==&"firestorm","Previous earned Truc Co and self-installed primary combat pair are preserved")
	for id: String in TanDangProgress.NPC_IDS:
		var saved: Dictionary=original_npc["records"][id];var current: Dictionary=hub.npc_population.state.records[id]
		var stable: bool=true
		for field: String in ["death","legacy_death","karma","causality","trust","fear","debt","room"]:stable=stable and Writer.canonical(saved[field])==Writer.canonical(current[field])
		check(stable and progress.alive(id),"Canonical life/memory/trust/room survive for the same authored person: "+id)
	check(hub.npc_population.state.karma(TanDangProgress.DU)["rescued"] and hub.npc_population.state.karma(TanDangProgress.DU)["assistance_used"],"Saved person's gratitude and consumed lifetime gift both survive")
	var loaded: Dictionary=Writer.read_json(path);check(Writer.seal_valid(loaded),"Cold profile retains exact-number numeric seal")
	var prior_meta: Dictionary=original["profile_commit"].duplicate(true);var next_meta: Dictionary=loaded["profile_commit"].duplicate(true);var revision_delta: int=int(next_meta["revision"])-int(prior_meta["revision"])
	for id: String in ["revision","seal"]:prior_meta.erase(id);next_meta.erase(id)
	check(revision_delta>=0 and revision_delta<=1 and Writer.canonical(prior_meta)==Writer.canonical(next_meta),"Load bookkeeping is at most one revision/seal, preserving exact-number metadata")
	original.erase("profile_commit");loaded.erase("profile_commit");check(Writer.canonical(original)==Writer.canonical(loaded),"All authoritative profile payload stays exactly earned")
	var profile_bytes: PackedByteArray=FileAccess.get_file_as_bytes(path);var npc_bytes: PackedByteArray=FileAccess.get_file_as_bytes(path+".npc_v1.json")
	for i: int in 4:
		var rows: Array[Dictionary]=TanDangProgress.rows(flow.profile);var relation: Array[Dictionary]=hub.tan_dang.relation_rows()
		check(rows.size()==3 and rows[2]["done"] and not relation.is_empty(),"Repeated journal projects completed facts and current relationship state")
	for action: String in ["q1_reward","q3_reward","choice_gate","recipe","support","assist"]:
		check(not progress.apply(action,TanDangProgress.DU,TanDangProgress.DU).get("ok",false),"Cold repeated story/aid request is refused without reward: "+action)
	check(FileAccess.get_file_as_bytes(path)==profile_bytes and FileAccess.get_file_as_bytes(path+".npc_v1.json")==npc_bytes,"Projection and refused duplicate actions do not write either file or spend/grant")
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen;screen.open_map();await step(3);screen.journal._choose_quest(&"tan_dang_relations");await step(3)
	check(screen.journal.selected_id==&"tan_dang_relations" and screen.journal.objective_label.visible and screen.journal.objective_label.text.contains("Đã nhận 2 Sợi Vải Lanh"),"Existing M journal renders loaded relationship memory")
	var data:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("cold-verification.json"),FileAccess.WRITE);data.store_string(JSON.stringify({"checks":checks,"failures":failures,"revision_delta":revision_delta,"profile_payload_unchanged":Writer.canonical(original)==Writer.canonical(loaded),"choice":s["choice"],"aid_used":true,"contribution":s["contribution"]},"\t",true,true));data.close()
	screen.close();flow.queue_free();await step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT StoryCold checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

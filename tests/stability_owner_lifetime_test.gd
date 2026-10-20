extends SceneTree
## Isolated lifetime diagnostic. No forced-free RefCounted or personal profile.
var checks: int=0
var failures: int=0
var rows: Array[Dictionary]=[]
func _initialize() -> void:_run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)
func _step(n: int) -> void:
	for _i: int in n:await process_frame;await physics_frame
func _pair() -> Dictionary:
	var profile:=SanctuaryProfile.new()
	var social:=OpeningSocialRuntime.new()
	var profile_refs_before: int=profile.get_reference_count()
	var social_refs_before: int=social.get_reference_count()
	var ok: bool=social.configure(profile)
	var refs: Dictionary={"profile_before":profile_refs_before,"profile_after":profile.get_reference_count(),"social_before":social_refs_before,"social_after":social.get_reference_count()}
	var p: WeakRef=weakref(profile);var s: WeakRef=weakref(social)
	social=null;profile=null
	return {"configured":ok,"refs":refs,"profile_released":p.get_ref()==null,"social_released":s.get_ref()==null}
func _cycle(index: int) -> Dictionary:
	var flow: GameFlow=preload("res://scenes/maps/prologue_hub.tscn").instantiate()
	flow.save_path_override="user://stability-lifetime/profile.json";root.add_child(flow)
	await _step(8)
	var refs: Dictionary={"flow":weakref(flow),"profile":weakref(flow.profile),"social":weakref(flow.social_runtime),"npc":weakref(flow.npc_life),"depth":weakref(flow.depth_progress),"inventory":weakref((flow.active_scene as PrologueHub).gear.inventory)}
	flow.queue_free();flow=null;await _step(10)
	var gone: Dictionary={}
	for key: String in refs:gone[key]=refs[key].get_ref()==null
	refs.clear();await _step(2)
	return {"cycle":index,"released":gone,"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	var pair: Dictionary=_pair();print("LIFETIME_PAIR ",JSON.stringify(pair))
	_check(pair["configured"] and pair["profile_released"] and pair["social_released"],"Social/profile composition releases both RefCounted owners after their external owners leave")
	rows.append(await _cycle(-1))
	for i: int in 10:
		var row: Dictionary=await _cycle(i);rows.append(row);print("LIFETIME_CYCLE ",JSON.stringify(row))
		for key: String in row["released"]:_check(row["released"][key],"Cycle %d releases %s"%[i,key])
	var first: Dictionary=rows[0];var last: Dictionary=rows[-1]
	_check(last["objects"]==first["objects"] and last["resources"]==first["resources"] and last["nodes"]==first["nodes"] and last["orphans"]==first["orphans"],"Ten GameFlow lifetimes return to the warmed object/resource/node/orphan counts")
	var f:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("owner-lifetime.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"pair":pair,"cycles":rows,"checks":checks,"failures":failures},"\t"));f.close()
	print("RESULT StabilityOwnerLifetime checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

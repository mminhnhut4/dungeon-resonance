extends SceneTree
## Isolated QA only: protocol fault boundaries, cold readers, no gameplay scene.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
const SCOPE: String = "tan_dang_mon_v1"
const DU: String = "tan_dang_du_hanh"
const LAM: String = "tan_dang_lam_tuoc"
var checks: int = 0
var failures: int = 0
var directory: String = ""
var notifications: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)

static func _scope_valid(value: Variant) -> bool:
	return value is Dictionary and value.size()==3 and value.get("schema")==1 and value.get("choice") in ["gate","rescue","reward","aid"] and NpcWorldState._integer(value.get("contribution"),0,100)

func _fixture(label: String) -> Dictionary:
	var profile := SanctuaryProfile.new()
	profile.save_path=directory+"/"+label+"/profile.json"
	profile.souls=200; profile.material_stash[&"linen_fiber"]=8
	profile.boss_proofs[&"golem"]=1
	_check(profile.save(),label+": initial profile")
	_check(profile.commit_cultivation(Model.initial_proposal(Model.new_progress(7),profile.material_stash,profile.souls,profile.boss_proofs)),label+": owner promotes profile format2")
	profile.register_extension_validator(SCOPE,_scope_valid)
	var npc := NpcWorldState.new()
	npc.save_path=profile.save_path+".npc_v1.json"
	_check(npc.save(),label+": durable NPC5 authority")
	return {"profile":profile,"npc":npc}

func _gate(npc: NpcWorldState) -> Dictionary:
	return npc.propose_sect_changes({DU:{"death_context":"core_withdrawal","killer_id":"core_reclaimed"},LAM:{"trust_delta":-2}})

func _commit(profile: SanctuaryProfile,npc: NpcWorldState,proposal: Dictionary) -> Dictionary:
	return profile.commit_npc_extension_event(SCOPE,"choice_gate_v1",{"schema":1,"choice":"gate","contribution":3},0,npc,proposal)

func _cold(path: String) -> Dictionary:
	var profile := SanctuaryProfile.new()
	profile.save_path=path; profile.register_extension_validator(SCOPE,_scope_valid)
	var loaded: bool=profile.load_profile()
	var npc := NpcWorldState.new(); npc.save_path=path+".npc_v1.json"
	var npc_loaded: bool=npc.load_state() if loaded else false
	return {"profile":profile,"npc":npc,"loaded":loaded and npc_loaded}

func _raw(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func _write(path: String,text: String) -> void:
	assert(path.begins_with(directory+"/"))
	var file: FileAccess=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text); file.flush(); file.close()

func _run() -> void:
	var allowed: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: dedicated QA data root required"); quit(2); return
	directory="user://verification/tan_dang_compound_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	_success_and_replay()
	_faults()
	_ambiguous_recovery()
	_knowledge_and_aid()
	print("RESULT tan_dang_compound_writer checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func _success_and_replay() -> void:
	var fixture: Dictionary=_fixture("success")
	var profile: SanctuaryProfile=fixture["profile"]
	var npc: NpcWorldState=fixture["npc"]
	var initial_npc: Dictionary=npc.snapshot()
	var before_profile: PackedByteArray=_raw(profile.save_path)
	var before_npc: PackedByteArray=_raw(npc.save_path)
	var proposal: Dictionary=_gate(npc)
	_check(not proposal.is_empty() and npc.snapshot()==initial_npc and _raw(profile.save_path)==before_profile and _raw(npc.save_path)==before_npc,"Quote/cancel is pure and leaves both files byte-exact")
	notifications=0
	profile.changed.connect(func() -> void: notifications+=1)
	npc.activity_changed.connect(func(_id: String,_mode: String) -> void: notifications+=1)
	var result: Dictionary=_commit(profile,npc,proposal)
	if not result.get("ok",false): print("COMPOUND_DIAGNOSTIC="+JSON.stringify(result))
	_check(result.get("ok",false) and result.get("status")=="committed","One compound command commits")
	_check(npc.records[DU]["mode"]=="dead" and npc.records[DU]["death"]["context"]=="core_withdrawal" and not npc.karma(DU)["player_murdered"],"Story death records distinct canonical cause")
	_check(profile.extension_state(SCOPE).get("choice")=="gate" and notifications==3,"Signals publish only after two authorities commit")
	var after_profile: PackedByteArray=_raw(profile.save_path)
	var after_npc: PackedByteArray=_raw(npc.save_path)
	result=_commit(profile,npc,proposal)
	_check(result.get("status")=="already_committed" and _raw(profile.save_path)==after_profile and _raw(npc.save_path)==after_npc and notifications==3,"Exact receipt replay has no save or signal")
	var cold: Dictionary=_cold(profile.save_path)
	_check(cold["loaded"] and cold["npc"].records[DU]["mode"]=="dead" and cold["profile"].extension_revision(SCOPE)==1,"Fresh owners agree on committed branch and death")
	_check(not profile.commit_extension_event(SCOPE,"bypass",{},0,{"schema":1,"choice":"rescue","contribution":3},1).get("ok",false),"Ordinary extension entry cannot bypass NPC participant")
	_check(npc.propose_sect_changes({DU:{"gratitude_reason":"rescued","gratitude_delta":1}}).is_empty(),"Dead NPC cannot be rescued by a stale choice")

func _faults() -> void:
	var points: Array[String]=["write_candidate","write_npc_candidate","write_decision","rename_decision","compound_after_profile_candidate","compound_after_npc_candidate","compound_after_decision","compound_profile_move","compound_after_profile_move","compound_profile_commit","compound_after_profile_commit","compound_npc_move","compound_after_npc_move","compound_npc_commit","compound_after_npc_commit","compound_cleanup"]
	var before_decision: Array[String]=["write_candidate","write_npc_candidate","write_decision","rename_decision","compound_after_profile_candidate","compound_after_npc_candidate"]
	for point: String in points:
		var fixture: Dictionary=_fixture(point)
		var profile: SanctuaryProfile=fixture["profile"]
		var npc: NpcWorldState=fixture["npc"]
		var before: Dictionary=npc.snapshot()
		var profile_before: PackedByteArray=_raw(profile.save_path)
		var npc_before: PackedByteArray=_raw(npc.save_path)
		notifications=0
		profile.changed.connect(func() -> void: notifications+=1)
		npc.activity_changed.connect(func(_id: String,_mode: String) -> void: notifications+=1)
		profile._writer.fault_plan={point:true}
		var result: Dictionary=_commit(profile,npc,_gate(npc))
		_check(not result.get("ok",false) and npc.snapshot()==before and notifications==0,point+": no provisional life or signal escapes")
		if result.get("status")=="quarantined":
			_check(profile.read_only and npc.read_only and not npc.save() and not profile.save(),point+": uncertain pair fences both live writers")
		if point in before_decision:
			_check(_raw(profile.save_path)==profile_before and _raw(npc.save_path)==npc_before,point+": predecision error keeps exact primaries")
		var cold: Dictionary=_cold(profile.save_path)
		_check(cold["loaded"],point+": cold recovery succeeds")
		if not cold["loaded"]: continue
		var expect_dead: bool=point not in before_decision
		_check((cold["npc"].records[DU]["mode"]=="dead")==expect_dead and (cold["profile"].extension_revision(SCOPE)==1)==expect_dead,point+": recovery yields old/old or new/new")
		var stable_profile: PackedByteArray=_raw(profile.save_path)
		var stable_npc: PackedByteArray=_raw(npc.save_path)
		var second: Dictionary=_cold(profile.save_path)
		_check(second["loaded"] and _raw(profile.save_path)==stable_profile and _raw(npc.save_path)==stable_npc,point+": second cold load does not repeat effects")

func _ambiguous_recovery() -> void:
	for variant: String in ["missing_candidate","future_npc","changed_primary"]:
		var fixture: Dictionary=_fixture("ambiguous_"+variant)
		var profile: SanctuaryProfile=fixture["profile"]
		var npc: NpcWorldState=fixture["npc"]
		profile._writer.fault_plan={"compound_after_profile_commit":true}
		_check(not _commit(profile,npc,_gate(npc)).get("ok",false),variant+": stop between two primaries")
		if variant=="missing_candidate":
			DirAccess.remove_absolute(npc.save_path+".compound.tmp")
		elif variant=="future_npc":
			var future: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(npc.save_path)); future["npc_schema"]=99
			_write(npc.save_path,JSON.stringify(future))
		else: _write(npc.save_path,FileAccess.get_file_as_string(npc.save_path)+" ")
		var profile_bytes: PackedByteArray=_raw(profile.save_path)
		var npc_bytes: PackedByteArray=_raw(npc.save_path)
		var cold: Dictionary=_cold(profile.save_path)
		_check(not cold["loaded"] and cold["profile"].read_only and _raw(profile.save_path)==profile_bytes and _raw(npc.save_path)==npc_bytes,variant+": ambiguous authority quarantined without overwrite")
		var independent := NpcWorldState.new(); independent.save_path=npc.save_path
		_check(not independent.load_state() and independent.read_only and not independent.save(),variant+": standalone NPC loader cannot observe half-commit")

func _knowledge_and_aid() -> void:
	var fixture: Dictionary=_fixture("knowledge")
	var profile: SanctuaryProfile=fixture["profile"]
	var npc: NpcWorldState=fixture["npc"]
	var souls_before: int=profile.souls
	var result: Dictionary=profile.commit_npc_extension_event(SCOPE,"recipe_v1",{"schema":1,"choice":"reward","contribution":0},0,npc,npc.propose_sect_changes({}),"firestorm")
	_check(result.get("ok",false) and profile.discovered_recipes.has(&"firestorm") and profile.archived_recipes.has(&"firestorm") and profile.souls==souls_before,"Knowledge and credit receipt share profile image without Souls cost")
	var before: PackedByteArray=_raw(profile.save_path)
	result=profile.commit_npc_extension_event(SCOPE,"recipe_again",{"schema":1,"choice":"reward","contribution":0},1,npc,npc.propose_sect_changes({}),"firestorm")
	_check(not result.get("ok",false) and _raw(profile.save_path)==before,"Already-known recipe cannot be charged a second time")
	var grateful: Dictionary=npc.propose_sect_changes({LAM:{"gratitude_delta":1,"gratitude_reason":"helped"}})
	_check(profile.commit_npc_extension_event(SCOPE,"thanks",{"schema":1,"choice":"reward","contribution":0},1,npc,grateful).get("ok",false),"Canonical gratitude saved with receipt")
	var linen: int=profile.material_stash[&"linen_fiber"]
	var aid: Dictionary=npc.propose_sect_changes({LAM:{"consume_assistance":true}})
	result=profile.commit_npc_extension_event(SCOPE,"aid",{"schema":1,"choice":"aid","contribution":0},2,npc,aid,"",{"linen_fiber":2})
	_check(result.get("ok",false) and profile.material_stash[&"linen_fiber"]==linen+2 and npc.karma(LAM)["assistance_used"],"Assistance consumes one canonical opportunity and deposits two linen atomically")
	_check(npc.propose_sect_changes({LAM:{"consume_assistance":true}}).is_empty(),"Canonical assistance cannot repeat")

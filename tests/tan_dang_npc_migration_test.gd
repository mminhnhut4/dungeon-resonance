extends SceneTree
## Schema1..4 source fixtures only; no personal save, clocks or game scene.
const VICTIM: String = "pilot_traveler"
const LAM: String = "tan_dang_lam_tuoc"
const DU: String = "tan_dang_du_hanh"
var directory: String = ""
var checks: int = 0
var failures: int = 0

class MigrationFault extends SanctuaryProfile:
	var fail_copy: bool = true
	var primary: String = ""
	func _copy_file(source: String,target: String) -> Error:
		if fail_copy and target.ends_with(".pre_tan_dang_v4.json"): return ERR_CANT_CREATE
		return super._copy_file(source,target)
	func _replace_file(temporary: String,target: String) -> bool:
		if not fail_copy and target==primary: return false
		return super._replace_file(temporary,target)

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)

func _write(path: String,data: Dictionary) -> void:
	assert(path.begins_with(directory+"/"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data)); file.flush(); file.close()

func _source(schema: int) -> Dictionary:
	var source: Dictionary=NpcWorldState.new().snapshot()
	source["npc_schema"]=schema; source["tick"]=100
	var ids: Array[String]=NpcPilotCatalog.LEGACY_IDS if schema==1 else NpcPilotCatalog.SCHEMA_TWO_IDS if schema==2 else NpcPilotCatalog.SCHEMA_THREE_IDS if schema==3 else NpcPilotCatalog.SCHEMA_FOUR_IDS
	for id: String in source["records"].keys():
		if id not in ids: source["records"].erase(id)
	for id: String in ids:
		var record: Dictionary=source["records"][id]
		if schema<3: record.erase("legacy_death")
		if schema==1:
			record.erase("schedule_index"); record.erase("interrupted")
			if id==VICTIM: record["x"]=600.0; record["target"]=800.0
	var victim: Dictionary=source["records"][VICTIM]
	victim["trust"]=-17; victim["fear"]=42; victim["debt"]=4; victim["greeted"]=true; victim["episode"]=3
	var death: Dictionary={"event_id":VICTIM+":3","killer_id":"player","tick":80,"room":"o01_p01","context":"explicit_execution"}
	if schema<3:
		victim["mode"]="dead"; victim["hp"]=0.0; victim["death"]=death
	else:
		victim["mode"]="rest"; victim["hp"]=20.0; victim["legacy_death"]=death
	victim["remaining"]=0
	return source

func _reader(path: String) -> NpcWorldState:
	var state := NpcWorldState.new(); state.save_path=path
	return state

func _run() -> void:
	var allowed: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: dedicated QA data root required"); quit(2); return
	directory="user://verification/tan_dang_migration_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	_migrations()
	_migration_faults()
	_life_and_karma()
	print("RESULT tan_dang_npc_migration checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func _migrations() -> void:
	for schema: int in [1,2,3,4]:
		var source: Dictionary=_source(schema)
		_check(NpcWorldState.valid(source),"Source schema%d accepted before migration" % schema)
		var path: String=directory+"/schema%d/profile.json.npc_v1.json" % schema
		_write(path,source)
		var original: PackedByteArray=FileAccess.get_file_as_bytes(path)
		var state: NpcWorldState=_reader(path)
		_check(state.load_state() and not state.read_only and state.snapshot()["npc_schema"]==NpcWorldState.SCHEMA and state.records.size()==15,"Schema%d reaches the authored fifteen identities without replacing historical lives" % schema)
		var backup: String=path+(".pre_tan_dang_v4.json" if schema==4 else ".pre_sect_v3.json" if schema==3 else ".pre_nonlethal_v%d.json" % schema)
		_check(FileAccess.get_file_as_bytes(backup)==original,"Schema%d backup is exact immutable source" % schema)
		for id: String in source["records"]:
			var old: Dictionary=source["records"][id]
			var current: Dictionary=state.records[id]
			var preserved: bool=true
			for field: String in ["trust","fear","debt","greeted","episode","x","target"]:
				preserved=preserved and current[field]==old[field]
			_check(preserved and NpcWorldState.life_id(id)==id+":opening:1","Stable identity and relationship retained: "+id)
		_check(state.records[VICTIM]["mode"]=="dead" and state.records[VICTIM]["hp"]==0 and state.records[VICTIM]["death"]==state.records[VICTIM]["legacy_death"],"Terminal historical fact never creates a replacement life")
		var terminal: Dictionary=state.records[VICTIM].duplicate(true)
		state.advance_ticks(8); _check(state.recover_after_expedition() and state.records[VICTIM]==terminal,"Ticks and expedition cannot resurrect historical death")
		_check(state.save(),"Explicit checkpoint persists ambient ticks before cold comparison")
		var cold: NpcWorldState=_reader(path)
		_check(cold.load_state() and cold.snapshot()==state.snapshot() and FileAccess.get_file_as_bytes(backup)==original,"Cold load retains exact terminal facts and backup")

func _migration_faults() -> void:
	for fail_copy: bool in [true,false]:
		var path: String=directory+"/migration_fault_%s/profile.json.npc_v1.json" % fail_copy
		_write(path,_source(4))
		var original: PackedByteArray=FileAccess.get_file_as_bytes(path)
		var state: NpcWorldState=_reader(path)
		var fault := MigrationFault.new(); fault.fail_copy=fail_copy; fault.primary=path; state.io=fault
		_check(not state.load_state() and state.read_only and state.records.size()==10 and FileAccess.get_file_as_bytes(path)==original,"Backup/replace failure retains old authority read-only")
		var retry: NpcWorldState=_reader(path)
		_check(retry.load_state() and retry.records.size()==15,"Fresh owner retries transient migration fault once")
	var conflict: String=directory+"/conflict/profile.json.npc_v1.json"
	_write(conflict,_source(4))
	var other: Dictionary=_source(4); other["tick"]=101
	_write(conflict+".pre_tan_dang_v4.json",other)
	var rejected: NpcWorldState=_reader(conflict)
	_check(not rejected.load_state() and rejected.read_only,"Conflicting immutable source blocks migration")
	var future: Dictionary=NpcWorldState.new().snapshot(); future["npc_schema"]=NpcWorldState.SCHEMA+1
	var future_path: String=directory+"/future/profile.json.npc_v1.json"; _write(future_path,future)
	var future_reader: NpcWorldState=_reader(future_path)
	_check(not future_reader.load_state() and future_reader.read_only and not future_reader.save(),"Future NPC schema stays read-only")

func _life_and_karma() -> void:
	var state: NpcWorldState=_reader(directory+"/life/profile.json.npc_v1.json")
	_check(state.save(),"New canonical fixture saved")
	_check(state.receive_hit(LAM,20.0,1300.0,true) and state.retaliation_reason(LAM)=="attacked","Player damage durably records grievance")
	var prior: Dictionary=state.karma(LAM)
	state.advance_ticks(8)
	_check(state.karma(LAM)==prior,"Clock advancement does not erase grievance")
	var proposal: Dictionary=state.propose_sect_changes({LAM:{"trust_delta":10,"gratitude_delta":3,"gratitude_reason":"helped"}})
	_check(not proposal.is_empty() and proposal["after"]["records"][LAM]["trust"]==state.records[LAM]["trust"] and proposal["after"]["records"][LAM]["karma"]["gratitude"]==0,"Story gratitude cannot buy forgiveness after harm")
	_check(state.receive_hit(LAM,1.0,1300.0,true) and state.records[LAM]["mode"]=="downed","New NPC reaches downed without automatic death")
	var token: String=state.decision_token(LAM)
	_check(not state.decide(LAM,token,true,false) and not state.decide(LAM,"stale",true,true),"Kill requires current episode and confirmation")
	_check(state.decide(LAM,token,false) and state.karma(LAM)["spared"] and state.karma(LAM)["gratitude"]==0,"Spare remembers offense without gratitude exploit")
	_check(state.recover_after_expedition() and state.receive_hit(LAM,1.0,1300.0,true),"Spared resident can recover through existing expedition boundary")
	token=state.decision_token(LAM)
	_check(state.decide(LAM,token,true,true) and state.records[LAM]["mode"]=="dead" and state.karma(LAM)["player_murdered"],"Confirmed execution writes canonical terminal cause")
	var terminal: Dictionary=state.records[LAM].duplicate(true)
	state.advance_ticks(8); state.recover_after_expedition()
	_check(state.records[LAM]==terminal and not state.receive_hit(LAM,1.0,1300.0,true),"Terminal new NPC cannot take damage or recover")
	var cold: NpcWorldState=_reader(state.save_path)
	_check(cold.load_state() and cold.records[LAM]==terminal,"Cold load preserves new murder fact")
	var old_id: String=NpcPilotCatalog.ORIGINAL_CULTIVATOR_IDS[0]
	_check(state.receive_hit(old_id,1.0,1500.0,true) and state.records[old_id]["mode"]=="recovering","Existing cultivator keeps nonlethal policy")
	var relocation: Dictionary=state.propose_sect_changes({DU:{"return_home":true}})
	_check(not relocation.is_empty() and relocation["after"]["records"][DU]["room"]=="h00_traveler_hub" and state.records[DU]["room"]=="o01_p03","Return-home proposal changes only canonical future placement")

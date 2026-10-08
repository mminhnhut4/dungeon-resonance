extends "res://tests/npc_nonlethal_recovery_test.gd"
## Exact v3 authority survives additive v4 stewards, including archived causality.
class SectFault extends SanctuaryProfile:
	var primary: String
	var fail_copy: bool=false
	func _copy_file(source: String,target: String) -> Error:
		if fail_copy and target.ends_with(".pre_sect_v3.json"): return ERR_CANT_CREATE
		return super._copy_file(source,target)
	func _replace_file(temporary: String,target: String) -> bool:
		if not fail_copy and target==primary: return false
		return super._replace_file(temporary,target)

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	var allowed: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"): quit(2); return
	directory="user://verification/sect_npc_%d_%d" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	var source: Dictionary=_source()
	_check(NpcWorldState.valid(source),"Exact legacy eight-NPC schema3 fixture is valid")
	var primary: String=directory+"/success/profile.json.npc_v1.json"
	_check(_write(primary,source),"Write v3 QA source")
	var original: PackedByteArray=FileAccess.get_file_as_bytes(primary)
	var state: CountedState=_reader(primary)
	_check(state.load_state() and not state.read_only and state.save_calls==1,"V3 migrates once through owner writer")
	_check(state.snapshot()["npc_schema"]==4 and state.records.size()==10,"V4 adds exactly two stable steward identities")
	for id: String in NpcPilotCatalog.SCHEMA_THREE_IDS:
		_check(state.records[id]==source["records"][id],"Every old relationship/history/motion field survives: "+id)
	for id: String in NpcPilotCatalog.SECT_STEWARD_IDS:
		_check(state.records[id]==NpcPilotCatalog.initial_record(id),"Only the new steward receives its authored initial state: "+id)
	_check(FileAccess.get_file_as_bytes(primary+".pre_sect_v3.json")==original,"Immutable backup retains exact pre-sect bytes")
	var cold: CountedState=_reader(primary)
	_check(cold.load_state() and cold.save_calls==0 and cold.snapshot()==state.snapshot(),"Cold v4 load neither migrates again nor erases history")
	for id: String in NpcPilotCatalog.SECT_STEWARD_IDS:
		state.receive_hit(id,1.0,0.0)
		_check(state.records[id]["mode"]=="recovering" and state.records[id]["death"].is_empty(),"New steward withdraws nonlethally")
		var injured: Dictionary=state.records[id].duplicate(true)
		state.advance_ticks(8)
		_check(state.records[id]==injured,"Ticks do not grant premature recovery")
	_check(state.recover_after_expedition(),"Existing expedition boundary can recover both stewards")
	for id: String in NpcPilotCatalog.SECT_STEWARD_IDS:
		_check(state.records[id]["hp"]==NpcPilotCatalog.MAX_HEALTH*.5 and state.records[id]["trust"]==-2 and state.records[id]["fear"]==6,"Recovery retains the offense and same authored life")
	_check(FileAccess.get_file_as_bytes(primary+".pre_sect_v3.json")==original,"Later updates never rotate pre-sect recovery copy")
	for fail_copy: bool in [true,false]:
		var target: String=directory+"/fault_%s/profile.json.npc_v1.json" % fail_copy
		_check(_write(target,source),"Write isolated migration fault fixture")
		var bytes: PackedByteArray=FileAccess.get_file_as_bytes(target)
		var failed: CountedState=_reader(target)
		var fault:=SectFault.new(); fault.primary=target; fault.fail_copy=fail_copy; failed.io=fault
		_check(not failed.load_state() and failed.read_only and failed.records.size()==8,"Failed copy/replace exposes only read-only old authority")
		_check(FileAccess.get_file_as_bytes(target)==bytes and not failed.save(),"Failed migration preserves exact primary and refuses later overwrite")
		var retry: CountedState=_reader(target)
		_check(retry.load_state() and retry.records.size()==10,"Fresh owner can retry after transient storage failure")
	var conflict: String=directory+"/conflict/profile.json.npc_v1.json"
	var other: Dictionary=source.duplicate(true); other["tick"]=101
	_check(_write(conflict,source) and _write(conflict+".pre_sect_v3.json",other),"Differing immutable backup is explicit conflict fixture")
	var primary_bytes: PackedByteArray=FileAccess.get_file_as_bytes(conflict)
	var backup_bytes: PackedByteArray=FileAccess.get_file_as_bytes(conflict+".pre_sect_v3.json")
	var blocked: CountedState=_reader(conflict)
	_check(not blocked.load_state() and blocked.read_only,"Different immutable source blocks migration")
	_check(FileAccess.get_file_as_bytes(conflict)==primary_bytes and FileAccess.get_file_as_bytes(conflict+".pre_sect_v3.json")==backup_bytes,"Neither side of the backup conflict is overwritten")
	for schema: int in [5,3]:
		var invalid: Dictionary=source.duplicate(true); invalid["npc_schema"]=schema
		if schema==3: invalid["records"].erase("pilot_traveler")
		var target: String=directory+"/invalid_%d/profile.json.npc_v1.json" % schema
		_check(_write(target,invalid),"Write unknown/incomplete authority fixture")
		var bytes: PackedByteArray=FileAccess.get_file_as_bytes(target)
		var rejected: CountedState=_reader(target)
		_check(not rejected.load_state() and rejected.read_only and not rejected.save() and FileAccess.get_file_as_bytes(target)==bytes,"Future/incomplete source is preserved read-only")
	print("RESULT sect_npc_migration checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures==0 else 1)

func _source() -> Dictionary:
	var source: Dictionary=NpcWorldState.new().snapshot()
	source["npc_schema"]=3; source["tick"]=100
	for id: String in NpcPilotCatalog.SECT_STEWARD_IDS: source["records"].erase(id)
	var old: Dictionary=source["records"][RESIDENT]
	old["mode"]="recovering"; old["hp"]=1.0; old["remaining"]=0; old["episode"]=3
	old["trust"]=-17; old["fear"]=42; old["debt"]=4; old["greeted"]=true
	old["legacy_death"]={"event_id":RESIDENT+":2","killer_id":"player","tick":80,"room":"o01_p01","context":"explicit_execution"}
	return source

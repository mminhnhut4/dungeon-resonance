extends "res://tests/tan_dang_living_state_test.gd"
## Schema8 / historical7 / existing-writer fault fixtures. No gameplay timing claim.
class HorizonFault extends SanctuaryProfile:
	var primary: String = ""
	var kind: String = ""
	var writes: int = 0
	func _open_writer(path: String) -> FileAccess:
		writes += 1
		if kind=="open" and path==primary+".tmp": return null
		return super._open_writer(path)
	func _copy_file(source: String,target: String) -> Error:
		if kind=="immutable" and target==primary+".pre_horizon_v7.json": return ERR_CANT_CREATE
		if kind=="backup_copy" and target==primary+".bak.tmp": return ERR_CANT_CREATE
		return super._copy_file(source,target)
	func _replace_file(temporary: String,target: String) -> bool:
		if (kind=="replace" and target==primary) or (kind=="backup_replace" and target==primary+".bak"): return false
		return super._replace_file(temporary,target)

func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"): quit(2);return
	directory = "user://verification/living_horizon_%d_%d"%[OS.get_process_id(),Time.get_ticks_usec()]
	_migrate_seven()
	_strict_shapes()
	_clock_contract()
	for schema: int in [5,6,7]: _pending_historical(schema)
	print("RESULT LivingHorizon checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

func _historical(value: Dictionary,schema: int = 7) -> Dictionary:
	var source: Dictionary = value.duplicate(true)
	source["npc_schema"] = schema
	for id: String in TanDangProgress.NPC_IDS:
		if schema<7: source["records"][id].erase("living")
		else: source["records"][id]["living"].erase("danger_elapsed")
		if schema<6: source["records"][id].erase("causality")
	return source

func _migration_case(source: Dictionary,label: String) -> void:
	_check(NpcWorldState.valid(source) and source["npc_schema"]==7,"Historical source7 is strict and has no elapsed: "+label)
	var path: String = directory+"/migrate_"+label+"/profile.json.npc_v1.json"
	_write_json(path,source)
	var original: PackedByteArray = _raw(path)
	var life: NpcWorldState = _reader(path)
	_check(life.load_state() and life.snapshot()["npc_schema"]==8,"Only committed migration publishes schema8: "+label)
	_check(_raw(path+".pre_horizon_v7.json")==original,"Immutable backup preserves exact source7 bytes: "+label)
	_check(Writer.canonical(_historical(life.snapshot()))==Writer.canonical(source),"Migration preserves every prior field and terminal fact: "+label)
	for id: String in TanDangProgress.NPC_IDS: _check(life.living_view(id)["danger_elapsed"]==0.0,"Unknown historical elapsed initializes zero: "+label+"/"+id)
	var bytes: PackedByteArray = _raw(path)
	var cold: NpcWorldState = _reader(path)
	_check(cold.load_state() and cold.snapshot()==life.snapshot() and _raw(path)==bytes and _raw(path+".pre_horizon_v7.json")==original,"Second cold load preserves current bytes and original backup: "+label)

func _migrate_seven() -> void:
	_migration_case(_historical(NpcWorldState.new().snapshot()),"none")
	var p: TanDangProgress = _danger("donor")
	for _i: int in 70: p.life.advance_living_danger(0.1)
	_check(p.life.credit_living_help(LAM),"Donor has a real owner assistance receipt")
	_migration_case(_historical(p.life.snapshot()),"danger_help")
	_check(p.life.receive_hit(LAM,NpcPilotCatalog.maximum_health(LAM)-1.0,520.0,false) and p.life.resolve_living_event(LAM,"withdrew"),"Donor records assisted injured withdrawal")
	_migration_case(_historical(p.life.snapshot()),"returning")
	_home(p.life)
	_check(p.life.mark_living_greeted(LAM,"forage_help"),"Returned living donor has one acknowledgement")
	# Declared same-room report fixture; no claim about LOS/physical presentation.
	p.life.records[DU]["x"]=1385.0;p.life.records[DU]["target"]=1385.0;p.life.records[DU]["mode"]="rest"
	_check(p.life.report_living_event(DU),"Donor has bounded local knowledge")
	_migration_case(_historical(p.life.snapshot()),"done_wound_ack_report")
	_kill(p,MOC)
	var source: Dictionary = _historical(p.life.snapshot())
	# Existing archived tombstone is already authoritative in NPC7. The schema8
	# bump must not accidentally rerun a generic <SCHEMA resurrection policy.
	var id: String = "pilot_traveler"
	var rec: Dictionary = source["records"][id]
	rec["episode"]=1;rec["mode"]="dead";rec["hp"]=0.0;rec["remaining"]=0;rec["interrupted"]={}
	rec["death"]={"event_id":id+":1","killer_id":"player","tick":source["tick"],"room":rec["room"],"context":"explicit_execution"}
	rec["legacy_death"]=rec["death"].duplicate(true)
	_migration_case(source,"murder_and_archived_death")
	for kind: String in ["immutable","open","backup_copy","backup_replace","replace"]:
		var path: String = directory+"/fault_"+kind+"/profile.json.npc_v1.json"
		_write_json(path,source)
		var original: PackedByteArray = _raw(path)
		var life: NpcWorldState = _reader(path)
		var fault := HorizonFault.new();fault.primary=path;fault.kind=kind;life.io=fault
		_check(not life.load_state() and life.read_only and not life.last_save_ok and life.snapshot()["npc_schema"]==7 and Writer.canonical(life.snapshot())==Writer.canonical(source),"Failed migration retains original7 authority: "+kind)
		_check(_raw(path)==original and not life.save(),"Failed migration never replaces original primary: "+kind)
		var retry: NpcWorldState = _reader(path)
		_check(retry.load_state() and retry.snapshot()["npc_schema"]==8 and _raw(path+".pre_horizon_v7.json")==original,"A fresh successful retry migrates once without overwriting backup: "+kind)
	var conflict: String = directory+"/conflict/profile.json.npc_v1.json"
	_write_json(conflict,source);_write_json(conflict+".pre_horizon_v7.json",_historical(NpcWorldState.new().snapshot()))
	var bytes: PackedByteArray = _raw(conflict);var backup: PackedByteArray = _raw(conflict+".pre_horizon_v7.json")
	var blocked: NpcWorldState = _reader(conflict)
	_check(not blocked.load_state() and blocked.read_only and _raw(conflict)==bytes and _raw(conflict+".pre_horizon_v7.json")==backup,"Conflicting immutable backup is never overwritten")
	var missing: String = directory+"/missing/profile.json.npc_v1.json"
	_write_json(missing+".pre_horizon_v7.json",source);blocked=_reader(missing)
	_check(not blocked.load_state() and blocked.read_only and not blocked.save() and not FileAccess.file_exists(missing),"A backup without primary cannot silently restore an earlier life")

func _strict_shapes() -> void:
	var p: TanDangProgress = _danger("strict")
	var good: Dictionary = p.life.snapshot()
	var seven: Dictionary = _historical(good)
	_check(NpcWorldState.valid(good) and NpcWorldState.valid(seven),"Current8 and historical7 dispatch independently")
	var bad: Dictionary = good.duplicate(true);bad["npc_schema"]=7
	_check(not NpcWorldState.valid(bad),"Schema7 rejects a schema8 living payload")
	bad=seven.duplicate(true);bad["npc_schema"]=8
	_check(not NpcWorldState.valid(bad),"Schema8 requires elapsed rather than guessing shape")
	for value: Variant in [-1.0,35.001,NAN,INF,"12",true,null]:
		bad=good.duplicate(true);bad["records"][LAM]["living"]["danger_elapsed"]=value
		_check(not NpcWorldState.valid(bad),"Strict elapsed rejects invalid scalar: "+str(value))
	for id: String in [MOC,DU]:
		bad=good.duplicate(true);bad["records"][id]["living"]["danger_elapsed"]=1.0
		_check(not NpcWorldState.valid(bad),"Only Lâm can have danger elapsed: "+id)
	bad=NpcWorldState.new().snapshot();bad["records"][LAM]["living"]["danger_elapsed"]=1.0
	_check(not NpcWorldState.valid(bad),"Elapsed cannot precede danger")
	bad=good.duplicate(true);bad["records"][LAM]["living"]["enemy_hp"]=30.0
	_check(not NpcWorldState.valid(bad),"No undeclared enemy persistence sneaks into schema8")
	bad=good.duplicate(true);bad["npc_schema"]=9
	var path: String=directory+"/future/profile.json.npc_v1.json";_write_json(path,bad)
	var bytes: PackedByteArray=_raw(path);var life: NpcWorldState=_reader(path)
	_check(not life.load_state() and life.read_only and not life.save() and _raw(path)==bytes,"Future authority quarantines without migration/write")
	path=directory+"/oversize/profile.json.npc_v1.json"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess=FileAccess.open(path,FileAccess.WRITE);file.store_string(" ".repeat(33000)+Writer.canonical(good));file.close()
	bytes=_raw(path);life=_reader(path)
	_check(not life.load_state() and life.read_only and not life.save() and _raw(path)==bytes,"Oversize source is refused without losing its bytes")

func _clock_contract() -> void:
	var p: TanDangProgress = _danger("clock")
	var life: NpcWorldState = p.life
	var fault := HorizonFault.new();fault.primary=life.save_path;life.io=fault
	watched_life=life;living_signals=0;life.activity_changed.connect(_capture_living_signal)
	var bytes: PackedByteArray=_raw(life.save_path)
	for _i: int in 200: life.advance_living_danger(0.1)
	_check(is_equal_approx(life.living_view(LAM)["danger_elapsed"],20.0) and fault.writes==0 and living_signals==0 and _raw(life.save_path)==bytes,"Per-frame clock is bounded RAM only; no writer or activity signal")
	var before: Dictionary=life.snapshot()
	for delta: float in [-1.0,0.0,NAN,INF]: _check(not life.advance_living_danger(delta) and life.snapshot()==before,"Invalid delta rejects without mutation")
	_check(life.advance_living_danger(1000.0) and is_equal_approx(life.living_view(LAM)["danger_elapsed"],20.1),"Oversized frame is clamped to existing0.1 seconds")
	before=life.snapshot();life.read_only=true
	_check(not life.advance_living_danger(0.1) and life.snapshot()==before,"Read-only clock refuses")
	life.read_only=false;life.compound_locked=true
	_check(not life.advance_living_danger(0.1) and life.snapshot()==before,"Compound lock clock refuses")
	life.compound_locked=false;life.set_active_room(HUB)
	_check(not life.advance_living_danger(0.1) and life.snapshot()==before,"Inactive room clock refuses")
	life.set_active_room(P01)
	for mode: String in ["talk","downed","recovering","dead"]:
		var old_mode: String=life.records[LAM]["mode"];life.records[LAM]["mode"]=mode
		var snapshot_before: Dictionary=life.snapshot()
		_check(not life.advance_living_danger(0.1) and life.snapshot()==snapshot_before,"Unavailable actor mode cannot count: "+mode)
		life.records[LAM]["mode"]=old_mode
	var journal: String=p.profile.save_path+".decision";_write_json(journal,{"commit_schema":2})
	before=life.snapshot()
	_check(not life.advance_living_danger(0.1) and not life.save() and life.snapshot()==before and _raw(life.save_path)==bytes,"Pending undecidable journal fences clock and ambient save")
	DirAccess.remove_absolute(journal) # Only this declared QA fixture journal.
	var view: Dictionary=life.living_view(LAM);view["danger_elapsed"]=0.0
	_check(life.snapshot()==before,"Read view is detached and cannot reset clock")
	_check(life.save(),"Existing owner checkpoints elapsed")
	var cold: NpcWorldState=_reader(life.save_path)
	_check(cold.load_state() and is_equal_approx(cold.living_view(LAM)["danger_elapsed"],20.1),"Cold schema8 load resumes its latest successful checkpoint")
	cold.set_active_room(P01)
	for _i: int in 200: cold.advance_living_danger(0.1)
	_check(cold.living_view(LAM)["danger_elapsed"]==35.0,"Clock saturates at35 rather than overflowing or auto-granting an outcome")
	_check(cold.credit_living_help(LAM) and cold.living_view(LAM)["danger_elapsed"]==35.0,"Actual assistance commit keeps elapsed")
	watched_life=cold;living_signals=0;cold.activity_changed.connect(_capture_living_signal)
	var gratitude: int=cold.karma(LAM)["gratitude"]
	before=cold.snapshot();bytes=_raw(cold.save_path);fault=HorizonFault.new();fault.primary=cold.save_path;fault.kind="replace";cold.io=fault
	_check(not cold.resolve_living_event(LAM,"withdrew") and cold.snapshot()==before and cold.living_view(LAM)["danger_elapsed"]==35.0 and _raw(cold.save_path)==bytes and living_signals==0,"Failed terminal commit rolls back result but never rewinds35seconds or publishes gratitude")
	cold.io=SanctuaryProfile.new();check_signal_commit=true
	_check(cold.resolve_living_event(LAM,"withdrew") and cold.karma(LAM)["gratitude"]==gratitude+1 and living_signals==1 and not provisional_signal,"Successful retry keeps assistance+withdraw and emits exactly once after commit")
	before=cold.snapshot();bytes=_raw(cold.save_path)
	_check(not cold.resolve_living_event(LAM,"withdrew") and not cold.advance_living_danger(0.1) and cold.snapshot()==before and _raw(cold.save_path)==bytes and living_signals==1,"Terminal replay cannot add time, gratitude or a notification")
	var reopened: NpcWorldState=_reader(cold.save_path)
	_check(reopened.load_state() and reopened.snapshot()==cold.snapshot(),"Cold result keepselapsed, assistance and once-only outcome")
	check_signal_commit=false;watched_life=null
	p=_danger("harm_priority");life=p.life
	for _i: int in 50: life.advance_living_danger(0.1)
	_check(life.credit_living_help(LAM),"Earlier accepted help exists before the later Player offense")
	gratitude=life.karma(LAM)["gratitude"]
	_check(life.receive_hit(LAM,1.0,520.0,true) and life.living_view(LAM)["outcome"]=="interrupted" and is_equal_approx(life.living_view(LAM)["danger_elapsed"],5.0),"Player harm retains time but interrupts help instead of buying gratitude")
	_check(life.decide(LAM,life.decision_token(LAM),true,true) and not life.advance_living_danger(0.1) and life.karma(LAM)["gratitude"]==gratitude,"Actual confirmed death cannot advance horizon or reward earlier help")
	_check(life.save() and NpcWorldState.valid(life.snapshot()),"Terminal history with nonzero elapsed remains valid and durable")

func _pending_historical(schema: int) -> void:
	var p: TanDangProgress=_fixture("pending_%d"%schema);_q1(p)
	p.profile._writer.fault_plan={"compound_after_decision":true}
	_check(not p.apply("choice_gate","","refuge").get("ok",false),"Declared journal2 interruption leaves a sealed decided transaction")
	var path: String=p.life.save_path
	for participant: String in [path,path+".compound.tmp"]:
		var value: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(participant))
		_write_json(participant,_historical(value,schema))
	# Historical protocol fixture only. Production never edits seals/candidates.
	var journal: String=p.profile.save_path+".decision"
	var decision: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(journal))
	decision["npc"]["before_sha256"]=NpcWorldState._byte_hash(path)
	decision["npc"]["after_sha256"]=NpcWorldState._byte_hash(path+".compound.tmp")
	decision.erase("seal");decision["seal"]=Writer.canonical(decision).sha256_text();_write_json(journal,decision)
	var decided: PackedByteArray=_raw(path+".compound.tmp")
	var blocked: NpcWorldState=_reader(path)
	_check(not blocked.load_state() and blocked.read_only and not blocked.save() and not FileAccess.file_exists(path+".pre_horizon_v7.json"),"Standalone owner cannot migrate pending historical participant%d"%schema)
	# Failure after profile replacement must preserve decided NPC bytes for retry.
	var profile:=SanctuaryProfile.new();profile.save_path=p.profile.save_path;profile.register_extension_validator(SCOPE,TanDangProgress.valid)
	profile._ensure_writer();profile._writer.fault_plan={"compound_recovery_npc_commit":true}
	_check(not profile.load_profile() and profile.read_only and FileAccess.file_exists(journal) and _raw(path+".compound.tmp")==decided,"Historical compound recovery failure quarantines before touching candidate semantics%d"%schema)
	profile=SanctuaryProfile.new();profile.save_path=p.profile.save_path;profile.register_extension_validator(SCOPE,TanDangProgress.valid)
	_check(profile.load_profile() and _raw(path)==decided and not FileAccess.file_exists(journal),"Existing writer finishes exact historical candidate before migration%d"%schema)
	var life: NpcWorldState=_reader(path)
	var suffix: String=".pre_horizon_v7.json" if schema==7 else ".pre_living_v6.json" if schema==6 else ".pre_causality_v5.json"
	_check(life.load_state() and life.snapshot()["npc_schema"]==8 and life.records[DU]["mode"]=="dead" and _raw(path+suffix)==decided,"Only recovered authentic source bytes become immutable backup before migration%d"%schema)
	var bytes: PackedByteArray=_raw(path);life=_reader(path)
	_check(life.load_state() and _raw(path)==bytes and profile.extension_state(SCOPE)["choice"]=="gate","Reopen repeats no receipt or historical branch%d"%schema)

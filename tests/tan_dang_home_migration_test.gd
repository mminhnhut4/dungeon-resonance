extends SceneTree
## Source-authored isolated fixtures. The root owns execution; never personal saves.
const VICTIM: String = "pilot_traveler"
const DU: String = "tan_dang_du_hanh"
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
var directory: String = ""
var checks: int = 0
var failures: int = 0

class CountedState extends NpcWorldState:
	var save_calls: int = 0
	func save() -> bool:
		save_calls += 1
		return super.save()

class MigrationFault extends SanctuaryProfile:
	var primary: String = ""
	var fail_copy: bool = true
	func _copy_file(source: String, target: String) -> Error:
		if fail_copy and target.ends_with(NpcWorldState.HOME_BACKUP_SUFFIX): return ERR_CANT_CREATE
		return super._copy_file(source,target)
	func _replace_file(temporary: String, target: String) -> bool:
		if not fail_copy and target == primary: return false
		return super._replace_file(temporary,target)

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func _write(path: String, data: Dictionary) -> bool:
	if not path.begins_with(directory + "/"): return false
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data,"\t"))
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	return ok

func _reader(path: String) -> CountedState:
	var state := CountedState.new()
	state.save_path = path
	return state

func _source(schema: int = 8) -> Dictionary:
	var ids: Array[String] = NpcPilotCatalog.LEGACY_IDS if schema == 1 else NpcPilotCatalog.SCHEMA_TWO_IDS if schema == 2 else NpcPilotCatalog.SCHEMA_THREE_IDS if schema == 3 else NpcPilotCatalog.SCHEMA_FOUR_IDS if schema == 4 else NpcPilotCatalog.SCHEMA_EIGHT_IDS
	var records: Dictionary = {}
	for id: String in ids:
		var record: Dictionary = NpcPilotCatalog.initial_record(id)
		record["trust"] = -7
		record["fear"] = 19
		record["debt"] = 3
		record["greeted"] = true
		record["episode"] = 3
		if schema < 3: record.erase("legacy_death")
		if schema == 1:
			record.erase("schedule_index")
			record.erase("interrupted")
			if id == VICTIM:
				record["x"] = 600.0
				record["target"] = 800.0
		if id in NpcPilotCatalog.TAN_DANG_IDS:
			if schema < 6: record.erase("causality")
			if schema >= 7:
				record["living"] = TanDangLivingState.empty()
				if schema == 7: record["living"].erase("danger_elapsed")
		records[id] = record
	var victim: Dictionary = records[VICTIM]
	var death: Dictionary = {"event_id":VICTIM + ":3","killer_id":"player","tick":80,"room":"o01_p01","context":"explicit_execution"}
	victim["remaining"] = 0
	if schema >= 3: victim["legacy_death"] = death.duplicate(true)
	if schema in [3,4]:
		victim["mode"] = "rest"
		victim["hp"] = 20.0
	else:
		victim["mode"] = "dead"
		victim["hp"] = 0.0
		victim["death"] = death.duplicate(true)
	if schema >= 5:
		# Preserve the quest's distinct terminal cause, not only generic old deaths.
		var du: Dictionary = records[DU]
		du["mode"] = "dead"
		du["hp"] = 0.0
		du["remaining"] = 0
		du["death"] = {"event_id":DU + ":3","killer_id":"core_reclaimed","tick":90,"room":"o01_p03","context":"core_withdrawal"}
	if schema >= 7:
		var lam: Dictionary = records[TanDangLivingState.LAM]
		lam["room"] = TanDangLivingState.P01
		lam["x"] = 500.0
		lam["target"] = 500.0
		lam["mode"] = "work"
		lam["remaining"] = 0
		lam["living"]["event_phase"] = "danger"
		if schema >= 8: lam["living"]["danger_elapsed"] = 19.75
	return {"npc_schema":schema,"tick":100,"records":records}

func _backup_suffix(schema: int) -> String:
	match schema:
		8: return NpcWorldState.HOME_BACKUP_SUFFIX
		7: return ".pre_horizon_v7.json"
		6: return ".pre_living_v6.json"
		5: return ".pre_causality_v5.json"
		4: return ".pre_tan_dang_v4.json"
		3: return ".pre_sect_v3.json"
	return ".pre_nonlethal_v%d.json" % schema

func _run() -> void:
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed + "/"):
		print("FAIL: dedicated QA data root required")
		quit(2)
		return
	directory = "user://verification/tan_dang_home_migration_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	_catalog_contract()
	_migrations()
	_faults_and_fences()
	_role_lifetime()
	print("RESULT tan_dang_home_migration checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _catalog_contract() -> void:
	var unique: Dictionary = {}
	for id: String in NpcPilotCatalog.IDS: unique[id] = true
	_check(unique.size() == 15 and NpcPilotCatalog.IDS.size() == 15 and NpcPilotCatalog.SCHEMA_EIGHT_IDS.size() == 13,"Exactly two unique identities extend the frozen thirteen-role roster")
	_check(NpcPilotCatalog.TAN_DANG_IDS == ["tan_dang_moc_yen","tan_dang_lam_tuoc","tan_dang_du_hanh"] and CultivatorCatalog.TAN_DANG_IDS == NpcPilotCatalog.TAN_DANG_IDS,"The three story/karma/living identities stay separate")
	var fresh := NpcWorldState.new()
	_check(NpcWorldState.valid(fresh.snapshot()),"Fresh fifteen-role schema9 validates")
	for id: String in NpcPilotCatalog.HOME_OFFICER_IDS:
		var record: Dictionary = fresh.records[id]
		var spec: Dictionary = CultivatorCatalog.definition(id)
		_check(id in NpcPilotCatalog.CULTIVATOR_IDS and id in CultivatorCatalog.HOME_OFFICER_IDS and record["room"] == "td01_lantern_court","Home officer has one canonical room and existing cultivator owner: " + id)
		_check(record.size() == 15 and not record.has("karma") and not record.has("causality") and not record.has("living"),"Home officer does not inherit the story-three payload: " + id)
		_check(not spec.is_empty() and spec["pattern"] in ["seal","thrust"] and not CultivatorCatalog.dialogue_lines(id).is_empty(),"Home officer reuses an existing combat pattern and authored dialogue: " + id)

func _migrations() -> void:
	for schema: int in range(1,9):
		var source: Dictionary = _source(schema)
		_check(NpcWorldState.valid(source),"Historical schema%d remains strictly valid" % schema)
		var path: String = directory + "/schema%d/profile.json.npc_v1.json" % schema
		_check(_write(path,source),"Write isolated schema%d source" % schema)
		var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var state: CountedState = _reader(path)
		if not state.load_state():
			_check(false,"Schema%d migration succeeds" % schema)
			continue
		_check(not state.read_only and state.snapshot()["npc_schema"] == 9 and state.records.size() == 15 and state.save_calls == 1,"Schema%d commits the two additional roles exactly once" % schema)
		_check(FileAccess.get_file_as_bytes(path + _backup_suffix(schema)) == original,"Schema%d immutable backup preserves exact source bytes" % schema)
		for id: String in source["records"]:
			var old: Dictionary = source["records"][id]
			var current: Dictionary = state.records[id]
			if schema == 8:
				_check(Writer.canonical(current) == Writer.canonical(old),"NPC8 entire historical record survives unchanged: " + id)
			else:
				var same: bool = true
				for field: String in ["x","target","trust","fear","debt","greeted","episode"]:
					same = same and current[field] == old[field]
				_check(same,"Historical schema%d motion/relationship fields survive: %s" % [schema,id])
		for id: String in NpcPilotCatalog.HOME_OFFICER_IDS:
			_check(state.records[id] == NpcPilotCatalog.initial_record(id),"Only the new role receives its authored initial record: " + id)
		_check(state.records[VICTIM]["mode"] == "dead" and state.records[VICTIM]["death"] == state.records[VICTIM]["legacy_death"],"Archived historical death stays terminal after schema%d" % schema)
		if schema >= 5:
			_check(state.records[DU]["death"] == source["records"][DU]["death"] and state.records[DU]["mode"] == "dead","Quest terminal cause survives schema%d" % schema)
		var cold: CountedState = _reader(path)
		_check(cold.load_state() and cold.save_calls == 0 and Writer.canonical(cold.snapshot()) == Writer.canonical(state.snapshot()),"Cold schema9 neither repeats migration nor creates another identity")
		_check(FileAccess.get_file_as_bytes(path + _backup_suffix(schema)) == original,"Cold load does not rotate the immutable source")

func _faults_and_fences() -> void:
	for fail_copy: bool in [true,false]:
		var path: String = directory + "/fault_%s/profile.json.npc_v1.json" % fail_copy
		var source: Dictionary = _source()
		_check(_write(path,source),"Write migration fault source")
		var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var state: CountedState = _reader(path)
		var fault := MigrationFault.new()
		fault.primary = path
		fault.fail_copy = fail_copy
		state.io = fault
		_check(not state.load_state() and state.read_only and Writer.canonical(state.snapshot()) == Writer.canonical(source) and state.records.size() == 13,"Copy/replace failure exposes only the exact historical13 read-only")
		_check(not state.save() and FileAccess.get_file_as_bytes(path) == original,"Failed migration cannot overwrite the source")
		var retry: CountedState = _reader(path)
		_check(retry.load_state() and retry.records.size() == 15 and retry.save_calls == 1,"A fresh owner retries after a transient IO fault")
	var conflict: String = directory + "/conflict/profile.json.npc_v1.json"
	var other: Dictionary = _source()
	other["tick"] = 101
	_check(_write(conflict,_source()) and _write(conflict + NpcWorldState.HOME_BACKUP_SUFFIX,other),"Write differing immutable backup")
	var primary_bytes: PackedByteArray = FileAccess.get_file_as_bytes(conflict)
	var backup_bytes: PackedByteArray = FileAccess.get_file_as_bytes(conflict + NpcWorldState.HOME_BACKUP_SUFFIX)
	var blocked: CountedState = _reader(conflict)
	_check(not blocked.load_state() and blocked.read_only and blocked.records.size() == 13,"Conflicting backup blocks the new authority")
	_check(FileAccess.get_file_as_bytes(conflict) == primary_bytes and FileAccess.get_file_as_bytes(conflict + NpcWorldState.HOME_BACKUP_SUFFIX) == backup_bytes,"Neither side of the backup conflict is replaced")
	for kind: String in ["missing_old","unknown_old","future","missing_new","orphan"]:
		var path: String = directory + "/" + kind + "/profile.json.npc_v1.json"
		var source: Dictionary = _source()
		match kind:
			"missing_old": source["records"].erase(VICTIM)
			"unknown_old": source["records"]["tan_dang_leader"] = NpcPilotCatalog.initial_record("tan_dang_leader")
			"future": source["npc_schema"] = 10
			"missing_new": source["npc_schema"] = 9
		if kind == "orphan":
			_check(_write(path + NpcWorldState.HOME_BACKUP_SUFFIX,source),"Write orphaned historical backup")
		else:
			_check(not NpcWorldState.valid(source) and _write(path,source),"Reject malformed/future source: " + kind)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path + NpcWorldState.HOME_BACKUP_SUFFIX if kind == "orphan" else path)
		var rejected: CountedState = _reader(path)
		_check(not rejected.load_state() and rejected.read_only and not rejected.save(),"Read-only fence preserves unknown history: " + kind)
		_check((not FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path + NpcWorldState.HOME_BACKUP_SUFFIX) == bytes) if kind == "orphan" else FileAccess.get_file_as_bytes(path) == bytes,"No fresh population replaces missing or malformed history: " + kind)

func _role_lifetime() -> void:
	var state: CountedState = _reader(directory + "/lifetime/profile.json.npc_v1.json")
	_check(state.save(),"Save new authored officers through the existing owner")
	for id: String in NpcPilotCatalog.HOME_OFFICER_IDS:
		_check(state.receive_hit(id,1.0,700.0,true) and state.records[id]["mode"] == "recovering" and state.records[id]["death"].is_empty(),"Officer uses existing nonlethal recovery without a new death policy: " + id)
		var injured: Dictionary = state.records[id].duplicate(true)
		state.advance_ticks(8)
		_check(state.records[id] == injured,"Ambient ticks cannot heal or replace the same officer: " + id)
	var cold: CountedState = _reader(state.save_path)
	_check(cold.load_state() and cold.records.size() == 15,"Cold load keeps one identity per officer")
	for id: String in NpcPilotCatalog.HOME_OFFICER_IDS:
		_check(cold.records[id] == state.records[id] and NpcWorldState.life_id(id) == id + ":opening:1","Cold load retains officer injury and stable life ID: " + id)

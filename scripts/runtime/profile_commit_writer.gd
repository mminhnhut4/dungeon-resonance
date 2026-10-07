extends RefCounted
## One writer behind SanctuaryProfile.save; v1 uses its compatible legacy backend.
## v2 uses the reviewed r2 journal protocol, never a parallel inventory/life owner.
const MAX_BYTES: int = 524288
const JsonSpans = preload("res://scripts/runtime/profile_json_spans.gd")
const OPAQUE_PATHS: Dictionary = {"npc_social": ["event_extensions","namespaces","npc_social"], "legacy_npc_social": ["npc_social_progress"]}
var path: String = ""
var io_ref: WeakRef
var busy: bool = false
var fault_plan: Dictionary = {}
var before_commit: Callable
var expected_hash: String = ""
var _candidate_spans: Dictionary = {}
var _verified_document: Dictionary = {}
var _verified_hash: String = ""

func configure(host: RefCounted, profile_path: String) -> bool:
	if not profile_path.begins_with("user://") or profile_path.contains("..") or profile_path.contains("\\"): return false
	path=profile_path.simplify_path(); io_ref=weakref(host)
	_verified_document.clear(); _verified_hash=""
	if OS.get_name()=="Windows": path=path.to_lower()
	expected_hash=_digest(path)
	return true

func note_current() -> void:
	expected_hash=_digest(path)

static func normalized(value: Variant) -> Variant:
	if value is float and is_finite(value) and value==floorf(value) and absf(value)<9007199254740992.0: return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key]=normalized(value[key])
		return result
	if value is Array:
		var result: Array = []
		for child: Variant in value: result.append(normalized(child))
		return result
	return value

static func canonical(value: Variant) -> String:
	return JSON.stringify(normalized(value),"",true,true)

# Only numbers that the engine JSON parser cannot round-trip need exact bits.
# The table is part of the seal. Profile format stays2; legacy seal1 is untouched.
const MAX_EXACT_NUMBERS: int = 4096
const EXACT_NUMBERS: String = "float64"

static func _float_bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0,value)
	return bytes.hex_encode()

static func _collect_exact(value: Variant, path_parts: Array, table: Array, opaque_hashes: Dictionary) -> void:
	for key: String in opaque_hashes:
		if not OPAQUE_PATHS.has(key): continue
		# An opaque byte span already replays the original parser result exactly.
		if path_parts==OPAQUE_PATHS[key]: return
	if value is float and is_finite(value):
		var restored: Variant = normalized(JSON.parse_string(canonical(value)))
		if (restored is int or restored is float) and _float_bits(float(restored))!=_float_bits(value):
			table.append({"path":path_parts.duplicate(),"bits":_float_bits(value)})
	elif value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		for key: Variant in keys: _collect_exact(value[key],path_parts+[String(key)],table,opaque_hashes)
	elif value is Array:
		for index: int in value.size(): _collect_exact(value[index],path_parts+[index],table,opaque_hashes)

static func sealed(payload: Dictionary, revision: int, opaque_hashes: Dictionary = {}) -> Dictionary:
	var result: Dictionary = normalized(payload)
	result.erase("profile_commit")
	var table: Array = []
	_collect_exact(result,[],table,opaque_hashes)
	result["profile_commit"]={"schema_version":1 if table.is_empty() else 2,"revision":revision,"seal":""}
	if not table.is_empty(): result["profile_commit"][EXACT_NUMBERS]=table
	if not opaque_hashes.is_empty(): result["profile_commit"]["opaque_sha256"]=opaque_hashes.duplicate()
	result["profile_commit"]["seal"]=canonical(result).sha256_text()
	return result

static func _exact_table(payload: Dictionary, restore_wire: bool = false) -> bool:
	var table: Variant = payload.get("profile_commit",{}).get(EXACT_NUMBERS)
	if not table is Array or table.is_empty() or table.size()>MAX_EXACT_NUMBERS: return false
	var seen: Dictionary = {}
	for entry: Variant in table:
		if not entry is Dictionary or entry.size()!=2 or not entry.has("path") or not entry.has("bits"): return false
		var parts: Variant = entry["path"]
		var bits: Variant = entry["bits"]
		if not parts is Array or parts.is_empty() or parts.size()>24 or not parts[0] is String or parts[0]=="profile_commit" or not bits is String or bits.length()!=16: return false
		for letter: String in bits:
			if letter not in "0123456789abcdef": return false
		var identity: String = canonical(parts)
		if seen.has(identity): return false
		seen[identity]=true
		var exact: float = bits.hex_decode().decode_double(0)
		if not is_finite(exact): return false
		var parent: Variant = payload
		for index: int in parts.size():
			var part: Variant = parts[index]
			if parent is Dictionary:
				if not part is String or not parent.has(part): return false
			elif parent is Array:
				if not _integer(part,0,parent.size()-1): return false
				part=int(part)
			else: return false
			if index<parts.size()-1:
				parent=parent[part]
				continue
			var current: Variant = parent[part]
			if not (current is int or current is float) or not is_finite(float(current)): return false
			if restore_wire:
				# Never trust bits over conflicting JSON: verify the original wire
				# parser result first, then restore before the unchanged full seal.
				var expected: Variant = normalized(JSON.parse_string(canonical(exact)))
				if not (expected is int or expected is float) or _float_bits(float(current))!=_float_bits(float(expected)): return false
				parent[part]=exact
			elif _float_bits(float(current))!=bits: return false
	return true

static func seal_valid(payload: Dictionary) -> bool:
	var meta: Variant = payload.get("profile_commit")
	if not meta is Dictionary or not _integer(meta.get("revision"),1,1000000000) or not _hash(meta.get("seal")): return false
	var schema: Variant = meta.get("schema_version")
	if not _integer(schema,1,2): return false
	var opaque: Variant = meta.get("opaque_sha256",{})
	if not opaque is Dictionary or (meta.has("opaque_sha256") and opaque.is_empty()): return false
	for key: Variant in opaque:
		if key not in OPAQUE_PATHS or not _hash(opaque[key]): return false
	if meta.size()!=3+(1 if meta.has("opaque_sha256") else 0)+(1 if schema==2 else 0): return false
	if schema==1 and meta.has(EXACT_NUMBERS): return false
	if schema==2 and not _exact_table(payload): return false
	# Recompute the supplied schema exactly, without upgrading old legitimate
	# seals or trusting a recomputed numeric table from altered input.
	var copy: Dictionary = normalized(payload)
	copy["profile_commit"]["seal"]=""
	return canonical(copy).sha256_text()==meta["seal"]

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floorf(float(value)) and value>=low and value<=high

static func _hash(value: Variant) -> bool:
	if not value is String or value.length()!=64: return false
	for letter: String in value:
		if letter not in "0123456789abcdef": return false
	return true

static func _depth(value: Variant, level: int = 0) -> bool:
	if level>24: return false
	if value is Dictionary:
		for child: Variant in value.values():
			if not _depth(child,level+1): return false
	if value is Array:
		for child: Variant in value:
			if not _depth(child,level+1): return false
	return true

static func read_json(file_path: String) -> Variant:
	return _read_document(file_path).get("data")

static func _read_document(file_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(file_path,FileAccess.READ)
	if file==null or file.get_length()>MAX_BYTES: return {}
	var parser: JSON = JSON.new()
	var raw: String = file.get_as_text()
	if parser.parse(raw)!=OK or not _depth(parser.data): return {}
	var fields: Dictionary = {}
	if parser.data is Dictionary:
		fields = JsonSpans.extract_many(raw,OPAQUE_PATHS)
		if not fields.get("ok",false): return {}
		var meta: Variant = parser.data.get("profile_commit",{})
		if meta is Dictionary and meta.has("opaque_sha256"):
			if not meta["opaque_sha256"] is Dictionary: return {}
			for key: Variant in meta["opaque_sha256"]:
				if key not in OPAQUE_PATHS: return {}
				var field: Dictionary = fields[key]
				if not field.get("present",false) or field["span"].sha256_text()!=meta["opaque_sha256"][key]: return {}
		if meta is Dictionary and _integer(meta.get("schema_version"),2,2):
			if not _exact_table(parser.data,true): return {}
	return {"data":normalized(parser.data),"fields":fields,"raw":raw}

static func _typed_path(key: String) -> Array[String]:
	var result: Array[String] = []
	result.assign(OPAQUE_PATHS[key])
	return result

func _preserved_spans(payload: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if not FileAccess.file_exists(path): return result
	var raw: String = FileAccess.get_file_as_string(path)
	var old_fields: Dictionary = _verified_document.get("fields",{}) if raw==_verified_document.get("raw",null) else JsonSpans.extract_many(raw,OPAQUE_PATHS)
	if not old_fields.get("ok",false): return result
	for key: String in OPAQUE_PATHS:
		var old: Dictionary = old_fields[key]
		var next: Variant = payload
		var present: bool = true
		for part: String in OPAQUE_PATHS[key]:
			if not next is Dictionary or not next.has(part): present=false; break
			next=next[part]
		# Match the old wire-parser semantics, including float rounding, while
		# serializing only this opaque leaf instead of scanning the whole profile.
		if old.get("present",false) and present and canonical(JSON.parse_string(old["span"]))==canonical(JSON.parse_string(canonical(next))):
			result[key]=old["span"]
	return result

func _profile_text(data: Dictionary) -> String:
	var result: String = canonical(data)
	if not _candidate_spans.is_empty(): result=JsonSpans.replace_many(result,OPAQUE_PATHS,_candidate_spans)
	return result

func legacy_text(payload: Dictionary) -> String:
	_candidate_spans=_preserved_spans(payload)
	return _profile_text(payload)

func _digest(file_path: String) -> String:
	return FileAccess.get_file_as_bytes(file_path).hex_encode().sha256_text() if FileAccess.file_exists(file_path) else ""

func _fault(point: String) -> bool:
	if not fault_plan.has(point): return false
	fault_plan.erase(point)
	return true

func _write(file_path: String, data: Variant, point: String) -> bool:
	if _fault(point): return false
	var host: RefCounted = io_ref.get_ref()
	var file: FileAccess = host._open_writer(file_path)
	if file==null: return false
	var serialized: String = _profile_text(data) if point=="write_candidate" else canonical(data)
	if serialized.is_empty(): file.close(); return false
	file.store_string(serialized); file.flush()
	var ok: bool = file.get_error()==OK
	file.close()
	return ok

func _rename(source: String, target: String, point: String) -> bool:
	return not _fault(point) and io_ref.get_ref()._rename_file(source,target)==OK

func _remove(file_path: String, point: String) -> bool:
	if not FileAccess.file_exists(file_path): return true
	return not _fault(point) and io_ref.get_ref()._remove_file(file_path)==OK and not FileAccess.file_exists(file_path)

func _cleanup() -> bool:
	if _fault("cleanup"): return false
	var ok: bool = true
	for suffix: String in [".tmp",".decision.tmp",".previous"]:
		if not _remove(path+suffix,"remove"+suffix.replace(".","_")): ok=false
	if ok and not _remove(path+".decision","remove_decision"): ok=false
	return ok

func _bad(error: String, quarantine: bool = true) -> Dictionary:
	return {"ok":false,"status":"quarantined" if quarantine else "rejected","error":error,"recovery_required":quarantine}

func _abort(error: String) -> Dictionary:
	return _bad(error,false) if _cleanup() else _bad(error+"_cleanup_unresolved")

func marker_valid() -> bool:
	if not FileAccess.file_exists(path+".format_v2"): return true
	return read_json(path+".format_v2")=={"marker_version":1,"profile_format":2}

func _valid(data: Variant) -> bool:
	return io_ref.get_ref()._validate_payload(data,true)

func _decision_valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=7 or data.get("commit_schema")!=1 or not _hash(data.get("before_sha256")) or not _hash(data.get("after_sha256")) or not data.get("fence") is Dictionary or not _hash(data.get("seal")) or data.get("profile_version")!=2 or data.get("profile_path")!=path: return false
	var copy: Dictionary = data.duplicate(true); copy.erase("seal")
	return canonical(copy).sha256_text()==data["seal"]

func _durable_fence(fence: Dictionary) -> Dictionary:
	if fence.is_empty(): return {"ok":true,"eligible":true,"unchanged":true}
	var adapter = load("res://scripts/cultivation/opening_npc_life_adapter.gd")
	if fence.get("npc_path")!=adapter._canonical_user_path(path+".npc_v1.json"): return {"ok":false}
	if fence.get("kind")=="npc_social": return io_ref.get_ref()._read_social_fence(fence)
	if fence.get("kind")!="npc": return {"ok":false}
	return adapter.durable_status(fence)

func recover() -> Dictionary:
	if not marker_valid(): return _bad("invalid_future_migration_marker")
	if not FileAccess.file_exists(path+".decision"):
		if FileAccess.file_exists(path+".tmp") and not _remove(path+".tmp","remove_tmp"): return _bad("uncommitted_cleanup_failed")
		if FileAccess.file_exists(path+".decision.tmp") and not _remove(path+".decision.tmp","remove_decision_tmp"): return _bad("decision_temp_cleanup_failed")
		return {"ok":true,"status":"ready"}
	var decision: Variant = read_json(path+".decision")
	if not _decision_valid(decision): return _bad("invalid_future_decision")
	var current: Variant = read_json(path)
	if _digest(path)==decision["after_sha256"] and _valid(current):
		return {"ok":true,"status":"recovered_committed"} if _cleanup() else _bad("committed_cleanup_unresolved")
	var pending: Variant = read_json(path+".tmp")
	if not _valid(pending) or _digest(path+".tmp")!=decision["after_sha256"]: return _bad("invalid_pending")
	var main_before: bool = _digest(path)==decision["before_sha256"] and io_ref.get_ref()._validate_payload(current,true)
	var moved_before: bool = not FileAccess.file_exists(path) and _digest(path+".previous")==decision["before_sha256"] and io_ref.get_ref()._validate_payload(read_json(path+".previous"),true)
	if not main_before and not moved_before: return _bad("ambiguous_authority")
	var life: Dictionary = _durable_fence(decision["fence"])
	if not life.get("ok",false): return _bad("life_authority_unavailable")
	if not life.get("eligible",false) or not life.get("unchanged",false):
		if moved_before and not _rename(path+".previous",path,"abort_restore"): return _bad("abort_restore_failed")
		return {"ok":true,"status":"recovered_aborted"} if _cleanup() else _bad("abort_cleanup_unresolved")
	if main_before and not _rename(path,path+".previous","recovery_move"): return _bad("recovery_move_failed")
	if not _rename(path+".tmp",path,"recovery_commit") or _digest(path)!=decision["after_sha256"]: return _bad("recovery_commit_failed")
	return {"ok":true,"status":"recovered_committed"} if _cleanup() else _bad("recovery_cleanup_unresolved")

func commit(payload: Dictionary, fence: Dictionary = {}, live_guard: Callable = Callable()) -> Dictionary:
	if busy: return _bad("writer_busy",false)
	busy=true
	var result: Dictionary = _commit_owned(payload,fence,live_guard)
	busy=false
	return result

func _npc_changes_require_fence(payload: Dictionary, current: Dictionary) -> bool:
	var previous: Dictionary = current.get("cultivation_progress",{}).get("actors",{}).get("pilot_gatherer",{})
	var next: Dictionary = payload.get("cultivation_progress",{}).get("actors",{}).get("pilot_gatherer",{})
	if canonical(previous)==canonical(next): return false
	# Stopping sponsorship never advances a dead or unavailable resident.
	if not previous.is_empty():
		var stopped: Dictionary = previous.duplicate(true)
		stopped["enrolled"]=false; stopped["sessions_left"]=0
		if canonical(stopped)==canonical(next): return false
	return true

func _commit_owned(payload: Dictionary, fence: Dictionary, live_guard: Callable) -> Dictionary:
	if not fence.is_empty() and not live_guard.is_valid(): return _bad("npc_live_guard_required",false)
	var ready: Dictionary = recover()
	if not ready["ok"]: return ready
	var current_hash: String = _digest(path)
	if current_hash!=expected_hash: return _bad("profile_changed_reload_required")
	# A private copy of the last disk-validated document is usable only while
	# the full byte digest still matches. No timestamp or caller-owned data is
	# trusted; recovery, pending candidates and changed files still parse afresh.
	var cached: bool = not _verified_document.is_empty() and _verified_hash==current_hash
	var current_document: Dictionary = _verified_document if cached else _read_document(path)
	var current: Variant = current_document.get("data")
	var before_valid: bool = cached
	if current is Dictionary:
		var current_version: Variant = current.get("version",0)
		if not _integer(current_version,1,2): return _bad("invalid_future_version")
		if current_version==2:
			if (not cached and not _valid(current)) or payload.get("version")!=2: return _bad("invalid_or_downgraded_v2")
			before_valid=true
	if payload.get("version")==1:
		if not io_ref.get_ref()._save_legacy_payload(payload): return _bad("legacy_io_failed",false)
		note_current()
		return {"ok":true,"status":"committed"}
	if not io_ref.get_ref()._validate_payload(payload,false): return _bad("invalid_candidate",false)
	if not before_valid and not io_ref.get_ref()._validate_payload(current,true): return _bad("invalid_before")
	_verified_document=current_document.duplicate(true); _verified_hash=current_hash
	if _npc_changes_require_fence(payload,current) and (fence.get("kind")!="npc" or fence.get("actor_id")!="pilot_gatherer" or not live_guard.is_valid()): return _bad("npc_progress_requires_life_fence",false)
	if not FileAccess.file_exists(path+".format_v2"):
		if not _write(path+".format_v2",{"marker_version":1,"profile_format":2},"write_marker") or not marker_valid(): return _bad("migration_marker_failed")
	var revision: int = int(current.get("profile_commit",{}).get("revision",0))+1
	if revision>1000000000: return _bad("revision_capacity",false)
	_candidate_spans=_preserved_spans(payload)
	var opaque_hashes: Dictionary = {}
	for key: String in _candidate_spans: opaque_hashes[key]=_candidate_spans[key].sha256_text()
	var candidate: Dictionary = sealed(payload,revision,opaque_hashes)
	var before_hash: String = _digest(path)
	if not _write(path+".tmp",candidate,"write_candidate"): return _abort("candidate_write_failed")
	var candidate_document: Dictionary = _read_document(path+".tmp")
	if not _valid(candidate_document.get("data")): return _abort("candidate_write_failed")
	if _fault("after_candidate"): return _bad("simulated_crash_after_candidate")
	var decision: Dictionary = {"commit_schema":1,"profile_version":2,"profile_path":path,"before_sha256":before_hash,"after_sha256":_digest(path+".tmp"),"fence":fence.duplicate(true)}
	decision["seal"]=canonical(decision).sha256_text()
	if not _write(path+".decision.tmp",decision,"write_decision") or not _decision_valid(read_json(path+".decision.tmp")) or not _rename(path+".decision.tmp",path+".decision","rename_decision"): return _abort("decision_write_failed")
	if _fault("after_decision"): return _bad("simulated_crash_after_decision")
	if before_commit.is_valid():
		var callback: Callable = before_commit; before_commit=Callable(); callback.call()
	if _digest(path)!=before_hash or (live_guard.is_valid() and not live_guard.call()): return _abort("live_or_profile_changed")
	var life: Dictionary = _durable_fence(fence)
	if not life.get("ok",false) or not life.get("eligible",false) or not life.get("unchanged",false): return _abort("durable_life_changed")
	if not _rename(path,path+".previous","rename_old"): return _abort("old_rename_failed")
	if _fault("after_old_rename"): return _bad("simulated_crash_after_old_rename")
	if not _rename(path+".tmp",path,"commit"):
		if not _rename(path+".previous",path,"rollback") or _digest(path)!=before_hash: return _bad("rollback_unresolved")
		return _abort("commit_failed_rolled_back")
	if _fault("after_commit"): return _bad("simulated_crash_after_commit")
	if _digest(path)!=decision["after_sha256"]: return _bad("commit_unresolved")
	var cleanup_ok: bool = _cleanup()
	note_current()
	_verified_document=candidate_document.duplicate(true); _verified_hash=expected_hash
	return {"ok":true,"status":"committed","cleanup_pending":not cleanup_ok,"payload":candidate}

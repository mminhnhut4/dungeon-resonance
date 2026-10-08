class_name NpcWorldState
extends RefCounted
## Pure bounded records: no Node, instance ID, wall clock or inventory rewards.
signal activity_changed(id: String, activity: String)
const STEP: float = 0.25
const MAX_TICKS: int = 1000000000
const SCHEMA: int = 3
var tick: int = 0
var records: Dictionary = {}
var save_path: String = ""
var read_only: bool = false
var last_save_ok: bool = true
var io: SanctuaryProfile = SanctuaryProfile.new()
var _snapshot_schema: int = SCHEMA
var emitting_recovery: bool = false
var _local_control: Dictionary[String, bool] = {}

func _init() -> void:
	for id: String in NpcPilotCatalog.IDS: records[id] = NpcPilotCatalog.initial_record(id)

func snapshot() -> Dictionary:
	return {"npc_schema":_snapshot_schema, "tick":tick, "records":records.duplicate(true)}

## Recovery preserves the same authored life. Legacy terminal facts are archived,
## never used to mint another generation or repeat social/cultivation rewards.
static func life_id(id: String) -> String:
	return id + ":opening:1" if id in NpcPilotCatalog.IDS else ""

## Read fence for a same-thread profile transaction. It never writes the sidecar
## and deliberately excludes x, schedule phase and clock from the fingerprint.
func social_fence(id: String) -> Dictionary:
	if read_only or id not in NpcSocialCatalog.IDS or not records.has(id) or not valid(snapshot()): return {}
	var durable: Variant = _read(save_path)
	if not valid(durable) or not durable["records"].has(id): return {}
	var live: Dictionary = records[id]
	var saved: Dictionary = durable["records"][id]
	for record: Dictionary in [live,saved]:
		if not record["death"].is_empty() or record["mode"] in ["dead","downed","recovering","flee"] or record["hp"] < 1: return {}
	return {"actor_id":id, "life_id":life_id(id), "npc_path":save_path, "live_fingerprint":_social_fingerprint(id,live), "durable_fingerprint":_social_fingerprint(id,saved)}

func social_fence_matches(fence: Dictionary) -> bool:
	if fence.size() != 5 or fence.get("npc_path") != save_path or fence.get("life_id") != life_id(str(fence.get("actor_id",""))): return false
	var current: Dictionary = social_fence(str(fence.get("actor_id","")))
	return not current.is_empty() and current == fence

static func _social_fingerprint(id: String, record: Dictionary) -> String:
	return JSON.stringify({"life_id":life_id(id), "room":record["room"], "episode":int(record["episode"]), "hp":float(record["hp"]), "trust":int(record["trust"]), "fear":int(record["fear"]), "debt":int(record["debt"]), "death":record["death"]},"",true,true).sha256_text()

func advance_ticks(count: int) -> void:
	if read_only: return
	for _index: int in clampi(count, 0, 8):
		tick = mini(tick + 1, MAX_TICKS)
		for id: String in NpcPilotCatalog.IDS:
			if _local_control.has(id): continue
			var record: Dictionary = records[id]
			var spec: Dictionary = NpcPilotCatalog.definition(id)
			match record["mode"]:
				"walk", "flee":
					var speed: float = float(spec["speed"]) * (1.8 if record["mode"] == "flee" else 1.0)
					record["x"] = move_toward(float(record["x"]), float(record["target"]), speed * STEP)
					if is_equal_approx(record["x"], record["target"]):
						if record["mode"] == "flee":
							_set_mode(id, "rest", 12)
						else:
							var point: Dictionary = NpcPilotCatalog.stop(id, int(record["schedule_index"]))
							_set_mode(id, point["mode"], point["ticks"])
				"rest", "work":
					record["remaining"] = maxi(0, int(record["remaining"]) - 1)
					if record["remaining"] == 0:
						var point: Dictionary = NpcPilotCatalog.stop(id, int(record["schedule_index"]))
						if is_equal_approx(record["x"], point["x"]):
							record["schedule_index"] = (int(record["schedule_index"]) + 1) % NpcPilotCatalog.SCHEDULES[id].size()
						# Recovery and fleeing can rest between stops. Resume the
						# pending stop instead of waiting forever for x to match it.
						record["target"] = NpcPilotCatalog.stop(id, int(record["schedule_index"]))["x"]
						_set_mode(id, "walk")

## A local cultivator controller can temporarily own motion. This is not saved:
## leaving a room or loading a profile resumes the authored patrol schedule.
func set_local_control(id: String, active: bool) -> bool:
	if id not in NpcPilotCatalog.CULTIVATOR_IDS: return false
	if not active:
		_local_control.erase(id)
		return true
	if read_only or not records.has(id) or records[id]["mode"] in ["dead", "downed", "recovering", "talk"]: return false
	_local_control[id] = true
	return true

func update_local_position(id: String, local_x: float) -> bool:
	if read_only or not _local_control.has(id) or not is_finite(local_x) or not records.has(id) or records[id]["mode"] in ["dead", "downed", "recovering", "talk"]: return false
	var spec: Dictionary = NpcPilotCatalog.definition(id)
	records[id]["x"] = clampf(local_x,float(spec["left"]),float(spec["right"]))
	return true

func _set_mode(id: String, mode: String, remaining: int = 0) -> void:
	records[id]["mode"] = mode
	records[id]["remaining"] = remaining
	activity_changed.emit(id, mode)

func begin_talk(id: String) -> bool:
	if read_only or not records.has(id) or records[id]["mode"] in ["talk", "downed", "dead", "recovering"]: return false
	records[id]["interrupted"] = {"mode":records[id]["mode"], "remaining":records[id]["remaining"]}
	_set_mode(id, "talk")
	return true

func end_talk(id: String) -> void:
	if not records.has(id) or records[id]["mode"] != "talk": return
	var interrupted: Dictionary = records[id]["interrupted"].duplicate()
	records[id]["interrupted"] = {}
	_set_mode(id, interrupted["mode"], int(interrupted["remaining"]))

func greet(id: String) -> bool:
	if read_only or not records.has(id) or records[id]["mode"] != "talk" or records[id]["greeted"]: return false
	var before: Dictionary = snapshot()
	records[id]["greeted"] = true
	records[id]["trust"] = mini(100, records[id]["trust"] + 1)
	return _commit_or_restore(before)

func receive_hit(id: String, hp: float, origin_x: float, player_caused: bool = true, actor_x: float = NAN, record_cause: bool = true) -> void:
	if read_only or not records.has(id) or records[id]["mode"] in ["downed", "dead", "recovering"]: return
	var record: Dictionary = records[id]
	var spec: Dictionary = NpcPilotCatalog.definition(id)
	record["interrupted"] = {}
	record["hp"] = clampf(hp, 1.0, NpcPilotCatalog.MAX_HEALTH)
	# Withdrawal never erases violence or rewards the attacker with gratitude.
	if record_cause:
		record["fear"] = mini(100, int(record["fear"]) + 6)
		if player_caused: record["trust"] = maxi(-100, int(record["trust"]) - 2)
	if hp <= 1.0:
		_local_control.erase(id)
		record["episode"] = mini(1000000, int(record["episode"]) + 1)
		_set_mode(id, "recovering")
	else:
		# A local actor may have moved between decisions. Use its contact sample
		# only for this reaction; offscreen/pure callers keep the record fallback.
		var contact_x: float = clampf(actor_x, spec["left"], spec["right"]) if is_finite(actor_x) else float(record["x"])
		record["target"] = spec["right"] if origin_x <= contact_x else spec["left"]
		_set_mode(id, "flee")
	# Failed ambient write leaves the current live health intact; UI exposes failure.
	save()

func decision_token(id: String) -> String:
	return "%s:%d" % [id, records[id]["episode"]] if records.has(id) and records[id]["mode"] == "downed" else ""

func decide(id: String, token: String, kill: bool, _confirmed: bool = false) -> bool:
	# Keep the old call surface, but no caller or stale UI can create a new death.
	if kill or read_only or token.is_empty() or token != decision_token(id): return false
	var before: Dictionary = snapshot()
	var record: Dictionary = records[id]
	record["mode"] = "recovering"
	record["remaining"] = 0
	record["interrupted"] = {}
	if not _commit_or_restore(before): return false
	activity_changed.emit(id, record["mode"])
	return true

## Trusted GameFlow calls only after an actual dungeon expedition returns.
## A failed write restores every resident; ordinary ticks/doors/load never heal.
func recover_after_expedition() -> bool:
	if read_only or _snapshot_schema != SCHEMA: return false
	var before: Dictionary = snapshot()
	var recovered: Array[String] = []
	for id: String in NpcPilotCatalog.IDS:
		var record: Dictionary = records[id]
		if record["mode"] not in ["downed", "recovering"]: continue
		record["mode"] = "rest"
		record["hp"] = NpcPilotCatalog.MAX_HEALTH * 0.5
		record["remaining"] = 12
		record["interrupted"] = {}
		recovered.append(id)
	if recovered.is_empty(): return true
	if not _commit_or_restore(before): return false
	# Do not emit rest until the single recovery commit has succeeded.
	emitting_recovery = true
	for id: String in recovered: activity_changed.emit(id, "rest")
	emitting_recovery = false
	return true

func _commit_or_restore(before: Dictionary) -> bool:
	if save(): return true
	records = before["records"]
	tick = int(before["tick"])
	return false

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 3 or not _integer(data.get("npc_schema"), 1, SCHEMA) or not data.get("records") is Dictionary: return false
	var legacy: bool = int(data["npc_schema"]) == 1
	var nonlethal: bool = int(data["npc_schema"]) == SCHEMA
	var ids: Array[String] = NpcPilotCatalog.LEGACY_IDS if legacy else NpcPilotCatalog.IDS if nonlethal else NpcPilotCatalog.SCHEMA_TWO_IDS
	if not _integer(data.get("tick"), 0, MAX_TICKS) or data["records"].size() != ids.size(): return false
	for id: String in ids:
		var record: Variant = data["records"].get(id)
		var spec: Dictionary = NpcPilotCatalog.definition(id)
		if not record is Dictionary or record.size() != (12 if legacy else 15 if nonlethal else 14) or record.get("room") != spec["room"]: return false
		if record.get("mode") not in NpcPilotCatalog.MODE_LABELS and (nonlethal or record.get("mode") != "dead"): return false
		var low: float = 520.0 if legacy and id == "pilot_traveler" else float(spec["left"])
		var high: float = 870.0 if legacy and id == "pilot_traveler" else float(spec["right"])
		for field: String in ["x", "target"]:
			if not _number(record.get(field), low, high): return false
		if not _number(record.get("hp"), 0, NpcPilotCatalog.MAX_HEALTH) or not _integer(record.get("remaining"), 0, 80): return false
		for field: String in ["trust", "debt", "fear"]:
			if not _integer(record.get(field), -100 if field == "trust" else 0, 100): return false
		if not record.get("greeted") is bool or not _integer(record.get("episode"), 0, 1000000) or not record.get("death") is Dictionary: return false
		if record["mode"] == "dead":
			var death: Dictionary = record["death"]
			if nonlethal or record["hp"] != 0 or not _valid_legacy_death(death,id,record,int(data["tick"])) or death["event_id"] != "%s:%d" % [id,record["episode"]]: return false
		elif record["hp"] < 1 or not record["death"].is_empty(): return false
		if record["mode"] in ["downed", "recovering"] and record["hp"] != 1: return false
		if record["mode"] in ["downed", "recovering"] and record["episode"] < 1 and not (nonlethal and record.get("legacy_death") is Dictionary and not record["legacy_death"].is_empty()): return false
		if nonlethal:
			if not record.get("legacy_death") is Dictionary: return false
			if not record["legacy_death"].is_empty() and not _valid_legacy_death(record["legacy_death"],id,record,int(data["tick"])): return false
			if record["mode"] == "recovering" and record["remaining"] != 0: return false
		if not legacy:
			if not _integer(record.get("schedule_index"), 0, NpcPilotCatalog.SCHEDULES[id].size()-1) or not record.get("interrupted") is Dictionary: return false
			var interrupted: Dictionary = record["interrupted"]
			if record["mode"] == "talk":
				if interrupted.size() != 2 or interrupted.get("mode") not in ["walk", "rest", "work", "flee"] or not _integer(interrupted.get("remaining"), 0, 80): return false
			elif not interrupted.is_empty(): return false
	return true

static func _valid_legacy_death(death: Dictionary, id: String, record: Dictionary, world_tick: int) -> bool:
	if death.size() != 5 or not death.get("event_id") is String or death.get("killer_id") != "player" or death.get("room") != record["room"] or death.get("context") != "explicit_execution" or not _integer(death.get("tick"),0,world_tick): return false
	var parts: PackedStringArray = death["event_id"].split(":")
	return parts.size() == 2 and parts[0] == id and parts[1].is_valid_int() and str(int(parts[1])) == parts[1] and int(parts[1]) >= 0 and int(parts[1]) <= int(record["episode"])

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and float(value) == floorf(float(value))

func _read(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 32768: return null
	var parser := JSON.new()
	return parser.data if parser.parse(file.get_as_text()) == OK else null

func _restore(data: Dictionary) -> void:
	# JSON numbers arrive as floats. Restore the authored scalar types explicitly.
	records = data["records"].duplicate(true)
	tick = int(data["tick"])
	_snapshot_schema = SCHEMA
	_local_control.clear()
	for id: String in records:
		for field: String in ["remaining", "trust", "debt", "fear", "episode"]: records[id][field] = int(records[id][field])
		for field: String in ["x", "target", "hp"]: records[id][field] = float(records[id][field])
		if not records[id]["death"].is_empty(): records[id]["death"]["tick"] = int(records[id]["death"]["tick"])
		if records[id].has("legacy_death") and not records[id]["legacy_death"].is_empty(): records[id]["legacy_death"]["tick"] = int(records[id]["legacy_death"]["tick"])
		if int(data["npc_schema"]) == 1:
			# Preserve every old scalar/tombstone. Only add schedule ownership fields.
			var closest: int = 0
			var distance: float = INF
			for index: int in NpcPilotCatalog.SCHEDULES[id].size():
				var next: float = absf(float(records[id]["target"]) - float(NpcPilotCatalog.stop(id,index)["x"]))
				if next < distance:
					closest = index
					distance = next
			records[id]["schedule_index"] = closest
			records[id]["interrupted"] = {"mode":"rest", "remaining":16} if records[id]["mode"] == "talk" else {}
		else:
			records[id]["schedule_index"] = int(records[id]["schedule_index"])
			if not records[id]["interrupted"].is_empty(): records[id]["interrupted"]["remaining"] = int(records[id]["interrupted"]["remaining"])
		if int(data["npc_schema"]) < SCHEMA:
			# Preserve the original fact and all relation/progression fields. The new
			# nonlethal policy changes active state, not what the old save recorded.
			records[id]["legacy_death"] = records[id]["death"].duplicate(true)
			if records[id]["mode"] in ["dead", "downed", "recovering"]:
				records[id]["mode"] = "recovering"
				records[id]["hp"] = 1.0
				records[id]["remaining"] = 0
				records[id]["interrupted"] = {}
			records[id]["death"] = {}
	if int(data["npc_schema"]) == 1: records["pilot_bridge_keeper"] = NpcPilotCatalog.initial_record("pilot_bridge_keeper")
	if int(data["npc_schema"]) < SCHEMA:
		for id: String in NpcPilotCatalog.CULTIVATOR_IDS: records[id] = NpcPilotCatalog.initial_record(id)

func load_state() -> bool:
	if not FileAccess.file_exists(save_path):
		# A valid tmp can still be an execution whose commit was reported failed.
		# An older backup can predate a committed death. Neither proves history.
		for suffix: String in [".previous", ".tmp", ".bak", ".pre_nonlethal_v1.json", ".pre_nonlethal_v2.json"]:
			if not FileAccess.file_exists(save_path + suffix): continue
			read_only = true
			return false
		return true # Existing profiles without an NPC sidecar are compatible.
	var data: Variant = _read(save_path)
	if not valid(data):
		read_only = true
		return false
	if int(data["npc_schema"]) < SCHEMA and not _preserve_legacy_source(data):
		_refuse_migration(data)
		return false
	_restore(data)
	for id: String in NpcPilotCatalog.IDS: end_talk(id)
	if int(data["npc_schema"]) < SCHEMA and not save():
		# No new authority is exposed if migration did not commit. Preserve the
		# full old view for diagnostics and leave the primary/backup under IO's
		# existing interrupted-replace rules; a fresh load can retry later.
		_refuse_migration(data)
		return false
	return true

func _refuse_migration(data: Dictionary) -> void:
	records = data["records"].duplicate(true)
	tick = int(data["tick"])
	_snapshot_schema = int(data["npc_schema"])
	last_save_ok = false
	read_only = true

func _preserve_legacy_source(data: Dictionary) -> bool:
	# This immutable copy survives ordinary .bak rotation. A pre-existing file
	# with different bytes is evidence to preserve, never permission to replace.
	var original: PackedByteArray = FileAccess.get_file_as_bytes(save_path)
	if original.is_empty() or JSON.parse_string(original.get_string_from_utf8()) != data: return false
	var backup_path: String = save_path + ".pre_nonlethal_v%d.json" % int(data["npc_schema"])
	if FileAccess.file_exists(backup_path):
		return FileAccess.get_file_as_bytes(backup_path) == original
	if io._copy_file(save_path,backup_path) != OK: return false
	return FileAccess.get_file_as_bytes(backup_path) == original and FileAccess.get_file_as_bytes(save_path) == original

func save() -> bool:
	last_save_ok = false
	if read_only or _snapshot_schema != SCHEMA or save_path.is_empty() or not valid(snapshot()): return false
	if FileAccess.file_exists(save_path) and not valid(_read(save_path)):
		read_only = true
		return false
	if DirAccess.make_dir_recursive_absolute(save_path.get_base_dir()) != OK: return false
	var file: FileAccess = io._open_writer(save_path + ".tmp")
	if file == null: return false
	file.store_string(JSON.stringify(snapshot()))
	file.flush()
	var write_ok: bool = file.get_error() == OK
	file.close()
	if not write_ok or not valid(_read(save_path + ".tmp")): return false
	if FileAccess.file_exists(save_path):
		if io._copy_file(save_path, save_path + ".bak.tmp") != OK or not io._replace_file(save_path + ".bak.tmp", save_path + ".bak"): return false
	last_save_ok = io._replace_file(save_path + ".tmp", save_path)
	return last_save_ok

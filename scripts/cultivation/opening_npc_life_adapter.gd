extends RefCounted
## Read-only bridge to the existing NPC life owner. No second records/death owner.
## Capture and recheck synchronously around the common profile writer's commit.
## Fingerprints are semantic fences, not durable revision counters or clocks.
const NpcState = preload("res://scripts/npc/npc_world_state.gd")
const NpcCatalog = preload("res://scripts/npc/npc_pilot_catalog.gd")
const NPC_SUFFIX: String = ".npc_v1.json"
const MAX_BYTES: int = 32768

var last_error: String = ""
var _state: NpcWorldState
var _npc_path: String = ""

func configure(live_state: NpcWorldState, profile_path: String) -> bool:
	_state = null
	_npc_path = ""
	last_error = ""
	var profile: String = _canonical_user_path(profile_path)
	if live_state == null or profile.is_empty() or profile.ends_with(NPC_SUFFIX):
		last_error = "invalid_profile_or_life_owner"
		return false
	var derived: String = _canonical_user_path(profile + NPC_SUFFIX)
	if derived.is_empty() or _canonical_user_path(live_state.save_path) != derived:
		last_error = "npc_path_does_not_belong_to_profile"
		return false
	_state = live_state
	_npc_path = derived
	return true

## Failure returns {} plus last_error. Success returns a JSON-safe fence only.
## A fresh, unsaved default NPC state is not durable authority; no initialization.
func capture(id: String, require_rest: bool = true) -> Dictionary:
	last_error = ""
	if _state == null or _npc_path.is_empty() or _canonical_user_path(_state.save_path) != _npc_path:
		return _capture_failure("life_owner_not_bound")
	if id not in NpcCatalog.IDS:
		return _capture_failure("unknown_npc_id")
	if _state.read_only:
		return _capture_failure("live_authority_quarantined")
	var live: Dictionary = _state.snapshot()
	if not NpcState.valid(live):
		return _capture_failure("invalid_live_authority")
	var durable: Variant = _read_primary(_npc_path)
	if not NpcState.valid(durable):
		return _capture_failure("durable_authority_missing_corrupt_or_future")
	if not _eligible(live["records"][id], require_rest):
		return _capture_failure("live_npc_ineligible")
	if not _eligible(durable["records"][id], require_rest):
		return _capture_failure("durable_npc_ineligible")
	return {
		"kind": "npc", "actor_id": id, "npc_path": _npc_path,
		"source_schema": 1, "require_rest": require_rest,
		"live_fingerprint": _fingerprint(id, live["records"][id]),
		"durable_fingerprint": _fingerprint(id, durable["records"][id])
	}

func matches(fence: Dictionary) -> bool:
	if not _valid_fence(fence) or fence["npc_path"] != _npc_path:
		last_error = "invalid_or_foreign_fence"
		return false
	var current: Dictionary = capture(fence["actor_id"], fence["require_rest"])
	return not current.is_empty() and current["live_fingerprint"] == fence["live_fingerprint"] and current["durable_fingerprint"] == fence["durable_fingerprint"]

## Cold recovery reads the primary sidecar only; no live object or backup fallback.
## ok=false: malformed/missing/corrupt/future authority requires quarantine.
## ok=true, eligible=false: valid authority blocks advancement (including death).
## The writer decides proven abort/recovery; this adapter never changes either save.
static func durable_status(fence: Dictionary) -> Dictionary:
	if not _valid_fence(fence):
		return {"ok": false, "eligible": false, "unchanged": false}
	var durable: Variant = _read_primary(fence["npc_path"])
	if not NpcState.valid(durable):
		return {"ok": false, "eligible": false, "unchanged": false}
	var record: Dictionary = durable["records"][fence["actor_id"]]
	return {
		"ok": true,
		"eligible": _eligible(record, fence["require_rest"]),
		"unchanged": _fingerprint(fence["actor_id"], record) == fence["durable_fingerprint"]
	}

func _capture_failure(reason: String) -> Dictionary:
	last_error = reason
	return {}

static func _eligible(record: Dictionary, require_rest: bool) -> bool:
	if not record["death"].is_empty() or float(record["hp"]) < 1.0:
		return false
	if record["mode"] in ["dead", "downed", "recovering", "flee", "talk"]:
		return false
	return not require_rest or record["mode"] == "rest"

static func _fingerprint(id: String, record: Dictionary) -> String:
	var death: Dictionary = {}
	if not record["death"].is_empty():
		var tombstone: Dictionary = record["death"]
		death = {
			"event_id": tombstone["event_id"], "killer_id": tombstone["killer_id"],
			"tick": int(tombstone["tick"]), "room": tombstone["room"],
			"context": tombstone["context"]
		}
	var projection: Dictionary = {
		"actor_id": id, "room": record["room"], "episode": int(record["episode"]),
		"death": death, "hp": float(record["hp"]), "mode": record["mode"]
	}
	return JSON.stringify(projection, "", true, true).sha256_text()

static func _valid_fence(fence: Dictionary) -> bool:
	if fence.size() != 7 or not fence.get("kind") is String or fence["kind"] != "npc":
		return false
	if not fence.get("actor_id") is String or fence["actor_id"] not in NpcCatalog.IDS:
		return false
	if not fence.get("npc_path") is String or not fence.get("require_rest") is bool:
		return false
	var schema: Variant = fence.get("source_schema")
	if not (schema is int or schema is float) or not is_finite(float(schema)) or float(schema) != 1.0:
		return false
	var path: String = fence["npc_path"]
	if path.is_empty() or path != _canonical_user_path(path) or not path.ends_with(NPC_SUFFIX):
		return false
	if _canonical_user_path(path.trim_suffix(NPC_SUFFIX)).is_empty():
		return false
	return _hash_string(fence.get("live_fingerprint")) and _hash_string(fence.get("durable_fingerprint"))

static func _hash_string(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true

static func _canonical_user_path(path: String) -> String:
	if path.length() > 1024 or not path.begins_with("user://") or path.contains("\\"):
		return ""
	var relative: String = path.trim_prefix("user://")
	if relative.to_utf8_buffer().has(0): return ""
	for forbidden: String in [":", "\n", "\r", "\t", "*", "?", "|", "<", ">", "\""]:
		if relative.contains(forbidden):
			return ""
	var root: String = _path_identity("user://").trim_suffix("/")
	var absolute: String = _path_identity(path)
	if not absolute.begins_with(root + "/"):
		return ""
	var canonical_relative: String = absolute.substr(root.length() + 1)
	if canonical_relative.is_empty() or not canonical_relative.ends_with(".json"):
		return ""
	return "user://" + canonical_relative

static func _path_identity(path: String) -> String:
	var absolute: String = ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
	return absolute.to_lower() if OS.get_name() == "Windows" else absolute

static func _read_primary(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	if file.get_length() > MAX_BYTES:
		file.close()
		return null
	var text: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null

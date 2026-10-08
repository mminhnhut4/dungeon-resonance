extends SceneTree
## Read-only adapter probes against real, fixture-owned NPC schema and sidecars.
## Time is used only for unique QA paths, never for cultivation progression.
const Adapter = preload("res://scripts/cultivation/opening_npc_life_adapter.gd")
const NpcState = preload("res://scripts/npc/npc_world_state.gd")
const NpcCatalog = preload("res://scripts/npc/npc_pilot_catalog.gd")
const ID: String = "pilot_gatherer"
const NPC_SUFFIX: String = ".npc_v1.json"

class CountedState extends NpcWorldState:
	var save_calls: int = 0
	func save() -> bool:
		save_calls += 1
		return super.save()

var checks: int = 0
var failures: int = 0
var directory: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	directory = "user://verification/opening_adapter_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	print("OPENING_ADAPTER_USER_DIR=" + ProjectSettings.globalize_path("user://"))
	print("OPENING_ADAPTER_FIXTURE_ROOT=" + directory)
	_alive_and_projection()
	_terminal_states()
	_authority_faults()
	_path_binding()
	_malformed_fences()
	print("RESULT opening_npc_life_adapter checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)
	else:
		print("PASS: " + label)

func _fixture(label: String) -> CountedState:
	var state := CountedState.new()
	state.save_path = directory + "/" + label + "/profile.json" + NPC_SUFFIX
	_check(NpcState.valid(state.snapshot()), label + ": real default NPC schema is valid")
	state.records[ID]["mode"] = "rest"
	state.records[ID]["remaining"] = 32
	_check(NpcState.valid(state.snapshot()), label + ": authored gatherer rest fixture is valid")
	_check(state.save(), label + ": life owner saves its isolated primary sidecar")
	return state

func _bound(state: CountedState) -> Adapter:
	var adapter := Adapter.new()
	_check(adapter.configure(state, state.save_path.trim_suffix(NPC_SUFFIX)), "Adapter binds the existing state and its profile-derived primary")
	return adapter

func _raw(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)

func _write_fault(path: String, text: String) -> bool:
	# Corruption injection is confined to this unique test fixture's primary.
	if not path.begins_with(directory + "/"):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	return ok

func _alive_and_projection() -> void:
	var state: CountedState = _fixture("alive")
	var adapter: Adapter = _bound(state)
	var before: Dictionary = state.snapshot()
	var bytes_before: PackedByteArray = _raw(state.save_path)
	var calls_before: int = state.save_calls
	var fence: Dictionary = adapter.capture(ID)
	_check(fence.size() == 7 and fence.get("kind") == "npc" and fence.get("actor_id") == ID and fence.get("source_schema") == 1 and fence.get("require_rest") == true, "Stable gatherer produces the bounded NPC fence")
	_check(adapter.matches(fence), "Fresh live and durable fence matches")
	_check(Adapter.durable_status(fence) == {"ok": true, "eligible": true, "unchanged": true}, "Cold durable status accepts the same alive rest authority")
	var parser := JSON.new()
	var parsed_ok: bool = parser.parse(JSON.stringify(fence)) == OK
	_check(parsed_ok and parser.data is Dictionary, "Fence round-trips through data-only JSON")
	if parsed_ok and parser.data is Dictionary:
		_check(adapter.matches(parser.data), "JSON integral floats retain fence semantics")
		_check(Adapter.durable_status(parser.data) == {"ok": true, "eligible": true, "unchanged": true}, "Cold JSON fence preserves durable eligibility")
	_check(state.snapshot() == before and _raw(state.save_path) == bytes_before and state.save_calls == calls_before, "Capture, matches and recovery reads do not save or mutate authority")
	state.tick += 1
	state.records[ID]["x"] += 1.0
	state.records[ID]["remaining"] -= 1
	state.records[ID]["trust"] += 1
	_check(NpcState.valid(state.snapshot()) and adapter.matches(fence), "Gameplay tick, movement, rest timer and relationship changes are outside the life fence")
	state.records[ID]["hp"] -= 1.0
	_check(not adapter.matches(fence), "Unsaved HP change invalidates the captured live fence")
	state.records[ID]["hp"] += 1.0
	state.records[ID]["episode"] += 1
	_check(not adapter.matches(fence), "Episode identity change invalidates the captured life fence")
	state.records[ID]["episode"] -= 1
	state.records[ID]["mode"] = "work"
	_check(adapter.capture(ID).is_empty() and not adapter.matches(fence), "Default training requires current live rest")
	_check(not adapter.capture(ID, false).is_empty(), "Explicit life-only guard permits eligible live work")
	state.records[ID]["mode"] = "rest"
	state.read_only = true
	_check(adapter.capture(ID).is_empty() and not adapter.matches(fence), "Live authority quarantine blocks capture and commit guard")
	state.read_only = false
	_check(adapter.capture("invented_npc").is_empty(), "Unknown stable NPC identity is rejected")
	_check(_raw(state.save_path) == bytes_before and state.save_calls == calls_before, "All live projection probes leave durable bytes and life save count unchanged")

func _terminal_states() -> void:
	var state: CountedState = _fixture("terminal")
	var adapter: Adapter = _bound(state)
	var fence: Dictionary = adapter.capture(ID)
	var alive: Dictionary = state.records[ID].duplicate(true)
	var bytes_before: PackedByteArray = _raw(state.save_path)
	var calls_before: int = state.save_calls
	for mode: String in ["downed", "recovering", "flee", "talk"]:
		state.records[ID] = alive.duplicate(true)
		if mode == "talk": state.begin_talk(ID)
		else: state.records[ID]["mode"] = mode
		state.records[ID]["remaining"] = 0
		if mode in ["downed", "recovering"]:
			state.records[ID]["hp"] = 1.0
			state.records[ID]["episode"] = 1
		_check(NpcState.valid(state.snapshot()), "Fixture %s conforms to the real NPC life schema" % mode)
		_check(adapter.capture(ID, false).is_empty() and not adapter.matches(fence), "Unsaved %s blocks progression despite an alive durable primary" % mode)
	state.records[ID] = alive.duplicate(true)
	# A valid unsaved withdrawal tests the live guard without mutating disk.
	state.records[ID]["hp"] = 1.0
	state.records[ID]["mode"] = "recovering"
	state.records[ID]["remaining"] = 0
	state.records[ID]["episode"] = 1
	_check(NpcState.valid(state.snapshot()), "Unsaved withdrawal fixture is valid nonlethal life authority")
	_check(adapter.capture(ID, false).is_empty() and not adapter.matches(fence), "An unsaved live withdrawal takes precedence over an eligible primary")
	_check(Adapter.durable_status(fence) == {"ok": true, "eligible": true, "unchanged": true}, "Cold disk-only status cannot invent knowledge of unsaved withdrawal")
	_check(_raw(state.save_path) == bytes_before and state.save_calls == calls_before, "Adapter does not commit the fixture's unsaved terminal states")
	_check(state.save(), "Fixture life owner persists its schema-valid withdrawal")
	var dead_bytes: PackedByteArray = _raw(state.save_path)
	var dead_calls: int = state.save_calls
	_check(Adapter.durable_status(fence) == {"ok": true, "eligible": false, "unchanged": false}, "Persisted withdrawal is valid authority with denied advancement, not corrupt-save quarantine")
	_check(adapter.capture(ID, false).is_empty() and not adapter.matches(fence), "Withdrawn NPC can neither capture nor match an old eligible fence")
	_check(_raw(state.save_path) == dead_bytes and state.save_calls == dead_calls and state.records[ID]["mode"] == "recovering", "Reading withdrawn authority never heals, saves or modifies it")

func _authority_faults() -> void:
	for fault: String in ["future", "corrupt", "missing"]:
		var state: CountedState = _fixture(fault)
		var adapter: Adapter = _bound(state)
		var fence: Dictionary = adapter.capture(ID)
		var calls_before: int = state.save_calls
		var good_bytes: PackedByteArray = _raw(state.save_path)
		_check(DirAccess.copy_absolute(state.save_path, state.save_path + ".bak") == OK, fault + ": setup retains a valid alive historical backup")
		if fault == "future":
			var future: Dictionary = state.snapshot()
			future["npc_schema"] = NpcState.SCHEMA + 1
			_check(_write_fault(state.save_path, JSON.stringify(future)), "Future authority fault is written only to its synthetic fixture")
		elif fault == "corrupt":
			_check(_write_fault(state.save_path, "{broken"), "Corrupt authority fault is written only to its synthetic fixture")
		else:
			_check(DirAccess.remove_absolute(state.save_path) == OK, "Missing authority fault removes only its fixture primary")
		var fault_bytes: PackedByteArray = _raw(state.save_path) if FileAccess.file_exists(state.save_path) else PackedByteArray()
		_check(adapter.capture(ID).is_empty() and not adapter.matches(fence), fault + ": valid backup cannot substitute for unavailable primary authority")
		_check(Adapter.durable_status(fence) == {"ok": false, "eligible": false, "unchanged": false}, fault + ": recovery distinguishes quarantine from a valid death")
		_check(_raw(state.save_path + ".bak") == good_bytes and state.save_calls == calls_before, fault + ": adapter never restores a backup or calls life save")
		_check((not FileAccess.file_exists(state.save_path)) if fault == "missing" else _raw(state.save_path) == fault_bytes, fault + ": primary fault evidence remains unchanged")
		_check(not FileAccess.file_exists(state.save_path + ".tmp") and not FileAccess.file_exists(state.save_path + ".previous"), fault + ": reads create no commit artifacts")
	var unsaved := CountedState.new()
	unsaved.save_path = directory + "/never_saved/profile.json" + NPC_SUFFIX
	var unsaved_adapter: Adapter = _bound(unsaved)
	_check(unsaved_adapter.capture(ID, false).is_empty(), "Fresh default records without a primary sidecar cannot enroll")
	_check(unsaved.save_calls == 0 and not FileAccess.file_exists(unsaved.save_path), "Adapter never initializes an unsaved default population")
	var checkpoint: CountedState = _fixture("checkpoint")
	var checkpoint_adapter: Adapter = _bound(checkpoint)
	checkpoint.records[ID]["mode"] = "work"
	_check(checkpoint.save(), "Fixture life owner checkpoints its eligible work mode")
	checkpoint.records[ID]["mode"] = "rest"
	var checkpoint_calls: int = checkpoint.save_calls
	_check(checkpoint_adapter.capture(ID).is_empty(), "Live rest alone cannot substitute for a durable rest checkpoint")
	_check(not checkpoint_adapter.capture(ID, false).is_empty(), "Explicit life-only guard accepts valid work primary plus rest live state")
	_check(checkpoint.save_calls == checkpoint_calls, "Adapter leaves checkpoint ownership with the existing life owner")

func _path_binding() -> void:
	var state: CountedState = _fixture("aliases")
	var profile: String = state.save_path.trim_suffix(NPC_SUFFIX)
	var adapter := Adapter.new()
	var bytes_before: PackedByteArray = _raw(state.save_path)
	var calls_before: int = state.save_calls
	var alias: String = profile.get_base_dir() + "/./profile.json"
	_check(adapter.configure(state, alias), "Profile /./ alias canonicalizes to the actual NPC owner path")
	var fence: Dictionary = adapter.capture(ID)
	_check(not fence.is_empty() and fence.get("npc_path") == profile + NPC_SUFFIX, "Fence emits one canonical user path after profile alias binding")
	state.save_path = profile.get_base_dir() + "/./profile.json" + NPC_SUFFIX
	_check(adapter.matches(fence), "A live sidecar /./ alias retains the same owner identity")
	if OS.get_name() == "Windows":
		var case_alias: String = "user://" + profile.trim_prefix("user://").to_upper()
		state.save_path = case_alias + NPC_SUFFIX.to_upper()
		_check(adapter.configure(state, case_alias) and adapter.matches(fence), "Windows case aliases bind to the same canonical profile and sidecar")
	state.save_path = profile + NPC_SUFFIX
	_check(not adapter.configure(state, directory + "/foreign/profile.json"), "A sidecar cannot bind to a different profile owner")
	_check(adapter.capture(ID).is_empty(), "Failed reconfiguration clears an old authority binding")
	_check(not adapter.configure(state, "res://profile.json"), "Resource filesystem cannot serve as a user save authority")
	_check(not adapter.configure(state, "user://../profile.json"), "A path escaping the user root cannot bind")
	_check(not adapter.configure(state, state.save_path), "A sidecar path cannot masquerade as the canonical profile")
	_check(_raw(state.save_path) == bytes_before and state.save_calls == calls_before, "Path binding and rejection never write sidecar bytes")

func _malformed_fences() -> void:
	var state: CountedState = _fixture("invalid_fences")
	var adapter: Adapter = _bound(state)
	var fence: Dictionary = adapter.capture(ID)
	var bytes_before: PackedByteArray = _raw(state.save_path)
	var calls_before: int = state.save_calls
	var mutations: Array[Dictionary] = [
		{"field": "kind", "value": "player"},
		{"field": "kind", "value": 1},
		{"field": "actor_id", "value": "invented_npc"},
		{"field": "actor_id", "value": 1},
		{"field": "npc_path", "value": false},
		{"field": "npc_path", "value": state.save_path.trim_suffix(NPC_SUFFIX)},
		{"field": "npc_path", "value": state.save_path.get_base_dir() + "/./profile.json" + NPC_SUFFIX},
		{"field": "source_schema", "value": 2},
		{"field": "source_schema", "value": "1"},
		{"field": "require_rest", "value": 1},
		{"field": "live_fingerprint", "value": "0"},
		{"field": "durable_fingerprint", "value": "G".repeat(64)}
	]
	for mutation: Dictionary in mutations:
		var bad: Dictionary = fence.duplicate(true)
		bad[mutation["field"]] = mutation["value"]
		_check(not adapter.matches(bad), "Malformed %s fence cannot pass a live guard" % mutation["field"])
		_check(Adapter.durable_status(bad) == {"ok": false, "eligible": false, "unchanged": false}, "Malformed %s fence cannot select a cold authority" % mutation["field"])
	var extra: Dictionary = fence.duplicate(true)
	extra["unexpected"] = true
	_check(not adapter.matches(extra) and not Adapter.durable_status(extra)["ok"], "Unexpected fence fields cannot alter the recovery contract")
	var foreign: Dictionary = fence.duplicate(true)
	foreign["npc_path"] = directory + "/other/profile.json" + NPC_SUFFIX
	_check(not adapter.matches(foreign), "A structurally valid fence cannot switch the configured live owner")
	_check(_raw(state.save_path) == bytes_before and state.save_calls == calls_before, "Malformed-fence probes leave the primary and life owner untouched")

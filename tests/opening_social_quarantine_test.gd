extends SceneTree
## Transport-only integration fixture. The real NPC social schema-2 module is
## deliberately not imported; this synthetic validator proves the owner boundary.
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
const Spans = preload("res://scripts/runtime/profile_json_spans.gd")
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const SOCIAL: Array[String] = ["event_extensions", "namespaces", "npc_social"]
const LEGACY: Array[String] = ["npc_social_progress"]
const SYNTHETIC_STATE: Dictionary = {"fixture_only": true, "version": 2, "help_count": 0}

var checks: int = 0
var failures: int = 0
var directory: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	directory = "user://verification/opening_social_opaque_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	print("OPENING_SOCIAL_OPAQUE_USER_DIR=" + ProjectSettings.globalize_path("user://"))
	print("OPENING_SOCIAL_OPAQUE_FIXTURE_ROOT=" + directory)
	_unsupported_scope_core()
	_duplicate_inner_semantics()
	_live_invalid_revision()
	_legacy_core_transport()
	_opaque_journal_recovery()
	print("RESULT opening_social_quarantine checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)
	else:
		print("PASS: " + label)

static func _transport_only_validator(state: Dictionary) -> bool:
	return state.size() == 3 and state.get("fixture_only") == true and state.get("version") == 2 and MaterialCatalog.valid_count(state.get("help_count"))

func _decode(span: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(span) == OK else null

func _raw(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func _write_fixture(path: String, text: String) -> bool:
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

func _read(path: String, expected_ok: bool = true) -> SanctuaryProfile:
	var profile := SanctuaryProfile.new()
	profile.save_path = path
	var loaded: bool = profile.load_profile()
	_check(loaded == expected_ok and (loaded or profile.read_only), "Cold core profile has the expected load/quarantine result")
	if loaded:
		_check(profile.register_extension_validator("npc_social", Callable(self, "_transport_only_validator")), "Only a trusted synthetic transport validator is registered")
	return profile

func _fixture(label: String, raw_span: String, legacy_span: String = "", v2: bool = true) -> SanctuaryProfile:
	var profile := SanctuaryProfile.new()
	profile.save_path = directory + "/" + label + "/profile.json"
	profile.souls = 80
	profile.material_stash[&"dust"] = 10
	profile.material_stash[&"linen_fiber"] = 8
	profile.material_stash[&"crystal"] = 20
	var ready: bool = profile.save()
	if ready and v2:
		ready = profile.commit_cultivation(Model.initial_proposal(Model.new_progress(7),profile.material_stash,profile.souls,profile.boss_proofs))
	var payload: Dictionary = Writer.read_json(profile.save_path)
	payload["event_extensions"] = {"schema_version": 1, "namespaces": {
		"npc_social": _decode(raw_span),
		"courier": {"revision": 0, "state": {"version": 1, "accepted": false, "contact_recorded": false, "contact_source": "", "outcome": ""}, "receipts": []},
		"sect": {"revision": 0, "state": {"fixture_marker": "preserve"}, "receipts": []}
	}}
	if not legacy_span.is_empty():
		payload["npc_social_progress"] = _decode(legacy_span)
	if v2:
		# Initial three-field seal binds parsed semantics. The first core commit
		# adds raw-span hashes without converting or repairing unsupported social.
		payload = Writer.sealed(payload, 1)
	var text: String = Spans.replace(Writer.canonical(payload), SOCIAL, raw_span)
	if not legacy_span.is_empty():
		text = Spans.replace(text, LEGACY, legacy_span)
	_check(ready and not text.is_empty() and _write_fixture(profile.save_path, text), label + ": isolated unsupported social fixture is complete valid JSON")
	return _read(profile.save_path)

func _span(profile: SanctuaryProfile, path: Array[String]) -> String:
	return Spans.extract(FileAccess.get_file_as_string(profile.save_path), path).get("span", "")

func _life(profile: SanctuaryProfile) -> NpcWorldState:
	var state := NpcWorldState.new()
	state.save_path = profile.save_path + ".npc_v1.json"
	_check(state.save(), "Existing NPC life owner creates only its fixture sidecar")
	# The authority, rather than a profile transport fixture, owns this explicit
	# confirmed death. Subsequent core saves must preserve the durable tombstone.
	state.receive_hit("pilot_traveler", 1.0, 0.0)
	var token: String = state.decision_token("pilot_traveler")
	_check(not token.is_empty() and state.decide("pilot_traveler", token, true, true) and NpcWorldState.valid(state.snapshot()) and state.records["pilot_traveler"]["mode"] == "dead", "Actual NPC owner persists an explicit confirmed-death tombstone")
	return state

func _blocked(profile: SanctuaryProfile, label: String) -> void:
	var before: PackedByteArray = _raw(profile.save_path)
	var materials: Dictionary = profile.material_stash.duplicate()
	var souls: int = profile.souls
	var result: Dictionary = profile.commit_extension_event("npc_social", "blocked_social_help", {&"linen_fiber": 2}, 1, SYNTHETIC_STATE, 0)
	_check(not profile.social_transactions_available() and profile.extension_revision("npc_social") == -1 and profile.extension_state("npc_social").is_empty(), label + ": social state and revision are explicitly unavailable")
	_check(not result.get("ok", true) and result.get("status") == "extension_quarantined" and profile.material_stash == materials and profile.souls == souls and _raw(profile.save_path) == before and not profile.read_only, label + ": unsupported social is blocked before any debit while core remains writable")

func _unsupported_scope_core() -> void:
	var cases: Array[Dictionary] = [
		{"id": "malformed", "span": " \t\r\n{\"revision\":9.00e+02,\"state\":{\"fixture_only\":true,\"version\":2,\"help_count\":0,\"label\":\"\\u0043ảnh 漢🌿\"},\"receipts\":[{\"id\":\"a\",\"id\":\"b\"}]} \r\n"},
		{"id": "future", "span": "\n {\"revision\":0,\"state\":{\"fixture_only\":true,\"version\":99,\"help_count\":0,\"label\":\"Thư 漢🌿\",\"amount\":1.2300E+02},\"receipts\":[]} \t"}
	]
	for scenario: Dictionary in cases:
		var profile: SanctuaryProfile = _fixture(scenario["id"], scenario["span"])
		var life: NpcWorldState = _life(profile)
		var life_bytes: PackedByteArray = _raw(life.save_path)
		var culture: Dictionary = profile.cultivation_progress.duplicate(true)
		var sect: Dictionary = profile.extension_state("sect")
		var courier: Dictionary = profile.courier_objectives()
		_blocked(profile, scenario["id"])
		_check(_span(profile, SOCIAL) == scenario["span"], scenario["id"] + ": cold load preserves every original opaque character")
		var economy := EconomySession.new()
		economy.profile = profile
		economy.inventory = GearInventory.new()
		_check(economy.buy_upgrade(&"max_hp") and profile.permanent_upgrades[&"max_hp"] == 1 and profile.souls == 60 and _span(profile, SOCIAL) == scenario["span"], scenario["id"] + ": real HP-upgrade save works and retains the unsupported social span")
		var committed: Dictionary = Writer.read_json(profile.save_path)
		_check(Writer.seal_valid(committed) and committed["profile_commit"].get("opaque_sha256", {}).get("npc_social") == scenario["span"].sha256_text(), scenario["id"] + ": first core save binds the exact opaque span into the sealed profile")
		profile.material_stash[&"dust"] += 1
		_check(profile.save() and _span(profile, SOCIAL) == scenario["span"] and _raw(life.save_path) == life_bytes, scenario["id"] + ": bank save leaves social and life bytes untouched")
		var cold: SanctuaryProfile = _read(profile.save_path)
		_check(cold.cultivation_progress == culture and cold.permanent_upgrades[&"max_hp"] == 1 and cold.material_stash[&"dust"] == 11 and cold.extension_state("sect") == sect and cold.courier_objectives() == courier and _span(cold, SOCIAL) == scenario["span"], scenario["id"] + ": cold core restore retains independent progress and scopes")
		_blocked(cold, scenario["id"] + " cold")
		var old_image: PackedByteArray = _raw(cold.save_path)
		cold._writer.fault_plan = {"write_candidate": true}
		_check(not cold.try_add_souls(2) and cold.souls == 60 and _raw(cold.save_path) == old_image and not cold.read_only, scenario["id"] + ": candidate-write fault retains the exact old image and cost")
		_check(cold.try_add_souls(2) and cold.souls == 62 and _span(cold, SOCIAL) == scenario["span"] and _raw(life.save_path) == life_bytes, scenario["id"] + ": explicit core retry preserves opaque social and NPC authority")
		var source: String = FileAccess.get_file_as_string(cold.save_path)
		var tampered: String = Spans.replace(source, SOCIAL, " " + scenario["span"])
		_check(not tampered.is_empty() and _write_fixture(cold.save_path, tampered), scenario["id"] + ": raw-only tamper retains valid JSON and the same parsed social value")
		var parsed: Variant = _decode(tampered)
		_check(parsed is Dictionary and Writer.seal_valid(Writer.normalized(parsed)) and Writer.read_json(cold.save_path) == null, scenario["id"] + ": raw hash detects tamper that semantic canonical sealing alone cannot see")
		var rejected: SanctuaryProfile = _read(cold.save_path, false)
		_check(rejected.read_only and not rejected.save() and FileAccess.get_file_as_string(cold.save_path) == tampered and _raw(life.save_path) == life_bytes, scenario["id"] + ": whole-file quarantine preserves tamper evidence and life authority")

func _duplicate_inner_semantics() -> void:
	var values: Array[String] = [
		" {\"revision\":0,\"state\":{\"fixture_only\":true,\"version\":2,\"help_count\":1,\"\\u0068elp_count\":0},\"receipts\":[]} ",
		"\t{\"revision\":0,\"revision\":0,\"state\":{\"fixture_only\":true,\"version\":2,\"help_count\":0},\"receipts\":[]} \n",
		" {\"revision\":1,\"state\":{\"fixture_only\":true,\"version\":2,\"help_count\":0},\"receipts\":[{\"id\":\"a\",\"id\":\"a\",\"arguments_sha256\":\"" + "0".repeat(64) + "\",\"revision\":1}]} "
	]
	for index: int in values.size():
		var profile: SanctuaryProfile = _fixture("duplicate_%d" % index, values[index])
		_check(SanctuaryProfile._valid_extension_entry(_decode(values[index])) and _transport_only_validator(_decode(values[index])["state"]), "Duplicate-inner fixture looks valid after last-key-wins parsing")
		_check(not Spans.unique_value(values[index]), "Raw uniqueness gate rejects semantic ambiguity inside an opaque value")
		_blocked(profile, "duplicate inner")
		_check(profile.try_add_souls(1) and _span(profile, SOCIAL) == values[index], "Core saving preserves valid-looking duplicate social data without interpreting it")
		var cold: SanctuaryProfile = _read(profile.save_path)
		_check(not cold.social_transactions_available() and _span(cold, SOCIAL) == values[index], "Cold duplicate-inner state remains transaction-blocked and raw-identical")

func _live_invalid_revision() -> void:
	var good: String = " {\"revision\":0,\"state\":{\"fixture_only\":true,\"version\":2,\"help_count\":0},\"receipts\":[]} "
	var profile: SanctuaryProfile = _fixture("live_invalid", good)
	_check(profile.social_transactions_available() and profile.extension_revision("npc_social") == 0, "Unambiguous synthetic state is available only after trusted validation")
	profile._retained_fields["event_extensions"]["namespaces"]["npc_social"]["revision"] = -1
	_blocked(profile, "invalid live revision")
	_check(profile.save() and not profile.read_only, "Core save preserves a live unsupported envelope instead of silently deleting it")
	var cold: SanctuaryProfile = _read(profile.save_path)
	_check(cold.extension_revision("npc_social") == -1 and not cold.social_transactions_available() and cold.souls == 80 and cold.material_stash[&"linen_fiber"] == 8, "Cold malformed revision exposes no revision and no debit")

func _legacy_core_transport() -> void:
	var field_span: String = "\t{\"revision\":4,\"state\":{\"version\":99,\"value\":7e+02},\"receipts\":[]} \n"
	var legacy_span: String = " \r\n{\"version\":99,\"utf\":\"漢🌿\",\"receipt\":\"old\",\"receipt\":\"last\",\"escaped\":\"\\u0041\"} \t"
	for v2: bool in [false, true]:
		var profile: SanctuaryProfile = _fixture("legacy_v%d" % (2 if v2 else 1), field_span, legacy_span, v2)
		_blocked(profile, "legacy social present")
		var life: NpcWorldState = _life(profile)
		var life_bytes: PackedByteArray = _raw(life.save_path)
		var economy := EconomySession.new()
		economy.profile = profile
		economy.inventory = GearInventory.new()
		_check(economy.buy_upgrade(&"max_hp") and _span(profile, SOCIAL) == field_span and _span(profile, LEGACY) == legacy_span and _raw(life.save_path) == life_bytes, "Legacy and namespace social spans survive a real core upgrade in both profile formats")
		var cold: SanctuaryProfile = _read(profile.save_path)
		_check(cold.profile_version == (2 if v2 else 1) and cold.permanent_upgrades[&"max_hp"] == 1 and _span(cold, SOCIAL) == field_span and _span(cold, LEGACY) == legacy_span and not cold.social_transactions_available(), "Cold legacy/core compatibility preserves exact spans and quarantines social alone")
		if v2:
			var sealed: Dictionary = Writer.read_json(cold.save_path)
			_check(sealed["profile_commit"]["opaque_sha256"] == {"npc_social": field_span.sha256_text(), "legacy_npc_social": legacy_span.sha256_text()}, "Version-two seal binds both opaque social representations")

func _opaque_journal_recovery() -> void:
	var field_span: String = " \r\n{\"revision\":999,\"state\":{\"version\":99,\"utf\":\"漢🌿\",\"n\":1.00e+02},\"receipts\":[{\"id\":\"old\",\"id\":\"last\"}]} \t"
	for point: String in ["after_candidate","after_decision","after_old_rename","after_commit"]:
		var profile: SanctuaryProfile = _fixture("raw_pending_"+point,field_span)
		var life: NpcWorldState = _life(profile)
		var life_bytes: PackedByteArray = _raw(life.save_path)
		profile._writer.fault_plan={point:true}
		_check(not profile.try_add_souls(2) and profile.read_only,point+": opaque candidate reaches a known interrupted journal window")
		var cold: SanctuaryProfile = _read(profile.save_path)
		var expected: int = 80 if point=="after_candidate" else 82
		_check(cold.souls==expected and _span(cold,SOCIAL)==field_span and _raw(life.save_path)==life_bytes,point+": recovery preserves exact social span/tombstone with one proven cost image")
		_check(not cold.social_transactions_available() and cold.extension_revision("npc_social")==-1 and not FileAccess.file_exists(cold.save_path+".decision") and not FileAccess.file_exists(cold.save_path+".tmp") and not FileAccess.file_exists(cold.save_path+".previous"),point+": recovery never interprets social or leaves journal intent")
		_check(cold.save() and Writer.seal_valid(Writer.read_json(cold.save_path)) and _span(cold,SOCIAL)==field_span,point+": later ordinary core commit retains a valid seal and exact opaque data")

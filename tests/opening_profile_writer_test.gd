extends SceneTree
## Consumer-visible persistence contracts using real profiles and NPC sidecars.
## Only unique QA fixtures are written; fault hooks are trusted test inputs.
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Adapter = preload("res://scripts/cultivation/opening_npc_life_adapter.gd")
const NPC: String = "pilot_gatherer"
const NPC_SUFFIX: String = ".npc_v1.json"
const SOCIAL_STATE: Dictionary = {"help_count": 1, "helped_ids": ["pilot_gatherer"]}

var checks: int = 0
var failures: int = 0
var notifications: int = 0
var directory: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	directory = "user://verification/opening_writer_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	print("OPENING_WRITER_USER_DIR=" + ProjectSettings.globalize_path("user://"))
	print("OPENING_WRITER_FIXTURE_ROOT=" + directory)
	_migration_and_common_saves()
	_social_and_courier()
	_ordinary_faults()
	_uncertain_cleanup()
	_crash_recovery()
	_quarantine()
	_npc_cultivation_gate()
	_npc_guards()
	_stale_writer()
	print("RESULT opening_profile_writer checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)
	else:
		print("PASS: " + label)

func _fixture(label: String, migrate: bool = true) -> SanctuaryProfile:
	var profile := SanctuaryProfile.new()
	profile.save_path = directory + "/" + label + "/profile.json"
	profile.souls = 200
	profile.coins = 20
	profile.material_stash[&"linen_fiber"] = 8
	profile.material_stash[&"dust"] = 10
	profile.material_stash[&"crystal"] = 20
	profile.boss_proofs[&"golem"] = 1
	var saved: bool = profile.save()
	var migrated: bool = not migrate
	if saved and migrate:
		migrated = profile.commit_cultivation(Model.initial_proposal(Model.new_progress(7),profile.material_stash,profile.souls,profile.boss_proofs))
	_check(saved and migrated, label + ": real legacy profile and requested cultivation fixture are durable")
	return profile

func _reader(path: String, expected_ok: bool = true) -> SanctuaryProfile:
	var profile := SanctuaryProfile.new()
	profile.save_path = path
	var loaded: bool = profile.load_profile()
	_check(loaded == expected_ok and (loaded or profile.read_only), "Cold profile load has the expected recovery/quarantine result")
	return profile

func _raw(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func _data(profile: SanctuaryProfile) -> Dictionary:
	var data: Variant = Writer.read_json(profile.save_path)
	return data if data is Dictionary else {}

func _revision(profile: SanctuaryProfile) -> int:
	return int(_data(profile).get("profile_commit", {}).get("revision", 0))

func _write_fault(path: String, text: String) -> bool:
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

func _social(profile: SanctuaryProfile, fence: Dictionary = {}, guard: Callable = Callable()) -> Dictionary:
	return profile.commit_extension_event("social", "social_help_v1", {&"linen_fiber": 2}, 0, SOCIAL_STATE, profile.extension_revision("social"), fence, guard)

func _social_once(profile: SanctuaryProfile, label: String) -> void:
	var before: PackedByteArray = _raw(profile.save_path)
	var result: Dictionary = _social(profile)
	_check(result.get("ok", false) and result.get("status") == "already_committed" and profile.material_stash[&"linen_fiber"] == 6 and profile.extension_revision("social") == 1 and _raw(profile.save_path) == before, label + ": replay cannot consume or publish a second social effect")

func _common_check(profile: SanctuaryProfile, progress: Dictionary, label: String, ok: bool) -> void:
	var data: Dictionary = _data(profile)
	_check(ok and Writer.seal_valid(data) and data.get("cultivation_progress") == progress and data.get("opaque_root") == {"schema_version": 7, "marker": "keep_root"} and data.get("world_progress", {}).get("opaque_world") == {"marker": "keep_world"}, label + ": common save retains cultivation and unrelated root/world extensions")

func _migration_and_common_saves() -> void:
	var legacy: SanctuaryProfile = _fixture("migration", false)
	var initial: Dictionary = _data(legacy)
	_check(initial.get("version") == 1 and not initial.has("cultivation_progress") and not initial.has("profile_commit"), "Legacy save remains version one before explicit enrollment")
	initial["opaque_root"] = {"schema_version": 7, "marker": "keep_root"}
	initial["world_progress"]["opaque_world"] = {"marker": "keep_world"}
	_check(_write_fault(legacy.save_path, JSON.stringify(initial)), "Unknown-extension fixture originates from a legacy file")
	var profile: SanctuaryProfile = _reader(legacy.save_path)
	var proposal: Dictionary = Model.initial_proposal(Model.new_progress(7),profile.material_stash,profile.souls,profile.boss_proofs)
	_check(profile.commit_cultivation(proposal) and profile.profile_version == 2, "Explicit cultivation initialization migrates the complete profile once")
	var migrated: Dictionary = _data(profile)
	_check(Writer.seal_valid(migrated) and _revision(profile) == 1 and Writer.read_json(profile.save_path + ".format_v2") == {"marker_version": 1, "profile_format": 2}, "Migration establishes a sealed profile and durable format marker")
	_check(migrated.get("opaque_root") == initial["opaque_root"] and migrated["world_progress"].get("opaque_world") == initial["world_progress"]["opaque_world"], "Migration preserves unknown root and world data")
	var training: Dictionary = Model.propose(profile.cultivation_progress, profile.material_stash, profile.souls, profile.boss_proofs, "train", {"actor_id": "player", "sessions": 1, "target_tick": 8}, "player_train_v1")
	_check(profile.commit_cultivation(training) and profile.material_stash[&"crystal"] == 19 and profile.cultivation_progress["actors"]["player"]["energy"] == 8, "One accepted training commits its cost and progress together")
	var progress: Dictionary = profile.cultivation_progress.duplicate(true)
	_common_check(profile, progress, "Soul reward", profile.try_add_souls(2))
	_common_check(profile, progress, "Soul spending", profile.spend(1))
	_common_check(profile, progress, "Style selection", profile.set_style(&"steady"))
	_common_check(profile, progress, "Starter selection", profile.set_starting_weapon(&"shadow_dagger"))
	_common_check(profile, progress, "Weapon unlock", profile.unlock_weapon(&"blade_fan"))
	profile.discover(&"firestorm")
	_common_check(profile, progress, "Recipe discovery", profile.discovered_recipes.has(&"firestorm"))
	_common_check(profile, progress, "Recipe archive", profile.archive(&"firestorm"))
	_common_check(profile, progress, "Blueprint learning", profile.learn_blueprint(&"world_saber_common"))
	_common_check(profile, progress, "Boss receipt", profile.record_boss_defeat("fixture_golem_01"))
	_common_check(profile, progress, "Opening milestone", profile.record_opening_event(&"explored"))
	profile.coins += 1
	_common_check(profile, progress, "Ordinary bank save", profile.save())
	var cold: SanctuaryProfile = _reader(profile.save_path)
	_check(cold.cultivation_progress == progress and cold.material_stash == profile.material_stash and cold.souls == profile.souls and cold.opening_progress == profile.opening_progress, "Cold restore retains exact earned cultivation and common opening progress")
	var cold_bytes: PackedByteArray = _raw(cold.save_path)
	var replay: Dictionary = Model.propose(cold.cultivation_progress, cold.material_stash, cold.souls, cold.boss_proofs, "train", {"actor_id": "player", "sessions": 1, "target_tick": 8}, "player_train_v1")
	_check(cold.commit_cultivation(replay) and _raw(cold.save_path) == cold_bytes and cold.material_stash[&"crystal"] == 19, "Cold replay of training does not consume another crystal")

func _social_and_courier() -> void:
	var profile: SanctuaryProfile = _fixture("social")
	_check(profile.commit_extension_event("sect", "sect_state_v1", {}, 0, {"fixture_marker": "sect_survives"}).get("ok", false), "Unrelated sect state uses the same profile owner")
	_check(profile.record_courier_offer() and profile.record_courier_contact("shrine"), "Courier scope is established through public wrapper methods")
	var sect: Dictionary = profile.extension_state("sect")
	var courier: Dictionary = profile.courier_objectives()
	var cultivation: Dictionary = profile.cultivation_progress.duplicate(true)
	var revision_before: int = _revision(profile)
	notifications = 0
	profile.changed.connect(func() -> void: notifications += 1)
	var result: Dictionary = _social(profile)
	_check(result.get("ok", false) and result.get("status") == "committed" and profile.material_stash[&"linen_fiber"] == 6 and profile.souls == 200, "Social help consumes exactly two linen in its own transaction")
	_check(profile.extension_state("social") == SOCIAL_STATE and profile.extension_revision("social") == 1 and _revision(profile) == revision_before + 1 and notifications == 1, "Social state, one receipt and one notification publish with the cost")
	_check(profile.extension_state("sect") == sect and profile.courier_objectives() == courier and profile.cultivation_progress == cultivation, "Social transaction preserves sect, courier and cultivation authorities")
	_social_once(profile, "Live social event")
	var before: PackedByteArray = _raw(profile.save_path)
	var conflict: Dictionary = profile.commit_extension_event("social", "social_help_v1", {&"linen_fiber": 2}, 0, {"help_count": 2}, 1)
	_check(not conflict.get("ok", true) and conflict.get("error") == "event_conflict" and _raw(profile.save_path) == before, "Reusing an event receipt with a different reward is rejected")
	var stale: Dictionary = profile.commit_extension_event("social", "social_help_v2", {&"linen_fiber": 2}, 0, {"help_count": 2}, 0)
	_check(not stale.get("ok", true) and stale.get("error") == "revision_or_capacity" and _raw(profile.save_path) == before, "Compare-and-swap rejects an obsolete social state revision")
	_check(not profile.commit_extension_event("social", "invalid_callback", {}, 0, {"callback": Callable(self, "_run")}, 1).get("ok", true) and _raw(profile.save_path) == before, "Executable content cannot enter an extension state")
	var cold: SanctuaryProfile = _reader(profile.save_path)
	_social_once(cold, "Cold social event")
	_check(cold.extension_state("sect") == sect and cold.courier_objectives() == courier, "Cold social restore retains independent scopes")
	for choice: StringName in [&"help", &"prepare"]:
		var bank: SanctuaryProfile = _fixture("courier_" + String(choice))
		_check(not bank.record_courier_contact("shrine") and not bank.quote_courier_choice(choice)["available"], "Courier contact and choice require an accepted offer")
		_check(bank.record_courier_offer() and bank.record_courier_offer() and bank.extension_revision("courier") == 1, "Offer receipt is durable and idempotent")
		_check(not bank.record_courier_contact("invented_source") and bank.record_courier_contact("pilgrim"), "Courier records one authorized contact source")
		var quote: Dictionary = bank.quote_courier_choice(choice)
		_check(quote["available"] and quote["souls_cost"] == 0 and quote["materials_cost"] == ({&"dust": 1} if choice == &"help" else {}) and quote["tuning_status"] == "proposal_not_final", "Courier quote exposes only the agreed dust tradeoff")
		var linen_before: int = bank.material_stash[&"linen_fiber"]
		_check(bank.commit_courier_choice(choice) and bank.material_stash[&"dust"] == (9 if choice == &"help" else 10) and bank.souls == 200 and bank.material_stash[&"linen_fiber"] == linen_before, "Courier choice has no Soul, cloth or social-help side effect")
		var event: Dictionary = bank.courier_choice_event()
		_check(event.get("receipt") == "opening_courier_supply_v1" and event.get("outcome") == String(choice) and bank.extension_revision("courier") == 3 and bank.extension_state("social").is_empty(), "Mutually exclusive courier outcomes share a single receipt")
		var choice_bytes: PackedByteArray = _raw(bank.save_path)
		_check(bank.commit_courier_choice(choice) and _raw(bank.save_path) == choice_bytes, "Same courier choice replays without another cost or receipt")
		var other: StringName = &"prepare" if choice == &"help" else &"help"
		_check(not bank.quote_courier_choice(other)["available"] and not bank.commit_courier_choice(other) and _raw(bank.save_path) == choice_bytes, "Opposite courier outcome cannot overwrite the chosen receipt")
		var restored: SanctuaryProfile = _reader(bank.save_path)
		_check(restored.courier_choice_event() == event and restored.material_stash == bank.material_stash, "Cold courier restore preserves the one selected consequence")

func _ordinary_faults() -> void:
	for point: String in ["write_candidate", "write_decision", "rename_decision", "rename_old", "commit"]:
		var profile: SanctuaryProfile = _fixture("fault_" + point)
		var before: PackedByteArray = _raw(profile.save_path)
		profile._writer.fault_plan = {point: true}
		var result: Dictionary = _social(profile)
		_check(not result.get("ok", true) and result.get("status") == "rejected" and not profile.read_only, point + ": verified durable abort reports definitive rejection")
		_check(_raw(profile.save_path) == before and profile.material_stash[&"linen_fiber"] == 8 and profile.extension_state("social").is_empty(), point + ": rejection preserves stock, progress and receipt")
		var cold: SanctuaryProfile = _reader(profile.save_path)
		_check(cold.material_stash[&"linen_fiber"] == 8 and cold.extension_state("social").is_empty(), point + ": cold recovery cannot apply a definitively aborted effect")
		_check(_social(cold).get("ok", false) and cold.material_stash[&"linen_fiber"] == 6, point + ": explicit retry may commit once after safe abort")
		_social_once(cold, point)

func _uncertain_cleanup() -> void:
	var cases: Array[Dictionary] = [
		{"id": "pending_remove", "plan": {"commit": true, "remove_tmp": true}, "recover": true},
		{"id": "abort_cleanup", "plan": {"commit": true, "cleanup": true}, "recover": true},
		{"id": "rollback", "plan": {"commit": true, "rollback": true}, "recover": true},
		{"id": "decision_remove", "plan": {"commit": true, "remove_decision": true}, "recover": false}
	]
	for scenario: Dictionary in cases:
		var profile: SanctuaryProfile = _fixture("compound_" + scenario["id"])
		profile._writer.fault_plan = scenario["plan"].duplicate()
		var result: Dictionary = _social(profile)
		_check(not result.get("ok", true) and result.get("status") == "quarantined" and result.get("recovery_required", false) and profile.read_only, scenario["id"] + ": unresolved abort never falsely reports a definitive rejection")
		_check(profile.material_stash[&"linen_fiber"] == 8 and profile.extension_state("social").is_empty() and FileAccess.file_exists(profile.save_path + ".decision"), scenario["id"] + ": RAM is rolled back while unresolved durable intent remains")
		var cold: SanctuaryProfile = _reader(profile.save_path, scenario["recover"])
		if scenario["recover"]:
			_check(cold.last_commit.get("status") == "recovered_committed" and cold.material_stash[&"linen_fiber"] == 6 and cold.extension_revision("social") == 1, scenario["id"] + ": recovery resolves pending cost and reward exactly once")
			_social_once(cold, scenario["id"])
		else:
			_check(cold.read_only and cold.last_commit.get("error") == "invalid_pending" and _data(cold).get("material_stash", {}).get("linen_fiber") == 8, "Missing candidate with unresolved decision remains quarantined without granting a reward")
	var committed: SanctuaryProfile = _fixture("committed_cleanup")
	committed._writer.fault_plan = {"cleanup": true}
	var success: Dictionary = _social(committed)
	_check(success.get("ok", false) and committed.last_commit.get("cleanup_pending", false) and committed.material_stash[&"linen_fiber"] == 6, "Post-commit cleanup failure preserves a successful durable transaction")
	var restored: SanctuaryProfile = _reader(committed.save_path)
	_check(restored.last_commit.get("status") == "recovered_committed" and not FileAccess.file_exists(committed.save_path + ".decision"), "Cold load completes pending cleanup of an already committed image")
	_social_once(restored, "Post-commit cleanup")

func _crash_recovery() -> void:
	for point: String in ["after_candidate", "after_decision", "after_old_rename", "after_commit"]:
		var profile: SanctuaryProfile = _fixture("crash_" + point)
		profile._writer.fault_plan = {point: true}
		var result: Dictionary = _social(profile)
		_check(not result.get("ok", true) and result.get("status") == "quarantined" and profile.material_stash[&"linen_fiber"] == 8, point + ": interrupted caller publishes no speculative RAM reward")
		var cold: SanctuaryProfile = _reader(profile.save_path)
		if point == "after_candidate":
			_check(cold.material_stash[&"linen_fiber"] == 8 and cold.extension_state("social").is_empty() and not FileAccess.file_exists(profile.save_path + ".tmp"), "Candidate without decision is discarded, never promoted")
			_check(_social(cold).get("ok", false), "Explicit retry commits the discarded pre-decision event")
		else:
			_check(cold.last_commit.get("status") == "recovered_committed" and cold.material_stash[&"linen_fiber"] == 6 and cold.extension_revision("social") == 1, point + ": proven decision recovers one cost and reward")
		_social_once(cold, point)
		var again: SanctuaryProfile = _reader(cold.save_path)
		_check(again.material_stash == cold.material_stash and again.extension_state("social") == SOCIAL_STATE, point + ": second cold load is exact and stable")

func _quarantine() -> void:
	var faults: Array[Dictionary] = [
		{"id": "future_root", "field": "version", "value": 3},
		{"id": "dict_version", "field": "version", "value": {"bad": 1}},
		{"id": "array_version", "field": "version", "value": [2]},
		{"id": "string_version", "field": "version", "value": "2"},
		{"id": "bool_version", "field": "version", "value": true},
		{"id": "future_cultivation", "field": "cultivation_schema", "value": 2},
		{"id": "malformed_cultivation", "field": "cultivation_schema", "value": []},
		{"id": "corrupt_json", "field": "raw", "value": "{broken"},
		{"id": "corrupt_seal", "field": "souls", "value": 201},
		{"id": "future_marker", "field": "marker", "value": {"marker_version": 2, "profile_format": 3}},
		{"id": "missing_main", "field": "missing", "value": null}
	]
	for fault: Dictionary in faults:
		var profile: SanctuaryProfile = _fixture("quarantine_" + fault["id"])
		var valid_bytes: PackedByteArray = _raw(profile.save_path)
		var injected: bool = DirAccess.copy_absolute(profile.save_path, profile.save_path + ".bak") == OK
		var altered: Dictionary = _data(profile).duplicate(true)
		match fault["field"]:
			"cultivation_schema":
				altered["cultivation_progress"]["schema_version"] = fault["value"]
				injected = _write_fault(profile.save_path, JSON.stringify(altered)) and injected
			"raw": injected = _write_fault(profile.save_path, fault["value"]) and injected
			"marker": injected = _write_fault(profile.save_path + ".format_v2", JSON.stringify(fault["value"])) and injected
			"missing": injected = DirAccess.remove_absolute(profile.save_path) == OK and injected
			_:
				altered[fault["field"]] = fault["value"]
				injected = _write_fault(profile.save_path, JSON.stringify(altered)) and injected
		_check(injected, fault["id"] + ": malformed/future fault is confined to its own fixture")
		var evidence: PackedByteArray = _raw(profile.save_path)
		var marker: PackedByteArray = _raw(profile.save_path + ".format_v2")
		var cold: SanctuaryProfile = _reader(profile.save_path, false)
		_check(cold.read_only and not cold.save() and _raw(profile.save_path) == evidence and _raw(profile.save_path + ".format_v2") == marker and _raw(profile.save_path + ".bak") == valid_bytes, fault["id"] + ": quarantine neither overwrites evidence nor restores stale resources")

func _npc_fixture(profile: SanctuaryProfile) -> Dictionary:
	var state := NpcWorldState.new()
	state.save_path = profile.save_path + NPC_SUFFIX
	state.records[NPC]["mode"] = "rest"
	state.records[NPC]["remaining"] = 32
	var saved: bool = state.save()
	var adapter := Adapter.new()
	var bound: bool = adapter.configure(state, profile.save_path)
	var fence: Dictionary = adapter.capture(NPC)
	_check(saved and bound and not fence.is_empty() and NpcWorldState.valid(state.snapshot()), "NPC fixture uses real saved rest state and stable gatherer authority")
	return {"state": state, "adapter": adapter, "fence": fence, "guard": Callable(adapter, "matches").bind(fence)}

func _fixture_death(state: NpcWorldState, persist: bool) -> void:
	# Retained helper name: fixture now invalidates eligibility by withdrawal.
	state.records[NPC]["hp"] = 1.0
	state.records[NPC]["mode"] = "recovering"
	state.records[NPC]["remaining"] = 0
	state.records[NPC]["interrupted"] = {}
	state.records[NPC]["episode"] = 1
	if persist:
		_check(state.save(), "Fixture life owner persists valid nonlethal withdrawal authority")

func _npc_cultivation_gate() -> void:
	var profile: SanctuaryProfile = _fixture("npc_cultivation_guard")
	var life: Dictionary = _npc_fixture(profile)
	var enroll: Dictionary = Model.propose(profile.cultivation_progress, profile.material_stash, profile.souls, profile.boss_proofs, "enroll", {"enabled": true}, "npc_enroll_v1")
	var before: PackedByteArray = _raw(profile.save_path)
	_check(not profile.commit_cultivation(enroll) and _raw(profile.save_path) == before and not profile.cultivation_progress["actors"].has(NPC), "Direct NPC creation without the matching life fence is rejected")
	_check(profile.commit_cultivation(enroll, life["fence"], life["guard"]) and profile.cultivation_progress["actors"].has(NPC), "Real saved rest authority permits explicit bounded NPC enrollment")
	var training: Dictionary = Model.propose(profile.cultivation_progress, profile.material_stash, profile.souls, profile.boss_proofs, "train", {"actor_id": NPC, "sessions": 1, "target_tick": 8}, "npc_train_v1")
	before = _raw(profile.save_path)
	_check(not profile.commit_cultivation(training) and _raw(profile.save_path) == before and profile.material_stash[&"crystal"] == 20 and profile.cultivation_progress["actors"][NPC]["energy"] == 0, "Direct NPC advancement with an empty fence cannot consume or reward")
	var foreign_fence: Dictionary = life["adapter"].capture("pilot_pilgrim", false)
	var foreign_guard: Callable = Callable(life["adapter"], "matches").bind(foreign_fence)
	_check(not profile.commit_cultivation(training, foreign_fence, foreign_guard) and _raw(profile.save_path) == before, "A different stable NPC cannot authorize gatherer cultivation")
	_check(profile.commit_cultivation(training, life["fence"], life["guard"]) and profile.material_stash[&"crystal"] == 19 and profile.cultivation_progress["actors"][NPC]["energy"] == 8, "Matching live and durable life fence commits one NPC session with its resource")
	var earned: Dictionary = profile.cultivation_progress.duplicate(true)
	_check(profile.try_add_souls(1) and profile.cultivation_progress == earned, "Common saves with unchanged NPC progress require no fresh cultivation fence")
	_fixture_death(life["state"], false)
	var disable: Dictionary = Model.propose(profile.cultivation_progress, profile.material_stash, profile.souls, profile.boss_proofs, "enroll", {"enabled": false}, "npc_disable_v1")
	_check(profile.commit_cultivation(disable) and not profile.cultivation_progress["actors"][NPC]["enrolled"] and profile.cultivation_progress["actors"][NPC]["sessions_left"] == 0 and profile.material_stash[&"crystal"] == 19, "Disabling sponsorship after withdrawal stops training without granting progress")

func _npc_guards() -> void:
	var profile: SanctuaryProfile = _fixture("npc_live_guard")
	var life: Dictionary = _npc_fixture(profile)
	var before: PackedByteArray = _raw(profile.save_path)
	var missing_guard: Dictionary = _social(profile, life["fence"])
	_check(not missing_guard.get("ok", true) and missing_guard.get("error") == "npc_live_guard_required" and _raw(profile.save_path) == before and not profile.read_only, "NPC transaction requires a live guard rather than trusting disk alone")
	var npc_before: PackedByteArray = _raw(life["state"].save_path)
	profile._writer.before_commit = func() -> void: _fixture_death(life["state"], false)
	var late_death: Dictionary = _social(profile, life["fence"], life["guard"])
	_check(not late_death.get("ok", true) and late_death.get("status") == "rejected" and late_death.get("error") == "live_or_profile_changed" and _raw(profile.save_path) == before and _raw(life["state"].save_path) == npc_before, "Late unsaved withdrawal aborts cost and reward before profile publication")
	var cold: SanctuaryProfile = _reader(profile.save_path)
	_check(cold.material_stash[&"linen_fiber"] == 8 and cold.extension_state("social").is_empty(), "Cold profile cannot grant an event definitively aborted by withdrawal")
	for point: String in ["after_decision", "after_old_rename"]:
		var pending: SanctuaryProfile = _fixture("npc_pending_death_" + point)
		var pending_life: Dictionary = _npc_fixture(pending)
		pending._writer.fault_plan = {point: true}
		_check(not _social(pending, pending_life["fence"], pending_life["guard"]).get("ok", true), "NPC pending fixture retains a proven interrupted decision")
		_fixture_death(pending_life["state"], true)
		var aborted: SanctuaryProfile = _reader(pending.save_path)
		_check(aborted.last_commit.get("status") == "recovered_aborted" and aborted.material_stash[&"linen_fiber"] == 8 and aborted.extension_state("social").is_empty(), point + ": persisted withdrawal blocks pending recovery and preserves old resources")
		_check(pending_life["state"].records[NPC]["mode"] == "recovering" and not FileAccess.file_exists(pending.save_path + ".decision"), "Profile recovery never heals the withdrawn NPC or leaves abort intent")
	for fault: String in ["future", "corrupt"]:
		var blocked: SanctuaryProfile = _fixture("npc_pending_" + fault)
		var blocked_life: Dictionary = _npc_fixture(blocked)
		blocked._writer.fault_plan = {"after_old_rename": true}
		_check(not _social(blocked, blocked_life["fence"], blocked_life["guard"]).get("ok", true), fault + ": pending profile fixture reaches the missing-main window")
		var state: NpcWorldState = blocked_life["state"]
		var npc_good: PackedByteArray = _raw(state.save_path)
		var backup_ok: bool = DirAccess.copy_absolute(state.save_path, state.save_path + ".bak") == OK
		var future: Dictionary = state.snapshot()
		future["npc_schema"] = NpcWorldState.SCHEMA + 1
		_check(backup_ok and _write_fault(state.save_path, JSON.stringify(future) if fault == "future" else "{broken"), fault + ": NPC authority fault preserves a valid historical backup")
		var quarantined: SanctuaryProfile = _reader(blocked.save_path, false)
		_check(quarantined.last_commit.get("error") == "life_authority_unavailable" and FileAccess.file_exists(blocked.save_path + ".previous") and FileAccess.file_exists(blocked.save_path + ".decision") and _raw(state.save_path + ".bak") == npc_good, fault + ": unavailable life authority quarantines recovery without resurrecting from backup")
	var committed: SanctuaryProfile = _fixture("npc_committed_death")
	var committed_life: Dictionary = _npc_fixture(committed)
	committed._writer.fault_plan = {"after_commit": true}
	_check(not _social(committed, committed_life["fence"], committed_life["guard"]).get("ok", true), "Committed NPC fixture interrupts before RAM publication")
	_fixture_death(committed_life["state"], true)
	var history: SanctuaryProfile = _reader(committed.save_path)
	_check(history.material_stash[&"linen_fiber"] == 6 and history.extension_revision("social") == 1 and committed_life["adapter"].capture(NPC).is_empty(), "Withdrawal after commit retains earned history while denying any new advancement")
	_social_once(history, "Committed history after withdrawal")
	if OS.get_name() == "Windows":
		var aliases: SanctuaryProfile = _fixture("npc_case_alias")
		var alias_life: Dictionary = _npc_fixture(aliases)
		aliases.save_path = "user://" + aliases.save_path.trim_prefix("user://").to_upper()
		_check(_social(aliases, alias_life["fence"], alias_life["guard"]).get("ok", false) and aliases.material_stash[&"linen_fiber"] == 6, "Canonical Windows NPC identity remains valid when the profile caller uses a case alias")

func _stale_writer() -> void:
	var owner: SanctuaryProfile = _fixture("stale_owner")
	var peer: SanctuaryProfile = _reader(owner.save_path)
	_check(owner.try_add_souls(1), "Current owner publishes an intervening profile update")
	var authoritative: PackedByteArray = _raw(owner.save_path)
	var rejected: Dictionary = _social(peer)
	_check(not rejected.get("ok", true) and rejected.get("error") == "profile_changed_reload_required" and peer.read_only and _raw(owner.save_path) == authoritative, "Stale writer cannot overwrite a newer owner or consume resources")
	var cold: SanctuaryProfile = _reader(owner.save_path)
	_check(cold.souls == 201 and cold.material_stash[&"linen_fiber"] == 8 and cold.extension_state("social").is_empty(), "Cold authority retains the intervening reward and no stale social effect")

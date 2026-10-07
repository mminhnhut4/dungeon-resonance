extends SceneTree
## Pure proposals only: no scenes, profile files, life owner or real save access.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_validation()
	_test_player_loop()
	_test_replay()
	_test_lineages()
	_test_aptitude_config()
	_test_npc_sponsorship()
	_test_bounds()
	print("RESULT OpeningCultivationState checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)
	else:
		print("PASS: " + label)

func _fixture(seed_value: int = 4) -> Dictionary:
	return {"progress": Model.new_progress(seed_value), "materials": {"crystal": 20, "dust": 10, "aptitude_herb": 0, "aptitude_pill": 0}, "souls": 25, "proofs": {"golem": 1}}

func _canonical(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)

func _commit(fixture: Dictionary, kind: String, args: Dictionary, event_id: String = "") -> Dictionary:
	var before: String = _canonical(fixture)
	var id: String = event_id if not event_id.is_empty() else "event_%d" % fixture["progress"]["next_event"]
	var result: Dictionary = Model.propose(fixture["progress"], fixture["materials"], fixture["souls"], fixture["proofs"], kind, args, id)
	_check(result.get("ok", false), "%s proposal accepted" % kind)
	_check(_canonical(fixture) == before, "%s proposal never mutates caller-owned state or bank" % kind)
	if result.get("ok", false):
		fixture["progress"] = result["progress"]
		fixture["materials"] = result["materials"]
		fixture["souls"] = result["souls"]
	return result

func _reject(fixture: Dictionary, kind: String, args: Dictionary, error: String, event_id: String = "rejected_event") -> void:
	var before: String = _canonical(fixture)
	var result: Dictionary = Model.propose(fixture["progress"], fixture["materials"], fixture["souls"], fixture["proofs"], kind, args, event_id)
	_check(not result.get("ok", false) and result.get("error") == error, "%s rejects with %s" % [kind, error])
	_check(_canonical(fixture) == before, "%s rejection preserves both progress and resource bank" % kind)

func _test_validation() -> void:
	var fixture: Dictionary = _fixture()
	_check(Model.valid(fixture["progress"], fixture["materials"]), "Fresh track accepts the real-shaped aggregate material bank")
	_check(fixture["progress"]["actors"]["player"]["stage"] == 0 and fixture["progress"]["config"]["tuning_status"] == "proposal_not_final", "Fresh player begins Luyện Khí with explicitly preliminary tuning")
	for seed_value: Variant in [-1, Model.LIMIT + 1, 1.5, true]:
		_check(Model.new_progress(seed_value).get("error") == "invalid_seed", "Invalid seed %s is rejected without coercion" % str(seed_value))
	var altered: Dictionary = fixture["progress"].duplicate(true)
	altered["schema_version"] = 2
	_check(not Model.valid(altered, fixture["materials"]), "Future progress schema fails closed")
	altered = fixture["progress"].duplicate(true)
	altered["config"]["schema_version"] = 2
	_check(not Model.valid(altered, fixture["materials"]), "Future tuning schema fails closed")
	altered = fixture["progress"].duplicate(true)
	altered["actors"]["player"]["hp"] = 40
	_check(not Model.valid(altered, fixture["materials"]), "Actor progress cannot become another HP authority")
	altered = fixture["progress"].duplicate(true)
	altered["actors"]["player"]["resources"] = {"crystal": 20}
	_check(not Model.valid(altered, fixture["materials"]), "Actor progress cannot carry another resource ledger")
	altered = fixture["progress"].duplicate(true)
	altered["next_event"] += 1
	_check(not Model.valid(altered, fixture["materials"]), "Event cursor cannot skip durable revision history")
	altered = fixture["progress"].duplicate(true)
	altered["config"]["energy_thresholds"] = [12, 12, 40]
	_check(not Model.valid(altered, fixture["materials"]), "Cumulative energy gates must increase")
	altered = fixture["progress"].duplicate(true)
	altered["config"]["training_session_ticks"] = 1
	_check(not Model.valid(altered, fixture["materials"]), "Persisted clock units cannot shorten the approved eight-pulse interval")
	var parser := JSON.new()
	_check(parser.parse(_canonical(fixture)) == OK and Model.valid(parser.data["progress"], parser.data["materials"]), "JSON float round-trip preserves valid progress and material stock")
	_reject(fixture, "train", {"actor_id": "player", "sessions": 1, "target_tick": 8, "callback": Callable(self, "_run")}, "invalid_command_arguments")
	_reject(fixture, "observe", {"insight_id": "invented_canon"}, "invalid_command_arguments")
	_reject(fixture, "mastery", {"actor_id": "pilot_gatherer"}, "invalid_command_arguments")

func _test_player_loop() -> void:
	var fixture: Dictionary = _fixture()
	_reject(fixture, "breakthrough", {"actor_id": "player"}, "energy_required")
	_reject(fixture, "train", {"actor_id": "player", "sessions": 1, "target_tick": 7}, "insufficient_gameplay_ticks")
	fixture["materials"]["crystal"] = 0
	_reject(fixture, "train", {"actor_id": "player", "sessions": 1, "target_tick": 8}, "training_resource_required")
	fixture["materials"]["crystal"] = 20
	_commit(fixture, "train", {"actor_id": "player", "sessions": 2, "target_tick": 16})
	_check(fixture["progress"]["actors"]["player"]["energy"] == 16 and fixture["materials"]["crystal"] == 18, "Two eligible sessions accrue energy and debit exactly two shared-bank crystals")
	_reject(fixture, "breakthrough", {"actor_id": "player"}, "mastery_required")
	_commit(fixture, "mastery", {})
	_commit(fixture, "mastery", {})
	_reject(fixture, "breakthrough", {"actor_id": "player"}, "insight_required")
	_commit(fixture, "observe", {"insight_id": "explored"})
	_reject(fixture, "observe", {"insight_id": "explored"}, "insight_already_observed")
	fixture["materials"]["dust"] = 0
	_reject(fixture, "breakthrough", {"actor_id": "player"}, "breakthrough_resource_required")
	fixture["materials"]["dust"] = 10
	_commit(fixture, "breakthrough", {"actor_id": "player"})
	_check(fixture["progress"]["actors"]["player"]["stage"] == 1 and fixture["progress"]["actors"]["player"]["energy"] == 16 and fixture["materials"]["dust"] == 9, "First explicit breakthrough consumes one dust and retains cumulative earned energy")
	_commit(fixture, "train", {"actor_id": "player", "sessions": 1, "target_tick": 24})
	for _index: int in 3: _commit(fixture, "mastery", {})
	_commit(fixture, "observe", {"insight_id": "thanh_vy_met"})
	_commit(fixture, "breakthrough", {"actor_id": "player"})
	_commit(fixture, "train", {"actor_id": "player", "sessions": 2, "target_tick": 40})
	for _index: int in 3: _commit(fixture, "mastery", {})
	_commit(fixture, "observe", {"insight_id": "golem_defeated"})
	_check(fixture["progress"]["actors"]["player"]["stage"] == 2, "Meeting all final thresholds never causes an automatic player breakthrough")
	fixture["proofs"]["golem"] = 0
	_reject(fixture, "breakthrough", {"actor_id": "player"}, "golem_proof_required")
	fixture["proofs"]["golem"] = 1
	fixture["souls"] = 4
	_reject(fixture, "breakthrough", {"actor_id": "player"}, "souls_required")
	fixture["souls"] = 25
	_commit(fixture, "breakthrough", {"actor_id": "player"}, "final_player_breakthrough")
	_check(fixture["progress"]["actors"]["player"]["stage"] == 3 and fixture["materials"]["crystal"] == 15 and fixture["materials"]["dust"] == 6 and fixture["souls"] == 20 and fixture["proofs"]["golem"] == 1, "Whole opening loop consumes five crystals, four dust and five Souls while retaining the Golem proof")
	_reject(fixture, "breakthrough", {"actor_id": "player"}, "stage_complete")
	_reject(fixture, "train", {"actor_id": "player", "sessions": 1, "target_tick": 48}, "stage_complete")

func _test_replay() -> void:
	var fixture: Dictionary = _fixture()
	var args: Dictionary = {"actor_id": "player", "sessions": 1, "target_tick": 8}
	_commit(fixture, "train", args, "once_only")
	fixture["materials"]["crystal"] += 7 # A separate authoritative bank transaction.
	var before: String = _canonical(fixture)
	var replay: Dictionary = Model.propose(fixture["progress"], fixture["materials"], fixture["souls"], fixture["proofs"], "train", {"target_tick": 8.0, "sessions": 1.0, "actor_id": "player"}, "once_only")
	_check(replay.get("already_committed", false) and replay["materials"]["crystal"] == 26 and replay["progress"]["revision"] == 1 and _canonical(fixture) == before, "Replay normalizes argument order/JSON numbers and returns the current bank without another cost")
	if replay.get("ok", false):
		replay["progress"]["actors"]["player"]["energy"] = 999
		replay["materials"]["crystal"] = 0
		_check(fixture["progress"]["actors"]["player"]["energy"] == 8 and fixture["materials"]["crystal"] == 26, "Returned replay state and materials share no mutable containers with the caller")
	_reject(fixture, "train", {"actor_id": "player", "sessions": 2, "target_tick": 24}, "event_conflict", "once_only")
	_reject(fixture, "mastery", {}, "event_conflict", "once_only")
	var parser := JSON.new()
	_check(parser.parse(_canonical(fixture)) == OK, "Receipt-bearing fixture round-trips through JSON")
	if parser.data is Dictionary:
		var loaded: Dictionary = parser.data
		var again: Dictionary = Model.propose(loaded["progress"], loaded["materials"], loaded["souls"], loaded["proofs"], "train", args, "once_only")
		_check(again.get("already_committed", false) and again["materials"]["crystal"] == 26, "Cold JSON replay preserves exactly-once debit")

func _test_lineages() -> void:
	var fixture: Dictionary = _fixture(4)
	_check(Model.node_available(fixture["progress"], "h00_courtyard_01"), "Stable seed four has the authored courtyard herb")
	_commit(fixture, "harvest", {"node_id": "h00_courtyard_01"})
	_check(fixture["materials"]["aptitude_herb"] == 1 and not Model.node_available(fixture["progress"].duplicate(true), "h00_courtyard_01"), "Claim atomically creates one lineage/stock and stays exhausted after reload copy")
	_reject(fixture, "harvest", {"node_id": "h00_courtyard_01"}, "node_unavailable")
	_commit(fixture, "craft_pill", {"origin_id": "h00_courtyard_01"})
	_check(fixture["materials"]["dust"] == 8 and fixture["materials"]["aptitude_herb"] == 0 and fixture["materials"]["aptitude_pill"] == 1 and fixture["progress"]["origins"].size() == 1, "Pill conversion costs two dust and preserves a single herb lineage")
	_reject(fixture, "craft_pill", {"origin_id": "h00_courtyard_01"}, "unconsumed_herb_required")
	_commit(fixture, "enroll", {"enabled": true})
	_commit(fixture, "consume", {"actor_id": "player", "origin_id": "h00_courtyard_01"})
	_check(fixture["materials"]["aptitude_pill"] == 0 and fixture["progress"]["actors"]["player"]["aptitude"] == 8 and fixture["progress"]["origins"]["h00_courtyard_01"]["consumed_lineage"] == "h00_courtyard_01", "Consumption debits the pill once and records its stable lineage consumer")
	_reject(fixture, "consume", {"actor_id": "player", "origin_id": "h00_courtyard_01"}, "origin_already_consumed")
	_reject(fixture, "consume", {"actor_id": "pilot_gatherer", "origin_id": "h00_courtyard_01"}, "origin_already_consumed")
	_commit(fixture, "train", {"actor_id": "player", "sessions": 1, "target_tick": 8})
	_commit(fixture, "train", {"actor_id": "player", "sessions": 1, "target_tick": 16})
	var actor: Dictionary = fixture["progress"]["actors"]["player"]
	_check(actor["energy"] == 17 and actor["remainder"] == 2800 and actor["mastery"] == 0 and actor["insight_ids"].is_empty() and actor["stage"] == 0, "Aptitude speeds fixed-point energy only, without bypassing mastery/insight/breakthrough")
	var wrong_bank: Dictionary = fixture["materials"].duplicate(true)
	wrong_bank["aptitude_pill"] = 1
	_check(not Model.valid(fixture["progress"], wrong_bank), "Consumed origin cannot leave another aggregate pill in the bank")
	var altered: Dictionary = fixture["progress"].duplicate(true)
	altered["actors"]["player"]["aptitude"] += 1
	_check(not Model.valid(altered, fixture["materials"]), "Aptitude gain without a matching consumed lineage is rejected")
	altered = fixture["progress"].duplicate(true)
	altered["origins"]["h00_courtyard_01"]["consumer"] = "pilot_gatherer"
	_check(not Model.valid(altered, fixture["materials"]), "Changing the lineage consumer cannot give two actors its growth")
	altered = fixture["progress"].duplicate(true)
	altered["harvested_nodes"].append("h00_courtyard_01")
	_check(not Model.valid(altered, fixture["materials"]), "Repeated harvested-node metadata is rejected")
	var absent: Dictionary = _fixture(0)
	_check(not Model.node_available(absent["progress"], "h00_courtyard_01") and not Model.node_available(absent["progress"], "o01_p04_01"), "Seed zero has neither fixed herb node")
	_reject(absent, "harvest", {"node_id": "h00_courtyard_01"}, "node_unavailable")
	var roadside: Dictionary = _fixture(2)
	_check(Model.node_available(roadside["progress"], "o01_p04_01"), "Seed two reproducibly has the roadside herb")

func _test_aptitude_config() -> void:
	var fixture: Dictionary = _fixture()
	fixture["progress"]["config"]["herb_occurrence_bps"] = 10000
	fixture["progress"]["config"]["aptitude_gains"]["herb"] = 800
	_check(Model.valid(fixture["progress"], fixture["materials"]) and fixture["progress"]["config"]["aptitude_cap"] == -1, "Persisted proposal can tune gains while leaving gameplay aptitude uncapped")
	for node_id: String in Model.NODE_IDS:
		_commit(fixture, "harvest", {"node_id": node_id})
		_commit(fixture, "consume", {"actor_id": "player", "origin_id": node_id})
	_check(fixture["progress"]["actors"]["player"]["aptitude"] == 1600, "Default uncapped aptitude accepts supported lineage gains above the former invented cap")
	var capped: Dictionary = _fixture()
	capped["progress"]["config"]["herb_occurrence_bps"] = 10000
	capped["progress"]["config"]["aptitude_cap"] = 5
	for node_id: String in Model.NODE_IDS: _commit(capped, "harvest", {"node_id": node_id})
	_commit(capped, "consume", {"actor_id": "player", "origin_id": Model.NODE_IDS[0]})
	_reject(capped, "consume", {"actor_id": "player", "origin_id": Model.NODE_IDS[1]}, "aptitude_capacity_requires_review")
	_check(capped["materials"]["aptitude_herb"] == 1 and capped["progress"]["origins"][Model.NODE_IDS[1]]["consumer"] == "", "An explicit proposal cap cannot consume or strand the refused herb")
	for cap: int in [-2, 0, Model.LIMIT + 1]:
		var altered: Dictionary = _fixture()["progress"]
		altered["config"]["aptitude_cap"] = cap
		_check(not Model.valid(altered, _fixture()["materials"]), "Unsupported proposal cap %d is rejected" % cap)

func _test_npc_sponsorship() -> void:
	var fixture: Dictionary = _fixture()
	_reject(fixture, "enroll", {"enabled": false}, "actor_not_found")
	_commit(fixture, "enroll", {"enabled": true})
	_check(fixture["progress"]["actors"]["pilot_gatherer"]["sessions_left"] == 6 and fixture["materials"]["crystal"] == 20, "Opt-in sponsorship allocates six sessions without inventing a second wallet")
	_reject(fixture, "train", {"actor_id": "pilot_gatherer", "sessions": 7, "target_tick": 56}, "training_session_budget")
	_commit(fixture, "train", {"actor_id": "pilot_gatherer", "sessions": 6, "target_tick": 48})
	var npc: Dictionary = fixture["progress"]["actors"]["pilot_gatherer"]
	_check(npc["energy"] == 48 and npc["mastery"] == 6 and npc["insight_ids"] == ["practice_1", "practice_2", "practice_3"] and npc["sessions_left"] == 0 and fixture["materials"]["crystal"] == 14, "NPC practice deterministically gains mastery/three insights and spends one shared crystal per session")
	_check(npc["stage"] == 0, "NPC training never implicitly commits a breakthrough")
	_reject(fixture, "train", {"actor_id": "pilot_gatherer", "sessions": 1, "target_tick": 56}, "training_session_budget")
	_commit(fixture, "breakthrough", {"actor_id": "pilot_gatherer"})
	_commit(fixture, "breakthrough", {"actor_id": "pilot_gatherer"})
	_reject(fixture, "breakthrough", {"actor_id": "pilot_gatherer"}, "mastery_required")
	_commit(fixture, "enroll", {"enabled": false})
	_reject(fixture, "train", {"actor_id": "pilot_gatherer", "sessions": 1, "target_tick": 56}, "actor_not_enrolled")
	_commit(fixture, "enroll", {"enabled": true})
	_commit(fixture, "train", {"actor_id": "pilot_gatherer", "sessions": 2, "target_tick": 64})
	_commit(fixture, "breakthrough", {"actor_id": "pilot_gatherer"})
	npc = fixture["progress"]["actors"]["pilot_gatherer"]
	_check(npc["stage"] == 3 and npc["mastery"] == 8 and fixture["materials"]["crystal"] == 12 and fixture["materials"]["dust"] == 6 and fixture["souls"] == 20, "Second explicit sponsorship completes one NPC example with the same paid breakthrough gates")
	_check(not npc.has("hp") and not npc.has("death") and not npc.has("mode"), "Pure NPC progress leaves live eligibility and irreversible death to the existing life adapter")

func _test_bounds() -> void:
	var fixture: Dictionary = _fixture()
	_reject(fixture, "train", {"actor_id": "player", "sessions": 9, "target_tick": 72}, "invalid_command_arguments")
	_commit(fixture, "train", {"actor_id": "player", "sessions": 8, "target_tick": Model.LIMIT})
	_check(fixture["progress"]["actors"]["player"]["trained_ticks"] == 64 and fixture["progress"]["actors"]["player"]["energy"] == 64 and fixture["materials"]["crystal"] == 12, "A large monotonic clock value grants only the explicitly verified bounded eight-session batch")
	_reject(fixture, "train", {"actor_id": "player", "sessions": 1, "target_tick": 8}, "insufficient_gameplay_ticks")
	var overflow: Dictionary = _fixture()
	overflow["progress"]["actors"]["player"]["energy"] = Model.LIMIT
	_reject(overflow, "train", {"actor_id": "player", "sessions": 1, "target_tick": 8}, "training_capacity_requires_review")
	var full: Dictionary = _fixture()
	full["progress"]["revision"] = Model.MAX_RECEIPTS
	full["progress"]["next_event"] = Model.MAX_RECEIPTS + 1
	full["progress"]["actors"]["player"]["mastery"] = Model.MAX_RECEIPTS
	for index: int in Model.MAX_RECEIPTS:
		full["progress"]["receipts"].append({"id": "filled_%d" % index, "kind": "mastery", "arguments_sha256": _canonical({}).sha256_text(), "revision": index + 1})
	_check(Model.valid(full["progress"], full["materials"]), "Bounded full receipt history remains readable")
	_reject(full, "mastery", {}, "receipt_capacity_requires_review", "new_after_full")
	var replay: Dictionary = Model.propose(full["progress"], full["materials"], full["souls"], full["proofs"], "mastery", {}, "filled_0")
	_check(replay.get("already_committed", false) and replay["progress"]["receipts"].size() == Model.MAX_RECEIPTS, "Full history still recognizes its earliest receipt without evicting idempotency evidence")

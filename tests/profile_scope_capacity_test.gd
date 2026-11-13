extends SceneTree
## Real content owners must coexist in one sealed save. Run only in a fresh,
## isolated user directory. --baseline stops after the ninth-owner regression;
## --cold-check reads the previous run's manifest in a separate process.
const EXPECTED_CAPACITY: int = 16
const MANIFEST: String = "user://scope_capacity_manifest.json"
const COLD_FIXTURES: Dictionary = {
	"all_owners":{"scopes":9, "npc":true},
	"capacity":{"scopes":16, "npc":true},
	"migration":{"scopes":9, "npc":false},
	"compound_boundary":{"scopes":16, "npc":true},
	"foundation_at_15":{"scopes":16, "npc":false},
	"foundation_at_16":{"scopes":16, "npc":false},
	"compound_full":{"scopes":16, "npc":true}
}
var checks: int = 0
var failures: int = 0
var evidence: Array[Dictionary] = []
var baseline: bool = false
var run_id: String = "fixed"

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _save_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value, "\t", true, true))
		file.close()

func _hash(path: String) -> String:
	return FileAccess.get_file_as_string(path).sha256_text()

func _scopes(profile: SanctuaryProfile) -> Dictionary:
	return profile._retained_fields.get("event_extensions", {}).get("namespaces", {})

func _command(profile: SanctuaryProfile, kind: String, args: Dictionary, branch: String = "") -> bool:
	var state: Dictionary = profile.cultivation_progress
	var proposal: Dictionary = OpeningCultivationState.propose(state, profile.material_stash, profile.souls, profile.boss_proofs, kind, args, "cult_%d" % int(state["next_event"]))
	return profile.commit_cultivation(proposal, {}, Callable(), branch)

func _profile(label: String) -> SanctuaryProfile:
	var profile := SanctuaryProfile.new()
	profile.save_path = "user://scope_capacity/%s/%s/profile.json" % [run_id, label]
	DirAccess.make_dir_recursive_absolute(profile.save_path.get_base_dir())
	check(not FileAccess.file_exists(profile.save_path), "fresh isolated fixture " + label)
	profile.souls = 100
	profile.coins = 123
	profile.material_stash[&"crystal"] = 20
	profile.material_stash[&"dust"] = 20
	profile.material_stash[&"linen_fiber"] = 10
	profile.hub_inventory = GearInventoryCodec.encode(HubPreparation.starter_inventory())
	check(profile.save(), "legacy writer fixture " + label)
	var legacy_hash: String = _hash(profile.save_path)
	var legacy := SanctuaryProfile.new()
	legacy.save_path = profile.save_path
	check(legacy.load_profile() and legacy.profile_version == 1 and _hash(profile.save_path) == legacy_hash, "format1 cold reader does not rewrite " + label)
	check(profile.commit_cultivation(OpeningCultivationState.initial_proposal(OpeningCultivationState.new_progress(0), profile.material_stash, profile.souls, profile.boss_proofs)), "sealed format2 initialization " + label)
	return profile

func _reader(path: String) -> SanctuaryProfile:
	var profile := SanctuaryProfile.new()
	profile.save_path = path
	var social := OpeningSocialRuntime.new()
	social.configure(profile)
	profile.register_extension_validator(TanDangProgress.SCOPE, TanDangProgress.valid)
	profile.register_extension_validator(OpeningExplorationProgress.SCOPE, OpeningExplorationProgress.valid)
	profile.register_extension_validator(DepthProgress.SCOPE, DepthProgress.valid)
	profile.register_extension_validator(MemberDungeonProgress.SCOPE, MemberDungeonProgress.valid)
	profile.register_extension_validator(SectJourneyProgress.SCOPE, SectJourneyProgress.valid)
	profile.register_extension_validator(RuneLearningService.SCOPE, RuneLearningService.valid)
	check(profile.load_profile() and not profile.read_only, "sealed reader accepts " + path)
	return profile

func _remember(profile: SanctuaryProfile, expected: int) -> void:
	var item: Dictionary = {"fixture":profile.save_path.get_base_dir().get_file(), "path":profile.save_path, "sha256":_hash(profile.save_path), "scopes":expected, "ledger":profile.hub_inventory.duplicate(true), "cultivation":profile.cultivation_progress.duplicate(true)}
	var npc_path: String = profile.save_path + NpcWorldState.NPC_SUFFIX
	if FileAccess.file_exists(npc_path):
		item["npc"] = {"sha256":_hash(npc_path), "snapshot":JSON.parse_string(FileAccess.get_file_as_string(npc_path))}
	evidence.append(item)

func _all_real_owners() -> void:
	var profile: SanctuaryProfile = _profile("all_owners")
	var npc := NpcWorldState.new()
	npc.save_path = profile.save_path + NpcWorldState.NPC_SUFFIX
	check(npc.save(), "real NPC sidecar fixture")
	var social := OpeningSocialRuntime.new()
	check(social.configure(profile), "social fence and validator configured")
	check(profile.record_courier_offer(), "courier uses its actual owner")
	check(profile.record_boss_defeat("scope_capacity_golem"), "Golem proof fixture through original owner")
	var depth := DepthProgress.new()
	depth.initialize(profile)
	check(depth.accept(), "depth scope accepted")
	for number: int in range(1, 6):
		check(depth.record(StringName("depth_floor_%d" % number), number), "depth floor " + str(number))
	check(depth.record(&"depth_boss_defeated", 5), "depth boss milestone")
	var member := MemberDungeonProgress.new()
	member.initialize(profile)
	check(member.record(9), "member floor scope through original owner")
	var sect := SectJourneyProgress.new()
	sect.initialize(profile)
	for event: String in ["accept", "west", "east", "guest"]:
		check(sect.record("thanh_van", event), "sect guest quest " + event)
	check(OpeningSocialRuntime.help(profile, npc, "pilot_traveler"), "social help commits original fence and cost")
	var tan := TanDangProgress.new()
	check(tan.initialize(profile, npc) and tan.apply("accept", "", "ledger").get("ok", false), "Tàn Đăng compound quest commits")
	var exploration := OpeningExplorationProgress.new()
	exploration.initialize(profile)
	check(exploration.claim().get("ok", false), "opening cache commits original reward and receipt")
	var economy := EconomySession.new()
	economy.initialize(profile, GearInventoryCodec.decode(profile.hub_inventory))
	economy.persist_safe_inventory = true
	var runes := RuneLearningService.new()
	runes.initialize(economy)
	check(runes.learn(&"fire"), "rune learning through original owner")
	check(_scopes(profile).size() == 8, "eight ordinary feature owners coexist before Trúc Cơ")
	var eight_hash: String = _hash(profile.save_path)
	var eight: SanctuaryProfile = _reader(profile.save_path)
	check(_scopes(eight).size() == 8 and _hash(profile.save_path) == eight_hash, "old eight-scope sealed save cold-loads byte-for-byte")
	for observation: String in OpeningCultivationState.OBSERVATIONS:
		check(_command(profile, "observe", {"insight_id":observation}), "cultivation observation " + observation)
	for number: int in 4:
		check(_command(profile, "mastery", {}), "confirmed-hit mastery fixture " + str(number))
	check(_command(profile, "train", {"actor_id":"player", "sessions":2, "target_tick":16}), "bounded cultivation training fixture")
	for stage: int in 2:
		check(_command(profile, "breakthrough", {"actor_id":"player"}), "cultivation stage " + str(stage + 1))
	var before: String = _hash(profile.save_path)
	var ledger: Dictionary = profile.hub_inventory.duplicate(true)
	var ok: bool = _command(profile, "breakthrough", {"actor_id":"player"}, "cloud_return")
	print("NINTH_OWNER ok=", ok, " scopes=", _scopes(profile).size(), " status=", profile.last_commit.get("status", ""), " error=", profile.last_commit.get("error", ""))
	check(ok, "Trúc Cơ ninth owner must not be rejected as ability_scope_requires_review")
	if not ok:
		check(_hash(profile.save_path) == before and profile.hub_inventory == ledger, "baseline refusal preserves inventory and primary bytes")
		return
	check(_scopes(profile).size() == 9 and profile.cultivation_abilities().get("selected_id") == "cloud_return", "all nine real owners including selected G branch persist")
	check(profile.hub_inventory == ledger, "scope growth keeps inventory UIDs and item properties")
	var cold: SanctuaryProfile = _reader(profile.save_path)
	check(_scopes(cold).size() == 9 and cold.cultivation_abilities() == profile.cultivation_abilities(), "nine-owner cold reader restores Trúc Cơ choice")
	check(cold.material_stash == profile.material_stash, "cold load preserves costs and cache reward")
	check(SanctuaryProfile.CommitWriter.canonical(cold.hub_inventory) == SanctuaryProfile.CommitWriter.canonical(ledger), "cold load preserves UID ledger across JSON numeric types")
	_remember(profile, 9)
	# Replaying completed gameplay owners must not repeat costs or rewards.
	var replay_hash: String = _hash(profile.save_path)
	check(not exploration.claim().get("ok", false) and not runes.learn(&"fire") and not OpeningSocialRuntime.help(profile, npc, "pilot_traveler"), "cache, rune learning and social help remain one-time")
	check(_hash(profile.save_path) == replay_hash, "rejected duplicate claims never rewrite save")
	_capsule(profile, npc, "nine")
	# Exercise the compound writer after the old eight-scope boundary too.
	check(tan.apply("observe_lamp", "", "lamp").get("ok", false), "NPC/profile compound update works with nine scopes")
	_remember(profile, 9)

func _capsule(profile: SanctuaryProfile, npc: NpcWorldState, label: String) -> void:
	var user: String = AmdSlotStore.new_id()
	var store := AmdSlotStore.new()
	var files: Dictionary = {}
	for key: String in ["profile", "npc"]:
		var text: String = FileAccess.get_file_as_string(profile.save_path if key == "profile" else npc.save_path)
		files[key] = {"text":text, "sha256":text.sha256_text()}
	var capsule: Dictionary = {"schemaVersion":1, "profileSchema":2, "gameBuild":"scope-capacity-regression", "files":files}
	var policy := AmdCapsule.new()
	var staged: String = policy.stage(JSON.parse_string(JSON.stringify(capsule, "", true, true)), user, store)
	check(not staged.is_empty(), "existing AMD client accepts " + label + " scopes: " + policy.error)
	if not staged.is_empty(): check(_hash(staged) == files["profile"]["sha256"], "AMD staging preserves exact " + label + " profile")
	var directory: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	if not directory.is_empty(): _save_json(directory.path_join("capsule_" + label + ".json"), capsule)

static func _marker(value: Variant) -> bool:
	return value is Dictionary and value.size() == 1 and value.get("version") == 1

func _capacity_and_migration() -> void:
	var profile: SanctuaryProfile = _profile("capacity")
	for index: int in EXPECTED_CAPACITY:
		var id: String = "capacity_%02d" % index
		check(profile.commit_extension_event(id, "first", {}, 0, {"version":1}, 0).get("ok", false), "bounded namespace " + str(index + 1))
	check(_scopes(profile).size() == EXPECTED_CAPACITY, "explicit finite namespace cap")
	profile._retained_fields["legacy_at_cap"] = {"version":1}
	check(profile.save(), "legacy preimage at capacity")
	var before: String = _hash(profile.save_path)
	var full_migration: Dictionary = profile.migrate_legacy_event_scope("migrate_over_cap", "legacy_at_cap", _marker)
	check(not full_migration.get("ok", false) and full_migration.get("error") == "scope_capacity" and profile._retained_fields.has("legacy_at_cap"), "legacy migration at cap refuses without dropping old facts")
	check(_hash(profile.save_path) == before, "migration capacity refusal preserves bytes")
	check(not profile.commit_extension_event("over_capacity", "first", {}, 0, {"version":1}, 0).get("ok", false), "seventeenth namespace rejected")
	check(_hash(profile.save_path) == before, "capacity refusal leaves primary bytes unchanged")
	check(profile.commit_extension_event("capacity_00", "second", {}, 0, {"version":1}, 1).get("ok", false), "existing owner still advances at cap")
	before = _hash(profile.save_path)
	check(profile.commit_extension_event("capacity_00", "second", {}, 0, {"version":1}, 1).get("status") == "already_committed", "receipt replay stays idempotent at cap")
	check(_hash(profile.save_path) == before, "receipt replay does not write at cap")
	var invalid: Dictionary = profile._retained_fields["event_extensions"].duplicate(true)
	invalid["namespaces"]["over_capacity"] = invalid["namespaces"]["capacity_00"].duplicate(true)
	check(not SanctuaryProfile._valid_extensions(invalid), "reader rejects over-cap envelopes")
	invalid = profile._retained_fields["event_extensions"].duplicate(true)
	invalid["namespaces"]["capacity_00"]["receipts"][0]["arguments_sha256"] = "bad"
	check(not SanctuaryProfile._valid_extensions(invalid), "receipt integrity remains strict")
	var npc := NpcWorldState.new()
	npc.save_path = profile.save_path + NpcWorldState.NPC_SUFFIX
	check(npc.save(), "capacity NPC fixture")
	_remember(profile, EXPECTED_CAPACITY)
	_capsule(profile, npc, "sixteen")
	var legacy: SanctuaryProfile = _profile("migration")
	for index: int in 8:
		check(legacy.commit_extension_event("legacy_peer_%d" % index, "first", {}, 0, {"version":1}, 0).get("ok", false), "migration peer " + str(index))
	legacy._retained_fields["legacy_scope_fixture"] = {"version":1}
	check(legacy.save(), "legacy extension preimage fixture")
	var result: Dictionary = legacy.migrate_legacy_event_scope("migrated_owner", "legacy_scope_fixture", _marker)
	check(result.get("ok", false) and result.get("status") == "migrated", "legacy migration can create ninth namespace")
	check(_scopes(legacy).size() == 9 and not legacy._retained_fields.has("legacy_scope_fixture"), "migration retains facts in one namespace")
	_remember(legacy, 9)
	check(AmdCapsule.MAX_PROFILE_BYTES == SanctuaryProfile.CommitWriter.MAX_BYTES and AmdCapsule.MAX_NPC_BYTES == 32768, "cloud client byte budgets remain aligned with readers")

func _compound_boundary() -> void:
	var profile: SanctuaryProfile = _profile("compound_boundary")
	for index: int in EXPECTED_CAPACITY - 1:
		check(profile.commit_extension_event("compound_peer_%02d" % index, "first", {}, 0, {"version":1}, 0).get("ok", false), "compound boundary peer " + str(index))
	var npc := NpcWorldState.new()
	npc.save_path = profile.save_path + NpcWorldState.NPC_SUFFIX
	check(npc.save(), "compound boundary durable NPC fixture")
	var tan := TanDangProgress.new()
	check(tan.initialize(profile, npc), "compound boundary validator")
	check(tan.apply("accept", "", "ledger").get("ok", false), "compound transaction can create sixteenth scope")
	check(_scopes(profile).size() == EXPECTED_CAPACITY, "compound writer shares exact capacity")
	check(tan.apply("observe_lamp", "", "lamp").get("ok", false), "existing compound owner advances at cap")
	var before: String = _hash(profile.save_path)
	var before_npc: String = _hash(npc.save_path)
	check(not profile.commit_extension_event("compound_over_cap", "first", {}, 0, {"version":1}, 0).get("ok", false), "new scope after compound cap refuses")
	check(_hash(profile.save_path) == before and _hash(npc.save_path) == before_npc, "compound cap refusal preserves both primaries")
	_remember(profile, EXPECTED_CAPACITY)

func _cultivation_boundary() -> void:
	for occupied: int in [EXPECTED_CAPACITY - 1, EXPECTED_CAPACITY]:
		var profile: SanctuaryProfile = _profile("foundation_at_%d" % occupied)
		for index: int in occupied:
			check(profile.commit_extension_event("foundation_peer_%02d" % index, "first", {}, 0, {"version":1}, 0).get("ok", false), "foundation boundary peer %d/%d" % [index + 1, occupied])
		for observation: String in OpeningCultivationState.OBSERVATIONS:
			check(_command(profile, "observe", {"insight_id":observation}), "foundation boundary observation " + observation)
		for index: int in 4:
			check(_command(profile, "mastery", {}), "foundation boundary mastery " + str(index))
		check(_command(profile, "train", {"actor_id":"player", "sessions":2, "target_tick":16}), "foundation boundary readiness")
		for stage: int in 2:
			check(_command(profile, "breakthrough", {"actor_id":"player"}), "foundation boundary earlier stage " + str(stage))
		var before: String = _hash(profile.save_path)
		var before_state: String = SanctuaryProfile.CommitWriter.canonical([profile.cultivation_progress, profile.material_stash, profile.souls, profile.hub_inventory, profile._retained_fields])
		var dust: int = profile.material_stash[&"dust"]
		var ledger: String = SanctuaryProfile.CommitWriter.canonical(profile.hub_inventory)
		var ok: bool = _command(profile, "breakthrough", {"actor_id":"player"}, "tether_sigil")
		if occupied < EXPECTED_CAPACITY:
			check(ok and _scopes(profile).size() == EXPECTED_CAPACITY and profile.cultivation_abilities().get("selected_id") == "tether_sigil", "Trúc Cơ can create sixteenth namespace")
			check(profile.material_stash[&"dust"] == dust - int(profile.cultivation_progress["config"]["final_dust_cost"]) and SanctuaryProfile.CommitWriter.canonical(profile.hub_inventory) == ledger, "successful boundary breakthrough charges exact cost and preserves UIDs")
		else:
			check(not ok and profile.last_commit.get("error") == "ability_scope_requires_review", "Trúc Cơ refuses seventeenth namespace")
			check(_hash(profile.save_path) == before and SanctuaryProfile.CommitWriter.canonical([profile.cultivation_progress, profile.material_stash, profile.souls, profile.hub_inventory, profile._retained_fields]) == before_state, "refused breakthrough keeps costs, cultivation, scopes and bytes unchanged")
		_remember(profile, EXPECTED_CAPACITY)

func _compound_full_refusal() -> void:
	var profile: SanctuaryProfile = _profile("compound_full")
	for index: int in EXPECTED_CAPACITY:
		check(profile.commit_extension_event("full_compound_peer_%02d" % index, "first", {}, 0, {"version":1}, 0).get("ok", false), "full compound peer " + str(index))
	var npc := NpcWorldState.new()
	npc.save_path = profile.save_path + NpcWorldState.NPC_SUFFIX
	check(npc.save(), "full compound durable NPC fixture")
	var tan := TanDangProgress.new()
	check(tan.initialize(profile, npc), "full compound validator")
	var before: String = _hash(profile.save_path)
	var before_npc: String = _hash(npc.save_path)
	var before_state: String = SanctuaryProfile.CommitWriter.canonical([profile._retained_fields, profile.material_stash, profile.souls, profile.hub_inventory, npc.snapshot()])
	var result: Dictionary = tan.apply("accept", "", "ledger")
	check(not result.get("ok", false) and result.get("error") == "stale_sect_proposal_or_capacity", "new compound NPC scope refuses at fully occupied cap")
	check(_hash(profile.save_path) == before and _hash(npc.save_path) == before_npc and SanctuaryProfile.CommitWriter.canonical([profile._retained_fields, profile.material_stash, profile.souls, profile.hub_inventory, npc.snapshot()]) == before_state, "compound capacity refusal preserves both files, life state and all costs")
	check(not npc.compound_locked and not profile.read_only and not FileAccess.file_exists(profile.save_path + ".decision"), "capacity refusal does not create a pending compound decision")
	_remember(profile, EXPECTED_CAPACITY)

func _valid_manifest(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 2 or data.get("version") != 1 or not data.get("profiles") is Array or data["profiles"].size() != COLD_FIXTURES.size(): return false
	var seen: Dictionary = {}
	for item: Variant in data["profiles"]:
		if not item is Dictionary or item.get("fixture") not in COLD_FIXTURES or seen.has(item["fixture"]): return false
		var label: String = item["fixture"]
		var path: Variant = item.get("path")
		if not path is String or not path.begins_with("user://scope_capacity/") or path.contains("..") or not path.ends_with("/" + label + "/profile.json"): return false
		var parts: PackedStringArray = path.trim_prefix("user://scope_capacity/").split("/")
		if parts.size() != 3 or not parts[0].is_valid_identifier(): return false
		if item.get("scopes") != COLD_FIXTURES[label]["scopes"] or not SanctuaryProfile.CommitWriter._hash(item.get("sha256")) or not item.get("ledger") is Dictionary or not item.get("cultivation") is Dictionary: return false
		if COLD_FIXTURES[label]["npc"]:
			if not item.get("npc") is Dictionary or not SanctuaryProfile.CommitWriter._hash(item["npc"].get("sha256")) or not item["npc"].get("snapshot") is Dictionary: return false
		seen[label] = true
	return seen.size() == COLD_FIXTURES.size()

func _cold_check() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	check(_valid_manifest(data), "complete previous-process manifest has seven distinct expected fixtures and paired NPC evidence")
	if not _valid_manifest(data): return
	for item: Dictionary in data["profiles"]:
		var path: String = item["path"]
		var profile: SanctuaryProfile = _reader(path)
		check(_scopes(profile).size() == int(item["scopes"]), "new process preserves namespace count")
		check(SanctuaryProfile.CommitWriter.canonical(profile.hub_inventory) == SanctuaryProfile.CommitWriter.canonical(item["ledger"]) and SanctuaryProfile.CommitWriter.canonical(profile.cultivation_progress) == SanctuaryProfile.CommitWriter.canonical(item["cultivation"]), "new process preserves UID ledger and cultivation")
		check(_hash(path) == item["sha256"], "cold read never rewrites primary")
		if COLD_FIXTURES[item["fixture"]]["npc"]:
			var npc := NpcWorldState.new()
			npc.save_path = path + NpcWorldState.NPC_SUFFIX
			check(npc.load_state() and not npc.read_only and not npc.compound_locked, "new process accepts paired NPC life authority")
			check(SanctuaryProfile.CommitWriter.canonical(npc.snapshot()) == SanctuaryProfile.CommitWriter.canonical(item["npc"]["snapshot"]), "new process preserves paired NPC life state")
			check(_hash(npc.save_path) == item["npc"]["sha256"], "cold read never rewrites paired NPC primary")

func _run() -> void:
	var cold: bool = "--cold-check" in OS.get_cmdline_user_args()
	baseline = "--baseline" in OS.get_cmdline_user_args()
	if baseline: run_id = "baseline"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--run=") and arg.trim_prefix("--run=").is_valid_identifier(): run_id = arg.trim_prefix("--run=")
	check(AmdSlotStore.isolated() and OS.get_user_data_dir().contains("Dungeon Resonance Scope QA"), "isolated QA user directory before any file writes")
	if failures == 0:
		if cold: _cold_check()
		else:
			_all_real_owners()
			if not baseline:
				_capacity_and_migration()
				_compound_boundary()
				_cultivation_boundary()
				_compound_full_refusal()
				# The same profile can be observed before and after a compound update.
				# Persist only its latest expected preimage in the cold manifest.
				var latest: Dictionary = {}
				for item: Dictionary in evidence: latest[item["path"]] = item
				var manifest: Dictionary = {"version":1, "profiles":latest.values()}
				check(_valid_manifest(manifest), "generated manifest covers every expected cold fixture")
				check(not _valid_manifest({"version":1, "profiles":[]}), "empty manifest cannot yield a false cold pass")
				var duplicate: Dictionary = manifest.duplicate(true)
				duplicate["profiles"][1] = duplicate["profiles"][0].duplicate(true)
				check(not _valid_manifest(duplicate), "duplicate cold fixtures cannot replace missing coverage")
				_save_json(MANIFEST, manifest)
	var result: Dictionary = {"checks":checks, "failures":failures, "baseline":baseline, "cold":cold, "userDir":OS.get_user_data_dir()}
	print("RESULT PROFILE_SCOPE_CAPACITY ", JSON.stringify(result))
	var directory: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	if not directory.is_empty(): _save_json(directory.path_join("cold-result.json" if cold else "result.json"), result)
	quit(0 if failures == 0 else 1)

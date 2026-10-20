extends SceneTree
## Social/courier carried costs share the actual sealed profile writer and life fence.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
const ID: String = "pilot_traveler"
var checks: int = 0
var failures: int = 0
var directory: String

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func _run() -> void:
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\", "/").begins_with(allowed + "/"):
		print("FAIL: bag_social_cost requires isolated QA user data")
		quit(2); return
	directory = "user://verification/bag_social_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_sources_and_replay()
	_test_courier_prepare_and_legacy()
	_test_extension_contracts()
	_test_owner_locks_and_reentry()
	_test_faults()
	_test_pending()
	_test_life_fence()
	print("RESULT bag_social_cost checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _fixture(label: String, supply_bag: bool = false) -> Dictionary:
	var bank := SanctuaryProfile.new()
	bank.save_path = directory + "/" + label + "/profile.json"
	bank.souls = 30; bank.coins = 41
	bank.material_stash[&"dust"] = 10
	bank.material_stash[&"linen_fiber"] = 8
	_check(bank.save() and bank.commit_cultivation(Model.initial_proposal(Model.new_progress(43), bank.material_stash, bank.souls, bank.boss_proofs)), label + ": actual owner creates sealed profile v2")
	var runtime := OpeningSocialRuntime.new()
	_check(runtime.configure(bank), label + ": trusted validators and durable life reader register")
	var life := NpcWorldState.new()
	life.save_path = bank.save_path + ".npc_v1.json"
	_check(life.save(), label + ": real NPC life sidecar is durable")
	var bag: GearInventory = HubPreparation.starter_inventory()
	var spare: GearItem = bag.add_equipment(GearInventory.COMMON_SWORD, GearItem.Quality.RARE)
	spare.drop_bonus = 0.013505235314369202
	spare.source = &"drop"; spare.loot_rolled = true
	bag.equipment_grid_uids()
	if supply_bag:
		bag.materials[&"dust"] = 2
		bag.materials[&"linen_fiber"] = 4
	bank.hub_inventory = GearInventoryCodec.encode(bag)
	_check(bank.save() and bank.record_courier_offer() and bank.record_courier_contact("shrine"), label + ": bag and real courier prerequisites commit")
	var economy := EconomySession.new()
	economy.initialize(bank, bag)
	economy.persist_safe_inventory = true
	return {"bank": bank, "bag": bag, "life": life, "runtime": runtime, "economy": economy}

func _snapshot(f: Dictionary) -> Dictionary:
	var bank: SanctuaryProfile = f["bank"]
	return {"bag": GearInventoryCodec.encode(f["bag"]), "ledger": bank.hub_inventory.duplicate(true), "stash": bank.material_stash.duplicate(),
		"souls": bank.souls, "coins": bank.coins, "extensions": bank._retained_fields.duplicate(true), "cultivation": bank.cultivation_progress.duplicate(true)}

func _cold(path: String) -> Dictionary:
	var bank := SanctuaryProfile.new()
	bank.save_path = path
	var runtime := OpeningSocialRuntime.new()
	_check(runtime.configure(bank), "Cold owner registers actual durable reader before recovery")
	_check(bank.load_profile() and not bank.read_only, "Cold owner resolves sealed profile")
	var bag: GearInventory = GearInventoryCodec.decode(bank.hub_inventory)
	_check(bag != null, "Cold carried inventory decodes finite owned UIDs")
	return {"bank": bank, "bag": bag, "runtime": runtime}

func _raw_help(f: Dictionary, state_override: Dictionary = {}) -> Dictionary:
	var bank: SanctuaryProfile = f["bank"]
	var life: NpcWorldState = f["life"]
	var raw: Dictionary = life.social_fence(ID)
	var fence: Dictionary = raw.duplicate(true); fence["kind"] = "npc_social"
	var state: Dictionary = OpeningSocialRuntime.state(bank)
	if not NpcSocialProgress.helped(state, ID): state = NpcSocialProgress.with_help(state, ID, NpcWorldState.life_id(ID))
	if not state_override.is_empty(): state = state_override
	return bank.commit_extension_event("npc_social", NpcSocialProgress.event_id(ID, NpcWorldState.life_id(ID)),
		{&"linen_fiber": 2}, 0, state, bank.extension_revision("npc_social"), fence, life.social_fence_matches.bind(raw), f["bag"])

func _action(f: Dictionary, kind: String) -> bool:
	return f["economy"].help_resident(f["life"], ID) if kind == "social" else f["economy"].commit_courier_choice(&"help")

func _test_sources_and_replay() -> void:
	var f: Dictionary = _fixture("sources")
	var bank: SanctuaryProfile = f["bank"]
	var bag: GearInventory = f["bag"]
	var before: Dictionary = _snapshot(f)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	_check(not OpeningSocialRuntime.can_help(bank, f["life"], ID, bag) and not OpeningSocialRuntime.help(bank, f["life"], ID, bag), "Stored linen alone cannot fund carried social help")
	_check(not bank.quote_courier_choice(&"help", bag)["available"] and not bank.commit_courier_choice(&"help", bag) and not bank.quote_courier_choice(&"prepare", bag)["available"] and not bank.commit_courier_choice(&"prepare", bag), "Stored dust alone cannot satisfy either carried courier choice")
	_check(_snapshot(f) == before and FileAccess.get_file_as_bytes(bank.save_path) == bytes, "Unavailable carried requests leave both ledgers and bytes untouched")
	bag.materials[&"linen_fiber"] = 2
	bag.materials[&"dust"] = 1
	bank.hub_inventory = GearInventoryCodec.encode(bag)
	_check(bank.save(), "Carried-only ingredients become durable")
	var original_items: Array = GearInventoryCodec.encode(bag)["items"].duplicate(true)
	var npc_bytes: PackedByteArray = FileAccess.get_file_as_bytes(f["life"].save_path)
	_check(OpeningSocialRuntime.help(bank, f["life"], ID, bag) and bag.materials[&"linen_fiber"] == 0 and bank.material_stash == before["stash"], "Social help consumes exactly two carried linen and preserves storage")
	_check(NpcSocialProgress.helped(OpeningSocialRuntime.state(bank), ID) and bank.extension_revision("npc_social") == 1, "Social cost commits with one canonical life receipt")
	bytes = FileAccess.get_file_as_bytes(bank.save_path)
	_check(not OpeningSocialRuntime.help(bank, f["life"], ID, bag) and _raw_help(f).get("status") == "already_committed" and FileAccess.get_file_as_bytes(bank.save_path) == bytes, "Social wrapper refuses repeat; low-level identical receipt replays without cost/write")
	_check(_raw_help(f, NpcSocialProgress.empty()).get("error") == "event_conflict" and FileAccess.get_file_as_bytes(bank.save_path) == bytes, "Conflicting social receipt cannot replace committed help")
	_check(bank.quote_courier_choice(&"help", bag)["consequence"].contains("trong túi") and bank.commit_courier_choice(&"help", bag) and bag.materials[&"dust"] == 0, "Courier help explains and consumes exactly one carried dust")
	bytes = FileAccess.get_file_as_bytes(bank.save_path)
	_check(bank.commit_courier_choice(&"help", bag) and not bank.commit_courier_choice(&"prepare", bag) and FileAccess.get_file_as_bytes(bank.save_path) == bytes, "Courier same choice replays even after bag empties; opposite choice conflicts")
	_check(bank.material_stash == before["stash"] and bank.coins == before["coins"] and bank.souls == before["souls"] and GearInventoryCodec.encode(bag)["items"] == original_items and FileAccess.get_file_as_bytes(f["life"].save_path) == npc_bytes, "Social/courier leave bank, currencies, exact gear UIDs/stats and NPC life bytes intact")
	var cold: Dictionary = _cold(bank.save_path)
	_check(Writer.canonical(GearInventoryCodec.encode(cold["bag"])) == Writer.canonical(GearInventoryCodec.encode(bag)) and cold["bank"].material_stash == before["stash"] and cold["bank"].courier_objectives()["outcome"] == "help" and NpcSocialProgress.helped(OpeningSocialRuntime.state(cold["bank"]), ID), "Cold load retains both receipts and their matching carried debits")

func _test_courier_prepare_and_legacy() -> void:
	var f: Dictionary = _fixture("prepare", true)
	var bank: SanctuaryProfile = f["bank"]
	var bag: GearInventory = f["bag"]
	var before: Dictionary = _snapshot(f)
	_check(bank.quote_courier_choice(&"prepare", bag)["consequence"].contains("trong túi") and bank.commit_courier_choice(&"prepare", bag), "Courier prepare accepts carried dust presence")
	_check(bag.materials[&"dust"] == 2 and bank.material_stash == before["stash"] and bank.souls == before["souls"] and bank.courier_objectives()["outcome"] == "prepare", "Prepare records choice but consumes no dust or other currency")
	var legacy: Dictionary = _fixture("legacy")
	_check(OpeningSocialRuntime.help(legacy["bank"], legacy["life"], ID) and legacy["bank"].material_stash[&"linen_fiber"] == 6 and legacy["bag"].materials[&"linen_fiber"] == 0, "Omitted carried parameter preserves legacy social API")
	_check(legacy["bank"].commit_courier_choice(&"help") and legacy["bank"].material_stash[&"dust"] == 9 and legacy["bag"].materials[&"dust"] == 0, "Omitted carried parameter preserves legacy courier API")

func _test_extension_contracts() -> void:
	var f: Dictionary = _fixture("extension", true)
	var bank: SanctuaryProfile = f["bank"]
	var bag: GearInventory = f["bag"]
	for gate: String in ["read_only", "hub_inventory_quarantined"]:
		bank.set(gate, true)
		var before: Dictionary = _snapshot(f)
		_check(not OpeningSocialRuntime.can_help(bank, f["life"], ID, bag) and not _action(f, "social") and not bank.quote_courier_choice(&"help", bag)["available"] and not _action(f, "courier") and _snapshot(f) == before, "Both carried services respect profile lock: " + gate)
		bank.set(gate, false)
	var before: Dictionary = _snapshot(f)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	var denied: Dictionary = bank.commit_extension_event("bag_test", "lineage_v1", {&"aptitude_herb": 1}, 0, {"count": 1}, 0, {}, Callable(), bag)
	_check(not denied.get("ok", false) and denied.get("error") == "lineage_cost_requires_owner" and _snapshot(f) == before and FileAccess.get_file_as_bytes(bank.save_path) == bytes, "Generic carried extension cannot charge lineage-bound materials")
	var result: Dictionary = bank.commit_extension_event("bag_test", "ordinary_v1", {&"dust": 1}, 1, {"count": 1}, 0, {}, Callable(), bag)
	_check(result.get("status") == "committed" and bag.materials[&"dust"] == 1 and bank.souls == 29 and bank.material_stash == before["stash"], "Generic extension atomically commits carried material, Soul cost and state")
	bytes = FileAccess.get_file_as_bytes(bank.save_path)
	_check(bank.commit_extension_event("bag_test", "ordinary_v1", {&"dust": 1}, 1, {"count": 1}, 0, {}, Callable(), bag).get("status") == "already_committed" and FileAccess.get_file_as_bytes(bank.save_path) == bytes, "Identical generic receipt replays independently of original source counts")
	_check(bank.commit_extension_event("bag_test", "ordinary_v1", {&"dust": 1}, 1, {"count": 2}, 1, {}, Callable(), bag).get("error") == "event_conflict" and bank.commit_extension_event("bag_test", "ordinary_v2", {}, 0, {"count": 2}, 0, {}, Callable(), bag).get("error") == "revision_or_capacity", "Generic carried extension retains receipt conflict and stale revision guards")

func _test_owner_locks_and_reentry() -> void:
	for kind: String in ["social", "courier"]:
		var f: Dictionary = _fixture("owner_" + kind, true)
		var bank: SanctuaryProfile = f["bank"]
		var economy: EconomySession = f["economy"]
		for gate: String in ["_busy", "hub_access", "persist_safe_inventory"]:
			economy.set(gate, gate == "_busy")
			var before: Dictionary = _snapshot(f)
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
			_check(not economy.quote_social_help(f["life"], ID)["can_help"] and not economy.quote_courier_choice(&"help")["available"] and not _action(f, kind) and _snapshot(f) == before and FileAccess.get_file_as_bytes(bank.save_path) == bytes, kind + ": economy owner blocks quote/action under " + gate)
			economy.set(gate, gate != "_busy")
		var persistence := SafeInventoryPersistence.new()
		root.add_child(persistence)
		persistence.initialize(economy)
		var revision: int = int(JSON.parse_string(FileAccess.get_file_as_string(bank.save_path))["profile_commit"]["revision"])
		var publications: Array[int] = [0, 0]
		var callback: Callable = func() -> void:
			publications[0] += 1
			if _action(f, "courier" if kind == "social" else "social"): publications[1] += 1
		bank.changed.connect(callback)
		economy.inventory.changed.connect(callback)
		economy.changed.connect(callback)
		_check(_action(f, kind) and publications[0] > 0 and publications[1] == 0 and not economy._busy, kind + ": commit callbacks cannot enter a second funded service")
		bank.changed.disconnect(callback)
		economy.inventory.changed.disconnect(callback)
		economy.changed.disconnect(callback)
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(bank.save_path))
		_check(int(saved["profile_commit"]["revision"]) == revision + 1 and persistence.committed == bank.hub_inventory, kind + ": real SafeInventoryPersistence observes one committed save without duplicate revision")
		_check((bank.courier_objectives()["outcome"] == "" and f["bag"].materials[&"dust"] == 2) if kind == "social" else (not NpcSocialProgress.helped(OpeningSocialRuntime.state(bank), ID) and f["bag"].materials[&"linen_fiber"] == 4), kind + ": blocked reentry leaves secondary receipt and material untouched")
		persistence.free()

func _test_faults() -> void:
	for kind: String in ["social", "courier"]:
		for point: String in ["write_candidate", "write_decision", "rename_decision", "rename_old", "commit"]:
			var f: Dictionary = _fixture(kind + "_" + point, true)
			var bank: SanctuaryProfile = f["bank"]
			var before: Dictionary = _snapshot(f)
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
			bank._writer.fault_plan = {point: true}
			_check(not _action(f, kind) and not bank.read_only and not f["economy"]._busy and bank._writer.fault_plan.is_empty(), kind + "/" + point + ": actual writer failure aborts and unlocks economy owner")
			_check(_snapshot(f) == before and FileAccess.get_file_as_bytes(bank.save_path) == bytes, kind + "/" + point + ": rollback restores costs, exact UID ledger, positions, extensions and bytes")
			var cold: Dictionary = _cold(bank.save_path)
			_check(Writer.canonical(GearInventoryCodec.encode(cold["bag"])) == Writer.canonical(before["bag"]) and cold["bank"].material_stash == before["stash"], kind + "/" + point + ": cold load cannot resurrect aborted costs")
			_check(_action(f, kind), kind + "/" + point + ": explicit retry commits once")

func _test_pending() -> void:
	for kind: String in ["social", "courier"]:
		for point: String in ["after_candidate", "after_decision", "after_old_rename", "after_commit"]:
			var f: Dictionary = _fixture("pending_" + kind + "_" + point, true)
			var bank: SanctuaryProfile = f["bank"]
			var before: Dictionary = _snapshot(f)
			bank._writer.fault_plan = {point: true}
			_check(not _action(f, kind) and bank.read_only and not f["economy"]._busy and _snapshot(f) == before, kind + "/" + point + ": unresolved journal exposes no speculative live cost")
			var cold: Dictionary = _cold(bank.save_path)
			if cold["bag"] == null: continue
			var committed: bool = point != "after_candidate"
			var expected_linen: int = 2 if committed and kind == "social" else 4
			var expected_dust: int = 1 if committed and kind == "courier" else 2
			_check(cold["bag"].materials[&"linen_fiber"] == expected_linen and cold["bag"].materials[&"dust"] == expected_dust and cold["bank"].material_stash == before["stash"], kind + "/" + point + ": journal recovers matching carried costs with untouched bank")
			var recorded: bool = NpcSocialProgress.helped(OpeningSocialRuntime.state(cold["bank"]), ID) if kind == "social" else cold["bank"].courier_objectives()["outcome"] == "help"
			_check(recorded == committed and cold["bank"].souls == before["souls"] and GearInventoryCodec.encode(cold["bag"])["items"] == before["bag"]["items"], kind + "/" + point + ": recovered receipt and exact gear ownership agree with payment")

func _test_life_fence() -> void:
	var f: Dictionary = _fixture("life_fence", true)
	var bank: SanctuaryProfile = f["bank"]
	var life: NpcWorldState = f["life"]
	var before: Dictionary = _snapshot(f)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	bank._writer.before_commit = func() -> void: life.receive_hit(ID, 1.0, 0.0)
	_check(not _action(f, "social") and life.records[ID]["mode"] == "recovering", "Real life owner can withdraw resident after quote but before profile commit")
	_check(_snapshot(f) == before and FileAccess.get_file_as_bytes(bank.save_path) == bytes and not NpcSocialProgress.helped(OpeningSocialRuntime.state(bank), ID), "Changed live/durable life fence aborts receipt and refunds carried linen")
	_check(not OpeningSocialRuntime.can_help(bank, life, ID, f["bag"]), "Withdrawn resident remains unavailable despite sufficient carried linen")

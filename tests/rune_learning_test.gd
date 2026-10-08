extends SceneTree
## Actual finite UID/cost transactions, writer faults and durable knowledge.
const Service = preload("res://scripts/runtime/rune_learning_service.gd")
const Cultivation = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int = 0
var failures: int = 0
var directory: String

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var actual: String = ProjectSettings.globalize_path("user://").replace("\\","/")
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not actual.begins_with(allowed + "/"):
		print("FAIL: Dedicated QA root is required before rune learning tests")
		quit(1)
		return
	directory = "user://verification/rune_learning_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	print("RUNE_LEARNING_USER_DIR="+actual)
	await _learning_and_crafting()
	_faults()
	_pending_recovery()
	_quarantine()
	print("RESULT rune_learning checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

func _fixture(label: String) -> Dictionary:
	var profile := SanctuaryProfile.new()
	profile.save_path = directory + "/" + label + "/profile.json"
	profile.souls = 100
	profile.material_stash[&"dust"] = 40
	profile.material_stash[&"crystal"] = 20
	_check(profile.save() and profile.commit_cultivation(Cultivation.initial_proposal(Cultivation.new_progress(43),profile.material_stash,profile.souls,profile.boss_proofs)),label+": fixture enters sealed v2 using the real owner")
	var inventory := GearInventory.new()
	inventory.add_rune(&"poison")
	var economy := EconomySession.new(); economy.initialize(profile,inventory); economy.persist_safe_inventory = true
	_check(economy._save_safe(),label+": original looted rune and safe inventory are durable")
	var service = Service.new(); service.initialize(economy)
	return {"profile":profile,"economy":economy,"inventory":inventory,"service":service}

func _cold(path: String) -> Dictionary:
	var profile := SanctuaryProfile.new(); profile.save_path = path
	_check(profile.load_profile() and not profile.read_only,"Cold profile resolves its sealed transaction")
	var inventory: GearInventory = GearInventoryCodec.decode(profile.hub_inventory)
	_check(inventory != null,"Cold inventory decodes finite committed UIDs")
	var economy := EconomySession.new(); economy.initialize(profile,inventory); economy.persist_safe_inventory = true
	var service = Service.new(); service.initialize(economy)
	return {"profile":profile,"economy":economy,"inventory":inventory,"service":service}

func _learning_and_crafting() -> void:
	var fixture: Dictionary = _fixture("normal")
	var profile: SanctuaryProfile = fixture["profile"]
	var economy: EconomySession = fixture["economy"]
	var inventory: GearInventory = fixture["inventory"]
	var service = fixture["service"]
	var persistence := SafeInventoryPersistence.new(); root.add_child(persistence); persistence.initialize(economy)
	_check(service.state() == Service.empty() and service.quote(&"fire")["can_learn"] and service.quote(&"wind")["cost"] == 5,"Old profile starts with no learned recipes and two introductory lessons")
	var poison_uid: int = inventory.items.keys()[0]
	_check(not service.quote(&"poison")["can_learn"] and inventory.equip_uid(0,poison_uid),"A looted rune can equip before its lesson unlocks")
	var detached: Dictionary = service.quote(&"fire"); detached["craft_materials"][&"dust"] = 999
	_check(service.quote(&"fire")["craft_materials"][&"dust"] == 2,"UI quotes cannot mutate shared cost definitions")
	var notifications: Array[int] = [0,0]
	var callback: Callable = func() -> void:
		notifications[0] += 1
		if service.learn(&"wind"): notifications[1] += 1
	inventory.changed.connect(callback)
	var before_items: int = inventory.items.size()
	var before_souls: int = profile.souls
	_check(service.learn(&"fire"),"First lesson commits knowledge and its first common rune")
	_check(profile.souls == before_souls-5 and inventory.items.size() == before_items+1 and service.state()["learned"] == ["fire"],"One lesson consumes its exact Tàn Hồn cost and grants one finite item")
	_check(notifications == [1,0] and not economy._busy,"One post-commit inventory signal cannot recursively purchase another lesson")
	inventory.changed.disconnect(callback)
	_check(persistence.committed == GearInventoryCodec.encode(inventory) and profile.hub_inventory == persistence.committed,"SafeInventoryPersistence observes only the committed UID ledger")
	var fire_uids: Array[int] = []
	for item: GearItem in inventory.items.values():
		if item.kind == &"rune" and item.definition_id == &"fire":
			fire_uids.append(item.uid)
			_check(item.quality == GearItem.Quality.COMMON and item.uid > 0,"Lesson reward has the existing common tier and a positive UID")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(profile.save_path)
	_check(not service.learn(&"fire") and bytes == FileAccess.get_file_as_bytes(profile.save_path),"Repeated learning neither charges again nor creates another rune or write")
	_check(not service.learn(&"lightning") and not service.learn(&"ice") and not service.learn(&"unknown"),"Missing exploration and unknown IDs cannot bypass lesson gates")
	profile.opening_progress = OpeningProgress.with_event(profile.opening_progress,&"explored")
	_check(profile.save() and service.learn(&"lightning") and service.learn(&"ice") and service.learn(&"wind"),"Existing exploration milestone unlocks both advanced lessons")
	_check(not service.learn(&"poison"),"Poison still requires the existing opening boss milestone")
	_check(profile.record_boss_defeat("rune_learning_controlled_boss") and service.learn(&"poison"),"Existing boss record unlocks poison without creating a new quest system")
	var revision: int = profile.extension_revision(Service.SCOPE)
	var receipts: Array = profile._retained_fields["event_extensions"]["namespaces"][Service.SCOPE]["receipts"].duplicate(true)
	var dust: int = profile.material_stash[&"dust"]
	var crystal: int = profile.material_stash[&"crystal"]
	var souls: int = profile.souls
	_check(revision == 5 and receipts.size() == 5 and service.craft(&"fire") and service.craft(&"fire"),"Five permanent lessons use five receipts; repeat craft succeeds independently")
	_check(profile.material_stash[&"dust"] == dust-4 and profile.material_stash[&"crystal"] == crystal-2 and profile.souls == souls,"Each repeat rune consumes two dust and one crystal from the stash only")
	_check(profile.extension_revision(Service.SCOPE) == revision and profile._retained_fields["event_extensions"]["namespaces"][Service.SCOPE]["receipts"] == receipts,"Repeat crafting does not consume extension receipt capacity")
	var encoded: Dictionary = GearInventoryCodec.encode(inventory)
	var cold: Dictionary = _cold(profile.save_path)
	_check(cold["service"].state() == service.state() and GearInventoryCodec.encode(cold["inventory"]) == encoded and cold["profile"].souls == souls,"Knowledge, all exact rune UIDs, costs and pre-existing equipment survive cold load")
	_check(not cold["service"].learn(&"fire") and cold["inventory"].items.has(fire_uids[0]) and cold["inventory"].items.has(poison_uid),"Cold replay retains both first reward and original looted UID")
	economy.hub_access = false
	_check(not service.craft(&"fire"),"Dungeon ownership cannot craft through a stale hub service")
	economy.hub_access = true
	profile.material_stash[&"dust"] = 0
	_check(not service.quote(&"fire")["can_craft"] and not service.craft(&"fire"),"Missing stash materials block repeat crafting")
	profile.material_stash[&"dust"] = dust-4
	while inventory.items.size() < GearInventoryCodec.MAX_ITEMS:
		inventory.add_item(&"rune",&"wind")
		inventory.bag[&"wind"] += 1
	_check(not service.craft(&"fire") and not service.quote(&"fire")["can_craft"],"Durable item capacity is checked before adding another rune")
	persistence.queue_free()
	await process_frame

func _faults() -> void:
	for action: String in ["learn","craft"]:
		for point: String in ["write_candidate","write_decision","rename_decision","rename_old","commit"]:
			var fixture: Dictionary = _fixture(action+"_"+point)
			var profile: SanctuaryProfile = fixture["profile"]
			var service = fixture["service"]
			if action == "craft": _check(service.learn(&"fire"),"Craft fault has a durable learned prerequisite")
			var inventory_before: Dictionary = GearInventoryCodec.encode(fixture["inventory"])
			var ledger_before: Dictionary = profile.hub_inventory.duplicate(true)
			var bank_before: Dictionary = profile.material_stash.duplicate()
			var souls_before: int = profile.souls
			var knowledge_before: Dictionary = service.state()
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(profile.save_path)
			profile._writer.fault_plan = {point:true}
			var success: bool = service.learn(&"fire") if action == "learn" else service.craft(&"fire")
			_check(not success and not fixture["economy"]._busy and not profile.read_only,action+"/"+point+": verified failure returns without publishing provisional purchase")
			_check(profile.hub_inventory == ledger_before and GearInventoryCodec.encode(fixture["inventory"]) == inventory_before and profile.material_stash == bank_before and profile.souls == souls_before and service.state() == knowledge_before,action+"/"+point+": rollback preserves exact costs, UID ledger and knowledge")
			_check(FileAccess.get_file_as_bytes(profile.save_path) == bytes,action+"/"+point+": primary bytes remain unchanged after definitive abort")
			var cold: Dictionary = _cold(profile.save_path)
			_check(cold["service"].state() == knowledge_before and GearInventoryCodec.encode(cold["inventory"]) == inventory_before,action+"/"+point+": cold reload cannot resurrect an aborted reward")
			_check(service.learn(&"fire") if action == "learn" else service.craft(&"fire"),action+"/"+point+": explicit retry commits once after safe rollback")

func _pending_recovery() -> void:
	for point: String in ["after_candidate","after_decision","after_old_rename","after_commit"]:
		var fixture: Dictionary = _fixture("pending_"+point)
		var profile: SanctuaryProfile = fixture["profile"]
		var original: Dictionary = GearInventoryCodec.encode(fixture["inventory"])
		profile._writer.fault_plan = {point:true}
		_check(not fixture["service"].learn(&"fire") and profile.read_only and GearInventoryCodec.encode(fixture["inventory"]) == original,point+": uncertain commit exposes no speculative live rune")
		var committed: bool = point != "after_candidate"
		var candidate: Dictionary = Writer.read_json(profile.save_path if point == "after_commit" else profile.save_path+".tmp")
		var expected: Dictionary = candidate["hub_inventory"].duplicate(true) if committed else original
		var cold: Dictionary = _cold(profile.save_path)
		# Candidate JSON has float wire numbers; codec restores typed integer UIDs.
		_check(GearInventoryCodec.valid(expected) and Writer.canonical(GearInventoryCodec.encode(cold["inventory"])) == Writer.canonical(expected) and cold["profile"].souls == 100-(5 if committed else 0),point+": journal recovery resolves exact finite UID and cost together")
		_check(cold["service"].quote(&"fire")["learned"] == committed,point+": recovered knowledge agrees with recovered item transaction")
		if committed: _check(not cold["service"].learn(&"fire"),point+": recovery never grants a second initial rune")

func _quarantine() -> void:
	var cases: Array[Dictionary] = [{"schema":2,"learned":["fire"]},{"schema":1,"learned":["unknown"]},{"schema":1,"learned":["fire","fire"]},{"schema":true,"learned":["fire"]}]
	for index: int in cases.size():
		var fixture: Dictionary = _fixture("quarantine_%d" % index)
		var profile: SanctuaryProfile = fixture["profile"]
		# Trusted fault injection creates an otherwise sealed unsupported extension.
		profile.register_extension_validator(Service.SCOPE,func(_value: Variant) -> bool: return true)
		_check(profile.commit_extension_event(Service.SCOPE,"unsupported_fixture",{},0,cases[index],0).get("ok",false),"Unsupported extension fixture uses the same sealed writer")
		var cold: Dictionary = _cold(profile.save_path)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(profile.save_path)
		_check(cold["service"].state().is_empty() and not cold["service"].learn(&"fire") and not cold["service"].craft(&"fire"),"Malformed or future knowledge is quarantined instead of silently becoming an empty lesson list")
		_check(not cold["profile"].read_only and bytes == FileAccess.get_file_as_bytes(profile.save_path),"Subsystem quarantine preserves bytes without locking unrelated profile owners")
	var mismatch: Dictionary = _fixture("receipt_mismatch")
	_check(mismatch["profile"].commit_extension_event(Service.SCOPE,"receipt_without_lesson",{},0,Service.empty(),0).get("ok",false),"Receipt count mismatch is a well-formed sealed negative fixture")
	_check(mismatch["service"].state().is_empty() and not mismatch["service"].learn(&"fire"),"Receipt and learned count mismatch cannot mint another first-rune reward")

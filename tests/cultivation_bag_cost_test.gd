extends SceneTree
## Actual safe-Hub session handlers; synthetic progression only seeds the gates.
## All writes require the explicitly isolated QA user directory.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int = 0
var failures: int = 0
var hz: int = 60
var flow: GameFlow
var hub: ExteriorHub
var session: OpeningCultivationSession
var inventory: GearInventory
var persistence: SafeInventoryPersistence

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func step(count: int = 1) -> void:
	for _index: int in count: await physics_frame

func pulse() -> void:
	for _index: int in hz * 2: session._physics_process(1.0 / float(hz))

func image() -> String:
	return Writer.canonical({"profile":flow.profile._export_payload(),"inventory":GearInventoryCodec.encode(inventory)})

func bytes() -> PackedByteArray: return FileAccess.get_file_as_bytes(flow.profile.save_path)

func revision() -> int: return int(Writer.read_json(flow.profile.save_path)["profile_commit"]["revision"])

func quote_train(actor_id: String = "player") -> Dictionary:
	var progress: Dictionary = flow.profile.cultivation_progress
	var actor: Dictionary = progress["actors"][actor_id]
	return Model.propose(progress, session._cost_materials(inventory), flow.profile.souls, flow.profile.boss_proofs, "train", {"actor_id":actor_id,"sessions":1,"target_tick":maxi(int(progress["gameplay_tick"]),int(actor["last_train_tick"]))+8}, "cult_%d" % int(progress["next_event"]))

func finish() -> void:
	if is_instance_valid(flow): flow.queue_free()
	await step(4)
	await root.get_node("AudioManager").shutdown()
	print("RESULT CultivationBagCost hz=%d checks=%d failures=%d" % [hz, checks, failures])
	quit(0 if failures == 0 else 1)

func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if DisplayServer.get_name() != "headless" or not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\", "/").begins_with(qa + "/"):
		print("FAIL: isolated headless QA user directory required"); quit(2); return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz = int(argument.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	var path: String = "user://verification/cultivation_bag_%d_%d/profile.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var fixture := SanctuaryProfile.new()
	fixture.save_path = path
	fixture.material_stash[&"crystal"] = 100
	fixture.material_stash[&"dust"] = 100
	fixture.material_stash[&"metal"] = 7
	fixture.souls = 30
	fixture.boss_proofs[&"golem"] = 1
	fixture.hub_inventory = GearInventoryCodec.encode(HubPreparation.starter_inventory(fixture))
	check(fixture.save(), "Existing writer establishes the isolated legacy before-image")
	fixture.profile_version = 2
	fixture.cultivation_progress = Model.new_progress(4)
	var actor: Dictionary = fixture.cultivation_progress["actors"]["player"]
	actor["stage"] = 2; actor["energy"] = 40; actor["mastery"] = 8
	actor["insight_ids"] = Model.OBSERVATIONS.duplicate()
	check(Model.valid(fixture.cultivation_progress, fixture.material_stash) and fixture.save(), "Synthetic ready-for-final-breakthrough fixture is valid and isolated")
	if failures > 0:
		print("FIXTURE_DIAGNOSTIC ",fixture.last_commit); await finish(); return
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path
	root.add_child(flow); current_scene = flow
	await step(12)
	hub = flow.active_scene as ExteriorHub
	session = flow.cultivation_session
	if hub == null or not session.initialized:
		check(false, "Product main binds the real safe Hub and cultivation session"); await finish(); return
	session.set_physics_process(false)
	inventory = hub.gear.inventory
	for child: Node in hub.get_children():
		if child is SafeInventoryPersistence: persistence = child
	check(persistence != null and session._safe_carried_inventory() == inventory, "Cost owner is the actual safe-Hub inventory and its existing ledger")
	check(session.snapshot()["materials"][&"crystal"] == 0 and session.snapshot()["materials"][&"dust"] == 0, "Panel reports carried ordinary resources instead of stocked bank")
	hub.player.relocate(hub.stations[&"training"].global_position)
	await step(3)
	var before: String = image()
	var before_bytes: PackedByteArray = bytes()
	check(session.start_training("player"), "Actual session starts player training")
	pulse()
	check(session.error == "training_resource_required" and image() == before and bytes() == before_bytes, "Bank-only crystals cannot pay; failed pulse preserves bag, progress and save bytes")
	hub.open_station(&"training")
	check(not session.perform("train", {"actor_id":"player","sessions":1,"target_tick":8}).get("ok",false), "UI cannot fabricate training clock commands")
	check(not session.perform("breakthrough", {"actor_id":"player","branch_id":"tether_sigil"}).get("ok",false) and image() == before, "Bank-only dust cannot pay final breakthrough")
	hub.close_station()
	hub.player.relocate(Vector2(370,640)); await step(3)
	check(hub.interact_station(&"aptitude_herb") and flow.profile.material_stash[&"aptitude_herb"] == 1, "Real harvest keeps one lineage herb in the canonical bank")
	hub.player.relocate(hub.stations[&"training"].global_position); await step(3)
	hub.open_station(&"training")
	before = image(); before_bytes = bytes()
	check(not session.perform("craft_pill", {"origin_id":"h00_courtyard_01"}).get("ok",false) and image() == before and bytes() == before_bytes, "Pill crafting cannot silently use bank dust")
	hub.close_station()
	check(inventory.add_material(&"crystal",6) and inventory.add_material(&"dust",6), "Fixture adds carried resources through real inventory persistence")
	var original_items: String = Writer.canonical(GearInventoryCodec.encode(inventory)["items"])
	before = image(); before_bytes = bytes()
	flow.profile._writer.fault_plan = {"write_candidate":true}
	check(session.start_training("player"), "Player training can retry with carried crystals")
	pulse()
	check(image() == before and bytes() == before_bytes and not hub.economy._busy, "Write failure rolls back carried counts, ledger and progress and releases economy lock")
	var proposal: Dictionary = quote_train()
	var old_revision: int = revision()
	var published_materials: Array[Dictionary] = []
	var capture_snapshot: Callable = func() -> void:
		if session._busy and not hub.economy._busy: published_materials.append(session.snapshot()["materials"].duplicate())
	session.ui_changed.connect(capture_snapshot)
	check(session.start_training("player"), "Retry starts the real training clock")
	pulse(); session.stop_training()
	session.ui_changed.disconnect(capture_snapshot)
	check(inventory.materials[&"crystal"] == 5 and flow.profile.material_stash[&"crystal"] == 100 and flow.profile.cultivation_progress["actors"]["player"]["energy"] == 48, "Two eligible seconds spend exactly one bag crystal while bank and earned mastery remain")
	check(not published_materials.is_empty() and published_materials.back()[&"crystal"] == 5 and published_materials.back()[&"dust"] == 6 and session.snapshot()["materials"][&"crystal"] == 5, "Final ui_changed after economy unlock publishes real carried counts instead of a transient zero snapshot")
	check(revision() == old_revision+1 and persistence.committed == flow.profile.hub_inventory, "Cost and progress use one durable write and refresh the safe inventory rollback ledger")
	before = image(); before_bytes = bytes()
	check(flow.profile.commit_cultivation(proposal,{},Callable(),"",inventory) and image() == before and bytes() == before_bytes, "Replaying the exact committed proposal cannot consume the bag twice")
	proposal = quote_train()
	check(inventory.add_material(&"crystal",1), "Live inventory can change after a quote")
	before = image(); before_bytes = bytes()
	check(not flow.profile.commit_cultivation(proposal,{},Callable(),"",inventory) and image() == before and bytes() == before_bytes, "Changed carried resource source rejects stale proposal without mutation")
	proposal = quote_train()
	proposal["materials"]["dust"] += 1
	check(not flow.profile.commit_cultivation(proposal,{},Callable(),"",inventory) and image() == before, "Owner re-proposes and rejects a forged output instead of trusting adapter material counts")
	hub.open_station(&"training")
	before = image(); before_bytes = bytes()
	flow.profile._writer.fault_plan = {"write_candidate":true}
	check(not session.perform("craft_pill", {"origin_id":"h00_courtyard_01"}).get("ok",false) and image() == before and bytes() == before_bytes, "Pill write failure restores bag dust and exact herb lineage together")
	check(session.perform("craft_pill", {"origin_id":"h00_courtyard_01"}).get("ok",false), "Real pill handler commits using carried dust")
	check(inventory.materials[&"dust"] == 4 and flow.profile.material_stash[&"dust"] == 100 and flow.profile.material_stash[&"aptitude_herb"] == 0 and flow.profile.material_stash[&"aptitude_pill"] == 1 and Model.valid(flow.profile.cultivation_progress,flow.profile.material_stash), "Pill conversion preserves lineage validation and ordinary bank stock")
	check(session.perform("consume", {"actor_id":"player","origin_id":"h00_courtyard_01"}).get("ok",false) and flow.profile.cultivation_progress["actors"]["player"]["aptitude"] == 8 and inventory.materials[&"dust"] == 4, "Consuming lineage pill stays on its existing authority and has no ordinary bag debit")
	before = image(); before_bytes = bytes()
	flow.profile._writer.fault_plan = {"write_candidate":true}
	check(not session.perform("breakthrough", {"actor_id":"player","branch_id":"tether_sigil"}).get("ok",false) and image() == before and bytes() == before_bytes and flow.profile.cultivation_abilities()["learned_ids"].is_empty(), "Final breakthrough write failure rolls back dust, souls, stage and branch together")
	check(session.perform("breakthrough", {"actor_id":"player","branch_id":"tether_sigil"}).get("ok",false), "Final breakthrough actual handler succeeds with bag dust")
	actor = flow.profile.cultivation_progress["actors"]["player"]
	check(actor["stage"] == 3 and actor["mastery"] == 8 and actor["insight_ids"].size() == 3 and actor["energy"] == 48 and inventory.materials[&"dust"] == 3 and flow.profile.souls == 30 and flow.profile.boss_proofs[&"golem"] == 1, "Breakthrough keeps earned progress/proof, spends one carried dust and preserves Souls under the PC curriculum")
	var life_state: NpcWorldState = hub.npc_population.state
	life_state.records[Model.NPC]["mode"] = "rest"; life_state.records[Model.NPC]["remaining"] = 32
	check(life_state.save() and session.perform("enroll", {"enabled":true}).get("ok",false), "Existing NPC authority enrolls a real eligible gatherer")
	hub.close_station()
	var life_bytes: PackedByteArray = FileAccess.get_file_as_bytes(life_state.save_path)
	var crystals: int = inventory.materials[&"crystal"]
	check(session.start_training(Model.NPC), "NPC sponsored training begins against its own life fence")
	pulse(); session.stop_training()
	check(inventory.materials[&"crystal"] == crystals-1 and flow.profile.material_stash[&"crystal"] == 100 and flow.profile.cultivation_progress["actors"][Model.NPC]["energy"] == 8 and FileAccess.get_file_as_bytes(life_state.save_path) == life_bytes, "NPC cost comes from player carried supplies without modifying the life sidecar")
	var fence: Dictionary = session.life.capture(Model.NPC)
	proposal = quote_train(Model.NPC)
	life_state.records[Model.NPC]["mode"] = "talk"
	before = image(); before_bytes = bytes()
	check(not flow.profile.commit_cultivation(proposal,fence,session.life.matches.bind(fence),"",inventory) and image() == before and bytes() == before_bytes, "Changed NPC life fence aborts proposed bag cost and progress atomically")
	life_state.records[Model.NPC]["mode"] = "rest"
	hub.economy.persist_safe_inventory = false
	before = image(); before_bytes = bytes()
	check(session.start_training(Model.NPC), "NPC may request training before safe-context cost validation")
	pulse(); session.stop_training()
	check(image() == before and bytes() == before_bytes, "Missing safe bag context blocks NPC pulse instead of falling back to bank")
	var saved_ledger: String = Writer.canonical(flow.profile.hub_inventory)
	var old_carried_dust: int = inventory.materials[&"dust"]
	inventory.materials[&"dust"] += 10 # Unsaved run-like state; deliberately no inventory signal.
	check(session._commit("mastery",{}).get("ok",false) and Writer.canonical(flow.profile.hub_inventory) == saved_ledger, "Non-cost mastery never checkpoints transient carried inventory into the Hub ledger")
	inventory.materials[&"dust"] = old_carried_dust
	hub.economy.persist_safe_inventory = true
	check(Writer.canonical(GearInventoryCodec.encode(inventory)["items"]) == original_items and flow.profile.material_stash[&"metal"] == 7, "Transactions preserve unrelated gear metadata and bank materials")
	var cold := SanctuaryProfile.new(); cold.save_path = path
	check(cold.load_profile() and not cold.read_only and cold.cultivation_progress == flow.profile.cultivation_progress and Writer.canonical(cold.hub_inventory) == Writer.canonical(GearInventoryCodec.encode(inventory)) and cold.material_stash == flow.profile.material_stash and cold.souls == flow.profile.souls, "Cold reload restores matching bag, bank, cultivation, lineage and currencies")
	await finish()

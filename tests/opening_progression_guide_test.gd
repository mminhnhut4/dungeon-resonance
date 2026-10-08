extends SceneTree
## Focused private QA: real quotes/UIDs, detached hints and actual product modal.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
class CountingProfile extends SanctuaryProfile:
	var saves: int = 0
	func save() -> bool:
		saves += 1
		return true
var checks: int = 0
var failures: int = 0
var flow: GameFlow
var directory: String
var examples: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: "+label)

func _step(count: int = 4) -> void:
	for _index: int in count: await physics_frame

func _state(profile: SanctuaryProfile, inventory: GearInventory) -> String:
	return JSON.stringify({"opening":profile.opening_progress,"cultivation":profile.cultivation_progress,"exterior":profile.exterior_progress,"upgrades":profile.permanent_upgrades,"souls":profile.souls,"coins":profile.coins,"bank":profile.material_stash,"proofs":profile.boss_proofs,"inventory":GearInventoryCodec.encode(inventory)})

func _guide(id: StringName, profile: SanctuaryProfile, inventory: GearInventory) -> Dictionary:
	return OpeningProgressionGuide.for_milestone(id, profile, inventory)

func _sample(label: String, profile: SanctuaryProfile, inventory: GearInventory) -> void:
	examples[label] = MapQuestProjection.rows(profile,inventory)

func _journal_row(journal: QuestJournal,id: StringName) -> Dictionary:
	for row: Dictionary in journal.rows:
		if row["id"] == id: return row
	return {}

func _base_gain_copy(inventory: GearInventory) -> void:
	var profile := CountingProfile.new()
	profile.cultivation_progress = Model.new_progress(4)
	profile.material_stash[&"crystal"] = 20
	var commands: Array[Dictionary] = [
		{"kind":"harvest","args":{"node_id":"h00_courtyard_01"}},
		{"kind":"consume","args":{"actor_id":"player","origin_id":"h00_courtyard_01"}},
		{"kind":"train","args":{"actor_id":"player","sessions":2,"target_tick":16}}
	]
	for index: int in commands.size():
		var command: Dictionary = commands[index]
		var result: Dictionary = Model.propose(profile.cultivation_progress,profile.material_stash,profile.souls,profile.boss_proofs,command["kind"],command["args"],"copy_fixture_%d" % index)
		_check(result.get("ok",false), "Owned model constructs valid aptitude/remainder copy fixture")
		if not result.get("ok",false): return
		profile.cultivation_progress = result["progress"]
		profile.material_stash.assign(result["materials"])
	var actor: Dictionary = profile.cultivation_progress["actors"]["player"]
	_check(actor["aptitude"] == 5 and actor["remainder"] == 8000, "Fixture carries real consumed-herb aptitude and accumulated fractional gain")
	var before: String = _state(profile,inventory)
	var next: Dictionary = Model.propose(profile.cultivation_progress,profile.material_stash,profile.souls,profile.boss_proofs,"train",{"actor_id":"player","sessions":1,"target_tick":24},"copy_next_session")
	_check(next.get("ok",false) and int(next["progress"]["actors"]["player"]["energy"])-int(actor["energy"]) == 9, "Actual next session gain differs from the base eight")
	var hint: String = _guide(&"first_upgrade",profile,inventory)["body"]
	_check("nhận 8 năng lượng cơ bản" in hint and "Tư chất ảnh hưởng lượng thực nhận" in hint and not "nhận 8 năng lượng." in hint, "Copy labels configured base gain rather than promising exact session reward")
	_check(_state(profile,inventory) == before and profile.saves == 0, "Copy projection and model preview leave authoritative state untouched")

func _pure_contracts() -> void:
	var profile := CountingProfile.new()
	var inventory: GearInventory = HubPreparation.starter_inventory(profile)
	inventory._ensure_slots()
	var initial: String = _state(profile, inventory)
	var serial: int = int(get_meta(&"dungeon_combat_serial", 0))
	var base: Array[Dictionary] = MapQuestProjection.rows(profile)
	_sample("fresh_equipped",profile,inventory)
	_base_gain_copy(inventory)
	for _repetition: int in 3:
		var guided: Array[Dictionary] = MapQuestProjection.rows(profile, inventory)
		_check(guided.size() == 6, "Six existing milestones; no extra quest")
		for index: int in 6:
			for field: String in ["id","title","target","done","next"]:
				_check(guided[index][field] == base[index][field], "Canonical row field preserved: "+field)
			_check(guided[index]["guide"]["body"].length() < 1800, "Bounded Vietnamese topic")
	_check(_state(profile, inventory) == initial and profile.saves == 0, "Repeated projection has no reward, currency, completion, ledger or save effects")
	_check(int(get_meta(&"dungeon_combat_serial", 0)) == serial, "Hints never allocate an item or combat UID")
	_check(not "Golem" in str(MapQuestProjection.rows(profile, inventory)) and not "Thanh Vy" in str(MapQuestProjection.rows(profile, inventory)), "Unknown quest identities remain undisclosed")
	_check(_guide(&"explored",profile,inventory)["status"] == "equipped", "Fresh existing starter is correctly reported equipped")
	var sword: GearItem = inventory.items[inventory.equipped_weapon_uid]
	inventory.unequip_equipment(0)
	_check(_guide(&"explored",profile,inventory)["status"] == "equip_needed", "Owned usable weapon gives an equip instruction")
	inventory.equip_equipment(sword.uid)
	_check(_guide(&"reward_collected",profile,inventory)["blockers"] == ["bank_stone_required","bank_coins_required"], "No ingredients reports both real deficits")
	_sample("no_upgrade_ingredients",profile,inventory)
	inventory.materials[&"enhancement_stone_1"] = 1
	profile.coins = 5
	_check(_guide(&"reward_collected",profile,inventory)["blockers"] == ["bank_stone_required"], "Carried stone does not satisfy the bank cost")
	_check(_guide(&"golem_defeated",profile,inventory)["status"] == "deposit_needed", "Carried ordinary material directs to existing stash")
	var economy := EconomySession.new(); economy.profile = profile; economy.inventory = inventory
	for level: int in 12:
		sword.enhancement_level = level
		var quote: Dictionary = economy.quote_enhance(sword.uid)
		profile.material_stash[quote["stone_id"]] = 1
		profile.coins = int(quote["coin_cost"])
		var hint: Dictionary = _guide(&"reward_collected",profile,inventory)
		_check(hint["status"] == "resources_ready" and str(quote["coin_cost"]) in hint["body"] and MaterialCatalog.DISPLAY_NAMES[quote["stone_id"]] in hint["body"], "All twelve quotes follow actual coin and stone grade contracts")
		_check(("%.2f → %.2f" % [sword.damage_factor(),sword.damage_factor()+0.03]) in hint["body"], "Before/after follows actual additive item factor")
	sword.enhancement_level = 12
	_check(_guide(&"reward_collected",profile,inventory)["status"] == "capped", "Capped weapon offers no +13")
	_sample("weapon_at_plus_12",profile,inventory)
	sword.broken = true
	_check(_guide(&"reward_collected",profile,inventory)["status"] == "repair_needed", "Broken equipped fixture never claims enhancement readiness")
	sword.broken = false
	var missing: Dictionary = _guide(&"returned_to_hub",profile,inventory)
	_check(missing["blockers"].has("rune_fire_required") and missing["blockers"].has("rune_wind_required") and "rương nhỏ có 2" in missing["body"] and "mất khi chết" in missing["body"], "Missing ingredients show the actual finite chest source and carried loss contract")
	_sample("missing_talisman_runes",profile,inventory)
	inventory.add_rune(&"fire"); inventory.add_rune(&"wind")
	_check(_guide(&"returned_to_hub",profile,inventory)["status"] == "install_needed", "Owned ingredients still require Catalyst installation")
	inventory.equip(3,&"fire")
	_check(_guide(&"returned_to_hub",profile,inventory)["status"] == "install_needed", "Rune on weapon is owned and can be moved to Catalyst")
	inventory.equip(3,&"")
	inventory.equip_catalyst_set([&"fire",&"wind"])
	_check(_guide(&"returned_to_hub",profile,inventory)["status"] == "exact_set", "Exact production Firestorm multiset is ready to try")
	inventory.add_rune(&"fire"); inventory.equip(2,&"fire")
	_check(_guide(&"returned_to_hub",profile,inventory)["status"] == "install_needed", "Extra duplicate invalidates exact pair; no subset fallback")
	profile.souls = 0
	_check(_guide(&"thanh_vy_met",profile,inventory)["status"] == "souls_required", "Permanent upgrade uses Souls rather than weapon stones or coins")
	profile.souls = 20
	_check(_guide(&"thanh_vy_met",profile,inventory)["status"] == "resources_ready", "First actual HP quote is affordable at 20 Souls")
	for id: StringName in WorldProgressionCatalog.UPGRADES: profile.permanent_upgrades[id] = WorldProgressionCatalog.MAX_LEVELS[id]
	_check(_guide(&"thanh_vy_met",profile,inventory)["status"] == "capped", "All permanent caps are reported without another purchase")
	profile.cultivation_progress = Model.new_progress(4)
	var cultivation: Dictionary = _guide(&"first_upgrade",profile,inventory)
	_check(cultivation["blockers"].has("energy_required") and cultivation["blockers"].has("mastery_required") and cultivation["blockers"].has("insight_required") and cultivation["blockers"].has("training_crystal_required"), "All initial cultivation prerequisites are explicit")
	profile.cultivation_progress["config"]["training_cost"] = 7
	_check("7 Tinh Thạch" in _guide(&"first_upgrade",profile,inventory)["body"], "Training guidance uses saved configurable tuning")
	var actor: Dictionary = profile.cultivation_progress["actors"]["player"]
	actor["stage"] = 2; actor["energy"] = 40; actor["mastery"] = 8; actor["insight_ids"] = ["explored","thanh_vy_met","golem_defeated"]
	profile.material_stash[&"dust"] = 2; profile.souls = 5
	_check(Model.valid(profile.cultivation_progress,profile.material_stash), "Missing-proof fixture is a valid owned cultivation track")
	_check(_guide(&"first_upgrade",profile,inventory)["blockers"] == ["boss_proof_required"], "Final breakthrough needs actual saved boss proof despite other sufficient numbers")
	_sample("breakthrough_missing_proof",profile,inventory)
	profile.boss_proofs[&"golem"] = 1
	_check(_guide(&"first_upgrade",profile,inventory)["status"] == "requirements_ready", "All displayed breakthrough requirements match saved state")
	actor["stage"] = 3
	_check(_guide(&"first_upgrade",profile,inventory)["status"] == "opening_complete", "Completed opening does not invent a higher realm")
	profile.read_only = true
	_check(_guide(&"thanh_vy_met",profile,inventory)["status"] == "blocked" and _guide(&"first_upgrade",profile,inventory)["status"] == "unavailable", "Quarantined profile does not claim transaction readiness")
	profile.read_only = false
	for id: StringName in OpeningProgress.IDS: profile.opening_progress = OpeningProgress.with_event(profile.opening_progress,id)
	var empty := GearInventory.new(); empty._ensure_slots()
	var skipped: Array[Dictionary] = MapQuestProjection.rows(profile,empty)
	_check(skipped.all(func(row: Dictionary) -> bool: return row["done"]) and skipped[0]["guide"]["status"] == "weapon_needed", "Skipped/old completed milestones do not manufacture equipment readiness")
	_sample("completed_quests_empty_gear",profile,empty)
	profile.opening_progress_quarantined = true
	_check(MapQuestProjection.rows(profile,inventory).is_empty(), "Unknown opening schema stays unavailable without invented milestones")
	_check(OpeningProgressionGuide.for_milestone(&"explored",null,null)["status"] == "unavailable", "Missing owners fail closed")
	var world_drops: DropTableResource = preload("res://data/loot/world_drop_table.tres")
	_check(is_equal_approx(world_drops.none_chance,0.35), "Current opening world loot has the audited 35 percent empty gate")
	var spawner := LootSpawner.new()
	spawner.inventory = inventory; spawner.permanent_profile = profile
	spawner.drop_table = world_drops.duplicate() as DropTableResource
	spawner.drop_table.none_chance = 1.0; spawner.drop_table.blueprint_chance_total = 0.0
	root.add_child(spawner)
	spawner.enemy_drop(Vector2.ZERO,&"golem",false,true)
	_check(spawner.spawned_total == 0, "Existing boss drop path can produce no Souls/reward; guide promises no automatic grant")
	spawner.free()

func _open(path: String) -> ExteriorHub:
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path
	root.add_child(flow); current_scene = flow
	await _step(12)
	flow.cultivation_session.set_physics_process(false)
	var hub: ExteriorHub = flow.active_scene as ExteriorHub
	if hub != null: hub.npc_population.set_process(false)
	return hub

func _close() -> void:
	flow.queue_free(); await _step(6); flow = null
	_check(is_equal_approx(Engine.time_scale,1.0), "Product teardown releases modal time claims")

func _product_replay_and_death() -> void:
	var fixture := SanctuaryProfile.new(); fixture.save_path = directory+"/product/profile.json"
	fixture.souls = 60; fixture.coins = 200; fixture.material_stash[&"dust"] = 8; fixture.material_stash[&"crystal"] = 8
	for id: StringName in OpeningProgress.IDS: fixture.opening_progress = OpeningProgress.with_event(fixture.opening_progress,id)
	var kit: GearInventory = HubPreparation.starter_inventory(fixture)
	kit.items[kit.equipped_weapon_uid].enhancement_level = 9
	fixture.hub_inventory = GearInventoryCodec.encode(kit)
	_check(fixture.save(), "Durable old completed profile uses existing save owner")
	_check(fixture.commit_cultivation(Model.initial_proposal(Model.new_progress(4),fixture.material_stash,fixture.souls,fixture.boss_proofs)), "Existing cultivation owner initializes isolated fixture")
	var hub: ExteriorHub = await _open(fixture.save_path)
	_check(hub != null, "Actual GameFlow opens private product fixture")
	if hub == null: await _close(); return
	var screen: InventoryScreen = hub.gear.modal as InventoryScreen
	var journal: QuestJournal = screen.journal
	var bytes: String = FileAccess.get_file_as_string(flow.profile.save_path)
	var state: String = _state(flow.profile,hub.gear.inventory)
	for index: int in 6:
		journal.select_quest(OpeningProgress.IDS[index])
		_check("HÀNH TRANG & SỨC MẠNH" in journal.objective_label.text and "TRẠNG THÁI:" in journal.objective_label.text and _journal_row(journal,OpeningProgress.IDS[index])["done"], "Completed topic and honest reward status are replayable in existing quest detail")
	journal.extension_rows_provider = func() -> Array[Dictionary]: return [{"id":&"existing_side_quest","title":"Việc tự nguyện","body":"Nội dung do owner hiện có cung cấp.","done":false}]
	journal.refresh()
	_check(journal.rows.size() == 8 and journal.rows[-1]["id"] == &"existing_side_quest", "Existing extension providers survive cards and cultivation follow-up")
	journal.extension_rows_provider = Callable(); journal.refresh()
	screen.open_map(); await _step()
	_check(screen.is_open and screen.tabs.current_tab == 2 and journal.tracker_text().is_empty() and not screen.tracker.visible, "Existing Map modal contains guidance with no persistent HUD")
	journal.select_quest(&"reward_collected")
	_check("+9 → +10" in journal.objective_label.text, "Old equipped enhancement is read from the actual UID")
	journal.scroll_detail(96); await _step(2)
	_check(journal.detail_scroll.scroll_vertical > 0, "Existing detail scroll accommodates Vietnamese guide")
	screen.close(); await _step()
	_check(_state(flow.profile,hub.gear.inventory) == state and FileAccess.get_file_as_string(flow.profile.save_path) == bytes, "Opening/reading/replaying modal leaves profile bytes, bank and inventory unchanged")
	var old_inventory: GearInventory = hub.gear.inventory
	var old_journal_id: int = journal.get_instance_id()
	var journal_listener := Callable(journal,"_request_refresh")
	var other_inventory_listeners: Array[Callable] = []
	for connection: Dictionary in old_inventory.changed.get_connections():
		var callback: Callable = connection["callable"]
		if callback.get_object_id() != old_journal_id: other_inventory_listeners.append(callback)
	for _index: int in 6: journal.bind_progress(flow.profile,old_inventory)
	_check(old_inventory.changed.get_connections().filter(func(connection: Dictionary) -> bool: return connection["callable"] == journal_listener).size() == 1 and flow.profile.changed.get_connections().filter(func(connection: Dictionary) -> bool: return connection["callable"] == journal_listener).size() == 1 and other_inventory_listeners.all(func(callback: Callable) -> bool: return old_inventory.changed.is_connected(callback)), "Repeated binding keeps one journal refresh request per owner and preserves unrelated listeners")
	old_inventory.unequip_equipment(0)
	_check(_journal_row(journal,&"explored")["guide"]["status"] == "equip_needed", "Actual inventory signal refreshes guide immediately")
	old_inventory.equip_equipment(kit.equipped_weapon_uid)
	flow.start_campaign(); await _step(10)
	var run: DungeonRun = flow.active_scene as DungeonRun
	_check(run != null, "Existing campaign receives prepared inventory")
	if run == null: await _close(); return
	run.outcome = &"defeat"
	_check(flow.show_hub(true), "Existing defeat return creates a fresh starter")
	await _step(12)
	hub = flow.active_scene as ExteriorHub
	hub.npc_population.set_process(false)
	var new_inventory: GearInventory = hub.gear.inventory
	journal = (hub.gear.modal as InventoryScreen).journal
	_check(new_inventory.items[new_inventory.equipped_weapon_uid].enhancement_level == 0 and "+0 → +1" in _journal_row(journal,&"reward_collected")["guide"]["body"], "Death guidance reads new UID; old +9 is not resurrected")
	_check(OpeningProgress.IDS.all(func(id: StringName) -> bool: return _journal_row(journal,id)["done"]), "Death does not erase canonical opening milestones")
	var resident: Dictionary = hub.npc_population.state.records["pilot_gatherer"]
	resident["mode"] = "downed"; resident["hp"] = 0.0; resident["episode"] = 1
	_check(hub.npc_population.state.decide("pilot_gatherer",hub.npc_population.state.decision_token("pilot_gatherer"),true,true), "Explicit fixture death is durably committed by NPC life owner")
	journal.refresh()
	_check("tùy chọn" in _journal_row(journal,&"first_upgrade")["guide"]["body"] and _journal_row(journal,&"first_upgrade")["guide"]["status"] == "blocked", "Dead optional NPC creates no player cultivation gate")
	_sample("dead_npc_after_player_defeat",flow.profile,new_inventory)
	_check(hub.open_npc(NpcCatalog.HEALER), "Safe Hub healer services remain reachable after pilot death")
	hub.dialogue.close()
	_check(hub.open_npc(NpcCatalog.SMITH), "Safe Hub smith services remain reachable after pilot death")
	hub.dialogue.close()
	var path: String = flow.profile.save_path
	await _close()
	hub = await _open(path)
	_check(hub.npc_population.state.records["pilot_gatherer"]["mode"] == "dead", "Cold reload preserves NPC terminal life state")
	journal = (hub.gear.modal as InventoryScreen).journal
	_check(journal.rows.size() == 7 and "+0 → +1" in _journal_row(journal,&"reward_collected")["guide"]["body"] and _journal_row(journal,&"explored")["done"], "Cold reload replays canonical old quests and derived follow-up against fresh current gear")
	await _close()
	_check(not old_inventory.changed.get_connections().any(func(connection: Dictionary) -> bool: return (connection["callable"] as Callable).get_object_id() == old_journal_id), "Deleted journal leaves no stale callback for its exact instance ID")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/") or DisplayServer.get_name() != "headless":
		print("FAIL: Requires isolated user:// and headless editor"); quit(2); return
	directory = "user://verification/opening_guide_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	AudioServer.set_bus_mute(0,true)
	_pure_contracts()
	await _product_replay_and_death()
	DirAccess.make_dir_recursive_absolute("res://docs/verification/opening_guidance")
	var file := FileAccess.open("res://docs/verification/opening_guidance/vn_copy_%d.json" % Engine.physics_ticks_per_second,FileAccess.WRITE)
	_check(file != null, "Vietnamese copy snapshots export only inside the owned QA output")
	if file != null: file.store_string(JSON.stringify(examples,"\t")); file.close()
	print("RESULT OpeningProgressionGuide checks=%d failures=%d hz=%d user_data=%s" % [checks,failures,Engine.physics_ticks_per_second,OS.get_user_data_dir()])
	quit(0 if failures == 0 else 1)

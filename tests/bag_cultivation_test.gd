extends SceneTree
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
class FaultProfile extends SanctuaryProfile:
	var fail_next: bool = false
	func _open_writer(path: String) -> FileAccess:
		if fail_next:
			fail_next = false
			return null
		return super._open_writer(path)

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func _profile(label: String) -> FaultProfile:
	var profile := FaultProfile.new()
	profile.save_path = "user://verification/bag_cult_%s_%d.json" % [label, Time.get_ticks_usec()]
	_check(profile.save(), "Initialize isolated profile " + label)
	return profile

func _event(profile: SanctuaryProfile, bag: GearInventory, kind: String, args: Dictionary, branch: String = "") -> bool:
	var carried: GearInventory = bag if kind in ["train", "breakthrough", "craft_pill"] else null
	var proposal: Dictionary = Model.propose(profile.cultivation_progress, profile.cultivation_materials(carried), profile.souls, profile.boss_proofs, kind, args, "cult_%d" % profile.cultivation_progress["next_event"])
	return proposal.get("ok", false) and profile.commit_cultivation(proposal, {}, Callable(), branch, carried)

func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\", "/").begins_with(qa + "/"):
		print("FAIL: isolated QA root required")
		quit(2)
		return
	_test_material_provenance()
	_test_service_costs()
	_test_new_curriculum()
	_test_legacy_migration()
	print("RESULT bag_cultivation checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_material_provenance() -> void:
	var bag := GearInventory.new()
	bag.materials[&"dust"] = 10
	bag.begin_expedition()
	_check(bag.spend_material(&"dust", 10), "Spend starting materials")
	_check(bag.add_material(&"dust", 10), "Pick up replacements later")
	_check(bag.defeat_materials()[&"dust"] == 0, "Death does not resurrect spent starting materials from later pickups")
	bag = GearInventory.new()
	bag.materials[&"dust"] = 10
	bag.begin_expedition()
	bag.add_material(&"dust", 5)
	bag.spend_material(&"dust", 7)
	_check(bag.defeat_materials()[&"dust"] == 8, "Newly picked materials are consumed first; only remaining original materials survive")
	bag.add_material(&"metal", 6)
	_check(bag.defeat_materials()[&"metal"] == 0, "Entirely new material type is lost on defeat")
	var clone: GearInventory = HubPreparation.clone_inventory(bag)
	_check(clone.expedition_active and clone.defeat_materials() == bag.defeat_materials(), "Disposable scene clone preserves expedition material provenance")
	clone.spend_material(&"dust", 1)
	_check(bag.defeat_materials()[&"dust"] == 8 and clone.defeat_materials()[&"dust"] == 7, "Clone has an independent protected ledger")
	var copied := GearInventory.new()
	GearInventoryCodec.copy_into(copied, clone)
	_check(copied.expedition_active and copied.defeat_materials() == clone.defeat_materials(), "Transaction copy preserves runtime provenance")
	HubPreparation.clear_carried(copied)
	_check(not copied.expedition_active and copied.protected_materials.is_empty(), "Ownership transfer clears provenance from emptied source")
	var a: GearItem = bag.add_equipment(GearInventory.COMMON_SWORD, GearItem.Quality.COMMON)
	var b: GearItem = bag.add_equipment(GearInventory.COMMON_SWORD, GearItem.Quality.RARE)
	bag.equip_equipment(a.uid)
	var before: Array = bag.items.keys()
	for mode: int in [0, 1, 2]:
		bag.sort_equipment(mode)
		_check(bag.items.keys() == before and bag.equipped_weapon_uid == a.uid and bag.equipment_grid_uids().has(b.uid), "Sort only changes layout, keeps UID and equipment")
	var encoded: Dictionary = GearInventoryCodec.encode(bag)
	var restored: GearInventory = GearInventoryCodec.decode(JSON.parse_string(JSON.stringify(encoded)))
	_check(restored != null and restored.equipment_grid_uids() == bag.equipment_grid_uids(), "Sorted layout survives serialized round trip")
	var legacy: Dictionary = encoded.duplicate(true)
	legacy.erase("equipment_positions")
	legacy.erase("positions")
	_check(GearInventoryCodec.decode(legacy) != null, "Legacy inventory without layout remains readable")
	var pc_layout: Dictionary = encoded.duplicate(true)
	pc_layout["positions"] = pc_layout["equipment_positions"]
	pc_layout.erase("equipment_positions")
	var pc_restored: GearInventory = GearInventoryCodec.decode(JSON.parse_string(JSON.stringify(pc_layout)))
	_check(pc_restored != null and pc_restored.equipment_grid_uids() == bag.equipment_grid_uids(), "PC legacy positions alias reads the same layout as Mac canonical field")
	_check(GearInventoryCodec.encode(pc_restored).has("equipment_positions") and not GearInventoryCodec.encode(pc_restored).has("positions"), "Next safe save converges to one canonical layout field")
	for invalid: Array in [[b.uid, b.uid], [a.uid], [2147483647], [-1], [0.5]]:
		var malformed: Dictionary = encoded.duplicate(true)
		malformed["positions"] = invalid
		_check(not GearInventoryCodec.valid(malformed), "Reject duplicate, equipped, unknown or invalid layout UIDs: " + str(invalid))
	var profile: FaultProfile = _profile("layout")
	profile.hub_inventory = encoded
	_check(profile.save(), "Save sorted inventory through profile owner")
	var cold := SanctuaryProfile.new()
	cold.save_path = profile.save_path
	_check(cold.load_profile() and GearInventoryCodec.decode(cold.hub_inventory).equipment_grid_uids() == bag.equipment_grid_uids(), "Cold profile load preserves sorted equipment layout")

func _test_service_costs() -> void:
	var profile: FaultProfile = _profile("services")
	var bag: GearInventory = HubPreparation.starter_inventory()
	var owner := EconomySession.new()
	owner.initialize(profile, bag)
	owner.persist_safe_inventory = true
	profile.coins = 100
	profile.material_stash[&"enhancement_stone_1"] = 9
	_check(not owner.quote_enhance(bag.equipped_weapon_uid)["can_enhance"], "Storage alone no longer pays for enhancement")
	bag.materials[&"enhancement_stone_1"] = 2
	_check(owner._save_safe(), "Persist carried and stored fixture separately")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(profile.save_path)
	profile.fail_next = true
	_check(not owner.enhance_item(bag.equipped_weapon_uid), "Failed writer rejects enhancement")
	_check(bag.materials[&"enhancement_stone_1"] == 2 and profile.coins == 100 and bag.items[bag.equipped_weapon_uid].enhancement_level == 0 and FileAccess.get_file_as_bytes(profile.save_path) == bytes, "Enhancement save failure rolls back bag, money, item and disk")
	_check(owner.enhance_item(bag.equipped_weapon_uid), "Enhance directly from bag")
	_check(bag.materials[&"enhancement_stone_1"] == 1 and profile.material_stash[&"enhancement_stone_1"] == 9, "Enhancement never silently consumes chest resources")
	for mode: int in [0, 1, 2]:
		var layout: Array[int] = bag.equipment_positions.duplicate()
		bytes = FileAccess.get_file_as_bytes(profile.save_path)
		profile.fail_next = true
		_check(not owner.sort_bag(mode) and bag.equipment_positions == layout and FileAccess.get_file_as_bytes(profile.save_path) == bytes, "Each PC sort mode retains Mac writer rollback semantics")
		_check(owner.sort_bag(mode), "Each PC sort mode commits through the safe owner")
	bag.materials[&"crystal"] = 5
	owner._save_safe()
	bytes = FileAccess.get_file_as_bytes(profile.save_path)
	var coins: int = profile.coins
	profile.fail_next = true
	_check(not owner.sell_bag_material(&"crystal", 5), "All-of-type sale propagates writer failure")
	_check(bag.materials[&"crystal"] == 5 and profile.coins == coins and FileAccess.get_file_as_bytes(profile.save_path) == bytes, "Failed sale keeps every item and exact saved bytes")

func _test_new_curriculum() -> void:
	var profile: FaultProfile = _profile("new")
	var bag: GearInventory = HubPreparation.starter_inventory()
	bag.materials[&"crystal"] = 2
	bag.materials[&"dust"] = 1
	profile.material_stash[&"dust"] = 17
	profile.material_stash[&"crystal"] = 19
	_check(profile.commit_cultivation(Model.initial_proposal(Model.new_progress(43), profile.material_stash, 0, profile.boss_proofs)), "Initialize new curriculum through sealed owner")
	for index: int in 4: _check(_event(profile, bag, "mastery", {}), "Record legitimate mastery proposal %d" % index)
	for tick: int in [8, 16]: _check(_event(profile, bag, "train", {"actor_id":"player", "sessions":1, "target_tick":tick}), "Two short training sessions use carried crystals")
	for id: String in ["thanh_vy_met", "explored"]: _check(_event(profile, bag, "observe", {"insight_id":id}), "Record accessible opening insight " + id)
	for stage: int in 2: _check(_event(profile, bag, "breakthrough", {"actor_id":"player"}), "Advance interim stage %d without extra material grind" % stage)
	var before: Dictionary = profile.cultivation_progress.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(profile.save_path)
	profile.fail_next = true
	_check(not _event(profile, bag, "breakthrough", {"actor_id":"player"}, "cloud_return"), "Final breakthrough rejects failed save")
	_check(profile.cultivation_progress == before and bag.materials[&"dust"] == 1 and profile.cultivation_abilities()["selected_id"] == "" and FileAccess.get_file_as_bytes(profile.save_path) == bytes, "Failed breakthrough rolls back stage, branch, bag and disk together")
	_check(_event(profile, bag, "breakthrough", {"actor_id":"player"}, "cloud_return"), "Reach Truc Co with two crystals, one dust, no Souls or boss proof")
	_check(profile.cultivation_progress["actors"]["player"]["stage"] == 3 and bag.materials[&"dust"] == 0 and bag.materials[&"crystal"] == 0 and profile.material_stash[&"dust"] == 17 and profile.material_stash[&"crystal"] == 19, "Only carried ingredients spent; storage remains exact")
	var loaded := SanctuaryProfile.new()
	loaded.save_path = profile.save_path
	_check(loaded.load_profile() and loaded.cultivation_abilities()["selected_id"] == "cloud_return", "Cold load preserves stage and chosen skill")
	var restored: GearInventory = GearInventoryCodec.decode(loaded.hub_inventory)
	_check(restored != null and restored.materials[&"dust"] == 0 and restored.equipped_weapon_uid == bag.equipped_weapon_uid, "Cold load preserves the same carried inventory ledger")

func _test_legacy_migration() -> void:
	var profile: FaultProfile = _profile("legacy")
	var old: Dictionary = Model.new_progress(43)
	old["config"].merge({"energy_thresholds":[12,24,40], "mastery_thresholds":[2,5,8], "insight_thresholds":[1,2,3], "interim_dust_cost":1, "final_dust_cost":2, "final_soul_cost":5, "final_golem_proof":1}, true)
	_check(profile.commit_cultivation(Model.initial_proposal(old, profile.material_stash, 0, profile.boss_proofs)), "Initialize legacy curriculum fixture")
	var original: PackedByteArray = FileAccess.get_file_as_bytes(profile.save_path)
	profile.fail_next = true
	_check(not profile.ease_opening_cultivation(), "Tuning migration propagates writer failure")
	_check(profile.cultivation_progress["config"]["energy_thresholds"] == [12,24,40] and FileAccess.get_file_as_bytes(profile.save_path) == original, "Failed migration restores exact legacy state and file")
	_check(profile.ease_opening_cultivation(), "Retry migrates existing player instead of changing defaults only")
	var backup: String = str(profile.last_commit.get("cultivation_backup_path", ""))
	_check(not backup.is_empty() and FileAccess.get_file_as_bytes(backup) == original, "Migration preimage is byte exact and immutable")
	_check(profile.cultivation_progress["actors"] == old["actors"] and profile.cultivation_progress["receipts"] == old["receipts"], "Tuning does not reset earned progress or duplicate receipts")
	_check(profile.ease_opening_cultivation(), "Repeated migration is idempotent")

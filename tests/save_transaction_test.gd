extends SceneTree
## Faults at native I/O boundaries must not publish or charge failed purchases.

class FaultProfile extends SanctuaryProfile:
	var failure_stage: StringName = &""
	var failures_left: int = 0

	func fail_once(stage: StringName) -> void:
		failure_stage = stage
		failures_left = 1

	func _open_writer(path: String) -> FileAccess:
		if failure_stage == &"write" and failures_left > 0:
			failures_left -= 1
			return null
		return super._open_writer(path)

	func _copy_file(from_path: String, to_path: String) -> Error:
		if failure_stage == &"backup_copy" and failures_left > 0:
			failures_left -= 1
			return ERR_CANT_CREATE
		return super._copy_file(from_path, to_path)

	func _rename_file(from_path: String, to_path: String) -> Error:
		var matches: bool = (failure_stage == &"commit" and from_path == save_path + ".tmp" and to_path == save_path) or (failure_stage == &"backup_commit" and from_path == save_path + ".bak.tmp" and to_path == save_path + ".bak")
		if matches and failures_left > 0:
			failures_left -= 1
			return ERR_CANT_CREATE
		return super._rename_file(from_path, to_path)

var checks: int = 0
var failures: int = 0
var changed_count: int = 0
var profile: FaultProfile
var test_directory: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	print("SAVE TRANSACTION TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	test_directory = "user://verification/save_transactions_%d_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec(), Engine.physics_ticks_per_second]
	profile = FaultProfile.new()
	profile.save_path = test_directory + "/profile.json"
	profile.souls = 200
	profile.discovered_recipes.append(&"firestorm")
	profile.changed.connect(_on_changed)
	_check(profile.save() and profile.save() and changed_count == 0, "Fixture writes a main save and good backup without announcing a gameplay transaction")
	var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(profile.save_path)
	var stages: Array[StringName] = [&"write", &"backup_copy", &"backup_commit", &"commit"]
	for stage: StringName in stages:
		profile.fail_once(stage)
		_check(not profile.spend(15) and not profile.last_save_ok and profile.souls == 200, "Failed %s spending returns false and restores the Soul balance" % stage)
		_check(changed_count == 0 and FileAccess.get_file_as_bytes(profile.save_path) == original_bytes, "Failed %s spending publishes no success and leaves main progress intact" % stage)
		profile.fail_once(stage)
		_check(not profile.unlock_weapon(&"blade_fan") and not profile.last_save_ok and profile.souls == 200 and not profile.unlocked_weapons.has(&"blade_fan"), "Failed %s unlock rolls back both payment and granted weapon" % stage)
		_check(changed_count == 0 and _disk_souls(profile.save_path) == 200, "Failed %s unlock does not persist a phantom purchase" % stage)
		profile.fail_once(stage)
		_check(not profile.archive(&"firestorm") and not profile.last_save_ok and profile.souls == 200 and not profile.archived_recipes.has(&"firestorm"), "Failed %s archive rolls back payment and knowledge together" % stage)
		_check(changed_count == 0 and _disk_souls(profile.save_path) == 200, "Failed %s archive cannot emit changed or lower persistent Souls" % stage)
	_check(profile.spend(15) and profile.souls == 185 and changed_count == 1 and _disk_souls(profile.save_path) == 185, "Successful spend commits once, then publishes the committed balance")
	_check(profile.unlock_weapon(&"blade_fan") and profile.souls == 135 and changed_count == 2, "Successful retry grants one weapon and charges its original fifty-Soul price")
	_check(not profile.unlock_weapon(&"blade_fan") and profile.souls == 135 and profile.unlocked_weapons.count(&"blade_fan") == 1 and changed_count == 2, "Repeated weapon purchase cannot charge or grant again")
	_check(profile.archive(&"firestorm") and profile.souls == 130 and changed_count == 3, "Successful archive retry retains its original five-Soul price")
	_check(not profile.archive(&"firestorm") and profile.souls == 130 and profile.archived_recipes.count(&"firestorm") == 1 and changed_count == 3, "Repeated archive purchase cannot duplicate knowledge or consume Souls")
	profile.fail_once(&"commit")
	profile.add_souls(25)
	_check(profile.souls == 130 and not profile.last_save_ok and changed_count == 3 and _disk_souls(profile.save_path) == 130, "A failed Soul award does not claim persistent progress or emit a misleading change")
	profile.add_souls(25)
	_check(profile.souls == 155 and profile.last_save_ok and changed_count == 4 and _disk_souls(profile.save_path) == 155, "An award retry commits its original amount without a doubled failed award")
	profile.fail_once(&"commit")
	profile.discover(&"overload")
	_check(not profile.discovered_recipes.has(&"overload") and not profile.last_save_ok and changed_count == 4, "Failed discovery does not create temporary permanent knowledge")
	profile.fail_once(&"commit")
	_check(not profile.set_style(&"chaotic") and profile.style == &"balanced" and changed_count == 4, "Failed storyteller setting restores the previous style")
	var loaded := SanctuaryProfile.new()
	loaded.save_path = profile.save_path
	_check(loaded.load_profile() and loaded.souls == 155 and loaded.unlocked_weapons.count(&"blade_fan") == 1 and loaded.archived_recipes.count(&"firestorm") == 1 and not loaded.discovered_recipes.has(&"overload") and loaded.style == &"balanced", "A new process view contains only successful transactions")
	var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile.save_path))
	_check(stored is Dictionary and stored.get("version", 0) == 1 and stored.size() == 7 and not stored.has("items") and not stored.has("hp") and not stored.has("cooldowns"), "Existing schema contains permanent fields only, without run state or a new progression schema")
	_check(not profile.set_starting_weapon(&"unknown") and profile.starting_weapon == &"ancient_sword" and changed_count == 4, "Unknown starting weapons cannot mutate or publish profile state")
	_check(not profile.set_starting_weapon(&"ritual_staff") and profile.starting_weapon == &"ancient_sword" and changed_count == 4, "Known but locked weapons cannot be selected or silently unlocked")
	for stage: StringName in stages:
		profile.fail_once(stage)
		_check(not profile.set_starting_weapon(&"blade_fan") and not profile.last_save_ok and profile.starting_weapon == &"ancient_sword" and changed_count == 4, "Failed %s starting-weapon selection restores the previous choice without announcing success" % stage)
		var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile.save_path))
		_check(disk is Dictionary and disk.get("starting_weapon", "") == "ancient_sword" and _disk_souls(profile.save_path) == 155 and profile.unlocked_weapons.count(&"blade_fan") == 1, "Failed %s selection preserves the stored choice, Soul balance and unlock list" % stage)
	_check(profile.set_starting_weapon(&"blade_fan") and profile.starting_weapon == &"blade_fan" and profile.last_save_ok and profile.souls == 155 and changed_count == 5, "Successful starting-weapon retry commits the existing unlocked ID without charging Souls")
	_check(profile.set_starting_weapon(&"blade_fan") and changed_count == 5 and profile.souls == 155 and profile.unlocked_weapons.count(&"blade_fan") == 1, "Selecting the same start again creates no duplicate unlock, payment or change signal")
	_check(loaded.load_profile() and loaded.starting_weapon == &"blade_fan" and loaded.souls == 155 and loaded.unlocked_weapons.count(&"blade_fan") == 1 and loaded.archived_recipes.count(&"firestorm") == 1, "Starting-weapon selection survives reload without denormalizing other progress")
	_check(profile.save(), "A validated latest main becomes the recovery backup")
	var backup_bytes: PackedByteArray = FileAccess.get_file_as_bytes(profile.save_path + ".bak")
	_write_text(profile.save_path, "{\"version\":1,\"souls\":\"broken\",\"weapons\":42}")
	var corrupt_bytes: PackedByteArray = FileAccess.get_file_as_bytes(profile.save_path)
	_check(profile.load_profile() and profile.souls == 155, "Corrupted main data recovers the last validated backup")
	profile.fail_once(&"commit")
	_check(not profile.spend(15) and profile.souls == 155 and not profile.last_save_ok, "A transaction after recovery still rolls back when final commit fails")
	_check(FileAccess.get_file_as_bytes(profile.save_path) == corrupt_bytes and FileAccess.get_file_as_bytes(profile.save_path + ".bak") == backup_bytes and changed_count == 5, "Failed recovery commit restores the old main and never poisons the good backup")
	_check(profile.save() and FileAccess.get_file_as_bytes(profile.save_path + ".bak") == backup_bytes and _disk_souls(profile.save_path) == 155, "Successful repair preserves the good backup instead of rotating corrupted data into it")
	var clean := SanctuaryProfile.new()
	clean.save_path = profile.save_path
	_check(clean.load_profile() and clean.souls == 155 and clean.unlocked_weapons.count(&"blade_fan") == 1 and clean.archived_recipes.count(&"firestorm") == 1, "Reload after repair cannot duplicate unlocks, archive entries or Souls")
	var future_text: String = JSON.stringify({"version": 2, "souls": 900, "weapons": ["ancient_sword", "shadow_dagger"]})
	_write_text(profile.save_path, future_text)
	_check(not profile.load_profile() and profile.souls == 155, "Unsupported future schema is rejected without mutating the live profile")
	_check(not profile.spend(15) and not profile.last_save_ok and profile.souls == 155 and FileAccess.get_file_as_string(profile.save_path) == future_text and changed_count == 5, "An older build cannot overwrite a future save or claim a successful purchase")
	_write_text(profile.save_path, "{\"version\":1,\"souls\":77,\"weapons\":[\"ancient_sword\",\"blade_fan\",\"blade_fan\",\"unknown\"],\"discovered\":[\"firestorm\",\"firestorm\"],\"archive\":[\"firestorm\",\"firestorm\",\"overload\"]}")
	_check(clean.load_profile() and clean.souls == 77 and clean.unlocked_weapons.count(&"blade_fan") == 1 and not clean.unlocked_weapons.has(&"unknown") and clean.discovered_recipes.count(&"firestorm") == 1 and clean.archived_recipes.count(&"firestorm") == 1 and not clean.archived_recipes.has(&"overload"), "Recovery validation filters duplicate or unknown progress without granting extra equipment")
	clean = null
	loaded = null
	profile = null
	_cleanup_fixture()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _disk_souls(path: String) -> int:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return int(data.get("souls", -1)) if data is Dictionary else -1


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _cleanup_fixture() -> void:
	# Only exact files created in this run's unique user:// verification folder.
	var base: String = test_directory + "/profile.json"
	for suffix: String in ["", ".tmp", ".bak", ".bak.tmp", ".previous", ".bak.previous"]:
		if FileAccess.file_exists(base + suffix):
			DirAccess.remove_absolute(base + suffix)
	DirAccess.remove_absolute(test_directory)


func _on_changed() -> void:
	changed_count += 1


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

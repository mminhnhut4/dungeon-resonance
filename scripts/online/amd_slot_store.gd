class_name AmdSlotStore
extends RefCounted
## Account routing metadata only. ProfileCommitWriter remains the save owner.
var error: String = ""

static func isolated() -> bool:
	var root: String = OS.get_environment("AMD201_DATA_ROOT")
	if root == "": root = OS.get_environment("DUNGEON_QA_DATA_ROOT")
	if root == "": return false
	var absolute: String = ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	var expected: String = root.replace("\\", "/").trim_suffix("/").to_lower() + "/"
	return absolute.begins_with(expected)

static func valid_user(user: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$")
	return pattern.search(user) != null

static func new_id() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var value: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [value.substr(0,8),value.substr(8,4),value.substr(12,4),value.substr(16,4),value.substr(20,12)]

static func home(user: String) -> String:
	return "user://amd201/" + user if isolated() and valid_user(user) else ""

static func owns(user: String, path: String) -> bool:
	var prefix: String = home(user)
	return prefix != "" and path.begins_with(prefix + "/slots/") and not ".." in path and not "\\" in path and path.ends_with("/profile.json")

func create_slot(user: String) -> String:
	var parent: String = home(user)
	if parent == "": error = "isolated_launcher_required"; return ""
	var path: String = parent + "/slots/" + new_id() + "/profile.json"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK:
		error = "slot_directory_failed"; return ""
	return path

func read_active(user: String) -> Dictionary:
	var parent: String = home(user)
	if parent == "": error = "isolated_launcher_required"; return {}
	for suffix: String in ["/active.json", "/active.previous.json"]:
		var data: Variant = read_json(parent + suffix)
		if data is Dictionary and AmdCapsule.integer_in(data.get("version"),1,1) and owns(user, str(data.get("path", ""))) and AmdCapsule.integer_in(data.get("baseRevision"),0,9007199254740991):
			return data
	return {}

func activate(user: String, path: String, revision: int) -> bool:
	if not owns(user, path) or revision < 0: error = "invalid_slot"; return false
	var parent: String = home(user)
	var old: Dictionary = read_active(user)
	if not old.is_empty() and not write_json(parent + "/active.previous.json", old): return false
	return write_json(parent + "/active.json", {"version":1, "path":path, "baseRevision":revision})

func pending(user: String) -> Dictionary:
	var parent: String = home(user)
	if parent == "": return {}
	var data: Variant = read_json(parent + "/pending.json")
	return data if data is Dictionary and data.get("version") == 1 and valid_user(str(data.get("operation", ""))) and data.get("body") is Dictionary else {}

func set_pending(user: String, body: Dictionary) -> Dictionary:
	var data: Dictionary = {"version":1,"operation":new_id(),"body":body}
	if not write_json(home(user) + "/pending.json", data): return {}
	return data

func clear_pending(user: String) -> bool:
	var parent: String = home(user)
	if parent == "": error = "invalid_account"; return false
	var path: String = parent + "/pending.json"
	return not FileAccess.file_exists(path) or DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK

func write_json(path: String, data: Dictionary) -> bool:
	if not isolated() or not path.begins_with("user://amd201/") or ".." in path: error = "unsafe_metadata_path"; return false
	var text: String = JSON.stringify(data, "", true, true)
	var temp: String = path + ".tmp"
	var handle := FileAccess.open(temp, FileAccess.WRITE)
	if handle == null: error = "metadata_open_failed"; return false
	handle.store_string(text); handle.flush()
	var ok: bool = handle.get_error() == OK
	handle.close()
	if not ok or FileAccess.get_file_as_string(temp).sha256_text() != text.sha256_text(): error = "metadata_readback_failed"; return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path)) != OK:
		error = "metadata_replace_failed"; return false
	return true

static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null or handle.get_length() > 1200000: return null
	var text: String = handle.get_as_text(); handle.close()
	return JSON.parse_string(text)

class_name AmdCapsule
extends RefCounted
var error: String = ""
const BUILD: String = "amd201-20261030"
const MAX_BYTES: int = 1048576

static func safe_hub(flow: GameFlow) -> bool:
	return is_instance_valid(flow) and flow.active_scene is ExteriorHub and not flow.returning and not flow.return_save_pending and not flow.profile.read_only and not flow.profile.hub_inventory_quarantined and not flow.active_scene.outside and flow.active_scene.npc_population.talking_id == "" and not flow.get_tree().paused

func capture(flow: GameFlow, user: String) -> Dictionary:
	if not safe_hub(flow) or not AmdSlotStore.owns(user, flow.profile.save_path): error = "return_to_safe_hub"; return {}
	var state: NpcWorldState = flow.active_scene.npc_population.state
	if state.read_only or state.compound_locked: error = "npc_recovery_required"; return {}
	var previous: Dictionary = flow.profile.hub_inventory
	flow.profile.hub_inventory = GearInventoryCodec.encode(flow.active_scene.gear.inventory)
	if not flow.profile.save():
		flow.profile.hub_inventory = previous; error = "local_profile_write_failed"; return {}
	if not state.save(): error = "local_npc_write_failed"; return {}
	var path: String = flow.profile.save_path
	if _has_recovery(path): error = "local_recovery_pending"; return {}
	var files: Dictionary = {}
	for key: String in ["profile", "npc"]:
		var file_path: String = path + (NpcWorldState.NPC_SUFFIX if key == "npc" else "")
		var text: String = FileAccess.get_file_as_string(file_path)
		if text.is_empty() or text.to_utf8_buffer().size() > 524288: error = "local_file_invalid"; return {}
		files[key] = {"text":text,"sha256":text.sha256_text()}
	if _has_recovery(path): error = "local_recovery_pending"; return {}
	return {"schemaVersion":1,"gameBuild":BUILD,"profileSchema":int(flow.profile.profile_version),"files":files}

func stage(capsule: Dictionary, user: String, store: AmdSlotStore) -> String:
	# JSON.parse_string returns floats. Array membership is type-sensitive, so
	# [1,2].has(2.0) rejects a valid wire value. Validate the numeric domain first;
	# never coerce strings/bools/fractions into a supported schema.
	if not integer_in(capsule.get("schemaVersion"),1,1) or not integer_in(capsule.get("profileSchema"),1,2) or not capsule.get("files") is Dictionary:
		error = "unsupported_capsule"; return ""
	if not capsule.get("gameBuild") is String or capsule["gameBuild"].strip_edges().is_empty() or capsule["gameBuild"].length() > 128:
		error = "unsupported_capsule"; return ""
	var files: Dictionary = capsule["files"]
	if files.size() != 2 or not files.has("profile") or not files.has("npc"): error = "invalid_capsule_files"; return ""
	var bytes: int = 0
	for key: String in ["profile", "npc"]:
		if not files[key] is Dictionary or not files[key].get("text") is String or not files[key].get("sha256") is String: error = "invalid_capsule_file"; return ""
		var text: String = files[key]["text"]
		bytes += text.to_utf8_buffer().size()
		if bytes > MAX_BYTES or text.to_utf8_buffer().size() > 524288 or text.sha256_text() != files[key]["sha256"]:
			error = "capsule_digest_or_size"; return ""
	var profile_data: Variant = JSON.parse_string(files["profile"]["text"])
	if not profile_data is Dictionary or profile_data.get("version") != capsule["profileSchema"]: error = "profile_schema_mismatch"; return ""
	var npc_data: Variant = JSON.parse_string(files["npc"]["text"])
	if not NpcWorldState.valid(npc_data): error = "npc_schema_or_payload"; return ""
	var path: String = store.create_slot(user)
	if path == "": error = store.error; return ""
	for key: String in ["profile", "npc"]:
		var target: String = path + (NpcWorldState.NPC_SUFFIX if key == "npc" else "")
		var handle := FileAccess.open(target, FileAccess.WRITE)
		if handle == null: error = "stage_open_failed"; return ""
		handle.store_string(files[key]["text"]); handle.flush()
		var ok: bool = handle.get_error() == OK
		handle.close()
		if not ok or FileAccess.get_file_as_string(target).sha256_text() != files[key]["sha256"]: error = "stage_readback_failed"; return ""
	# Existing readers own seal/UID/schema validation; failure leaves active slot intact.
	var profile := SanctuaryProfile.new()
	profile.register_extension_validator(TanDangProgress.SCOPE,TanDangProgress.valid)
	profile.register_extension_validator(OpeningExplorationProgress.SCOPE,OpeningExplorationProgress.valid)
	profile.save_path = path
	var profile_ok: bool = profile.load_profile()
	if not profile_ok or profile.read_only or profile.hub_inventory_quarantined or profile.exterior_progress_quarantined or profile.opening_progress_quarantined:
		error = "profile_reader_rejected"; return ""
	var npc := NpcWorldState.new()
	npc.save_path = path + NpcWorldState.NPC_SUFFIX
	if not npc.load_state() or npc.read_only or _has_recovery(path): error = "npc_reader_rejected"; return ""
	# A seal rejection may return defaults without read_only: demand unchanged bytes.
	if FileAccess.get_file_as_string(path).sha256_text() != files["profile"]["sha256"] or profile.last_commit.get("status", "") == "recovered":
		error = "profile_not_exact"; return ""
	return path

static func integer_in(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum

static func _has_recovery(path: String) -> bool:
	for suffix: String in [".decision", ".decision.tmp", ".previous", ".npc_v1.json.compound.previous"]:
		if FileAccess.file_exists(path + suffix): return true
	return false

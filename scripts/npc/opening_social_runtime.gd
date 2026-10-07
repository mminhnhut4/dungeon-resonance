class_name OpeningSocialRuntime
extends RefCounted
## Trusted composition only: no life writes, new schema or second profile writer.
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
const Spans = preload("res://scripts/runtime/profile_json_spans.gd")
var profile: SanctuaryProfile
var migration_results: Dictionary = {}

func configure(permanent: SanctuaryProfile) -> bool:
	profile = permanent
	return profile.register_extension_validator("npc_social", NpcSocialProgress.valid) and profile.register_extension_validator("courier", CourierProgress.valid) and profile.register_social_fence_reader(_durable_reader)

func migrate_legacy() -> void:
	# Initialization may first promote format1 through the existing cultivation
	# transaction. Each old scope is then moved once, without paying its cost again.
	for scope: String in ["npc_social", "courier"]:
		var key: String = "npc_social_progress" if scope == "npc_social" else "courier_opportunity"
		var validator: Callable = NpcSocialProgress.valid if scope == "npc_social" else CourierProgress.valid
		if _legacy_unambiguous(scope, key):
			migration_results[scope] = profile.migrate_legacy_event_scope(scope, key, validator)
		else:
			migration_results[scope] = {"ok":false,"status":"extension_quarantined","error":"ambiguous_legacy_scope"}

func _legacy_unambiguous(scope: String, key: String) -> bool:
	if not FileAccess.file_exists(profile.save_path): return true
	var file: FileAccess = FileAccess.open(profile.save_path, FileAccess.READ)
	if file == null or file.get_length() > Writer.MAX_BYTES: return false
	var text: String = file.get_as_text(); file.close()
	var path: Array[String] = [key]
	var old: Dictionary = Spans.extract(text, path)
	var current_path: Array[String] = ["event_extensions", "namespaces", scope]
	var current: Dictionary = Spans.extract(text, current_path)
	return old.get("ok",false) and current.get("ok",false) and (not old.get("present",false) or Spans.unique_value(old["span"])) and (not current.get("present",false) or Spans.unique_value(current["span"]))

static func state(permanent: SanctuaryProfile) -> Dictionary:
	var current: Dictionary = permanent.extension_state("npc_social")
	return current if NpcSocialProgress.valid(current) else NpcSocialProgress.empty()

static func can_help(permanent: SanctuaryProfile, life: NpcWorldState, id: String) -> bool:
	return permanent != null and permanent.profile_version == 2 and permanent.social_transactions_available() and life != null and life.save_path == permanent.save_path + ".npc_v1.json" and id in NpcSocialCatalog.IDS and life.records.has(id) and not NpcSocialProgress.helped(state(permanent),id) and permanent.material_stash.get(NpcSocialCatalog.HELP_MATERIAL,0) >= NpcSocialCatalog.HELP_COST and life.records[id]["fear"] < 12 and not life.social_fence(id).is_empty()

static func help(permanent: SanctuaryProfile, life: NpcWorldState, id: String) -> bool:
	if not can_help(permanent,life,id): return false
	var raw_fence: Dictionary = life.social_fence(id)
	var fence: Dictionary = raw_fence.duplicate(true); fence["kind"] = "npc_social"
	var next: Dictionary = NpcSocialProgress.with_help(state(permanent),id,NpcWorldState.life_id(id))
	return permanent.commit_extension_event("npc_social",NpcSocialProgress.event_id(id,NpcWorldState.life_id(id)),{NpcSocialCatalog.HELP_MATERIAL:NpcSocialCatalog.HELP_COST},0,next,permanent.extension_revision("npc_social"),fence,life.social_fence_matches.bind(raw_fence)).get("ok",false)

func _durable_reader(fence: Dictionary) -> Dictionary:
	var refused: Dictionary = {"ok":false,"eligible":false,"unchanged":false}
	var id: String = str(fence.get("actor_id",""))
	if fence.size() != 6 or fence.get("kind") != "npc_social" or id not in NpcSocialCatalog.IDS or fence.get("life_id") != NpcWorldState.life_id(id): return refused
	var path: String = profile.save_path + ".npc_v1.json"
	if fence.get("npc_path") != path: return refused
	for field: String in ["live_fingerprint","durable_fingerprint"]:
		if not Writer._hash(fence.get(field)): return refused
	var file: FileAccess = FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 32768: return refused
	var text: String = file.get_as_text(); file.close()
	if not Spans.unique_value(text): return refused
	var payload: Variant = JSON.parse_string(text)
	if not NpcWorldState.valid(payload): return refused
	var record: Dictionary = payload["records"][id]
	var eligible: bool = record["death"].is_empty() and record["mode"] not in ["dead","downed","recovering","flee"] and record["hp"] >= 1
	return {"ok":true,"eligible":eligible,"unchanged":NpcWorldState._social_fingerprint(id,record) == fence["durable_fingerprint"]}

class_name SanctuaryProfile
extends RefCounted
## Only permanent progress is persisted. Run HP/items/cooldowns never enter save.

signal changed
var save_path: String = "user://sanctuary_v1.json"
var souls: int = 0
var coins: int = 0
var material_stash: Dictionary[StringName, int] = MaterialCatalog.empty_counts()
var unlocked_weapons: Array[StringName] = [&"ancient_sword", &"shadow_dagger"]
var discovered_recipes: Array[StringName] = []
var archived_recipes: Array[StringName] = []
var style: StringName = &"balanced"
var starting_weapon: StringName = &"ancient_sword"
var last_save_ok: bool = true
var permanent_upgrades: Dictionary[StringName, int] = WorldProgressionCatalog.empty_upgrades()
var learned_blueprints: Array[StringName] = []
var boss_proofs: Dictionary[StringName, int] = {&"golem": 0}
var boss_receipts: Array[String] = []
var bounty_accepted: bool = false
var bounty_claimed: bool = false
var bounty_start_proofs: int = 0
var hub_inventory: Dictionary = {}
var hub_inventory_quarantined: bool = false
var exterior_progress: Dictionary = ExteriorProgress.empty()
var exterior_progress_quarantined: bool = false
var opening_progress: Dictionary = OpeningProgress.empty()
var opening_progress_quarantined: bool = false
const CommitWriter = preload("res://scripts/runtime/profile_commit_writer.gd")
const CultivationState = preload("res://scripts/cultivation/opening_cultivation_state.gd")
var cultivation_progress: Dictionary = {}
var profile_version: int = 1
var read_only: bool = false
var last_commit: Dictionary = {}
var _writer: RefCounted
var _retained_fields: Dictionary = {}
var _retained_world_fields: Dictionary = {}
var _social_fence_reader: Callable
var _extension_validators: Dictionary = {}
const WEAPONS: Array[StringName] = [&"ancient_sword", &"shadow_dagger", &"blade_fan", &"ritual_staff", &"demon_greatsword", &"gale_dual_daggers", &"storm_arcane_staff", &"blood_spiked_whip"]
const RECIPES: Array[StringName] = [&"firestorm", &"overload", &"charged_slash", &"astral_firestorm", &"eclipse_blades", &"thermal_shock", &"superconduct", &"blizzard", &"combustion", &"frost_venom", &"miasma_cloud", &"neurotoxin"]


func add_souls(amount: int) -> void:
	if amount <= 0:
		return
	var previous: int = souls
	souls = mini(999999, souls + amount)
	if not save():
		souls = previous
		return
	changed.emit()


func try_add_souls(amount: int, opening_reward: bool = false) -> bool:
	if amount <= 0 or amount > MaterialCatalog.MAX_COUNT or souls > MaterialCatalog.MAX_COUNT - amount: return false
	var previous: Dictionary = opening_progress
	if opening_reward: opening_progress = OpeningProgress.with_event(opening_progress, &"reward_collected")
	souls += amount
	if not save():
		souls -= amount
		opening_progress = previous
		return false
	changed.emit()
	return true


func learn_blueprint(id: StringName) -> bool:
	if not WorldProgressionCatalog.valid_id(id) or learned_blueprints.has(id) or learned_blueprints.size() >= 256: return false
	learned_blueprints.append(id)
	if not save():
		learned_blueprints.erase(id)
		return false
	changed.emit()
	return true


func record_boss_defeat(receipt: String, id: StringName = &"golem") -> bool:
	if id != &"golem" or receipt.is_empty() or receipt.length() > 128 or boss_receipts.has(receipt) or boss_proofs[id] >= MaterialCatalog.MAX_COUNT: return false
	var previous: Array[String] = boss_receipts.duplicate()
	var previous_opening: Dictionary = opening_progress
	opening_progress = OpeningProgress.with_event(opening_progress, &"golem_defeated")
	boss_receipts.append(receipt)
	while boss_receipts.size() > WorldProgressionCatalog.MAX_RECEIPTS: boss_receipts.pop_front()
	boss_proofs[id] += 1
	if not save():
		boss_proofs[id] -= 1
		boss_receipts.assign(previous)
		opening_progress = previous_opening
		return false
	changed.emit()
	return true


func record_opening_event(id: StringName) -> bool:
	if id not in OpeningProgress.IDS: return false
	if opening_progress["completed"].has(String(id)): return true
	var previous: Dictionary = opening_progress
	opening_progress = OpeningProgress.with_event(opening_progress, id)
	if not save():
		opening_progress = previous
		return false
	changed.emit()
	return true


func opening_objectives() -> Dictionary:
	# UI receives a detached snapshot; never a mutable profile reference.
	return OpeningProgress.snapshot(opening_progress)


func spend(amount: int) -> bool:
	if amount < 0 or souls < amount:
		return false
	souls -= amount
	if not save():
		souls += amount
		return false
	changed.emit()
	return true


func unlock_weapon(id: StringName) -> bool:
	var cost: int = 50 if id == &"blade_fan" else 75 if id == &"ritual_staff" else -1
	if cost < 0 or unlocked_weapons.has(id) or souls < cost:
		return false
	souls -= cost
	unlocked_weapons.append(id)
	if not save():
		souls += cost
		unlocked_weapons.erase(id)
		return false
	changed.emit()
	return true


func discover(id: StringName) -> void:
	if RECIPES.has(id) and not discovered_recipes.has(id):
		discovered_recipes.append(id)
		if not save():
			discovered_recipes.erase(id)
			return
		changed.emit()


func archive(id: StringName) -> bool:
	if not discovered_recipes.has(id) or archived_recipes.has(id) or souls < 5:
		return false
	souls -= 5
	archived_recipes.append(id)
	if not save():
		souls += 5
		archived_recipes.erase(id)
		return false
	changed.emit()
	return true


func set_style(value: StringName) -> bool:
	if value not in [&"steady", &"balanced", &"chaotic"]:
		return false
	var previous: StringName = style
	style = value
	if not save():
		style = previous
		return false
	changed.emit()
	return true


func set_starting_weapon(id: StringName) -> bool:
	if not WEAPONS.has(id) or not unlocked_weapons.has(id):
		return false
	if starting_weapon == id:
		return true
	var previous: StringName = starting_weapon
	starting_weapon = id
	if not save():
		starting_weapon = previous
		return false
	changed.emit()
	return true


func _ensure_writer() -> bool:
	var canonical_path: String = save_path.simplify_path()
	if OS.get_name()=="Windows": canonical_path=canonical_path.to_lower()
	if _writer!=null and _writer.path==canonical_path:
		save_path=_writer.path
		return true
	_writer=CommitWriter.new()
	if not _writer.configure(self,save_path): return false
	save_path=_writer.path
	return true

func _export_payload() -> Dictionary:
	var payload: Dictionary = _retained_fields.duplicate(true)
	payload.merge({"version": profile_version, "souls": souls, "weapons": unlocked_weapons, "discovered": discovered_recipes, "archive": archived_recipes, "style": style, "starting_weapon": starting_weapon},true)
	# Optional version-one extension: old zero-economy saves keep their layout.
	# Only banked materials and sale proceeds persist, never the run inventory.
	if coins > 0 or material_stash.values().any(func(amount: int) -> bool: return amount > 0):
		payload["coins"] = coins
		payload["material_stash"] = material_stash
	if not _retained_world_fields.is_empty() or permanent_upgrades.values().any(func(level: int) -> bool: return level > 0) or not learned_blueprints.is_empty() or boss_proofs[&"golem"] > 0 or bounty_accepted or bounty_claimed or not hub_inventory.is_empty():
		payload["world_progress"] = _world_payload()
	if not hub_inventory.is_empty(): payload["hub_inventory"] = hub_inventory
	if ExteriorProgress.used(exterior_progress): payload["exterior_progress"] = exterior_progress
	if not opening_progress["completed"].is_empty(): payload["opening_progress"] = opening_progress
	if not cultivation_progress.is_empty():
		payload["version"]=2
		payload["cultivation_progress"]=cultivation_progress.duplicate(true)
		payload["material_stash"]=material_stash.duplicate()
	return payload

func save() -> bool:
	return _save_with_context()

func _save_with_context(fence: Dictionary = {}, guard: Callable = Callable()) -> bool:
	last_save_ok=false
	if read_only or not _ensure_writer():
		last_commit={"ok":false,"status":"rejected","error":"profile_read_only_or_invalid_path"}
		return false
	if not OpeningProgress.valid(opening_progress) or not ExteriorProgress.valid(exterior_progress) or not _valid_economy_fields({"coins":coins,"material_stash":material_stash}) or not _valid_world_fields(_world_payload()) or (not hub_inventory.is_empty() and not GearInventoryCodec.valid(hub_inventory)):
		last_commit={"ok":false,"status":"rejected","error":"invalid_live_profile"}
		return false
	last_commit=_writer.commit(_export_payload(),fence,guard)
	if not last_commit["ok"]:
		read_only=last_commit["status"]=="quarantined"
		return false
	last_save_ok=true
	return true

func compact_cultivation_receipts() -> bool:
	# Mandatory before the live session starts. Keep an immutable byte-exact
	# preimage, then use the same sealed writer/rollback protocol as every reward.
	last_save_ok=false
	if read_only or not _ensure_writer() or not CultivationState.valid(cultivation_progress,material_stash):
		return _compaction_failed("invalid_or_read_only_cultivation")
	if int(cultivation_progress["schema_version"]) == CultivationState.COMPACT_SCHEMA_VERSION:
		last_commit={"ok":true,"status":"already_compacted"}; last_save_ok=true
		return true
	var compacted: Dictionary = CultivationState.compact_progress(cultivation_progress,material_stash)
	if compacted.is_empty(): return _compaction_failed("legacy_event_sequence_requires_review")
	var original: PackedByteArray = FileAccess.get_file_as_bytes(save_path)
	var digest: String = original.hex_encode().sha256_text()
	if original.is_empty() or digest != _writer.expected_hash:
		return _compaction_failed("profile_changed_reload_required")
	var disk: Variant = _read_json(save_path)
	if not _validate_payload(disk,true) or CommitWriter.canonical(disk.get("cultivation_progress")) != CommitWriter.canonical(cultivation_progress):
		return _compaction_failed("compaction_source_invalid")
	var backup: String = save_path + ".cultivation_v1." + digest + ".bak"
	if FileAccess.file_exists(backup):
		if FileAccess.get_file_as_bytes(backup) != original: return _compaction_failed("compaction_backup_conflict")
	else:
		var staged_backup: String = backup + ".tmp"
		if _copy_file(save_path,staged_backup) != OK or FileAccess.get_file_as_bytes(staged_backup) != original:
			return _compaction_failed("compaction_backup_write_failed")
		if _rename_file(staged_backup,backup) != OK:
			return _compaction_failed("compaction_backup_publish_failed")
		if FileAccess.get_file_as_bytes(backup) != original: return _compaction_failed("compaction_backup_verify_failed")
	var previous: Dictionary = cultivation_progress
	cultivation_progress=compacted
	if not _save_with_context():
		cultivation_progress=previous
		return false
	last_commit["cultivation_backup_path"]=backup
	changed.emit()
	return true

func _compaction_failed(reason: String) -> bool:
	last_commit={"ok":false,"status":"rejected","error":reason}
	return false

func commit_cultivation(proposal: Dictionary, fence: Dictionary = {}, guard: Callable = Callable(), ability_choice: String = "") -> bool:
	if read_only or not proposal.get("ok",false): return false
	var gate: Dictionary = _cultivation_proposal_gate(proposal)
	if not gate.get("ok",false):
		last_commit={"ok":false,"status":"rejected","error":gate.get("error","invalid_proposal")}
		return false
	if gate.get("replay",false):
		if not ability_choice.is_empty() and cultivation_abilities().get("selected_id","")!=ability_choice:
			last_commit={"ok":false,"status":"rejected","error":"branch_replay_conflict"}; return false
		last_commit={"ok":true,"status":"already_committed"}
		return true
	if not FileAccess.file_exists(save_path) and not save(): return false
	var previous_extensions: Dictionary = _retained_fields.duplicate(true)
	var old_stage: int = int(cultivation_progress.get("actors",{}).get("player",{}).get("stage",0))
	var next_stage: int = int(proposal.get("progress",{}).get("actors",{}).get("player",{}).get("stage",0))
	if old_stage==2 and next_stage==3:
		if ability_choice not in ["cloud_return","tether_sigil"]:
			last_commit={"ok":false,"status":"rejected","error":"branch_choice_required"}; return false
		var extensions: Dictionary = _retained_fields.get("event_extensions",{"schema_version":1,"namespaces":{}}).duplicate(true)
		if not _valid_extensions(extensions) or extensions["namespaces"].has("abilities") or extensions["namespaces"].size()>=8:
			last_commit={"ok":false,"status":"rejected","error":"ability_scope_requires_review"}; return false
		var ability_state: Dictionary = {"version":1,"learned_ids":[ability_choice],"selected_id":ability_choice}
		var receipt: Dictionary = {"id":"truc_co_branch_v1","arguments_sha256":CommitWriter.canonical(ability_state).sha256_text(),"revision":1}
		extensions["namespaces"]["abilities"]={"revision":1,"state":ability_state,"receipts":[receipt]}
		_retained_fields["event_extensions"]=extensions
	elif not ability_choice.is_empty():
		last_commit={"ok":false,"status":"rejected","error":"branch_choice_only_at_truc_co"}; return false
	var previous: Dictionary = cultivation_progress
	var previous_materials: Dictionary[StringName,int] = material_stash.duplicate()
	var previous_souls: int = souls
	var previous_version: int = profile_version
	cultivation_progress=proposal["progress"].duplicate(true)
	for id: StringName in MaterialCatalog.IDS: material_stash[id]=int(proposal["materials"].get(id,0))
	souls=int(proposal["souls"]); profile_version=2
	if not _save_with_context(fence,guard):
		_retained_fields=previous_extensions
		cultivation_progress=previous; material_stash=previous_materials
		souls=previous_souls; profile_version=previous_version
		return false
	changed.emit()
	return true

func commit_cultivation_proposal(proposal: Dictionary, fence: Dictionary = {}, guard: Callable = Callable(), ability_choice: String = "") -> bool:
	return commit_cultivation(proposal,fence,guard,ability_choice)

func _cultivation_proposal_gate(proposal: Dictionary) -> Dictionary:
	if not _json_data(proposal) or not CultivationState._hex_digest(proposal.get("source_sha256")) or not proposal.get("event") is Dictionary or not proposal.get("request") is Dictionary: return {"ok":false,"error":"proposal_identity_required"}
	if not cultivation_progress.is_empty() and not CultivationState.valid(cultivation_progress,material_stash): return {"ok":false,"error":"invalid_live_cultivation"}
	var event: Dictionary = proposal["event"]
	if not CultivationState._keys(event,["id","kind","arguments_sha256"]) or not CultivationState._event_id(event.get("id")) or not CultivationState._hex_digest(event.get("arguments_sha256")) or event["arguments_sha256"]!=CommitWriter.canonical(CultivationState._normalize(proposal["request"])).sha256_text(): return {"ok":false,"error":"invalid_proposal_identity"}
	# A committed receipt is authoritative. Never publish its old snapshot.
	for receipt: Dictionary in cultivation_progress.get("receipts",[]):
		if receipt["id"]==event["id"]:
			return {"ok":true,"replay":true} if receipt["kind"]==event["kind"] and receipt["arguments_sha256"]==event["arguments_sha256"] else {"ok":false,"error":"event_conflict"}
	if proposal["source_sha256"]!=CultivationState.source_fingerprint(cultivation_progress,material_stash,souls,boss_proofs): return {"ok":false,"error":"stale_cultivation_source"}
	var expected: Dictionary
	if event["kind"]=="initialize":
		if profile_version!=1 or not cultivation_progress.is_empty() or not proposal.get("progress") is Dictionary: return {"ok":false,"error":"cultivation_already_initialized"}
		expected=CultivationState.initial_proposal(proposal["progress"],material_stash,souls,boss_proofs)
	else:
		expected=CultivationState.propose(cultivation_progress,material_stash,souls,boss_proofs,event["kind"],proposal["request"],event["id"])
	if not expected.get("ok",false) or expected.get("already_committed",false): return {"ok":false,"error":"invalid_uncommitted_proposal"}
	for key: String in ["progress","materials","souls","event","request","source_sha256"]:
		if CommitWriter.canonical(proposal.get(key))!=CommitWriter.canonical(expected[key]): return {"ok":false,"error":"proposal_snapshot_mismatch"}
	return {"ok":true,"replay":false}

func cultivation_abilities() -> Dictionary:
	var state: Dictionary = extension_state("abilities")
	if state.is_empty(): return {"version":1,"learned_ids":[],"selected_id":""}
	if state.size()!=3 or state.get("version")!=1 or not state.get("learned_ids") is Array or state["learned_ids"].size()!=1 or state.get("selected_id") not in ["cloud_return","tether_sigil"] or state["learned_ids"][0]!=state["selected_id"] or cultivation_progress.get("actors",{}).get("player",{}).get("stage",0)!=3: return {}
	return state

func courier_objectives() -> Dictionary:
	# Unmigrated/malformed legacy outcome remains opaque evidence. Only the
	# courier action is disabled; unrelated saves retain that evidence.
	if _retained_fields.has("courier_opportunity"): return {}
	var state: Dictionary = extension_state("courier")
	if state.is_empty(): state={"version":1,"accepted":false,"contact_recorded":false,"contact_source":"","outcome":""}
	return state if _valid_courier(state) else {}

static func _valid_courier(state: Dictionary) -> bool:
	return state.size()==5 and state.get("version")==1 and state.get("accepted") is bool and state.get("contact_recorded") is bool and state.get("contact_source") in ["","pilgrim","shrine"] and state.get("outcome") in ["","prepare","help"] and (state["contact_recorded"]==not str(state["contact_source"]).is_empty()) and (not state["contact_recorded"] or state["accepted"]) and (state["outcome"]=="" or state["contact_recorded"])

func record_courier_offer() -> bool:
	var state: Dictionary = courier_objectives()
	if state.is_empty(): return false
	if state["accepted"]: return true
	state["accepted"]=true
	return commit_extension_event("courier","courier_offer_v1",{},0,state,extension_revision("courier")).get("ok",false)

func accept_courier_opportunity() -> bool:
	return record_courier_offer()

func record_courier_contact(source: String) -> bool:
	var state: Dictionary = courier_objectives()
	if state.is_empty() or not state["accepted"] or source not in ["pilgrim","shrine"]: return false
	if state["contact_recorded"]: return true
	state["contact_recorded"]=true; state["contact_source"]=source
	return commit_extension_event("courier","courier_contact_v1",{},0,state,extension_revision("courier")).get("ok",false)

func quote_courier_choice(choice: StringName) -> Dictionary:
	var state: Dictionary = courier_objectives()
	var same: bool = not state.is_empty() and state["outcome"]==String(choice)
	var allowed: bool = not read_only and profile_version==2 and choice in [&"prepare",&"help"] and not state.is_empty() and state["accepted"] and state["contact_recorded"] and (same or (state["outcome"]=="" and material_stash[&"dust"]>=1))
	return {"available":allowed,"already_committed":same,"materials_cost":{&"dust":1} if choice==&"help" else {},"souls_cost":0,"tuning_status":"proposal_not_final","consequence":"Góp 1 Bột Phép cho trạm tiếp tế Thanh Vy · 0 Tàn Hồn / vải" if choice==&"help" else "Giữ 1 Bột Phép trong kho để tự chuẩn bị · Không tăng chỉ số tức thời"}

func commit_courier_choice(choice: StringName) -> bool:
	var quote: Dictionary = quote_courier_choice(choice)
	if not quote["available"]: return false
	var state: Dictionary = courier_objectives(); state["outcome"]=String(choice)
	return commit_extension_event("courier","opening_courier_supply_v1",quote["materials_cost"],0,state,extension_revision("courier")).get("ok",false)

func courier_choice_event() -> Dictionary:
	var state: Dictionary = courier_objectives()
	if state.is_empty() or state["outcome"]=="": return {}
	return {"receipt":"opening_courier_supply_v1","outcome":state["outcome"],"source_id":"pilot_pilgrim" if state["contact_source"]=="pilgrim" else "p03_shrine_register","recipient_id":"npc_healer"}

func extension_state(scope_id: String) -> Dictionary:
	if not extension_transactions_available(scope_id): return {}
	return _retained_fields.get("event_extensions",{}).get("namespaces",{}).get(scope_id,{}).get("state",{}).duplicate(true)

func register_extension_validator(scope_id: String, validator: Callable) -> bool:
	# Trusted composition supplies semantics; no saved content can select code.
	if not _extension_id(scope_id,32) or not validator.is_valid(): return false
	_extension_validators[scope_id]=validator
	return true

func extension_transactions_available(scope_id: String) -> bool:
	if read_only: return false
	var extensions: Variant = _retained_fields.get("event_extensions",{"schema_version":1,"namespaces":{}})
	if not _valid_extensions(extensions): return false
	if scope_id=="npc_social" and _retained_fields.has("npc_social_progress"): return false
	if not extensions["namespaces"].has(scope_id): return scope_id!="npc_social" or _extension_validators.has(scope_id)
	var entry: Variant = extensions["namespaces"][scope_id]
	if not _valid_extension_entry(entry): return false
	if scope_id=="npc_social" and not _extension_validators.has(scope_id): return false
	if scope_id=="npc_social" and FileAccess.file_exists(save_path):
		var raw: Dictionary = CommitWriter.JsonSpans.extract(FileAccess.get_file_as_string(save_path),CommitWriter._typed_path("npc_social"))
		if not raw.get("ok",false) or (raw.get("present",false) and not CommitWriter.JsonSpans.unique_value(raw["span"])): return false
	if _extension_validators.has(scope_id):
		var validator: Callable = _extension_validators[scope_id]
		return validator.call(entry["state"].duplicate(true))==true
	return true

func social_transactions_available() -> bool:
	return extension_transactions_available("npc_social")

func register_social_fence_reader(reader: Callable) -> bool:
	# Composition code supplies the reviewed life owner's cold reader before
	# load/recovery. No script path or callable is accepted from saved JSON.
	if not reader.is_valid(): return false
	_social_fence_reader=reader
	return true

func _read_social_fence(fence: Dictionary) -> Dictionary:
	if not _social_fence_reader.is_valid(): return {"ok":false}
	var result: Variant = _social_fence_reader.call(fence.duplicate(true))
	if not result is Dictionary or not result.get("ok") is bool or not result.get("eligible") is bool or not result.get("unchanged") is bool: return {"ok":false}
	return result

func extension_revision(scope_id: String) -> int:
	if not extension_transactions_available(scope_id): return -1
	return int(_retained_fields.get("event_extensions",{}).get("namespaces",{}).get(scope_id,{}).get("revision",0))

func migrate_legacy_event_scope(scope_id: String, legacy_key: String, validator: Callable) -> Dictionary:
	# Trusted composition supplies its data validator. Validation failure is a
	# subsystem quarantine, never a permission to drop unknown receipt data.
	if read_only or profile_version!=2 or not _extension_id(scope_id,32) or not _extension_id(legacy_key,64) or not validator.is_valid(): return {"ok":false,"status":"rejected","error":"migration_not_ready"}
	if not _retained_fields.has(legacy_key): return {"ok":true,"status":"already_migrated"}
	if scope_id=="npc_social":
		var text: String = FileAccess.get_file_as_string(save_path)
		var legacy_path: Array[String] = [legacy_key]
		var raw_legacy: Dictionary = CommitWriter.JsonSpans.extract(text,legacy_path)
		if not raw_legacy.get("ok",false) or not raw_legacy.get("present",false) or not CommitWriter.JsonSpans.unique_value(raw_legacy["span"]) or CommitWriter.canonical(CommitWriter.normalized(JSON.parse_string(raw_legacy["span"])))!=CommitWriter.canonical(_retained_fields[legacy_key]): return {"ok":false,"status":"extension_quarantined","error":"ambiguous_or_missing_legacy_social_span"}
		var raw_scope: Dictionary = CommitWriter.JsonSpans.extract(text,CommitWriter._typed_path("npc_social"))
		if not raw_scope.get("ok",false) or (raw_scope.get("present",false) and not CommitWriter.JsonSpans.unique_value(raw_scope["span"])): return {"ok":false,"status":"extension_quarantined","error":"ambiguous_social_namespace_span"}
		var live_extensions: Variant = _retained_fields.get("event_extensions",{"schema_version":1,"namespaces":{}})
		if not _valid_extensions(live_extensions): return {"ok":false,"status":"extension_quarantined","error":"invalid_extensions"}
		var live_scopes: Dictionary = live_extensions["namespaces"]
		if live_scopes.has(scope_id) and (not raw_scope.get("present",false) or CommitWriter.canonical(CommitWriter.normalized(JSON.parse_string(raw_scope["span"])))!=CommitWriter.canonical(live_scopes[scope_id])): return {"ok":false,"status":"extension_quarantined","error":"missing_or_changed_social_namespace_span"}
	if scope_id=="npc_social" and not _extension_validators.has(scope_id): register_extension_validator(scope_id,validator)
	var legacy: Variant = _retained_fields[legacy_key]
	if not legacy is Dictionary or not _json_data(legacy) or validator.call(legacy.duplicate(true))!=true: return {"ok":false,"status":"extension_quarantined","error":"malformed_or_future_legacy_extension"}
	var extensions: Dictionary = _retained_fields.get("event_extensions",{"schema_version":1,"namespaces":{}}).duplicate(true)
	if not _valid_extensions(extensions): return {"ok":false,"status":"extension_quarantined","error":"invalid_extensions"}
	if extensions["namespaces"].has(scope_id):
		if not _valid_extension_entry(extensions["namespaces"][scope_id]): return {"ok":false,"status":"extension_quarantined","error":"malformed_or_future_namespace"}
		if CommitWriter.canonical(extensions["namespaces"][scope_id]["state"])!=CommitWriter.canonical(legacy): return {"ok":false,"status":"extension_quarantined","error":"legacy_scope_conflict"}
	else:
		if extensions["namespaces"].size()>=8: return {"ok":false,"status":"rejected","error":"scope_capacity"}
		var receipt: Dictionary = {"id":"migration_legacy_"+scope_id+"_v1","arguments_sha256":CommitWriter.canonical([scope_id,legacy_key,legacy]).sha256_text(),"revision":1}
		extensions["namespaces"][scope_id]={"revision":1,"state":legacy.duplicate(true),"receipts":[receipt]}
	var previous: Dictionary = _retained_fields.duplicate(true)
	_retained_fields["event_extensions"]=extensions; _retained_fields.erase(legacy_key)
	if not _save_with_context():
		_retained_fields=previous
		return last_commit.duplicate(true)
	changed.emit()
	return {"ok":true,"status":"migrated"}

func commit_extension_event(scope_id: String, event_id: String, materials_cost: Dictionary, souls_cost: int, next_state: Dictionary, expected_revision: int = 0, fence: Dictionary = {}, guard: Callable = Callable()) -> Dictionary:
	# Social/sect/styles data share this owner. A receipt and its cost cannot split.
	if not extension_transactions_available(scope_id): return {"ok":false,"status":"extension_quarantined","error":"unsupported_or_corrupt_scope"}
	if _extension_validators.has(scope_id) and _extension_validators[scope_id].call(next_state.duplicate(true))!=true: return {"ok":false,"status":"extension_quarantined","error":"invalid_proposed_scope"}
	if scope_id=="npc_social" and (fence.get("kind")!="npc_social" or not guard.is_valid() or not _social_fence_reader.is_valid()): return {"ok":false,"status":"rejected","error":"social_life_fence_required"}
	if read_only or profile_version!=2 or not _extension_id(scope_id,32) or not _extension_id(event_id,128) or not _json_data(next_state) or CommitWriter.canonical(next_state).length()>16384 or not MaterialCatalog.valid_count(souls_cost): return {"ok":false,"status":"rejected","error":"invalid_event_or_profile_not_ready"}
	for id: Variant in materials_cost:
		if StringName(str(id)) not in MaterialCatalog.IDS or not MaterialCatalog.valid_count(materials_cost[id]): return {"ok":false,"status":"rejected","error":"invalid_cost"}
	var extensions: Dictionary = _retained_fields.get("event_extensions",{"schema_version":1,"namespaces":{}}).duplicate(true)
	if not _valid_extensions(extensions): return {"ok":false,"status":"quarantined","error":"invalid_extensions"}
	var current: Dictionary = extensions["namespaces"].get(scope_id,{"revision":0,"state":{},"receipts":[]})
	var args_hash: String = CommitWriter.canonical([scope_id,materials_cost,souls_cost,next_state]).sha256_text()
	for receipt: Dictionary in current["receipts"]:
		if receipt["id"]==event_id:
			return {"ok":true,"status":"already_committed","revision":receipt["revision"]} if receipt["arguments_sha256"]==args_hash else {"ok":false,"status":"rejected","error":"event_conflict"}
	if int(current["revision"])!=expected_revision or current["receipts"].size()>=256 or (not extensions["namespaces"].has(scope_id) and extensions["namespaces"].size()>=8): return {"ok":false,"status":"rejected","error":"revision_or_capacity"}
	if souls<souls_cost: return {"ok":false,"status":"rejected","error":"insufficient_souls"}
	for id: Variant in materials_cost:
		if material_stash.get(StringName(str(id)),0)<int(materials_cost[id]): return {"ok":false,"status":"rejected","error":"insufficient_materials"}
	var previous: Dictionary = _retained_fields.duplicate(true)
	var previous_bank: Dictionary[StringName,int] = material_stash.duplicate()
	var previous_souls: int = souls
	current=current.duplicate(true); current["revision"]+=1
	current["state"]=next_state.duplicate(true)
	current["receipts"].append({"id":event_id,"arguments_sha256":args_hash,"revision":current["revision"]})
	extensions["namespaces"][scope_id]=current
	_retained_fields["event_extensions"]=extensions
	for id: Variant in materials_cost: material_stash[StringName(str(id))]-=int(materials_cost[id])
	souls-=souls_cost
	if not _save_with_context(fence,guard):
		_retained_fields=previous; material_stash=previous_bank; souls=previous_souls
		return last_commit.duplicate(true)
	changed.emit()
	return {"ok":true,"status":"committed","revision":current["revision"]}

static func _extension_id(value: String, limit: int) -> bool:
	if value.is_empty() or value.length()>limit: return false
	for letter: String in value:
		if letter not in "abcdefghijklmnopqrstuvwxyz0123456789_:.-": return false
	return true

static func _json_data(value: Variant, level: int = 0) -> bool:
	if level>24: return false
	if value is Dictionary:
		for key: Variant in value:
			if not (key is String or key is StringName) or not _json_data(value[key],level+1): return false
		return true
	if value is Array:
		for child: Variant in value:
			if not _json_data(child,level+1): return false
		return true
	return value==null or value is bool or value is int or value is String or value is StringName or (value is float and is_finite(value))

static func _valid_extensions(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=2 or data.get("schema_version")!=1 or not data.get("namespaces") is Dictionary or data["namespaces"].size()>8: return false
	for scope_id: Variant in data["namespaces"]:
		if not scope_id is String or not _extension_id(scope_id,32): return false
		# Social is an opaque extension boundary, even when its own envelope is
		# unsupported. Enclosing namespaces/schema/profile remain strict.
		if scope_id=="npc_social":
			if not _json_data(data["namespaces"][scope_id]): return false
		elif not _valid_extension_entry(data["namespaces"][scope_id]): return false
	return true

static func _valid_extension_entry(entry: Variant) -> bool:
	if not entry is Dictionary or entry.size()!=3 or not MaterialCatalog.valid_count(entry.get("revision")) or not entry.get("state") is Dictionary or not _json_data(entry["state"]) or not entry.get("receipts") is Array or entry["receipts"].size()>256 or entry["revision"]!=entry["receipts"].size(): return false
	var seen: Dictionary = {}
	for index: int in entry["receipts"].size():
		var receipt: Variant = entry["receipts"][index]
		if not receipt is Dictionary or receipt.size()!=3 or not receipt.get("id") is String or not _extension_id(receipt["id"],128) or seen.has(receipt["id"]) or not CommitWriter._hash(receipt.get("arguments_sha256")) or receipt.get("revision")!=index+1: return false
		seen[receipt["id"]]=true
	return true

func _validate_payload(data: Variant, require_seal: bool = true) -> bool:
	if not data is Dictionary or data.get("version") not in [1,2] or not _json_data(data): return false
	for key: String in ["weapons","discovered","archive"]:
		if data.has(key) and not data[key] is Array: return false
	if data.has("souls") and (not (data["souls"] is int or data["souls"] is float) or not is_finite(float(data["souls"]))): return false
	if not _valid_economy_fields(data) or (data.has("world_progress") and (not data["world_progress"] is Dictionary or not _valid_world_fields(data["world_progress"]))): return false
	if data["version"]==1: return not data.has("cultivation_progress") and not data.has("profile_commit")
	if not MaterialCatalog.valid_count(data.get("souls")) or not data.get("material_stash") is Dictionary or not CultivationState.valid(data.get("cultivation_progress"),data["material_stash"]): return false
	if data.has("hub_inventory") and (not data["hub_inventory"] is Dictionary or not GearInventoryCodec.valid(data["hub_inventory"])): return false
	if data.has("opening_progress") and not OpeningProgress.valid(data["opening_progress"]): return false
	if data.has("exterior_progress") and not ExteriorProgress.valid(data["exterior_progress"]): return false
	if data.has("event_extensions") and not _valid_extensions(data["event_extensions"]): return false
	return not require_seal or CommitWriter.seal_valid(data)

func _save_legacy_payload(payload: Dictionary) -> bool:
	if not OpeningProgress.valid(opening_progress) or not ExteriorProgress.valid(exterior_progress) or not _valid_economy_fields({"coins": coins, "material_stash": material_stash}) or not _valid_world_fields(_world_payload()) or (not hub_inventory.is_empty() and not GearInventoryCodec.valid(hub_inventory)):
		last_save_ok = false
		return false
	# Never let an older build overwrite a save written by a newer schema.
	if _has_future_schema(_read_json(save_path)):
		last_save_ok = false
		return false
	var directory: String = save_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_save_ok = false
		return false
	var file: FileAccess = _open_writer(save_path + ".tmp")
	if file == null:
		last_save_ok = false
		return false
	var serialized: String = _writer.legacy_text(payload)
	if serialized.is_empty(): file.close(); return false
	file.store_string(serialized)
	file.flush()
	var write_ok: bool = file.get_error() == OK
	file.close()
	if not write_ok or not _is_supported_profile(_read(save_path + ".tmp")):
		last_save_ok = false
		return false
	var backup: String = save_path + ".bak"
	# Rotate only a validated main save. A corrupted main must not poison the
	# last good backup after load_profile has recovered progress from it.
	if _is_supported_profile(_read(save_path)):
		if _copy_file(save_path, backup + ".tmp") != OK or not _replace_file(backup + ".tmp", backup):
			last_save_ok = false
			return false
	last_save_ok = _replace_file(save_path + ".tmp", save_path)
	return last_save_ok


func load_profile() -> bool:
	if not _ensure_writer(): return false
	last_commit=_writer.recover()
	if not last_commit["ok"]:
		read_only=true
		return false
	var raw: Variant = _read_json(save_path)
	var data: Variant = _read(save_path)
	var recovered_backup: bool = false
	if _has_future_schema(raw) or (raw is Dictionary and raw.get("version")==2 and not _validate_payload(raw)):
		read_only=true
		return false
	if not _is_supported_profile(data):
		var backup: Variant = _read(save_path + ".bak")
		if FileAccess.file_exists(save_path+".format_v2") or (backup is Dictionary and (_has_future_schema(backup) or backup.get("version",0)==2)):
			read_only=true
			return false
		data=backup; recovered_backup=true
	if not _is_supported_profile(data):
		read_only=FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path+".bak")
		return false
	if not _validate_payload(data) or _has_future_schema(data):
		read_only=true
		return false
	read_only=false
	profile_version=int(data["version"])
	cultivation_progress=data.get("cultivation_progress",{}).duplicate(true)
	_retained_fields=data.duplicate(true)
	for key: String in ["version","souls","coins","material_stash","weapons","discovered","archive","style","starting_weapon","world_progress","hub_inventory","exterior_progress","opening_progress","cultivation_progress","profile_commit"]: _retained_fields.erase(key)
	_retained_world_fields=data.get("world_progress",{}).duplicate(true)
	for key: String in ["upgrades","blueprints","boss_proofs","boss_receipts","bounty_accepted","bounty_claimed","bounty_start_proofs"]: _retained_world_fields.erase(key)
	_writer.note_current()
	souls = clampi(int(data.get("souls", 0)), 0, 999999)
	coins = int(data.get("coins", 0))
	material_stash = MaterialCatalog.empty_counts()
	for id: StringName in MaterialCatalog.IDS:
		material_stash[id] = int(data.get("material_stash", {}).get(String(id), 0))
	_load_world_fields(data)
	opening_progress_quarantined = data.has("opening_progress") and not OpeningProgress.valid(data["opening_progress"])
	opening_progress = data["opening_progress"].duplicate(true) if data.has("opening_progress") and not opening_progress_quarantined else OpeningProgress.empty()
	# Quarantine malformed geographic data independently, preserving the valid
	# current UID ledger. Missing extension is an ordinary legacy v1 save.
	exterior_progress_quarantined = data.has("exterior_progress") and not ExteriorProgress.valid(data["exterior_progress"])
	exterior_progress = data["exterior_progress"].duplicate(true) if data.has("exterior_progress") and not exterior_progress_quarantined else ExteriorProgress.empty()
	# Backup is permanent-progress recovery only. Its wardrobe may predate an
	# already-launched run, so restoring those UIDs could duplicate carried gear.
	if recovered_backup and not hub_inventory.is_empty():
		hub_inventory = {}
		hub_inventory_quarantined = true
	unlocked_weapons.assign([&"ancient_sword", &"shadow_dagger"])
	for id: Variant in data.get("weapons", []):
		if (StringName(str(id)) in WEAPONS or (WorldProgressionCatalog.valid_id(id) and ResourceLoader.exists("res://data/weapons/%s.tres" % str(id)))) and not unlocked_weapons.has(StringName(str(id))):
			unlocked_weapons.append(StringName(str(id)))
	discovered_recipes.clear()
	archived_recipes.clear()
	for id: Variant in data.get("discovered", []):
		if StringName(str(id)) in RECIPES and not discovered_recipes.has(StringName(str(id))):
			discovered_recipes.append(StringName(str(id)))
	for id: Variant in data.get("archive", []):
		if discovered_recipes.has(StringName(str(id))) and not archived_recipes.has(StringName(str(id))):
			archived_recipes.append(StringName(str(id)))
	var saved_style: StringName = StringName(str(data.get("style", "balanced")))
	style = saved_style if saved_style in [&"steady", &"balanced", &"chaotic"] else &"balanced"
	var start: StringName = StringName(str(data.get("starting_weapon", "ancient_sword")))
	starting_weapon = start if unlocked_weapons.has(start) else &"ancient_sword"
	return true


func _read(path: String) -> Variant:
	var data: Variant = _read_json(path)
	if data is Dictionary:
		for key: String in ["weapons", "discovered", "archive"]:
			if data.has(key) and not data[key] is Array:
				return null
		if data.has("souls") and not (data.souls is int or data.souls is float):
			return null
		if data.has("souls") and not is_finite(float(data.souls)):
			return null
		if not _valid_economy_fields(data):
			return null
		if data.has("world_progress") and (not data["world_progress"] is Dictionary or not _valid_world_fields(data["world_progress"])): return null
	return data


func _valid_economy_fields(data: Dictionary) -> bool:
	if data.has("coins") and not MaterialCatalog.valid_count(data["coins"]):
		return false
	if not data.has("material_stash"):
		return true
	if not data["material_stash"] is Dictionary:
		return false
	for id: Variant in data["material_stash"]:
		if not (id is String or id is StringName) or StringName(str(id)) not in MaterialCatalog.IDS or not MaterialCatalog.valid_count(data["material_stash"][id]):
			return false
	return true


func _world_payload() -> Dictionary:
	var payload: Dictionary = _retained_world_fields.duplicate(true)
	payload.merge({"upgrades": permanent_upgrades, "blueprints": learned_blueprints, "boss_proofs": boss_proofs, "boss_receipts": boss_receipts, "bounty_accepted": bounty_accepted, "bounty_claimed": bounty_claimed, "bounty_start_proofs": bounty_start_proofs},true)
	return payload


func _valid_world_fields(data: Dictionary) -> bool:
	if not data.get("upgrades", {}) is Dictionary or not data.get("boss_proofs", {}) is Dictionary: return false
	for id: Variant in data.get("upgrades", {}):
		if StringName(str(id)) not in WorldProgressionCatalog.UPGRADES or not MaterialCatalog.valid_count(data["upgrades"][id]) or int(data["upgrades"][id]) > WorldProgressionCatalog.MAX_LEVELS[StringName(str(id))]: return false
	for id: Variant in data.get("boss_proofs", {}):
		if str(id) != "golem" or not MaterialCatalog.valid_count(data["boss_proofs"][id]): return false
	if not data.get("blueprints", []) is Array or data.get("blueprints", []).size() > 256 or not data.get("boss_receipts", []) is Array or data.get("boss_receipts", []).size() > WorldProgressionCatalog.MAX_RECEIPTS: return false
	var seen: Array[String] = []
	for id: Variant in data.get("blueprints", []):
		if not WorldProgressionCatalog.valid_id(id) or seen.has(str(id)): return false
		seen.append(str(id))
	seen.clear()
	for receipt: Variant in data.get("boss_receipts", []):
		if not receipt is String or receipt.is_empty() or receipt.length() > 128 or seen.has(receipt): return false
		seen.append(receipt)
	for key: String in ["bounty_accepted", "bounty_claimed"]:
		if data.has(key) and not data[key] is bool: return false
	return MaterialCatalog.valid_count(data.get("bounty_start_proofs", 0)) and (not data.get("bounty_claimed", false) or data.get("bounty_accepted", false))


func _load_world_fields(data: Dictionary) -> void:
	var progress: Dictionary = data.get("world_progress", {})
	permanent_upgrades = WorldProgressionCatalog.empty_upgrades()
	for id: StringName in WorldProgressionCatalog.UPGRADES: permanent_upgrades[id] = int(progress.get("upgrades", {}).get(String(id), 0))
	learned_blueprints.clear()
	for id: Variant in progress.get("blueprints", []): learned_blueprints.append(StringName(str(id)))
	boss_proofs = {&"golem": int(progress.get("boss_proofs", {}).get("golem", 0))}
	boss_receipts.assign(progress.get("boss_receipts", []))
	bounty_accepted = progress.get("bounty_accepted", false)
	bounty_claimed = progress.get("bounty_claimed", false)
	bounty_start_proofs = int(progress.get("bounty_start_proofs", 0))
	# Malformed wardrobe is quarantined independently; never restore a stale
	# backup item ledger which may already have moved into a disposable run.
	hub_inventory = data.get("hub_inventory", {}) if data.get("hub_inventory", {}) is Dictionary else {}
	hub_inventory_quarantined = data.has("hub_inventory") and (not data["hub_inventory"] is Dictionary or not GearInventoryCodec.valid(hub_inventory))
	if hub_inventory_quarantined: hub_inventory = {}


func _read_json(path: String) -> Variant:
	return CommitWriter.read_json(path)


func _is_supported_profile(data: Variant) -> bool:
	return _validate_payload(data)


func _has_future_schema(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var version: Variant = data.get("version", 0)
	if not (version is int or version is float) or not is_finite(float(version)): return true
	if float(version)>2.0 or (float(version)==2.0 and not data.has("cultivation_progress")): return true
	var cultivation: Variant = data.get("cultivation_progress")
	if cultivation is Dictionary:
		var schema: Variant = cultivation.get("schema_version")
		if not (schema is int or schema is float) or not is_finite(float(schema)) or float(schema)>float(CultivationState.COMPACT_SCHEMA_VERSION): return true
	return ExteriorProgress.future(data.get("exterior_progress",null)) or OpeningProgress.future(data.get("opening_progress", null))


func _replace_file(temporary: String, target: String) -> bool:
	# Preserve the existing target until the new file is committed. The backup
	# provides recovery across a process crash between the two native renames;
	# ordinary commit failure restores the target before the caller rolls back RAM.
	var previous: String = target + ".previous"
	var had_target: bool = FileAccess.file_exists(target)
	if had_target:
		if FileAccess.file_exists(previous) and _remove_file(previous) != OK:
			return false
		if _rename_file(target, previous) != OK:
			return false
	if _rename_file(temporary, target) != OK:
		if had_target:
			_rename_file(previous, target)
		return false
	if had_target:
		_remove_file(previous)
	return true


func _copy_file(from_path: String, to_path: String) -> Error:
	return DirAccess.copy_absolute(from_path, to_path)


func _open_writer(path: String) -> FileAccess:
	return FileAccess.open(path, FileAccess.WRITE)


func _rename_file(from_path: String, to_path: String) -> Error:
	return DirAccess.rename_absolute(from_path, to_path)


func _remove_file(path: String) -> Error:
	return DirAccess.remove_absolute(path)

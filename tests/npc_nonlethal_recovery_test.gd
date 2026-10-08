extends SceneTree
## Actual owner IO/migrations and DamageEvent, with a dedicated QA root only.
const RESIDENT: String = "pilot_traveler"
const CULTIVATOR: String = "thanh_van_disciple_01"

class CountedState extends NpcWorldState:
	var save_calls: int = 0
	func save() -> bool:
		save_calls += 1
		return super.save()

class FaultIo extends SanctuaryProfile:
	var main_path: String = ""
	var fail_stage: String = ""
	func _open_writer(path: String) -> FileAccess:
		return null if fail_stage == "open" else super._open_writer(path)
	func _copy_file(source: String, target: String) -> Error:
		if fail_stage == "immutable_copy" and target.ends_with(".pre_nonlethal_v2.json"): return ERR_CANT_CREATE
		return super._copy_file(source,target)
	func _replace_file(temporary: String, target: String) -> bool:
		if fail_stage == "backup" and target == main_path + ".bak": return false
		if fail_stage == "primary" and target == main_path: return false
		return super._replace_file(temporary,target)

var checks: int = 0
var failures: int = 0
var directory: String
var recovery_notifications: int = 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var actual: String = ProjectSettings.globalize_path("user://").replace("\\","/")
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not actual.begins_with(allowed + "/"):
		print("FAIL: Dedicated QA root is required before every NPC save fixture")
		quit(1)
		return
	directory = "user://verification/npc_nonlethal_%d_%d_%d" % [Engine.physics_ticks_per_second,OS.get_process_id(),Time.get_ticks_usec()]
	print("NPC_NONLETHAL_USER_DIR=" + actual)
	_policy()
	_recovery_transaction()
	_migration(1)
	_migration(2)
	_migration_faults()
	_immutable_backup_guards()
	_quarantine()
	_local_control()
	await _damage_pipeline()
	print("RESULT npc_nonlethal_recovery checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1
	print(("PASS: " if condition else "FAIL: ") + label)

func _fixture(label: String) -> CountedState:
	var state := CountedState.new()
	state.save_path = directory + "/" + label + "/profile.json.npc_v1.json"
	_check(state.load_state() and state.save(),label + ": clean schema4 owner commits through existing IO")
	return state

func _write(path: String, payload: Dictionary) -> bool:
	if not path.begins_with(directory + "/"): return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var stream := FileAccess.open(path,FileAccess.WRITE)
	if stream == null: return false
	stream.store_string(JSON.stringify(payload)); stream.flush()
	var success: bool = stream.get_error() == OK
	stream.close()
	return success

func _reader(path: String) -> CountedState:
	var state := CountedState.new()
	state.save_path = path
	return state

func _policy() -> void:
	var state: CountedState = _fixture("policy")
	_check(state.records.size() == 10 and NpcWorldState.valid(state.snapshot()),"Exactly six residents and four cultivators exist in schema4")
	var life: String = NpcWorldState.life_id(RESIDENT)
	var debt: int = state.records[RESIDENT]["debt"]
	state.receive_hit(RESIDENT,1.0,0.0)
	_check(state.records[RESIDENT]["mode"] == "recovering" and state.records[RESIDENT]["hp"] == 1.0,"Lethal incoming harm withdraws a living resident immediately")
	_check(state.records[RESIDENT]["death"].is_empty() and state.records[RESIDENT]["legacy_death"].is_empty(),"New harm creates neither terminal death nor fabricated history")
	_check(state.records[RESIDENT]["trust"] == -2 and state.records[RESIDENT]["fear"] == 6 and state.records[RESIDENT]["debt"] == debt,"Withdrawal remembers harm and grants no gratitude to the attacker")
	var withdrawn: Dictionary = state.records[RESIDENT].duplicate(true)
	for _step: int in 200: state.advance_ticks(8)
	_check(state.records[RESIDENT] == withdrawn,"Four hundred seconds of authored time cannot recover withdrawn NPCs")
	_check(not state.begin_talk(RESIDENT) and state.social_fence(RESIDENT).is_empty(),"Withdrawn life cannot supply dialogue or social-help eligibility")
	state.receive_hit(RESIDENT,0.0,0.0)
	_check(state.records[RESIDENT] == withdrawn,"Further damage cannot farm fear or downed episodes after withdrawal")
	var before: Dictionary = state.snapshot()
	_check(not state.decide(RESIDENT,RESIDENT+":1",true,true) and not state.decide(RESIDENT,RESIDENT+":1",true,false),"Both confirmed and unconfirmed legacy execution calls are refused")
	_check(state.snapshot() == before and NpcWorldState.life_id(RESIDENT) == life,"Rejected execution preserves life identity and all records")
	var cold: CountedState = _reader(state.save_path)
	_check(cold.load_state() and cold.records[RESIDENT] == withdrawn,"Cold load keeps withdrawal rather than healing it")
	# A compatibility downed input can withdraw, never pay a mercy reward.
	state.records[RESIDENT]["mode"] = "downed"
	var token: String = state.decision_token(RESIDENT)
	_check(state.save() and not token.is_empty(),"A valid compatibility downed state owns its episode token")
	_check(not state.decide(RESIDENT,token,true,true) and state.decide(RESIDENT,token,false),"Even a current downed token cannot authorize execution")
	_check(state.records[RESIDENT]["debt"] == debt and state.records[RESIDENT]["trust"] == -2,"Legacy spare callback does not buy debt or erase offense")
	_check(not state.decide(RESIDENT,token,false),"Repeated old choice cannot replay a withdrawal")

func _recovery_transaction() -> void:
	var state: CountedState = _fixture("recover")
	state.receive_hit(RESIDENT,1.0,0.0)
	state.receive_hit(CULTIVATOR,1.0,0.0)
	state.records[RESIDENT]["debt"] = 4
	_check(state.save(),"Existing relationship debt can be preserved across recovery")
	var before: Dictionary = state.snapshot()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(state.save_path)
	var fault := FaultIo.new(); fault.main_path = state.save_path; fault.fail_stage = "primary"
	state.io = fault
	state.activity_changed.connect(_on_activity)
	_check(not state.recover_after_expedition(),"Rejected final replace prevents expedition recovery from committing")
	_check(state.snapshot() == before and FileAccess.get_file_as_bytes(state.save_path) == bytes,"Recovery failure restores all live records and preserves primary bytes")
	_check(recovery_notifications == 0 and not state.last_save_ok,"Failed recovery emits no successful rest notification")
	fault.fail_stage = ""
	var writes: int = state.save_calls
	_check(state.recover_after_expedition() and state.save_calls == writes + 1,"One expedition-return recovery writes the whole affected population once")
	for id: String in [RESIDENT,CULTIVATOR]:
		_check(state.records[id]["mode"] == "rest" and state.records[id]["hp"] == NpcPilotCatalog.MAX_HEALTH * 0.5,id + ": actual recovery retains the previous half-health value")
		for field: String in ["trust","fear","debt","episode","greeted","legacy_death"]:
			_check(state.records[id][field] == before["records"][id][field],id + ": recovery preserves " + field)
	writes = state.save_calls
	var recovered: Dictionary = state.snapshot()
	_check(state.recover_after_expedition() and state.save_calls == writes and state.snapshot() == recovered,"Repeated return binding is an idempotent no-write operation")
	var cold: CountedState = _reader(state.save_path)
	_check(cold.load_state() and cold.snapshot() == recovered,"Successful expedition recovery survives cold load")
	var recovered_x: float = cold.records[RESIDENT]["x"]
	var schedule_index: int = cold.records[RESIDENT]["schedule_index"]
	cold.advance_ticks(8)
	cold.advance_ticks(5)
	_check(cold.records[RESIDENT]["mode"] == "walk" and cold.records[RESIDENT]["x"] != recovered_x and cold.records[RESIDENT]["schedule_index"] == schedule_index,"Recovered resident resting between stops resumes its pending route after the bounded rest")
	state.activity_changed.disconnect(_on_activity)

func _on_activity(_id: String, mode: String) -> void:
	if mode == "rest": recovery_notifications += 1

func _legacy(schema: int) -> Dictionary:
	var state := NpcWorldState.new()
	var data: Dictionary = state.snapshot()
	data["npc_schema"] = schema
	data["tick"] = 90
	for id: String in NpcPilotCatalog.CULTIVATOR_IDS: data["records"].erase(id)
	if schema == 1: data["records"].erase("pilot_bridge_keeper")
	for id: String in data["records"]:
		var record: Dictionary = data["records"][id]
		record.erase("legacy_death")
		if schema == 1:
			record.erase("schedule_index"); record.erase("interrupted")
			if id == RESIDENT: record["x"] = 700.0; record["target"] = 870.0
	var prior: Dictionary = data["records"][RESIDENT]
	prior["mode"] = "dead"; prior["hp"] = 0.0; prior["episode"] = 3
	prior["trust"] = -17; prior["fear"] = 42; prior["debt"] = 4; prior["greeted"] = true
	prior["death"] = {"event_id":RESIDENT+":3","killer_id":"player","tick":80,"room":"o01_p01","context":"explicit_execution"}
	return data

func _migration(schema: int) -> void:
	var path: String = directory + "/migration%d/profile.json.npc_v1.json" % schema
	var legacy: Dictionary = _legacy(schema)
	_check(NpcWorldState.valid(legacy) and _write(path,legacy),"Exact legacy schema%d input is accepted before migration" % schema)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var canonical_path: String = path.trim_suffix(".npc_v1.json")
	var opaque_profile: Dictionary = {"npc_social":{"receipt":"keep-help"},"courier":{"receipt":"keep-courier"},"cultivation":{"receipt":"keep-cultivation"},"uid":"unchanged"}
	_check(_write(canonical_path,opaque_profile),"Sentinel canonical profile is present beside sidecar")
	var canonical_bytes: PackedByteArray = FileAccess.get_file_as_bytes(canonical_path)
	var state: CountedState = _reader(path)
	_check(state.load_state() and not state.read_only and state.save_calls == 1,"Schema%d migrates with one durable owner transaction" % schema)
	_check(state.snapshot()["npc_schema"] == 4 and state.records.size() == 10 and NpcWorldState.valid(state.snapshot()),"Migration creates exact schema4 identities only after validation")
	_check(FileAccess.get_file_as_bytes(path+".bak") == original,"Migration backup preserves the entire original sidecar byte for byte")
	var immutable_path: String = path + ".pre_nonlethal_v%d.json" % schema
	_check(FileAccess.get_file_as_bytes(immutable_path) == original,"Immutable premigration source is byte-identical to the validated legacy primary")
	_check(state.records[RESIDENT]["legacy_death"] == legacy["records"][RESIDENT]["death"],"Every field of the original terminal fact remains in legacy_death")
	_check(state.records[RESIDENT]["death"].is_empty() and state.records[RESIDENT]["mode"] == "recovering" and state.records[RESIDENT]["hp"] == 1.0,"Old terminal resident is withdrawn pending a real expedition return")
	for field: String in ["episode","trust","fear","debt","greeted","room","x","target"]:
		_check(state.records[RESIDENT][field] == legacy["records"][RESIDENT][field],"Migration retains old " + field)
	_check(FileAccess.get_file_as_bytes(canonical_path) == canonical_bytes,"NPC migration cannot rewrite social/courier/cultivation receipts or UID data")
	var cold: CountedState = _reader(path)
	_check(cold.load_state() and cold.save_calls == 0 and cold.snapshot() == state.snapshot(),"Cold schema4 load cannot replay migration or manufacture another life")
	var archive: Dictionary = cold.records[RESIDENT]["legacy_death"].duplicate(true)
	_check(cold.recover_after_expedition(),"Migrated NPC can return under the new expedition policy")
	cold.receive_hit(RESIDENT,1.0,0.0)
	_check(cold.records[RESIDENT]["episode"] == 4 and cold.records[RESIDENT]["legacy_death"] == archive and NpcWorldState.valid(cold.snapshot()),"A later injury advances episode without overwriting the historical event")
	_check(FileAccess.get_file_as_bytes(immutable_path) == original,"Recovery and later saves never rotate the immutable premigration source")

func _migration_faults() -> void:
	for stage: String in ["immutable_copy","open","backup","primary"]:
		var path: String = directory + "/migration_fail_" + stage + "/profile.json.npc_v1.json"
		var legacy: Dictionary = _legacy(2)
		_check(_write(path,legacy),stage + ": fault fixture writes a valid old authority")
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var state: CountedState = _reader(path)
		var fault := FaultIo.new(); fault.main_path = path; fault.fail_stage = stage; state.io = fault
		_check(not state.load_state() and state.read_only,stage + ": failed migration exposes no new active authority")
		_check(SanctuaryProfile.CommitWriter.canonical(state.snapshot()) == SanctuaryProfile.CommitWriter.canonical(legacy) and FileAccess.get_file_as_bytes(path) == bytes,stage + ": rollback preserves the complete parsed old view and exact primary bytes")
		_check(not state.save() and not state.recover_after_expedition(),stage + ": quarantined instance cannot overwrite or recover old records")
		var retry: CountedState = _reader(path)
		_check(retry.load_state() and retry.records.size() == 10,stage + ": fresh load can retry the same valid migration")

func _immutable_backup_guards() -> void:
	var path: String = directory + "/immutable_conflict/profile.json.npc_v1.json"
	var legacy: Dictionary = _legacy(2)
	var old_backup: Dictionary = legacy.duplicate(true); old_backup["records"][RESIDENT]["trust"] = -22
	_check(_write(path,legacy) and _write(path+".pre_nonlethal_v2.json",old_backup),"An existing different premigration image is explicit preserved evidence")
	var primary: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(path+".pre_nonlethal_v2.json")
	var reader: CountedState = _reader(path)
	_check(not reader.load_state() and reader.read_only and SanctuaryProfile.CommitWriter.canonical(reader.snapshot()) == SanctuaryProfile.CommitWriter.canonical(legacy),"Conflicting immutable source quarantines migration without defaulting life records")
	_check(FileAccess.get_file_as_bytes(path) == primary and FileAccess.get_file_as_bytes(path+".pre_nonlethal_v2.json") == backup,"Neither primary nor conflicting immutable source can be overwritten")
	var absent_path: String = directory + "/immutable_only/profile.json.npc_v1.json"
	_check(_write(absent_path+".pre_nonlethal_v2.json",legacy),"Missing-primary fixture retains only its premigration evidence")
	var absent: CountedState = _reader(absent_path)
	_check(not absent.load_state() and absent.read_only and not absent.save() and not FileAccess.file_exists(absent_path),"Immutable evidence alone prevents silently resetting a missing primary")

func _quarantine() -> void:
	var valid: Dictionary = NpcWorldState.new().snapshot()
	var cases: Dictionary = {}
	var future: Dictionary = valid.duplicate(true); future["npc_schema"] = NpcWorldState.SCHEMA + 1; cases["future"] = future
	var missing: Dictionary = valid.duplicate(true); missing["records"].erase(CULTIVATOR); cases["missing_current_id"] = missing
	var corrupt: Dictionary = valid.duplicate(true); corrupt["records"][RESIDENT].erase("legacy_death"); cases["missing_history_field"] = corrupt
	var terminal: Dictionary = valid.duplicate(true); terminal["records"][RESIDENT]["mode"] = "dead"; cases["new_terminal_state"] = terminal
	var history: Dictionary = valid.duplicate(true); history["records"][RESIDENT]["legacy_death"] = {"event_id":"invented"}; cases["malformed_history"] = history
	for label: String in cases:
		var path: String = directory + "/quarantine_" + label + "/profile.json.npc_v1.json"
		_check(_write(path,cases[label]) and _write(path+".bak",valid),label + ": malformed primary coexists with older valid backup")
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var state: CountedState = _reader(path)
		_check(not NpcWorldState.valid(cases[label]) and not state.load_state() and state.read_only,label + ": invalid authority is quarantined without adding default residents")
		_check(not state.recover_after_expedition() and not state.save() and FileAccess.get_file_as_bytes(path) == bytes,label + ": old alive backup cannot erase history or replace the primary")
	var absent_path: String = directory + "/missing_primary/profile.json.npc_v1.json"
	_check(_write(absent_path+".bak",valid),"Missing-primary fixture keeps only an older backup")
	var absent: CountedState = _reader(absent_path)
	_check(not absent.load_state() and absent.read_only and not FileAccess.file_exists(absent_path),"Missing primary with possible history is quarantined rather than repopulated")

func _local_control() -> void:
	var state: CountedState = _fixture("control")
	var before: Dictionary = state.records[CULTIVATOR].duplicate(true)
	_check(not state.set_local_control(RESIDENT,true) and state.set_local_control(CULTIVATOR,true),"Only authored cultivators can hold local combat motion")
	state.advance_ticks(8)
	_check(state.records[CULTIVATOR] == before,"Held local combat cannot compete with the 4Hz patrol owner")
	var writes: int = state.save_calls
	_check(state.update_local_position(CULTIVATOR,99999.0) and state.records[CULTIVATOR]["x"] == NpcPilotCatalog.definition(CULTIVATOR)["right"],"Local combat position remains inside the authored patrol bounds")
	_check(not state.update_local_position(CULTIVATOR,NAN) and state.save_calls == writes,"Local position cannot introduce NaN or per-frame disk writes")
	_check(state.save() and NpcWorldState.valid(state.snapshot()),"Runtime motion hold is absent from the durable schema")
	var cold: CountedState = _reader(state.save_path)
	_check(cold.load_state() and not cold.update_local_position(CULTIVATOR,1600.0),"Cold load never restores a stale combat controller")
	_check(state.set_local_control(CULTIVATOR,false) and not state.update_local_position(CULTIVATOR,1600.0),"Leaving a room releases motion ownership")
	var x: float = state.records[CULTIVATOR]["x"]
	state.advance_ticks(8)
	_check(state.records[CULTIVATOR]["x"] != x,"Released resident resumes its existing authored patrol")
	state.receive_hit(CULTIVATOR,35.0,0.0,true,NAN,true)
	var trust: int = state.records[CULTIVATOR]["trust"]
	var fear: int = state.records[CULTIVATOR]["fear"]
	state.receive_hit(CULTIVATOR,32.0,0.0,true,NAN,false)
	_check(state.records[CULTIVATOR]["hp"] == 32.0 and state.records[CULTIVATOR]["trust"] == trust and state.records[CULTIVATOR]["fear"] == fear,"Child damage can update health without duplicating the same incident's blame")
	state.receive_hit(CULTIVATOR,1.0,0.0)
	_check(not state.set_local_control(CULTIVATOR,true) and not state.update_local_position(CULTIVATOR,1600.0),"Withdrawn cultivator cannot restart local combat motion")

func _damage_pipeline() -> void:
	var state: CountedState = _fixture("damage")
	var actor := Node2D.new(); root.add_child(actor)
	var source := Node2D.new(); root.add_child(source)
	var health := HealthComponent.new(); health.maximum_health = 40; actor.add_child(health)
	var resolver := NpcPilotResolver.new(); resolver.world_state = state; resolver.stable_id = RESIDENT; resolver.health = health; actor.add_child(resolver)
	var hurtbox := Hurtbox.new(); hurtbox.actor_body = actor; hurtbox.health = health; hurtbox.damage_resolver = resolver; hurtbox.team_id = 3; actor.add_child(hurtbox)
	var event := DamageEvent.new()
	event.source_id = source.get_instance_id(); event.target_id = actor.get_instance_id(); event.source_team_id = 1
	event.attack_id = 741; event.hit_window_id = 1; event.root_event_id = 741; event.base_damage = 999.0
	var result: DamageResult = hurtbox.take_damage(event)
	_check(result.actual_damage == 39.0 and not result.killed and health.current_health == 1.0,"Actual resolver applies nonlethal health floor before publishing damage result")
	_check(state.records[RESIDENT]["mode"] == "recovering" and state.records[RESIDENT]["death"].is_empty(),"Accepted contact reaches the same authoritative withdrawal owner")
	var record: Dictionary = state.records[RESIDENT].duplicate(true)
	event.source_kind = DamageEvent.SourceKind.DOT; event.attack_id = 742
	result = hurtbox.take_internal_damage(event)
	_check(result.blocked and result.block_reason == &"npc_protected" and state.records[RESIDENT] == record,"Internal DOT cannot bypass withdrawal protection or generate another consequence")
	actor.queue_free(); source.queue_free()
	await process_frame
	await process_frame

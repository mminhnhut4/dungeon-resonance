extends SceneTree
## Test-only composition of the current nonlethal resident source and
## canonical courier adapter with the common R2 owner. No product UI activation.
const SocialLife = preload("res://scripts/npc/npc_world_state.gd")
const SocialProgress = preload("res://tests/integration_fixtures/reviewed_opening/social_progress.gd")
const Courier = preload("res://tests/integration_fixtures/reviewed_opening/courier_opportunity.gd")
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
const Spans = preload("res://scripts/runtime/profile_json_spans.gd")
const ID: String = "pilot_traveler"
const SOCIAL_PATH: Array[String] = ["event_extensions", "namespaces", "npc_social"]
var checks: int = 0
var failures: int = 0
var directory: String
var events: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second=int(argument.trim_prefix("--hz="))
	var user_dir: String = ProjectSettings.globalize_path("user://").replace("\\","/")
	var qa_root: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not qa_root.is_absolute_path() or not user_dir.begins_with(qa_root+"/"):
		print("FAIL: Isolated QA user directory required")
		quit(1); return
	directory="user://verification/combined_actual_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	print("COMBINED_ACTUAL_USER_DIR="+user_dir)
	_social_once()
	_social_io_faults()
	_pending_recovery()
	_life_rechecks()
	_migration_and_quarantine()
	_courier_choices()
	_material_capabilities()
	print("RESULT OpeningCombinedOwner checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures==0 else 1)

func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: "+label)

func _raw(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func _register(profile: SanctuaryProfile) -> void:
	_check(profile.register_extension_validator("npc_social",SocialProgress.valid),"Actual social semantic validator registers before load")
	_check(profile.register_social_fence_reader(Callable(self,"_durable_reader").bind(profile.save_path)),"Trusted current life primary reader registers before recovery")

func _fixture(label: String) -> SanctuaryProfile:
	var profile := SanctuaryProfile.new()
	profile.save_path=directory+"/"+label+"/profile.json"
	_register(profile)
	profile.souls=25; profile.coins=20
	profile.material_stash[&"linen_fiber"]=8; profile.material_stash[&"dust"]=10; profile.material_stash[&"crystal"]=20
	_check(profile.save(),label+": isolated v1 fixture is durable")
	_check(profile.commit_cultivation(Model.initial_proposal(Model.new_progress(4),profile.material_stash,profile.souls,profile.boss_proofs)),label+": common owner initializes v2 once")
	return profile

func _reader(path: String, expected_ok: bool = true, register_before: bool = true) -> SanctuaryProfile:
	var profile := SanctuaryProfile.new(); profile.save_path=path
	if register_before: _register(profile)
	var loaded: bool = profile.load_profile()
	_check(loaded==expected_ok and (loaded or profile.read_only),"Cold owner load has the expected recovery/quarantine result")
	return profile

func _life(profile: SanctuaryProfile) -> RefCounted:
	var life: RefCounted = SocialLife.new()
	life.set("save_path",profile.save_path+".npc_v1.json")
	_check(life.call("save")==true and SocialLife.valid(life.call("snapshot")),"Actual eight-resident schema3 life owner saves its primary sidecar")
	_check(life.call("snapshot")["npc_schema"]==3 and life.get("records").size()==8,"Combined fixture uses current life authority, not a synthetic transport validator")
	return life

func _fence(life: RefCounted) -> Dictionary:
	var value: Dictionary = life.call("social_fence",ID)
	if value.is_empty(): return {}
	value["kind"]="npc_social"
	return value

func _guard(life: RefCounted, fence: Dictionary) -> Callable:
	var raw: Dictionary = fence.duplicate(true); raw.erase("kind")
	return Callable(life,"social_fence_matches").bind(raw)

func _durable_reader(fence: Dictionary, profile_path: String) -> Dictionary:
	var refused: Dictionary = {"ok":false,"eligible":false,"unchanged":false}
	if fence.size()!=6 or fence.get("kind")!="npc_social" or fence.get("actor_id")!=ID or fence.get("life_id")!=SocialLife.life_id(ID): return refused
	var path: String = profile_path+".npc_v1.json"
	if fence.get("npc_path")!=path or not path.begins_with(directory+"/"): return refused
	for field: String in ["live_fingerprint","durable_fingerprint"]:
		if not Writer._hash(fence.get(field)): return refused
	var file: FileAccess = FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>32768: return refused
	var text: String = file.get_as_text(); file.close()
	if not Spans.unique_value(text): return refused
	var payload: Variant = JSON.parse_string(text)
	if not SocialLife.valid(payload): return refused
	var record: Dictionary = payload["records"][ID]
	var eligible: bool = record["death"].is_empty() and record["mode"] not in ["dead","downed","recovering","flee"] and record["hp"]>=1
	return {"ok":true,"eligible":eligible,"unchanged":SocialLife._social_fingerprint(ID,record)==fence["durable_fingerprint"]}

func _help(profile: SanctuaryProfile, life: RefCounted) -> Dictionary:
	var fence: Dictionary = _fence(life)
	if fence.is_empty(): return {"ok":false,"error":"no_eligible_actual_life"}
	var current: Dictionary = profile.extension_state("npc_social")
	if current.is_empty(): current=SocialProgress.empty()
	var next: Dictionary = current if SocialProgress.helped(current,ID) else SocialProgress.with_help(current,ID,SocialLife.life_id(ID))
	return profile.commit_extension_event("npc_social",SocialProgress.event_id(ID,SocialLife.life_id(ID)),{&"linen_fiber":2},0,next,profile.extension_revision("npc_social"),fence,_guard(life,fence))

func _social_once() -> void:
	var profile: SanctuaryProfile = _fixture("social_once")
	var life: RefCounted = _life(profile)
	var npc_bytes: PackedByteArray = _raw(life.get("save_path"))
	var progress: Dictionary = profile.cultivation_progress.duplicate(true)
	_check(profile.record_courier_offer() and profile.record_courier_contact("shrine"),"Courier flags use the same canonical writer")
	var courier: Dictionary = profile.courier_objectives()
	var result: Dictionary = _help(profile,life)
	_check(result.get("ok",false) and result.get("status")=="committed" and profile.material_stash[&"linen_fiber"]==6,"Actual social help commits one two-linen cost and semantic receipt")
	_check(SocialProgress.helped(profile.extension_state("npc_social"),ID) and profile.extension_revision("npc_social")==1,"Only canonical npc_social holds the actual life-bound help history")
	_check(profile.cultivation_progress==progress and profile.courier_objectives()==courier and _raw(life.get("save_path"))==npc_bytes,"Social preserves cultivation/courier and never writes the life sidecar")
	var bytes: PackedByteArray = _raw(profile.save_path)
	_check(_help(profile,life).get("status")=="already_committed" and _raw(profile.save_path)==bytes and profile.material_stash[&"linen_fiber"]==6,"Live social replay neither debits nor republishes")
	var cold: SanctuaryProfile = _reader(profile.save_path)
	_check(_help(cold,life).get("status")=="already_committed" and _raw(profile.save_path)==bytes,"Cold social replay stays one effect")
	var relation: Dictionary = SocialProgress.relationship(cold.extension_state("npc_social"),ID,life.get("records")[ID])
	_check(relation["fear"]==life.get("records")[ID]["fear"],"Help relation does not erase the life owner's fear")

func _social_io_faults() -> void:
	for point: String in ["write_candidate","write_decision","rename_decision","rename_old","commit"]:
		var profile: SanctuaryProfile = _fixture("social_fault_"+point)
		var life: RefCounted = _life(profile)
		var before: PackedByteArray = _raw(profile.save_path)
		var npc_before: PackedByteArray = _raw(life.get("save_path"))
		profile._writer.fault_plan={point:true}
		var result: Dictionary = _help(profile,life)
		_check(not result.get("ok",true) and result.get("status")=="rejected" and not profile.read_only,point+": actual social transaction is definitively aborted")
		_check(_raw(profile.save_path)==before and profile.material_stash[&"linen_fiber"]==8 and profile.extension_state("npc_social").is_empty() and _raw(life.get("save_path"))==npc_before,point+": no speculative receipt, debit or NPC write")
		var cold: SanctuaryProfile = _reader(profile.save_path)
		_check(_help(cold,life).get("ok",false) and cold.material_stash[&"linen_fiber"]==6,point+": explicit retry commits exactly once after proved abort")

func _pending_recovery() -> void:
	for point: String in ["after_candidate","after_decision","after_old_rename","after_commit"]:
		var profile: SanctuaryProfile = _fixture("social_pending_"+point)
		var life: RefCounted = _life(profile)
		profile._writer.fault_plan={point:true}
		_check(not _help(profile,life).get("ok",true),point+": interrupted caller publishes no result")
		if point=="after_decision":
			var absent: SanctuaryProfile = _reader(profile.save_path,false,false)
			_check(absent.read_only and FileAccess.file_exists(profile.save_path+".decision"),"Missing trusted reader fails closed before pending social recovery")
		var cold: SanctuaryProfile = _reader(profile.save_path)
		if point=="after_candidate":
			_check(cold.material_stash[&"linen_fiber"]==8 and cold.extension_state("npc_social").is_empty(),"A candidate without a decision never promotes")
		else:
			_check(cold.material_stash[&"linen_fiber"]==6 and SocialProgress.helped(cold.extension_state("npc_social"),ID),point+": real social semantic state and its debit recover together")
		var again: SanctuaryProfile = _reader(profile.save_path)
		_check(again.material_stash==cold.material_stash and again.extension_state("npc_social")==cold.extension_state("npc_social"),point+": second cold load is stable")
	var dead: SanctuaryProfile = _fixture("pending_dead")
	var dead_life: RefCounted = _life(dead)
	dead._writer.fault_plan={"after_old_rename":true}
	_check(not _help(dead,dead_life).get("ok",true),"Withdrawal fixture reaches the pending missing-main window")
	dead_life.call("receive_hit",ID,1.0,0.0)
	_check(dead_life.call("decide",ID,dead_life.call("decision_token",ID),true,true)==false and dead_life.get("records")[ID]["mode"]=="recovering","Actual life owner durably withdraws the injured NPC and rejects execution")
	var tombstone: PackedByteArray = _raw(dead_life.get("save_path"))
	var aborted: SanctuaryProfile = _reader(dead.save_path)
	_check(aborted.last_commit.get("status")=="recovered_aborted" and aborted.material_stash[&"linen_fiber"]==8 and aborted.extension_state("npc_social").is_empty(),"Persisted withdrawal aborts a pending social effect without a debit")
	_check(_raw(dead_life.get("save_path"))==tombstone,"Profile recovery cannot heal or rewrite the actual NPC owner")

func _life_rechecks() -> void:
	for change: String in ["fear","downed","unsaved_down"]:
		var profile: SanctuaryProfile = _fixture("social_recheck_"+change)
		var life: RefCounted = _life(profile)
		var before: PackedByteArray = _raw(profile.save_path)
		profile._writer.before_commit=func() -> void:
			if change=="fear": life.get("records")[ID]["fear"]+=1; life.call("save")
			elif change=="downed": life.call("receive_hit",ID,1.0,0.0)
			else:
				life.get("records")[ID]["mode"]="downed"; life.get("records")[ID]["hp"]=1.0; life.get("records")[ID]["episode"]=1
		var result: Dictionary = _help(profile,life)
		_check(not result.get("ok",true) and _raw(profile.save_path)==before and profile.material_stash[&"linen_fiber"]==8,change+": live/durable actual relationship and eligibility are rechecked before publication")
		_check(profile.extension_state("npc_social").is_empty(),change+": failed fence grants no social history")

func _write_fixture(profile: SanctuaryProfile, text: String) -> void:
	_check(profile.save_path.begins_with(directory+"/"),"Raw evidence writes are confined to this unique fixture")
	var file: FileAccess = FileAccess.open(profile.save_path,FileAccess.WRITE)
	if file==null: _check(false,"Fixture writer opens"); return
	file.store_string(text); file.flush(); _check(file.get_error()==OK,"Raw fixture is durable"); file.close()

func _migration_and_quarantine() -> void:
	var legacy: SanctuaryProfile = _fixture("social_legacy")
	var data: Dictionary = Writer.read_json(legacy.save_path)
	var actual: Dictionary = SocialProgress.with_help(SocialProgress.empty(),ID,SocialLife.life_id(ID))
	data["npc_social_progress"]=actual
	_write_fixture(legacy,Writer.canonical(Writer.sealed(data,2)))
	var loaded: SanctuaryProfile = _reader(legacy.save_path)
	var linen: int = loaded.material_stash[&"linen_fiber"]
	_check(not loaded.social_transactions_available(),"Legacy social remains disabled until canonical migration")
	_check(loaded.migrate_legacy_event_scope("npc_social","npc_social_progress",SocialProgress.valid).get("ok",false),"Actual reviewed social schema migrates through the common writer")
	_check(loaded.extension_state("npc_social")==actual and not Writer.read_json(loaded.save_path).has("npc_social_progress") and loaded.material_stash[&"linen_fiber"]==linen,"Migration removes the old mirror in one commit without charging again")
	var bytes: PackedByteArray = _raw(loaded.save_path)
	_check(loaded.migrate_legacy_event_scope("npc_social","npc_social_progress",SocialProgress.valid).get("status")=="already_migrated" and _raw(loaded.save_path)==bytes,"Migration replay is read-only")
	for kind: String in ["future","duplicate"]:
		var profile: SanctuaryProfile = _fixture("social_opaque_"+kind)
		var payload: Dictionary = Writer.read_json(profile.save_path)
		var span: String
		var path: Array[String]
		if kind=="future":
			span=" \n{\"revision\":0,\"state\":{\"schema_version\":99,\"receipts\":{}},\"receipts\":[]} \t"
			payload["event_extensions"]={"schema_version":1,"namespaces":{"npc_social":JSON.parse_string(span)}}
			path=SOCIAL_PATH
		else:
			span="{\"schema_version\":1,\"receipts\":{\"pilot_traveler\":{\"life_id\":\"pilot_traveler:opening:1\",\"event_id\":\"ambiguous\",\"event_id\":\"pilot_traveler:opening:1:help:linen:1\"}}}"
			payload["npc_social_progress"]=JSON.parse_string(span); path=["npc_social_progress"]
		var text: String = Spans.replace(Writer.canonical(Writer.sealed(payload,2)),path,span)
		_write_fixture(profile,text)
		var cold: SanctuaryProfile = _reader(profile.save_path)
		_check(not cold.social_transactions_available() and not cold.read_only,kind+": only social is quarantined")
		if kind=="duplicate":
			_check(not cold.migrate_legacy_event_scope("npc_social","npc_social_progress",SocialProgress.valid).get("ok",true),"Actual valid-looking duplicate receipt cannot erase raw legacy evidence")
		_check(cold.try_add_souls(1) and Spans.extract(FileAccess.get_file_as_string(cold.save_path),path).get("span")==span,kind+": ordinary core save preserves every opaque social byte")

func _courier_choices() -> void:
	for choice: StringName in [&"prepare",&"help"]:
		var profile: SanctuaryProfile = _fixture("courier_"+String(choice))
		var life: RefCounted = _life(profile)
		life.call("receive_hit","pilot_pilgrim",1.0,0.0)
		_check(life.call("decide","pilot_pilgrim",life.call("decision_token","pilot_pilgrim"),true,true)==false and life.get("records")["pilot_pilgrim"]["mode"]=="recovering","Courier fallback fixture has an actual withdrawn pilgrim")
		var npc_bytes: PackedByteArray = _raw(life.get("save_path"))
		var adapter: RefCounted = Courier.new(); adapter.call("initialize",profile,profile); adapter.call("arm",&"healer")
		var accepted: Dictionary = adapter.call("apply_action",&"courier_accept")
		_check(accepted.get("success",false),"Reviewed adapter resolves the common owner's offer alias")
		var offered: PackedByteArray = _raw(profile.save_path)
		_check(profile.record_courier_offer() and profile.accept_courier_opportunity() and _raw(profile.save_path)==offered and profile.extension_revision("courier")==1,"Both offer API names share one receipt and no second write")
		adapter.call("arm",&"shrine")
		_check(adapter.call("apply_action",&"courier_contact")["success"],"Dead-contact fallback records the shrine through canonical owner")
		events.clear(); adapter.connect("choice_committed",Callable(self,"_record_event"))
		var linen: int = profile.material_stash[&"linen_fiber"]
		var result: Dictionary = adapter.call("apply_action",StringName("courier_"+String(choice)))
		_check(result.get("success",false) and events.size()==1 and events[0]==profile.courier_choice_event(),"Canonical courier adapter emits only the committed owner's exact snapshot")
		_check(profile.material_stash[&"dust"]==(9 if choice==&"help" else 10) and profile.material_stash[&"linen_fiber"]==linen and profile.souls==25,"Courier has one dust consequence, no social linen or Soul charge")
		_check(not Writer.read_json(profile.save_path).has("courier_opportunity") and _raw(life.get("save_path"))==npc_bytes,"Courier uses one namespace and preserves the NPC tombstone")
		var committed: PackedByteArray = _raw(profile.save_path)
		_check(adapter.call("apply_action",StringName("courier_"+String(choice)))["success"] and events.size()==1 and _raw(profile.save_path)==committed,"Adapter replay grants no second event or write")
		var other: StringName = &"help" if choice==&"prepare" else &"prepare"
		_check(not adapter.call("apply_action",StringName("courier_"+String(other)))["success"] and _raw(profile.save_path)==committed,"Opposite courier outcome stays blocked")
		var cold: SanctuaryProfile = _reader(profile.save_path)
		var rebound: RefCounted = Courier.new(); rebound.call("initialize",cold,cold); rebound.call("arm",&"shrine"); events.clear(); rebound.connect("choice_committed",Callable(self,"_record_event"))
		_check(rebound.call("objectives")["committed_event"]==cold.courier_choice_event() and events.is_empty(),"Cold/rebound adapter reads the receipt without replaying a live event")

func _record_event(event: Dictionary) -> void:
	events.append(event.duplicate(true))

func _material_capabilities() -> void:
	var profile: SanctuaryProfile = _fixture("capabilities")
	var economy := EconomySession.new(); economy.profile=profile; economy.inventory=GearInventory.new(); economy.hub_access=true
	var bytes: PackedByteArray = _raw(profile.save_path)
	for id: StringName in [&"aptitude_herb",&"aptitude_pill"]:
		var policy: Dictionary = MaterialCatalog.material_policy(id)
		var capability: Dictionary = economy.material_capability(id,1)
		_check(policy["lineage_bound"] and not policy["ordinary_transfer"] and policy["art_status"]=="missing_final" and not capability["can_deposit"] and not capability["can_withdraw"],"Both aptitude items are display-only under the public capability query")
	_check(_raw(profile.save_path)==bytes,"Detached capability queries perform no save or grant")

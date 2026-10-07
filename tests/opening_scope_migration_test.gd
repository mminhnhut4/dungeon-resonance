extends SceneTree
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
var checks: int = 0
var failures: int = 0
var directory: String
func _initialize() -> void: call_deferred("_run")
func _check(value: bool, text: String) -> void:
	checks+=1
	if not value: failures+=1; print("FAIL "+text)
	else: print("PASS "+text)
func _fixture(name: String) -> SanctuaryProfile:
	var profile := SanctuaryProfile.new(); profile.save_path=directory+"/"+name+".json"
	profile.souls=100; profile.material_stash[&"dust"]=3; profile.material_stash[&"linen_fiber"]=6
	profile.save(); profile.commit_cultivation(Model.initial_proposal(Model.new_progress(4),profile.material_stash,profile.souls,profile.boss_proofs))
	return profile
func _valid_social(state: Dictionary) -> bool:
	return state.get("schema_version")==1 and state.get("receipts") is Dictionary
func _run() -> void:
	directory="user://verification/opening_scope_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var profile: SanctuaryProfile = _fixture("valid")
	var social: Dictionary = {"schema_version":1,"receipts":{"pilot_traveler":{"life_id":"pilot_traveler:opening:1","event_id":"pilot_traveler:opening:1:help:linen:1"}}}
	var courier: Dictionary = {"version":1,"accepted":true,"contact_recorded":true,"contact_source":"shrine","outcome":"help"}
	profile._retained_fields["npc_social_progress"]=social
	profile._retained_fields["courier_opportunity"]=courier
	_check(profile.save() and profile.courier_objectives().is_empty(),"Legacy scopes are retained while courier is disabled pending migration")
	_check(profile.migrate_legacy_event_scope("npc_social","npc_social_progress",_valid_social).get("ok",false),"Valid social state moves through one common commit")
	_check(profile.migrate_legacy_event_scope("courier","courier_opportunity",SanctuaryProfile._valid_courier).get("ok",false),"Valid courier outcome moves through the same owner")
	_check(not profile._retained_fields.has("npc_social_progress") and not profile._retained_fields.has("courier_opportunity"),"No mirrored root social/courier authority remains")
	_check(profile.extension_state("npc_social")==social and profile.courier_objectives()==courier and profile.souls==100 and profile.material_stash[&"linen_fiber"]==6 and profile.material_stash[&"dust"]==3,"Migration preserves original receipts/outcome and grants or charges nothing")
	_check(profile.migrate_legacy_event_scope("courier","courier_opportunity",SanctuaryProfile._valid_courier)["status"]=="already_migrated","Migration repeats without another event or cost")
	var reloaded := SanctuaryProfile.new(); reloaded.save_path=profile.save_path
	reloaded.register_extension_validator("npc_social",_valid_social)
	_check(reloaded.load_profile() and reloaded.extension_state("npc_social")==social and reloaded.courier_choice_event()["source_id"]=="p03_shrine_register","Cold read uses canonical scopes and committed event projection")
	var malformed: SanctuaryProfile = _fixture("malformed")
	malformed._retained_fields["npc_social_progress"]={"schema_version":9,"bad_receipt":"must_keep"}
	malformed._retained_fields["courier_opportunity"]={"version":9,"outcome":"unknown_history"}
	_check(malformed.save(),"Opaque malformed subsystem fields remain saveable evidence")
	var before: Dictionary = malformed._retained_fields.duplicate(true)
	_check(malformed.migrate_legacy_event_scope("npc_social","npc_social_progress",_valid_social)["status"]=="extension_quarantined" and malformed.migrate_legacy_event_scope("courier","courier_opportunity",SanctuaryProfile._valid_courier)["status"]=="extension_quarantined","Future/malformed subsystem migrations are refused separately")
	_check(not malformed.read_only and malformed._retained_fields==before and malformed.courier_objectives().is_empty(),"Subsystem refusal keeps opaque history and disables its own action only")
	var inventory := GearInventory.new()
	var economy := EconomySession.new(); economy.initialize(malformed,inventory)
	_check(economy.buy_upgrade(&"max_hp") and malformed.souls==80 and malformed.save(),"Malformed optional social/courier does not softlock the existing first HP upgrade")
	var cold := SanctuaryProfile.new(); cold.save_path=malformed.save_path
	_check(cold.load_profile() and cold._retained_fields["npc_social_progress"]==before["npc_social_progress"] and cold._retained_fields["courier_opportunity"]==before["courier_opportunity"],"Unrelated core commits retain bad receipt evidence on cold load")
	var conflict: SanctuaryProfile = _fixture("conflict")
	conflict.commit_extension_event("courier","fixture_scope",{},0,courier)
	conflict._retained_fields["courier_opportunity"]={"version":1,"accepted":false,"contact_recorded":false,"contact_source":"","outcome":""}; conflict.save()
	_check(conflict.migrate_legacy_event_scope("courier","courier_opportunity",SanctuaryProfile._valid_courier)["status"]=="extension_quarantined" and conflict._retained_fields.has("courier_opportunity") and conflict.extension_state("courier")==courier,"Conflicting histories remain preserved and cannot silently overwrite the committed outcome")
	var fault: SanctuaryProfile = _fixture("migration_io")
	fault._retained_fields["courier_opportunity"]=courier; fault.save()
	var fault_before: PackedByteArray = FileAccess.get_file_as_bytes(fault.save_path)
	fault._writer.fault_plan={"write_candidate":true}
	_check(not fault.migrate_legacy_event_scope("courier","courier_opportunity",SanctuaryProfile._valid_courier).get("ok",false) and fault._retained_fields.has("courier_opportunity") and fault.extension_state("courier").is_empty() and FileAccess.get_file_as_bytes(fault.save_path)==fault_before,"Migration IO failure retains one legacy authority and exact old image")
	_check(fault.migrate_legacy_event_scope("courier","courier_opportunity",SanctuaryProfile._valid_courier).get("ok",false),"Explicit migration retry moves the same valid outcome once")
	var opaque: SanctuaryProfile = _fixture("opaque_scope")
	_check(opaque.commit_extension_event("courier","opaque_fixture",{},0,{"version":9,"bad_receipt":"retain_scope"}).get("ok",false),"Generic codec retains JSON-opaque subsystem state")
	_check(opaque.courier_objectives().is_empty() and opaque.spend(1) and opaque.extension_state("courier")["bad_receipt"]=="retain_scope" and not opaque.read_only,"Malformed scoped courier state disables courier while unrelated saves retain evidence")
	var reader: SanctuaryProfile = _fixture("social_reader")
	reader.register_extension_validator("npc_social",_valid_social)
	var fake_fence: Dictionary = {"kind":"npc_social","npc_path":reader.save_path+".npc_v1.json"}
	_check(not reader.commit_extension_event("npc_social","help_read_fence",{&"linen_fiber":2},0,social,0,fake_fence,func() -> bool: return true).get("ok",false) and reader.material_stash[&"linen_fiber"]==6,"Unregistered social durable reader cannot commit a help cost")
	_check(reader.register_social_fence_reader(func(_fence: Dictionary) -> Variant: return "invalid_result") and not reader.commit_extension_event("npc_social","help_read_fence",{&"linen_fiber":2},0,social,0,fake_fence,func() -> bool: return true).get("ok",false),"Trusted reader contract still rejects malformed return types")
	_check(reader.register_social_fence_reader(func(_fence: Dictionary) -> Dictionary: return {"ok":true,"eligible":true,"unchanged":true}),"Composition can install a trusted reader; no callable is read from JSON")
	_check(reader.commit_extension_event("npc_social","help_read_fence",{&"linen_fiber":2},0,social,0,fake_fence,func() -> bool: return true).get("ok",false) and reader.material_stash[&"linen_fiber"]==4,"Transport hook commits canonical scope and cost together after both guards")
	print("RESULT OpeningScopeMigration checks=%d failures=%d" % [checks,failures]); quit(0 if failures==0 else 1)

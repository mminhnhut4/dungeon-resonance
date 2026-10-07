extends SceneTree
## Narrow reviewer regressions: raw migration authority and stale proposals.
## Social validator is a transport fixture, not the actual schema2 feature.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
const Spans = preload("res://scripts/runtime/profile_json_spans.gd")
const LEGACY: Array[String] = ["npc_social_progress"]
const SOCIAL: Array[String] = ["event_extensions","namespaces","npc_social"]
const LIFE: String = "pilot_traveler:opening:1"
const HELP: String = LIFE+":help:linen:1"
var directory: String
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL "+label)
	else: print("PASS "+label)
func _fixture(label: String) -> SanctuaryProfile:
	var p := SanctuaryProfile.new(); p.save_path=directory+"/"+label+"/profile.json"
	p.souls=100; p.material_stash[&"dust"]=20; p.material_stash[&"crystal"]=30; p.material_stash[&"linen_fiber"]=8; p.boss_proofs[&"golem"]=1
	_check(p.save() and p.commit_cultivation(Model.initial_proposal(Model.new_progress(4),p.material_stash,p.souls,p.boss_proofs)),label+": guarded fresh initialization commits")
	return p
func _run() -> void:
	directory="user://verification/opening_review_r2_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	_migration(); _stale_proposals(); _realm_replay(); _courier_alias(); _material_capabilities()
	print("RESULT OpeningOwnerReviewR2 checks=%d failures=%d" % [checks,failures]); quit(0 if failures==0 else 1)
static func _valid_social(state: Dictionary) -> bool:
	return state.size()==2 and state.get("schema_version")==1 and state.get("receipts")=={"pilot_traveler":{"life_id":LIFE,"event_id":HELP}}
func _social_state() -> Dictionary:
	return {"schema_version":1,"receipts":{"pilot_traveler":{"life_id":LIFE,"event_id":HELP}}}
func _span(p: SanctuaryProfile, path: Array[String]) -> String:
	return Spans.extract(FileAccess.get_file_as_string(p.save_path),path).get("span","")
func _snapshot(p: SanctuaryProfile) -> String:
	return Writer.canonical([p.cultivation_progress,p.material_stash,p.souls,p.boss_proofs,p.permanent_upgrades,p.cultivation_abilities()])
func _propose(p: SanctuaryProfile, id: String, kind: String = "train", args: Dictionary = {}) -> Dictionary:
	if kind=="train": args={"actor_id":"player","sessions":1,"target_tick":int(p.cultivation_progress["gameplay_tick"])+8}
	return Model.propose(p.cultivation_progress,p.material_stash,p.souls,p.boss_proofs,kind,args,id)
func _write_raw(p: SanctuaryProfile, legacy_span: String, scope_span: String = "") -> void:
	var payload: Dictionary = Writer.read_json(p.save_path)
	payload["npc_social_progress"]=JSON.parse_string(legacy_span)
	if not scope_span.is_empty(): payload["event_extensions"]={"schema_version":1,"namespaces":{"npc_social":JSON.parse_string(scope_span)}}
	var text: String = Writer.canonical(Writer.sealed(payload,1))
	text=Spans.replace(text,LEGACY,legacy_span)
	if not scope_span.is_empty(): text=Spans.replace(text,SOCIAL,scope_span)
	var file := FileAccess.open(p.save_path,FileAccess.WRITE); file.store_string(text); file.close()
	_check(not text.is_empty() and p.load_profile(),"Owned raw fixture has valid enclosing JSON/seal")
func _migration() -> void:
	var valid_span: String = Writer.canonical(_social_state())
	var duplicate: String = " \n{\"schema_version\":1,\"receipts\":{\"pilot_traveler\":{\"life_id\":\""+LIFE+"\",\"event_id\":\"bad\",\"event_id\":\""+HELP+"\"}}} \t"
	var scope: String = " {\"revision\":0,\"state\":"+duplicate+",\"receipts\":[]} \r\n"
	for scenario: String in ["legacy_duplicate","namespace_duplicate"]:
		var p: SanctuaryProfile = _fixture(scenario)
		_write_raw(p,duplicate if scenario=="legacy_duplicate" else valid_span,scope if scenario=="namespace_duplicate" else "")
		_check(_valid_social(JSON.parse_string(duplicate)),"Last duplicate event_id looks valid after dictionary parsing")
		var original: PackedByteArray = FileAccess.get_file_as_bytes(p.save_path)
		var before: String = _snapshot(p)
		var result: Dictionary = p.migrate_legacy_event_scope("npc_social","npc_social_progress",_valid_social)
		_check(result.get("status")=="extension_quarantined" and _snapshot(p)==before and FileAccess.get_file_as_bytes(p.save_path)==original and p._retained_fields.has("npc_social_progress") and not p.read_only,scenario+": migration preserves exact ambiguous evidence and banks")
		var economy := EconomySession.new(); economy.initialize(p,GearInventory.new())
		_check(economy.buy_upgrade(&"max_hp") and p.souls==80 and p.material_stash[&"linen_fiber"]==8,scenario+": unrelated HP upgrade remains writable with no help charge")
		_check(_span(p,LEGACY)==(duplicate if scenario=="legacy_duplicate" else valid_span) and (scenario!="namespace_duplicate" or _span(p,SOCIAL)==scope),scenario+": HP save retains every original raw span")
		var cold := SanctuaryProfile.new(); cold.save_path=p.save_path; cold.register_extension_validator("npc_social",_valid_social)
		_check(cold.load_profile() and cold.migrate_legacy_event_scope("npc_social","npc_social_progress",_valid_social).get("status")=="extension_quarantined" and cold.permanent_upgrades[&"max_hp"]==1 and cold.material_stash[&"linen_fiber"]==8,scenario+": reload cannot convert ambiguity into a valid new help authority")
	var missing: SanctuaryProfile = _fixture("missing_legacy_span")
	missing._retained_fields["npc_social_progress"]=_social_state()
	var image: PackedByteArray = FileAccess.get_file_as_bytes(missing.save_path)
	_check(missing.migrate_legacy_event_scope("npc_social","npc_social_progress",_valid_social).get("status")=="extension_quarantined" and FileAccess.get_file_as_bytes(missing.save_path)==image and not missing.read_only,"Missing durable legacy span cannot be migrated from RAM")
	var absent: SanctuaryProfile = _fixture("missing_namespace_span")
	_write_raw(absent,valid_span)
	absent._retained_fields["event_extensions"]={"schema_version":1,"namespaces":{"npc_social":{"revision":0,"state":_social_state(),"receipts":[]}}}
	_check(absent.migrate_legacy_event_scope("npc_social","npc_social_progress",_valid_social).get("status")=="extension_quarantined" and absent._retained_fields.has("npc_social_progress"),"An existing live namespace needs its exact durable span before migration")
func _stale_proposals() -> void:
	var p: SanctuaryProfile = _fixture("committed_replay")
	var a: Dictionary = _propose(p,"a")
	_check(p.commit_cultivation(a),"A commits its one crystal and progression receipt")
	_check(p.try_add_souls(3),"A is followed by a real Soul reward")
	var economy := EconomySession.new(); economy.initialize(p,GearInventory.new())
	_check(economy.buy_upgrade(&"max_hp"),"A is followed by a real HP purchase")
	_check(p.commit_cultivation(_propose(p,"b")),"B advances from the current source")
	var snapshot: String = _snapshot(p); var image: PackedByteArray = FileAccess.get_file_as_bytes(p.save_path)
	_check(p.commit_cultivation_proposal(a) and p.last_commit.get("status")=="already_committed" and _snapshot(p)==snapshot and FileAccess.get_file_as_bytes(p.save_path)==image,"Replay original A after B/reward/HP is success without rewriting any old snapshot")
	for mutation: String in ["reward","hp","b","bank","proof"]:
		var stale: SanctuaryProfile = _fixture("stale_"+mutation)
		var pending: Dictionary = _propose(stale,"pending_a")
		match mutation:
			"reward": _check(stale.try_add_souls(2),"Pending proposal source changes by Soul reward")
			"hp":
				var market := EconomySession.new(); market.initialize(stale,GearInventory.new()); _check(market.buy_upgrade(&"max_hp"),"Pending proposal source changes by real HP cost")
			"b": _check(stale.commit_cultivation(_propose(stale,"first_b")),"Pending A source changes by B")
			"bank": stale.material_stash[&"dust"]+=1; _check(stale.save(),"Pending source changes by bank save")
			"proof": _check(stale.record_boss_defeat("new_golem_proof"),"Pending source changes by actual proof receipt")
		var current: String = _snapshot(stale); var bytes: PackedByteArray = FileAccess.get_file_as_bytes(stale.save_path)
		_check(not stale.commit_cultivation(pending) and stale.last_commit.get("error")=="stale_cultivation_source" and _snapshot(stale)==current and FileAccess.get_file_as_bytes(stale.save_path)==bytes and not stale.read_only,mutation+": uncommitted stale A is rejected before cost/state publication")
	var forged: Dictionary = _propose(p,"forged")
	forged["materials"]["crystal"]+=10
	_check(not p.commit_cultivation(forged) and p.last_commit.get("error")=="proposal_snapshot_mismatch","A fresh identity cannot smuggle a changed output snapshot")
	_check(not p.commit_cultivation({"ok":true,"already_committed":true}),"An unverified replay flag cannot bypass event authority")
func _realm_replay() -> void:
	var p: SanctuaryProfile = _fixture("realm_replay")
	var training: Dictionary = Model.propose(p.cultivation_progress,p.material_stash,p.souls,p.boss_proofs,"train",{"actor_id":"player","sessions":5,"target_tick":40},"realm_training")
	_check(p.commit_cultivation(training),"Realm fixture pays its five training crystals")
	for n: int in 8: _check(p.commit_cultivation(_propose(p,"mastery_%d"%n,"mastery")),"Trusted model mastery fixture commits one event")
	for insight: String in Model.OBSERVATIONS: _check(p.commit_cultivation(_propose(p,"observe_"+insight,"observe",{"insight_id":insight})),"Realm fixture derives one prerequisite observation")
	for n: int in 2: _check(p.commit_cultivation(_propose(p,"refine_%d"%n,"breakthrough",{"actor_id":"player"})),"Explicit refinement pays its dust")
	var a: Dictionary = _propose(p,"realm_a","breakthrough",{"actor_id":"player"})
	_check(p.try_add_souls(1) and not p.commit_cultivation(a,{},Callable(),"tether_sigil") and p.cultivation_abilities()["learned_ids"].is_empty() and p.cultivation_progress["actors"]["player"]["stage"]==2,"Uncommitted stale realm proposal cannot charge or unlock after reward")
	a=_propose(p,"realm_a","breakthrough",{"actor_id":"player"})
	_check(p.commit_cultivation(a,{},Callable(),"tether_sigil") and p.souls==96 and p.cultivation_abilities()["learned_ids"]==["tether_sigil"],"Fresh realm A pays five Souls and unlocks exactly one branch")
	var economy := EconomySession.new(); economy.initialize(p,GearInventory.new())
	_check(p.try_add_souls(2) and economy.buy_upgrade(&"max_hp") and p.commit_cultivation(_propose(p,"post_realm_b","mastery")),"Reward/HP/B occur after the branch receipt")
	var snapshot: String = _snapshot(p); var image: PackedByteArray = FileAccess.get_file_as_bytes(p.save_path)
	_check(p.commit_cultivation(a,{},Callable(),"tether_sigil") and _snapshot(p)==snapshot and FileAccess.get_file_as_bytes(p.save_path)==image,"Realm A replay preserves later energy, stock, Soul/HP cost and chosen unlock")
	_check(not p.commit_cultivation(a,{},Callable(),"cloud_return") and _snapshot(p)==snapshot,"Replay cannot change the already selected branch")
	var cold := SanctuaryProfile.new(); cold.save_path=p.save_path
	_check(cold.load_profile() and cold.commit_cultivation(a,{},Callable(),"tether_sigil") and _snapshot(cold)==snapshot and FileAccess.get_file_as_bytes(cold.save_path)==image,"Cold replay uses the durable receipt and preserves later cost/unlock state")
func _courier_alias() -> void:
	var p: SanctuaryProfile = _fixture("courier_alias")
	_check(p.accept_courier_opportunity() and p.courier_objectives()["accepted"],"Courier adapter's accept API uses the canonical offer receipt")
	var image: PackedByteArray = FileAccess.get_file_as_bytes(p.save_path)
	_check(p.record_courier_offer() and p.accept_courier_opportunity() and FileAccess.get_file_as_bytes(p.save_path)==image,"Both courier API names replay one offer without another write")

func _material_capabilities() -> void:
	var p: SanctuaryProfile = _fixture("material_query")
	var economy := EconomySession.new(); var carried := GearInventory.new(); economy.initialize(p,carried)
	var image: PackedByteArray = FileAccess.get_file_as_bytes(p.save_path)
	for id: StringName in [&"aptitude_herb",&"aptitude_pill"]:
		var quote: Dictionary = economy.material_capability(id)
		_check(quote["known"] and quote["lineage_bound"] and quote["art_status"]=="missing_final" and not quote["can_deposit"] and not quote["can_withdraw"] and not economy.withdraw(id,1),"Lineage service card exposes read-only transfer and missing final icon state")
	_check(economy.material_capability(&"dust")["can_withdraw"] and economy.material_capability(&"unknown")["art_status"]=="unknown" and not economy.material_capability(&"unknown")["transfer_allowed"],"Ordinary and unknown material cards use the same generic policy")
	p.read_only=true
	_check(not economy.material_capability(&"dust")["can_withdraw"] and FileAccess.get_file_as_bytes(p.save_path)==image,"Material query is read-only and respects profile quarantine")

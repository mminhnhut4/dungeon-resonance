extends "res://tests/tan_dang_quest_test.gd"
## Owner-only contracts. Runtime contact/LOS and native motion need separate QA.
const HUB: String = "h00_traveler_hub"
const P01: String = "o01_p01"
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
var watched_life: NpcWorldState
var watched_signal_id: String = LAM
var living_signals: int = 0
var check_signal_commit: bool = false
var provisional_signal: bool = false

class LivingFault extends SanctuaryProfile:
	var primary: String = ""
	var copy_failure: bool = false
	func _copy_file(source: String,target: String) -> Error:
		if copy_failure and target.ends_with(".pre_living_v6.json"): return ERR_CANT_CREATE
		return super._copy_file(source,target)
	func _replace_file(temporary: String,target: String) -> bool:
		if not copy_failure and target==primary: return false
		return super._replace_file(temporary,target)

func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"): quit(2);return
	directory = "user://verification/tan_dang_living_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	_migration_six()
	_pending_six()
	_routines_and_gates()
	_help_and_receipts()
	_help_before_withdrawal()
	_ignore_harm_and_death()
	_boundary_faults()
	_negative_facts_and_wounds()
	_signal_contract()
	print("RESULT TanDangLivingState checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func _write_json(path: String,value: Dictionary) -> void:
	assert(path.begins_with(directory+"/"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(Writer.canonical(value));file.flush();file.close()

func _six(value: Dictionary) -> Dictionary:
	var source: Dictionary = value.duplicate(true)
	source["npc_schema"] = 6
	for id: String in TanDangProgress.NPC_IDS: source["records"][id].erase("living")
	return source

func _reader(path: String) -> NpcWorldState:
	var life := NpcWorldState.new()
	life.save_path = path
	return life

func _ready(label: String,branch: String = "rescue") -> TanDangProgress:
	var p: TanDangProgress = _fixture(label)
	_q1(p);_apply(p,"choice_"+branch,"refuge");_finish(p)
	p.life.set_active_room(HUB)
	return p

func _ticks(life: NpcWorldState,count: int) -> void:
	for _i: int in count: life.advance_ticks(1)

func _danger(label: String,branch: String = "rescue") -> TanDangProgress:
	var p: TanDangProgress = _ready(label,branch)
	_check(p.life.start_living_event(p.state()),"Lâm independently starts one post-q3 material trip")
	_ticks(p.life,80)
	_check(p.life.transfer_lam(P01),"Canonical NPC door handoff at Hub endpoint")
	p.life.set_active_room(P01)
	_ticks(p.life,80)
	_check(p.life.advance_living_event(LAM,"collecting","danger"),"Danger starts only after actual owner movement and collection dwell")
	return p

func _home(life: NpcWorldState) -> void:
	_ticks(life,100)
	_check(life.transfer_lam(HUB),"Returning NPC crosses P01 door only at endpoint")
	life.set_active_room(HUB)
	_ticks(life,80)
	_check(life.living_view(LAM)["event_phase"]=="done" and life.records[LAM]["room"]==HUB,"Same life returns home and commits terminal finite receipt")

func _migration_six() -> void:
	var p: TanDangProgress = _ready("migration_donor")
	_check(p.life.receive_hit(DU,1.0,1300,true,NAN,true,[LAM,MOC]) and p.life.decide(DU,p.life.decision_token(DU),false) and p.life.recover_after_expedition(),"Donor records real hurt, witnesses and mercy")
	_check(p.life.report_cause(DU,"attacked",DU,HUB),"Donor has a bounded published report")
	_apply(p,"reconcile",DU,DU)
	_kill(p,MOC)
	var source: Dictionary = _six(p.life.snapshot())
	_check(NpcWorldState.valid(source),"Exact NPC6 shape including old causality remains accepted")
	var path: String = directory+"/six/profile.json.npc_v1.json"
	_write_json(path,source)
	var original: PackedByteArray = _raw(path)
	var life: NpcWorldState = _reader(path)
	_check(life.load_state() and life.snapshot()["npc_schema"]==NpcWorldState.SCHEMA,"NPC6 migrates via existing life owner")
	_check(_raw(path+".pre_living_v6.json")==original,"Immutable NPC6 backup preserves exact original bytes")
	for id: String in NpcPilotCatalog.IDS:
		var retained: Dictionary = life.records[id].duplicate(true)
		retained.erase("living")
		_check(retained==source["records"][id],"All prior fields survive schema6→7: "+id)
	_check(life.records[DU]["causality"]["reconciled"] and life.records[DU]["causality"]["peace_used"] and not life.records[DU]["causality"]["reports"].is_empty(),"Migration does not reset peace, harm, testimony or witness source")
	_check(life.records[MOC]["mode"]=="dead" and life.recover_after_expedition() and life.records[MOC]["mode"]=="dead","Migration preserves terminal death across expedition recovery")
	var cold: NpcWorldState = _reader(path)
	_check(cold.load_state() and cold.snapshot()==life.snapshot() and _raw(path+".pre_living_v6.json")==original,"Cold reopen neither rewrites history nor immutable backup")
	for copy_failure: bool in [true,false]:
		var fault_path: String = directory+"/migration_fault_%s/profile.json.npc_v1.json" % copy_failure
		_write_json(fault_path,source)
		var fault := LivingFault.new();fault.primary=fault_path;fault.copy_failure=copy_failure
		life = _reader(fault_path);life.io=fault
		_check(not life.load_state() and life.read_only and life.snapshot()["npc_schema"]==6,"Backup/replace fault leaves NPC6 authority quarantined")
		# A refused migration intentionally retains parsed historical values;
		# JSON turns integer-valued floats into a different native Variant type.
		_check(Writer.canonical(life.snapshot())==Writer.canonical(source) and _raw(fault_path)==original,"Every historical value and exact primary byte survives failed migration")
		var retry: NpcWorldState = _reader(fault_path)
		_check(retry.load_state() and retry.records[MOC]["mode"]=="dead","Fresh retry retains the same terminal life")
	var conflict: String = directory+"/migration_conflict/profile.json.npc_v1.json"
	_write_json(conflict,source)
	var other: Dictionary = source.duplicate(true);other["tick"]+=1
	_write_json(conflict+".pre_living_v6.json",other)
	life = _reader(conflict)
	_check(not life.load_state() and life.read_only and _raw(conflict)==original,"Conflicting immutable backup never authorizes overwrite")
	var missing: String = directory+"/migration_missing/profile.json.npc_v1.json"
	_write_json(missing+".pre_living_v6.json",source)
	life = _reader(missing)
	_check(not life.load_state() and life.read_only and not life.save(),"Missing primary with schema6 history cannot mint new residents")
	var future: Dictionary = source.duplicate(true);future["npc_schema"]=8
	var future_path: String = directory+"/migration_future/profile.json.npc_v1.json";_write_json(future_path,future)
	life = _reader(future_path)
	_check(not life.load_state() and life.read_only and not life.save(),"Unknown future schema is read-only")

func _pending_six() -> void:
	# A real journal2 interruption, encoded with historical NPC6 participants.
	# Only this protocol fixture reseals; production recovery remains unchanged.
	var p: TanDangProgress = _fixture("pending_six")
	_q1(p)
	p.profile._writer.fault_plan = {"compound_after_decision":true}
	_check(not p.apply("choice_gate","","refuge").get("ok",false),"Declared writer fault stops after durable compound decision")
	var npc_path: String = p.life.save_path
	for path: String in [npc_path,npc_path+".compound.tmp"]:
		var value: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		_write_json(path,_six(value))
	var decision_path: String = p.profile.save_path+".decision"
	var decision: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(decision_path))
	decision["npc"]["before_sha256"] = NpcWorldState._byte_hash(npc_path)
	decision["npc"]["after_sha256"] = NpcWorldState._byte_hash(npc_path+".compound.tmp")
	decision.erase("seal");decision["seal"]=Writer.canonical(decision).sha256_text()
	_write_json(decision_path,decision)
	var decided: PackedByteArray = _raw(npc_path+".compound.tmp")
	var blocked: NpcWorldState = _reader(npc_path)
	_check(not blocked.load_state() and blocked.read_only and not blocked.save() and not FileAccess.file_exists(npc_path+".pre_living_v6.json"),"Standalone life loader cannot migrate a pending NPC6 participant")
	var profile := SanctuaryProfile.new();profile.save_path=p.profile.save_path;profile.register_extension_validator(SCOPE,TanDangProgress.valid)
	_check(profile.load_profile() and _raw(npc_path)==decided and not FileAccess.file_exists(decision_path),"Original writer finishes sealed NPC6 bytes before migration")
	var life: NpcWorldState = _reader(npc_path)
	_check(life.load_state() and life.records[DU]["mode"]=="dead" and _raw(npc_path+".pre_living_v6.json")==decided,"Only after roll-forward does owner migrate the decided death to7")
	var final_bytes: PackedByteArray = _raw(npc_path)
	life = _reader(npc_path)
	_check(life.load_state() and _raw(npc_path)==final_bytes and profile.extension_state(SCOPE)["choice"]=="gate","Second reopen neither repeats receipt nor changes branch")

func _routines_and_gates() -> void:
	var p: TanDangProgress = _fixture("routines")
	var life: NpcWorldState = p.life
	var before_moc: Dictionary = life.records[MOC].duplicate(true)
	var before_lam: Dictionary = life.records[LAM].duplicate(true)
	var before_du: Dictionary = life.records[DU].duplicate(true)
	_ticks(life,120)
	_check(life.records[MOC]==before_moc and life.records[LAM]==before_lam,"No active room means no autonomous Tàn Đăng progress")
	life.set_active_room(HUB);_ticks(life,100)
	_check(life.records[MOC]["x"]!=before_moc["x"] and life.records[LAM]==before_lam and life.records[DU]==before_du,"Only the active resident follows a real bounded route")
	_check(not life.start_living_event(p.state()),"No materials event can bypass the existing quest")
	life.set_active_room("o01_p03");_ticks(life,140)
	_check(life.records[LAM]["x"]>=1310.0 and life.records[LAM]["x"]<=1500.0 and life.records[DU]==before_du,"Lâm stays beside core; Dư cannot leave sustaining core early")
	var old: Dictionary = life.snapshot();life.compound_locked=true;_ticks(life,20)
	_check(life.snapshot()==old and not life.start_living_event(p.state()),"Compound lock fences routines and new event commits")
	life.compound_locked=false;life.read_only=true;_ticks(life,20)
	_check(life.snapshot()==old,"Quarantined state cannot simulate new facts")

func _help_and_receipts() -> void:
	var p: TanDangProgress = _ready("help")
	var life: NpcWorldState = p.life
	var trust: int = life.records[LAM]["trust"]
	_check(life.mark_living_greeted(LAM,"quest_help") and not life.mark_living_greeted(LAM,"quest_help") and life.records[LAM]["trust"]==trust,"Quest gratitude has one independent acknowledgement and no trust payout")
	_check(life.start_living_event(p.state()) and not life.start_living_event(p.state()),"One authored life starts the trip once")
	_check(not life.transfer_lam(P01),"Door transfer refuses teleport from Hub starting point")
	_ticks(life,80)
	_check(life.transfer_lam(P01),"Outbound endpoint hands off canonical room")
	var frozen: Dictionary = life.records[LAM].duplicate(true);_ticks(life,40)
	_check(life.records[LAM]==frozen,"NPC freezes after crossing while player remains in Hub")
	life.set_active_room(P01)
	_check(not life.advance_living_event(LAM,"collecting","danger"),"Threat cannot start before material destination and dwell")
	_ticks(life,80);_check(life.advance_living_event(LAM,"collecting","danger"),"Collection boundary commits danger")
	var cold: NpcWorldState = _reader(life.save_path)
	_check(cold.load_state() and cold.living_view(LAM)["event_phase"]=="danger","Cold reload retains a pending encounter without starting another trip")
	var gratitude: int = life.karma(LAM)["gratitude"]
	var bank: Dictionary = p.profile.material_stash.duplicate(true)
	var profile_bytes: PackedByteArray = _raw(p.profile.save_path)
	_check(not life.resolve_living_event(LAM,"helped"),"Standing nearby cannot claim help without accepted-contact credit")
	_check(life.credit_living_help(LAM) and not life.credit_living_help(LAM),"Accepted threat contact is credited at most once")
	_check(life.resolve_living_event(LAM,"helped") and life.karma(LAM)["gratitude"]==gratitude+1 and not life.resolve_living_event(LAM,"helped"),"One resolved help adds old-owner gratitude once")
	_check(p.profile.material_stash==bank and _raw(p.profile.save_path)==profile_bytes,"Event itself grants no currency, inventory or profile receipt")
	_check(not life.report_living_event(MOC) and not life.report_living_event(DU),"An off-room listener does not learn event outcome")
	_home(life)
	_check(life.mark_living_greeted(LAM,"forage_help") and not life.mark_living_greeted(LAM,"forage_help") and life.records[LAM]["trust"]==trust,"Forage thanks remains available after earlier quest thanks; neither farms trust")
	var historical: Dictionary = life.records[LAM]["living"].duplicate(true)
	_apply(p,"assist",LAM,LAM)
	_check(life.records[LAM]["living"]==historical and p.profile.material_stash[&"linen_fiber"]==int(bank[&"linen_fiber"])+2,"Existing aid compound preserves living receipt and grants original2linen once")
	_unchanged_rejection(p,"assist",LAM,LAM)
	_check(not life.start_living_event(p.state()),"Finished life cannot replay materials event")
	# Model fixture declares calm co-location; runtime separately proves LOS/dwell.
	life.records[DU]["x"]=1385.0;life.records[DU]["target"]=1385.0;life.records[DU]["mode"]="rest";life.records[DU]["remaining"]=8
	life.records[LAM]["x"]=1345.0;life.records[LAM]["target"]=1345.0;life.records[LAM]["mode"]="rest";life.records[LAM]["remaining"]=8
	_check(life.save() and life.report_living_event(DU) and not life.report_living_event(DU),"Same-room calm conversation publishes one bounded source receipt")
	_check(life.living_view(DU)["heard_materials"] and life.living_view(DU)["heard_outcome"]=="helped" and not life.living_view(MOC)["heard_materials"],"Only the actual listener learns Lâm's completed outcome")
	p = _cold(p);life=p.life;life.set_active_room(HUB)
	_check(life.living_view(DU)["heard_materials"] and life.living_view(LAM)["acknowledged"]["forage_help"] and not life.mark_living_greeted(LAM,"forage_help"),"Cold reopen preserves knowledge and independent greeting receipts")
	var copy: Dictionary = life.living_view(LAM);copy["acknowledged"]["forage_help"]=false
	_check(life.living_view(LAM)["acknowledged"]["forage_help"],"Read projection cannot mutate canonical receipts")
	var g: TanDangProgress = _danger("gate_help","gate")
	_check(not g.life.karma(LAM)["helped"] and g.life.credit_living_help(LAM) and g.life.resolve_living_event(LAM,"helped") and not g.life.karma(LAM)["helped"],"New encounter help never forges the old quest-help flag")

func _help_before_withdrawal() -> void:
	for floor_hit: bool in [false,true]:
		var p: TanDangProgress = _danger("help_withdraw_%s" % floor_hit,"gate")
		var life: NpcWorldState = p.life
		var gratitude: int = life.karma(LAM)["gratitude"]
		var profile_bytes: PackedByteArray = _raw(p.profile.save_path)
		_check(life.credit_living_help(LAM) and not life.living_view(LAM)["forage_help"] and not life.mark_living_greeted(LAM,"forage_help"),"Pending accepted contact alone cannot publish a resolved thank-you")
		if not floor_hit:
			_check(life.receive_hit(LAM,NpcPilotCatalog.maximum_health(LAM)*0.5,520.0,false),"Chosen retreat follows actual non-Player injury")
		var before: Dictionary = life.snapshot()
		var bytes: PackedByteArray = _raw(life.save_path)
		watched_life=life;watched_signal_id=LAM;living_signals=0;provisional_signal=false;check_signal_commit=true
		life.activity_changed.connect(_capture_living_signal)
		var fault := LivingFault.new();fault.primary=life.save_path;life.io=fault
		var resolved: bool = life.receive_hit(LAM,1.0,520.0,false) if floor_hit else life.resolve_living_event(LAM,"withdrew")
		_check(not resolved and life.snapshot()==before and _raw(life.save_path)==bytes and living_signals==0,"Failed assisted retreat rolls back HP, outcome and gratitude without provisional notification")
		life.io=SanctuaryProfile.new()
		resolved = life.receive_hit(LAM,1.0,520.0,false) if floor_hit else life.resolve_living_event(LAM,"withdrew")
		_check(resolved and living_signals==1 and not provisional_signal,"Assisted retreat publishes one notification after its durable result")
		_check(life.living_view(LAM)["outcome"]=="withdrew" and life.living_view(LAM)["forage_help"] and life.karma(LAM)["gratitude"]==gratitude+1,"Actual help is remembered even though Lâm keeps his decision to withdraw")
		_check(not life.resolve_living_event(LAM,"withdrew") and not life.resolve_living_event(LAM,"helped") and living_signals==1,"Resolved retreat cannot pay again or be rewritten as a victory")
		_check(_raw(p.profile.save_path)==profile_bytes and not life.karma(LAM)["helped"] and not life.karma(LAM)["spared"],"Retreat assistance invents no quest help, mercy or profile reward")
		_check(life.receive_hit(LAM,life.records[LAM]["hp"],520.0,false) and life.karma(LAM)["gratitude"]==gratitude+1,"A later monster hit during return cannot replay the resolved assistance")
		_check(not provisional_signal,"Both retreat paths publish only canonical committed facts")
		check_signal_commit=false;watched_life=null
		var cold: NpcWorldState = _reader(life.save_path)
		_check(cold.load_state() and cold.living_view(LAM)["forage_help"] and cold.living_view(LAM)["outcome"]=="withdrew" and cold.karma(LAM)["gratitude"]==gratitude+1,"Cold reopen preserves assisted retreat without another gratitude payout")
		cold.set_active_room(P01);_home(cold)
		if floor_hit:
			_check(not cold.mark_living_greeted(LAM,"forage_help") and cold.recover_after_expedition(),"Severely wounded helper cannot speak before existing recovery boundary")
		_check(cold.mark_living_greeted(LAM,"forage_help") and not cold.mark_living_greeted(LAM,"forage_help") and NpcWorldState.valid(cold.snapshot()),"Assisted retreat supports one valid independent gratitude greeting")
		var reopened: NpcWorldState = _reader(cold.save_path)
		_check(reopened.load_state() and reopened.living_view(LAM)["acknowledged"]["forage_help"] and reopened.karma(LAM)["gratitude"]==gratitude+1,"Greeting and gratitude survive another cold reopen without replay")
	var p: TanDangProgress = _danger("help_then_harm_retreat","gate")
	var life: NpcWorldState = p.life
	var gratitude: int = life.karma(LAM)["gratitude"]
	_check(life.credit_living_help(LAM) and life.receive_hit(LAM,30.0,520.0,true) and life.receive_hit(LAM,1.0,520.0,false),"Friendly fire remains authoritative even when a monster later forces withdrawal")
	_check(life.living_view(LAM)["outcome"]=="interrupted" and not life.living_view(LAM)["forage_help"] and life.karma(LAM)["gratitude"]==gratitude and not life.mark_living_greeted(LAM,"forage_help"),"Help then harm cannot become gratitude through the non-Player floor path")
	p=_danger("withdraw_then_later_harm","gate");life=p.life
	_check(life.credit_living_help(LAM) and life.resolve_living_event(LAM,"withdrew"),"Earlier assisted retreat is a committed historical fact")
	gratitude=life.karma(LAM)["gratitude"]
	_check(life.receive_hit(LAM,30.0,520.0,true) and life.living_view(LAM)["outcome"]=="withdrew" and life.living_view(LAM)["forage_help"] and life.karma(LAM)["gratitude"]==gratitude,"Later harm preserves earlier assisted retreat without adding gratitude")
	_check(not life.mark_living_greeted(LAM,"forage_help"),"Historical assistance cannot bypass current injury for a grateful greeting")
	_unchanged_rejection(p,"assist",LAM,LAM)

func _ignore_harm_and_death() -> void:
	var p: TanDangProgress = _danger("ignore")
	var life: NpcWorldState = p.life
	var karma: Dictionary = life.karma(LAM)
	_check(life.resolve_living_event(LAM,"self") and life.karma(LAM)==karma,"Ignoring an encounter adds neither offense nor invented gratitude")
	_home(life)
	p = _danger("nonplayer_withdraw");life=p.life;karma=life.karma(LAM)
	_check(life.receive_hit(LAM,1.0,520.0,false) and life.records[LAM]["mode"]=="walk" and life.decision_token(LAM).is_empty(),"Monster floor auto-withdraws without a player spare/kill prompt")
	_check(life.living_view(LAM)["outcome"]=="withdrew" and life.karma(LAM)==karma and not life.karma(LAM)["spared"] and life.records[LAM]["hp"]==1.0,"Withdrawal grants no spare, gratitude or healing")
	_home(life)
	_check(life.records[LAM]["hp"]==1.0 and life.records[LAM]["mode"]=="recovering" and life.living_view(LAM)["convalescing"],"Severe wound reaches home convalescence without healing HP")
	var wounded: NpcWorldState = _reader(life.save_path)
	_check(wounded.load_state() and wounded.records[LAM]["hp"]==1.0 and wounded.living_view(LAM)["convalescing"],"Cold reopen preserves severe wound and finite convalescence")
	wounded.set_active_room(HUB);_ticks(wounded,160)
	_check(wounded.records[LAM]["hp"]==1.0 and wounded.records[LAM]["mode"]=="recovering","Idle time cannot heal or send a severely wounded resident back to work")
	_check(wounded.recover_after_expedition() and wounded.records[LAM]["hp"]==NpcPilotCatalog.maximum_health(LAM)*0.5 and not wounded.living_view(LAM)["convalescing"] and wounded.karma(LAM)==karma,"Only actual expedition boundary recovers the wound; no mercy or gratitude is invented")
	p = _danger("harm");life=p.life
	_check(life.credit_living_help(LAM) and life.receive_hit(LAM,1.0,520.0,true),"Player harm after genuine help stays authoritative")
	_check(life.records[LAM]["mode"]=="downed" and not life.decision_token(LAM).is_empty() and life.living_view(LAM)["outcome"]=="interrupted" and not life.resolve_living_event(LAM,"helped"),"Player injury never auto-spares and invalidates uncommitted gratitude")
	var gratitude: int = life.karma(LAM)["gratitude"]
	_check(life.decide(LAM,life.decision_token(LAM),false) and life.karma(LAM)["gratitude"]==gratitude and life.recover_after_expedition(),"Existing explicit mercy/expedition boundaries retain offense and cannot farm event credit")
	_check(life.living_view(LAM)["event_phase"]=="returning" and not life.mark_living_greeted(LAM,"forage_help"),"Recovered harmed resident can return but cannot thank for the interrupted event")
	_home(life)
	_check(not life.start_living_event(p.state()) and life.records[LAM]["causality"]["harmed"],"Return and routine never erase harm or reset encounter capacity")
	p = _danger("terminal");life=p.life
	_check(life.receive_hit(LAM,1.0,520.0,true) and life.decide(LAM,life.decision_token(LAM),true,true),"Explicit player execution remains canonical in P01")
	var dead: Dictionary = life.records[LAM].duplicate(true);_ticks(life,160);life.recover_after_expedition()
	_check(life.records[LAM]==dead and not life.transfer_lam(HUB) and not life.mark_living_greeted(LAM,"quest_help") and not life.report_living_event(DU),"Dead NPC cannot travel, speak, report or recover")
	var cold: NpcWorldState = _reader(life.save_path)
	_check(cold.load_state() and cold.records[LAM]==dead,"Cold load retains exact terminal P01 life")

func _boundary_faults() -> void:
	var p: TanDangProgress = _ready("faults")
	var life: NpcWorldState = p.life
	var before: Dictionary = life.snapshot()
	var bytes: PackedByteArray = _raw(life.save_path)
	var fault := LivingFault.new();fault.primary=life.save_path;life.io=fault
	_check(not life.start_living_event(p.state()) and life.snapshot()==before and _raw(life.save_path)==bytes,"Failed event start publishes no movement or receipt")
	life.io=SanctuaryProfile.new();_check(life.start_living_event(p.state()),"Start retries once after transient IO fault")
	_ticks(life,80);before=life.snapshot();bytes=_raw(life.save_path);life.io=fault
	_check(not life.transfer_lam(P01) and life.snapshot()==before and _raw(life.save_path)==bytes,"Failed door commit leaves NPC in its original room")
	life.io=SanctuaryProfile.new();_check(life.transfer_lam(P01),"Door retries from the same endpoint")
	life.set_active_room(P01);_ticks(life,80);before=life.snapshot();bytes=_raw(life.save_path);life.io=fault
	_check(not life.advance_living_event(LAM,"collecting","danger") and life.snapshot()==before and _raw(life.save_path)==bytes,"Failed danger commit cannot authorize threat spawn")
	life.io=SanctuaryProfile.new();_check(life.advance_living_event(LAM,"collecting","danger"),"Danger can retry after IO recovery")
	before=life.snapshot();bytes=_raw(life.save_path);life.io=fault
	_check(not life.credit_living_help(LAM) and life.snapshot()==before and _raw(life.save_path)==bytes,"Failed accepted-contact receipt does not expose provisional help")
	life.io=SanctuaryProfile.new();_check(life.credit_living_help(LAM),"Contact can be credited after a later actual accepted hit")
	before=life.snapshot();bytes=_raw(life.save_path);life.io=fault
	_check(not life.resolve_living_event(LAM,"helped") and life.snapshot()==before and _raw(life.save_path)==bytes,"Failed resolution leaves encounter pending with no gratitude payout")
	life.io=SanctuaryProfile.new();_check(life.resolve_living_event(LAM,"helped"),"Resolved result commits once after recovery")
	_home(life)
	before=life.snapshot();bytes=_raw(life.save_path);life.io=fault
	_check(not life.mark_living_greeted(LAM,"forage_help") and life.snapshot()==before and _raw(life.save_path)==bytes,"Failed greeting acknowledgement neither mutates trust nor consumes the line")

func _negative_facts_and_wounds() -> void:
	var empty: Dictionary = NpcWorldState.new().snapshot()
	var bad: Dictionary = empty.duplicate(true);bad["records"][LAM]["living"]["event_phase"]="forever"
	_check(not NpcWorldState.valid(bad),"Unknown event phase cannot enter the finite schema")
	bad=empty.duplicate(true);bad["records"][LAM]["room"]=P01;bad["records"][LAM]["x"]=150.0;bad["records"][LAM]["target"]=150.0
	_check(not NpcWorldState.valid(bad),"No P01 material expedition can appear without its start fact")
	bad=empty.duplicate(true);bad["records"][DU]["living"]["heard_materials"]=true
	_check(not NpcWorldState.valid(bad),"A listener cannot have a report without any resolved source event")
	bad=empty.duplicate(true);bad["records"][LAM]["living"]["acknowledged"]["forage_help"]=true
	_check(not NpcWorldState.valid(bad),"Forage greeting cannot precede its actual help result")
	bad=empty.duplicate(true);bad["records"][LAM]["living"]["convalescing"]=true
	_check(not NpcWorldState.valid(bad),"Convalescence requires a real wounded returned event")
	bad["records"][LAM]["hp"]="broken"
	_check(not NpcWorldState.valid(bad),"Malformed convalescent HP is rejected without invoking numeric operators")
	bad=empty.duplicate(true);bad["records"][MOC]["living"]["extra_receipt"]=true
	_check(not NpcWorldState.valid(bad),"Living facts cannot silently grow into an unbounded ledger")
	var p: TanDangProgress = _danger("nonfatal_harm")
	var life: NpcWorldState = p.life
	var hp: float = NpcPilotCatalog.maximum_health(LAM)-1.0
	_check(life.receive_hit(LAM,hp,520.0,true) and life.records[LAM]["mode"]=="flee" and life.living_view(LAM)["outcome"]=="interrupted","Nonfatal Player harm interrupts the event with real flee state")
	_home(life)
	_check(life.living_view(LAM)["convalescing"] and life.records[LAM]["mode"]=="rest" and life.records[LAM]["hp"]==hp,"Partial wound stays visible resting at home without fake healing")
	var before: Dictionary = life.records[LAM].duplicate(true);_ticks(life,200)
	_check(life.records[LAM]==before,"A wounded partial-HP resident does not resume work on an idle timer")
	var cold: NpcWorldState = _reader(life.save_path)
	_check(cold.load_state() and cold.records[LAM]==before,"Reopen retains partial wound and convalescence")
	cold.set_active_room(HUB)
	_check(cold.recover_after_expedition() and not cold.living_view(LAM)["convalescing"] and cold.records[LAM]["hp"]==hp and cold.records[LAM]["causality"]["harmed"],"Expedition clears convalescence without reducing HP above the existing half-health floor or erasing harm")
	_ticks(cold,20)
	_check(cold.records[LAM]["x"]!=before["x"] or cold.records[LAM]["mode"]=="walk","Existing routine resumes only after canonical recovery")
	p=_danger("later_harm");life=p.life
	_check(life.credit_living_help(LAM) and life.resolve_living_event(LAM,"helped"),"Declared earlier help is already committed")
	var gratitude: int = life.karma(LAM)["gratitude"]
	_check(life.receive_hit(LAM,hp,520.0,true) and life.living_view(LAM)["outcome"]=="helped" and life.karma(LAM)["gratitude"]==gratitude,"A later assault cannot rewrite earlier help chronology or pay another gratitude")
	_home(life)
	_check(not life.mark_living_greeted(LAM,"forage_help") and life.records[LAM]["causality"]["harmed"],"Historical help cannot make an injured NPC offer a fresh grateful greeting")
	_unchanged_rejection(p,"assist",LAM,LAM)
	p=_danger("partial_withdraw");life=p.life
	gratitude=life.karma(LAM)["gratitude"]
	_check(life.receive_hit(LAM,hp,520.0,false) and life.resolve_living_event(LAM,"withdrew"),"Actual nonfatal monster injury can lead to a chosen retreat")
	_check(life.karma(LAM)["gratitude"]==gratitude and not life.living_view(LAM)["forage_help"],"Unassisted chosen retreat invents neither gratitude nor help memory")
	_home(life)
	before=life.snapshot();var bytes: PackedByteArray=_raw(life.save_path)
	var fault := LivingFault.new();fault.primary=life.save_path;life.io=fault
	_check(not life.recover_after_expedition() and life.snapshot()==before and _raw(life.save_path)==bytes,"Failed recovery commit retains wound, convalescence and all receipt bytes")
	life.io=SanctuaryProfile.new()
	_check(life.recover_after_expedition() and life.records[LAM]["hp"]==hp and not life.living_view(LAM)["convalescing"] and not life.karma(LAM)["spared"],"Recovery retry preserves high HP and never labels monster retreat as player mercy")

func _capture_living_signal(id: String,_activity: String) -> void:
	if id!=watched_signal_id: return
	living_signals += 1
	if check_signal_commit:
		var durable: Variant = JSON.parse_string(FileAccess.get_file_as_string(watched_life.save_path))
		if Writer.canonical(durable)!=Writer.canonical(watched_life.snapshot()): provisional_signal=true

func _signal_contract() -> void:
	var p: TanDangProgress = _ready("signals")
	var life: NpcWorldState = p.life
	watched_life=life;living_signals=0;provisional_signal=false
	life.activity_changed.connect(_capture_living_signal)
	var fault := LivingFault.new();fault.primary=life.save_path
	life.io=fault;check_signal_commit=true
	_check(not life.start_living_event(p.state()) and living_signals==0,"Failed finite start emits no provisional journal notification")
	life.io=SanctuaryProfile.new()
	_check(life.start_living_event(p.state()) and living_signals==1,"Successful start publishes exactly once after its durable write")
	life.living_view(LAM)
	_check(not life.start_living_event(p.state()) and living_signals==1,"Read getters and repeated start emit nothing")
	check_signal_commit=false;_ticks(life,80)
	var prior: int=living_signals;check_signal_commit=true
	_check(life.transfer_lam(P01) and living_signals==prior+1,"Door handoff emits exactly once after commit")
	life.set_active_room(P01);check_signal_commit=false;_ticks(life,80)
	prior=living_signals;check_signal_commit=true
	_check(life.advance_living_event(LAM,"collecting","danger") and living_signals==prior+1,"Danger boundary immediately invalidates journal once")
	prior=living_signals
	_check(life.credit_living_help(LAM) and living_signals==prior+1 and not life.credit_living_help(LAM) and living_signals==prior+1,"Accepted help receipt emits once, replay emits nothing")
	prior=living_signals;life.io=fault
	_check(not life.resolve_living_event(LAM,"helped") and living_signals==prior,"Failed result cannot announce gratitude or return")
	life.io=SanctuaryProfile.new()
	_check(life.resolve_living_event(LAM,"helped") and living_signals==prior+1,"Resolved result emits one post-commit notification")
	check_signal_commit=false;_ticks(life,100)
	check_signal_commit=true;_check(life.transfer_lam(HUB),"Signal fixture returns through real NPC door")
	life.set_active_room(HUB);check_signal_commit=false;_ticks(life,56)
	prior=living_signals;check_signal_commit=true;life.advance_ticks(1)
	_check(life.living_view(LAM)["event_phase"]=="done" and living_signals==prior+1,"Home completion publishes its finite done receipt immediately")
	prior=living_signals
	_check(life.mark_living_greeted(LAM,"forage_help") and living_signals==prior+1 and not life.mark_living_greeted(LAM,"forage_help"),"Visible greeting acknowledgement publishes once and cannot repeat")
	# Explicit local-conversation fixture; no actor/LOS claim in this test.
	check_signal_commit=false
	life.records[DU]["x"]=1385.0;life.records[DU]["target"]=1385.0;life.records[DU]["mode"]="rest";life.records[DU]["remaining"]=8
	_check(life.save(),"Signal fixture saves the actual local listener")
	watched_signal_id=DU;prior=living_signals;check_signal_commit=true;life.io=fault
	_check(not life.report_living_event(DU) and living_signals==prior,"Failed report does not publish knowledge")
	life.io=SanctuaryProfile.new()
	_check(life.report_living_event(DU) and living_signals==prior+1 and not life.report_living_event(DU),"Direct report publishes exactly once after save")
	_check(not provisional_signal,"Every finite notification observes already committed canonical bytes")
	check_signal_commit=false;watched_life=null

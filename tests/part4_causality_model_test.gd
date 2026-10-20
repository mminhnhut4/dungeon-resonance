extends "res://tests/tan_dang_quest_test.gd"
## Pure owner/IO boundaries. No personal files or gameplay/traversal claims.
class CausalityFault extends SanctuaryProfile:
	var fail_copy: bool=true
	var primary: String=""
	func _copy_file(source: String,target: String) -> Error:
		if fail_copy and target.ends_with(".pre_causality_v5.json"):return ERR_CANT_CREATE
		return super._copy_file(source,target)
	func _replace_file(temporary: String,target: String) -> bool:
		if not fail_copy and target==primary:return false
		return super._replace_file(temporary,target)

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	directory="user://verification/part4_causality_model"
	_migrate_five();_public_facts();_mercy_and_peace()
	print("RESULT Part4CausalityModel checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

func _write_json(path: String,data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()

func _bytes(p: TanDangProgress) -> Dictionary:
	return {"profile":FileAccess.get_file_as_bytes(p.profile.save_path),"npc":FileAccess.get_file_as_bytes(p.life.save_path)}

func _five() -> Dictionary:
	var p: TanDangProgress=_fixture("five_donor")
	_q1(p);_apply(p,"choice_rescue","refuge")
	_check(p.life.receive_hit(DU,1.0,1300,true) and p.life.decide(DU,p.life.decision_token(DU),true,true),"Declared donor keeps rescue before a confirmed later death")
	_unchanged_rejection(p,"assist",DU,DU)
	var s: Dictionary=p.life.snapshot();s["npc_schema"]=5
	for id: String in TanDangProgress.NPC_IDS:
		s["records"][id].erase("causality")
		s["records"][id].erase("living")
	_check(NpcWorldState.valid(s),"Exact historical NPC5 record shape remains accepted")
	return s

func _migrate_five() -> void:
	var source: Dictionary=_five()
	var path: String=directory+"/old5/npc.json";_write_json(path,source)
	var original: PackedByteArray=FileAccess.get_file_as_bytes(path)
	var life:=NpcWorldState.new();life.save_path=path
	_check(life.load_state() and life.snapshot()["npc_schema"]==NpcWorldState.SCHEMA,"NPC5 migrates through its existing owner")
	_check(FileAccess.get_file_as_bytes(path+".pre_causality_v5.json")==original,"Immutable NPC5 byte backup predates migration")
	for id: String in TanDangProgress.NPC_IDS:
		var retained: Dictionary=life.records[id].duplicate(true);retained.erase("causality");retained.erase("living")
		_check(retained==source["records"][id],"No old life/karma/placement/UID identity field is reset: "+id)
	_check(life.records[DU]["mode"]=="dead" and life.records[DU]["causality"]["harmed"] and life.records[DU]["causality"]["witnesses"]["player_murder"].is_empty() and life.records[DU]["causality"]["reports"].is_empty(),"Legacy murder remains terminal/private; absent witness/report evidence is never invented")
	_check(life.recover_after_expedition() and life.records[DU]["mode"]=="dead","Migration never revives a saved terminal life")
	for copy_fails: bool in [true,false]:
		var fault_path: String=directory+"/fault_%s/npc.json"%copy_fails;_write_json(fault_path,source)
		var fault:=CausalityFault.new();fault.fail_copy=copy_fails;fault.primary=fault_path
		life=NpcWorldState.new();life.save_path=fault_path;life.io=fault
		_check(not life.load_state() and life.read_only and life.snapshot()["npc_schema"]==5 and FileAccess.get_file_as_bytes(fault_path)==original,"NPC5 backup/replace failure retains old authority, never exposes NPC6")
		life=NpcWorldState.new();life.save_path=fault_path
		_check(life.load_state() and life.records[DU]["mode"]=="dead","Fresh owner retries transient migration without changing death")
	var conflict: String=directory+"/conflict/npc.json";_write_json(conflict,source)
	var changed: Dictionary=source.duplicate(true);changed["tick"]+=1;_write_json(conflict+".pre_causality_v5.json",changed)
	life=NpcWorldState.new();life.save_path=conflict
	_check(not life.load_state() and life.read_only and FileAccess.get_file_as_bytes(conflict)==original,"Conflicting immutable NPC5 backup blocks migration")

func _public_facts() -> void:
	var p: TanDangProgress=_fixture("facts");var life: NpcWorldState=p.life
	_check(life.receive_hit(DU,1,1300,true,NAN,true,[LAM,MOC]),"Canonical injury records declared same-room observers only")
	_check(life.decide(DU,life.decision_token(DU),true,true,[LAM,MOC]),"Confirmed execution records contemporaneous witnesses")
	_check(life.records[DU]["causality"]["witnesses"]["player_murder"]==[LAM],"Offscreen MOC cannot be asserted as a P03 eyewitness")
	var before: PackedByteArray=FileAccess.get_file_as_bytes(life.save_path)
	_check(not life.report_cause(DU,"player_murder",MOC,String(ExteriorRouteCatalog.HUB)) and FileAccess.get_file_as_bytes(life.save_path)==before,"Uninformed keeper cannot fabricate a report or write")
	_check(not TanDangCausality.knows(life.records,DU,"player_murder",LAM),"A private witnessed fact is not yet a public institutional report")
	var fault:=CausalityFault.new();fault.fail_copy=false;fault.primary=life.save_path;life.io=fault
	_check(not life.report_cause(DU,"player_murder",LAM,"o01_p03") and life.records[DU]["causality"]["reports"].is_empty() and FileAccess.get_file_as_bytes(life.save_path)==before,"Failed report write publishes neither testimony nor false public knowledge")
	life.io=SanctuaryProfile.new()
	_check(life.report_cause(DU,"player_murder",LAM,"o01_p03"),"Living same-room witness can publish one local report")
	_check(TanDangCausality.knows(life.records,DU,"player_murder",LAM) and not TanDangCausality.knows(life.records,DU,"player_murder",MOC),"P03 publication does not tell the Hub or every faction")
	_check(p.knows_murder(LAM) and not p.knows_murder(MOC),"Invitation eligibility reads actual knowledge rather than undisclosed global murder facts")
	before=FileAccess.get_file_as_bytes(life.save_path)
	_check(not life.report_cause(DU,"player_murder",LAM,"o01_p03") and FileAccess.get_file_as_bytes(life.save_path)==before,"Duplicate publication has no write or repeat reward")
	p=_cold(p)
	_check(p.life.records[DU]["causality"]["reports"].size()==1 and not TanDangCausality.knows(p.life.records,DU,"player_murder",MOC),"Cold load retains report origin and bounded geographic knowledge")
	var bad: Dictionary=p.life.snapshot();bad["records"][DU]["causality"]["reports"].append(bad["records"][DU]["causality"]["reports"][0].duplicate())
	_check(not NpcWorldState.valid(bad),"Duplicate/unbounded report records are invalid save data")

func _mercy_and_peace() -> void:
	var p: TanDangProgress=_fixture("peace");_q1(p);_apply(p,"choice_rescue","refuge")
	var life: NpcWorldState=p.life
	_check(life.receive_hit(DU,1,1300,true),"After-rescue harm stays separate from gratitude")
	_unchanged_rejection(p,"reconcile",DU,DU)
	_check(life.decide(DU,life.decision_token(DU),false),"Actual life owner records mercy")
	_unchanged_rejection(p,"reconcile",DU,DU)
	_check(life.recover_after_expedition(),"Declared expedition boundary recovers the spared life")
	_unchanged_rejection(p,"reconcile",DU,DU)
	_finish(p)
	_check(life.report_cause(DU,"attacked",DU,String(ExteriorRouteCatalog.HUB)),"Declared model report exists before negotiated peace")
	var reports: Array=life.records[DU]["causality"]["reports"].duplicate(true)
	var trust: int=life.records[DU]["trust"];var bank: Dictionary=p.profile.material_stash.duplicate();var souls: int=p.profile.souls
	var before: Dictionary=_bytes(p)
	p.profile._writer.fault_plan={"write_candidate":true}
	_check(not p.apply("reconcile",DU,DU).get("ok",false) and _bytes(p)==before and life.karma(DU)["grievance"]=="attacked" and not life.records[DU]["causality"]["peace_used"],"Failed compound reconciliation cannot buy provisional forgiveness")
	p.profile._writer.fault_plan={}
	_apply(p,"reconcile",DU,DU)
	_check(life.karma(DU)["grievance"]=="" and life.karma(DU)["rescued"] and life.karma(DU)["spared"] and life.records[DU]["causality"]["harmed"] and life.records[DU]["causality"]["peace_used"] and life.records[DU]["trust"]==trust and life.records[DU]["causality"]["reports"]==reports,"Peace stops old retaliation but retains injury/rescue/mercy/trust/public-report history")
	_unchanged_rejection(p,"assist",DU,DU);_unchanged_rejection(p,"reconcile",DU,DU)
	_check(p.profile.material_stash==bank and p.profile.souls==souls,"Peace grants no materials, money or refreshed aid")
	p=_cold(p);life=p.life
	_check(life.records[DU]["causality"]["reconciled"],"Cold load restores limited peace")
	_check(life.receive_hit(DU,1,1300,true) and life.decide(DU,life.decision_token(DU),false) and life.recover_after_expedition(),"Reoffense and a second mercy still use ordinary life boundaries")
	_unchanged_rejection(p,"reconcile",DU,DU);_unchanged_rejection(p,"assist",DU,DU)
	_check(life.karma(DU)["grievance"]=="attacked" and not life.records[DU]["causality"]["reconciled"] and life.karma(DU)["gratitude"]==2,"Reoffense ends peace permanently without farming rescue/mercy gratitude")
	var neutral: TanDangProgress=_fixture("neutral_mercy")
	for _i: int in 2:
		_check(neutral.life.receive_hit(LAM,1,1300,false) and neutral.life.decide(LAM,neutral.life.decision_token(LAM),false) and neutral.life.recover_after_expedition(),"Non-player injury and mercy cycle remains valid")
	_check(neutral.life.karma(LAM)["gratitude"]==1,"Repeated mercy cannot farm gratitude even without player-caused injury")

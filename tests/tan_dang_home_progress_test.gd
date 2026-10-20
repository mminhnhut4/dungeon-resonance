extends "res://tests/tan_dang_quest_test.gd"
## Real profile/NPC transactions in an isolated root; no scripted reward grants.
const LEADER: String = TanDangProgress.LEADER
const DEPUTY: String = TanDangProgress.DEPUTY

func _run() -> void:
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: dedicated QA data root required"); quit(2); return
	directory = "user://verification/tan_dang_home_progress_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	for branch: String in ["gate","rescue"]: _home_branch(branch)
	_known_home_recipe()
	_purchase_failure()
	_unavailable_officers()
	print("RESULT tan_dang_home_progress checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _home_work(progress: TanDangProgress, branch: String = "rescue") -> void:
	_apply(progress,"accept",DEPUTY,DEPUTY)
	_unchanged_rejection(progress,"accept",DEPUTY,DEPUTY)
	_unchanged_rejection(progress,"q1_reward",DEPUTY,DEPUTY)
	_apply(progress,"observe_lamp","lamp")
	_apply(progress,"find_lam","refuge")
	_apply(progress,"inspect_core","refuge")
	_apply(progress,"q1_reward",DEPUTY,DEPUTY)
	_check(progress.earned_merit() == 2 and progress.state()["contribution"] == 2,"Deputy closes real investigation once: merit2 and contribution2")
	_unchanged_rejection(progress,"q1_reward",DEPUTY,DEPUTY)
	_apply(progress,"choice_"+branch,"refuge")
	if branch == "gate": _apply(progress,"install_core","lamp")
	_unchanged_rejection(progress,"report_moc",DEPUTY,DEPUTY)
	_apply(progress,"report_moc",MOC)
	_apply(progress,"report_lam",LAM)
	_apply(progress,"q3_reward",DEPUTY,DEPUTY)
	_check(progress.earned_merit() == 6 and progress.state()["contribution"] == 6,"Same three quest receipts produce merit6 and spendable contribution6")

func _home_branch(branch: String) -> void:
	var progress: TanDangProgress = _fixture("home_"+branch)
	var original_gear: StringName = progress.profile.starting_weapon
	var original_materials: Dictionary = progress.profile.material_stash.duplicate(true)
	var original_souls: int = progress.profile.souls
	_check(progress.officer_available(LEADER) and progress.officer_available(DEPUTY) and not progress.can_join(LEADER),"Two independent officers exist; leader cannot admit a fresh guest")
	_unchanged_rejection(progress,"accept",LEADER,LEADER)
	_unchanged_rejection(progress,"accept",DEPUTY,LEADER)
	_unchanged_rejection(progress,"join",LEADER,LEADER)
	_home_work(progress,branch)
	_unchanged_rejection(progress,"join",DEPUTY,DEPUTY)
	_unchanged_rejection(progress,"recipe",LEADER,LEADER)
	_unchanged_rejection(progress,"q3_reward",DEPUTY,DEPUTY)
	_check(progress.can_join(LEADER),"Leader accepts either completed story branch")
	_apply(progress,"recipe",DEPUTY,DEPUTY)
	_check(progress.known_recipe() and progress.state()["contribution"] == 0 and progress.earned_merit() == 6 and progress.can_join(LEADER),"Purchase spends6 once while lifetime merit and admission stay6")
	_unchanged_rejection(progress,"recipe",DEPUTY,DEPUTY)
	_apply(progress,"join",LEADER,LEADER)
	_unchanged_rejection(progress,"join",LEADER,LEADER)
	_check(progress.profile.starting_weapon == original_gear and progress.profile.material_stash == original_materials and progress.profile.souls == original_souls,"Home loop does not add gear restrictions, Souls fees or material rewards")
	progress = _cold(progress)
	_check(progress.earned_merit() == 6 and progress.state()["membership"] == "member" and progress.state()["contribution"] == 0,"Cold load preserves member, spent contribution and earned merit independently")
	for action: String in ["q1_reward","q3_reward","recipe"]:
		_unchanged_rejection(progress,action,DEPUTY,DEPUTY)
	var journey := TanDangJourney.new()
	journey.progress = progress
	var prior: Dictionary = progress.state()
	var npc_before: Dictionary = progress.life.snapshot()
	var before: PackedByteArray = _raw(progress.profile.save_path)
	for officer: String in [LEADER,DEPUTY]:
		journey.context = StringName(officer)
		_check(not journey._speaker_lines().is_empty(),"New officer has authored dialogue without story-NPC causality fields")
		journey.relation_rows()
	_check(progress.state() == prior and progress.life.snapshot() == npc_before and _raw(progress.profile.save_path) == before,"Officer dialogue/map reads cannot grant progress or rewrite owners")
	journey.free()
	_apply(progress,"leave",LEADER,LEADER)
	_check(progress.earned_merit() == 6 and progress.known_recipe() and progress.state()["membership"] == "left","Voluntary departure preserves earned merit and purchased knowledge")
	_unchanged_rejection(progress,"join",LEADER,LEADER)

func _known_home_recipe() -> void:
	var progress: TanDangProgress = _fixture("known_home",true)
	_home_work(progress)
	_apply(progress,"recipe",DEPUTY,DEPUTY)
	_check(progress.state()["contribution"] == 6 and not progress.state()["recipe_paid"] and progress.earned_merit() == 6,"Already-known recipe records one claim without charging contribution")
	_unchanged_rejection(progress,"recipe",DEPUTY,DEPUTY)

func _purchase_failure() -> void:
	var progress: TanDangProgress = _fixture("purchase_failure")
	_home_work(progress)
	progress.profile._writer.fault_plan = {"write_npc_candidate":true}
	_unchanged_rejection(progress,"recipe",DEPUTY,DEPUTY)
	_check(progress.available() and not progress.known_recipe() and progress.state()["contribution"] == 6,"Predecision write failure keeps purchase retryable and fully unpaid")
	progress.profile._writer.fault_plan = {"compound_after_decision":true}
	var result: Dictionary = progress.apply("recipe",DEPUTY,DEPUTY)
	_check(not result.get("ok",false) and not progress.available(),"Durable purchase decision failure fences both live owners")
	var owner := SanctuaryProfile.new()
	owner.save_path = progress.profile.save_path
	owner.register_extension_validator(SCOPE,TanDangProgress.valid)
	_check(owner.load_profile(),"Cold profile resolves the existing compound purchase decision")
	var npc := NpcWorldState.new()
	npc.save_path = owner.save_path+".npc_v1.json"
	_check(npc.load_state(),"Cold NPC reads the resolved same purchase participant")
	var restored := TanDangProgress.new()
	restored.initialize(owner,npc)
	_check(restored.available() and restored.known_recipe() and restored.state()["contribution"] == 0 and restored.earned_merit() == 6,"Recovered purchase has exactly one recipe claim, one charge and unchanged merit")
	_unchanged_rejection(restored,"recipe",DEPUTY,DEPUTY)

func _unavailable_officers() -> void:
	var progress: TanDangProgress = _fixture("officer_unavailable")
	_check(progress.life.receive_hit(DEPUTY,1.0,600.0,true),"Fixture downs deputy through existing life owner")
	_unchanged_rejection(progress,"accept",DEPUTY,DEPUTY)
	var journey := TanDangJourney.new()
	journey.progress = progress
	var fallback: Dictionary = journey.navigation_target(&"tan_dang_home")
	_check(fallback["room"] == ExteriorRouteCatalog.HUB and fallback["point"].x == TanDangJourney.LEDGER_X,"Unavailable deputy guidance falls back to the real ledger, not an absent actor")
	journey.free()
	_apply(progress,"accept","ledger")
	_check(progress.state()["accepted"],"Original ledger remains accessible while deputy is unavailable")
	var absent_leader: TanDangProgress = _fixture("leader_recovering")
	_home_work(absent_leader)
	_check(absent_leader.life.receive_hit(LEADER,1.0,float(absent_leader.life.records[LEADER]["x"])-20.0,true),"Fixture puts leader into recovery through the existing life owner")
	_check(absent_leader.life.records[LEADER]["mode"] == "recovering" and absent_leader.state()["membership"] == "guest" and absent_leader.earned_merit() == 6 and absent_leader.can_join(MOC) and not absent_leader.can_join(LEADER),"Completed guest retains a valid sponsor while the leader is recovering")
	_unchanged_rejection(absent_leader,"join",LEADER,LEADER)
	var admission_journey := TanDangJourney.new()
	admission_journey.progress = absent_leader
	var guidance: String = admission_journey._admission_step(absent_leader.state())
	var sponsor_name: String = NpcPilotCatalog.definition(MOC)["name"]
	fallback = admission_journey.navigation_target(&"tan_dang_home")
	_check(fallback["room"] == StringName(absent_leader.life.records[MOC]["room"]) and fallback["point"].x == float(absent_leader.life.records[MOC]["x"]) and fallback["hint"].contains(sponsor_name),"Recovering leader navigation selects the available original sponsor")
	_check(guidance.contains("Tông chủ hiện vắng mặt") and guidance.contains(sponsor_name) and guidance.contains("tự nguyện nhập môn") and not guidance.contains("còn cần một lời giới thiệu"),"Admission guidance names the same available sponsor instead of reporting a missing introduction")
	var complete: TanDangProgress = _fixture("no_remote_pardon")
	_home_work(complete)
	_kill(complete,MOC)
	_kill(complete,LAM)
	_check(not complete.can_join(LEADER),"A new leader does not recreate unavailable original sponsors")
	_unchanged_rejection(complete,"join",LEADER,LEADER)
	admission_journey.progress = complete
	guidance = admission_journey._admission_step(complete.state())
	_check(not complete.can_join(MOC) and not complete.can_join(LAM) and guidance.contains("còn cần một lời giới thiệu hợp lệ"),"Admission guidance still reports a genuinely missing sponsor")
	admission_journey.free()

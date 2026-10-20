extends SceneTree
## Finite quest commands against real isolated profile/NPC owners; no actor/UI.
const Cultivation = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const MOC: String = TanDangProgress.MOC
const LAM: String = TanDangProgress.LAM
const DU: String = TanDangProgress.DU
const SCOPE: String = TanDangProgress.SCOPE
var directory: String = ""
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)

func _raw(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func _fixture(label: String,known_recipe: bool = false) -> TanDangProgress:
	var profile := SanctuaryProfile.new()
	profile.save_path=directory+"/"+label+"/profile.json"
	profile.souls=200; profile.coins=17; profile.material_stash[&"linen_fiber"]=8
	profile.boss_proofs[&"golem"]=1
	_check(profile.save() and profile.commit_cultivation(Cultivation.initial_proposal(Cultivation.new_progress(7),profile.material_stash,profile.souls,profile.boss_proofs)),label+": profile initialized through canonical format2 migration")
	var npc := NpcWorldState.new(); npc.save_path=profile.save_path+".npc_v1.json"
	_check(npc.save(),label+": durable canonical NPC authority")
	var progress := TanDangProgress.new()
	_check(progress.initialize(profile,npc) and progress.available() and progress.state()==TanDangProgress.empty(),label+": new slice starts unaccepted without replacing other progress")
	if known_recipe:
		profile.discover(&"firestorm")
		_check(profile.last_save_ok and progress.known_recipe(),label+": recipe already discovered through original owner")
	return progress

func _apply(progress: TanDangProgress,action: String,place: String = "",actor_id: String = "") -> bool:
	var result: Dictionary=progress.apply(action,actor_id,place)
	var ok: bool=result.get("ok",false)
	_check(ok,action+" commits: "+str(result))
	return ok

func _unchanged_rejection(progress: TanDangProgress,action: String,place: String = "",actor_id: String = "") -> void:
	var profile_bytes: PackedByteArray=_raw(progress.profile.save_path)
	var npc_bytes: PackedByteArray=_raw(progress.life.save_path)
	var state: Dictionary=progress.state()
	var life: Dictionary=progress.life.snapshot()
	var result: Dictionary=progress.apply(action,actor_id,place)
	_check(not result.get("ok",false) and progress.state()==state and progress.life.snapshot()==life and _raw(progress.profile.save_path)==profile_bytes and _raw(progress.life.save_path)==npc_bytes,action+": rejected/replayed command changes no live state or save bytes")

func _q1(progress: TanDangProgress) -> void:
	_apply(progress,"accept","ledger")
	_apply(progress,"observe_lamp","lamp")
	_apply(progress,"find_lam","refuge")
	_apply(progress,"inspect_core","refuge")
	_apply(progress,"q1_reward")
	_check(progress.state()["contribution"]==2 and progress.state()["rewards"]==["q1"],"First quest rewards exactly two contribution once")

func _finish(progress: TanDangProgress) -> void:
	if progress.state()["core"]=="carried":
		_unchanged_rejection(progress,"report_moc",MOC)
		_apply(progress,"install_core","lamp")
	_apply(progress,"report_moc",MOC if progress.alive(MOC) else "ledger")
	_apply(progress,"report_lam",LAM if progress.alive(LAM) else "ledger")
	_apply(progress,"q3_reward")
	_check(progress.state()["contribution"]==6 and progress.state()["rewards"].size()==3 and progress.state()["membership"]=="guest","Guest completes all quests with enough contribution for the recipe")

func _kill(progress: TanDangProgress,id: String) -> void:
	_check(progress.life.receive_hit(id,1.0,float(progress.life.records[id]["x"])-20.0,true),"Real damage downs "+id)
	# Pure-model fixture explicitly declares same-room eyewitnesses/publication.
	var witnesses: Array[String]=[]
	for other: String in TanDangProgress.NPC_IDS:
		if other!=id and progress.alive(other) and progress.life.records[other]["room"]==progress.life.records[id]["room"]:witnesses.append(other)
	_check(progress.life.decide(id,progress.life.decision_token(id),true,true,witnesses),"Confirmed execution commits "+id)
	for witness: String in witnesses:
		if progress.life.report_cause(id,"player_murder",witness,progress.life.records[witness]["room"]):break

func _cold(progress: TanDangProgress) -> TanDangProgress:
	var profile := SanctuaryProfile.new(); profile.save_path=progress.profile.save_path
	profile.register_extension_validator(SCOPE,TanDangProgress.valid)
	_check(profile.load_profile(),"Cold profile loads sealed quest")
	var npc := NpcWorldState.new(); npc.save_path=profile.save_path+".npc_v1.json"
	_check(npc.load_state(),"Cold NPC loads same life authority")
	var restored := TanDangProgress.new(); restored.initialize(profile,npc)
	_check(restored.available() and restored.state()==progress.state(),"Cold quest projection agrees with committed state")
	return restored

func _run() -> void:
	var allowed: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: dedicated QA data root required"); quit(2); return
	directory="user://verification/tan_dang_quest_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	_model_validation()
	for branch: String in ["gate","rescue"]: _branch(branch)
	_known_recipe()
	_all_dead_fallback()
	_death_after_rescue()
	_offense_and_assistance()
	_membership_and_coexistence()
	print("RESULT tan_dang_quest checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func _model_validation() -> void:
	_check(TanDangProgress.valid(TanDangProgress.empty()),"Empty authored quest state valid")
	for field: String in ["contribution","core","discoveries","membership","version"]:
		var invalid: Dictionary=TanDangProgress.empty()
		match field:
			"contribution": invalid[field]=2
			"core": invalid[field]="spent"
			"discoveries": invalid[field]=["lamp","lamp"]
			"membership": invalid[field]="member"
			"version": invalid[field]=2
		_check(not TanDangProgress.valid(invalid),"Validator rejects inconsistent or future "+field)

func _branch(branch: String) -> void:
	var progress: TanDangProgress=_fixture("branch_"+branch)
	_q1(progress)
	var profile_bytes: PackedByteArray=_raw(progress.profile.save_path)
	var npc_bytes: PackedByteArray=_raw(progress.life.save_path)
	var life_before: Dictionary=progress.life.snapshot()
	var state_before: Dictionary=progress.state()
	for _index: int in 3:
		TanDangProgress.rows(progress.profile); progress.state(); progress.alive(DU); progress.can_join()
	_check(progress.life.snapshot()==life_before and progress.state()==state_before and _raw(progress.profile.save_path)==profile_bytes and _raw(progress.life.save_path)==npc_bytes,"Reading/canceling choice without apply has no side effects")
	_unchanged_rejection(progress,"choice_"+branch,"ledger")
	_apply(progress,"choice_"+branch,"refuge")
	_check(progress.state()["choice"]==branch and progress.state()["contribution"]==4,"Choice is durable with second quest reward")
	if branch=="gate":
		_check(not progress.alive(DU) and progress.life.records[DU]["death"]["context"]=="core_withdrawal" and not progress.murder_recorded() and progress.state()["core"]=="carried","Gate choice records core withdrawal without player execution offense")
	else:
		_check(progress.alive(DU) and progress.state()["core"]=="spent" and progress.state()["lamp"]=="broken" and progress.life.karma(DU)["rescued"],"Rescue records living recipient, consumed core and broken lamp")
	_check(progress.life.records[LAM]["room"]=="h00_traveler_hub","Living Lam returns through canonical placement")
	_unchanged_rejection(progress,"choice_"+branch,"refuge")
	_unchanged_rejection(progress,"choice_"+("rescue" if branch=="gate" else "gate"),"refuge")
	_unchanged_rejection(progress,"q1_reward")
	progress=_cold(progress)
	_finish(progress)
	var cultivation_before: Dictionary=progress.profile.cultivation_progress.duplicate(true)
	var souls_before: int=progress.profile.souls
	_apply(progress,"recipe","ledger")
	_apply(progress,"support","ledger")
	_check(progress.state()["contribution"]==0 and progress.state()["recipe_paid"] and progress.profile.archived_recipes.has(&"firestorm") and progress.profile.souls==souls_before,"Both branches buy exactly one existing recipe using contribution, not Souls")
	_check(progress.state()["support_claimed"] and progress.profile.cultivation_progress==cultivation_before,"Support records existing guidance without granting cultivation stage")
	for action: String in ["q3_reward","recipe","support"]: _unchanged_rejection(progress,action,"ledger")
	progress=_cold(progress)
	_check(progress.state()["choice"]==branch and progress.state()["recipe_claimed"],"Cold final state preserves branch and reward receipts")

func _known_recipe() -> void:
	var progress: TanDangProgress=_fixture("known_recipe",true)
	_q1(progress); _apply(progress,"choice_rescue","refuge"); _finish(progress)
	_apply(progress,"recipe","ledger")
	_check(progress.state()["recipe_claimed"] and not progress.state()["recipe_paid"] and progress.state()["contribution"]==6,"Already-known recipe consumes no contribution and still records completion")
	_unchanged_rejection(progress,"recipe","ledger")

func _all_dead_fallback() -> void:
	var progress: TanDangProgress=_fixture("all_dead")
	for id: String in [MOC,LAM,DU]: _kill(progress,id)
	var tombstones: Dictionary={MOC:progress.life.records[MOC]["death"].duplicate(true),LAM:progress.life.records[LAM]["death"].duplicate(true),DU:progress.life.records[DU]["death"].duplicate(true)}
	_q1(progress)
	_unchanged_rejection(progress,"choice_rescue","refuge")
	_apply(progress,"choice_gate","refuge")
	_apply(progress,"install_core","lamp")
	_unchanged_rejection(progress,"report_moc",MOC)
	_apply(progress,"report_moc","ledger")
	_unchanged_rejection(progress,"report_lam",LAM)
	_apply(progress,"report_lam","ledger")
	_apply(progress,"q3_reward","ledger")
	_apply(progress,"recipe","ledger"); _apply(progress,"support","ledger")
	_check(progress.state()["rewards"].size()==3 and progress.state()["recipe_claimed"] and progress.state()["support_claimed"] and not progress.can_join(),"All-dead evidence/ledger path retains mandatory rewards but no new membership")
	_unchanged_rejection(progress,"join",MOC)
	for id: String in [MOC,LAM,DU]:
		_check(progress.life.records[id]["death"]==tombstones[id] and not progress.alive(id),"Fallback neither rewrites murder nor resurrects "+id)
	progress=_cold(progress)
	_check(not progress.alive(DU) and progress.state()["core"]=="installed","Dead-before-choice core outcome survives reload")

func _death_after_rescue() -> void:
	var progress: TanDangProgress=_fixture("death_after_rescue")
	_q1(progress); _apply(progress,"choice_rescue","refuge")
	_kill(progress,DU)
	_unchanged_rejection(progress,"choice_gate","refuge")
	_check(progress.state()["choice"]=="rescue" and progress.state()["core"]=="spent" and progress.life.karma(DU)["rescued"] and progress.life.karma(DU)["player_murdered"],"Later death preserves the original rescue history and consumed core")
	_finish(progress); _apply(progress,"recipe","ledger"); _apply(progress,"support","ledger")
	_check(not progress.can_join() and progress.state()["recipe_claimed"],"Later murder blocks membership without blocking progress rewards")
	progress=_cold(progress)
	_check(progress.state()["choice"]=="rescue" and not progress.alive(DU),"No cold reload turns later death into gate branch or revival")

func _offense_and_assistance() -> void:
	var grateful: TanDangProgress=_fixture("aid")
	_q1(grateful); _apply(grateful,"choice_rescue","refuge")
	var linen: int=grateful.profile.material_stash[&"linen_fiber"]
	_apply(grateful,"assist",LAM,LAM)
	_check(grateful.profile.material_stash[&"linen_fiber"]==linen+2 and grateful.life.karma(LAM)["assistance_used"],"Gratitude gives concrete existing linen in warehouse once")
	_unchanged_rejection(grateful,"assist",LAM,LAM)
	grateful=_cold(grateful)
	_unchanged_rejection(grateful,"assist",LAM,LAM)
	var offended: TanDangProgress=_fixture("offense")
	_check(offended.life.receive_hit(LAM,NpcPilotCatalog.maximum_health(LAM)-1.0,1300.0,true),"Player offense commits before narrative reward")
	var trust: int=offended.life.records[LAM]["trust"]
	_q1(offended); _apply(offended,"choice_rescue","refuge")
	_check(offended.life.records[LAM]["trust"]==trust and offended.life.karma(LAM)["gratitude"]==0 and offended.life.retaliation_reason(LAM)=="attacked","Story rescue cannot overwrite canonical offense with trust")
	_unchanged_rejection(offended,"assist",LAM,LAM)
	_apply(offended,"notice",LAM,LAM)
	_unchanged_rejection(offended,"notice",LAM,LAM)
	for _index: int in 11: offended.life.advance_ticks(8)
	_check(offended.life.save() and offended.life.retaliation_reason(LAM)=="attacked","More than twenty seconds of world ticks does not erase resentment")
	offended=_cold(offended)
	_check(offended.life.retaliation_reason(LAM)=="attacked" and offended.state()["response_notices"]==[LAM+":attacked"],"Response receipt and grievance share durable canonical state")

func _membership_and_coexistence() -> void:
	var progress: TanDangProgress=_fixture("membership")
	var old_sect := SectJourneyProgress.new(); old_sect.initialize(progress.profile)
	for event: String in ["accept","west","east","guest"]:
		_check(old_sect.record("thanh_van",event),"Existing faction event remains writable: "+event)
	var social := OpeningSocialRuntime.new(); _check(social.configure(progress.profile),"Existing social validators remain registered")
	_check(OpeningSocialRuntime.help(progress.profile,progress.life,"pilot_traveler"),"Existing social assistance still commits through original life fence")
	var original_faction: Dictionary=progress.profile.extension_state(SectJourneyProgress.SCOPE)
	var original_social: Dictionary=progress.profile.extension_state("npc_social")
	var original_cultivation: Dictionary=progress.profile.cultivation_progress.duplicate(true)
	var original_weapon: StringName=progress.profile.starting_weapon
	_q1(progress); _apply(progress,"choice_rescue","refuge"); _finish(progress)
	_apply(progress,"recipe","ledger"); _apply(progress,"support","ledger")
	_apply(progress,"decline",MOC)
	_check(progress.state()["declined"] and progress.state()["membership"]=="guest","Declining invitation preserves guest status")
	_apply(progress,"join",MOC)
	_check(progress.state()["membership"]=="member","Living recipient may accept voluntary membership later")
	var credit: int=progress.state()["contribution"]
	_apply(progress,"leave",MOC)
	_check(progress.state()["membership"]=="left" and progress.state()["contribution"]==credit and progress.state()["recipe_claimed"] and progress.profile.starting_weapon==original_weapon,"Leaving keeps knowledge, contribution and gear class selection")
	_check(progress.profile.extension_state(SectJourneyProgress.SCOPE)==original_faction and progress.profile.extension_state("npc_social")==original_social and progress.profile.cultivation_progress==original_cultivation,"New sect does not reset old faction, social assistance or cultivation")
	_check(progress.life.retaliation_reason(MOC)=="" and progress.life.retaliation_reason(LAM)=="","Leaving alone creates no betrayal grievance")

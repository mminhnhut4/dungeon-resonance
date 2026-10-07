extends SceneTree
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
class PausedWriter extends Writer:
	var stop_point: String = ""
	var proof_path: String = ""
	var token: String = ""
	func _fault(point: String) -> bool:
		if point!=stop_point: return super._fault(point)
		var proof := FileAccess.open(proof_path,FileAccess.WRITE)
		proof.store_string(JSON.stringify({"pid":OS.get_process_id(),"point":point,"token":token,"profile_path":path})); proof.flush(); proof.close()
		print("OWNED_CRASH_READY "+token)
		# Only this dedicated probe blocks at a durable checkpoint. The runner
		# verifies PID, executable and token before stopping this exact process.
		while true: OS.delay_msec(50)
		return false
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("_run")
func _check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1; print("FAIL "+label)
	else: print("PASS "+label)
func _run() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var path: String = args.get("profile","")
	if not path.begins_with("user://verification/opening_process_"):
		print("Invalid owned probe path"); quit(2); return
	var profile := SanctuaryProfile.new(); profile.save_path=path
	if args.get("stage","")=="crash":
		profile.souls=25; profile.material_stash[&"crystal"]=20; profile.material_stash[&"dust"]=10
		if not profile.save() or not profile.commit_cultivation(Model.initial_proposal(Model.new_progress(4),profile.material_stash,profile.souls,profile.boss_proofs)): quit(2); return
		var probe := PausedWriter.new(); probe.configure(profile,path)
		probe.stop_point=args["point"]; probe.proof_path=args["proof"]; probe.token=args["token"]
		profile._writer=probe
		var proposal: Dictionary = Model.propose(profile.cultivation_progress,profile.material_stash,profile.souls,profile.boss_proofs,"train",{"actor_id":"player","sessions":1,"target_tick":8},"process_train_1")
		profile.commit_cultivation(proposal)
		print("Probe unexpectedly returned"); quit(3); return
	_check(profile.load_profile() and not profile.read_only,"Fresh process recovers the interrupted common owner")
	var expected: int = 0 if args["point"]=="after_candidate" else 8
	_check(profile.cultivation_progress["actors"]["player"]["energy"]==expected,"Cold energy is one proven before/after value")
	_check(profile.material_stash[&"crystal"]==20-(1 if expected==8 else 0),"Resource debit matches the same recovered progress")
	_check(Writer.seal_valid(Writer.read_json(path)),"Recovered root2 seal is valid")
	_check(not FileAccess.file_exists(path+".tmp") and not FileAccess.file_exists(path+".decision") and not FileAccess.file_exists(path+".previous"),"Cold recovery cleans all interrupted journal artifacts")
	_check(profile.save(),"Recovered owner can commit a later ordinary profile save")
	print("RESULT OpeningProfileProcess point=%s checks=%d failures=%d" % [args["point"],checks,failures])
	quit(0 if failures==0 else 1)

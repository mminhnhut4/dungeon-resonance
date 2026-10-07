extends SceneTree
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
const Model=preload("res://scripts/cultivation/opening_cultivation_state.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,title: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS: " if ok else "FAIL: ")+title)
func mastery(profile: SanctuaryProfile) -> bool:
	var proposal: Dictionary=Model.propose(profile.cultivation_progress,profile.material_stash,profile.souls,profile.boss_proofs,"mastery",{},"cult_%d"%profile.cultivation_progress["next_event"])
	return profile.commit_cultivation(proposal)
func _run() -> void:
	var profile:=SanctuaryProfile.new(); profile.save_path="user://verification/writer_cache.json"
	check(profile.save(),"Cache fixture starts from a real legacy save")
	check(profile.commit_cultivation(Model.initial_proposal(Model.new_progress(42),profile.material_stash,profile.souls,profile.boss_proofs)),"Common writer migrates to sealed cultivation progress")
	check(mastery(profile),"Warm transaction records immediate durable mastery")
	profile.last_commit["payload"]["cultivation_progress"]["actors"]["player"]["mastery"]=999
	check(mastery(profile) and profile.cultivation_progress["actors"]["player"]["mastery"]==2,"Mutating the returned payload cannot mutate writer's verified copy")
	var disk: Dictionary=Writer.read_json(profile.save_path)
	check(disk["cultivation_progress"]["actors"]["player"]["mastery"]==2 and Writer.seal_valid(disk),"Durable file contains exactly the two accepted events and a valid seal")
	var external: Dictionary=disk.duplicate(true); external["souls"]=7
	external=Writer.sealed(external,int(disk["profile_commit"]["revision"])+1)
	var text: String=Writer.canonical(external)
	var file:=FileAccess.open(profile.save_path,FileAccess.WRITE); file.store_string(text); file.close()
	check(not mastery(profile) and profile.last_commit.get("error")=="profile_changed_reload_required","An external valid change invalidates warm cache before any write")
	check(FileAccess.get_file_as_string(profile.save_path)==text and profile.cultivation_progress["actors"]["player"]["mastery"]==2,"Stale-owner rejection keeps external bytes and rolls back RAM")
	var cold:=SanctuaryProfile.new(); cold.save_path=profile.save_path
	check(cold.load_profile() and cold.souls==7 and cold.cultivation_progress["actors"]["player"]["mastery"]==2,"Cold owner reads the actual intervening authority")
	print("RESULT writer_cache checks=%d failures=%d"%[checks,failures]); quit(1 if failures else 0)

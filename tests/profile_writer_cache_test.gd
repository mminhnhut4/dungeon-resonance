extends SceneTree
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
const Model=preload("res://scripts/cultivation/opening_cultivation_state.gd")
var checks: int=0
var failures: int=0
var fixture_path: String=""
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,title: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS: " if ok else "FAIL: ")+title)
func mastery(profile: SanctuaryProfile) -> bool:
	if not Model.valid(profile.cultivation_progress,profile.material_stash): return false
	var proposal: Dictionary=Model.propose(profile.cultivation_progress,profile.material_stash,profile.souls,profile.boss_proofs,"mastery",{},"cult_%d"%profile.cultivation_progress["next_event"])
	return profile.commit_cultivation(proposal)
func finish() -> void:
	print("RESULT writer_cache checks=%d failures=%d hz=%d path=%s"%[checks,failures,Engine.physics_ticks_per_second,fixture_path])
	quit(1 if failures else 0)
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second=int(argument.trim_prefix("--hz="))
	var allowed: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: Cache fixture requires an isolated QA user directory"); quit(2); return
	fixture_path="user://verification/writer_cache_%d_%d_%d.json"%[OS.get_process_id(),Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	var profile:=SanctuaryProfile.new(); profile.save_path=fixture_path
	var started: bool=profile.save()
	check(started,"Cache fixture starts from a real legacy save")
	if not started: finish(); return
	var migrated: bool=profile.commit_cultivation(Model.initial_proposal(Model.new_progress(42),profile.material_stash,profile.souls,profile.boss_proofs))
	check(migrated,"Common writer migrates to sealed cultivation progress")
	if not migrated: finish(); return
	var warm: bool=mastery(profile)
	var payload: Variant=profile.last_commit.get("payload")
	var returned_progress: Variant=payload.get("cultivation_progress") if payload is Dictionary else null
	var usable_payload: bool=returned_progress is Dictionary and Model.valid(returned_progress,profile.material_stash)
	check(warm and usable_payload,"Warm transaction records immediate durable mastery with a usable returned payload")
	if not warm or not usable_payload: finish(); return
	returned_progress["actors"]["player"]["mastery"]=999
	check(mastery(profile) and profile.cultivation_progress["actors"]["player"]["mastery"]==2,"Mutating the returned payload cannot mutate writer's verified copy")
	var disk: Dictionary=Writer.read_json(profile.save_path)
	var usable_disk: bool=Writer.seal_valid(disk) and Model.valid(disk.get("cultivation_progress"),disk.get("material_stash"))
	check(usable_disk and disk["cultivation_progress"]["actors"]["player"]["mastery"]==2,"Durable file contains exactly the two accepted events and a valid seal")
	if not usable_disk: finish(); return
	var external: Dictionary=disk.duplicate(true); external["souls"]=7
	external=Writer.sealed(external,int(disk["profile_commit"]["revision"])+1)
	var text: String=Writer.canonical(external)
	var file:=FileAccess.open(profile.save_path,FileAccess.WRITE)
	if file==null:
		check(false,"External-authority fixture opens its existing private file"); finish(); return
	file.store_string(text); file.close()
	check(not mastery(profile) and profile.last_commit.get("error")=="profile_changed_reload_required","An external valid change invalidates warm cache before any write")
	check(FileAccess.get_file_as_string(profile.save_path)==text and profile.cultivation_progress["actors"]["player"]["mastery"]==2,"Stale-owner rejection keeps external bytes and rolls back RAM")
	var cold:=SanctuaryProfile.new(); cold.save_path=profile.save_path
	check(cold.load_profile() and cold.souls==7 and cold.cultivation_progress["actors"]["player"]["mastery"]==2,"Cold owner reads the actual intervening authority")
	finish()

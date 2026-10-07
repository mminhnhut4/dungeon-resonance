extends SceneTree
## Separate native-process evidence of actual product composition before recovery.
const BaseProbe = preload("res://tests/opening_profile_process_probe.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: _run.call_deferred()
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: " + label)

func _run() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=",true,1)
		if pair.size() == 2: args[pair[0]] = pair[1]
	var path: String = args.get("profile","")
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not path.begins_with("user://verification/opening_process_") or not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: Owned isolated native probe required"); quit(2); return
	if args.get("stage","") == "crash":
		var fixture := SanctuaryProfile.new(); fixture.save_path = path
		fixture.souls = 25; fixture.material_stash[&"linen_fiber"] = 8
		fixture.material_stash[&"dust"] = 10; fixture.material_stash[&"crystal"] = 20
		if not fixture.save() or not fixture.commit_cultivation(Model.initial_proposal(Model.new_progress(4),fixture.material_stash,fixture.souls,fixture.boss_proofs)): quit(2); return
	var flow: GameFlow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path; root.add_child(flow); current_scene = flow
	for _index: int in 8: await physics_frame
	var hub: ExteriorHub = flow.active_scene as ExteriorHub
	hub.npc_population.set_process(false)
	if args.get("stage","") == "crash":
		var probe = BaseProbe.PausedWriter.new(); probe.configure(flow.profile,path)
		probe.stop_point = args["point"]; probe.proof_path = args["proof"]; probe.token = args["token"]
		flow.profile._writer = probe
		hub.economy.help_resident(hub.npc_population.state,"pilot_traveler")
		print("FAIL: Native social probe unexpectedly returned"); quit(3); return
	var recovered: bool = args["point"] != "after_candidate"
	_check(not flow.profile.read_only and flow.profile.social_transactions_available(), "Fresh actual GameFlow registers semantic validator/primary reader before recovery")
	_check(flow.profile.material_stash[&"linen_fiber"] == (6 if recovered else 8), "Fresh product process recovers exactly one or zero cloth debit")
	_check(NpcSocialProgress.helped(OpeningSocialRuntime.state(flow.profile),"pilot_traveler") == recovered, "The same recovered image holds its real life-bound receipt")
	_check(flow.profile.souls == 25 and flow.profile.material_stash[&"dust"] == 10 and flow.profile.cultivation_progress["seed"] == 4, "Social recovery preserves common cultivation and other resources")
	_check(Writer.seal_valid(Writer.read_json(path)), "Fresh product root2 seal is valid")
	_check(not FileAccess.file_exists(path+".tmp") and not FileAccess.file_exists(path+".decision") and not FileAccess.file_exists(path+".previous"), "Product recovery closes its interrupted journal")
	_check(NpcWorldState.valid(hub.npc_population.state.snapshot()) and hub.npc_population.state.records["pilot_traveler"]["death"].is_empty(), "Actual primary schema2 resident is retained")
	_check(flow.profile.try_add_souls(1), "Fresh product owner can perform a later ordinary save")
	flow.queue_free()
	for _index: int in 4: await physics_frame
	print("RESULT OpeningProductProcess point=%s checks=%d failures=%d" % [args["point"],checks,failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
## Two distinct native processes use only their isolated test profile.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: _run.call_deferred()
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: " + label)
func _step(count: int = 4) -> void:
	for _index: int in count: await physics_frame

func _run() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=",true,1)
		if pair.size() == 2: args[pair[0]] = pair[1]
	var path: String = args.get("profile","")
	var stage: String = args.get("stage","")
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not path.begins_with("user://verification/opening_anchor_") or stage not in ["prepare","recover"] or not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: Isolated anchor process probe required"); quit(2); return
	Engine.physics_ticks_per_second = int(args.get("hz","60"))
	if stage == "prepare":
		var fixture := SanctuaryProfile.new(); fixture.save_path = path
		fixture.souls = 25; fixture.material_stash[&"linen_fiber"] = 8
		fixture.material_stash[&"dust"] = 10; fixture.material_stash[&"crystal"] = 20
		if not fixture.save() or not fixture.commit_cultivation(Model.initial_proposal(Model.new_progress(4),fixture.material_stash,fixture.souls,fixture.boss_proofs)): print("FAIL: Fixture initialization"); quit(2); return
	var flow: GameFlow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path; root.add_child(flow); current_scene = flow
	await _step(12)
	var hub: ExteriorHub = flow.active_scene as ExteriorHub
	hub.npc_population.set_process(false)
	var actor: Player = hub.player
	var ledger: GearInventory = hub.gear.inventory
	if stage == "prepare":
		_check(hub.enter_exterior(&"o01_p03"), "Real main scene enters the shrine room")
		PlayerTravel.relocate(actor,ExteriorHub.ORIGIN + hub.exterior.interactions[&"shrine"])
		await _step(6)
		_check(hub.interact_station(&"shrine") and hub.dialogue.is_open and not actor.controls_enabled and flow.profile.exterior_progress["anchor_id"] == "shrine", "Actual shrine input commits anchor and opens courier dialogue")
		_check(not hub.restore_exterior_anchor(), "The open courier modal refuses travel until its owner closes")
		hub.dialogue.close(); await _step(2)
		# Explicit QA inventory fixture uses the existing canonical save, not a new owner.
		flow.profile.hub_inventory = GearInventoryCodec.encode(ledger)
		_check(flow.profile.save() and GearInventoryCodec.valid(flow.profile.hub_inventory), "Canonical profile saves geography and the prepared UID ledger together")
		_check(flow.profile.load_profile() and hub.restore_exterior_anchor() and hub.player == actor and hub.gear.inventory == ledger, "Same-session anchor reload keeps the exact actor and inventory")
		await _step(4)
		_check(actor.global_position.distance_to(ExteriorHub.ORIGIN+hub.exterior.anchors[&"shrine"]) < 2 and actor.motor.is_grounded(), "Same-session actor rests on the shrine dry floor")
	else:
		_check(ExteriorProgress.valid(flow.profile.exterior_progress) and flow.profile.exterior_progress["room_id"] == "o01_p03" and flow.profile.exterior_progress["anchor_id"] == "shrine", "A fresh native GameFlow reads the canonical shrine anchor")
		_check(hub.outside and hub.exterior.room_id == &"o01_p03" and hub.last_entry == &"shrine" and actor.global_position.distance_to(ExteriorHub.ORIGIN+hub.exterior.anchors[&"shrine"]) < 2 and actor.motor.is_grounded(), "Cold startup restores the actual room and dry floor")
		var decoded: GearInventory = GearInventoryCodec.decode(flow.profile.hub_inventory)
		_check(decoded != null and decoded.items.keys() == ledger.items.keys() and decoded.items.size() == ledger.items.size(), "Cold startup restores the prepared UID ledger without duplicating gear")
		_check(actor.controls_enabled and not hub.dialogue.is_open and TimeScaleClaims.owner_count(self) == 0 and is_equal_approx(Engine.time_scale,1.0), "Cold startup inherits no old shrine modal or time claim")
		_check(flow.profile.profile_version == 2 and flow.profile.souls == 25 and flow.profile.material_stash[&"dust"] == 10 and flow.profile.material_stash[&"linen_fiber"] == 8, "Geographic reload grants no resource and retains canonical format2")
		_check(flow.profile.save() and Writer.seal_valid(Writer.read_json(path)) and flow.profile.exterior_progress["anchor_id"] == "shrine", "A later ordinary save retains a valid seal and the same geographic anchor")
	flow.queue_free(); await _step(6)
	print("RESULT OpeningAnchorProcess stage=%s hz=%d checks=%d failures=%d" % [stage,Engine.physics_ticks_per_second,checks,failures])
	quit(0 if failures == 0 else 1)

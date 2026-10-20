extends SceneTree
## Final breakthrough through the actual station handler, one fixture per branch.
## Progress gates are synthetic; abilities are granted only by the real commit.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int = 0
var failures: int = 0
var hz: int = 60
var flow: GameFlow

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func step(count: int = 1) -> void:
	for _index: int in count: await physics_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code; event.keycode = code; event.pressed = true
	Input.parse_input_event(event); await step(2)
	event = InputEventKey.new()
	event.physical_keycode = code; event.keycode = code; event.pressed = false
	Input.parse_input_event(event)

func aim(hub: ExteriorHub, target: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = hub.player.get_viewport().get_final_transform() * hub.player.get_canvas_transform() * target
	Input.parse_input_event(motion); await step(2)

func close_flow() -> void:
	if is_instance_valid(flow): flow.queue_free()
	await step(5)
	flow = null

func open_flow(path: String) -> ExteriorHub:
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path
	root.add_child(flow); current_scene = flow
	await step(12)
	flow.cultivation_session.set_physics_process(false)
	return flow.active_scene as ExteriorHub

func fixture(branch: String) -> String:
	var profile := SanctuaryProfile.new()
	profile.save_path = "user://verification/truc_co_bag_%d_%d_%s/profile.json" % [OS.get_process_id(), Time.get_ticks_usec(), branch]
	profile.material_stash[&"dust"] = 66; profile.material_stash[&"crystal"] = 77
	profile.souls = 5; profile.boss_proofs[&"golem"] = 1
	var inventory: GearInventory = HubPreparation.starter_inventory(profile)
	inventory.materials[&"dust"] = 2
	profile.hub_inventory = GearInventoryCodec.encode(inventory)
	check(profile.save(), branch + ": isolated legacy before-image exists")
	profile.cultivation_progress = Model.new_progress(4)
	profile.profile_version = 2
	var actor: Dictionary = profile.cultivation_progress["actors"]["player"]
	actor["stage"] = 2; actor["energy"] = 40; actor["mastery"] = 8
	actor["insight_ids"] = Model.OBSERVATIONS.duplicate()
	check(Model.valid(profile.cultivation_progress,profile.material_stash) and profile.save(), branch + ": synthetic earned thresholds saved without an ability namespace")
	return profile.save_path

func branch_case(branch: String) -> void:
	var failures_before_fixture: int = failures
	var path: String = fixture(branch)
	if failures > failures_before_fixture: return
	var hub: ExteriorHub = await open_flow(path)
	if hub == null:
		check(false, branch + ": main opened expected Hub"); await close_flow(); return
	var session: OpeningCultivationSession = flow.cultivation_session
	var runtime: CultivationStyleRuntime = session.style_binding.runtime
	var inventory: GearInventory = hub.gear.inventory
	check(flow.profile.cultivation_abilities()["learned_ids"].is_empty() and runtime.learned.is_empty(), branch + ": sufficient thresholds alone never grant a technique")
	check(not hub.player.resonance_controller.foundation_resonance_enabled,branch+": pre-breakthrough composite link remains locked")
	var bank: Dictionary = flow.profile.material_stash.duplicate()
	var items: String = Writer.canonical(GearInventoryCodec.encode(inventory)["items"])
	hub.player.relocate(hub.stations[&"training"].global_position); await step(3)
	hub.open_station(&"training")
	var button: Button = hub.station_content.find_child("CultivationBranch_" + branch,true,false) as Button
	check(button != null and not button.disabled, branch + ": actual training panel exposes the chosen ready breakthrough button")
	if button == null:
		await close_flow(); return
	var before: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var failed_button_id: int = button.get_instance_id()
	flow.profile._writer.fault_plan = {"write_candidate":true}
	button.pressed.emit()
	check(FileAccess.get_file_as_bytes(path) == before and inventory.materials[&"dust"] == 2 and flow.profile.souls == 5 and flow.profile.cultivation_progress["actors"]["player"]["stage"] == 2 and runtime.learned.is_empty(), branch + ": failed actual button commit preserves cost, stage and locked runtime together")
	check(not hub.player.resonance_controller.foundation_resonance_enabled,branch+": rollback cannot provisionally grant the composite link")
	# Quoted buttons accept one delivery. Retry belongs to the deferred rebuilt
	# view, never to the consumed button retained during the same frame.
	await step(2)
	button = hub.station_content.find_child("CultivationBranch_" + branch,true,false) as Button
	check(button != null and button.get_instance_id() != failed_button_id and not button.disabled and not button.get_signal_connection_list("pressed").is_empty(), branch + ": failed transaction rebuilds a fresh connected branch button for retry")
	if button == null:
		await close_flow(); return
	button.pressed.emit()
	var ability: Dictionary = flow.profile.cultivation_abilities()
	var actor: Dictionary = flow.profile.cultivation_progress["actors"]["player"]
	check(ability["learned_ids"] == [branch] and ability["selected_id"] == branch and runtime.learned == [StringName(branch)] and runtime.selected == StringName(branch), branch + ": committed profile event binds exactly one earned technique to the live Player")
	check(hub.player.resonance_controller.foundation_resonance_enabled,branch+": committed Truc Co opens the existing composite-chain path")
	check(actor["stage"] == 3 and actor["energy"] == 40 and actor["mastery"] == 8 and actor["insight_ids"] == Model.OBSERVATIONS and inventory.materials[&"dust"] == 1 and flow.profile.souls == 5 and flow.profile.material_stash == bank and flow.profile.boss_proofs[&"golem"] == 1, branch + ": final breakthrough consumes one carried dust and preserves Souls and preserves accumulated progress and stored supplies")
	var committed: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var other: String = "cloud_return" if branch == "tether_sigil" else "tether_sigil"
	check(not session.perform("breakthrough",{"actor_id":"player","branch_id":other}).get("ok",false) and FileAccess.get_file_as_bytes(path) == committed and runtime.learned == [StringName(branch)], branch + ": a second branch cannot be purchased after the committed final breakthrough")
	check(Writer.canonical(GearInventoryCodec.encode(inventory)["items"]) == items, branch + ": breakthrough leaves all equipment UIDs and metadata intact")
	hub.close_station(); await step(4)
	hub.player.energy.regeneration = 0.0; hub.player.energy.reset()
	hub.feedback.hit_stop_seconds = 0.0; hub.feedback.reset_feedback()
	if branch == "tether_sigil": await sigil_input(hub,runtime)
	else: await counter_input(hub,runtime)
	await close_flow()
	hub = await open_flow(path)
	runtime = flow.cultivation_session.style_binding.runtime
	ability = flow.profile.cultivation_abilities()
	check(ability["learned_ids"] == [branch] and runtime.learned == [StringName(branch)] and runtime.selected == StringName(branch) and flow.profile.cultivation_progress["actors"]["player"]["stage"] == 3, branch + ": fresh product load restores one selected ability and rebinds runtime without granting again")
	check(hub.player.resonance_controller.foundation_resonance_enabled,branch+": old committed stage derives the link on cold load without another resource spend")
	check(flow.profile.material_stash == bank and hub.gear.inventory.materials[&"dust"] == 1 and flow.profile.souls == 5 and flow.profile.cultivation_progress["actors"]["player"]["mastery"] == 8 and flow.profile.cultivation_progress["actors"]["player"]["insight_ids"] == Model.OBSERVATIONS, branch + ": cold load preserves exact earned progress and separate resource ledgers")
	flow.start_run();await step(8)
	check(flow.active_scene is DungeonRun and flow.active_scene.player.resonance_controller.foundation_resonance_enabled,branch+": actual departure binds the committed unlock to the new dungeon actor")
	check(flow.active_scene.gear.inventory.materials[&"dust"]==1 and flow.profile.souls==5 and flow.profile.material_stash==bank,branch+": scene rebinding cannot charge breakthrough resources again")
	await close_flow()

func sigil_input(hub: ExteriorHub, runtime: CultivationStyleRuntime) -> void:
	await aim(hub,hub.player.aim.global_position + Vector2(100,-20))
	var energy: float = hub.player.energy.current
	await key(KEY_G); await step(ceili(float(hz)*0.65))
	check(is_instance_valid(runtime.mark) and runtime.mark.is_armed() and is_equal_approx(hub.player.energy.current,energy-18.0), "Tỏa Linh Ấn: actual G places and arms a room-owned sigil for 18 mana")
	await key(KEY_G); await step(ceili(float(hz)*0.5))
	check(not is_instance_valid(runtime.mark) and is_equal_approx(hub.player.energy.current,energy-26.0) and runtime.cooldowns[&"tether_sigil"] > 0.0, "Tỏa Linh Ấn: second G pulses the same mark for 8 mana and retains placement cooldown")

func counter_input(hub: ExteriorHub, runtime: CultivationStyleRuntime) -> void:
	# Isolate the intended hostile target: this one-target counter can otherwise
	# legitimately hit the nearby training dummy first at a different physics Hz.
	hub.dummy.global_position = Vector2(-2000,-2000)
	hub.training_slime.global_position = Vector2(-2100,-2000)
	hub.player.relocate(Vector2(500,640)); await step(3)
	var guard: BaseEnemy = preload("res://scenes/enemies/ancient_guard.tscn").instantiate() as BaseEnemy
	guard.position = Vector2(600,640); guard.player = hub.player
	guard.combat_feedback = hub.feedback; guard.ai_enabled = false
	hub.yard.add_child(guard); await step(3)
	await aim(hub,guard.hurtbox.global_position)
	guard.state_machine.transition_to(&"telegraph"); guard.state_machine.transition_to(&"attack")
	await key(KEY_SHIFT)
	guard.attack_hitbox.sample_contacts()
	check(hub.player.motor.is_dashing and runtime.counter_remaining > 0.0, "Hồi Phong Kiếm: real dash through a hostile sweep earns the counter ticket")
	guard.attack_hitbox.deactivate()
	await step(ceili(float(hz)*0.18))
	guard.global_position = hub.player.global_position + Vector2(-52,0)
	guard.state_machine.transition_to(&"telegraph")
	await aim(hub,guard.hurtbox.global_position)
	var energy: float = hub.player.energy.current
	var hp: float = guard.health.current_health
	await key(KEY_G); await step(ceili(float(hz)*0.16))
	check(is_equal_approx(hub.player.energy.current,energy-12.0) and runtime.counter_remaining == 0.0 and runtime.cooldowns[&"cloud_return"] > 0.0, "Hồi Phong Kiếm: actual G consumes the dodge ticket, 12 mana and starts its cooldown")
	print("COUNTER_DIAGNOSTIC hp=%s->%s hits=%s hero=%s target=%s aim=%s direction=%s mode=%s clock=%s attempted=%s" % [hp,guard.health.current_health,runtime.accepted_hits,hub.player.global_position,guard.hurtbox.global_position,hub.player.aim.target_position,runtime._direction,runtime._mode,runtime._time,runtime._attempted])
	check(guard.health.current_health < hp and runtime.accepted_hits == 1, "Hồi Phong Kiếm: newly earned branch damages the real enemy through its existing hitbox")
	guard.queue_free(); await step(3)

func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if DisplayServer.get_name() != "headless" or not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa + "/"):
		print("FAIL: isolated headless QA directory required"); quit(2); return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz = int(argument.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	for branch: String in ["tether_sigil","cloud_return"]: await branch_case(branch)
	await root.get_node("AudioManager").shutdown()
	print("RESULT TrucCoBagUnlock hz=%d checks=%d failures=%d" % [hz,checks,failures])
	quit(0 if failures == 0 else 1)

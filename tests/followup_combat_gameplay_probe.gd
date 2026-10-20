extends "res://tests/story_gameplay_probe.gd"
## Native H7 continuation. All attacks, repair, equip and travel use normal input.
## Copy to tests/ only after the root integrator releases the engine lane.

const DAGGER_UID: int = 519
const MAX_CONTACTS: int = 256
const MAX_MOTION_SAMPLES: int = 1200
var contacts: Array[Dictionary] = []
var confirmed: Array[Dictionary] = []
var commits: Array[Dictionary] = []
var motion_samples: Array[Dictionary] = []
var target_ids: Dictionary[int, bool] = {}
var sword_uid: int = 0
var repair_receipt: Dictionary = {}
var dungeon_receipt: Dictionary = {}
var _dungeon_player_bound: bool = false


func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(qa + "/") or DisplayServer.get_name() == "headless" or not "--native-approved" in OS.get_cmdline_user_args() or not "--qa-seed-h7" in OS.get_cmdline_user_args():
		quit(2)
		return
	root.unfocusable = true
	root.size = Vector2i(1152, 648)
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	AudioServer.set_bus_mute(0, true)
	evidence = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	profile_path = "user://newcomer-item1/profile.json"
	var source_profile: String = OS.get_environment("FOLLOWUP_SOURCE_PROFILE")
	var source_npc: String = OS.get_environment("FOLLOWUP_SOURCE_NPC")
	if not _check(not evidence.is_empty() and not source_profile.is_empty() and not source_npc.is_empty() and FileAccess.file_exists(profile_path) and FileAccess.file_exists(profile_path + ".npc_v1.json") and FileAccess.get_sha256(profile_path) == source_profile and FileAccess.get_sha256(profile_path + ".npc_v1.json") == source_npc, "Exact earned H7 profile and NPC bytes before product startup"):
		quit(2)
		return
	bot = CombatBot.new()
	root.add_child(bot)
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = profile_path
	root.add_child(flow)
	current_scene = flow
	await _step(30)
	var home: PrologueHub = flow.active_scene as PrologueHub
	if not _check(home != null and not flow.qa_tools_enabled and is_instance_valid(home.training_slime), "Product Hub has its physical training Slime and no QA grants"):
		await _finish_combat(false)
		return
	sword_uid = home.gear.inventory.equipped_weapon_uid
	if not _check(sword_uid == 1 and home.gear.inventory.items.has(DAGGER_UID) and home.gear.inventory.items[DAGGER_UID].broken and home.gear.inventory.items[DAGGER_UID].definition_id == &"shadow_dagger" and home.gear.inventory.materials[&"metal"] == 30 and home.gear.inventory.materials[&"dust"] == 4, "Earned sword UID1 and owned broken Shadow Dagger UID519 with thirty metal/four dust"):
		await _finish_combat(false)
		return
	recorder = preload("res://tests/newcomer_capture.gd").new()
	root.add_child(recorder)
	recorder.begin(evidence)
	process_frame.connect(_watch_frame)
	home.player.equipped_weapon.attack_committed.connect(_attack_committed)
	home.player.equipped_weapon.hit_confirmed.connect(_player_confirmed)
	_watch_frame()
	_stage("hub_sword")
	var before: int = _accepted_count("hub_sword")
	for attempt: int in 8:
		if _accepted_count("hub_sword") > before:
			break
		if not await _hub_attack(home):
			break
	if not _check(_accepted_count("hub_sword") > before, "Ordinary J with earned sword lands on moving Hub training Slime"):
		await _finish_combat(false)
		return
	_check(_has_immediate_flash("hub_sword") and _has_confirmed_freeze("hub_sword"), "Accepted sword contact commits Slime flash in hit_resolved and genuine hit-stop in hit_confirmed")
	await _shot("earned_sword_slime_contact")
	if not await _repair_and_equip(home):
		await _finish_combat(false)
		return
	_stage("hub_dagger")
	before = _accepted_count("hub_dagger")
	for attempt: int in 12:
		if _accepted_count("hub_dagger") >= before + 2:
			break
		if not await _hub_attack(home):
			break
	_check(_accepted_count("hub_dagger") >= before + 2, "Two ordinary dagger J contacts resolve against real Hub Slime HP")
	_check(_has_immediate_flash("hub_dagger"), "Accepted dagger contact also refreshes the painted Slime flash before hit-stop")
	var thrust_samples: int = 0
	var thrust_clean: bool = true
	for row: Dictionary in motion_samples:
		if row["uid"] != DAGGER_UID or row["motion"] != "thrust" or row["phase"] != Weapon.Phase.ACTIVE:
			continue
		thrust_samples += 1
		thrust_clean = thrust_clean and not row["crescent"] and not row["ink"] and not row["slash"]
	_check(thrust_samples > 0 and thrust_clean, "Every observed committed dagger thrust Active sample excludes sweeping crescent and slash art")
	await _shot("shadow_dagger_thrust_contact")
	if not await _dungeon_combat(home):
		await _finish_combat(false)
		return
	await _finish_combat(true)


func _hub_attack(home: PrologueHub) -> bool:
	var slime: HubTrainingSlime = home.training_slime
	if not is_instance_valid(slime) or slime.health.current_health <= 0.0:
		await pause(1.4)
		slime = home.training_slime
	if not _check(is_instance_valid(slime) and slime.health.current_health > 0.0, "A living physical training Slime is available for the next input"):
		return false
	var side: float = -1.0 if home.player.global_position.x < slime.global_position.x else 1.0
	if not await _walk(home.player, slime.global_position.x + side * 34.0, 360):
		return false
	var motion := InputEventMouseMotion.new()
	motion.position = home.player.get_canvas_transform() * (slime.global_position + Vector2(0, -14))
	root.push_input(motion, true)
	await _step(2)
	await _key(KEY_J)
	await pause(0.42)
	return home.player.health.current_health > 0.0


func _repair_and_equip(home: PrologueHub) -> bool:
	_stage("smith_repair_owned_uid519")
	if not await _talk(home, NpcCatalog.SMITH):
		return false
	var choice: Button = home.dialogue.choice_list.get_node_or_null("Choice_smith_repair") as Button
	if not _check(choice != null, "Actual Smith repair dialogue choice is visible"):
		return false
	await _click(choice)
	await pause(0.6)
	var inv: GearInventory = home.gear.inventory
	var offer: Dictionary = home.economy.quote_repair(DAGGER_UID)
	var metal: int = inv.materials[&"metal"]
	var dust: int = inv.materials[&"dust"]
	if not _check(offer["can_repair"] and metal >= int(offer["metal"]) and dust >= int(offer["dust"]), "Actual quote is payable by the earned bag, not a granted fixture"):
		return false
	var repair: Button = home.station_content.find_child("RepairEquipment_%d" % DAGGER_UID, true, false) as Button
	if not _check(repair != null and repair.is_visible_in_tree() and not repair.disabled, "Actual UID519 repair button is present and enabled"):
		return false
	await _click(repair)
	await pause(0.6)
	repair_receipt = {"uid": DAGGER_UID, "metal_before": metal, "dust_before": dust, "metal_cost": int(offer["metal"]), "dust_cost": int(offer["dust"]), "metal_after": inv.materials[&"metal"], "dust_after": inv.materials[&"dust"], "broken_after": inv.items[DAGGER_UID].broken}
	if not _check(inv.items[DAGGER_UID].can_equip() and inv.materials[&"metal"] == metal - int(offer["metal"]) and inv.materials[&"dust"] == dust - int(offer["dust"]), "One Smith UI repair spends quoted materials and preserves the same UID"):
		return false
	await _shot("smith_repaired_actual_uid519")
	await _key(KEY_ESCAPE)
	await _step(5)
	_stage("bag_right_click_shadow_dagger")
	await _key(KEY_TAB)
	await pause(0.6)
	var screen: InventoryScreen = home.gear.modal as InventoryScreen
	if not _check(screen != null and screen.is_open and screen.tabs.current_tab == 0 and screen.bag_uids.has(DAGGER_UID), "Actual Tab equipment bag contains repaired UID519"):
		return false
	var offset: int = screen.bag_uids.find(DAGGER_UID)
	var desired_page: int = floori(float(offset) / 20.0)
	for _index: int in 20:
		if screen.page == desired_page:
			break
		var arrow: Button = screen.pager.get_parent().get_child(1 if screen.page < desired_page else 0) as Button
		await _click(arrow)
	if not _check(screen.page == desired_page, "Actual bag pager reaches UID519 without changing inventory positions directly"):
		return false
	var button: Button = screen.bag_buttons[offset % 20]
	if not _check(button.is_visible_in_tree(), "UID519 bag card is actually visible"):
		return false
	var point: Vector2 = button.get_global_rect().get_center()
	var mouse := InputEventMouseMotion.new()
	mouse.position = point
	root.push_input(mouse, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		root.push_input(event, true)
		await _step(2)
	if not _check(inv.equipped_weapon_uid == DAGGER_UID and home.player.equipped_weapon.definition.id == &"shadow_dagger", "Actual right-click equips owned repaired Shadow Dagger UID519"):
		return false
	await _shot("bag_actual_shadow_dagger_equipped")
	await _key(KEY_ESCAPE)
	return _check(home.player.controls_enabled and not screen.is_open, "Closing bag returns ordinary attack controls")


func _dungeon_combat(home: PrologueHub) -> bool:
	_stage("actual_portal_first_floor")
	if not await _walk(home.player, home.stations[&"portal"].global_position.x):
		return false
	await _key(KEY_E)
	await _step(12)
	if not _check(flow.active_scene is DungeonRun, "Physical portal E opens a normal unseeded dungeon run"):
		return false
	var run: DungeonRun = flow.active_scene as DungeonRun
	bot.run = run
	bot.enabled = true
	_stage("dungeon")
	for tick: int in 5400:
		if run.outcome != &"" or (run.living_enemies().is_empty() and not run.room.locked):
			break
		await _step(1)
	bot.stop()
	var accepted: int = _accepted_count("dungeon", false)
	dungeon_receipt = {"outcome": String(run.outcome), "room_number": run.room_number, "wave": run.wave, "player_hp": run.player.health.current_health, "remaining_enemies": run.living_enemies().size(), "room_locked": run.room.locked, "accepted_contacts": accepted, "elapsed_limit_physics_ticks": 5400}
	_check(accepted > 0, "Actual first-floor bot lands at least one resolved contact without HP/AI/RNG edits")
	_check(_has_immediate_flash("dungeon"), "At least one real first-floor accepted contact updates its enemy material immediately")
	if run.outcome == &"defeat":
		_stage("real_dungeon_defeat_after_contact")
	else:
		_stage("first_floor_clear" if run.living_enemies().is_empty() and not run.room.locked else "first_floor_bounded_limit")
	await _shot("actual_first_floor_combat_result")
	return accepted > 0


func _watch_frame() -> void:
	if not is_instance_valid(flow):
		return
	var world: Node = flow.active_scene
	var player: Player
	var trail: WeaponTrail
	if world is PrologueHub:
		var home: PrologueHub = world as PrologueHub
		player = home.player
		trail = home.presentation.trail if is_instance_valid(home.presentation) else null
		if is_instance_valid(home.training_slime):
			_bind_target(home.training_slime)
	elif world is DungeonRun:
		var run: DungeonRun = world as DungeonRun
		player = run.player
		trail = run.presentation.trail if is_instance_valid(run.presentation) else null
		if not _dungeon_player_bound and is_instance_valid(player):
			player.equipped_weapon.attack_committed.connect(_attack_committed)
			player.equipped_weapon.hit_confirmed.connect(_player_confirmed)
			player.hurtbox.hit_resolved.connect(_player_hurt)
			_dungeon_player_bound = true
		for enemy: Node2D in run.living_enemies():
			_bind_target(enemy)
	if not is_instance_valid(player) or not is_instance_valid(trail) or motion_samples.size() >= MAX_MOTION_SAMPLES:
		return
	var weapon: Weapon = player.equipped_weapon
	if weapon.phase != Weapon.Phase.ACTIVE or weapon.snapshot == null:
		return
	var snapshot: AttackSnapshot = weapon.snapshot
	var definition: WeaponDefinition = snapshot.weapon_definition
	if definition == null or snapshot.cosmetic_combo_index < 0 or snapshot.cosmetic_combo_index >= definition.combo_steps.size():
		return
	motion_samples.append({"stage": phase, "uid": (world as PrologueHub).gear.inventory.equipped_weapon_uid if world is PrologueHub else (world as DungeonRun).gear.inventory.equipped_weapon_uid, "attack_id": snapshot.attack_id, "phase": weapon.phase, "motion": String(definition.combo_steps[snapshot.cosmetic_combo_index].motion), "crescent": trail.crescent.visible, "ink": trail.crescent_ink.visible, "slash": trail.slash_sprite.visible, "ribbon": trail.ribbon.visible, "clock": weapon._phase_remaining})


func _bind_target(target: Node2D) -> void:
	if not is_instance_valid(target) or target_ids.has(target.get_instance_id()):
		return
	var hurt: Hurtbox = target.get("hurtbox") as Hurtbox
	if not is_instance_valid(hurt):
		return
	target_ids[target.get_instance_id()] = true
	hurt.hit_resolved.connect(_target_resolved.bind(target.get_instance_id()))


func _target_resolved(event: DamageEvent, result: DamageResult, id: int) -> void:
	if contacts.size() >= MAX_CONTACTS or not is_instance_valid(flow):
		return
	var world: Node = flow.active_scene
	var player: Player = (world as PrologueHub).player if world is PrologueHub else (world as DungeonRun).player if world is DungeonRun else null
	if not is_instance_valid(player) or event.source_id != player.get_instance_id():
		return
	var target: Node2D = instance_from_id(id) as Node2D
	var skin: SlimeSpriteSkin
	var visual: WorldEnemyVisual
	if is_instance_valid(target):
		skin = target.get_node_or_null("SlimeSpriteSkin") as SlimeSpriteSkin
		for child: Node in target.get_children():
			if child is WorldEnemyVisual:
				visual = child as WorldEnemyVisual
				break
	var flash: float = -1.0
	var active: bool = false
	var material: ShaderMaterial
	if is_instance_valid(skin) and is_instance_valid(skin.sprite):
		material = skin.sprite.material as ShaderMaterial
		if material != null:
			flash = float(material.get_shader_parameter("flash"))
			active = bool(material.get_shader_parameter("active"))
	elif is_instance_valid(visual) and is_instance_valid(visual.sprite):
		material = visual.sprite.material as ShaderMaterial
		if material != null:
			flash = float(material.get_shader_parameter("flash"))
	contacts.append({"stage": phase, "target": id, "target_type": target.get_class() if is_instance_valid(target) else "disposed", "accepted": not result.blocked and result.actual_damage > 0.0, "blocked": result.blocked, "reason": String(result.block_reason), "damage": result.actual_damage, "source_kind": event.source_kind, "melee": event.melee_hit, "attack_id": event.attack_id, "root": event.root_event_id, "skin_flash_at_resolved": flash, "skin_active_at_resolved": active, "skin_reactions": skin.hit_reaction_count if is_instance_valid(skin) else visual.hit_reaction_count if is_instance_valid(visual) else -1})


func _player_confirmed(event: DamageEvent, result: DamageResult) -> void:
	if confirmed.size() >= MAX_CONTACTS or result.blocked or result.actual_damage <= 0.0:
		return
	var world: Node = flow.active_scene if is_instance_valid(flow) else null
	var feedback: CombatFeedback = (world as PrologueHub).feedback if world is PrologueHub else (world as DungeonRun).feedback if world is DungeonRun else null
	confirmed.append({"stage": phase, "attack_id": event.attack_id, "root": event.root_event_id, "target": event.target_id, "damage": result.actual_damage, "feedback_frozen_after_confirmed": is_instance_valid(feedback) and feedback.is_frozen(), "hitstop_remaining": feedback.hit_stop_remaining if is_instance_valid(feedback) else 0.0})


func _player_hurt(event: DamageEvent, result: DamageResult) -> void:
	if contacts.size() >= MAX_CONTACTS:
		return
	contacts.append({"stage": phase, "player_target": true, "accepted": not result.blocked and result.actual_damage > 0.0, "reason": String(result.block_reason), "damage": result.actual_damage, "source_kind": event.source_kind, "root": event.root_event_id})


func _attack_committed(attack: AttackSnapshot) -> void:
	if commits.size() >= MAX_CONTACTS:
		return
	var definition: WeaponDefinition = attack.weapon_definition
	if definition == null or attack.cosmetic_combo_index < 0 or attack.cosmetic_combo_index >= definition.combo_steps.size():
		return
	var world: Node = flow.active_scene if is_instance_valid(flow) else null
	var uid: int = (world as PrologueHub).gear.inventory.equipped_weapon_uid if world is PrologueHub else (world as DungeonRun).gear.inventory.equipped_weapon_uid if world is DungeonRun else 0
	commits.append({"stage": phase, "uid": uid, "attack_id": attack.attack_id, "definition": String(definition.id), "combo_index": attack.cosmetic_combo_index, "motion": String(definition.combo_steps[attack.cosmetic_combo_index].motion), "damage": attack.base_damage})


func _accepted_count(scope: String, melee_only: bool = true) -> int:
	var count: int = 0
	for row: Dictionary in contacts:
		if row.get("stage", "") == scope and row.get("accepted", false) and (not melee_only or row.get("melee", false)):
			count += 1
	return count


func _has_immediate_flash(scope: String) -> bool:
	for row: Dictionary in contacts:
		if row.get("stage", "") == scope and row.get("accepted", false) and float(row.get("skin_flash_at_resolved", -1.0)) >= 0.5 and (row.get("skin_active_at_resolved", false) or scope == "dungeon"):
			return true
	return false


func _has_confirmed_freeze(scope: String) -> bool:
	for row: Dictionary in confirmed:
		if row["stage"] == scope and row["feedback_frozen_after_confirmed"]:
			return true
	return false


func _finish_combat(complete: bool) -> void:
	bot.stop()
	await pause(0.3)
	var capture: Dictionary = recorder.finish() if is_instance_valid(recorder) else {}
	var state: Dictionary = {"checks": checks, "failures": failures, "complete": complete, "source_profile_sha256": OS.get_environment("FOLLOWUP_SOURCE_PROFILE"), "source_npc_sha256": OS.get_environment("FOLLOWUP_SOURCE_NPC"), "profile_path": ProjectSettings.globalize_path(profile_path), "sword_uid": sword_uid, "repair": repair_receipt, "dungeon": dungeon_receipt, "contacts": contacts, "confirmed": confirmed, "commits": commits, "motion_samples": motion_samples, "capture": {"wall_seconds": capture.get("wall_seconds", 0.0), "frames": (capture.get("frames", []) as Array).size(), "audio": capture.get("audio", {})}, "scope": "Earned H7 save, normal viewport J/walk/Smith dialogue and repair/Tab right-click/physical portal/bot first floor. No grants, HP, damage, warp, enemy, AI, RNG, or save edits. A dungeon defeat is reported as defeat, never victory; unowned spear is unit-only."}
	if is_instance_valid(flow):
		state["profile_sha256"] = FileAccess.get_sha256(profile_path)
		state["npc_sha256"] = FileAccess.get_sha256(profile_path + ".npc_v1.json")
	if process_frame.is_connected(_watch_frame):
		process_frame.disconnect(_watch_frame)
	if is_instance_valid(recorder):
		recorder.queue_free()
	if is_instance_valid(bot):
		bot.queue_free()
	if is_instance_valid(flow):
		flow.queue_free()
	current_scene = null
	await _step(8)
	await root.get_node("AudioManager").shutdown()
	var file: FileAccess = FileAccess.open(evidence.path_join("followup-combat-route.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state, "\t", true, true))
		file.close()
	print("RESULT FollowupCombat checks=%d failures=%d complete=%s wall=%.3f" % [checks, failures, complete, float(state["capture"]["wall_seconds"])])
	quit(0 if complete and failures == 0 else 1)

extends SceneTree
## Focused opening integration using real scenes and isolated synthetic profiles.
class FaultProfile extends SanctuaryProfile:
	var failure_stage: StringName = &""
	var reject: bool = false
	var writes: int = 0
	func save() -> bool:
		# Count owner transaction attempts, not the journal's multiple file writes.
		writes += 1
		return super.save()
	func _open_writer(path: String) -> FileAccess:
		var failed: bool = failure_stage == &"write" or (failure_stage == &"decision_write" and path == save_path + ".decision.tmp")
		return null if reject and failed else super._open_writer(path)
	func _copy_file(source: String, target: String) -> Error:
		# Standalone purchase fixtures still exercise the real legacy v1 backend.
		if reject and profile_version == 1 and failure_stage == &"decision_write": return ERR_CANT_CREATE
		return super._copy_file(source, target)
	func _rename_file(source: String, target: String) -> Error:
		var history_publish: bool = source == save_path + ".decision.tmp" and target == save_path + ".decision" if profile_version == 2 else source == save_path + ".bak.tmp" and target == save_path + ".bak"
		var matches: bool = (failure_stage == &"commit" and source == save_path + ".tmp" and target == save_path) or (failure_stage == &"decision_commit" and history_publish)
		return ERR_CANT_CREATE if reject and matches else super._rename_file(source, target)

var checks: int = 0
var failures: int = 0
var directory: String

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)
	else: print("PASS: " + label)

func _step(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func _dialogue_key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code; event.keycode = code; event.pressed = true
	root.push_input(event, true)
	await _step(2)
	event.pressed = false
	root.push_input(event, true)
	await _step(2)

func _dialogue_mouse(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = position
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT; event.position = position; event.pressed = true
	root.push_input(event, true)
	await _step(2)
	event.pressed = false
	root.push_input(event, true)
	await _step(2)

func _reader(profile: SanctuaryProfile) -> SanctuaryProfile:
	var reader := SanctuaryProfile.new()
	reader.save_path = profile.save_path
	_check(reader.load_profile(), "Synthetic profile reload succeeds")
	return reader

func _new_flow(id: String) -> GameFlow:
	var flow := GameFlow.new()
	flow.hub_scene = preload("res://scenes/hub/exterior_hub_room.tscn")
	flow.campaign_scene = preload("res://scenes/world_campaign.tscn")
	flow.world_building_enabled = true
	flow.save_path_override = directory + "/" + id + "/profile.json"
	root.add_child(flow)
	return flow

func _fault(flow: GameFlow) -> FaultProfile:
	var bank := FaultProfile.new()
	bank.save_path = flow.profile.save_path
	_check(bank.load_profile(), "Fault injection starts from a valid committed safe wardrobe")
	flow.profile = bank
	var hub: PrologueHub = flow.active_scene as PrologueHub
	hub.profile = bank
	hub.economy.profile = bank
	return bank

func _boss_soul(run: DungeonRun) -> LootPickup:
	for pickup: LootPickup in run.gear.loot.get_children():
		pickup.automatic = false
		if pickup.kind == &"soul" and pickup.opening_reward: return pickup
	return null

func _prepare_boss(run: WorldCampaign) -> void:
	run.gear.loot.drop_table = run.gear.loot.drop_table.duplicate(true) as DropTableResource
	run.gear.loot.drop_table.none_chance = 0.0
	run.gear.loot.drop_table.blueprint_chance_total = 0.0
	run.enter_stage(4)
	run.feedback.hit_stop_seconds = 0.0
	run.feedback.enable_global_hitstop(false)

func _run() -> void:
	var allowed_user_root: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
		if argument.begins_with("--opening-user-root="): allowed_user_root = argument.trim_prefix("--opening-user-root=").replace("\\", "/").trim_suffix("/")
	var actual_user_dir: String = OS.get_user_data_dir().replace("\\", "/")
	if allowed_user_root.is_empty() or not actual_user_dir.begins_with(allowed_user_root + "/"):
		print("FAIL: Refusing opening test without a verified isolated user directory")
		quit(2)
		return
	print("ISOLATED_USER_DIR: " + actual_user_dir)
	directory = "user://opening_loop_%d_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec(), Engine.physics_ticks_per_second]
	print("OPENING LOOP: %d Hz, Windows native file I/O fault boundaries" % Engine.physics_ticks_per_second)
	await _test_opening()
	await _test_dungeon_exploration()
	for stage: StringName in [&"write", &"decision_write", &"decision_commit", &"commit"]:
		await _test_reward_recovery(stage)
		await _test_return_recovery(stage)
		_test_upgrade_bounty_faults(stage)
		await _test_pickup_transition_escrow(&"soul", stage)
		await _test_pickup_transition_escrow(&"blueprint", stage)
	await _test_death_escrow()
	_test_extension()
	_check(is_equal_approx(Engine.time_scale, 1.0), "Opening teardown releases every modal time claim")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_opening() -> void:
	var flow: GameFlow = _new_flow("opening")
	await _step(2)
	var hub: ExteriorHub = flow.active_scene as ExteriorHub
	var bank: FaultProfile = _fault(flow)
	_check(bank.opening_objectives()["completed"].is_empty() and hub.player.controls_enabled, "Fresh profile has no fabricated opening milestones and permits free walking")
	bank.failure_stage = &"commit"
	bank.reject = true
	_check(not hub.enter_exterior(&"o01_p01") and bank.opening_objectives()["completed"].is_empty() and not hub.outside, "Failed geographic commit rolls exploration objective and movement back together")
	bank.reject = false
	_check(hub.enter_exterior(&"o01_p01") and bank.opening_objectives()["completed"] == ["explored"], "Real exterior door commits exploration once")
	_check(hub.return_to_hub() and hub.economy.accept_bounty(&"golem_hunt"), "Optional exploration returns freely before accepting the existing Golem bounty")
	await _step(2)
	flow.start_campaign()
	await _step(2)
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	_prepare_boss(run)
	run.boss.health.apply_damage(9999)
	await _step(4)
	var soul: LootPickup = _boss_soul(run)
	_check(run.portal_active and bank.boss_proofs[&"golem"] == 1 and bank.opening_objectives()["completed"].has("golem_defeated") and bank.souls == 0, "Actual Golem death records proof/objective without automatically banking its Soul reward")
	_check(soul != null and soul.quantity == 25 and soul.collect() and not soul.collect() and bank.souls == 25, "One actual Golem Soul mote commits exactly 25 Souls and its reward milestone")
	run._boss_defeated()
	await _step(3)
	_check(bank.boss_proofs[&"golem"] == 1 and bank.boss_receipts.size() == 1, "Repeated boss callbacks cannot duplicate proof receipts or rewards")
	_check(run.win() and flow.show_hub(false), "Existing portal victory returns and commits the opening return milestone")
	await _step(3)
	hub = flow.active_scene as ExteriorHub
	var before_hp: float = hub.player.health.maximum_health
	_check(hub.open_npc(NpcCatalog.HEALER) and bank.opening_objectives()["completed"].has("thanh_vy_met"), "Opening Thanh Vy's real dialogue records the encounter")
	hub.dialogue.advance()
	hub.dialogue.select_choice(&"upgrade_max_hp")
	_check(bank.souls == 25 and bank.permanent_upgrades[&"max_hp"] == 0 and hub.dialogue.page_index == 0, "Opening service cannot spend before the final live-balance page")
	for attempt: int in hub.dialogue.pages.size() * 2 + 2:
		if hub.dialogue.page_index == hub.dialogue.pages.size() - 1 and not hub.dialogue.is_typing(): break
		await _dialogue_key(KEY_E)
	var hp_button: Button = hub.dialogue.choice_list.get_node_or_null("Choice_upgrade_max_hp") as Button
	_check(hp_button != null and not hp_button.disabled and hub.dialogue.choice_list.visible, "Final Thanh Vy page exposes the real twenty-Soul HP service")
	if hp_button != null and not hp_button.disabled:
		hub.dialogue.body_scroll.ensure_control_visible(hp_button)
		await _step(3)
		await _dialogue_mouse(hp_button.get_global_rect().get_center())
	_check(bank.souls == 5 and bank.permanent_upgrades[&"max_hp"] == 1 and is_equal_approx(hub.player.health.maximum_health, before_hp + 10), "Thanh Vy's existing first HP upgrade consumes 20 Souls and adds ten maximum HP")
	hub.dialogue.close()
	_check(bank.opening_objectives()["complete"] and _reader(bank).opening_objectives()["complete"], "All six real opening milestones survive reload")
	var detached: Dictionary = bank.opening_objectives()
	detached["completed"].clear()
	_check(bank.opening_objectives()["complete"], "Tracker snapshot cannot mutate permanent objective state")
	_check(hub.economy.claim_bounty(&"golem_hunt") and not hub.economy.claim_bounty(&"golem_hunt"), "Bounty is claimed once after the real Golem proof")
	var reward: GearItem
	for item: GearItem in hub.gear.inventory.items.values():
		if item.definition_id == &"ancient_sword_bounty": reward = item
	reward.enhancement_level = 4
	reward.drop_bonus = 0.05
	reward.affix_id = &""
	hub.gear.inventory.equip_equipment(reward.uid)
	hub.economy._save_safe()
	var lost_uid: int = reward.uid
	flow.start_campaign()
	await _step(2)
	run = flow.active_scene as WorldCampaign
	_check(run.player.equipped_weapon.definition.id == &"ancient_sword_bounty", "Prepared run uses the claimed four-hit moveset")
	run.player.health.apply_damage(9999)
	_check(flow.show_hub(true), "Equipped death returns through the ownership boundary")
	await _step(3)
	hub = flow.active_scene as ExteriorHub
	var fresh: GearItem = hub.gear.inventory.items[hub.gear.inventory.equipped_weapon_uid]
	_check(fresh.definition_id == &"ancient_sword_bounty" and fresh.uid != lost_uid and fresh.enhancement_level == 0 and fresh.drop_bonus == 0.0 and fresh.affix_id == &"" and fresh.quality == GearItem.Quality.COMMON, "Death retains learned combo on one fresh plain starter UID, without restoring lost bonuses")
	_check(not hub.gear.inventory.items.has(lost_uid) and not hub.economy.claim_bounty(&"golem_hunt") and bank.unlocked_weapons.count(&"ancient_sword_bounty") == 1, "Dead reward UID is absent and neither bounty nor permanent unlock can duplicate")
	var stored: SanctuaryProfile = _reader(bank)
	var restored: GearInventory = GearInventoryCodec.decode(stored.hub_inventory)
	_check(restored != null and restored.items[restored.equipped_weapon_uid].definition_id == &"ancient_sword_bounty" and stored.souls == 5 and stored.opening_objectives()["complete"], "Death/reload preserves combo preparation, banked Souls, first upgrade and objectives")
	flow.start_campaign()
	await _step(2)
	run = flow.active_scene as WorldCampaign
	_check(run.player.equipped_weapon.definition.id == &"ancient_sword_bounty", "Next prepared run retains combo access after death")
	flow.queue_free()
	await _step(5)

func _test_reward_recovery(stage: StringName) -> void:
	var flow: GameFlow = _new_flow("reward_" + String(stage))
	await _step(2)
	var bank: FaultProfile = _fault(flow)
	flow.start_campaign()
	await _step(2)
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	_prepare_boss(run)
	bank.failure_stage = stage
	bank.reject = true
	var original: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	run.boss.health.apply_damage(9999)
	await _step(4)
	var soul: LootPickup = _boss_soul(run)
	_check(run.has_pending_rewards() and bank.boss_proofs[&"golem"] == 0 and bank.boss_receipts.is_empty() and not bank.opening_objectives()["completed"].has("golem_defeated"), "%s proof failure rolls receipt and objective back" % stage)
	var nested_collection: Callable = func(pickup: LootPickup) -> void: _check(not pickup.collect(), "%s failed pickup callback cannot recursively retry a disk write" % stage)
	soul.save_retry_required.connect(nested_collection)
	_check(soul != null and not soul.collect() and soul.save_retry_pending and bank.souls == 0 and not bank.opening_objectives()["completed"].has("reward_collected"), "%s Soul failure retains one explicit pending reward with no phantom milestone" % stage)
	soul.save_retry_required.disconnect(nested_collection)
	soul.life = 0.001
	var before: int = bank.writes
	await _step(20)
	_check(bank.writes == before and is_instance_valid(soul) and run.player.controls_enabled and FileAccess.get_file_as_bytes(bank.save_path) == original, "%s errors cause no frame retries, expiry, movement lock or committed-file corruption" % stage)
	var uids: Array = run.gear.inventory.items.keys().duplicate()
	run.finish(&"victory")
	_check(not flow.show_hub(false) and flow.return_save_pending and flow.active_scene == run and run.gear.inventory.items.keys() == uids, "%s pending proof/reward prevents scene reset before a retry decision" % stage)
	before = bank.writes
	for index: int in 20: flow._process(1.0)
	flow.start_campaign()
	_check(bank.writes == before and flow.active_scene == run, "%s return timer and repeated launch cannot retry or replace a pending run" % stage)
	bank.reject = false
	var reentrant: Callable = func() -> void:
		flow.show_hub(false)
		flow.start_campaign()
	bank.changed.connect(reentrant)
	_check(flow.retry_pending_return(), "%s explicit retry resolves proof, Soul escrow and return" % stage)
	bank.changed.disconnect(reentrant)
	await _step(3)
	_check(flow.active_scene is PrologueHub and bank.boss_proofs[&"golem"] == 1 and bank.boss_receipts.size() == 1 and bank.souls == 25 and not flow.retry_pending_return(), "%s successful and reentrant callbacks commit each reward exactly once" % stage)
	var stored: SanctuaryProfile = _reader(bank)
	_check(stored.boss_proofs[&"golem"] == 1 and stored.souls == 25 and stored.opening_objectives()["completed"].has("returned_to_hub"), "%s recovered rewards and return are durable" % stage)
	flow.queue_free()
	await _step(5)

func _test_return_recovery(stage: StringName) -> void:
	var flow: GameFlow = _new_flow("return_" + String(stage))
	await _step(2)
	var bank: FaultProfile = _fault(flow)
	flow.start_campaign()
	await _step(2)
	var run: DungeonRun = flow.active_scene as DungeonRun
	run.gear.inventory.run_coins = 7
	run.gear.inventory.materials[&"crystal"] = 9
	run.finish(&"victory")
	var original: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	var uids: Array = run.gear.inventory.items.keys().duplicate()
	bank.failure_stage = stage
	bank.reject = true
	_check(not flow.show_hub(false) and flow.return_save_pending and bank.coins == 0 and bank.hub_inventory.is_empty() and run.gear.inventory.run_coins == 7 and run.gear.inventory.items.keys() == uids, "%s bank failure keeps coin and UID ownership entirely in the run" % stage)
	var before: int = bank.writes
	for index: int in 20:
		flow._process(1.0)
		flow.show_hub(false)
	_check(bank.writes == before and FileAccess.get_file_as_bytes(bank.save_path) == original, "%s return error stops frame and repeated callback writes" % stage)
	_check(not flow.retry_pending_return() and bank.writes == before + 1 and bank.coins == 0, "%s one explicit failed retry attempts one bank transaction" % stage)
	bank.reject = false
	var reentrant: Callable = func() -> void: flow.show_hub(false)
	bank.changed.connect(reentrant)
	_check(flow.retry_pending_return(), "%s explicit bank retry succeeds" % stage)
	bank.changed.disconnect(reentrant)
	await _step(3)
	_check(bank.coins == 7 and flow.active_scene.gear.inventory.run_coins == 0 and flow.active_scene.gear.inventory.materials[&"crystal"] == 9 and not flow.retry_pending_return(), "%s coins bank once while surviving UID/material ledger moves to Hub" % stage)
	var stored: SanctuaryProfile = _reader(bank)
	_check(stored.coins == 7 and stored.hub_inventory["run_coins"] == 0 and stored.hub_inventory["items"].size() == uids.size(), "%s bank coin/inventory transaction survives reload" % stage)
	flow.queue_free()
	await _step(5)

func _test_death_escrow() -> void:
	var flow: GameFlow = _new_flow("death_escrow")
	await _step(2)
	var bank: FaultProfile = _fault(flow)
	flow.start_campaign()
	await _step(2)
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	_prepare_boss(run)
	run.boss.health.apply_damage(9999)
	await _step(4)
	var soul: LootPickup = _boss_soul(run)
	bank.failure_stage = &"commit"
	bank.reject = true
	_check(not soul.collect(), "Soul save fault begins escrow before death")
	run.gear.inventory.run_coins = 12
	run.player.health.apply_damage(9999)
	_check(not flow.show_hub(true) and flow.active_scene == run, "Death cannot erase an already attempted permanent reward save")
	bank.reject = false
	_check(flow.retry_pending_return() and bank.souls == 25 and bank.coins == 0, "Explicit death recovery banks the earned Soul once and loses carried coins")
	await _step(3)
	_check(flow.active_scene.gear.inventory.run_coins == 0 and _reader(bank).souls == 25, "Death recovery remains durable with a fresh preparation ledger")
	flow.queue_free()
	await _step(5)

func _test_pickup_transition_escrow(kind: StringName, stage: StringName) -> void:
	var label: String = "%s/%s" % [kind, stage]
	var flow: GameFlow = _new_flow("transition_" + String(kind) + "_" + String(stage))
	await _step(2)
	var bank: FaultProfile = _fault(flow)
	flow.start_campaign()
	await _step(2)
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	var pickup: LootPickup = run.gear.loot.spawn(kind, &"souls" if kind == &"soul" else &"world_saber", run.player.global_position, 3 if kind == &"soul" else 1)
	pickup.automatic = false
	var pickup_id: int = pickup.get_instance_id()
	var original: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	bank.failure_stage = stage
	bank.reject = true
	_check(not pickup.collect() and pickup.save_retry_pending and FileAccess.get_file_as_bytes(bank.save_path) == original, "%s failed real collection retains the uncredited reward" % label)
	var previous_room: DungeonRoom = run.room
	var inventory_uids: Array = run.gear.inventory.items.keys().duplicate()
	run.room.set_locked(false)
	_check(run.advance_room() and run.stage == 2 and run.room != previous_room and run.player.controls_enabled, "%s real room advance stays available after a pickup save error" % label)
	var writes_after_transition: int = bank.writes
	await _step(5)
	var retained: bool = is_instance_valid(pickup) and not pickup.is_queued_for_deletion()
	_check(retained and pickup.get_instance_id() == pickup_id and pickup.save_retry_pending and run.pending_reward_state()["pickup_count"] == 1, "%s room cleanup retains the same pending pickup and recovery count" % label)
	_check(retained and run.is_ancestor_of(pickup) and not run.gear.loot.is_ancestor_of(pickup) and not run.room.is_ancestor_of(pickup), "%s pending reward belongs to the persistent run outside disposable room loot" % label)
	_check(bank.writes == writes_after_transition and bank.souls == 0 and bank.learned_blueprints.is_empty() and run.gear.inventory.items.keys() == inventory_uids, "%s transition does not auto-retry, credit, reset or duplicate run ownership" % label)
	_check(not run.retry_pending_rewards() and run.pending_reward_state()["pickup_count"] == 1 and bank.souls == 0 and bank.learned_blueprints.is_empty(), "%s explicit failed retry after room change still retains one reward" % label)
	bank.reject = false
	var notice: RunSaveRecovery
	for child: Node in run.get_children():
		if child is RunSaveRecovery: notice = child as RunSaveRecovery
	_check(notice != null and notice.panel.visible and not notice.retry_button.disabled, "%s nonmodal retry button is available in the next room" % label)
	if notice != null: notice.retry_button.pressed.emit()
	var credited: bool = bank.souls == 3 if kind == &"soul" else bank.learned_blueprints.count(&"world_saber") == 1
	_check(credited and not run.has_pending_rewards() and run.pending_reward_state()["pickup_count"] == 0 and run.gear.inventory.items.keys() == inventory_uids, "%s next-room button credits the retained reward exactly once without resetting gear" % label)
	var writes_after_commit: int = bank.writes
	_check(run.retry_pending_rewards() and bank.writes == writes_after_commit and not (is_instance_valid(pickup) and pickup.collect()), "%s repeated recovery/collection callback cannot write or credit again" % label)
	var stored: SanctuaryProfile = _reader(bank)
	_check((stored.souls == 3 if kind == &"soul" else stored.learned_blueprints.count(&"world_saber") == 1), "%s room-transition recovery survives profile reload" % label)
	await _step(2)
	_check(not is_instance_valid(pickup), "%s committed escrow collectible releases its run owner" % label)
	run.gear.inventory.run_coins = 7
	run.finish(&"victory")
	_check(flow.show_hub(false), "%s recovered run can return and bank remaining gear/coins" % label)
	await _step(3)
	flow.show_hub(false)
	await _step(2)
	stored = _reader(bank)
	_check(bank.coins == 7 and stored.coins == 7 and (stored.souls == 3 if kind == &"soul" else stored.learned_blueprints.count(&"world_saber") == 1), "%s repeated Hub callback banks seven coins and the recovered reward once" % label)
	flow.queue_free()
	await _step(5)

func _test_dungeon_exploration() -> void:
	var flow: GameFlow = _new_flow("dungeon_exploration")
	await _step(2)
	var bank: FaultProfile = _fault(flow)
	flow.start_campaign()
	await _step(2)
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	bank.failure_stage = &"commit"
	bank.reject = true
	_check(run.enter_stage(2) and run.player.controls_enabled and run.has_pending_rewards() and bank.opening_objectives()["completed"].is_empty(), "Existing dungeon exploration remains walkable with one explicitly pending milestone on save error")
	var before: int = bank.writes
	await _step(20)
	_check(bank.writes == before and run.pending_reward_state()["objective_count"] == 1, "Dungeon exploration milestone does not retry writes each frame")
	bank.reject = false
	_check(run.retry_pending_rewards() and not run.has_pending_rewards() and _reader(bank).opening_objectives()["completed"] == ["explored"], "Existing exploration room's real entry persists on explicit retry without requiring any kill")
	flow.queue_free()
	await _step(5)

func _test_upgrade_bounty_faults(stage: StringName) -> void:
	var bank := FaultProfile.new()
	bank.save_path = directory + "/purchase_" + String(stage) + "/profile.json"
	bank.souls = 25
	var inventory: GearInventory = HubPreparation.starter_inventory()
	var economy := EconomySession.new()
	economy.initialize(bank, inventory)
	economy.persist_safe_inventory = true
	_check(economy._save_safe(), "%s first-upgrade fixture commits only a starter wardrobe and 25 Souls" % stage)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	bank.failure_stage = stage
	bank.reject = true
	_check(not economy.buy_upgrade(&"max_hp") and bank.souls == 25 and bank.permanent_upgrades[&"max_hp"] == 0 and not bank.opening_objectives()["completed"].has("first_upgrade") and FileAccess.get_file_as_bytes(bank.save_path) == original, "%s first-upgrade failure rolls cost, level, objective and disk back together" % stage)
	bank.reject = false
	var nested_buy: Callable = func() -> void: _check(not economy.buy_upgrade(&"max_hp"), "%s upgrade callback cannot recursively purchase another level" % stage)
	bank.changed.connect(nested_buy)
	_check(economy.buy_upgrade(&"max_hp") and bank.souls == 5 and bank.permanent_upgrades[&"max_hp"] == 1 and bank.opening_objectives()["completed"].has("first_upgrade"), "%s explicit upgrade retry charges 20 Souls once" % stage)
	bank.changed.disconnect(nested_buy)
	_check(economy.accept_bounty(&"golem_hunt") and bank.record_boss_defeat("purchase-boss"), "%s bounty fixture accepts before its sole proof" % stage)
	var before_count: int = inventory.items.size()
	original = FileAccess.get_file_as_bytes(bank.save_path)
	bank.reject = true
	_check(not economy.claim_bounty(&"golem_hunt") and not bank.bounty_claimed and not bank.unlocked_weapons.has(&"ancient_sword_bounty") and inventory.items.size() == before_count and FileAccess.get_file_as_bytes(bank.save_path) == original, "%s bounty failure leaves no provisional reward UID, unlock or claimed flag" % stage)
	bank.reject = false
	var nested_claim: Callable = func() -> void: _check(not economy.claim_bounty(&"golem_hunt"), "%s bounty callback cannot recursively grant another reward" % stage)
	bank.changed.connect(nested_claim)
	_check(economy.claim_bounty(&"golem_hunt") and inventory.items.size() == before_count + 1 and bank.unlocked_weapons.count(&"ancient_sword_bounty") == 1, "%s bounty retry grants exactly one sword and unlock" % stage)
	bank.changed.disconnect(nested_claim)
	_check(not economy.claim_bounty(&"golem_hunt") and inventory.items.size() == before_count + 1, "%s repeated bounty click cannot regrant its sword" % stage)
	var stored: SanctuaryProfile = _reader(bank)
	_check(stored.souls == 5 and stored.permanent_upgrades[&"max_hp"] == 1 and stored.bounty_claimed and stored.unlocked_weapons.count(&"ancient_sword_bounty") == 1, "%s purchase and bounty outcomes survive reload without duplication" % stage)
	# Simulate the old bug's already-saved post-death regular wardrobe.
	var legacy: GearInventory = HubPreparation.starter_inventory()
	var current_uid: int = legacy.equipped_weapon_uid
	economy.inventory = legacy
	var fresh_sword: GearItem = legacy.items[current_uid]
	var legacy_count: int = legacy.items.size()
	_check(economy._save_safe() and economy.quote_bounty(&"golem_hunt")["can_reclaim"], "%s old post-death save exposes learned moveset recovery without reopening the bounty" % stage)
	bank.reject = true
	_check(not economy.reclaim_bounty_moveset(&"golem_hunt") and fresh_sword.definition_id == &"ancient_sword" and legacy.items.size() == legacy_count, "%s reclaim save failure rolls the owned starter definition back" % stage)
	bank.reject = false
	_check(economy.reclaim_bounty_moveset(&"golem_hunt") and fresh_sword.uid == current_uid and fresh_sword.definition_id == &"ancient_sword_bounty" and fresh_sword.enhancement_level == 0 and fresh_sword.affix_id == &"" and legacy.items.size() == legacy_count, "%s reclaim teaches the existing fresh UID without restoring or granting a reward item" % stage)
	_check(not economy.reclaim_bounty_moveset(&"golem_hunt") and not economy.claim_bounty(&"golem_hunt") and bank.souls == 5 and legacy.items.size() == legacy_count, "%s repeated reclaim/bounty callbacks cannot duplicate gear or payment" % stage)
	stored = _reader(bank)
	var reclaimed: GearInventory = GearInventoryCodec.decode(stored.hub_inventory)
	_check(reclaimed.items[current_uid].definition_id == &"ancient_sword_bounty" and stored.bounty_claimed and stored.unlocked_weapons.count(&"ancient_sword_bounty") == 1, "%s reclaimed starter moveset survives reload with one owned UID" % stage)

func _test_extension() -> void:
	var bank := SanctuaryProfile.new()
	bank.save_path = directory + "/extension/profile.json"
	_check(bank.save(), "Legacy profile fixture saves without any opening extension")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(bank.save_path))
	_check(not payload.has("opening_progress") and bank.load_profile() and bank.opening_objectives()["completed"].is_empty(), "Absent extension keeps legacy save shape and fabricates no completion")
	for malformed: Variant in [{"version": 1, "completed": ["invented"]}, {"version": 1, "completed": ["explored", "explored"]}, {"version": 1, "completed": true}]:
		payload["opening_progress"] = malformed
		var writer: FileAccess = FileAccess.open(bank.save_path, FileAccess.WRITE)
		writer.store_string(JSON.stringify(payload))
		writer.close()
		_check(bank.load_profile() and bank.opening_progress_quarantined and bank.opening_objectives()["completed"].is_empty(), "Malformed opening extension quarantines independently of permanent progress")
	payload["opening_progress"] = {"version": 2, "completed": []}
	var writer: FileAccess = FileAccess.open(bank.save_path, FileAccess.WRITE)
	writer.store_string(JSON.stringify(payload))
	writer.close()
	var original: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	_check(not bank.load_profile() and not bank.save() and FileAccess.get_file_as_bytes(bank.save_path) == original, "Future opening extension cannot be overwritten by this build")

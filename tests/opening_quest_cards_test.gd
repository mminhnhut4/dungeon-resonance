extends SceneTree
## Actual quest UI/reward owners, only synthetic saves under verified user://.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
var checks: int = 0
var failures: int = 0
var directory: String
var flow: GameFlow
var examples: Dictionary = {}

func _initialize() -> void: _run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _step(n: int = 4) -> void:
	for _index: int in n: await physics_frame
func _open(path: String) -> ExteriorHub:
	flow = GameFlow.new()
	flow.hub_scene = preload("res://scenes/hub/exterior_hub_room.tscn")
	flow.campaign_scene = preload("res://scenes/world_campaign.tscn")
	flow.world_building_enabled = true; flow.save_path_override = path
	root.add_child(flow); await _step(8)
	var hub: ExteriorHub = flow.active_scene as ExteriorHub
	if hub != null: hub.npc_population.set_process(false)
	return hub
func _close() -> void:
	flow.queue_free(); await _step(6); flow = null
func _row(journal: QuestJournal,id: StringName) -> Dictionary:
	for row: Dictionary in journal.rows:
		if row["id"] == id: return row
	return {}
func _reward_count(inventory: GearInventory) -> int:
	var count: int = 0
	for item: GearItem in inventory.items.values():
		if item.definition_id == WorldProgressionCatalog.BOUNTY_REWARD: count += 1
	return count
func _snapshot(profile: SanctuaryProfile,inventory: GearInventory) -> String:
	return JSON.stringify({"opening":profile.opening_progress,"cultivation":profile.cultivation_progress,"souls":profile.souls,"coins":profile.coins,"bank":profile.material_stash,"proofs":profile.boss_proofs,"accepted":profile.bounty_accepted,"claimed":profile.bounty_claimed,"inventory":GearInventoryCodec.encode(inventory)})

func _old_and_end_state() -> void:
	var bank := SanctuaryProfile.new(); bank.save_path = directory+"/old/profile.json"
	for id: StringName in [&"explored",&"thanh_vy_met"]: bank.opening_progress = OpeningProgress.with_event(bank.opening_progress,id)
	_check(bank.save(),"Old-save fixture durably records only the two audited milestones")
	var hub: ExteriorHub = await _open(bank.save_path)
	var screen: InventoryScreen = hub.gear.modal as InventoryScreen
	var journal: QuestJournal = screen.journal
	screen.open_map(); await _step()
	_check(journal.selected_id == &"golem_defeated" and journal.rows[0]["id"] == &"golem_defeated", "Audited old-save shape opens unfinished bounty first")
	_check("CẦN LÀM TIẾP" in journal.detail_title.text and "Kiếm Lữ Hành" in journal.objective_label.text and "Vô Danh" in journal.objective_label.text,"Default detail gives action, actual reward and concrete NPC")
	var button: Button = journal.quest_buttons[&"golem_defeated"]
	_check(button.has_theme_stylebox_override(&"normal") and button.get_theme_stylebox(&"normal") is StyleBoxTexture and button.text.contains("0/1"),"Active card has gold antique frame and text/counter cues")
	_check(journal.quest_buttons[&"explored"].text.begins_with("✓ ĐÃ HOÀN THÀNH") and journal.quest_buttons[&"explored"].has_theme_color_override(&"font_color"),"Completed card has checkmark plus muted text")
	_check(root.gui_get_focus_owner() == button and not journal.action_button.disabled,"Native keyboard focus and live accept binding select active card")
	var geometry: Array[Dictionary] = []
	journal.action_notice.text = "Chưa nhận: kiểm tra chứng tích, một ô túi trống và trạng thái lưu. Có thể thử lại."
	journal.action_notice.show()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size = Vector2i.ZERO
	for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = extent; await _step(5); screen._resize(); await _step(3)
		var bounds: Rect2 = root.get_visible_rect()
		_check(bounds.encloses(screen.panel.get_global_rect()),"Quest panel stays inside viewport %s" % extent)
		_check(screen.content_scroll.get_global_rect().encloses(journal.action_button.get_global_rect()),"Reward action is visible in quest page %s" % extent)
		_check(screen.content_scroll.get_global_rect().encloses(journal.detail_scroll.get_global_rect()),"Structured objective detail is visible %s" % extent)
		journal.scroll_detail(10000); await _step(2)
		_check(journal.detail_scroll.scroll_vertical > 0,"Long Vietnamese detail remains scrollable %s" % extent)
		journal.detail_scroll.scroll_vertical = 0
		geometry.append({"viewport":str(extent),"panel":str(screen.panel.get_global_rect()),"page":str(screen.content_scroll.get_global_rect()),"action":str(journal.action_button.get_global_rect()),"detail":str(journal.detail_scroll.get_global_rect())})
	examples["geometry"] = geometry
	journal.action_notice.hide()
	root.size = Vector2i(1280,720); await _step(3)
	var before: String = _snapshot(flow.profile,hub.gear.inventory)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(flow.profile.save_path)
	for _n: int in 3: journal.refresh(); journal.focus_recommended()
	_check(_snapshot(flow.profile,hub.gear.inventory) == before and FileAccess.get_file_as_bytes(flow.profile.save_path) == bytes,"Reading/rebuilding cards never saves or grants a reward")
	_check(journal.graph.buttons[&"o01_p02"].text.contains("?") and journal.tracker_text().is_empty() and not screen.tracker.visible,"Unknown map remains concealed and gameplay has no mission overlay")
	examples["audited_old_shape"] = journal.rows.duplicate(true)
	screen.close(); await _step()
	_check(not screen._quest_action(&"bounty_accept")["ok"] and not flow.profile.bounty_accepted,"Closed UI rejects a stale quest command")
	await _close()
	var profile := SanctuaryProfile.new(); profile.cultivation_progress = Model.new_progress(4)
	var kit: GearInventory = HubPreparation.starter_inventory(profile)
	for id: StringName in OpeningProgress.IDS:
		if id != &"reward_collected": profile.opening_progress = OpeningProgress.with_event(profile.opening_progress,id)
	profile.cultivation_progress["actors"]["player"]["insight_ids"] = ["explored","golem_defeated","thanh_vy_met"]
	profile.bounty_accepted = true; profile.bounty_claimed = true
	var rows: Array[Dictionary] = OpeningQuestCards.decorate(MapQuestProjection.rows(profile,kit),profile,kit)
	_check(rows[0]["id"] == &"cultivation_breakthrough" and rows.any(func(row: Dictionary) -> bool: return row["id"] == &"reward_collected" and row["card"]["optional"]),"Successful return without random loot still offers cultivation next")
	profile.cultivation_progress["actors"]["player"]["stage"] = 3
	profile.cultivation_progress["actors"]["player"]["energy"] = profile.cultivation_progress["config"]["energy_thresholds"][2]
	profile.cultivation_progress["actors"]["player"]["mastery"] = profile.cultivation_progress["config"]["mastery_thresholds"][2]
	rows = OpeningQuestCards.decorate(MapQuestProjection.rows(profile,kit),profile,kit)
	_check(rows[0]["id"] == &"prepare_next_run" and "không bảo đảm" in rows[0]["card"]["reward"],"Completed cultivation offers an honest optional next trip, no invented realm/reward")
	profile.read_only = true; profile.bounty_claimed = false
	rows = OpeningQuestCards.decorate(MapQuestProjection.rows(profile,kit),profile,kit)
	_check(rows.all(func(row: Dictionary) -> bool: return not row["card"]["command_enabled"]),"Read-only profiles never show an enabled claim/accept command")

func _insight_retry() -> void:
	var hub: ExteriorHub = await _open(directory+"/insight/profile.json")
	var bank: SanctuaryProfile = flow.profile
	# Synthetic saved milestone from an interrupted older session: no fake UI grant.
	bank.opening_progress = OpeningProgress.with_event(bank.opening_progress,&"explored")
	_check(bank.save(),"Pending-insight fixture saves the actual milestone through existing writer")
	bank._writer.fault_plan = {"write_candidate":true}
	hub.cultivation_session._sync_insights()
	var screen: InventoryScreen = hub.gear.modal as InventoryScreen
	screen.open_map(); await _step()
	var journal: QuestJournal = screen.journal
	_check(not OpeningQuestCards.insights_ready(bank) and _row(journal,&"explored")["card"]["command"] == &"retry_insights","Failed real insight commit shows pending reward and explicit retry")
	journal.select_quest(&"explored"); journal._request_action(); await _step()
	_check(OpeningQuestCards.insights_ready(bank) and bank.cultivation_progress["actors"]["player"]["insight_ids"].count("explored") == 1,"Quest retry delegates to existing cultivation owner and earns exactly one insight")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	_check(screen._quest_action(&"retry_insights")["ok"] and FileAccess.get_file_as_bytes(bank.save_path) == bytes,"Repeated insight retry cannot add another receipt or disk change")
	await _close()

func _reward_loop() -> void:
	var hub: ExteriorHub = await _open(directory+"/loop/profile.json")
	var bank: SanctuaryProfile = flow.profile
	var screen: InventoryScreen = hub.gear.modal as InventoryScreen
	screen.open_map(); await _step()
	_check(screen.journal.selected_id == &"explored" and "ĐƯỜNG BỘ" in screen.journal.objective_label.text,"Fresh game starts with a concrete exploration objective")
	screen.close(); await _step()
	_check(hub.enter_exterior(&"o01_p01") and hub.return_to_hub(),"Real route entrance and return record exploration")
	_check(bank.cultivation_progress["actors"]["player"]["insight_ids"].count("explored") == 1,"Actual route completion auto-grants one cultivation insight")
	screen.open_map(); await _step()
	screen.journal._request_action(); await _step()
	_check(bank.bounty_accepted and not bank.bounty_claimed and _reward_count(hub.gear.inventory) == 0,"Accept button records contract without minting its reward")
	_check(not screen._quest_action(&"bounty_accept")["ok"] and not screen._quest_action(&"bounty_claim")["ok"],"Double accept and premature claim are rejected by canonical owner")
	screen.close(); await _step()
	flow.start_campaign(); await _step(8)
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	var run_screen: InventoryScreen = run.gear.modal as InventoryScreen
	run_screen.open_map(); await _step()
	_check(not run_screen._quest_action(&"bounty_claim")["ok"],"Dungeon context cannot claim a camp reward")
	run_screen.close(); await _step()
	run.gear.loot.drop_table = run.gear.loot.drop_table.duplicate(true) as DropTableResource
	run.gear.loot.drop_table.none_chance = 0.0; run.gear.loot.drop_table.blueprint_chance_total = 0.0
	run.enter_stage(4); run.feedback.hit_stop_seconds = 0.0; run.feedback.enable_global_hitstop(false)
	run.boss.health.apply_damage(9999); await _step(5)
	var soul: LootPickup
	for pickup: LootPickup in run.gear.loot.get_children():
		pickup.automatic = false
		if pickup.kind == &"soul" and pickup.opening_reward: soul = pickup
	_check(bank.boss_proofs[&"golem"] == 1 and soul != null,"Real boss death provides one canonical proof and deterministic fixture loot")
	_check(soul != null and soul.collect() and not soul.collect() and bank.souls == 25,"Real pickup grants 25 Souls once, separately from journal bounty")
	_check(run.win() and flow.show_hub(false),"Real victory returns through existing return owner")
	await _step(8); hub = flow.active_scene as ExteriorHub; hub.npc_population.set_process(false)
	screen = hub.gear.modal as InventoryScreen; screen.open_map(); await _step()
	_check(screen.journal.selected_id == &"golem_defeated" and not screen.journal.action_button.disabled and "1/1" in screen.journal.objective_label.text,"Ready reward becomes default with enabled claim and actual proof counter")
	var kit: GearInventory = hub.gear.inventory
	var filler: EquipmentData = preload("res://data/equipment/ancient_sword_bounty.tres")
	var added: Array[int] = []
	while kit.equipment_bag_uids().size() < GearInventory.EQUIPMENT_BAG_CAPACITY:
		var item: GearItem = kit.add_equipment(filler); added.append(item.uid)
	_check(screen.journal.action_button.disabled and not screen._quest_action(&"bounty_claim")["ok"] and not bank.bounty_claimed,"Full bag disables UI and canonical claim keeps reward pending")
	for uid: int in added: kit.items.erase(uid)
	kit.changed.emit(); await _step()
	var before: String = _snapshot(bank,kit)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	bank._writer.fault_plan = {"write_candidate":true}
	screen.journal._request_action(); await _step()
	_check(_snapshot(bank,kit) == before and FileAccess.get_file_as_bytes(bank.save_path) == bytes and not bank.bounty_claimed,"Failed claim write rolls back flag, bank, ledger and item together")
	_check("Chưa nhận" in screen.journal.action_notice.text and not screen.journal.action_button.disabled,"Failed save remains an explicit retryable pending reward")
	screen.journal._request_action(); await _step()
	_check(bank.bounty_claimed and _reward_count(kit) == 1 and bank.unlocked_weapons.count(WorldProgressionCatalog.BOUNTY_REWARD) == 1,"Retry claims exactly one real sword and one permanent moveset unlock")
	var claimed_bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	_check(not screen._quest_action(&"bounty_claim")["ok"] and FileAccess.get_file_as_bytes(bank.save_path) == claimed_bytes,"Repeated claim leaves committed reward bytes unchanged")
	examples["claimed_bounty"] = screen.journal.rows.duplicate(true)
	screen.close(); await _step()
	_check(hub.open_npc(NpcCatalog.HEALER),"Real Thanh Vy dialogue remains reachable")
	hub.dialogue.close()
	_check(bank.cultivation_progress["actors"]["player"]["insight_ids"].count("thanh_vy_met") == 1,"Actual NPC encounter auto-grants one insight")
	var reward: GearItem
	for item: GearItem in kit.items.values():
		if item.definition_id == WorldProgressionCatalog.BOUNTY_REWARD: reward = item
	kit.equip_equipment(reward.uid); hub.economy._save_safe()
	var old_uid: int = reward.uid
	flow.start_campaign(); await _step(8); run = flow.active_scene as WorldCampaign
	run.player.health.apply_damage(9999)
	_check(flow.show_hub(true),"Reward-equipped death returns through existing ownership boundary")
	await _step(8); hub = flow.active_scene as ExteriorHub; hub.npc_population.set_process(false)
	kit = hub.gear.inventory
	_check(bank.bounty_claimed and not kit.items.has(old_uid) and not hub.economy.claim_bounty(WorldProgressionCatalog.BOUNTY_ID),"Death loses old reward UID while permanent receipt forbids another payout")
	var path: String = bank.save_path; await _close()
	hub = await _open(path); screen = hub.gear.modal as InventoryScreen; screen.open_map(); await _step()
	_check(flow.profile.bounty_claimed and _row(screen.journal,&"golem_defeated")["card"]["complete"] and "Đã nhận" in _row(screen.journal,&"golem_defeated")["card"]["reward_status"],"Cold reload displays claimed reward accurately after death")
	_check(not screen._quest_action(&"bounty_claim")["ok"] and OpeningQuestCards.insights_ready(flow.profile),"Cold reload cannot reclaim sword or duplicate synchronized insights")
	await _close()

func _canonical_counter() -> void:
	var profile := SanctuaryProfile.new()
	profile.cultivation_progress = Model.new_progress(4)
	for id: StringName in OpeningProgress.IDS:
		profile.opening_progress = OpeningProgress.with_event(profile.opening_progress,id)
	var kit: GearInventory = HubPreparation.starter_inventory(profile)
	var journal := QuestJournal.new()
	journal.bind_progress(profile,kit)
	root.add_child(journal); await _step()
	var before: String = _snapshot(profile,kit)
	_check(journal.rows.size()==7 and "6 / 6" in journal.state_label.text and "Đã hoàn tất" in journal.state_label.text,"Six completed canonical milestones show 6/6 with the derived cultivation goal")
	journal.extension_rows_provider = func() -> Array[Dictionary]: return [{"id":&"qa_completed_extra","title":"QA extra","body":"Read-only extra","done":true}]
	journal.refresh()
	_check(journal.rows.size()==8 and "6 / 6" in journal.state_label.text,"Completed extension rows never increase the canonical counter")
	profile.cultivation_progress["actors"]["player"]["stage"] = 3
	profile.cultivation_progress["actors"]["player"]["energy"] = profile.cultivation_progress["config"]["energy_thresholds"][2]
	profile.cultivation_progress["actors"]["player"]["mastery"] = profile.cultivation_progress["config"]["mastery_thresholds"][2]
	profile.cultivation_progress["actors"]["player"]["insight_ids"] = ["explored","golem_defeated","thanh_vy_met"]
	journal.refresh()
	_check(journal.quest_buttons.has(&"prepare_next_run") and "6 / 6" in journal.state_label.text,"Optional next-trip goal never changes the completed milestone denominator")
	profile.opening_progress = OpeningProgress.empty()
	for id: StringName in [&"explored",&"thanh_vy_met"]: profile.opening_progress = OpeningProgress.with_event(profile.opening_progress,id)
	journal.refresh()
	_check("2 / 6" in journal.state_label.text and not "Đã hoàn tất" in journal.state_label.text,"Partial canonical progress remains 2/6 despite a completed extension")
	var after_setup: String = _snapshot(profile,kit)
	journal.refresh()
	_check(_snapshot(profile,kit)==after_setup and before!=after_setup,"Canonical counter refresh remains a read-only projection")
	journal.queue_free(); await _step()

func _early_guidance() -> void:
	var profile := SanctuaryProfile.new()
	profile.cultivation_progress = Model.new_progress(4)
	var kit: GearInventory = HubPreparation.starter_inventory(profile)
	var before: String = _snapshot(profile,kit)
	var rows: Array[Dictionary] = OpeningQuestCards.decorate(MapQuestProjection.rows(profile,kit),profile,kit)
	_check(rows.any(func(row: Dictionary) -> bool: return row["id"] == &"cultivation_breakthrough" and row["card"]["optional"]),"Cultivation route is visible before all opening milestones are complete")
	_check("mộc nhân" in OpeningProgressionGuide.cultivation_next_step(profile),"Fresh player receives the concrete mastery action")
	_check(_snapshot(profile,kit) == before,"Guidance does not grant training or mutate resources")
	var actor: Dictionary = profile.cultivation_progress["actors"]["player"]
	actor["mastery"] = 8
	_check("KHO CĂN CỨ" in OpeningProgressionGuide.cultivation_next_step(profile),"Missing bank crystal points to collection and deposit")
	profile.material_stash[&"crystal"] = 1
	_check("đóng bảng" in OpeningProgressionGuide.cultivation_next_step(profile),"Funded training tells player to close the menu")
	actor["energy"] = 40
	_check("ĐƯỜNG BỘ" in OpeningProgressionGuide.cultivation_next_step(profile),"Missing insight names the actual road interaction")
	actor["insight_ids"] = ["explored"]
	_check("Bột Phép" in OpeningProgressionGuide.cultivation_next_step(profile),"Missing breakthrough cost names its bank material")
	profile.material_stash[&"dust"] = 4
	_check("Đủ điều kiện" in OpeningProgressionGuide.cultivation_next_step(profile),"Ready player receives the exact breakthrough destination")

func _run() -> void:
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/") or DisplayServer.get_name() != "headless":
		print("FAIL: requires verified isolated user:// and headless engine"); quit(2); return
	directory = "user://verification/quest_cards_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	AudioServer.set_bus_mute(0,true)
	_early_guidance()
	await _canonical_counter(); await _old_and_end_state(); await _insight_retry(); await _reward_loop()
	_check(is_equal_approx(Engine.time_scale,1.0),"Quest teardown releases modal time ownership")
	DirAccess.make_dir_recursive_absolute("res://docs/verification/quest_cards")
	var file := FileAccess.open("res://docs/verification/quest_cards/vn_cards.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(examples,"\t")); file.close()
	print("RESULT OpeningQuestCards checks=%d failures=%d user_data=%s" % [checks,failures,OS.get_user_data_dir()])
	quit(0 if failures == 0 else 1)

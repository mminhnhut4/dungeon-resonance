extends SceneTree
## Focused UI callbacks over actual owners. Run only with isolated QA user data.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int = 0
var failures: int = 0
var hub: PrologueHub
var bank: SanctuaryProfile
var screen: InventoryScreen

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\", "/").begins_with(qa + "/"):
		print("FAIL: mac UI test requires isolated QA data")
		quit(2)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	bank = SanctuaryProfile.new()
	bank.save_path = "user://verification/mac_ui_%d_%d/profile.json" % [Engine.physics_ticks_per_second, Time.get_ticks_usec()]
	bank.coins = 5000
	bank.souls = 40
	_check(bank.save(), "Private fixture save")
	_check(bank.commit_cultivation(Model.initial_proposal(Model.new_progress(43), bank.material_stash, bank.souls, bank.boss_proofs)), "Initialize cultivation through existing owner")
	hub = preload("res://scenes/hub/prologue_hub_room.tscn").instantiate() as PrologueHub
	hub.profile = bank
	hub.world_building_enabled = true
	root.add_child(hub)
	current_scene = hub
	await _frames(6)
	hub.economy.persist_safe_inventory = true
	screen = hub.gear.modal as InventoryScreen
	_check(hub.economy.has_method("quote_sell_all_bag") and hub.gear.inventory.has_method("sort_equipment_bag"), "Backend contract available")
	await _inventory_transactions()
	await _merchant_transactions()
	await _shop_comparison()
	await _service_sources()
	await _compact_input()
	_cultivation_guidance()
	hub.queue_free()
	await _frames(6)
	print("RESULT MacBagProgressionUI checks=%d failures=%d hz=%d" % [checks, failures, Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

func _seed_sale() -> Dictionary:
	var inventory: GearInventory = hub.gear.inventory
	var ordinary: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD)
	var enhanced: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD, GearItem.Quality.RARE)
	enhanced.enhancement_level = 1
	var protected: GearItem = inventory.add_equipment(preload("res://data/equipment/ancient_sword_bounty.tres"))
	inventory.materials[&"crystal"] = 3
	inventory.materials[&"slime_essence"] = 2
	bank.material_stash[&"crystal"] = 17
	_check(hub.economy._save_safe(), "Fixture commits carried ledger")
	return {"ordinary":ordinary.uid, "enhanced":enhanced.uid, "protected":protected.uid}

func _inventory_transactions() -> void:
	var uids: Dictionary = _seed_sale()
	screen.open()
	await _frames(4)
	_check(screen.is_open and not screen.sort_bag_button.disabled and not screen.sell_all_bag_button.disabled, "Bag actions enabled in real inventory modal at hub")
	var inventory: GearInventory = hub.gear.inventory
	var before: String = _ledger()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	screen.sell_all_bag_button.pressed.emit()
	await _frames(3)
	var quote: Dictionary = screen._bag_sale_offer.duplicate(true)
	_check(screen.bag_confirmation.visible and quote["item_count"] == 6 and quote["total"] > 0, "Bulk preview counts equipment plus material quantities")
	_check(not quote["equipment_uids"].has(inventory.equipped_weapon_uid) and not quote["equipment_uids"].has(uids["enhanced"]) and not quote["equipment_uids"].has(uids["protected"]), "Preview excludes equipped, enhanced and protected gear")
	_check(screen.bag_confirmation.get_node("CancelBagSale").has_focus(), "Cancel receives default focus")
	_check(_ledger() == before and FileAccess.get_file_as_bytes(bank.save_path) == bytes, "Preview never writes or consumes")
	var old_token: int = int(quote["token"])
	screen.bag_confirmation.get_node("CancelBagSale").pressed.emit()
	screen.sell_all_bag_button.pressed.emit()
	screen._confirm_bag_sale(String(quote["signature"]), old_token)
	_check(_ledger() == before and not screen._bag_sale_offer.is_empty(), "Old callback cannot confirm a reopened identical quote")
	var current: Dictionary = screen._bag_sale_offer.duplicate()
	inventory.materials[&"crystal"] += 1
	var changed: String = _ledger()
	screen._confirm_bag_sale(String(current["signature"]), int(current["token"]))
	_check(_ledger() == changed and screen.status.text.contains("Chưa bán"), "Inventory rejects changed quote atomically")
	screen.sell_all_bag_button.pressed.emit()
	current = screen._bag_sale_offer.duplicate()
	var coins: int = bank.coins
	var before_fault: String = _ledger()
	var before_disk: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	bank._writer.fault_plan = {"write_candidate":true}
	screen.bag_confirmation.get_node("ConfirmBagSale").pressed.emit()
	_check(_ledger() == before_fault and FileAccess.get_file_as_bytes(bank.save_path) == before_disk and screen.status.text.contains("Chưa bán"), "Bulk UI save failure restores exact ledger and bytes")
	bank._writer.fault_plan.clear()
	screen.sell_all_bag_button.pressed.emit()
	current = screen._bag_sale_offer.duplicate()
	screen.bag_confirmation.get_node("ConfirmBagSale").pressed.emit()
	_check(bank.coins == coins + int(current["total"]) and not inventory.items.has(uids["ordinary"]), "Confirm performs one real bulk sale")
	_check(inventory.items.has(uids["enhanced"]) and inventory.items.has(uids["protected"]) and bank.material_stash[&"crystal"] == 17, "Protected gear and stash remain intact")
	before = _ledger()
	screen._confirm_bag_sale(String(current["signature"]), int(current["token"]))
	_check(_ledger() == before, "Duplicate confirmation cannot sell again")
	var clothing: GearItem = inventory.add_equipment(GearInventory.STARTER_CLOTHING[0], GearItem.Quality.RARE)
	var common: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD)
	inventory.equipment_positions.assign([clothing.uid, common.uid, uids["protected"], uids["enhanced"]])
	var worn: Array[int] = inventory.equipment_uids.duplicate()
	var item_keys: Array = inventory.items.keys()
	screen.sort_bag_button.pressed.emit()
	_check(inventory.equipment_uids == worn and inventory.items.keys() == item_keys and inventory.equipment_positions[0] == uids["enhanced"], "Sort keeps identity and equipment; puts upgraded Rare weapon first")
	var loaded := SanctuaryProfile.new()
	loaded.save_path = bank.save_path
	_check(loaded.load_profile() and GearInventoryCodec.decode(loaded.hub_inventory).equipment_positions == inventory.equipment_positions, "Sort persists positions through real profile writer")
	var positions: Array[int] = inventory.equipment_positions.duplicate()
	positions.reverse()
	inventory.equipment_positions.assign(positions)
	bank._writer.fault_plan = {"commit":true}
	screen.sort_bag_button.pressed.emit()
	_check(inventory.equipment_positions == positions and screen.status.text.contains("Chưa sắp xếp"), "Failed sort save preserves prior positions")
	bank._writer.fault_plan.clear()
	hub.economy.hub_access = false
	screen._refresh_bag_actions()
	screen._sort_bag()
	_check(screen.sort_bag_button.disabled and inventory.equipment_positions == positions, "Locked hub owner cannot fall back to unsaved run sorting")
	hub.economy.hub_access = true
	screen.close()
	await _frames(3)

func _merchant_transactions() -> void:
	hub.open_station(&"merchant")
	await _frames(3)
	var before: String = _ledger()
	hub.station_content.get_node("SellAllBag").pressed.emit()
	await _frames(3)
	_check(hub.station_content.has_node("BulkSalePreview") and hub.station_content.get_node("CancelBulkSale").has_focus(), "Merchant exposes same preview with default cancel")
	var token: int = int(hub._pending_bulk_sale["token"])
	hub.station_content.get_node("CancelBulkSale").pressed.emit()
	hub._confirm_bulk_sale(token)
	_check(_ledger() == before and hub._pending_bulk_sale.is_empty(), "Merchant cancel and stale callback preserve ledger")
	_check(hub.station_content.find_child("SellMaterial_*", true, false) == null, "Merchant has no direct stash-sale action")
	hub.station_content.get_node("SellAllBag").pressed.emit()
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	hub.route_world_input(event)
	_check(hub.station_open and hub._pending_bulk_sale.is_empty() and _ledger() == before, "Escape cancels sale while keeping merchant open")
	hub.close_station()

func _shop_comparison() -> void:
	for extent: Vector2i in [Vector2i(800,600), Vector2i(1280,720)]:
		root.size = extent
		hub.open_station(&"merchant")
		await _frames(4)
		var before: String = _ledger()
		hub.station_content.get_node("BuyWeapon_common_sword_1").pressed.emit()
		await _frames(4)
		var label: Label = hub.station_content.get_node("ShopEquipmentStats")
		var expected: String = hub._shop_details(GearInventory.COMMON_SWORD, GearItem.Quality.RARE)
		_check(label.text == expected and label.text.contains("BỘ ĐÒN") and label.text.contains("SO VỚI ĐANG MẶC") and label.text.contains("Đòn 1:"), "Shop shows same detailed stats, combo clocks and comparison at %s" % extent)
		_check(_ledger() == before, "Shop preview allocates no inventory UID and writes no state")
		var cancel: Button = hub.station_content.get_node("CancelPurchase")
		hub.station_scroll.ensure_control_visible(cancel)
		await _frames(3)
		_check(hub.station_scroll.get_global_rect().encloses(cancel.get_global_rect()), "Shop confirmation cancel reachable within viewport")
		cancel.pressed.emit()
		hub.close_station()
	var original_coins: int = bank.coins
	bank.coins = 0
	hub.open_station(&"merchant")
	hub.station_content.get_node("BuyWeapon_common_sword_0").pressed.emit()
	await _frames(3)
	_check(hub.station_content.has_node("ShopEquipmentStats") and hub.station_content.get_node("ConfirmPurchase").disabled, "Unaffordable gear still allows reading stats but cannot purchase")
	hub.close_station()
	bank.coins = original_coins

func _service_sources() -> void:
	hub.gear.inventory.materials[&"dust"] = 1
	bank.material_stash[&"dust"] = 100
	var label: String = hub._materials_text({&"dust":3})
	_check(label.contains("túi 1/3") and label.contains("thiếu 2"), "Craft requirements use carried amounts rather than large stash")
	_check(hub._rune_material_snapshot({&"dust":3}).contains("1/3"), "Rune recipe snapshot uses carried ledger")
	hub.open_station(&"stash")
	_check(hub.station_caption.text.contains("Rút nguyên liệu về túi"), "Stash explains storage-only source contract")
	hub.close_station()
	root.size = Vector2i(800,600)
	for station: StringName in [&"smith_forge", &"smith_enhance", &"smith_stones", &"healer_consumables", &"rune_learning"]:
		hub.open_station(station)
		await _frames(4)
		for child: Node in hub.station_content.get_children():
			if child is ServiceItemCard:
				_check(child.size.y <= hub.station_scroll.size.y, "Single service card fits scroll viewport at 800: " + String(child.name))
		hub.close_station()
		await _frames(2)

func _compact_input() -> void:
	root.size = Vector2i(800,600)
	hub.gear.inventory.materials[&"crystal"] = 2
	_check(hub.economy._save_safe(), "Compact input fixture persists")
	screen.open()
	await _frames(6)
	screen._show_tooltip(hub.gear.inventory.equipped_weapon_uid)
	var before: String = _ledger()
	await _click_control(screen.sell_all_bag_button, screen.content_scroll)
	_check(not screen._bag_sale_offer.is_empty() and not screen.tooltip.visible, "Actual mouse opens bag preview at 800 without tooltip covering actions")
	var cancel: Button = screen.bag_confirmation.get_node("CancelBagSale")
	await _click_control(cancel, screen.content_scroll)
	_check(screen._bag_sale_offer.is_empty() and _ledger() == before and screen.is_open, "Actual cancel click preserves bag and keeps inventory open at 800")
	await _click_control(screen.sell_all_bag_button, screen.content_scroll)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event, true)
	await _frames(2)
	_check(screen._bag_sale_offer.is_empty() and screen.is_open and _ledger() == before, "Escape first cancels inventory sale without dismissing bag")
	_check(screen.acquisition_hint.text.contains("nguyên liệu đang mang") and not screen.acquisition_hint.text.contains("trong kho"), "Inherited rune acquisition hint matches carried crafting")
	screen.close()
	await _frames(3)

func _click_control(button: Button, scroll: ScrollContainer) -> void:
	scroll.ensure_control_visible(button)
	await _frames(3)
	_check(scroll.get_global_rect().encloses(button.get_global_rect()), "Action is reachable inside compact viewport: " + String(button.name))
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		root.push_input(event, true)
		await _frames(2)

func _cultivation_guidance() -> void:
	var profile := SanctuaryProfile.new()
	profile.cultivation_progress = Model.new_progress(7)
	# This fixture checks guidance for an explicit legacy/custom curriculum.
	profile.cultivation_progress["config"].merge({"energy_thresholds":[12,24,40],"mastery_thresholds":[2,5,8],"insight_thresholds":[1,2,3],"interim_dust_cost":1,"final_dust_cost":2,"final_soul_cost":5,"final_golem_proof":1}, true)
	var inventory: GearInventory = HubPreparation.starter_inventory(profile)
	var view: Dictionary = OpeningProgressionGuide.cultivation_view(profile, inventory)
	_check(view["action"].contains("mộc nhân") and view["action"].contains("2 lần") and view["body"].contains("CÒN THIẾU"), "First cultivation step gives concrete mastery deficit and destination")
	var actor: Dictionary = profile.cultivation_progress["actors"]["player"]
	actor["mastery"] = 2
	profile.material_stash[&"crystal"] = 4
	view = OpeningProgressionGuide.cultivation_view(profile, inventory)
	_check(view["action"].contains("Rút 1 Tinh Thạch") and view["action"].contains("trong túi"), "Stored resources recommend exact withdrawal instead of treating stash as spendable")
	inventory.materials[&"crystal"] = 1
	view = OpeningProgressionGuide.cultivation_view(profile, inventory)
	_check(view["action"].contains("điều tức") and view["action"].contains("12 tu vi"), "Training step distinguishes accumulated cultivation from mana")
	actor["energy"] = 12
	view = OpeningProgressionGuide.cultivation_view(profile, inventory)
	_check(view["action"].contains("ĐƯỜNG BỘ") and view["action"].contains("1 lĩnh ngộ"), "Insight step supplies first concrete milestone")
	actor["insight_ids"] = ["explored"]
	profile.material_stash[&"dust"] = 10
	view = OpeningProgressionGuide.cultivation_view(profile, inventory)
	_check(view["status"] == "blocked" and view["action"].contains("Rút 1 " + MaterialCatalog.DISPLAY_NAMES[&"dust"]), "Full stash never marks carried-cost breakthrough ready")
	inventory.materials[&"dust"] = 1
	view = OpeningProgressionGuide.cultivation_view(profile, inventory)
	_check(view["status"] == "requirements_ready" and view["body"].contains("SẴN SÀNG ĐỘT PHÁ") and view["reward"].contains("Luyện Khí II"), "Eligible step displays readiness and exact next-stage outcome")
	var snapshot: String = Writer.canonical({"progress":profile.cultivation_progress,"bag":GearInventoryCodec.encode(inventory),"stash":profile.material_stash})
	var rows: Array[Dictionary] = [{"id":&"explored","title":"Khảo sát","body":"","done":true}]
	var decorated: Array[Dictionary] = OpeningQuestCards.decorate(rows, profile, inventory)
	var cards: Array = decorated.filter(func(row: Dictionary) -> bool: return row["id"] == &"cultivation_breakthrough")
	_check(cards.size() == 1 and cards[0]["card"]["reward_status"].contains("Sẵn sàng") and cards[0]["card"]["progress"].contains("Bột Phép trong túi 1/1"), "Quest card shares cultivation counts and ready state")
	_check(Writer.canonical({"progress":profile.cultivation_progress,"bag":GearInventoryCodec.encode(inventory),"stash":profile.material_stash}) == snapshot, "Guide/card projection is read-only")
	_check(not screen.tracker.visible and screen.tracker_label.text.is_empty(), "Quest copy stays off combat HUD")

func _ledger() -> String:
	return Writer.canonical({"inventory":GearInventoryCodec.encode(hub.gear.inventory),"coins":bank.coins,"souls":bank.souls,"stash":bank.material_stash})

func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

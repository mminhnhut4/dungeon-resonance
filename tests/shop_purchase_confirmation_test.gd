extends SceneTree
## Actual station controls and owner transactions, isolated profile and GUI input.
const Cultivation = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
class RepricedEconomy extends EconomySession:
	var surcharge: int = 0
	func quote_buy(id: StringName, quality: int) -> Dictionary:
		var quote: Dictionary = super.quote_buy(id,quality)
		quote["coin_cost"] = int(quote["coin_cost"])+surcharge
		return quote

var checks: int = 0
var failures: int = 0
var hub: PrologueHub
var bank: SanctuaryProfile

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var qa_root: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not qa_root.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa_root+"/"):
		print("FAIL: shop confirmation requires isolated QA data root")
		quit(2)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	bank = SanctuaryProfile.new()
	bank.save_path = "user://verification/shop_confirm_%d_%d.json" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	bank.coins = 2000
	bank.souls = 2000
	_check(bank.save(),"Create private merchant profile")
	_check(bank.commit_cultivation(Cultivation.initial_proposal(Cultivation.new_progress(43),bank.material_stash,bank.souls,bank.boss_proofs)),"Fixture initializes sealed profile v2 through the actual owner")
	hub = preload("res://scenes/hub/prologue_hub_room.tscn").instantiate() as PrologueHub
	hub.profile = bank
	hub.world_building_enabled = true
	root.add_child(hub)
	current_scene = hub
	await _frames(6)
	hub.economy.persist_safe_inventory = true
	_check(hub.economy._save_safe(),"Fixture begins with the actual persisted inventory")
	for size: Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		root.size = size
		await _selection_and_cancel()
	await _single_commit_and_stale_buttons()
	await _stale_conditions()
	await _potions()
	await _soul_confirmation()
	await _rune_services()
	hub.queue_free()
	await _frames(6)
	print("RESULT shop_purchase_confirmation checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

func _selection_and_cancel() -> void:
	hub.open_station(&"merchant")
	await _frames(4)
	var before: Dictionary = _ledger()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	await _click("BuyWeapon_common_sword_0")
	_check(_ledger() == before and FileAccess.get_file_as_bytes(bank.save_path) == bytes,"Selecting a good cannot charge, grant, or write save")
	var preview := hub.station_content.get_node("PurchaseItemPreview") as ServiceItemCard
	_check(preview.item_title.text == GearInventory.COMMON_SWORD.item_name and preview.detail_label.text.contains("Thường") and preview.quantity_label.text.contains("20 Linh Thạch") and preview.quantity_label.text.contains("Số lượng 1"),"Confirmation displays the exact item, quality, quantity and quoted price")
	var cancel := hub.station_content.get_node("CancelPurchase") as Button
	_check(cancel.has_focus() and hub.station_open and not hub.player.controls_enabled and not hub.gear.modal.is_open,"Confirmation keeps the existing modal with Cancel as default focus")
	await _click("CancelPurchase")
	_check(_ledger() == before and hub.station_open and hub.station_content.has_node("BuyWeapon_common_sword_0"),"Cancel returns to the shop without mutation")
	await _click("BuyWeapon_common_sword_0")
	await _action(&"ui_cancel")
	_check(hub.station_open and hub._pending_purchase.is_empty() and _ledger() == before,"First Escape cancels purchase while leaving shop open")
	await _action(&"ui_cancel")
	_check(not hub.station_open and hub.player.controls_enabled,"Second Escape closes shop and restores controls")

func _single_commit_and_stale_buttons() -> void:
	hub.open_station(&"merchant")
	await _frames(3)
	var before: Dictionary = _ledger()
	await _click("BuyWeapon_common_sword_0")
	var confirm := hub.station_content.get_node("ConfirmPurchase") as Button
	var callback: Callable = confirm.get_signal_connection_list(&"pressed")[0]["callable"]
	var old_token: int = int(hub._pending_purchase["token"])
	await _click("ConfirmPurchase")
	_check(bank.coins == int(before["coins"])-20 and hub.gear.inventory.items.size() == before["inventory"]["items"].size()+1,"Explicit mouse confirmation buys exactly one item at the shown price")
	var after: Dictionary = _ledger()
	callback.call()
	hub._confirm_purchase(old_token)
	_check(_ledger() == after,"Repeated and stale confirmation callbacks cannot buy twice")
	var loaded := SanctuaryProfile.new()
	loaded.save_path = bank.save_path
	var reload_ok: bool = loaded.load_profile()
	_check(reload_ok and loaded.coins == bank.coins and Writer.canonical(loaded.hub_inventory) == Writer.canonical(bank.hub_inventory),"Confirmed price and inventory persist through the existing save owner")
	await _click("BuyWeapon_common_sword_1")
	var close_token: int = int(hub._pending_purchase["token"])
	hub.close_station()
	hub._confirm_purchase(close_token)
	_check(_ledger() == after and hub._pending_purchase.is_empty(),"Closing the station invalidates its pending purchase")

func _stale_conditions() -> void:
	hub.open_station(&"merchant")
	await _frames(3)
	await _click("BuyWeapon_common_sword_0")
	bank.coins = 0
	var before: Dictionary = _ledger()
	await _click("ConfirmPurchase")
	_check(_ledger() == before and hub.station_notice.contains("Chưa mua"),"Funds are rechecked after preview without granting goods")
	bank.coins = 2000
	hub._refresh_station()
	await _frames(3)
	await _click("BuyWeapon_common_sword_0")
	var fillers: Array[int] = []
	while hub.gear.inventory.equipment_bag_uids().size() < GearInventory.EQUIPMENT_BAG_CAPACITY:
		fillers.append(hub.gear.inventory.add_equipment(GearInventory.COMMON_SWORD,GearItem.Quality.COMMON).uid)
	before = _ledger()
	await _click("ConfirmPurchase")
	_check(_ledger() == before,"Bag filling after preview cannot consume coins or overflow capacity")
	for uid: int in fillers: hub.gear.inventory.items.erase(uid)
	hub.gear.inventory.changed.emit()
	hub._refresh_station()
	await _frames(3)
	for blocked_state: String in ["read_only","hub_inventory_quarantined","hub_access"]:
		await _click("BuyWeapon_common_sword_0")
		if blocked_state == "hub_access": hub.economy.hub_access = false
		else: bank.set(blocked_state,true)
		before = _ledger()
		await _click("ConfirmPurchase")
		_check(_ledger() == before,"Confirmation respects changed owner state: "+blocked_state)
		if blocked_state == "hub_access": hub.economy.hub_access = true
		else: bank.set(blocked_state,false)
		hub._refresh_station()
		await _frames(3)
	var original_economy: EconomySession = hub.economy
	var repriced := RepricedEconomy.new()
	repriced.initialize(bank,hub.gear.inventory)
	repriced.persist_safe_inventory = true
	hub.economy = repriced
	hub._refresh_station()
	await _frames(3)
	await _click("BuyWeapon_common_sword_0")
	repriced.surcharge = 7
	before = _ledger()
	await _click("ConfirmPurchase")
	_check(_ledger() == before,"A changed quote is rejected instead of charging an unseen price")
	hub.economy = original_economy
	hub._refresh_station()
	await _frames(3)
	await _click("BuyWeapon_common_sword_0")
	before = _ledger()
	var disk: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	bank._writer.fault_plan = {"commit":true}
	await _click("ConfirmPurchase")
	_check(_ledger() == before and FileAccess.get_file_as_bytes(bank.save_path) == disk,"Failed owner save rolls back confirmed payment and provisional UID")
	bank._writer.fault_plan.clear()
	hub.close_station()

func _potions() -> void:
	hub.open_station(&"healer_consumables")
	await _frames(3)
	var before: Dictionary = _ledger()
	var hp: float = hub.player.health.current_health
	await _click("BuyConsumable_potion")
	_check(_ledger() == before,"Selecting medicine is also only a preview")
	await _click("ConfirmPurchase")
	_check(bank.coins == int(before["coins"])-10 and hub.gear.inventory.consumables[&"potion"] == int(before["potions"])+1 and hub.player.health.current_health == hp,"Confirm stores one potion without auto-healing")
	await _click("BuyConsumable_potion")
	var original_count: int = hub.gear.inventory.consumables[&"potion"]
	hub.gear.inventory.consumables[&"potion"] = MaterialCatalog.MAX_COUNT
	before = _ledger()
	await _click("ConfirmPurchase")
	_check(_ledger() == before,"Consumable capacity is rechecked at confirmation")
	hub.gear.inventory.consumables[&"potion"] = original_count
	hub.close_station()

func _soul_confirmation() -> void:
	hub.open_npc(NpcCatalog.HEALER)
	await _reveal_dialogue()
	var before: int = bank.souls
	var hp_level: int = bank.permanent_upgrades[&"max_hp"]
	hub.dialogue.select_choice(&"upgrade_max_hp")
	_check(hub.dialogue.confirmation.visible and bank.souls == before and bank.permanent_upgrades[&"max_hp"] == hp_level,"Selecting permanent HP opens a price confirmation without buying")
	hub.dialogue.cancel_confirmation()
	_check(bank.souls == before and bank.permanent_upgrades[&"max_hp"] == hp_level,"Cancel Soul upgrade leaves its price and level intact")
	hub.dialogue.select_choice(&"upgrade_max_hp")
	bank.souls = 0
	hub.dialogue.confirm_choice()
	_check(bank.souls == 0 and bank.permanent_upgrades[&"max_hp"] == hp_level,"Soul confirmation rechecks affordability before commit")
	hub.dialogue.close()
	await _frames(2)
	bank.souls = before
	hub.open_npc(NpcCatalog.HEALER)
	await _reveal_dialogue()
	_check(hub.dialogue.choice_list.has_node("Choice_upgrade_max_mana"),"New max-mana service is discovered from the authoritative upgrade catalog")
	var mana_level: int = bank.permanent_upgrades[&"max_mana"]
	var quote: Dictionary = hub.economy.quote_upgrade(&"max_mana")
	hub.dialogue.select_choice(&"upgrade_max_mana")
	_check(hub.dialogue.confirmation.visible and hub.dialogue.confirmation_text.text.contains("Mana tối đa") and bank.souls == before,"Max-mana uses the same readable Soul confirmation")
	hub.dialogue.confirm_choice()
	_check(bank.permanent_upgrades[&"max_mana"] == mana_level+1 and bank.souls == before-int(quote["cost"]),"Explicit max-mana confirmation calls the existing Soul purchase owner")
	hub.dialogue.close()

func _ledger() -> Dictionary:
	return {"coins":bank.coins,"souls":bank.souls,"inventory":GearInventoryCodec.encode(hub.gear.inventory),"potions":hub.gear.inventory.consumables[&"potion"],"materials":bank.material_stash.duplicate(true),"rune_learning":hub.rune_learning.state().duplicate(true)}

func _rune_services() -> void:
	root.size = Vector2i(800,600)
	hub.open_npc(NpcCatalog.HEALER)
	await _reveal_dialogue()
	var entry := hub.dialogue.choice_list.get_node("Choice_rune_learning") as Button
	_check(not entry.disabled and entry.text.contains("Học & chế bùa"),"Thanh Vy exposes the discoverable rune-learning entry")
	hub.dialogue.body_scroll.ensure_control_visible(entry)
	await _frames(3)
	await _click_at(entry.get_global_rect().get_center())
	_check(hub.station_open and hub.current_station == &"rune_learning" and not hub.dialogue.is_open,"Actual dialogue click transfers to the rune service modal")
	_check(hub.station_content.get_child_count() == 5 and hub.station_caption.text.contains("Bùa nhặt được"),"Five rune cards explain permanent learning and existing loot usability")
	var lightning := hub.station_content.get_node("RuneService_lightning") as ServiceItemCard
	var poison := hub.station_content.get_node("RuneService_poison") as ServiceItemCard
	_check(lightning.disabled and lightning.detail_label.text.to_lower().contains("khám phá") and poison.disabled and poison.detail_label.text.contains("Golem"),"Locked rune cards show their distinct prerequisite without spending")
	var before: Dictionary = _ledger()
	await _click("RuneService_fire")
	var preview := hub.station_content.get_node("PurchaseItemPreview") as ServiceItemCard
	_check(_ledger() == before and preview.quantity_label.text.contains("5 Tàn Hồn") and preview.detail_label.text.contains("1 bùa Thường"),"Learning preview shows Soul cost and the single Common gift before mutation")
	await _click("CancelPurchase")
	_check(_ledger() == before,"Cancel learning leaves knowledge, items and currencies intact")
	await _click("RuneService_fire")
	bank.souls = 0
	before = _ledger()
	await _click("ConfirmPurchase")
	_check(_ledger() == before,"Learning confirmation rejects funds lost after preview")
	bank.souls = 2000
	hub._refresh_station()
	await _frames(3)
	await _click("RuneService_fire")
	var token: int = int(hub._pending_purchase["token"])
	var runes: int = int(hub.gear.inventory.bag[&"fire"])
	await _click("ConfirmPurchase")
	_check(bank.souls == 1995 and hub.rune_learning.state()["learned"].has("fire") and hub.gear.inventory.bag[&"fire"] == runes+1,"Confirmed learning grants one Common rune and durable knowledge")
	before = _ledger()
	hub._confirm_purchase(token)
	_check(_ledger() == before,"Stale learning confirmation cannot repeat payment or the gift")
	var fire := hub.station_content.get_node("RuneService_fire") as ServiceItemCard
	_check(fire.disabled and fire.item_title.text.contains("Đã học") and fire.detail_label.text.contains("trong kho"),"Learned card switches to crafting and explains missing stored materials")
	bank.material_stash[&"dust"] = 4
	bank.material_stash[&"crystal"] = 2
	hub._refresh_station()
	await _frames(3)
	await _click("RuneService_fire")
	preview = hub.station_content.get_node("PurchaseItemPreview") as ServiceItemCard
	_check(preview.quantity_label.text.contains("4/2") and preview.quantity_label.text.contains("2/1") and not preview.quantity_label.text.contains("Tàn Hồn"),"Crafting confirmation shows actual stash counts against both material costs")
	bank.material_stash[&"dust"] = 0
	before = _ledger()
	await _click("ConfirmPurchase")
	_check(_ledger() == before,"Crafting rechecks stash after preview without creating a rune")
	bank.material_stash[&"dust"] = 4
	hub._refresh_station()
	await _frames(3)
	await _click("RuneService_fire")
	before = _ledger()
	await _click("ConfirmPurchase")
	_check(bank.material_stash[&"dust"] == 2 and bank.material_stash[&"crystal"] == 1 and bank.souls == before["souls"] and hub.gear.inventory.bag[&"fire"] == runes+2,"Explicit crafting consumes stored ingredients once and grants one extra rune")
	hub.close_station()
	_check(hub.player.controls_enabled,"Closing rune service restores player controls")

func _click(name: String) -> void:
	var button: Button = hub.station_content.get_node_or_null(NodePath(name)) as Button
	_check(button != null and not button.disabled,"Accessible station button: "+name)
	if button == null or button.disabled: return
	hub.station_scroll.ensure_control_visible(button)
	await _frames(3)
	_check(hub.station_scroll.get_global_rect().encloses(button.get_global_rect()),"Station button is reachable within the scroll viewport: "+name)
	var at: Vector2 = button.get_global_rect().get_center()
	await _click_at(at)

func _click_at(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion,true)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await _frames(2)

func _reveal_dialogue() -> void:
	for _index: int in hub.dialogue.pages.size()*2+2:
		if not hub.dialogue.is_typing() and hub.dialogue.page_index == hub.dialogue.pages.size()-1: break
		hub.dialogue.advance()
	await _frames(3)

func _action(action: StringName) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event,true)
		await _frames(2)

func _frames(count: int) -> void:
	for _index: int in count:
		await physics_frame
		await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+message)

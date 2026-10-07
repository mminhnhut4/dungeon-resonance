extends SceneTree
## Native focused fixture: isolated profiles only, no real save or user window.
class FaultProfile extends SanctuaryProfile:
	var fail_write: bool = false
	func _open_writer(path: String) -> FileAccess:
		return null if fail_write else super._open_writer(path)
var checks: int = 0
var failures: int = 0
var hub: PrologueHub
var bank: FaultProfile
func _initialize() -> void: call_deferred("_run")
func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", message)
func _frames(count: int = 3) -> void:
	for i: int in count: await process_frame
func _button(name_text: String) -> Button:
	return hub.station_content.find_child(name_text, true, false) as Button
func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(qa + "/"):
		print("ERROR: isolated profile required"); quit(2); return
	bank = FaultProfile.new()
	bank.save_path = "user://focused/profile.json"
	bank.souls = 4
	bank.coins = 20
	_check(bank.save(), "Initial test profile commits")
	hub = PrologueHub.new()
	hub.profile = bank
	hub.world_building_enabled = true
	root.add_child(hub)
	current_scene = hub
	hub.economy.persist_safe_inventory = true
	await _frames()
	var inv: GearInventory = hub.gear.inventory
	var ec: EconomySession = hub.economy
	var hud: ArtHUD = hub.presentation.art_hud
	var screen: InventoryScreen = hub.gear.modal as InventoryScreen
	var initial_gear: Dictionary = GearInventoryCodec.encode(inv)
	hub.open_station(&"stash")
	_check(hub.station_content.has_node("StashEmpty"), "Fresh zero-count stash says Kho rong")
	_check(_button("WithdrawMaterial_crystal") == null and _button("WithdrawMaterial_metal") == null, "Zero catalog entries produce no storage cards")
	_check(_button("DepositAllMaterials").disabled, "Empty bag cannot deposit")
	_check(GearInventoryCodec.encode(inv) == initial_gear, "Opening stash does not mutate UID ledger")
	inv.add_material(&"crystal", 2)
	hub._refresh_station()
	_check(hub.station_content.has_node("StashEmpty") and _button("DepositMaterial_crystal") != null and _button("WithdrawMaterial_crystal") == null, "Carried material shown separately from still-empty stash")
	_button("DepositMaterial_crystal").pressed.emit()
	_check(bank.material_stash[&"crystal"] == 1 and inv.materials[&"crystal"] == 1 and _button("WithdrawMaterial_crystal") != null, "Native deposit button moves one and exposes stored record")
	var reload_profile := SanctuaryProfile.new(); reload_profile.save_path = bank.save_path
	_check(reload_profile.load_profile() and reload_profile.material_stash[&"crystal"] == 1, "Stored count survives actual disk roundtrip")
	var reloaded_bag: GearInventory = GearInventoryCodec.decode(reload_profile.hub_inventory)
	_check(reloaded_bag != null and reloaded_bag.materials[&"crystal"] == 1 and reloaded_bag.equipped_weapon_uid == inv.equipped_weapon_uid, "Persisted bag and equipped UID preserved atomically")
	_button("WithdrawMaterial_crystal").pressed.emit()
	_check(inv.materials[&"crystal"] == 2 and bank.material_stash[&"crystal"] == 0 and _button("WithdrawMaterial_crystal") == null and hub.station_content.has_node("StashEmpty"), "Last withdrawal removes card and restores empty state")
	bank.fail_write = true
	var frozen: Dictionary = GearInventoryCodec.encode(inv)
	var frozen_stash: Dictionary = bank.material_stash.duplicate()
	_check(not ec.deposit(&"crystal", 1) and GearInventoryCodec.encode(inv) == frozen and bank.material_stash == frozen_stash, "Failed deposit preserves exact bag/UID/stash")
	bank.fail_write = false
	bank.material_stash[&"crystal"] = 2
	inv.materials[&"crystal"] = MaterialCatalog.MAX_COUNT
	hub._refresh_station()
	_check(_button("WithdrawMaterial_crystal").disabled and not ec.withdraw(&"crystal",1), "Full material destination blocks withdrawal before consuming source")
	inv.materials[&"crystal"] = 2
	inv.materials[&"aptitude_herb"] = 1
	hub._refresh_station()
	_check(_button("DepositMaterial_aptitude_herb").disabled and _button("DepositAllMaterials").disabled, "Lineage-bound herb cannot use ordinary or bulk storage path")
	_check(ec.deposit(&"crystal",1) and inv.materials[&"aptitude_herb"] == 1, "Ordinary individual deposit stays usable with lineage herb present")
	bank.read_only = true
	hub._refresh_station()
	_check(_button("WithdrawMaterial_crystal").disabled and _button("DepositMaterial_crystal").disabled, "Read-only/future profile displays records without transfer controls")
	bank.read_only = false
	hub.close_station()
	inv.materials[&"crystal"] = 3
	inv.materials[&"metal"] = 1
	inv.add_consumable(&"potion",1)
	inv.changed.emit()
	await _frames()
	_check(screen.tabs.get_tab_title(2) == "Bản đồ & Nhiệm vụ" and screen.carried_page.get_index() == 3, "New owned-item page preserves existing map tab index")
	_check(screen.carried_page.has_node("BagMaterial_crystal") and screen.carried_page.has_node("BagConsumable_potion") and not screen.carried_page.has_node("BagMaterial_detox_root"), "Owned materials/consumables have cards; zero items omitted")
	screen.open()
	screen.tabs.current_tab = 3
	await _frames(6)
	var material_card: ServiceItemCard = screen.carried_page.get_node("BagMaterial_crystal")
	var potion_card: ServiceItemCard = screen.carried_page.get_node("BagConsumable_potion")
	_check(material_card.is_visible_in_tree() and material_card.size.y >= 96 and material_card.quantity_label.text == "Số lượng 3", "Owned material card actually visible with count and height")
	_check(potion_card.is_visible_in_tree() and potion_card.size.y >= 96 and potion_card.quantity_label.text == "Số lượng 1", "Owned consumable card actually visible with count and height")
	_check(material_card.disabled and not material_card._action_panel.visible and potion_card.disabled and not potion_card._action_panel.visible, "Read-only bag cards remain visible with action chips hidden")
	screen.close()
	_check(hud.soul_text.visible and hud.soul_text.text == "Tàn Hồn 4" and hud.currency_text.text == "Linh Thạch 20", "HUD shows separate authoritative currency values without debug toggle")
	var pickup := LootPickup.new(); pickup.kind=&"material"; pickup.item_id=&"slime_essence"; pickup.quantity=2; pickup.player=hub.player; pickup.inventory=inv; pickup.automatic=false
	hub.add_child(pickup)
	var stash_before: int = bank.material_stash[&"slime_essence"]
	_check(pickup.collect() and inv.materials[&"slime_essence"] == 2 and bank.material_stash[&"slime_essence"] == stash_before, "Actual pickup enters BAG, never deposits itself")
	_check(not pickup.collect(), "Repeated pickup cannot duplicate material")
	var old_souls: int = bank.souls
	bank.try_add_souls(3)
	_check(hud.soul_text.text == "Tàn Hồn 7" and bank.souls == old_souls + 3, "Soul commit immediately refreshes HUD")
	bank.fail_write = true
	_check(not bank.try_add_souls(9) and bank.souls == 7 and hud.soul_text.text == "Tàn Hồn 7", "Failed soul save rolls back and HUD stays committed")
	bank.fail_write = false
	bank.souls = 50
	bank.changed.emit()
	var cost: int = ec.quote_upgrade(&"max_hp")["cost"]
	_check(ec.buy_upgrade(&"max_hp") and bank.souls == 50-cost and hud.soul_text.text == "Tàn Hồn %d" % (50-cost), "Real soul spending refreshes HUD independently of coins")
	bank.fail_write = true
	old_souls = bank.souls
	_check(not ec.buy_upgrade(&"mana_regen") and bank.souls == old_souls and hud.soul_text.text == "Tàn Hồn %d" % old_souls, "Failed upgrade refunds souls with correct display")
	bank.fail_write = false
	var quote: Dictionary = ec.quote_bag_material_sale(&"crystal",1)
	_check(quote["unit_price"] == 5 and quote["quantity"] == 1 and quote["owned"] == 3, "Bag sale quote exposes owned quantity and existing unit price")
	var coins_before: int = bank.coins
	_check(ec.sell_bag_material(&"crystal",1) and bank.coins == coins_before+5 and inv.materials[&"crystal"] == 2 and bank.souls == old_souls, "Material sale exchanges only BAG count and Linh Thach")
	_check(not ec.sell_bag_material(&"metal") and not ec.sell_bag_material(&"crystal",0) and not ec.sell_bag_material(&"crystal",-1) and not ec.sell_bag_material(&"crystal",3), "Unknown price/zero/negative/excess sale rejected")
	bank.fail_write = true
	frozen = GearInventoryCodec.encode(inv); coins_before = bank.coins
	_check(not ec.sell_bag_material(&"crystal") and GearInventoryCodec.encode(inv) == frozen and bank.coins == coins_before, "Material sale save failure restores exact source and balance")
	bank.fail_write = false
	bank.coins = MaterialCatalog.MAX_COUNT
	_check(not ec.sell_bag_material(&"crystal"), "Currency overflow rejects before sale")
	bank.coins = 30
	var loot := LootSpawner.new(); loot.inventory = inv; loot.player = hub.player
	hub.add_child(loot)
	loot.rng.seed = 20261005
	var sampled: Dictionary = {}
	for i: int in 64:
		var dropped: GearItem = loot._broken_drop()
		if sampled.has(dropped.definition_id): continue
		sampled[dropped.definition_id] = true
		var native_pickup: LootPickup = loot.spawn_gear(dropped, hub.player.global_position)
		native_pickup.automatic = false
		_check(native_pickup.collect() and ec.quote_bag_equipment_sale(dropped.uid)["can_sell"] and ec.quote_bag_equipment_sale(dropped.uid)["total"] == 2, "Native broken-drop pickup becomes a sellable owned UID: " + String(dropped.definition_id))
		coins_before = bank.coins
		_check(ec.sell_bag_equipment(dropped.uid) and not inv.items.has(dropped.uid) and bank.coins == coins_before + 2, "Actual broken-drop sale commits once: " + String(dropped.definition_id))
		if sampled.size() == 5: break
	_check(sampled.size() == 5, "Native current drop pool covers all three legacy weapons and two clothing definitions")
	loot.queue_free()
	await _frames()
	var item: GearItem = inv.add_equipment(GearInventory.COMMON_SWORD)
	item.source = &"drop"
	inv.equipment_grid_uids()
	var uid: int = item.uid
	_check(ec.quote_bag_equipment_sale(uid)["total"] == 5 and ec.quote_bag_equipment_sale(uid)["eligible"], "Ordinary common loot receives bounded sale price")
	_check(not ec.quote_bag_equipment_sale(inv.equipped_weapon_uid)["eligible"], "Equipped weapon cannot be sold")
	item.source = &"quest"
	_check(not ec.quote_bag_equipment_sale(uid)["eligible"], "Quest/special source cannot use basic sale")
	item.source = &"drop"; item.quality = GearItem.Quality.EPIC
	_check(not ec.quote_bag_equipment_sale(uid)["eligible"], "Higher-rarity forging gear preserved")
	item.quality = GearItem.Quality.RARE; item.broken=true
	_check(ec.quote_bag_equipment_sale(uid)["total"] == 5, "Broken rare sale price bounded below merchant purchase")
	item.quality = GearItem.Quality.COMMON; item.broken=false
	bank.fail_write = true
	frozen = GearInventoryCodec.encode(inv); coins_before=bank.coins
	_check(not ec.sell_bag_equipment(uid) and inv.items[uid] == item and GearInventoryCodec.encode(inv) == frozen and bank.coins == coins_before, "Gear sale rollback preserves same UID, object, grid slot and currency")
	bank.fail_write=false
	hub.open_station(&"merchant")
	hub._request_gear_sale(uid)
	_check(_button("ConfirmEquipmentSale") != null and inv.items.has(uid), "Choosing sale requires a separate explicit confirmation")
	_button("ConfirmEquipmentSale").pressed.emit()
	_check(not inv.items.has(uid) and bank.coins == coins_before+5 and hud.currency_text.text == "Linh Thạch %d" % bank.coins, "Confirmed gear sale commits one owned UID and refreshes currency")
	_check(not ec.sell_bag_equipment(uid) and bank.coins == coins_before+5, "Stale/double gear-sale click cannot pay twice")
	var nested: Array[bool] = []
	var attempt := func() -> void: nested.append(ec.sell_bag_material(&"crystal"))
	ec.changed.connect(attempt)
	_check(ec.sell_bag_material(&"crystal") and nested == [false], "Commit callbacks cannot reenter sale transaction")
	ec.changed.disconnect(attempt)
	coins_before = bank.coins
	var bag_before: int = inv.equipment_bag_uids().size()
	_check(ec.buy_weapon(&"common_sword",GearItem.Quality.COMMON) and inv.equipment_bag_uids().size() == bag_before+1 and bank.coins == coins_before-20, "Existing merchant purchase goes BAG at unchanged price20")
	bank.fail_write=true; bank.coins=100
	frozen=GearInventoryCodec.encode(inv); coins_before=bank.coins
	_check(not ec.buy_weapon(&"common_sword",GearItem.Quality.RARE) and GearInventoryCodec.encode(inv)==frozen and bank.coins==coins_before, "Purchase disk failure restores items and balance")
	bank.fail_write=false
	while inv.equipment_bag_uids().size() < GearInventory.EQUIPMENT_BAG_CAPACITY: inv.add_equipment(GearInventory.COMMON_SWORD)
	_check(not ec.buy_weapon(&"common_sword",GearItem.Quality.COMMON) and bank.coins==coins_before, "Full BAG prevents purchase without deducting balance")
	hub.close_station()
	var healer: Array[Dictionary] = hub._npc_choices(NpcCatalog.HEALER)
	_check(String(healer[0]["text"]).contains("Đang có") and String(healer[0]["text"]).contains("Thiếu"), "Soul upgrade displays cost, balance and shortage together")
	inv.run_coins = 9
	hud.refresh_hud()
	_check(hud.currency_text.text.contains("Mang 9") and not hud.soul_text.text.contains("9"), "Run Linh Thach shown separately from permanent Souls")
	var second := PrologueHub.new(); second.profile=SanctuaryProfile.new(); second.profile.save_path="user://focused/second.json"; second.profile.souls=123; second.world_building_enabled=true
	root.add_child(second)
	hud.bind(second,second.player)
	_check(hud.soul_text.text == "Tàn Hồn 123", "HUD bind reads new scene profile rather than stale source")
	hud.bind(hub,hub.player)
	second.queue_free()
	await _frames()
	_check(hud.soul_text.text == "Tàn Hồn %d" % bank.souls, "HUD remains valid after previous bound scene is freed")
	hub.queue_free()
	await _frames(5)
	var audio: Node = root.get_node_or_null("AudioManager")
	if audio != null: audio.call("shutdown")
	print("RESULT StorageSoulCommerce %d checks %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

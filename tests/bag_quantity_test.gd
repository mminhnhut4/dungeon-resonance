extends SceneTree
const Q = preload("res://scripts/runtime/bag_quantity_transactions.gd")
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int = 0
var failures: int = 0
var hub: PrologueHub
var bank: SanctuaryProfile
var owner: EconomySession
var runes: RuneLearningService
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: "+label)
func frames(count: int = 3) -> void:
	for _i: int in count: await process_frame
func ledger() -> String:
	return Writer.canonical([bank.coins,bank.souls,bank.material_stash,GearInventoryCodec.encode(owner.inventory)])
func run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\", "/").begins_with(qa+"/"): quit(2); return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	bank = SanctuaryProfile.new(); bank.save_path = "user://verification/quantities_%d_%d/profile.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	bank.coins = 10000; bank.souls = 20
	check(bank.save() and bank.commit_cultivation(Model.initial_proposal(Model.new_progress(3),bank.material_stash,bank.souls,bank.boss_proofs)),"Sealed private fixture")
	hub = preload("res://scenes/hub/prologue_hub_room.tscn").instantiate() as PrologueHub
	hub.profile = bank; hub.world_building_enabled = true
	root.add_child(hub); current_scene = hub; await frames(5)
	owner = hub.economy; owner.persist_safe_inventory = true; runes = hub.rune_learning
	check(bank.learn_blueprint(&"world_saber") and runes.learn(&"fire"),"Real recipe and rune knowledge")
	for id: StringName in MaterialCatalog.IDS:
		if MaterialCatalog.material_policy(id)["ordinary_transfer"]: owner.inventory.materials[id] = 100
	bank.material_stash[&"dust"] = 37
	check(owner._save_safe(),"Carried ledger persists")
	var original_bank: Dictionary = bank.material_stash.duplicate()
	var rng := RandomNumberGenerator.new(); rng.seed = 124
	for spec: Array in [[&"equipment",&"common_sword"],[&"consumable",&"potion"],[&"consumable_craft",&"bandage"],[&"rune_craft",&"fire"],[&"forge",&"world_saber_very_rare"],[&"material_sale",&"slime_essence"]]:
		var kind: StringName = spec[0]; var id: StringName = spec[1]
		check(not Q.quote(owner,kind,id,0,0,runes)["can_commit"] and not Q.quote(owner,kind,id,-1,0,runes)["can_commit"] and not Q.quote(owner,kind,id,MaterialCatalog.MAX_COUNT+1,0,runes)["can_commit"],String(kind)+": invalid quantity rejected")
		var offer: Dictionary = Q.quote(owner,kind,id,3,0,runes)
		check(offer["can_commit"],String(kind)+": three-unit quote affordable")
		var before: String = ledger(); var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path); var rng_before: int = rng.state
		for fault: String in ["write_candidate","commit"]:
			bank._writer.fault_plan = {fault:true}
			check(not Q.commit(owner,offer,runes,rng)["committed"] and ledger() == before and FileAccess.get_file_as_bytes(bank.save_path) == bytes and rng.state == rng_before,String(kind)+": whole batch rollback at "+fault)
		bank._writer.fault_plan.clear()
		var reentered: Array[bool] = []
		var callback: Callable = func() -> void: reentered.append(Q.commit(owner,offer,runes,rng)["committed"])
		owner.changed.connect(callback)
		var revision: int = JSON.parse_string(FileAccess.get_file_as_string(bank.save_path))["profile_commit"]["revision"]
		var coins: int = bank.coins; var materials: Dictionary = owner.inventory.materials.duplicate()
		var item_count: int = owner.inventory.items.size(); var potions: int = owner.inventory.consumables.get(id,0)
		var result: Dictionary = Q.commit(owner,offer,runes,rng)
		owner.changed.disconnect(callback)
		check(result["committed"] and result["quantity"] == 3 and reentered == [false],String(kind)+": atomic batch and publication lock")
		check(int(JSON.parse_string(FileAccess.get_file_as_string(bank.save_path))["profile_commit"]["revision"]) == revision+1,String(kind)+": exactly one durable revision")
		check(bank.coins == coins-int(offer["coin_cost"])+int(offer["total"]),String(kind)+": exact total coins")
		for material: StringName in offer["materials"]: check(owner.inventory.materials[material] == int(materials[material])-int(offer["materials"][material]),String(kind)+": exact carried cost "+String(material))
		if kind in [&"equipment",&"rune_craft",&"forge"]: check(owner.inventory.items.size() == item_count+int(result["successes"]),String(kind)+": distinct finite output UIDs")
		if kind in [&"consumable",&"consumable_craft"]: check(owner.inventory.consumables[id] == potions+3,String(kind)+": exact stack output")
		if kind == &"material_sale": check(owner.inventory.materials[id] == int(materials[id])-3,"Selected sale quantity only")
		var after: String = ledger()
		check(not Q.commit(owner,offer,runes,rng)["committed"] and ledger() == after,String(kind)+": repeated stale offer cannot duplicate")
	check(bank.material_stash == original_bank,"Every quantity service preserves stored materials")
	var loaded := SanctuaryProfile.new(); loaded.save_path = bank.save_path
	check(loaded.load_profile() and Writer.canonical(loaded.hub_inventory) == Writer.canonical(GearInventoryCodec.encode(owner.inventory)),"Cold reload preserves all committed quantities and UIDs")
	var limit: Dictionary = Q.quote(owner,&"equipment",&"common_sword",1,0,runes)
	check(not Q.quote(owner,&"equipment",&"common_sword",int(limit["maximum"])+1,0,runes)["can_commit"],"Bag capacity cannot be overbooked")
	owner.inventory.materials[&"linen_fiber"] = 1
	check(not Q.quote(owner,&"consumable_craft",&"bandage",2,0,runes)["can_commit"],"Full bank cannot fund a missing carried batch")
	owner.inventory.materials[&"linen_fiber"] = 20; check(owner._save_safe(),"UI seed persisted")
	root.size = Vector2i(800,600); root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size = Vector2i.ZERO
	hub.open_station(&"merchant"); await frames()
	var sale_spin: SpinBox = hub.station_content.get_node("SaleQuantity/Amount")
	sale_spin.value = 4; await frames()
	var slime: int = owner.inventory.materials[&"slime_essence"]; var sale_coins: int = bank.coins
	hub.station_content.get_node("SellBagMaterial_slime_essence").pressed.emit()
	check(owner.inventory.materials[&"slime_essence"] == slime-4 and bank.coins == sale_coins+12,"Actual quantity sale UI sells four and quotes twelve")
	hub.station_content.get_node("BuyWeapon_common_sword_0").pressed.emit(); await frames()
	var spin: SpinBox = hub.station_content.get_node("PurchaseQuantity/Amount")
	spin.get_line_edit().text = "2"; spin.apply(); await frames()
	check(hub._pending_purchase["quantity"] == 2 and hub.station_content.get_node("PurchaseItemPreview").quantity_label.text.contains("Tổng 40"),"Typed purchase quantity updates visible total")
	var count: int = owner.inventory.items.size(); var purchase_coins: int = bank.coins
	hub.station_content.get_node("ConfirmPurchase").pressed.emit()
	check(owner.inventory.items.size() == count+2 and bank.coins == purchase_coins-40,"One purchase confirmation commits two gear items")
	hub.close_station(); hub.open_station(&"healer_consumables"); await frames()
	spin = hub.station_content.get_node("CraftQuantity/Amount"); spin.get_line_edit().text = "3"; spin.apply(); await frames()
	var bandages: int = owner.inventory.consumables[&"bandage"]
	hub.station_content.get_node("CraftConsumable_bandage").pressed.emit()
	check(owner.inventory.consumables[&"bandage"] == bandages+3,"Typed crafting quantity creates three stack units")
	hub.close_station(); hub.open_station(&"rune_learning"); await frames()
	hub.station_content.get_node("RuneService_fire").pressed.emit(); await frames()
	spin = hub.station_content.get_node("PurchaseQuantity/Amount"); spin.value = 2; await frames()
	var rune_count: int = owner.inventory.bag[&"fire"]
	hub.station_content.get_node("ConfirmPurchase").pressed.emit()
	check(owner.inventory.bag[&"fire"] == rune_count+2,"Rune craft confirmation uses entered quantity")
	hub.close_station(); hub.open_station(&"smith_stones"); await frames()
	spin = hub.station_content.get_node("StoneQuantity/Amount"); spin.value = 2; await frames()
	var stones: int = owner.inventory.materials[&"enhancement_stone_1"]; var upgrades: int = owner.inventory.materials[&"enhancement_stone_2"]
	hub.station_content.get_node("CombineStone_1").pressed.emit()
	check(owner.inventory.materials[&"enhancement_stone_1"] == stones-10 and owner.inventory.materials[&"enhancement_stone_2"] == upgrades+2,"Stone combining uses entered batch count atomically")
	hub.close_station(); hub.queue_free(); await frames(5)
	print("RESULT BagQuantity checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

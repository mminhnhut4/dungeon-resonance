extends SceneTree
## Focused real-scene campfire UI and native action guards, isolated QA data.
## --capture is only used after the parent assigns a GPU slot.
var checks: int = 0
var failures: int = 0
var captures: int = 0
var level: Node2D
var session: SurvivalSession
var capture: bool = false
var geometry: Array[Dictionary] = []
var destination: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var hz: int = 60
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	destination = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").replace("\\","/")
	capture = OS.get_cmdline_user_args().has("--capture")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/") or not destination.is_absolute_path() or (capture and DisplayServer.get_name()=="headless"):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	AudioServer.set_bus_mute(0,true)
	if capture:
		DisplayServer.window_set_title("Dungeon Resonance · Campfire UI QA")
		print("GPU QA screen=%d screens=%d renderer=%s" % [DisplayServer.window_get_current_screen(),DisplayServer.get_screen_count(),RenderingServer.get_video_adapter_name()])
	level = preload("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	session = level.survival
	# TestLevel loads the shared QA profile; this UI fixture owns a fresh writer/path.
	# Moving a loaded v2 profile to an empty path correctly rejects invalid_before.
	session.profile = SanctuaryProfile.new()
	session.profile.save_path = "user://verification/campfire_%d/profile.json" % OS.get_process_id()
	session.director.automatic = false
	session.director.set_physics_process(false)
	session.condition.enabled = false
	session.campfire.set_physics_process(false)
	for enemy: SlimeEnemy in level.enemies: enemy.ai_enabled = false
	session.player.reset_movement_at(Vector2(670,640))
	await _frames(20)
	var inventory: GearInventory = session.gear.inventory
	for id: StringName in [&"metal",&"dust",&"crystal",&"slime_essence"]: inventory.materials[id] = 20
	for id: StringName in inventory.consumables: inventory.consumables[id] = 2
	for data: RelicData in RelicRuntime.CATALOG:
		session.gear.relics.acquire(data.id)
		var item: GearItem = inventory.add_item(&"relic",data.id)
		if data.id==&"phantom_mirror": session.panel._relic_uid = item.uid
	var spare: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD)
	var broken: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD)
	broken.broken = true
	var blank: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD,GearItem.Quality.VERY_RARE)
	blank.source = &"drop"
	var original_uid: int = inventory.equipped_weapon_uid
	var originals: Array = inventory.items.keys()
	var materials_before: Dictionary = inventory.materials.duplicate(true)
	var consumables_before: Dictionary = inventory.consumables.duplicate(true)
	var equipped_before: Array = session.gear.relics.equipped.duplicate()
	for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = extent
		await _frames(5)
		session.panel.open(true)
		await _frames(10)
		for tab: int in 4:
			session.panel.tabs.current_tab = tab
			await _frames(6)
			_check(root.get_visible_rect().encloses(session.panel.panel.get_global_rect()), "Campfire panel bounded at %s tab %d" % [extent,tab])
			_check(session.panel.panel.get_global_rect().encloses(session.panel.tabs.get_global_rect()) and session.panel.tabs.get_global_rect().end.y <= session.panel.footer_stack.global_position.y, "Tabbed content is bounded above persistent feedback/footer")
			_check(root.get_visible_rect().encloses(session.panel.close_button.get_global_rect()) and session.panel.close_button.size.y>=44, "Close footer visible with 44px hit area")
			if not root.get_visible_rect().encloses(session.panel.close_button.get_global_rect()):
				var parent: Node = session.panel.close_button
				while parent != session.panel:
					if parent is Control: print("LAYOUT ANCESTOR %s rect=%s min=%s" % [parent.get_class(),parent.get_global_rect(),parent.get_combined_minimum_size()])
					parent = parent.get_parent()
				for child: Node in session.panel.tabs.find_children("*","Control",true,false):
					if child.is_visible_in_tree(): print("LAYOUT CHILD %s rect=%s min=%s" % [child.get_class(),child.get_global_rect(),child.get_combined_minimum_size()])
			_check(session.panel.panel.get_theme_stylebox("panel") is StyleBoxTexture, "Campfire uses approved antique skin")
			_check(session.panel.tabs.get_tab_bar().size.y>=44, "Four group tabs have usable hit area")
			for child: Node in session.panel.panel.find_children("*","Button",true,false):
				if child.is_visible_in_tree(): _check(child.size.y>=44,"Visible action has 44px hit area")
			if tab==0:
				_check(session.panel.selected_title.text==OpeningItemPresentation.item_name(inventory.items[original_uid]), "Selected item has actual local name")
				_check(session.panel.item_list.item_count+session.panel.relic_list.item_count==inventory.items.size(), "Every owned UID remains in exactly one item list")
				for index: int in session.panel.item_list.item_count:
					var caption: String = session.panel.item_list.get_item_text(index)
					_check(not caption.contains("starter_") and not caption.contains("shadow_dagger") and not caption.begins_with("#") and not caption.contains(" · armor") and not caption.contains(" · catalyst"), "Item row has no technical ID/kind/UID")
					var item: GearItem = inventory.items[int(session.panel.item_list.get_item_metadata(index))]
					_check(session.panel.item_list.get_item_icon(index)!=null,"Every row has contextual art or neutral missing-art marker")
					if OpeningItemPresentation.item_icon(item)==null: _check(session.panel.item_list.get_item_icon(index)==OpeningItemPresentation.MISSING_ICON and "Chưa có ảnh riêng" in caption,"Missing art is explicit without unrelated item reuse")
				_check(session.panel.selected_image.texture!=null and session.panel.selected_image.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Selected sword uses whole contextual art")
			if tab==1:
				for card: ServiceItemCard in session.panel.craft_cards.values(): _check(card.quantity_label.visible and card.detail_label.visible and "có" in card.detail_label.text and card.get_signal_connection_list(&"pressed").size()==1,"Recipe shows cost/current stock/output count and one original callback")
			if tab==2:
				_check(session.panel.use_cards[&"potion"].disabled and session.panel.use_cards[&"bandage"].disabled and session.panel.use_cards[&"antidote"].disabled, "Unneeded medicine actions visibly disabled")
			if tab==3:
				_check(session.panel.relic_cards.size()==3 and session.panel.relic_list.item_count==4, "Relics have actual owned names and exactly three slots")
				_check(not session.panel.relic_description.text.is_empty(),"Selected relic explains its actual purpose")
			geometry.append({"viewport":[extent.x,extent.y],"tab":tab,"panel":str(session.panel.panel.get_global_rect()),"footer":str(session.panel.close_button.get_global_rect()),"minimum":str(session.panel.panel.get_combined_minimum_size())})
			if capture: await _capture("campfire_tab%d_%dx%d" % [tab,extent.x,extent.y])
		session.panel.close()
		await _frames(3)
	_check(inventory.items.keys()==originals and inventory.equipped_weapon_uid==original_uid and inventory.materials==materials_before and inventory.consumables==consumables_before and session.gear.relics.equipped==equipped_before, "Opening all groups changes no UID, cost, item, consumable or relic assignment")
	_check(not FileAccess.file_exists(session.profile.save_path), "Presentation performs no save")
	# Selection survives changed/rebuild, and equipped gear remains protected.
	session.panel.tabs.current_tab = 0
	session.panel.open(true)
	await _frames(6)
	_select_uid(spare.uid)
	inventory.changed.emit()
	await _frames(3)
	_check(session.panel.selected_uid==spare.uid and session.panel.selected_title.text==OpeningItemPresentation.item_name(spare), "Selection survives ledger refresh without switching UID")
	_select_uid(broken.uid)
	_check(session.panel.equip_button.disabled and "Hỏng" in session.panel.selected_state.text, "Broken selected item cannot be equipped")
	_select_uid(blank.uid)
	_check(session.panel.equip_button.disabled and "Phôi" in session.panel.selected_state.text, "Forging blank cannot be equipped")
	_select_uid(original_uid)
	_check(session.panel.dismantle_button.disabled, "Equipped UID cannot be dismantled")
	# Native upgrade calls old craft callback; exact quote and one UID retained.
	_select_uid(spare.uid)
	var quote: Dictionary = OpeningItemPresentation.craft_quote(inventory,&"upgrade",spare.uid)
	var metal_before: int = inventory.materials[&"metal"]
	var dust_before: int = inventory.materials[&"dust"]
	await _accept(session.panel.upgrade_button)
	_check(inventory.items.has(spare.uid) and spare.quality==GearItem.Quality.RARE and inventory.materials[&"metal"]==metal_before-int(quote["metal"]) and inventory.materials[&"dust"]==dust_before-int(quote["dust"]), "Native upgrade uses original exact price and same UID once")
	_check(session.panel.upgrade_button.disabled, "Rare item cannot be upgraded again at camp")
	await _accept(session.panel.equip_button)
	_check(inventory.equipped_weapon_uid==spare.uid and inventory.items.has(original_uid),"Native equip selects the same owned UID without replacing the ledger")
	_select_uid(original_uid)
	await _accept(session.panel.equip_button)
	_select_uid(broken.uid)
	metal_before = inventory.materials[&"metal"]
	dust_before = inventory.materials[&"dust"]
	await _accept(session.panel.dismantle_button)
	_check(not inventory.items.has(broken.uid) and inventory.materials[&"metal"]==metal_before+3 and inventory.materials[&"dust"]==dust_before+1,"Native dismantle removes exactly the selected Common UID at original yield")
	session.panel.selected_uid = broken.uid
	session.panel.dismantle_button.pressed.emit()
	_check(inventory.materials[&"metal"]==metal_before+3 and inventory.materials[&"dust"]==dust_before+1,"Repeated stale dismantle callback cannot duplicate materials")
	# Camp/no-ingredient guards remain effective even on explicit callback delivery.
	session.panel.close()
	session.panel.open(false)
	await _frames(3)
	var potion_before: int = inventory.consumables[&"potion"]
	var dust_saved: int = inventory.materials[&"dust"]
	_check(session.panel.craft_cards[&"potion"].disabled,"Outside camp recipe disabled with reason")
	session.panel.craft_cards[&"potion"].pressed.emit()
	_check(inventory.consumables[&"potion"]==potion_before and inventory.materials[&"dust"]==dust_saved,"Outside camp callback spends nothing")
	session.panel.close()
	session.panel.open(true)
	inventory.materials[&"dust"] = 0
	session.panel.refresh(false)
	_check(session.panel.craft_cards[&"potion"].disabled,"No ingredient recipe disabled")
	session.panel.craft_cards[&"potion"].pressed.emit()
	_check(inventory.consumables[&"potion"]==potion_before and inventory.materials[&"dust"]==0,"Rejected recipe consumes nothing")
	inventory.materials[&"dust"] = dust_saved
	session.panel.tabs.current_tab = 1
	await _frames(4)
	await _accept(session.panel.craft_cards[&"potion"])
	_check(inventory.consumables[&"potion"]==potion_before+1 and inventory.materials[&"dust"]==dust_saved-4,"Native recipe creates exactly one potion at unchanged cost")
	# Native use preserves no-need/no-stock guards and heals once when needed.
	session.panel.tabs.current_tab = 2
	await _frames(3)
	potion_before = inventory.consumables[&"potion"]
	session.panel.use_cards[&"potion"].pressed.emit()
	_check(inventory.consumables[&"potion"]==potion_before,"Full health use callback consumes nothing")
	session.player.health.apply_damage(40)
	session.panel.refresh(false)
	var hp_before: float = session.player.health.current_health
	await _accept(session.panel.use_cards[&"potion"])
	_check(inventory.consumables[&"potion"]==potion_before-1 and is_equal_approx(session.player.health.current_health,hp_before+30),"Native potion input heals 30 and consumes one")
	var band_before: int = inventory.consumables[&"bandage"]
	session.panel.use_cards[&"bandage"].pressed.emit()
	_check(inventory.consumables[&"bandage"]==band_before,"No bleeding use callback consumes nothing")
	var antidote_before: int = inventory.consumables[&"antidote"]
	session.panel.use_cards[&"antidote"].pressed.emit()
	_check(inventory.consumables[&"antidote"]==antidote_before,"No poison use callback consumes nothing")
	potion_before = inventory.consumables[&"potion"]
	inventory.consumables[&"potion"] = 0
	session.panel.refresh(false)
	session.panel.use_cards[&"potion"].pressed.emit()
	_check(session.panel.use_cards[&"potion"].disabled and inventory.consumables[&"potion"]==0,"No-stock use remains disabled and cannot consume a negative count")
	inventory.consumables[&"potion"] = potion_before
	var trap_before: int = inventory.consumables[&"trap"]
	var placeholders: Array[Node] = []
	for index: int in 8:
		var placeholder := Node.new()
		level.add_child(placeholder)
		placeholder.add_to_group(&"floor_traps")
		placeholders.append(placeholder)
	session.panel.refresh(false)
	session.panel.use_cards[&"trap"].pressed.emit()
	_check(session.panel.use_cards[&"trap"].disabled and inventory.consumables[&"trap"]==trap_before and get_nodes_in_group(&"floor_traps").size()==8,"Eight-trap cap visibly disables placement and spends nothing")
	for placeholder: Node in placeholders: placeholder.free()
	# Relic assignment delegates exactly one old slot callback.
	session.panel.tabs.current_tab = 3
	await _frames(4)
	var selected_relic: GearItem = inventory.items[session.panel._relic_uid]
	await _accept(session.panel.relic_cards[0])
	_check(session.gear.relics.equipped[0].id==selected_relic.definition_id and inventory.items.has(selected_relic.uid),"Native relic input assigns old slot without losing UID")
	_check(session.panel.relic_cards[0].disabled,"Already equipped relic cannot be duplicated")
	await _accept(session.panel.inventory_button)
	_check(not session.panel.is_open and session.gear.modal.is_open,"Native inventory footer hands modal ownership to the existing inventory")
	session.gear.modal.close()
	session.panel.close()
	# Matching production smuggler UI uses real offer, original transaction/price.
	session.director.current_incident = &"smuggler"
	session.merchant_trade_used = false
	session.profile.souls = 20
	session.merchant_panel.show()
	session.player.suspend_controls(true)
	session._refresh_merchant_view()
	await _frames(5)
	for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = extent
		await _frames(6)
		_check(root.get_visible_rect().encloses(session.merchant_panel.get_global_rect()),"Smuggler panel stays bounded at %s" % extent)
		_check(session.merchant_choices[&"souls"].size.y>=44 and session.merchant_choices[&"blood"].size.y>=44,"Smuggler payment choices retain 44px hit area")
		_check(not session.merchant_choices[&"souls"].disabled and not session.merchant_choices[&"blood"].disabled,"Available offer shows both original payment choices enabled")
		if capture: await _capture("smuggler_available_%dx%d" % [extent.x,extent.y])
	if not root.get_visible_rect().encloses(session.merchant_panel.get_global_rect()): print("MERCHANT GEOMETRY panel=%s min=%s viewport=%s" % [session.merchant_panel.get_global_rect(),session.merchant_panel.get_combined_minimum_size(),root.get_visible_rect()])
	var count_before: int = inventory.items.size()
	var uids_before: Array = inventory.items.keys()
	var items_before: Array = GearInventoryCodec.encode(inventory)["items"].duplicate(true)
	await _accept(session.merchant_choices[&"souls"])
	_check(session.profile.souls==5 and inventory.items.size()==count_before+1 and session.merchant_trade_used,"Native smuggler purchase keeps 15 Souls and one actual item")
	var purchased_uids: Array = inventory.items.keys().filter(func(uid: int) -> bool: return not uids_before.has(uid))
	var purchased: GearItem = inventory.items[purchased_uids[0]] if purchased_uids.size()==1 else null
	var items_after: Array = GearInventoryCodec.encode(inventory)["items"]
	_check(purchased!=null and purchased.kind==&"weapon" and purchased.definition_id==&"shadow_dagger" and purchased.quality==GearItem.Quality.RARE and items_before.all(func(item: Dictionary) -> bool: return items_after.has(item)),"Smuggler adds exactly one Rare shadow dagger UID and preserves all existing items")
	var purchased_ledger: Dictionary = GearInventoryCodec.encode(inventory)
	var max_hp_before: float = session.player.health.maximum_health
	session.merchant_choices[&"souls"].pressed.emit()
	_check(session.profile.souls==5 and inventory.items.size()==count_before+1,"Used smuggler callback cannot buy twice")
	session.merchant_choices[&"blood"].pressed.emit()
	_check(GearInventoryCodec.encode(inventory)==purchased_ledger and session.profile.souls==5 and session.player.health.maximum_health==max_hp_before,"Repeated Souls and blood callbacks preserve the purchased UID ledger and exact resources")
	_check(session.merchant_choices[&"souls"].disabled and session.merchant_choices[&"blood"].disabled,"Purchased offer visibly disables both payment choices")
	if capture: await _capture("smuggler_sold_1920x1080")
	session.merchant_panel.hide()
	session.player.suspend_controls(false)
	var file := FileAccess.open(destination.path_join("campfire_geometry.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(geometry,"\t"))
	file.close()
	level.queue_free()
	await _frames(8)
	_check(is_equal_approx(Engine.time_scale,1),"Campfire teardown releases UI time ownership")
	print("RESULT CampfireUI checks=%d failures=%d captures=%d physics_hz=%d" % [checks,failures,captures,Engine.physics_ticks_per_second])
	await root.get_node("AudioManager").shutdown()
	quit(0 if failures==0 else 1)

func _select_uid(uid: int) -> void:
	for index: int in session.panel.item_list.item_count:
		if int(session.panel.item_list.get_item_metadata(index))==uid:
			session.panel.item_list.select(index)
			session.panel._selected(index)
			return

func _accept(button: Button) -> void:
	button.grab_focus()
	await _frames(3)
	for pressed: bool in [true,false]:
		var event := InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = pressed
		root.push_input(event,true)
		await _frames(2)

func _frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(destination.path_join(label+".png"))
	_check(error==OK,"Actual GPU frame saved")
	if error==OK: captures += 1

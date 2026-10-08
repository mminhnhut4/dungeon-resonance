extends SceneTree
## Same real Hub fixture measures the immutable one-column reference and revision.
## Capture is run only in an explicitly assigned GPU slot; transactions are isolated.

var checks: int = 0
var failures: int = 0
var captures: int = 0
var hub: PrologueHub
var baseline: bool = false
var capture: bool = false
var measurements: Array[Dictionary] = []
var destination: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	baseline = OS.get_cmdline_user_args().has("--baseline")
	capture = OS.get_cmdline_user_args().has("--capture")
	destination = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").replace("\\", "/")
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\", "/").begins_with(allowed + "/") or not destination.is_absolute_path() or (capture and DisplayServer.get_name() == "headless"):
		print("FAIL: Two-column fixture requires private data/evidence and assigned render window")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	AudioServer.set_bus_mute(0, true)
	if capture:
		DisplayServer.window_set_title("Dungeon Resonance · Two-column services QA")
		print("GPU QA screen=%d screen_count=%d renderer=%s" % [DisplayServer.window_get_current_screen(), DisplayServer.get_screen_count(), RenderingServer.get_video_adapter_name()])
	hub = preload("res://scenes/hub/prologue_hub_room.tscn").instantiate() as PrologueHub
	hub.profile = SanctuaryProfile.new()
	hub.profile.save_path = "user://two_column_transaction_fixture.json"
	hub.profile.coins = 5000
	for id: StringName in MaterialCatalog.IDS: hub.profile.material_stash[id] = 7 if id != &"origin_divine_stone" else 0
	hub.profile.learned_blueprints.assign([&"world_axe", &"world_fan"])
	hub.world_building_enabled = true
	root.add_child(hub)
	current_scene = hub
	await _frames(8)
	var coins_before: int = hub.profile.coins
	var stash_before: Dictionary = hub.profile.material_stash.duplicate()
	var count_before: int = hub.gear.inventory.items.size()
	var uid_before: int = hub.gear.inventory.equipped_weapon_uid
	for extent: Vector2i in [Vector2i(800,600), Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = extent
		await _frames(5)
		for service: StringName in [&"stash", &"merchant"]:
			hub.open_station(service)
			await _frames(12)
			_check(root.get_visible_rect().encloses(hub.station_panel.get_global_rect()), "Panel stays inside %s" % extent)
			_check(root.get_visible_rect().encloses(hub.station_close.get_global_rect()) and hub.station_close.size.y >= 44, "Fixed close button stays visible")
			var cards: Array[ServiceItemCard] = []
			var full: int = 0
			var partial: int = 0
			var clip: Rect2 = hub.station_scroll.get_global_rect()
			for child: Node in hub.station_content.get_children():
				if not child is ServiceItemCard:
					if child is Control: _check(is_equal_approx(child.size.x, hub.station_content.size.x - (0.0 if baseline else float(hub.station_content.get("right_inset")))), "Headings/deposit span both columns, leaving the scroll thumb clear")
					continue
				var card := child as ServiceItemCard
				cards.append(card)
				if clip.encloses(card.get_global_rect()): full += 1
				elif clip.intersects(card.get_global_rect()): partial += 1
				_check(card.size.y >= 44 and card._action_panel.size.y >= 44, "Native item action and visible affordance meet 44px minimum")
				_check(card.get_global_rect().encloses(card.item_icon.get_global_rect()) and card.get_global_rect().encloses(card.item_title.get_global_rect()) and card.get_global_rect().encloses(card.quantity_label.get_global_rect()) and card.get_global_rect().encloses(card._action_panel.get_global_rect()), "Image/name/count/action stay inside their card")
				_check(card.quantity_label.get_theme_font_size("font_size") >= 14 and card.item_title.get_theme_font_size("font_size") >= 16, "Vietnamese labels remain readable")
				if not baseline:
					_check(card.get("compact") == true and not card.detail_label.visible, "Long descriptions move out of compact cards")
					_check(card.tooltip_text.contains(card.detail_label.text), "Full description remains in tooltip")
					_check(card.item_icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Whole item art keeps its aspect ratio")
					_check(card.get_global_rect().end.x <= hub.station_scroll.get_v_scroll_bar().global_position.x + 1, "Scroll thumb cannot cover a card or its action")
					if service == &"merchant": _check(_quoted_price_visible(card), "Actual quoted sale total or purchase price in Linh Thạch is visible before action")
			if not baseline:
				_check(int(hub.station_content.get("columns")) == 2, "Default storage/shop layout has two columns")
				_check(hub.station_scroll.get_v_scroll_bar().visible and hub.station_scroll.get_v_scroll_bar().size.x >= 12, "One antique scroll thumb remains visibly usable")
				for index: int in range(cards.size() - 1):
					var a: Rect2 = cards[index].get_global_rect()
					var b: Rect2 = cards[index + 1].get_global_rect()
					_check(not a.intersects(b), "Adjacent cards never overlap")
					if is_equal_approx(a.position.y, b.position.y):
						_check(is_equal_approx(a.size.x, b.size.x) and is_equal_approx(a.size.y, b.size.y) and b.position.x > a.end.x, "Left/right pair has equal width and aligned height")
			measurements.append({"service": String(service), "viewport": [extent.x, extent.y], "panel_position": [hub.station_panel.position.x, hub.station_panel.position.y], "panel_size": [hub.station_panel.size.x, hub.station_panel.size.y], "scroll_size": [clip.size.x,clip.size.y], "full_visible_items": full, "partial_visible_items": partial, "total_items": cards.size(), "first_card_size": [cards[0].size.x,cards[0].size.y]})
			print("VISIBLE %s %dx%d full=%d partial=%d panel=%s card=%s" % [service, extent.x, extent.y, full, partial, hub.station_panel.size, cards[0].size])
			if not baseline:
				var left_y: float = cards[0].global_position.y
				var right_y: float = cards[1].global_position.y
				var wheel := InputEventMouseButton.new()
				wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
				wheel.pressed = true
				wheel.position = clip.get_center()
				root.push_input(wheel, true)
				await _frames(4)
				_check(hub.station_scroll.scroll_vertical > 0 and is_equal_approx(left_y - cards[0].global_position.y, right_y - cards[1].global_position.y), "Native wheel input scrolls both columns in synchrony")
				hub.station_scroll.scroll_vertical = 0
				await _frames(4)
			if service == &"stash":
				var ids: Array[StringName] = []
				var expected_ids: Array[StringName] = []
				for id: StringName in MaterialCatalog.IDS:
					if hub.profile.material_stash[id] > 0: expected_ids.append(id)
				for card: ServiceItemCard in cards: ids.append(StringName(String(card.name).trim_prefix("WithdrawMaterial_")))
				ids.sort(); expected_ids.sort()
				_check(ids == expected_ids and not hub.station_content.has_node("WithdrawMaterial_origin_divine_stone"), "All positive-stock catalog materials retained exactly once; empty stock omitted")
				if not baseline:
					cards[0].grab_focus()
					await _action(&"ui_right")
					_check(root.gui_get_focus_owner() == cards[1], "Controller/right arrow moves left to right")
					await _action(&"ui_down")
					_check(root.gui_get_focus_owner() == cards[3], "Down keeps the right column")
					await _action(&"ui_focus_prev")
					_check(root.gui_get_focus_owner() == cards[2], "Previous focus follows row-major order")
				var last: Button = hub.station_content.get_node("WithdrawMaterial_detox_root") as Button
				last.grab_focus()
				await _frames(5)
				_check(hub.station_scroll.scroll_vertical > 0, "Focus brings lower items into the shared scroll")
				_check(hub.find_children("*", "ScrollContainer", true, false).has(hub.station_scroll), "One station scroll owns the item grid")
			hub.station_scroll.scroll_vertical = 0
			hub.station_close.grab_focus()
			await _frames(4)
			if capture: await _capture("two_columns_%s_%dx%d" % [service, extent.x, extent.y])
			hub.close_station()
			await _frames(3)
	_check(hub.profile.coins == coins_before and hub.profile.material_stash == stash_before and hub.gear.inventory.items.size() == count_before and hub.gear.inventory.equipped_weapon_uid == uid_before, "Layout inspection preserves every transaction value")
	if not baseline:
		# Busy ordinary actions retain a guarded callback. A lineage policy denial
		# removes the callback; both cases must preserve the transaction values.
		hub.economy.set("_busy", true)
		hub.open_station(&"stash")
		await _frames(5)
		var denied := hub.station_content.get_node("WithdrawMaterial_metal") as Button
		_check(denied.disabled and denied.get_signal_connection_list(&"pressed").size() == 1, "Busy ordinary row is disabled with one guarded owner callback")
		denied.pressed.emit()
		_check(hub.profile.material_stash == stash_before, "Explicit pressed on read-only row cannot transfer")
		var lineage: Button = hub.station_content.get_node("WithdrawMaterial_aptitude_pill") as Button
		_check(lineage.disabled and lineage.get_signal_connection_list(&"pressed").is_empty(), "Lineage policy denial has no ordinary transfer callback")
		lineage.pressed.emit()
		_check(hub.profile.material_stash == stash_before and hub.profile.coins == coins_before and hub.gear.inventory.items.size() == count_before, "Busy/lineage forced presses preserve materials, coins and UID count")
		hub.close_station()
		hub.economy.set("_busy", false)
		# Native GUI input executes the existing shop callback exactly once.
		root.size = Vector2i(1280,720)
		hub.open_station(&"merchant")
		await _frames(8)
		var buy := hub.station_content.get_node("BuyWeapon_common_sword_0") as Button
		var quote: Dictionary = hub.economy.call(&"quote_buy", &"common_sword", GearItem.Quality.COMMON)
		_check(buy.get_signal_connection_list(&"pressed").size() == 1, "One native pressed handler retained")
		buy.grab_focus()
		await _frames(4)
		await _action(&"ui_accept")
		await _frames(5)
		_check(hub.profile.coins == coins_before and hub.gear.inventory.items.size() == count_before and hub.station_content.has_node("ConfirmPurchase"),"Accept first opens purchase confirmation without spending")
		(hub.station_content.get_node("ConfirmPurchase") as Button).grab_focus()
		await _frames(2)
		await _action(&"ui_accept")
		await _frames(5)
		_check(hub.profile.coins == coins_before - int(quote.get("coin_cost",0)) and hub.gear.inventory.items.size() == count_before + 1 and hub.gear.inventory.equipped_weapon_uid == uid_before, "Accept buys exactly one item at the unchanged quote, preserving equipped UID")
		hub.close_station()
	var file := FileAccess.open(destination.path_join("geometry_before.json" if baseline else "geometry_after.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements, "\t"))
	file.close()
	hub.queue_free()
	await _frames(8)
	_check(is_equal_approx(Engine.time_scale, 1), "Teardown releases service time claim")
	print("RESULT TwoColumnServiceUI baseline=%s checks=%d failures=%d captures=%d" % [baseline,checks,failures,captures])
	await root.get_node("AudioManager").shutdown()
	quit(0 if failures == 0 else 1)

func _quoted_price_visible(card: ServiceItemCard) -> bool:
	var key: String = String(card.name)
	var quote: Dictionary
	var price: int
	if key.begins_with("SellMaterial_"):
		quote = hub.economy.quote_material_sale(StringName(key.trim_prefix("SellMaterial_")))
		price = int(quote["total"])
	elif key.begins_with("SellBagMaterial_"):
		quote = hub.economy.quote_bag_material_sale(StringName(key.trim_prefix("SellBagMaterial_")))
		price = int(quote["total"])
	elif key.begins_with("SellBagEquipment_"):
		quote = hub.economy.quote_bag_equipment_sale(int(key.trim_prefix("SellBagEquipment_")))
		price = int(quote["total"])
	elif key.begins_with("BuyWeapon_"):
		var stock: String = key.trim_prefix("BuyWeapon_")
		var split: int = stock.rfind("_")
		if split < 0: return false
		quote = hub.economy.quote_buy(StringName(stock.substr(0, split)), int(stock.substr(split + 1)))
		price = int(quote["coin_cost"])
	else: return false
	var expected := RegEx.new()
	if expected.compile("(^|[^0-9])%d Linh Thạch($|[^0-9])" % price) != OK: return false
	return price > 0 and card.quantity_label.is_visible_in_tree() and expected.search(card.quantity_label.text) != null

func _frames(count: int) -> void:
	for index: int in count: await process_frame

func _action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)

func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + description)

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(destination.path_join(label + ".png"))
	_check(error == OK, "Actual GPU frame saved")
	if error == OK: captures += 1

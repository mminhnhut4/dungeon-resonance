extends SceneTree
## Real hub/service fixture, isolated profile. No transaction is executed.
## --capture is reserved for the GPU window granted by the integrating parent.

var checks: int = 0
var failures: int = 0
var captures: int = 0
var hub: PrologueHub
var capture: bool = false
var first_preview: bool = false
var geometry: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	first_preview = OS.get_cmdline_user_args().has("--first-service-preview")
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\", "/").begins_with(allowed + "/") or (capture and DisplayServer.get_name() == "headless"):
		print("FAIL: Antique UI fixture requires isolated data and assigned render window")
		quit(2)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	if capture: DisplayServer.window_set_title("Dungeon Resonance · Antique services QA")
	if capture: print("GPU QA screen=%d screen_count=%d renderer=%s" % [DisplayServer.window_get_current_screen(),DisplayServer.get_screen_count(),RenderingServer.get_video_adapter_name()])
	AudioServer.set_bus_mute(0, true)
	hub = preload("res://scenes/hub/prologue_hub_room.tscn").instantiate() as PrologueHub
	hub.profile = SanctuaryProfile.new()
	hub.profile.save_path = "user://antique_fixture_unused.json"
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
	var survival_session := SurvivalSession.new()
	survival_session.gear = hub.gear
	survival_session.player = hub.player
	survival_session.profile = hub.profile
	survival_session.condition = hub.condition
	survival_session.set_physics_process(false)
	var crafting := SurvivalPanel.new()
	crafting.session = survival_session
	root.add_child(survival_session)
	survival_session.set_physics_process(false)
	survival_session.add_child(crafting)
	_check(ItemArtCatalog.icon(&"trap") == null, "Missing trap has an honest pending-image state")
	for id: StringName in MaterialCatalog.IDS:
		var icon: Texture2D = ItemArtCatalog.icon(id)
		_check(icon == null or not icon.get_image().is_empty(), "Mapped image validates; newly added unmapped IDs keep an explicit pending state: %s" % id)
	var extents: Array[Vector2i] = [Vector2i(800,600), Vector2i(1280,720), Vector2i(1920,1080)]
	var services: Array[StringName] = [&"stash", &"merchant", &"blacksmith", &"smith_forge", &"smith_enhance", &"smith_stones", &"healer_consumables"]
	if first_preview:
		extents.assign([Vector2i(800,600),Vector2i(1280,720)])
		services.assign([&"stash",&"merchant"])
	for extent: Vector2i in extents:
		root.size = extent
		await _frames(5)
		for service: StringName in services:
			hub.open_station(service)
			await _frames(8)
			_check(root.get_visible_rect().encloses(hub.station_panel.get_global_rect()), "%s panel bounded at %s" % [service, extent])
			_check(root.get_visible_rect().encloses(hub.station_close.get_global_rect()) and hub.station_close.size.y >= 44, "%s close hit area visible at %s" % [service, extent])
			_check(hub.station_title.text.length() > 0 and hub.station_panel.get_theme_stylebox("panel") is StyleBoxTexture, "%s has antique frame and persistent title" % service)
			if service == &"stash":
				var rows: int = 0
				for child: Node in hub.station_content.get_children():
					if child is ServiceItemCard:
						rows += 1
						_check(child.item_title.text.length() > 0 and "Trong kho" in child.quantity_label.text, "Storage row has actual name/count and mapped image or pending state")
				_check(rows == MaterialCatalog.IDS.size(), "All actual material catalog IDs have storage rows")
				var last: Control = hub.station_content.get_node("WithdrawMaterial_detox_root")
				last.grab_focus()
				await _frames(5)
				_check(hub.station_scroll.scroll_vertical > 0, "Keyboard focus scrolls to last material")
				hub.station_scroll.scroll_vertical = 0
				await _frames(3)
			if service == &"merchant":
				_check(hub.station_content.get_node("BuyWeapon_common_sword_0") is Button, "Shop preserves common_sword quote/action NodePath")
				_check(hub.station_content.get_node("SellMaterial_crystal") is ServiceItemCard, "Sale uses illustrated card with existing callback")
			for child: Node in hub.station_content.get_children():
				if child is ServiceItemCard:
					_check(child.size.x <= hub.station_scroll.size.x + 1 and child.size.y >= (76 if child.compact else 96), "Item row wraps inside scroll and keeps generous hit area")
					_check(child.get_global_rect().encloses(child.item_icon.get_global_rect()), "Item image stays inside its row")
			geometry.append({"service":String(service),"extent":str(extent),"panel":str(hub.station_panel.get_global_rect()),"close":str(hub.station_close.get_global_rect()),"content_width":hub.station_content.size.x,"scroll_width":hub.station_scroll.size.x})
			if capture and service in [&"stash", &"merchant", &"smith_stones", &"healer_consumables"]:
				await _capture("antique_%s_%dx%d" % [service, extent.x, extent.y])
			hub.close_station()
			await _frames(3)
		if first_preview: continue
		var screen: InventoryScreen = hub.gear.modal as InventoryScreen
		screen.open()
		await _frames(8)
		_check(screen.panel.get_theme_stylebox("panel") is StyleBoxTexture and screen.bag_buttons[0].get_theme_stylebox("normal") is StyleBoxTexture, "Inventory frame and tactile slots share the antique skin")
		_check(root.get_visible_rect().encloses(screen.panel.get_global_rect()), "Antique inventory remains bounded at %s" % extent)
		if capture: await _capture("antique_inventory_%dx%d" % [extent.x,extent.y])
		screen.close()
		crafting.open()
		await _frames(8)
		_check(root.get_visible_rect().encloses(crafting.panel.get_global_rect()), "Crafting remains bounded at %s" % extent)
		if not root.get_visible_rect().encloses(crafting.panel.get_global_rect()):
			print("CRAFTING GEOMETRY viewport=%s panel=%s minimum=%s" % [str(root.get_visible_rect()),str(crafting.panel.get_global_rect()),str(crafting.panel.get_combined_minimum_size())])
			for child: Node in crafting.panel.find_children("*", "Control", true, false):
				if child.get_combined_minimum_size().x > extent.x - 68: print("CRAFTING WIDE %s %s min=%s" % [child.get_class(),str(child.get_path()),str(child.get_combined_minimum_size())])
		_check(crafting.item_list.item_count == hub.gear.inventory.items.size() and crafting.item_list.get_item_icon(0) != null, "Crafting projects owned items with contextual icons")
		crafting.close()
	# A denied transfer capability must remove the callback as well as disable UI.
	# This is the same projection used by lineage-bound materials in cultivation.
	hub.economy.set("_busy", true)
	hub.open_station(&"stash")
	await _frames(6)
	var denied: Button = hub.station_content.get_node("WithdrawMaterial_metal") as Button
	_check(denied.disabled and denied.get_signal_connection_list(&"pressed").is_empty(), "Rejected transfer capability creates a read-only row with no withdraw callback")
	denied.pressed.emit()
	_check(hub.profile.material_stash == stash_before, "Even explicit pressed emission on denied row cannot withdraw")
	hub.close_station()
	hub.economy.set("_busy", false)
	_check(ItemArtCatalog.icon(&"aptitude_herb") == null and ItemArtCatalog.icon(&"aptitude_pill") == null, "New lineage IDs keep missing-art state instead of wrong material reuse")
	_check(hub.profile.coins == coins_before and hub.profile.material_stash == stash_before and hub.gear.inventory.items.size() == count_before and hub.gear.inventory.equipped_weapon_uid == uid_before, "Opening skins preserves prices, materials, item count and equipped UID")
	_check(not FileAccess.file_exists(hub.profile.save_path), "Presentation writes no profile")
	DirAccess.make_dir_recursive_absolute("res://docs/verification/antique_ui")
	var file: FileAccess = FileAccess.open("res://docs/verification/antique_ui/geometry.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(geometry,"\t"))
	file.close()
	survival_session.queue_free()
	hub.queue_free()
	await _frames(8)
	_check(is_equal_approx(Engine.time_scale,1), "Service/inventory teardown releases time claim")
	print("RESULT AntiqueServiceUI checks=%d failures=%d captures=%d" % [checks,failures,captures])
	await root.get_node("AudioManager").shutdown()
	quit(0 if failures == 0 else 1)

func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + description)

func _frames(count: int) -> void:
	for index: int in count: await process_frame

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var destination: String = "res://docs/verification/antique_ui/%s.png" % label
	DirAccess.make_dir_recursive_absolute("res://docs/verification/antique_ui")
	var error: Error = root.get_texture().get_image().save_png(destination)
	_check(error == OK, "Actual in-game GPU image saved")
	if error == OK: captures += 1

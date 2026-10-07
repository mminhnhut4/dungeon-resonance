extends "res://tests/preview_combat_art.gd"
## Finite GPU preview, with real GUI events and an isolated profile.

func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	if DisplayServer.get_name() == "headless":
		print("FAIL: Inventory preview requires GPU rendering")
		await audio.shutdown()
		quit(1)
		return
	campaign = preload("res://scenes/linear_campaign.tscn").instantiate() as LinearCampaign
	campaign.profile = SanctuaryProfile.new()
	campaign.profile.save_path = "user://verification/preview_inventory.json"
	root.add_child(campaign)
	current_scene = campaign
	campaign.survival.director.automatic = false
	_freeze_input_and_ai()
	campaign.player.relocate(Vector2(520, 640))
	_pointer(Vector2(850, 612))
	await _frames(12)
	var inventory: GearInventory = campaign.gear.inventory
	var modal: InventoryScreen = campaign.gear.modal as InventoryScreen
	var original: int = inventory.equipped_weapon_uid
	var spare: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD)
	await _inventory_capture("common_sword_idle")
	modal.open()
	await _frames(4)
	await _mouse(modal.bag_buttons[modal.bag_uids.find(spare.uid)], MOUSE_BUTTON_LEFT)
	if inventory.equipped_weapon_uid != spare.uid:
		failed = true
		print("FAIL: GPU GUI click did not equip the spare sword")
	modal._show_tooltip(spare.uid)
	await _inventory_capture("equipment_tooltip")
	await _mouse(modal.equipment_buttons[0], MOUSE_BUTTON_RIGHT)
	if inventory.equipped_weapon_uid != 0:
		failed = true
		print("FAIL: GPU right-click did not unequip")
	await _inventory_capture("unarmed_bag")
	await _mouse(modal.bag_buttons[modal.bag_uids.find(original)], MOUSE_BUTTON_LEFT)
	modal.tabs.current_tab = 1
	await _frames(3)
	await _inventory_capture("rune_tab")
	modal.close()
	campaign.player.suspend_controls(false)
	await _frames(4)
	_pointer(Vector2(850, 612))
	var event := InputEventAction.new()
	event.action = &"attack"
	event.pressed = true
	root.push_input(event, true)
	await _frames(6)
	await _inventory_capture("common_sword_swing")
	event.pressed = false
	root.push_input(event, true)
	await _frames(30)
	_pointer(Vector2(280, 612))
	await _frames(8)
	await _inventory_capture("common_sword_left")
	campaign.enter_stage(4)
	_freeze_input_and_ai()
	campaign.player.relocate(Vector2(560, 640))
	await _frames(8)
	modal.open()
	await _frames(3)
	await _inventory_capture("boss_inventory")
	modal.close()
	campaign.queue_free()
	await _frames(5)
	await audio.shutdown()
	print("INVENTORY PREVIEW: %d captures; %s" % [captures, "FAIL" if failed else "PASS"])
	quit(1 if failed else 0)


func _mouse(button: Button, code: MouseButton) -> void:
	var click := InputEventMouseButton.new()
	click.position = button.get_global_rect().get_center()
	click.button_index = code
	click.pressed = true
	root.push_input(click, true)
	await _frames(1)
	click.pressed = false
	root.push_input(click, true)
	await _frames(3)


func _inventory_capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://docs/verification/inventory_" + label + ".png")
	var status: Error = image.save_png(path)
	if status != OK:
		failed = true
		print("FAIL: Inventory capture %s" % error_string(status))
	else:
		print("CAPTURE %s" % path)
	captures += 1

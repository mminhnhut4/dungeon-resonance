extends SceneTree
## Finite GPU evidence: actual main scene, UI clicks, house and painted campaign.

var flow: GameFlow
var failures: int = 0
var captures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	if DisplayServer.get_name() == "headless":
		print("FAIL: Prologue preview requires real GPU rendering")
		await audio.shutdown()
		quit(1)
		return
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/preview_prologue.json"
	flow.qa_tools_enabled = true # Explicit QA sample chest preview.
	root.add_child(flow)
	current_scene = flow
	await _frames(14)
	var hub: PrologueHub = flow.active_scene as PrologueHub
	_camera(hub.player)
	_pointer(hub.player, Vector2(650, 610))
	await _capture("training_yard")
	hub.player.relocate(Vector2(1050, 640))
	await _frames(5)
	hub.claim_test_chest()
	hub.gear.modal.open()
	await _frames(5)
	var screen: InventoryScreen = hub.gear.modal as InventoryScreen
	var rare: int = -1
	for index: int in screen.bag_uids.size():
		if screen.bag_uids[index] == 0: continue
		var item: GearItem = hub.gear.inventory.items[screen.bag_uids[index]]
		if item.equipment_definition == PrologueHub.RARE_SWORD: rare = index
	if rare >= 0:
		await _mouse(screen.bag_buttons[rare], MOUSE_BUTTON_LEFT)
	_check(hub.player.equipped_weapon.definition == PrologueHub.RARE_SWORD.moveset and hub.player.equipped_weapon.additional_runes.size() == 1, "Actual bag mouse click equips the Rare lightning sword")
	await _capture("seven_slot_inventory")
	hub.gear.modal.close()
	hub.player.relocate(hub.stations[&"house"].global_position)
	await _frames(5)
	await _capture("house_door")
	_check(hub.interact_station(&"house"), "House E interaction enters the separate safe interior")
	await _frames(8)
	await _capture("player_home")
	hub.player.relocate(hub.house.bed_point.global_position)
	hub.player.health.apply_damage(20)
	_check(hub.interact_station(&"bed") and hub.player.health.current_health == hub.player.health.maximum_health, "Visible bed rest restores the actual health")
	hub.player.relocate(hub.house.exit_point.global_position)
	hub.interact_station(&"home_exit")
	hub.player.relocate(Vector2(1570, 640))
	await _frames(8)
	_spawn_item_board(hub)
	await _frames(18)
	await _capture("approved_loot_fire_1")
	await _frames(10)
	await _capture("approved_loot_fire_2")
	hub.gear.inventory.add_material(&"crystal", 3)
	hub.gear.inventory.add_material(&"slime_essence", 2)
	hub.economy.deposit_all()
	hub.player.relocate(hub.stations[&"merchant"].global_position)
	hub.open_station(&"merchant")
	await _frames(7)
	await _capture("kael_sale")
	hub.close_station()
	hub.player.relocate(hub.stations[&"portal"].global_position)
	await _frames(7)
	await _capture("dungeon_portal")
	hub.interact_station(&"portal")
	await _frames(12)
	var campaign: LinearCampaign = flow.active_scene as LinearCampaign
	_check(campaign != null and campaign.player.health.current_health == 115.0, "Actual portal prepares the campaign with seven-slot loadout")
	campaign.survival.director.automatic = false
	campaign.player.suspend_controls(true)
	_camera(campaign.player)
	await _capture("temple_foyer")
	campaign.enter_stage(4)
	campaign.player.relocate(Vector2(760, 640))
	await _frames(7)
	await _capture("temple_boss")
	flow.queue_free()
	await _frames(6)
	await audio.shutdown()
	print("PROLOGUE GPU PREVIEW: %d captures, %d failures" % [captures, failures])
	quit(0 if failures == 0 else 1)

func _spawn_item_board(hub: PrologueHub) -> void:
	for index: int in ItemArtCatalog.IDS.size():
		var id: StringName = ItemArtCatalog.IDS[index]
		var pickup := LootPickup.new()
		pickup.player = hub.player
		pickup.inventory = hub.gear.inventory
		pickup.automatic = false
		pickup.position = Vector2(1435 + index * 27, 618)
		pickup.floor_y = 640
		pickup.launch_velocity = Vector2.ZERO
		if index < 4:
			pickup.kind = &"material"
			pickup.item_id = id
		elif index >= 9:
			pickup.kind = &"consumable"
			pickup.item_id = id
		else:
			var definition: EquipmentData = GearInventory.COMMON_SWORD
			if id == &"broken_top": definition = GearInventory.STARTER_CLOTHING[0]
			if id == &"broken_gloves": definition = GearInventory.STARTER_CLOTHING[3]
			var item := GearItem.new()
			item.kind = EquipmentData.SLOT_KINDS[definition.slot_type]
			item.equipment_definition = definition
			item.definition_id = definition.id
			item.broken = true
			pickup.runtime_item = item
			pickup.kind = item.kind
		hub.yard.add_child(pickup)
		# The board illustrates each approved icon; live snapshots are tested separately.
		await _frames(2)
		var skin: LootVisualSkin = pickup.get_node("LootVisualSkin") as LootVisualSkin
		skin.sprite.texture = ItemArtCatalog.icon(id)

func _camera(player: Player) -> void:
	var camera: PlayerCamera = player.get_node("Camera2D") as PlayerCamera
	camera.follow_enabled = false
	camera.position = Vector2(0, -120)
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	camera.force_update_scroll()

func _pointer(player: Player, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = player.get_canvas_transform() * position
	Input.parse_input_event(event)

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

func _frames(amount: int) -> void:
	for index: int in amount: await process_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image.save_png(ProjectSettings.globalize_path("res://docs/verification/prologue_" + label + ".png")) == OK, "Capture " + label)
	captures += 1

func _check(condition: bool, message: String) -> void:
	if not condition: failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", message])

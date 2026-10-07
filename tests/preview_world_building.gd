extends SceneTree
## Actual rendered main scene and mouse menus; private save/material fixtures only.
var flow: GameFlow
var failures: int = 0
var captures: int = 0
var capture_labels: Array[String] = []

func _initialize() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	call_deferred("_run")

func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	if DisplayServer.get_name() == "headless":
		print("FAIL: World preview requires real GPU rendering")
		await audio.shutdown(); quit(1); return
	var profile := SanctuaryProfile.new()
	profile.save_path = "user://verification/world_preview_private.json"
	profile.coins = 5000
	profile.souls = 500
	for id: StringName in MaterialCatalog.IDS:
		profile.material_stash[id] = 50 if id != &"origin_divine_stone" else 0
	profile.learned_blueprints.assign([&"world_axe", &"world_fan"])
	_check(profile.save(), "Private preview save is isolated from the player's profile")
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = profile.save_path
	root.add_child(flow); current_scene = flow
	await _frames(12)
	var hub: PrologueHub = flow.active_scene as PrologueHub
	_check(hub.world_building_enabled and hub.npcs.size() == 3, "Actual configured main scene enables three approved NPCs")
	_camera(hub.player)
	hub.player.relocate(Vector2(1910, 640))
	await _frames(8)
	await _capture("base_npcs")
	hub.player.relocate(hub.stations[NpcCatalog.SMITH].global_position)
	await _key(KEY_E)
	hub.dialogue.advance()
	await _capture("smith_dialogue")
	await _choice(hub, &"smith_stones")
	await _mouse(hub.station_content.get_node("CombineStone_1") as Button, hub.station_scroll)
	_check(hub.profile.material_stash[&"enhancement_stone_1"] == 45 and hub.profile.material_stash[&"enhancement_stone_2"] == 51, "Actual mouse stone exchange applies5:1")
	await _capture("stone_exchange")
	hub.close_station()
	hub.open_npc(NpcCatalog.SMITH); hub.dialogue.advance()
	await _choice(hub, &"smith_enhance")
	var uid: int = hub.gear.inventory.equipped_weapon_uid
	await _mouse(hub.station_content.get_node("EnhanceWeapon_%d" % uid) as Button, hub.station_scroll)
	_check(hub.gear.inventory.items[uid].enhancement_level == 1 and hub.gear.inventory.items[uid].quality == GearItem.Quality.COMMON, "Mouse enhancement changes+level while preserving rarity")
	await _capture("weapon_enhancement")
	hub.close_station()
	hub.open_npc(NpcCatalog.SMITH); hub.dialogue.advance()
	await _choice(hub, &"smith_forge")
	await _mouse(hub.station_content.get_node("ForgeButton_world_axe_very_rare") as Button, hub.station_scroll)
	_check(hub.gear.inventory.items.values().any(func(item: GearItem) -> bool: return item.definition_id == &"world_axe" and item.quality == 2), "Mouse forge creates a real VeryRare axe from learned blueprint and materials")
	_check(not hub.economy.quote_forge(&"world_axe_legendary")["can_forge"] and not hub.economy.quote_forge(&"world_axe_divine")["can_forge"], "No legitimate current source for DivineStone keeps Legendary/Divine forging unavailable")
	await _capture("forging")
	hub.close_station()
	hub.player.relocate(hub.stations[NpcCatalog.HEALER].global_position)
	await _key(KEY_E); hub.dialogue.advance()
	await _capture("healer_dialogue")
	await _choice(hub, &"healer_consumables")
	var bandages: int = hub.gear.inventory.consumables[&"bandage"]
	await _mouse(hub.station_content.get_node("CraftConsumable_bandage") as Button, hub.station_scroll)
	_check(hub.gear.inventory.consumables[&"bandage"] == bandages + 1, "Mouse crafts a bandage into the owned consumable ledger")
	await _capture("survival_crafting")
	hub.close_station()
	hub.player.relocate(hub.stations[NpcCatalog.WANDERER].global_position)
	await _key(KEY_E); hub.dialogue.advance()
	await _capture("wanderer_bounty")
	await _choice(hub, &"bounty_accept")
	_check(hub.profile.bounty_accepted, "Mouse accepts the persistent Golem bounty")
	hub.dialogue.close()
	hub.player.relocate(hub.stations[&"merchant"].global_position)
	hub.open_station(&"merchant")
	await _frames(5)
	var coins_before: int = hub.profile.coins
	var starter_quote: Dictionary = hub.economy.quote_buy(&"common_sword", GearItem.Quality.COMMON)
	var items_before: int = hub.gear.inventory.items.size()
	await _mouse(hub.station_content.get_node_or_null("BuyWeapon_common_sword_0") as Button, hub.station_scroll)
	_check(starter_quote["can_buy"] and hub.profile.coins == coins_before - int(starter_quote["coin_cost"]) and hub.gear.inventory.items.size() == items_before + 1, "Actual merchant mouse purchase buys one basic Common sword at its quoted cost")
	await _capture("kael_basic_shop")
	hub.close_station()
	hub.player.relocate(Vector2(530, 640))
	for id: StringName in WeaponVariantCatalog.IDS:
		var item: GearItem = hub.gear.inventory.add_equipment(WeaponVariantCatalog.equipment_for(id), GearItem.Quality.COMMON)
		hub.gear.inventory.equip_equipment(item.uid)
		hub.player.controls_enabled = false
		_pointer(hub.player, Vector2(620, 612))
		hub.player.aim.sample_cursor()
		hub.player.action_state_machine.transition_to(&"attack")
		for frame: int in 80:
			await physics_frame; await process_frame
			if hub.player.equipped_weapon.phase == Weapon.Phase.ACTIVE: break
		await _capture(String(id) + "_common")
		hub.player.action_state_machine.transition_to(&"ready")
		hub.player.equipped_weapon.cancel_combo()
		hub.executor.clear_entities()
		hub.gear.inventory.unequip_equipment(EquipmentData.SlotType.WEAPON)
		hub.gear.inventory.items.erase(item.uid)
		hub.gear.inventory.changed.emit()
	hub.player.controls_enabled = true
	hub.player.relocate(hub.stations[&"portal"].global_position)
	_check(hub.interact_station(&"portal"), "Actual portal starts WorldCampaign")
	await _frames(12)
	var campaign: WorldCampaign = flow.active_scene as WorldCampaign
	_check(campaign != null, "Configured campaign scene uses the mixed monster roster")
	campaign.survival.set_enabled(false)
	campaign.feedback.hit_stop_seconds = 0
	campaign.player.controls_enabled = false
	campaign.player.health.maximum_health = 100000
	campaign.player.health.current_health = 100000
	campaign.player.relocate(Vector2(760, 640))
	_camera(campaign.player)
	await _frames(20)
	await _capture("mixed_foyer")
	campaign.enter_stage(2)
	campaign.player.relocate(Vector2(650, 640))
	await _frames(7)
	campaign.gear.loot.chest_drop(Vector2(760, 640))
	await _frames(10)
	await _capture("hidden_chest_multiple_loot")
	campaign.enter_stage(3)
	campaign.player.relocate(Vector2(710, 640))
	await _frames(10)
	await _capture("wraith_shield_champion")
	for id: StringName in WorldCampaign.MONSTERS:
		# One enemy isolated for close examination; actual AI owns its windup.
		for enemy: Node in get_nodes_in_group(&"enemies"):
			if campaign.room.is_ancestor_of(enemy):
				enemy.ai_enabled = false
				enemy.hide()
		var specimen: BaseEnemy = WorldCampaign.MONSTERS[id].instantiate() as BaseEnemy
		specimen.player = campaign.player
		specimen.combat_feedback = campaign.feedback
		specimen.position = Vector2(790, 510 if id == &"bloodwing_bat" else 615 if id == &"sword_wraith" else 640)
		campaign.room.add_child(specimen)
		for frame: int in 180:
			await physics_frame; await process_frame
			if specimen.state_machine.get_state_id() == &"telegraph": break
		await _capture(String(id) + "_telegraph")
		for frame: int in 80:
			await physics_frame; await process_frame
			if specimen.state_machine.get_state_id() == &"attack": break
		await _frames(3)
		await _capture(String(id) + "_attack")
		_check(specimen.attacks_started > 0, "Actual %s AI enters its distinctive attack" % id)
		specimen.queue_free()
		await _frames(4)
	campaign.enter_stage(4)
	campaign.player.relocate(Vector2(760, 640))
	await _frames(10)
	await _capture("boss_arena")
	flow.queue_free()
	await _frames(8)
	_check(get_nodes_in_group(&"world_enemy_hazards").is_empty() and get_nodes_in_group(&"spell_entities").is_empty(), "Preview teardown releases hazards and projectiles")
	var report: Dictionary = {"captures": captures, "failures": failures, "labels": capture_labels, "save": "user://verification/world_preview_private.json", "limits": "Private finite GPU fixture with supplied currency/materials/blueprints and held HP; no origin_divine_stone supplied and no alteration to player save. Captures inspect approved static sprites with procedural motion, not new per-frame art sheets."}
	var file: FileAccess = FileAccess.open("res://docs/verification/world_gpu_preview.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	await audio.shutdown()
	print("WORLD GPU PREVIEW: %d captures, %d failures" % [captures, failures])
	quit(0 if failures == 0 else 1)

func _choice(hub: PrologueHub, id: StringName) -> void:
	await _frames(3)
	await _mouse(hub.dialogue.choice_list.get_node("Choice_" + String(id)) as Button, hub.dialogue.body_scroll)

func _mouse(button: Button, scroll: ScrollContainer) -> void:
	if not is_instance_valid(button) or not is_instance_valid(scroll) or not scroll.is_ancestor_of(button):
		_check(false, "Expected visible menu button is missing from its ScrollContainer")
		return
	scroll.ensure_control_visible(button)
	await _frames(3)
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await _frames(1)
	event = event.duplicate(); event.pressed = false
	root.push_input(event, true)
	await _frames(4)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code; event.keycode = code; event.pressed = true
	root.push_input(event, true)
	await _frames(1)
	event = event.duplicate(); event.pressed = false
	root.push_input(event, true)
	await _frames(3)

func _pointer(player: Player, target: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = player.get_canvas_transform() * target
	root.push_input(event, true)

func _camera(player: Player) -> void:
	var camera: PlayerCamera = player.get_node("Camera2D") as PlayerCamera
	camera.follow_enabled = false; camera.position = Vector2(0, -120)
	camera.position_smoothing_enabled = false; camera.reset_smoothing(); camera.force_update_scroll()

func _frames(amount: int) -> void:
	for frame: int in amount: await process_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/verification/world_" + label + ".png")) == OK, "Capture " + label)
	captures += 1; capture_labels.append(label)

func _check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)

extends SceneTree

var checks: int = 0
var failures: int = 0
var upgrades_requested: Array[StringName] = []
var bounties_requested: Array[StringName] = []
var smith_requests: int = 0
var attacks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--physics-hz="): Engine.physics_ticks_per_second = int(argument.get_slice("=", 1))
		elif argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.get_slice("=", 1))
	print("NPC DIALOGUE TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	var flow: GameFlow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.set("world_building_enabled", true)
	flow.save_path_override = "user://verification/npc_dialogue_%d.json" % Engine.physics_ticks_per_second
	var fixture := SanctuaryProfile.new()
	fixture.save_path = flow.save_path_override
	fixture.save()
	root.add_child(flow)
	await _step(8)
	var hub: PrologueHub = flow.active_scene as PrologueHub
	var box: DialogueBox = hub.dialogue
	hub.permanent_upgrade_requested.connect(func(id: StringName, _hub: PrologueHub) -> void: upgrades_requested.append(id))
	hub.bounty_requested.connect(func(id: StringName, _hub: PrologueHub) -> void: bounties_requested.append(id))
	hub.smith_requested.connect(func(_hub: PrologueHub) -> void: smith_requests += 1)
	hub.player.equipped_weapon.attack_committed.connect(func(_snapshot: AttackSnapshot) -> void: attacks += 1)
	_check(hub.world_building_enabled and hub.npcs.size() == 3, "Opt-in Hub has three NPCs without replacing old stations")
	_check(hub.stations.has(&"blacksmith") and hub.stations.has(&"house") and hub.stations.has(&"portal"), "Old forge, home and portal interaction anchors remain intact")
	for id: StringName in hub.npcs:
		var npc: HubNpc = hub.npcs[id]
		var bounds: Rect2i = npc.alpha_geometry.get("bounds", Rect2i())
		_check(npc.body != null and npc.body.texture is AtlasTexture and is_equal_approx(bounds.size.y * npc.body.scale.x, 60.0), "Approved %s silhouette scales its alpha body to60px" % NpcCatalog.NAMES[id])
		_check(EnemySpriteArt.foot_world(npc.body, npc.alpha_geometry["foot_pixel"]).distance_to(npc.global_position) < 0.001, "%s alpha feet meet its unchanged world anchor" % NpcCatalog.NAMES[id])
	_check(hub.npcs[NpcCatalog.SMITH].find_children("*", "PointLight2D", true, false).is_empty(), "Starter NPC artwork adds no aura or collision lighting system")
	var floor: StaticBody2D = hub.yard.get_node("YardFloor") as StaticBody2D
	var floor_shape: Shape2D = (floor.get_child(0) as CollisionShape2D).shape
	hub.player.relocate(hub.stations[NpcCatalog.SMITH].global_position)
	await _key(KEY_E)
	_check(box.is_open and box.speaker_label.text == "Thiết Lão" and box.text_label.text == NpcCatalog.dialogue(NpcCatalog.SMITH)[0], "Actual E starts the approved Vietnamese smith dialogue")
	_check(box.portrait.visible and box.portrait.texture is AtlasTexture and box.portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Dialogue shows an approved alpha portrait crop without distorting its aspect ratio")
	_check(box.is_typing() and box.text_label.visible_characters < box.text_label.text.length(), "Dialogue begins with a real partial typewriter reveal")
	_check(not hub.player.controls_enabled and is_equal_approx(Engine.time_scale, 0.1) and not (hub.gear.modal as InventoryScreen).open_button.visible, "Conversation owns one movement/modal/time lock")
	_check(not hub.enter_house() and not hub.interact_station(&"portal"), "Dialogue cannot enter a home or start a run behind its modal")
	var y_before: float = hub.player.global_position.y
	await _key(KEY_J)
	await _mouse(MOUSE_BUTTON_LEFT, Vector2(3, 3))
	await _key(KEY_I)
	_check(attacks == 0 and not hub.player.equipped_weapon.hitbox.active and hub.executor.spawned_projectiles == 0, "Keyboard and mouse attack/cast do not pass behind dialogue")
	await _key(KEY_SPACE)
	_check(not box.is_typing() and box.text_label.visible_characters == box.text_label.text.length(), "Actual Space reveals the entire page")
	_check(hub.player.global_position.y >= y_before - 0.01 and hub.player.locomotion_state_machine.get_state_id() != &"jump", "Space advances dialogue without jumping the Player")
	_check(box.choice_list.visible and box.choice_list.get_child_count() == 5, "Revealed smith dialogue exposes repairs, recipes, enhancement, stones and goodbye choices")
	await _step(3)
	for item: Control in [box.panel, box.body_scroll, box.speaker_label, box.text_label, box.choice_list, box.close_button, box.hint, box.portrait]:
		print("NPC UI DIAGNOSTIC: %s size=%s min=%s" % [item.name, item.size, item.get_combined_minimum_size()])
	_check(root.get_visible_rect().encloses(box.panel.get_global_rect()) and root.get_visible_rect().encloses(box.close_button.get_global_rect()), "Fully revealed portrait dialogue and five choices keep the close footer inside the viewport")
	_select(box, &"smith_repair")
	await _step(3)
	_check(not box.is_open and hub.station_open and hub.current_station == &"blacksmith" and smith_requests == 1, "Real smith choice opens the existing material-backed repair menu")
	_check(not hub.player.controls_enabled and is_equal_approx(Engine.time_scale, 0.1), "Switching dialogue to repair preserves a single input/time owner")
	await _key(KEY_TAB)
	_check(not hub.station_open and not hub.gear.modal.is_open and hub.player.controls_enabled and is_equal_approx(Engine.time_scale, 1.0), "Actual Tab closes repair without opening a second inventory modal")
	var profile: SanctuaryProfile = hub.profile
	profile.souls = 2000
	# Reset only this suite's persistent fixture to make repeated verification safe.
	profile.permanent_upgrades = WorldProgressionCatalog.empty_upgrades()
	profile.bounty_accepted = false
	profile.bounty_claimed = false
	profile.bounty_start_proofs = 0
	profile.boss_proofs[&"golem"] = 0
	profile.boss_receipts.clear()
	profile.save()
	profile.changed.emit()
	hub.player.relocate(hub.stations[NpcCatalog.HEALER].global_position)
	await _key(KEY_E)
	_check(box.speaker_label.text == "Thanh Vy" and box.text_label.text == NpcCatalog.dialogue(NpcCatalog.HEALER)[0], "Healer uses the user's Vietnamese purification dialogue")
	await _key(KEY_E)
	_check(not box.is_typing() and box.choice_list.get_child_count() == 6 and box.choice_list.has_node("Choice_courier_open"), "E reveals three permanent services, consumables, the optional courier entry and goodbye")
	_check((box.choice_list.get_node("Choice_upgrade_max_hp") as Button).text.contains("+0 → +10 HP"), "Upgrade choice renders the quoted benefit and cost as Vietnamese text")
	var hp_quote: Dictionary = hub.economy.call(&"quote_upgrade", &"max_hp")
	var souls_before: int = profile.souls
	var maximum_before: float = hub.player.health.maximum_health
	var health_before: float = hub.player.health.current_health
	_select(box, &"upgrade_max_hp")
	await _step(3)
	var hp_after: Dictionary = hub.economy.call(&"quote_upgrade", &"max_hp")
	_check(upgrades_requested == [&"max_hp"] and hp_after["level"] == hp_quote["level"] + 1 and profile.souls == souls_before - hp_quote["cost"], "Mouse service choice delegates one atomic Soul purchase to EconomySession")
	_check(is_equal_approx(hub.player.health.maximum_health, maximum_before + 10.0) and is_equal_approx(hub.player.health.current_health, health_before), "Bought permanent HP updates the real Player capacity without giving free healing")
	_check(box.is_open and box.speaker_label.text == "Thanh Vy" and box.pages.size() == 2, "Successful service keeps a Vietnamese confirmation conversation")
	box.advance()
	box.advance()
	box.advance()
	_check(box.text_label.text.contains("Tịnh hóa hoàn tất"), "Confirmation describes permanent progress without inventing a damage bonus")
	var loaded := SanctuaryProfile.new()
	loaded.save_path = profile.save_path
	loaded.load_profile()
	var economy := EconomySession.new()
	economy.initialize(loaded, hub.gear.inventory)
	_check((economy.call(&"quote_upgrade", &"max_hp") as Dictionary)["level"] == hp_after["level"] and loaded.souls == profile.souls, "NPC purchase round-trips its level and Soul cost through the real save")
	box.close()
	await _step(2)
	var regeneration_before: float = hub.player.energy.regeneration
	hub.open_npc(NpcCatalog.HEALER)
	box.advance()
	_select(box, &"upgrade_mana_regen")
	await _step(2)
	_check(is_equal_approx(hub.player.energy.regeneration, regeneration_before + 2.0) and hub.economy.quote_upgrade(&"mana_regen")["level"] == 1, "Real regeneration service applies its permanent bonus to the Player energy pool")
	box.close()
	var capacity_before: int = hub.gear.inventory.catalyst_capacity
	hub.open_npc(NpcCatalog.HEALER)
	box.advance()
	_select(box, &"upgrade_rune_capacity")
	await _step(2)
	_check(hub.gear.inventory.catalyst_capacity == capacity_before + 1 and hub.player.resonance_controller.catalyst_a.runtime_state.opened_slots == capacity_before + 1, "Actual rune service opens the same extra slot in inventory and spell runtime")
	_check(hub.gear.modal.slots[GearInventory.CATALYST_INDICES[3]].visible, "Rune modal exposes the purchased fourth Catalyst slot immediately")
	box.close()
	profile.coins = 2000
	for material: StringName in MaterialCatalog.IDS:
		if MaterialCatalog.material_policy(material)["ordinary_transfer"]: profile.material_stash[material] = 100
	profile.material_stash[&"origin_divine_stone"] = 0
	profile.learn_blueprint(&"world_saber")
	var weapon_uid: int = hub.gear.inventory.equipped_weapon_uid
	var weapon: GearItem = hub.gear.inventory.items[weapon_uid]
	var old_quality: int = weapon.quality
	var old_level: int = weapon.enhancement_level
	var enhancement_quote: Dictionary = hub.economy.quote_enhance(weapon_uid)
	var coin_before: int = profile.coins
	hub.open_npc(NpcCatalog.SMITH)
	box.advance()
	_select(box, &"smith_enhance")
	await _step(2)
	_check(hub.current_station == &"smith_enhance" and hub.station_content.get_node_or_null("EnhanceWeapon_%d" % weapon_uid) is Button, "Smith dialogue opens a real UID-addressed enhancement control")
	(hub.station_content.get_node("EnhanceWeapon_%d" % weapon_uid) as Button).pressed.emit()
	await _step(2)
	_check(weapon.enhancement_level == old_level + 1 and weapon.quality == old_quality and hub.gear.inventory.items[weapon_uid] == weapon and profile.coins == coin_before - enhancement_quote["coin_cost"], "Actual enhancement button commits one guaranteed level without rarity/UID replacement")
	_check(hub.station_notice.contains("thành công") and not hub.station_notice.contains("50%"), "Guaranteed enhancement feedback does not reuse the Divine gamble label")
	hub.close_station()
	var stones_before: int = profile.material_stash[&"enhancement_stone_1"]
	var stones_after_before: int = profile.material_stash[&"enhancement_stone_2"]
	hub.open_npc(NpcCatalog.SMITH)
	box.advance()
	_select(box, &"smith_stones")
	await _step(2)
	(hub.station_content.get_node("CombineStone_1") as Button).pressed.emit()
	await _step(2)
	_check(profile.material_stash[&"enhancement_stone_1"] == stones_before - 5 and profile.material_stash[&"enhancement_stone_2"] == stones_after_before + 1, "Actual stone control consumes five source stones and creates one next-grade stone")
	hub.close_station()
	hub.open_npc(NpcCatalog.SMITH)
	box.advance()
	_select(box, &"smith_forge")
	await _step(2)
	_check(hub.station_content.get_node_or_null("ForgeButton_world_saber_very_rare") is Button and not (hub.station_content.get_node("ForgeButton_world_saber_very_rare") as Button).disabled, "Learned family blueprint exposes its actual VeryRare forge control")
	_check((hub.station_content.get_node("ForgeButton_world_saber_legendary") as Button).disabled and (hub.station_content.get_node("ForgeButton_world_saber_divine") as Button).disabled, "Legendary/Divine stay unavailable without future special-boss Origin Godstone")
	var item_count: int = hub.gear.inventory.items.size()
	(hub.station_content.get_node("ForgeButton_world_saber_very_rare") as Button).pressed.emit()
	await _step(2)
	var forged: GearItem
	for item: GearItem in hub.gear.inventory.items.values():
		if item.definition_id == &"world_saber" and item.source == &"crafted": forged = item
	_check(forged != null and forged.quality == GearItem.Quality.VERY_RARE and forged.can_equip() and hub.gear.inventory.items.size() == item_count + 1, "Actual forge creates usable crafted high-tier gear, distinct from locked drop blanks")
	hub.close_station()
	hub.open_station(&"merchant")
	await _step(2)
	var starter_quote: Dictionary = hub.economy.quote_buy(&"common_sword", GearItem.Quality.COMMON)
	var starter_button: Button = hub.station_content.get_node_or_null("BuyWeapon_common_sword_0") as Button
	_check(starter_button != null and not starter_button.disabled and starter_quote["can_buy"], "Kael's starter sword resource key exposes an enabled Common purchase despite its ancient_sword gear ID")
	coin_before = profile.coins
	item_count = hub.gear.inventory.items.size()
	if starter_button != null:
		hub.station_scroll.ensure_control_visible(starter_button)
		await _step(3)
		await _mouse(MOUSE_BUTTON_LEFT, starter_button.get_global_rect().get_center())
	_check(hub.gear.inventory.items.size() == item_count + 1 and profile.coins == coin_before - int(starter_quote["coin_cost"]) and hub.gear.inventory.items.values().any(func(item: GearItem) -> bool: return item.definition_id == GearInventory.COMMON_SWORD.id and item.quality == GearItem.Quality.COMMON and item.source == &"merchant"), "Actual Kael mouse purchase commits one Common starter sword and its quoted price")
	_check(hub.station_content.get_node_or_null("BuyWeapon_world_saber_0") is Button and hub.station_content.get_node_or_null("BuyWeapon_world_saber_1") is Button and hub.station_content.get_node_or_null("BuyWeapon_world_saber_2") == null, "Kael offers learned Common/Rare family tiers while higher grades stay at the smith")
	coin_before = profile.coins
	item_count = hub.gear.inventory.items.size()
	(hub.station_content.get_node("BuyWeapon_world_saber_1") as Button).pressed.emit()
	await _step(2)
	_check(hub.gear.inventory.items.size() == item_count + 1 and profile.coins == coin_before - 40, "Actual Kael purchase commits one Rare UID and its quoted price")
	hub.close_station()
	hub.open_npc(NpcCatalog.HEALER)
	box.advance()
	_select(box, &"healer_consumables")
	await _step(2)
	var potions_before: int = hub.gear.inventory.consumables[&"potion"]
	var current_health: float = hub.player.health.current_health
	coin_before = profile.coins
	(hub.station_content.get_node("BuyConsumable_potion") as Button).pressed.emit()
	await _step(2)
	_check(hub.gear.inventory.consumables[&"potion"] == potions_before + 1 and profile.coins == coin_before - 10 and hub.player.health.current_health == current_health, "Actual healer purchase stores one potion without immediately healing")
	var linen_before: int = profile.material_stash[&"linen_fiber"]
	var bandages_before: int = hub.gear.inventory.consumables[&"bandage"]
	(hub.station_content.get_node("CraftConsumable_bandage") as Button).pressed.emit()
	await _step(2)
	_check(profile.material_stash[&"linen_fiber"] == linen_before - 2 and hub.gear.inventory.consumables[&"bandage"] == bandages_before + 1, "Actual craft control consumes only the quoted stash ingredients")
	hub.close_station()
	hub.player.relocate(hub.stations[NpcCatalog.WANDERER].global_position)
	await _key(KEY_E)
	_check(box.text_label.text == NpcCatalog.dialogue(NpcCatalog.WANDERER)[0], "Wanderer names floor4, Golem and its sigil core in the approved dialogue")
	await _key(KEY_SPACE)
	_select(box, &"bounty_accept")
	await _step(2)
	var accepted: Dictionary = hub.economy.call(&"quote_bounty", &"golem_hunt")
	_check(accepted["accepted"] and not accepted["can_accept"] and not accepted["can_claim"] and bounties_requested == [&"golem_hunt"], "NPC accepts the single Golem bounty once and cannot claim it early")
	box.close()
	# The production proof recorder is exercised before the actual claim button.
	profile.record_boss_defeat("npc_test_receipt", &"golem")
	hub.open_npc(NpcCatalog.WANDERER)
	box.advance()
	_select(box, &"bounty_claim")
	await _step(2)
	var claimed: Dictionary = hub.economy.call(&"quote_bounty", &"golem_hunt")
	_check(claimed["claimed"] and not claimed["can_claim"] and claimed["reward_combo_id"] == WorldProgressionCatalog.BOUNTY_REWARD, "Actual claim unlocks only the authored combo reward and refuses a second claim")
	_check(bounties_requested.size() == 2 and profile.bounty_claimed, "Bounty hook and persistent claim ledger update exactly once")
	var reward: GearItem
	for item: GearItem in hub.gear.inventory.items.values():
		if item.definition_id == WorldProgressionCatalog.BOUNTY_REWARD: reward = item
	_check(reward != null and reward.can_equip() and reward.equipment_definition.moveset.combo_steps.size() == 4, "Claim places a usable four-hit combo reward in the actual inventory")
	box.close()
	loaded.load_profile()
	_check((economy.call(&"quote_bounty", &"golem_hunt") as Dictionary)["claimed"], "Bounty completion remains claimed after save reload")
	hub.open_npc(NpcCatalog.SMITH)
	await _step(2)
	var old_window: Vector2i = root.size
	var old_scale: Vector2i = root.content_scale_size
	root.size = Vector2i(720, 480)
	root.content_scale_size = Vector2i(720, 480)
	await _step(4)
	box.advance()
	await _step(4)
	var viewport_bounds: Rect2 = root.get_visible_rect()
	_check(viewport_bounds.encloses(box.panel.get_global_rect()) and viewport_bounds.encloses(box.close_button.get_global_rect()), "Dialogue and persistent mouse close fit a real720×480 viewport")
	await _mouse(MOUSE_BUTTON_LEFT, box.close_button.get_global_rect().get_center())
	_check(not box.is_open and hub.player.controls_enabled and is_equal_approx(Engine.time_scale, 1.0) and attacks == 0, "Actual mouse close restores control/time without firing a world attack")
	root.size = old_window
	root.content_scale_size = old_scale
	await _step(4)
	await _verify_layout_matrix(hub)
	var pages: Array[String] = ["Trang đầu.", "Trang sau: lời nhắn tiếng Việt."]
	hub.open_npc(NpcCatalog.HEALER)
	box.open("Thanh Vy", pages)
	await _key(KEY_E)
	_check(box.page_index == 0 and not box.is_typing(), "First E completes a page without skipping it")
	await _key(KEY_E)
	_check(box.page_index == 1 and box.is_typing(), "Second E moves to the next page and starts a fresh typewriter")
	await _key(KEY_E)
	await _key(KEY_E)
	_check(not box.is_open and hub.player.controls_enabled, "The final page without choices closes with E")
	_check((floor.get_child(0) as CollisionShape2D).shape == floor_shape, "NPC conversations/services leave the Hub terrain resource unchanged")
	var han := RegEx.new()
	han.compile("[\\p{Han}]")
	var no_han: bool = true
	for id: StringName in NpcCatalog.NAMES:
		no_han = no_han and han.search(NpcCatalog.NAMES[id]) == null
		for line: String in NpcCatalog.dialogue(id): no_han = no_han and han.search(line) == null
	_check(no_han, "Displayed NPC names and dialogue contain no readable Han text")
	hub.open_npc(NpcCatalog.SMITH)
	flow.queue_free()
	await _step(8)
	_check(is_equal_approx(Engine.time_scale, 1.0) and get_nodes_in_group(&"spell_entities").is_empty(), "Teardown during open dialogue releases its time/input owner and spells")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _verify_layout_matrix(hub: PrologueHub) -> void:
	var old_window: Vector2i = root.size
	var old_scale: Vector2i = root.content_scale_size
	var box: DialogueBox = hub.dialogue
	for extent: Vector2i in [Vector2i(1152, 648), Vector2i(720, 480)]:
		root.size = extent
		root.content_scale_size = extent
		await _step(4)
		for id: StringName in [NpcCatalog.SMITH, NpcCatalog.HEALER, NpcCatalog.WANDERER]:
			hub.open_npc(id)
			await _step(2)
			box.advance()
			await _step(4)
			var bounds: Rect2 = root.get_visible_rect()
			_check(box.choice_list.visible and not box.is_typing() and bounds.encloses(box.panel.get_global_rect()) and bounds.encloses(box.close_button.get_global_rect()) and bounds.encloses(box.hint.get_global_rect()) and bounds.encloses(box.portrait.get_global_rect()), "Revealed %s portrait/services keep the panel and footer inside %s" % [NpcCatalog.NAMES[id], extent])
			var goodbye: Button = box.choice_list.get_node("Choice_goodbye") as Button
			box.body_scroll.ensure_control_visible(goodbye)
			await _step(3)
			var reachable: bool = box.body_scroll.get_global_rect().encloses(goodbye.get_global_rect())
			await _mouse(MOUSE_BUTTON_LEFT, goodbye.get_global_rect().get_center())
			_check(reachable and not box.is_open and hub.player.controls_enabled and is_equal_approx(Engine.time_scale, 1.0) and attacks == 0, "Scrolled %s goodbye accepts real mouse input and releases the modal at %s" % [NpcCatalog.NAMES[id], extent])
			box.close()
	root.size = old_window
	root.content_scale_size = old_scale
	await _step(4)

func _select(box: DialogueBox, id: StringName) -> void:
	for index: int in box.choices.size():
		if StringName(box.choices[index].get("id", "")) == id:
			(box.choice_list.get_child(index) as Button).pressed.emit()
			return

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _step(2)
	event.pressed = false
	Input.parse_input_event(event)
	await _step(2)

func _mouse(button: int, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	# Control rectangles use viewport coordinates even when the window is scaled.
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.pressed = true
	root.push_input(event, true)
	await _step(2)
	event.pressed = false
	root.push_input(event, true)
	await _step(2)

func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

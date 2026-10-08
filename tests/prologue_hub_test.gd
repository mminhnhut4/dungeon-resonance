extends SceneTree
## Product integration: safe combat, mouse inventory, home, material custody and
## Hub -> prepared campaign -> defeat/victory. No neutral-equipment fixture.

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	var flow: GameFlow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.qa_tools_enabled = true
	# Exercise the prior Prologue contract; the new NPC suite uses World mode.
	flow.world_building_enabled = false
	flow.campaign_scene = null
	flow.save_path_override = "user://verification/prologue_hub_%d.json" % Engine.physics_ticks_per_second
	root.add_child(flow)
	current_scene = flow
	await _step(15)
	var hub: PrologueHub = flow.active_scene as PrologueHub
	hub.feedback.hit_stop_seconds = 0.0
	flow.profile.coins = 0
	flow.profile.souls = 0
	flow.profile.material_stash = MaterialCatalog.empty_counts()
	flow.profile.save()
	_check(hub != null and flow.hub_scene != null, "Opt-in main scene boots the interactive Prologue Hub")
	_check(hub.gear.inventory.equipment_uids.size() == 7 and hub.gear.inventory.equipment_uids.all(func(uid: int) -> bool: return uid > 0), "Hub starts with seven real equipped slots")
	_check(hub.player.health.current_health == 115.0 and hub.player.hurtbox.damage_resolver.armor_rating == 11.0, "Hub begins fully healthy with the actual confirmed starter armor")
	_check((hub.player.get_node("Visuals") as PlayerVisualRig).is_modular_active() and hub.presentation.trail != null and hub.presentation.art_hud != null, "Hub uses modular equipment, attack trail and real art HUD")
	_check(hub.player.health.minimum_health == 1.0 and not hub.training_aggression and hub.training_slime.player == null, "Safety is opt-in and the training Slime starts passive")
	var deaths: Array[int] = [0]
	hub.player.health.died.connect(func() -> void: deaths[0] += 1)
	var dealt: float = hub.player.health.apply_damage(10000.0)
	_check(dealt == 114.0 and hub.player.health.current_health == 1.0 and deaths[0] == 0, "Direct health damage stops at one HP before any death signal")
	hub.player.health.current_health = 2.0
	var burn: DamageEvent = _damage(hub.player.hurtbox, 0.25)
	burn.source_kind = DamageEvent.SourceKind.DOT
	burn.burn_damage = 50.0
	burn.burn_duration = 0.6
	burn.burn_interval = 0.1
	burn.ignore_damage_grace = true
	hub.player.hurtbox.take_internal_damage(burn)
	await _time(0.4)
	_check(hub.player.health.current_health == 1.0 and deaths[0] == 0 and hub.player.action_state_machine.get_state_id() != &"dead", "Actual burn DOT cannot kill the Hub Player or trigger Game Over")
	hub.condition.enabled = true
	hub.condition.add_stress(100.0, &"berserk")
	hub.player.equipped_weapon.swing_resolved.emit(false)
	_check(hub.player.health.current_health == 1.0 and deaths[0] == 0, "Berserk missed-swing internal penalty respects the same health floor")
	hub.condition.clear()
	hub.condition.enabled = false
	hub.player.reset_movement_at(Vector2(575, 640))
	await _step(5)
	var before_hits: int = hub.dummy.hit_count
	var mouse := InputEventMouseMotion.new()
	mouse.position = hub.player.get_canvas_transform() * (hub.dummy.global_position + Vector2(0, -16))
	Input.parse_input_event(mouse)
	await _key(KEY_J)
	await _time(0.45)
	_check(hub.dummy.hit_count > before_hits and hub.dummy.last_damage_event != null, "Actual attack input hits the dummy through the existing hitbox and DamageEvent")
	_check(hub.damage_numbers.total_spawned > 0 and hub.dummy.damage_number_spawner == hub.damage_numbers, "Confirmed Hub dummy hit uses the shared finite damage-number spawner")
	hub.set_training_aggression(true)
	_check(hub.training_slime.player == hub.player and hub.training_slime.contact_damage_enabled, "Training toggle activates the existing chase/bite FSM")
	hub.player.relocate(hub.training_slime.global_position + Vector2(15, 0))
	hub.player.hurtbox.set_invulnerable(false)
	var hp_before: float = hub.player.health.current_health
	await _time(0.35)
	_check(hub.player.health.current_health < hp_before and hub.player.health.current_health > 0.0, "Training Slime makes real gentle damage without replacing the safe health pipeline")
	hub.set_training_aggression(false)
	_check(not hub.training_slime.contact_damage_enabled and not hub.training_slime.bite_hitbox.active, "Turning practice aggression off closes contact and active bite")
	hub.player.reset_movement_at(Vector2(900, 640))
	await _step(3)
	_check(hub.claim_test_chest(), "Exact Common outfit and Rare lightning sample can be claimed")
	var owned: int = hub.gear.inventory.items.size()
	_check(not hub.claim_test_chest() and hub.gear.inventory.items.size() == owned, "Repeated chest claim cannot duplicate equipment or runes")
	_check(hub.gear.inventory.items.values().all(func(item: GearItem) -> bool: return item.quality <= GearItem.Quality.RARE), "Hub demo never unlocks advanced or Legendary/Divine equipment")
	var rare: GearItem
	for item: GearItem in hub.gear.inventory.items.values():
		if item.equipment_definition == PrologueHub.RARE_SWORD:
			rare = item
	_check(rare != null and rare.quality == GearItem.Quality.RARE, "Rare sample has its own UID and runtime rarity")
	await _key(KEY_TAB)
	var ui: InventoryScreen = hub.gear.modal as InventoryScreen
	_check(ui.is_open and is_equal_approx(Engine.time_scale, 0.1) and ui.equipment_buttons.size() == 7, "Tab opens the seven-slot preparation UI with owned slowdown")
	var index: int = ui.bag_uids.find(rare.uid)
	await _click(ui.bag_buttons[index], MOUSE_BUTTON_LEFT)
	_check(hub.gear.inventory.equipped_weapon_uid == rare.uid and hub.player.equipped_weapon.visual_quality == GearItem.Quality.RARE, "Real bag click equips Rare UID and syncs its quality")
	_check(hub.player.equipped_weapon.additional_runes.any(func(rune: RuneData) -> bool: return rune.id == &"lightning"), "Clicking Rare lightning sword adds its intrinsic rune without rewriting a shared definition")
	ui.close()
	_check(is_equal_approx(Engine.time_scale, 1.0) and hub.player.controls_enabled, "Closing inventory restores time and Player input")
	hub.player.relocate(hub.stations[&"training"].global_position)
	await _key(KEY_E)
	_check(hub.station_open and not ui.is_open and not ui.open_button.visible, "Opening an E station owns the single preparation modal")
	await _key(KEY_TAB)
	_check(not hub.station_open and not ui.is_open and is_equal_approx(Engine.time_scale, 1.0), "Actual Tab closes a station before inventory can open a second modal")
	_check(hub.gear.inventory.equip_catalyst_set([&"fire", &"wind"]), "Owned test shards prepare real Firestorm")
	hub.player.energy.reset()
	var count: int = hub.executor.spawned_projectiles
	await _key(KEY_I)
	await _time(0.4)
	_check(hub.executor.spawned_projectiles > count and hub.player.resonance_controller.cast_count > 0, "Actual spell key fires the configured projectile scene in the Hub")
	var player_id: int = hub.player.get_instance_id()
	var gear_id: int = hub.gear.inventory.get_instance_id()
	var equipment: Array[int] = hub.gear.inventory.equipment_uids.duplicate()
	hub.player.relocate(hub.stations[&"house"].global_position)
	await _key(KEY_E)
	_check(hub.inside_house and hub.house.visible and not hub.yard.visible, "E at the house enters a distinct indoor scene")
	_check(hub.player.get_instance_id() == player_id and hub.gear.inventory.get_instance_id() == gear_id and hub.gear.inventory.equipment_uids == equipment, "Entering home retains the exact Player, wardrobe and UID inventory")
	_check(hub.executor.get_child_count() == 0 and (hub.player.get_node("Camera2D") as Camera2D).limit_left == 3200, "Indoor transition clears outgoing spells and changes only camera bounds")
	hub.player.health.apply_damage(20.0)
	hub.player.relocate(hub.house.bed_point.global_position)
	await _key(KEY_E)
	_check(hub.player.health.current_health == hub.player.health.maximum_health and hub.player.energy.current == 100.0, "E at the bed genuinely rests HP and energy")
	hub.player.relocate(hub.house.exit_point.global_position)
	await _key(KEY_E)
	_check(not hub.inside_house and hub.player.get_instance_id() == player_id and hub.gear.inventory.equipment_uids == equipment, "House exit restores the yard with the same equipped character")
	hub.gear.inventory.materials[&"crystal"] = 3
	_check(hub.economy.deposit_all() and flow.profile.material_stash[&"crystal"] == 3 and hub.gear.inventory.materials[&"crystal"] == 0, "Storage uses the save-backed EconomySession transaction")
	hub.gear.inventory.materials[&"slime_essence"] = 2
	hub.economy.deposit_all()
	hub.player.relocate(hub.stations[&"merchant"].global_position)
	await _key(KEY_E)
	# ServiceItemCard retains the authored action NodePath; its accessible
	# caption now includes the whole-stash action and the material title.
	var sell_essence: Button = hub.station_content.get_node_or_null("SellMaterial_slime_essence") as Button
	_check(hub.station_open and sell_essence != null and not sell_essence.disabled, "E at Kael exposes the approved essence sale through real GUI")
	if not hub.station_open or sell_essence == null or sell_essence.disabled:
		await _abort_fixture(flow)
		return
	sell_essence.pressed.emit()
	_check(flow.profile.coins == 6 and flow.profile.material_stash[&"slime_essence"] == 0 and flow.profile.material_stash[&"crystal"] == 3, "Kael button sells only selected stored material once at its prototype price")
	hub.close_station()
	var damaged: GearItem = hub.gear.inventory.add_equipment(GearInventory.STARTER_CLOTHING[2])
	damaged.broken = true
	damaged.source = &"drop"
	damaged.loot_rolled = true
	damaged.drop_bonus = 0.04
	damaged.affix_id = &"speed"
	damaged.affix_value = 0.02
	flow.profile.material_stash[&"metal"] = 2
	flow.profile.material_stash[&"dust"] = 1
	flow.profile.save()
	hub.player.relocate(hub.stations[&"blacksmith"].global_position)
	await _key(KEY_E)
	var repair: Button
	for node: Node in hub.station_content.get_children():
		if node is Button and node.text.begins_with("Sửa "):
			repair = node
	_check(hub.station_open and repair != null and not repair.disabled, "E at the smith shows a repair quote using stored materials")
	if not hub.station_open or repair == null or repair.disabled:
		await _abort_fixture(flow)
		return
	repair.pressed.emit()
	_check(not damaged.broken and damaged.loot_rolled and damaged.drop_bonus == 0.04 and damaged.affix_value == 0.02 and flow.profile.material_stash[&"metal"] == 0 and flow.profile.material_stash[&"dust"] == 0, "Smith GUI repairs the same UID without rerolling or duplicating its saved loot state")
	hub.close_station()
	owned = hub.gear.inventory.items.size()
	rare.source = &"drop"
	rare.loot_rolled = true
	rare.drop_bonus = 0.03
	rare.affix_id = &"speed"
	rare.affix_value = 0.04
	hub.gear.inventory.materials[&"metal"] = 2
	hub.gear.inventory.consumables[&"potion"] = 3
	var original_inventory: GearInventory = hub.gear.inventory
	hub.player.relocate(hub.stations[&"portal"].global_position)
	await _key(KEY_E)
	await _step(8)
	var campaign: LinearCampaign = flow.active_scene as LinearCampaign
	campaign.survival.director.automatic = false
	for enemy: Node2D in campaign.living_enemies():
		enemy.ai_enabled = false
	_check(campaign != null and campaign.stage == 1, "E at the right portal starts campaign floor one")
	_check(campaign.gear.inventory != original_inventory and campaign.gear.inventory.items[rare.uid] != rare and campaign.gear.inventory.items[rare.uid].equipment_definition == rare.equipment_definition, "Prepared run clones mutable UID items while sharing immutable authored resources")
	_check(original_inventory.items.is_empty() and original_inventory.total_shards() == 0 and original_inventory.consumables[&"potion"] == 0 and campaign.gear.inventory.consumables[&"potion"] == 3, "Starting a run moves all carried UID gear, shards and consumables out of the Hub exactly once")
	var copied_rare: GearItem = campaign.gear.inventory.items[rare.uid]
	_check(copied_rare.source == rare.source and copied_rare.loot_rolled and copied_rare.drop_bonus == 0.03 and copied_rare.affix_id == rare.affix_id and copied_rare.affix_value == 0.04, "Hub-to-run clone retains the frozen source, bonus and affix of each UID")
	copied_rare.affix_value = 0.01
	_check(rare.affix_value == 0.04, "Changing a disposable run roll never changes the Hub-owned preparation item")
	_check(campaign.gear.inventory.equipped_weapon_uid == rare.uid and campaign.gear.inventory.slots[0] == &"fire" and campaign.gear.inventory.slots[1] == &"wind", "Prepared equipment and Catalyst slots carry into the run")
	_check(campaign.gear.inventory.materials[&"crystal"] == 0 and flow.profile.material_stash[&"crystal"] == 3 and campaign.gear.inventory.materials[&"metal"] == 2 and original_inventory.materials[&"metal"] == 0, "Stored resources stay home and carried material moves into the run only once")
	_check(campaign.player.health.minimum_health == 0.0 and campaign.gear.loot.crystal_drops_enabled and campaign.gear.loot.prologue_drops_enabled, "Dungeon damage is lethal again and its approved opt-in drops are enabled")
	campaign.player.health.apply_damage(10000.0)
	await _time(1.4)
	hub = flow.active_scene as PrologueHub
	_check(hub != null and hub.from_defeat and hub.player.health.current_health == 115.0, "Defeat returns to the selected new Hub with a healthy starter kit")
	_check(hub.gear.inventory.items.size() == 8 and not hub.claim_test_chest() and not hub.gear.inventory.items.has(rare.uid), "Death loses carried test gear; once-per-session chest stays claimed and a fresh seven-piece starter kit remains playable")
	_check(hub.gear.inventory.items[hub.gear.inventory.equipped_weapon_uid].quality == GearItem.Quality.COMMON and hub.gear.inventory.slots.all(func(id: StringName) -> bool: return id == &""), "Defeat resets worn equipment and sockets instead of keeping the dead run build")
	_check(hub.gear.inventory.materials[&"metal"] == 0 and flow.profile.material_stash[&"crystal"] == 3, "Death loses carried run materials while preserving deposited base storage")
	_check(hub.gear.inventory.consumables[&"potion"] == 0 and hub.gear.inventory.total_shards() == 0, "Death cannot restore lost consumables or shards from a stale preparation clone")
	flow.start_campaign()
	await _step(5)
	campaign = flow.active_scene as LinearCampaign
	campaign.survival.director.automatic = false
	campaign.enter_stage(4)
	await _step(3)
	var found_gear := GearItem.new()
	found_gear.uid = CombatIds.next_id()
	found_gear.kind = &"armor"
	found_gear.definition_id = GearInventory.STARTER_CLOTHING[0].id
	found_gear.equipment_definition = GearInventory.STARTER_CLOTHING[0]
	found_gear.source = &"drop"
	found_gear.broken = true
	found_gear.loot_rolled = true
	found_gear.drop_bonus = 0.05
	found_gear.affix_id = &"speed"
	found_gear.affix_value = 0.03
	var gear_pickup: LootPickup = campaign.gear.loot.spawn_gear(found_gear, campaign.player.global_position)
	_check(gear_pickup.collect() and campaign.gear.inventory.items.has(found_gear.uid), "Actual run pickup owns the frozen broken gear before victory")
	var potion_pickup: LootPickup = campaign.gear.loot.spawn(&"consumable", &"potion", campaign.player.global_position, 2)
	_check(potion_pickup.collect() and campaign.gear.inventory.consumables[&"potion"] == 2, "Run consumable pickup stores exactly its quantity in the carried ledger")
	var shard_count_before: int = campaign.gear.inventory.total_shards()
	var fire_pickup: LootPickup = campaign.gear.loot.spawn(&"rune", &"fire", campaign.player.global_position)
	_check(fire_pickup.collect() and campaign.gear.inventory.total_shards() == shard_count_before + 1, "Newly picked rune becomes one owned run UID")
	# Simulate an existing overflow ledger handed to victory: return must preserve
	# all UIDs rather than discard the twenty-first item or reroll its ownership.
	while campaign.gear.inventory.equipment_bag_uids().size() < 21:
		campaign.gear.inventory.add_item(&"weapon", &"ancient_sword")
	var won_gear_count: int = campaign.gear.inventory.items.size()
	campaign.boss.health.apply_damage(10000.0)
	await _step(4)
	campaign.gear.inventory.materials[&"metal"] = 4
	_check(campaign.portal_active and campaign.win(), "Actual Boss death enables the existing victory portal")
	await _time(2.2)
	hub = flow.active_scene as PrologueHub
	_check(hub != null and not hub.from_defeat and hub.gear.inventory.materials[&"metal"] == 4, "Victory returns to the new Hub and brings its carried materials once")
	_check(hub.gear.inventory.items.size() == won_gear_count and hub.gear.inventory.items.has(found_gear.uid) and hub.gear.inventory.consumables[&"potion"] == 2 and hub.gear.inventory.total_shards() == shard_count_before + 1, "Victory returns remainder gear, rune and consumable ownership exactly once")
	var returned: GearItem = hub.gear.inventory.items[found_gear.uid]
	_check(returned != found_gear and returned.broken and returned.loot_rolled and returned.source == &"drop" and returned.drop_bonus == 0.05 and returned.affix_value == 0.03 and returned.equipment_definition == found_gear.equipment_definition, "Won broken gear retains frozen roll while returning an independent runtime item")
	ui = hub.gear.modal as InventoryScreen
	ui.open()
	_check(ui.bag_uids.size() > 20 and ui.bag_uids.has(found_gear.uid), "Victory overflow remains visible in the owned equipment grid instead of silently disappearing")
	ui._change_page(1)
	_check(ui.page == 1 and ui.bag_buttons[0].text != "·", "Second inventory page exposes overflow equipment")
	ui.close()
	flow.profile.material_stash[&"metal"] = 2
	flow.profile.material_stash[&"dust"] = 1
	flow.profile.save()
	hub.player.relocate(hub.stations[&"blacksmith"].global_position)
	await _key(KEY_E)
	repair = null
	for node: Node in hub.station_content.get_children():
		if node is Button and node.text.begins_with("Sửa "):
			repair = node
	_check(repair != null and not repair.disabled, "Victorious carried drop reaches the real Hub smith repair UI")
	if repair == null or repair.disabled:
		await _abort_fixture(flow)
		return
	repair.pressed.emit()
	_check(not returned.broken and returned.drop_bonus == 0.05 and returned.affix_value == 0.03 and hub.gear.inventory.items.size() == won_gear_count, "Full pickup -> win -> Hub -> repair cycle preserves UID and frozen attributes without duplicates")
	hub.close_station()
	var materials: int = hub.gear.inventory.materials[&"metal"]
	flow.show_hub()
	await _step(5)
	_check((flow.active_scene as PrologueHub).gear.inventory.materials[&"metal"] == materials, "Repeated Hub navigation cannot award victory materials twice")
	_check((flow.active_scene as PrologueHub).gear.inventory.items.size() == won_gear_count and (flow.active_scene as PrologueHub).gear.inventory.consumables[&"potion"] == 2, "Repeated Hub navigation cannot duplicate won gear or consumables")
	hub = flow.active_scene as PrologueHub
	hub.open_station(&"stash")
	await _step(4)
	var viewport_extent: Vector2 = root.get_visible_rect().size
	_check(Rect2(Vector2.ZERO, viewport_extent).encloses(hub.station_panel.get_global_rect()) and hub.station_close.get_global_rect().end.y <= viewport_extent.y, "Storage panel and persistent close button fit the real default viewport")
	var old_window_size: Vector2i = root.size
	var old_scale_size: Vector2i = root.content_scale_size
	root.size = Vector2i(720, 480)
	root.content_scale_size = Vector2i(720, 480)
	for row: int in 20:
		hub._label(hub.station_content, Vector2.ZERO, "Vật liệu bổ sung kiểm bố cục · nội dung dài cần cuộn, nút đóng vẫn truy cập được.")
	await _step(6)
	viewport_extent = root.get_visible_rect().size
	_check(viewport_extent.x <= 720.0 and viewport_extent.y <= 480.0 and Rect2(Vector2.ZERO, viewport_extent).encloses(hub.station_panel.get_global_rect()), "Actual viewport resize constrains the station panel width and height")
	var scrollbar: VScrollBar = hub.station_scroll.get_v_scroll_bar()
	_check(scrollbar.max_value > scrollbar.page and hub.station_close.is_visible_in_tree() and Rect2(Vector2.ZERO, viewport_extent).encloses(hub.station_close.get_global_rect()), "Long item list scrolls inside the panel while close remains visible")
	hub.station_scroll.scroll_vertical = int(scrollbar.max_value)
	hub.station_close.pressed.emit()
	await _step(2)
	_check(not hub.station_open and is_equal_approx(Engine.time_scale, 1.0) and hub.player.controls_enabled, "Clicking the persistent close button at scroll end restores input and time")
	root.size = old_window_size
	root.content_scale_size = old_scale_size
	await _step(4)
	var objects_before: int = 0
	var resources_before: int = 0
	for cycle: int in 6:
		flow.start_campaign()
		await _step(8)
		(flow.active_scene as DungeonRun).survival.director.automatic = false
		(flow.active_scene as DungeonRun).finish(&"defeat")
		flow.show_hub(true)
		await _step(12)
		if cycle == 1:
			objects_before = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			resources_before = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var objects_after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_after: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	print("STRESS: Prologue cycles objects=%d->%d resources=%d->%d" % [objects_before, objects_after, resources_before, resources_after])
	_check(objects_after <= objects_before and resources_after <= resources_before, "Six Hub/prepared-campaign cycles retain no additional owners/resources after warm-up")
	hub = flow.active_scene as PrologueHub
	hub.open_station(&"stash")
	flow.queue_free()
	await _step(6)
	_check(is_equal_approx(Engine.time_scale, 1.0) and get_nodes_in_group(&"spell_entities").is_empty(), "Hub and campaign teardown release time claims and spell owners")
	var health := HealthComponent.new()
	root.add_child(health)
	health.apply_damage(10000.0)
	_check(health.minimum_health == 0.0 and health.current_health == 0.0, "Ordinary HealthComponent default remains lethal for all legacy actors")
	health.queue_free()
	await _step(3)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _abort_fixture(flow: GameFlow) -> void:
	# Preserve the failing assertion and release the real scene owners instead
	# of dereferencing a missing button and idling until the runner timeout.
	flow.queue_free()
	await _step(8)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1)

func _damage(target: Hurtbox, amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = 987654
	event.source_team_id = 2
	event.target_id = target.get_actor_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = amount
	return event

func _click(button: Button, code: MouseButton) -> void:
	await _step(2)
	var position: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.position = position
	click.button_index = code
	click.pressed = true
	root.push_input(click, true)
	await _step(1)
	click.pressed = false
	root.push_input(click, true)
	await _step(2)

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _step(2)
	event.pressed = false
	Input.parse_input_event(event)
	await _step(2)

func _time(seconds: float) -> void:
	await _step(ceili(seconds * Engine.physics_ticks_per_second))

func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

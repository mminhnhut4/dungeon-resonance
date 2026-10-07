extends "res://tests/survival_test_base.gd"
## Real GUI mouse dispatch, UID transactions, unarmed contacts and lifetime.

func _initialize() -> void:
	suite = "inventory_equipment"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	var inventory: GearInventory = level.gear.inventory
	var screen: InventoryScreen = level.gear.modal as InventoryScreen
	var visual: EquipmentVisual = level.gear.equipment_visual
	var original_uid: int = inventory.equipped_weapon_uid
	var physical_socket: Node2D = player.equipped_weapon.get_parent() as Node2D
	var socket_transform: Transform2D = physical_socket.transform
	var hurt_shape: Shape2D = player.hurtbox.get_node("CollisionShape2D").shape
	_check(screen != null and screen.bag_buttons.size() == 20 and screen.equipment_buttons.size() == 7, "Real inventory scene exposes 20 bag cells and seven independent equipment slots")
	_check(not screen.is_open and not screen.panel.visible and not screen.veil.visible, "Equipment modal starts closed")
	_check(GearItem.NAMES.size() == 6 and GearItem.NAMES[5] == "Thần thánh", "One ordered six-tier rarity system replaces the old tiers")
	_check(inventory.items[original_uid].quality == GearItem.Quality.COMMON, "Starting sword is Common")
	var threat: float = session.director.threat_points()
	inventory.items[original_uid].quality = GearItem.Quality.RARE
	_check(session.director.threat_points() > threat, "Rare gear increases threat above Common without changing the starter budget")
	inventory.items[original_uid].quality = GearItem.Quality.COMMON
	_check(visual.weapon_sprite.texture == GearInventory.COMMON_SWORD.world_sprite_texture and visual.weapon_sprite.visible, "Common sword is shown in the independent hand sprite")
	_check(Player.SWORD.base_damage == 10 and GearInventory.COMMON_SWORD.bonus_atk == 0, "Common sword preserves existing base damage and has no bonus stats")
	var source_hash: int = hash(GearInventory.COMMON_SWORD.get("moveset"))
	var spare: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD)
	_check(spare != null and spare.uid != original_uid, "Two swords sharing one Resource have distinct owned UIDs")
	_check(not inventory.equip_equipment(-999) and not inventory.unequip_equipment(-1), "Invalid identities/slots leave the inventory intact")
	var count: int = inventory.items.size()
	await _key(KEY_TAB)
	_check(screen.is_open and screen.veil.visible and not player.controls_enabled and is_equal_approx(Engine.time_scale, 0.1), "Tab opens the actual equipment modal and acquires 10-percent slowdown")
	_check(screen.tabs.current_tab == 0, "Equipment is the default tab")
	_check(root.get_visible_rect().encloses(screen.panel.get_global_rect()) and screen.panel.get_global_rect().encloses(screen.bag_buttons[19].get_global_rect()), "Inventory panel and last bag cell fit entirely inside the actual viewport")
	screen._show_tooltip(spare.uid)
	_check(screen.tooltip.visible and "Kiếm Sắt Lữ Hành" in screen.tooltip_name.text and "Thường" in screen.tooltip_name.text, "Hover tooltip identifies the owned Common sword")
	var hits: int = level.dummy_a.hit_count
	await _click(screen.bag_buttons[screen.bag_uids.find(spare.uid)], MOUSE_BUTTON_LEFT)
	_check(inventory.equipped_weapon_uid == spare.uid and inventory.equipment_bag_uids().has(original_uid), "Actual left click swaps owned swords and returns the previous UID to the bag")
	_check(inventory.items.size() == count and level.dummy_a.hit_count == hits and not player.equipped_weapon.hitbox.active, "GUI equipment click neither duplicates gear nor attacks the world")
	_check(visual.shown_uid == spare.uid, "Hand display updates on the equip signal without debug hotkeys")
	await _click(screen.equipment_buttons[0], MOUSE_BUTTON_RIGHT)
	_check(inventory.equipped_weapon_uid == 0 and player.equipped_weapon.definition == GearSession.UNARMED, "Right click unequips and selects the authored unarmed moveset")
	_check(not visual.weapon_sprite.visible and player.equipped_weapon.installed_rune == null, "Unarmed hides the sword and cannot borrow its weapon rune")
	await _step(8)
	_check(inventory.equipped_weapon_uid == 0 and player.equipped_weapon.definition.id == &"unarmed", "Periodic quality sync does not silently re-equip the removed sword")
	var first_free: int = screen.bag_uids.find(0)
	var rune_count: int = inventory.total_shards()
	screen.tabs.current_tab = 1
	screen.equip_selected(&"fire")
	_check(player.resonance_controller.get_recipe().id == &"fire_bolt" and inventory.total_shards() == rune_count, "Existing rune tab still installs Catalyst runes without duplicating shards")
	screen.tabs.current_tab = 0
	await _key(KEY_TAB)
	await _step(4)
	_check(not screen.is_open and player.controls_enabled and is_equal_approx(Engine.time_scale, 1.0), "Closing Tab restores movement and global time")
	level.gear.remove_child(screen)
	screen._resize()
	level.gear.add_child(screen)
	await _step(3)
	_check(screen.is_inside_tree() and not screen.is_open and is_equal_approx(Engine.time_scale, 1.0), "Deferred layout is safe while a retained UI is detached during a room teardown")
	player.reset_movement_at(Vector2(680, 640))
	level.dummy_a.global_position = Vector2(707, 640)
	await _step(4)
	_aim(level.dummy_a.hurtbox.global_position)
	var before: int = level.dummy_a.hit_count
	await _attack()
	await _time(0.09)
	_check(player.equipped_weapon.snapshot != null and player.equipped_weapon.snapshot.base_damage == 5.0, "Unarmed commits a separate basic five-damage punch snapshot")
	await _time(0.08)
	_check(level.dummy_a.hit_count == before + 1, "Basic punch contacts the real Hurtbox exactly once")
	await _time(0.2)
	_aim(player.global_position + Vector2(150, -20))
	player.energy.reset()
	var spell: SpellSnapshot = player.resonance_controller.commit_cast()
	_check(spell != null and spell.recipe_id == &"fire_bolt", "Unarmed retains the independent Catalyst cast pipeline")
	await _key(KEY_TAB)
	await _click(screen.bag_buttons[screen.bag_uids.find(original_uid)], MOUSE_BUTTON_RIGHT)
	_check(inventory.equipped_weapon_uid == original_uid and player.equipped_weapon.definition == Player.SWORD, "Right-clicking a bag sword also equips it")
	_check(screen.bag_uids.find(original_uid) == -1 and screen.bag_uids.find(0) <= first_free, "Equipped item vacates its bag position")
	var rune_ids: Array[StringName] = inventory.slots.duplicate()
	var cooled: float = player.resonance_controller.loadout_state.cooldowns_by_recipe_id.get(&"fire_bolt", 0.0)
	for index: int in 12:
		inventory.equip_equipment(spare.uid if index % 2 == 0 else original_uid)
	_check(inventory.items.size() == count and inventory.slots == rune_ids, "Repeated equip swaps preserve all owned item and rune identities")
	_check(player.resonance_controller.loadout_state.cooldowns_by_recipe_id.get(&"fire_bolt", 0.0) == cooled, "Equipment changes cannot reset spell cooldowns")
	_check(hash(GearInventory.COMMON_SWORD.get("moveset")) == source_hash and Player.SWORD.critical_chance == 0, "Equipment does not mutate cached moveset Resources")
	_check(physical_socket.transform == socket_transform and player.hurtbox.get_node("CollisionShape2D").shape == hurt_shape, "Changing equipment preserves the physical socket transform and Hurtbox resource")
	await _test_stats(inventory, screen)
	await _test_full_bag(inventory)
	screen.close()
	await _step(3)
	player.equipped_weapon.start_combo()
	player.equipped_weapon.advance(0.08)
	_check(player.equipped_weapon.hitbox.active, "Sword active window still opens from its authoritative clock")
	inventory.equip_equipment(spare.uid)
	_check(not player.equipped_weapon.hitbox.active and player.action_state_machine.get_state_id() == &"ready", "Equipment swap cancels an active old weapon even when the moveset is shared")
	var retained: int = inventory.equipped_weapon_uid
	player.relocate(Vector2(180, 640))
	await _step(3)
	_check(inventory.equipped_weapon_uid == retained and visual.shown_uid == retained, "Room relocation keeps the equipped UID and hand display")
	screen.open()
	player.health.apply_damage(999)
	await _step(3)
	_check(not screen.is_open and not screen.veil.visible and not player.controls_enabled, "Death closes inventory without reviving controls")
	_check(is_equal_approx(Engine.time_scale, 1.0), "Death releases the modal time claim")
	_check(not visual.visible, "Dead Player hides equipment presentation")


func _test_stats(inventory: GearInventory, screen: InventoryScreen) -> void:
	var amulet := EquipmentData.new()
	amulet.id = &"fixture_amulet"
	amulet.item_name = "Fixture capacity"
	amulet.slot_type = EquipmentData.SlotType.AMULET
	amulet.bonus_hp = 30
	amulet.bonus_mana = 20
	var ring := EquipmentData.new()
	ring.id = &"fixture_ring"
	ring.slot_type = EquipmentData.SlotType.RING
	ring.bonus_speed = 0.15
	ring.bonus_crit = 0.1
	var charm: GearItem = inventory.add_equipment(amulet)
	var band: GearItem = inventory.add_equipment(ring)
	var hp: float = player.health.current_health
	var speed: float = player.motor.run_speed
	inventory.equip_equipment(charm.uid)
	inventory.equip_equipment(band.uid)
	_check(player.health.maximum_health == 130 and player.energy.maximum == 120 and player.health.current_health == hp, "Capacity bonus updates HP/mana without free healing")
	_check(is_equal_approx(player.motor.run_speed, speed * 1.15) and is_equal_approx(player.equipped_weapon.equipment_critical_bonus, 0.1), "Independent ring modifiers update runtime speed and crit")
	inventory.equip_equipment(band.uid)
	_check(is_equal_approx(player.motor.run_speed, speed * 1.15), "Re-equipping the same UID never stacks its bonus")
	_check(not inventory.dismantle(charm.uid) and not inventory.dismantle(band.uid), "Equipped accessories are protected from salvage")
	inventory.unequip_equipment(EquipmentData.SlotType.AMULET)
	inventory.unequip_equipment(EquipmentData.SlotType.RING)
	_check(player.health.maximum_health == 100 and player.energy.maximum == 100 and player.motor.run_speed == speed and player.equipped_weapon.equipment_critical_bonus == 0, "Unequip rebuilds base stats exactly without residual modifiers")
	screen._show_tooltip(band.uid)
	_check("Tốc chạy %: +15" in screen.tooltip_body.text and "Chí mạng %: +10" in screen.tooltip_body.text, "Tooltip reports actual accessory bonuses")
	inventory.dismantle(charm.uid)
	inventory.dismantle(band.uid)


func _test_full_bag(inventory: GearInventory) -> void:
	var added: Array[int] = []
	while inventory.equipment_bag_uids().size() < 20:
		added.append(inventory.add_equipment(GearInventory.COMMON_SWORD).uid)
	var retained: int = inventory.equipped_weapon_uid
	var count: int = inventory.items.size()
	_check(inventory.add_equipment(GearInventory.COMMON_SWORD) == null and inventory.items.size() == count, "A full equipment bag rejects additions without allocating an owned item")
	_check(not inventory.unequip_equipment(0) and inventory.equipped_weapon_uid == retained, "Full-bag unequip rolls back completely")
	var spare: int = added[0]
	_check(inventory.equip_equipment(spare) and inventory.equipment_bag_uids().size() == 20 and inventory.items.size() == count, "Equip swap remains possible with a full bag without losing the old weapon")
	_check(not inventory.craft(&"upgrade", inventory.add_item(&"weapon", &"ancient_sword", GearItem.Quality.RARE).uid), "Camp cannot turn Rare weapons into blacksmith-only Very Rare gear")
	for uid: int in added:
		if uid != inventory.equipped_weapon_uid:
			inventory.dismantle(uid)
	_check(inventory.items.has(inventory.equipped_weapon_uid), "Salvage cleanup preserves the currently equipped owned UID")
	var drops: Array[int] = []
	for index: int in 40:
		var drop: LootPickup = level.gear.loot.spawn(&"weapon", &"ancient_sword", Vector2(700, 500))
		drops.append(drop.quality)
	_check(drops.all(func(q: int) -> bool: return q <= GearItem.Quality.RARE), "World loot never bypasses the blacksmith gate for higher-tier weapons")
	level.gear.loot.clear()


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


func _aim(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = player.aim.get_canvas_transform() * position
	root.push_input(event, true)
	player.aim.sample_cursor()


func _attack() -> void:
	var event := InputEventAction.new()
	event.action = &"attack"
	event.pressed = true
	Input.parse_input_event(event)
	await _step(1)
	event.pressed = false
	Input.parse_input_event(event)

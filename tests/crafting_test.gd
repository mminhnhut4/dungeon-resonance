extends "res://tests/survival_test_base.gd"

func _initialize() -> void:
	suite = "crafting"
	super._initialize()


func test_system() -> void:
	var inventory: GearInventory = level.gear.inventory
	_check(GearItem.NAMES.size() == 6 and inventory.items.size() == 12, "Six tiers apply to starting weapons, six clothing/accessory items, catalyst and rune items")
	var spare: GearItem = inventory.add_item(&"weapon", &"ancient_sword", GearItem.Quality.LEGENDARY)
	var before: int = inventory.materials[&"metal"]
	_check(inventory.dismantle(spare.uid) and inventory.materials[&"metal"] == before + 11, "Dismantling consumes a unique Legendary weapon and yields metal")
	_check(not inventory.dismantle(spare.uid) and inventory.materials[&"metal"] == before + 11, "Repeated dismantle cannot duplicate resources")
	_check(not inventory.dismantle(inventory.equipped_weapon_uid) and not inventory.dismantle(inventory.catalyst_uid), "Currently equipped weapon and catalyst are protected")
	inventory.equip(0, &"fire")
	var rune_uid: int = inventory.slot_uids[0]
	_check(not inventory.dismantle(rune_uid), "Socketed rune cannot also be salvaged")
	inventory.equip(0, &"")
	var fire_count: int = inventory.bag[&"fire"]
	_check(inventory.dismantle(rune_uid) and inventory.bag[&"fire"] == fire_count - 1, "Rune salvage decrements both ledger and bag")
	_check(not inventory.dismantle(rune_uid), "Destroyed rune ID stays invalid")
	_check(not inventory.craft(&"unknown") and not inventory.craft(&"upgrade", -1), "Invalid recipes and item identities spend no resources")
	var equipped: GearItem = inventory.items[inventory.equipped_weapon_uid]
	var metal: int = inventory.materials[&"metal"]
	var dust: int = inventory.materials[&"dust"]
	inventory.materials[&"metal"] = 0
	inventory.materials[&"dust"] = 0
	_check(not inventory.craft(&"upgrade", equipped.uid) and inventory.materials[&"metal"] == 0 and inventory.materials[&"dust"] == 0, "Unaffordable upgrade is transactional")
	inventory.materials[&"metal"] = metal
	inventory.materials[&"dust"] = dust
	var spare_dagger: GearItem
	for item: GearItem in inventory.items.values():
		if item.kind == &"weapon" and item.definition_id == &"shadow_dagger":
			spare_dagger = item
	inventory.dismantle(spare_dagger.uid)
	_check(inventory.craft(&"upgrade", equipped.uid) and equipped.quality == GearItem.Quality.RARE, "Camp recipe raises runtime item quality exactly one tier")
	level.gear.sync_loadout()
	_check(player.equipped_weapon.damage_multiplier == 1.1 and inventory.weapon_capacity == 2, "Rare weapon gives its quality damage factor and extra rune slot")
	_check(Player.SWORD.base_damage == 10.0 and Player.SWORD.combo_steps.size() == 3, "Quality upgrade leaves shared WeaponDefinition untouched")
	var catalyst: GearItem = inventory.items[inventory.catalyst_uid]
	catalyst.quality = GearItem.Quality.LEGENDARY
	inventory.changed.emit()
	_check(inventory.catalyst_capacity == 5 and player.resonance_controller.catalyst_a.runtime_state.opened_slots == 5, "Legendary catalyst exposes five runtime slots")
	inventory.add_rune(&"fire", GearItem.Quality.LEGENDARY)
	inventory.equip(4, &"fire")
	_check(inventory.slots[4] == &"fire" and inventory.total_shards() >= 3, "Extra catalyst slot accepts an owned quality rune")
	level.gear.modal.refresh()
	_check(level.gear.modal.slots[4].visible and level.gear.modal.slots[6].visible, "Inventory reveals quality-unlocked destinations")
	inventory.equip(4, &"")
	inventory.add_rune(&"fire")
	inventory.add_rune(&"lightning")
	inventory.equip_catalyst_set([&"fire", &"fire", &"wind", &"lightning"])
	_check(player.resonance_controller.get_recipe().id == &"astral_firestorm", "Four-slot exact recipe uses the new quality capacity")
	inventory.equip(5, &"lightning")
	_check(player.resonance_controller.get_recipe().id == &"eclipse_blades", "Five-slot exact recipe remains distinct from its subsets")
	inventory.equip_catalyst_set([&"fire", &"wind"])
	player.resonance_controller.quality_rng.seed = 777
	session.condition.enabled = false
	var empowered: int = 0
	for index: int in 100:
		player.energy.reset()
		player.resonance_controller.reset_runtime()
		var spell: SpellSnapshot = player.resonance_controller.commit_cast()
		if spell.empowered:
			empowered += 1
	_check(empowered >= 20 and empowered <= 50 and player.resonance_controller.bonus_proc_chance == 0.35, "Legendary quality produces bounded empowered resonance rolls")
	session.condition.enabled = true
	catalyst.quality = GearItem.Quality.COMMON
	inventory.equip_catalyst_set([])
	inventory.changed.emit()
	_check(inventory.catalyst_capacity == 3, "Removing quality capacity returns to the base three slots")
	var legendary: GearItem = inventory.add_item(&"weapon", &"shadow_dagger", GearItem.Quality.LEGENDARY)
	_check(not inventory.craft(&"upgrade", legendary.uid), "Camp cannot forge Legendary into Divine")
	inventory.materials[&"dust"] += 12
	inventory.materials[&"metal"] += 8
	_check(inventory.craft(&"potion") and inventory.craft(&"bandage") and inventory.craft(&"trap"), "Recipes produce potion, bandage and floor trap")
	player.health.apply_damage(20.0)
	_check(session.use_consumable(&"potion") and player.health.current_health == 100.0, "Crafted potion heals with the health cap")
	session.condition.inflict(&"bleeding")
	_check(session.use_consumable(&"bandage") and not session.condition.bleeding, "Crafted bandage cures the body wound")
	player.global_position = Vector2(780, 640)
	await _step(3)
	level.enemies[0].global_position = player.global_position + Vector2(15, 0)
	var hp: float = level.enemies[0].health.current_health
	_check(session.use_consumable(&"trap"), "Crafted trap deploys on actual floor")
	await _step(4)
	_check(level.enemies[0].health.current_health == hp - 25.0 and get_nodes_in_group(&"floor_traps").is_empty(), "Trap damages one enemy and destroys itself")
	player.global_position = session.campfire.global_position
	await _step(3)
	_check(player.hurtbox.sanctuary_safe and player.hurtbox.take_damage(_damage(player.hurtbox, 10.0)).blocked, "Campfire creates a safe resting radius")
	await _key(KEY_E)
	_check(session.panel.is_open and session.panel.can_craft, "E opens the crafting interface at campfire")
	session.panel.close()
	await _key(KEY_F3)
	_check(profile.souls == 100 and session.panel.is_open and session.panel.can_craft, "F3 grants debug souls and opens crafting in place")
	session.panel.close()
	level.secret_chest.player.global_position = level.secret_chest.global_position
	level.secret_chest.interact()
	_check(level.gear.loot.get_children().all(func(node: Node) -> bool: return node.quality >= 0 and node.quality <= 4), "Chest loot qualities stay within the non-Divine authored drop tiers")
	_check(level.gear.loot.get_children().any(func(node: Node) -> bool: return node.kind == &"catalyst"), "Quality loot includes Catalyst items as well as runes and weapons")

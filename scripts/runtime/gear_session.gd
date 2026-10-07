class_name GearSession
extends Node
## Composition root shared by the playground and dungeon run.

var player: Player
var inventory := GearInventory.new()
var loot: LootSpawner
var modal: GearInventoryModal
var hud: Label
var allow_interaction: bool = true
var energy_bar: ProgressBar
var relics: RelicRuntime
const UNARMED: WeaponDefinition = preload("res://data/weapons/unarmed.tres")
const INVENTORY_SCENE: PackedScene = preload("res://scenes/ui/inventory_screen.tscn")
var equipment_visual: EquipmentVisual
var equipment_stats: EquipmentStats
var _applied_weapon_uid: int = -1


func initialize(actor: Player, feedback: CombatFeedback, world: Node2D, demo_shards: bool = false, existing_inventory: GearInventory = null) -> void:
	player = actor
	player.gear_switch_enabled = true
	player.equipped_weapon.equip(Player.SWORD)
	player.equipped_weapon.effect_executor = player.resonance_controller.executor
	player.weapon_changed.connect(_on_weapon_changed)
	player.energy.enabled = true
	player.energy.feedback = feedback
	if existing_inventory != null:
		inventory = existing_inventory
		var equipped: GearItem = inventory.items.get(inventory.equipped_weapon_uid)
		if equipped != null and equipped.can_equip():
			player.equipped_weapon.equip(equipped.equipment_definition.moveset if equipped.equipment_definition != null else load("res://data/weapons/%s.tres" % equipped.definition_id) as WeaponDefinition)
	else:
		inventory.owned_weapons.assign([Player.SWORD, Player.DAGGER])
		inventory.equipped_weapon_uid = inventory.add_item(&"weapon", &"ancient_sword").uid
		inventory.add_item(&"weapon", &"shadow_dagger")
		inventory.catalyst_uid = inventory.add_item(&"catalyst", &"starter_catalyst").uid
		inventory.install_starter_clothing()
	equipment_stats = EquipmentStats.new()
	add_child(equipment_stats)
	equipment_stats.initialize(player, inventory)
	if existing_inventory == null:
		# Start a fresh run fully healthy; subsequent room/loadout changes never heal.
		player.health.reset_health()
	inventory.changed.connect(sync_loadout)
	loot = LootSpawner.new()
	loot.player = player
	loot.inventory = inventory
	loot.feedback = feedback
	world.add_child(loot)
	modal = INVENTORY_SCENE.instantiate() as GearInventoryModal
	modal.player = player
	modal.inventory = inventory
	add_child(modal)
	equipment_visual = EquipmentVisual.new()
	equipment_visual.player = player
	equipment_visual.inventory = inventory
	player.get_node("Visuals").add_child(equipment_visual)
	player.health.died.connect(modal.close)
	var canvas := CanvasLayer.new()
	canvas.layer = 12
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(48, 590)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06))
	hud.add_theme_constant_override("outline_size", 6)
	hud.add_theme_font_size_override("font_size", 15)
	canvas.add_child(hud)
	energy_bar = ProgressBar.new()
	energy_bar.position = Vector2(48, 568)
	energy_bar.size = Vector2(270, 12)
	energy_bar.show_percentage = false
	energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(energy_bar)
	if demo_shards:
		for rune: RuneData in GearInventory.RUNES.slice(0, 3):
			inventory.add_rune(rune.id)
	sync_loadout()


func sync_loadout() -> void:
	var can_reset_action: bool = player.health.current_health > 0.0 and not (player.hit_reaction != null and player.hit_reaction.blocks_controls())
	if inventory.explicit_weapon_selection and _applied_weapon_uid != inventory.equipped_weapon_uid:
		player.equipped_weapon.cancel_combo()
		if can_reset_action:
			player.action_state_machine.transition_to(&"ready")
	if inventory.explicit_weapon_selection:
		var choice: GearItem = inventory.items.get(inventory.equipped_weapon_uid)
		var wanted: WeaponDefinition = UNARMED
		if choice != null and choice.can_equip():
			wanted = choice.equipment_definition.moveset if choice.equipment_definition != null else load("res://data/weapons/%s.tres" % choice.definition_id) as WeaponDefinition
		if wanted != null and player.equipped_weapon.definition != wanted:
			if can_reset_action:
				player.action_state_machine.transition_to(&"ready")
			player.equipped_weapon.equip(wanted)
	sync_quality()
	_applied_weapon_uid = inventory.equipped_weapon_uid
	player.resonance_controller.catalyst_a.install_runes(inventory.catalyst_runes())
	player.equipped_weapon.installed_rune = inventory.get_rune(inventory.slots[3])
	player.equipped_weapon.additional_runes.clear()
	for slot: int in [6, 7]:
		if slot < inventory.slots.size() and inventory.slots[slot] != &"":
			player.equipped_weapon.additional_runes.append(inventory.get_rune(inventory.slots[slot]))
	var equipped_item: GearItem = inventory.items.get(inventory.equipped_weapon_uid)
	if equipped_item != null and equipped_item.can_equip() and equipped_item.equipment_definition != null:
		player.equipped_weapon.additional_runes.append_array(equipped_item.equipment_definition.intrinsic_runes)
	if inventory.explicit_weapon_selection and inventory.equipped_weapon_uid == 0:
		player.equipped_weapon.installed_rune = null
		player.equipped_weapon.additional_runes.clear()


func sync_quality() -> void:
	inventory._ensure_slots()
	if player.gear_switch_enabled:
		var owned: Array[WeaponDefinition] = []
		for id: StringName in SanctuaryProfile.WEAPONS:
			if inventory.items.values().any(func(item: GearItem) -> bool: return item.kind == &"weapon" and item.definition_id == id and item.can_equip()):
				owned.append(load("res://data/weapons/%s.tres" % id) as WeaponDefinition)
		if owned.is_empty():
			owned.append(UNARMED)
		for item: GearItem in inventory.items.values():
			if item.kind != &"weapon" or not item.can_equip() or item.equipment_definition == null:
				continue
			var family: WeaponDefinition = item.equipment_definition.moveset
			if family != null and family.visual_profile != &"legacy" and not owned.has(family):
				if owned.size() == 1 and owned[0] == UNARMED: owned.clear()
				owned.append(family)
		player.available_weapons.assign(owned)
		var index: int = owned.find(player.equipped_weapon.definition)
		if index >= 0:
			player.gear_index = index
	var weapon_item: GearItem = inventory.items.get(inventory.equipped_weapon_uid)
	if weapon_item != null and not weapon_item.can_equip():
		weapon_item = null
	if not inventory.explicit_weapon_selection and (weapon_item == null or weapon_item.definition_id != player.equipped_weapon.definition.id):
		weapon_item = null
		for item: GearItem in inventory.items.values():
			if item.kind == &"weapon" and item.can_equip() and item.definition_id == player.equipped_weapon.definition.id and (weapon_item == null or item.quality > weapon_item.quality):
				weapon_item = item
		inventory.equipped_weapon_uid = weapon_item.uid if weapon_item != null else 0
	inventory.equipment_uids[EquipmentData.SlotType.WEAPON] = inventory.equipped_weapon_uid
	var catalyst: GearItem = inventory.items.get(inventory.catalyst_uid)
	var rune_factor: float = 1.0
	var rune_bonus: int = 0
	var rune_proc: float = 0.0
	for slot: int in GearInventory.CATALYST_INDICES:
		var rune_item: GearItem = inventory.items.get(inventory.slot_uids[slot])
		if rune_item != null:
			rune_factor = maxf(rune_factor, rune_item.damage_factor())
			rune_bonus = maxi(rune_bonus, rune_item.bonus_slots())
			rune_proc = maxf(rune_proc, rune_item.proc_chance())
	inventory.catalyst_capacity = mini(5, 3 + (catalyst.bonus_slots() if catalyst != null else 0) + rune_bonus + clampi(inventory.permanent_rune_capacity, 0, 2))
	inventory.weapon_capacity = mini(3, 1 + (weapon_item.bonus_slots() if weapon_item != null else 0))
	for slot: int in [4, 5, 6, 7]:
		var allowed: bool = GearInventory.CATALYST_INDICES.find(slot) < inventory.catalyst_capacity if slot in [4, 5] else slot - 5 < inventory.weapon_capacity
		if not allowed and inventory.slots[slot] != &"":
			inventory.bag[inventory.slots[slot]] += 1
			inventory.slots[slot] = &""
			inventory.slot_uids[slot] = 0
	player.resonance_controller.catalyst_a.runtime_state.opened_slots = inventory.catalyst_capacity
	var factor: float = weapon_item.damage_factor() if weapon_item != null else 1.0
	player.equipped_weapon.visual_quality = clampi(weapon_item.quality, GearItem.Quality.COMMON, GearItem.Quality.DIVINE) if weapon_item != null else GearItem.Quality.COMMON
	player.equipped_weapon.damage_multiplier = factor + (equipment_stats.attack_bonus / maxf(1.0, player.equipped_weapon.definition.base_damage) if is_instance_valid(equipment_stats) else 0.0)
	player.resonance_controller.quality_damage_multiplier = (catalyst.damage_factor() if catalyst != null else 1.0) * rune_factor
	player.resonance_controller.bonus_proc_chance = maxf(catalyst.proc_chance() if catalyst != null else 0.0, rune_proc)


func _on_weapon_changed(_definition: WeaponDefinition) -> void:
	inventory.explicit_weapon_selection = false
	sync_loadout()
	modal.refresh()


func reset_inventory() -> void:
	inventory.explicit_weapon_selection = false
	inventory.equipment_uids.resize(EquipmentData.SLOT_COUNT)
	inventory.equipment_uids.fill(0)
	inventory.equipment_positions.clear()
	inventory.equipped_weapon_uid = 0
	inventory.items.clear()
	inventory.slots.assign([&"", &"", &"", &"", &"", &"", &"", &""])
	inventory.slot_uids.assign([0, 0, 0, 0, 0, 0, 0, 0])
	for id: StringName in inventory.bag:
		inventory.bag[id] = 0
	for id: StringName in inventory.materials:
		inventory.materials[id] = 0
	for id: StringName in inventory.consumables:
		inventory.consumables[id] = 0
	inventory.catalyst_uid = inventory.add_item(&"catalyst", &"starter_catalyst").uid
	for definition: WeaponDefinition in player.available_weapons:
		var item: GearItem = inventory.add_item(&"weapon", definition.id)
		if definition == player.equipped_weapon.definition:
			inventory.equipped_weapon_uid = item.uid
	inventory.install_starter_clothing()
	inventory.changed.emit()
	if is_instance_valid(equipment_stats):
		equipment_stats.reset_base_stats()
	if is_instance_valid(relics):
		relics.clear_equipped()
		relics.owned.clear()


func _process(_delta: float) -> void:
	if hud == null:
		return
	sync_quality()
	var rune: RuneData = player.equipped_weapon.installed_rune
	energy_bar.value = player.energy.current
	hud.text = "Q · %s | Khảm: %s\nNăng lượng %d/100 ▰ Lướt 25 · Phép 30\nTab · Hành trang | E · Nhặt / mở rương" % [player.equipped_weapon.definition.display_name, rune.display_name if rune != null else "Trống", roundi(player.energy.current)]


func _unhandled_input(event: InputEvent) -> void:
	if not allow_interaction or modal == null or modal.is_open or not player.controls_enabled:
		return
	if event.is_action_pressed(&"interact"):
		for node: Node in get_tree().get_nodes_in_group(&"chests"):
			var chest := node as TreasureChest
			if chest != null and chest.player == player and chest.interact():
				return
		loot.interact_nearest()

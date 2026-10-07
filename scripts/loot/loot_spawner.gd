class_name LootSpawner
extends Node2D

signal pickup_spawned(pickup: LootPickup)

var player: Player
var inventory: GearInventory
var feedback: CombatFeedback
var maximum_pickups: int = 96
var drop_serial: int = 0
var spawned_total: int = 0
var rng := RandomNumberGenerator.new()
var quality_enabled: bool = false
var relics: RelicRuntime
var crystal_drops_enabled: bool = false
var prologue_drops_enabled: bool = false
var drop_table: DropTableResource
var permanent_profile: SanctuaryProfile
const BROKEN_WEAPONS: Array[StringName] = [&"ancient_sword", &"shadow_dagger", &"storm_arcane_staff"]
const BROKEN_CLOTHING: Array[EquipmentData] = [preload("res://data/equipment/starter_top.tres"), preload("res://data/equipment/starter_gloves.tres")]


func _ready() -> void:
	rng.randomize()


func spawn(kind: StringName, id: StringName, location: Vector2, quantity: int = 1, runtime_item: GearItem = null) -> LootPickup:
	if quantity <= 0 or quantity > MaterialCatalog.MAX_COUNT or (kind == &"material" and id not in MaterialCatalog.IDS) or (kind == &"consumable" and id not in [&"potion", &"bandage", &"antidote"]) or (kind not in [&"material", &"consumable", &"soul", &"coins"] and quantity != 1):
		return null
	if get_child_count() >= maximum_pickups:
		return null
	if runtime_item != null and (runtime_item.uid <= 0 or runtime_item.definition_id != id or kind not in [&"weapon", &"equipment"]):
		return null
	var pickup := LootPickup.new()
	pickup.player = player
	pickup.inventory = inventory
	pickup.feedback = feedback
	pickup.relics = relics
	pickup.kind = kind
	pickup.item_id = id
	pickup.quantity = quantity
	pickup.permanent_profile = permanent_profile
	if kind == &"soul": pickup.life = 15.0
	if runtime_item != null:
		# Freeze the already-rolled UID before ready/signals can expose the pickup.
		var frozen := GearItem.new()
		frozen.uid = runtime_item.uid
		frozen.kind = runtime_item.kind
		frozen.definition_id = runtime_item.definition_id
		frozen.quality = runtime_item.quality
		frozen.equipment_definition = runtime_item.equipment_definition
		runtime_item.copy_loot_state_to(frozen)
		pickup.runtime_item = frozen
	pickup.quality = rng.randi_range(0, 4) if quality_enabled and kind not in [&"potion", &"material", &"consumable", &"soul", &"coins", &"blueprint"] else GearItem.Quality.COMMON
	if kind == &"weapon":
		pickup.quality = mini(pickup.quality, GearItem.Quality.RARE)
	if pickup.runtime_item != null:
		pickup.quality = pickup.runtime_item.quality
	elif prologue_drops_enabled and kind == &"weapon":
		# Existing chests keep their definitions, but real run loot receives its
		# single bounded roll before collection (including usable Common/Rare).
		var owned := GearItem.new()
		owned.uid = CombatIds.next_id()
		owned.kind = &"weapon"
		owned.definition_id = id
		owned.quality = pickup.quality
		if id == GearInventory.COMMON_SWORD.id:
			owned.equipment_definition = GearInventory.COMMON_SWORD
		if not ResourceLoader.exists("res://data/weapons/%s.tres" % id) or not LootAffixRoller.roll_once(owned, rng):
			pickup.free()
			return null
		pickup.runtime_item = owned
	pickup.position = location
	pickup.floor_y = location.y + 14.0
	pickup.launch_velocity = Vector2(rng.randf_range(-45, 45), -110)
	add_child(pickup)
	spawned_total += 1
	pickup_spawned.emit(pickup)
	return pickup


func spawn_gear(item: GearItem, location: Vector2) -> LootPickup:
	if item == null or item.kind not in EquipmentData.SLOT_KINDS or item.quality < GearItem.Quality.COMMON or item.quality > GearItem.Quality.DIVINE:
		return null
	return spawn(&"weapon" if item.kind == &"weapon" else &"equipment", item.definition_id, location, 1, item)


func enemy_drop(location: Vector2, enemy_type: StringName = &"slime", elite: bool = false, boss: bool = false) -> void:
	if drop_table != null:
		_world_enemy_drop(location, enemy_type, elite, boss)
		return
	var ids: Array[StringName] = [&"fire", &"wind", &"lightning", &"ice", &"poison"]
	spawn(&"rune", ids[drop_serial % 5], location)
	drop_serial += 1
	spawn(&"consumable" if prologue_drops_enabled else &"potion", &"potion" if prologue_drops_enabled else &"health", location + Vector2(20, 0))
	if crystal_drops_enabled:
		spawn(&"material", &"crystal", location + Vector2(-20, 0), MaterialCatalog.CRYSTALS_PER_ENEMY)
	if prologue_drops_enabled:
		if rng.randf() < MaterialCatalog.ESSENCE_DROP_CHANCE:
			spawn(&"material", &"slime_essence", location + Vector2(-34, 0))
		if rng.randf() < MaterialCatalog.BROKEN_GEAR_DROP_CHANCE:
			spawn_gear(_broken_drop(), location + Vector2(34, 0))


func _world_enemy_drop(location: Vector2, enemy_type: StringName, elite: bool, boss: bool) -> void:
	# Blueprint is its own unconditional 0.5% TOTAL eligible-monster gate.
	# A subsequent empty material roll never changes that marginal probability.
	var known: Array[StringName] = permanent_profile.learned_blueprints if permanent_profile != null else []
	var blueprint: StringName = drop_table.choose_blueprint(rng.randf(), rng, known, elite or boss)
	if blueprint != &"": spawn(&"blueprint", blueprint, location)
	if rng.randf() < drop_table.none_chance: return
	var souls: int = drop_table.boss_souls if boss else drop_table.elite_souls if elite else drop_table.regular_souls
	if souls > 0 and permanent_profile != null: spawn(&"soul", &"souls", location, souls)
	if rng.randf() < 0.35: spawn(&"coins", &"coins", location + Vector2(14, 0), rng.randi_range(1, 3))
	var materials: Array[StringName] = drop_table.material_pool(enemy_type)
	if not materials.is_empty(): spawn(&"material", materials[rng.randi_range(0, materials.size() - 1)], location + Vector2(-16, 0), rng.randi_range(1, 2))
	if rng.randf() < drop_table.stone_chance: spawn(&"material", &"enhancement_stone_1", location + Vector2(-32, 0))
	if rng.randf() < MaterialCatalog.BROKEN_GEAR_DROP_CHANCE: spawn_gear(_broken_drop(), location + Vector2(32, 0))
	# Bản Nguyên Thần Thạch belongs to a future special Boss ONLY. Never here.


func _broken_drop() -> GearItem:
	var item := GearItem.new()
	item.uid = CombatIds.next_id()
	item.quality = GearItem.Quality.COMMON
	var index: int = rng.randi_range(0, BROKEN_WEAPONS.size() + BROKEN_CLOTHING.size() - 1)
	if index < BROKEN_WEAPONS.size():
		item.kind = &"weapon"
		item.definition_id = BROKEN_WEAPONS[index]
		if item.definition_id == GearInventory.COMMON_SWORD.id:
			item.equipment_definition = GearInventory.COMMON_SWORD
	else:
		item.equipment_definition = BROKEN_CLOTHING[index - BROKEN_WEAPONS.size()]
		item.kind = EquipmentData.SLOT_KINDS[item.equipment_definition.slot_type]
		item.definition_id = item.equipment_definition.id
	LootAffixRoller.roll_once(item, rng, &"drop", true)
	return item


func chest_drop(location: Vector2, large: bool = false) -> void:
	if drop_table != null:
		_world_chest_drop(location, large)
		return
	var ids: Array[StringName] = [&"fire", &"wind", &"lightning", &"ice", &"poison"]
	for index: int in (3 if large else 2):
		spawn(&"rune", ids[rng.randi_range(0, 4 if quality_enabled else 2)], location + Vector2(index * 24 - 24, 0))
	var weapon_id: StringName = &"shadow_dagger" if rng.randf() < 0.5 else &"ancient_sword"
	if quality_enabled:
		var content_weapons: Array[StringName] = [&"demon_greatsword", &"gale_dual_daggers", &"storm_arcane_staff", &"blood_spiked_whip"]
		weapon_id = content_weapons[rng.randi_range(0, 3)]
	spawn(&"weapon", weapon_id, location + Vector2(48, 0))
	if large:
		spawn(&"potion", &"health", location + Vector2(-48, 0))
	if quality_enabled:
		spawn(&"catalyst", &"starter_catalyst", location + Vector2(-72, 0))


func _world_chest_drop(location: Vector2, large: bool) -> void:
	var count: int = rng.randi_range(3, 5) + (1 if large else 0)
	var materials: Array[StringName] = [&"metal", &"dust", &"crystal", &"healing_herb", &"linen_fiber", &"detox_root", &"enhancement_stone_1", &"enhancement_stone_2"]
	for index: int in count:
		var point: Vector2 = location + Vector2((index - count / 2.0) * 20, 0)
		if index == count - 1 and rng.randf() < 0.5:
			var item: GearItem = _broken_drop()
			item.quality = GearItem.Quality.RARE
			spawn_gear(item, point)
		else:
			spawn(&"material", materials[rng.randi_range(0, materials.size() - 1)], point, rng.randi_range(3, 5))

	# Restore the existing finite chest RuneShard rule in the world-loot route.
	var ids: Array[StringName] = [&"fire", &"wind", &"lightning", &"ice", &"poison"]
	for index: int in (3 if large else 2):
		spawn(&"rune", ids[rng.randi_range(0, 4 if quality_enabled else 2)], location + Vector2(index * 24 - 24, 0))

func interact_nearest() -> bool:
	var nearest: LootPickup
	var best: float = 100.0
	for child: Node in get_children():
		var pickup := child as LootPickup
		if pickup == null or pickup.collected_once:
			continue
		var distance: float = pickup.global_position.distance_to(player.global_position)
		if distance < best:
			nearest = pickup
			best = distance
	return nearest.interact() if nearest != null else false


func clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

class_name LootPickup
extends Node2D
## Finite collectible, room-owned. Collection commits once before signals/free.

signal collected(pickup: LootPickup)
signal save_retry_required(pickup: LootPickup)
var player: Player
var inventory: GearInventory
var item_id: StringName = &"fire"
var kind: StringName = &"rune"
var collected_once: bool = false
var automatic: bool = true
var age: float = 0.0
var life: float = 90.0
var launch_velocity := Vector2(0, -110)
var floor_y: float = 640.0
var feedback: CombatFeedback
var quality: int = GearItem.Quality.COMMON
var relics: RelicRuntime
var quantity: int = 1
var presentation_skin_active: bool = false
var item_label: Label
var _collection_pending: bool = false
var runtime_item: GearItem
var permanent_profile: SanctuaryProfile
var opening_reward: bool = false
var save_retry_pending: bool = false


func _ready() -> void:
	add_to_group(&"loot")
	z_index = 7
	var label := Label.new()
	item_label = label
	label.name = "ItemLabel"
	label.position = Vector2(-80, -30)
	label.size.x = 160
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.text = "%s · %s" % [item_id, GearItem.NAMES[quality]] if kind != &"potion" else "+30 HP"
	add_child(label)
	queue_redraw()


func _physics_process(delta: float) -> void:
	# Failed permanent transactions remain available for an explicit retry.
	if save_retry_pending: return
	if is_instance_valid(feedback) and feedback.is_frozen():
		return
	age += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if not is_instance_valid(player) or player.health.current_health <= 0.0 or collected_once:
		return
	var distance: float = global_position.distance_to(player.global_position + Vector2(0, -18))
	if automatic and age > 0.35 and distance < 95.0:
		global_position = global_position.move_toward(player.global_position + Vector2(0, -18), 340.0 * delta)
		if distance < 20.0:
			collect()
	else:
		launch_velocity.y += 350.0 * delta
		position += launch_velocity * delta
		if position.y > floor_y - 14.0:
			position.y = floor_y - 14.0
			launch_velocity = Vector2.ZERO
	queue_redraw()


func interact() -> bool:
	if not is_instance_valid(player) or global_position.distance_to(player.global_position) > 100.0:
		return false
	return collect()


func collect() -> bool:
	if collected_once or _collection_pending or not is_instance_valid(player) or inventory == null or (not save_retry_pending and player.health.current_health <= 0.0):
		return false
	_collection_pending = true
	if not _apply_collection():
		if permanent_profile != null and kind in [&"soul", &"blueprint"] and not permanent_profile.last_save_ok:
			save_retry_pending = true
			save_retry_required.emit(self)
		_collection_pending = false
		return false
	collected_once = true
	save_retry_pending = false
	_collection_pending = false
	inventory.changed.emit()
	collected.emit(self)
	queue_free()
	return true


func _apply_collection() -> bool:
	if kind == &"soul":
		return permanent_profile != null and permanent_profile.try_add_souls(quantity, opening_reward)
	if kind == &"coins":
		if inventory.run_coins > MaterialCatalog.MAX_COUNT - quantity: return false
		inventory.run_coins += quantity
		return true
	if kind == &"blueprint":
		return permanent_profile != null and (permanent_profile.learned_blueprints.has(item_id) or permanent_profile.learn_blueprint(item_id))
	if runtime_item != null:
		return _collect_gear_snapshot()
	if kind == &"potion":
		if player.health.heal(30.0) <= 0.0:
			return false
	elif kind == &"weapon":
		if inventory.equipment_bag_uids().size() >= GearInventory.EQUIPMENT_BAG_CAPACITY:
			return false
		if not ResourceLoader.exists("res://data/weapons/%s.tres" % item_id):
			return false
		var definition: WeaponDefinition = load("res://data/weapons/%s.tres" % item_id) as WeaponDefinition
		if not inventory.owned_weapons.has(definition):
			inventory.owned_weapons.append(definition)
		inventory.add_item(&"weapon", item_id, quality)
	elif kind == &"catalyst":
		inventory.add_item(&"catalyst", item_id, quality)
	elif kind == &"relic":
		if not is_instance_valid(relics) or not relics.acquire(item_id):
			return false
		inventory.add_item(&"relic", item_id, quality)
	elif kind == &"material":
		if not inventory.add_material(item_id, quantity):
			return false
	elif kind == &"consumable":
		if not inventory.add_consumable(item_id, quantity):
			return false
	else:
		if not inventory.add_rune(item_id, quality):
			return false
	return true


func _collect_gear_snapshot() -> bool:
	if inventory.items.has(runtime_item.uid) or inventory.equipment_bag_uids().size() >= GearInventory.EQUIPMENT_BAG_CAPACITY or runtime_item.kind not in EquipmentData.SLOT_KINDS:
		return false
	var definition: WeaponDefinition
	if runtime_item.equipment_definition != null:
		var data: EquipmentData = runtime_item.equipment_definition
		if data.id != runtime_item.definition_id or data.slot_type < 0 or data.slot_type >= EquipmentData.SLOT_COUNT or EquipmentData.SLOT_KINDS[data.slot_type] != runtime_item.kind:
			return false
		definition = data.moveset
	elif runtime_item.kind == &"weapon" and ResourceLoader.exists("res://data/weapons/%s.tres" % item_id):
		definition = load("res://data/weapons/%s.tres" % item_id) as WeaponDefinition
	else:
		return false
	if runtime_item.kind == &"weapon":
		if definition == null:
			return false
		if not inventory.owned_weapons.has(definition):
			inventory.owned_weapons.append(definition)
	inventory.items[runtime_item.uid] = runtime_item
	return true


func _draw() -> void:
	if presentation_skin_active:
		return
	var color := Color(0.4, 1.0, 0.65) if kind == &"potion" else Color(1.0, 0.8, 0.25)
	if kind == &"rune" and inventory != null:
		var rune: RuneData = inventory.get_rune(item_id)
		if rune != null:
			color = rune.display_color
	var bob := Vector2(0, sin(age * 4.0) * 3.0)
	draw_rect(Rect2(bob - Vector2(7, 7), Vector2(14, 14)), color)
	draw_circle(bob, 11, Color(color, 0.18))

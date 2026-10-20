extends TreasureChest
## Existing chest/pickup/inventory owners; one authored cache per disposable visit.
const Supply = preload("res://data/shattered_mine_supply_catalog.gd")
const SOURCE_ID: StringName = Supply.SOURCE_ID
const COST: Dictionary = Supply.COST

func _ready() -> void:
	super._ready()
	label.set_meta(&"debug_keep",true)
	set_meta(&"source_id",SOURCE_ID)
	set_meta(&"shattered_mine_source",SOURCE_ID)
	_update_label()

func interact() -> bool:
	if locked or is_open or not is_instance_valid(player) or not player.controls_enabled or player.health.current_health <= 0 or player.global_position.distance_to(global_position)>85:
		return false
	if spawner == null or spawner.get_child_count()+COST.size()>spawner.maximum_pickups:
		return false
	var created: Array[LootPickup] = []
	for id: StringName in [&"dust",&"crystal"]:
		var pickup: LootPickup = spawner.spawn(&"material",id,global_position+Vector2(-18 if id==&"dust" else 18,-14),int(COST[id]))
		if pickup == null:
			for previous: LootPickup in created:
				spawner.remove_child(previous)
				previous.queue_free()
			return false
		pickup.set_meta(&"source_id",SOURCE_ID)
		pickup.set_meta(&"shattered_mine_source",SOURCE_ID)
		pickup.floor_y = global_position.y
		pickup.launch_velocity = Vector2(0,-70)
		pickup.life = 3600.0
		created.append(pickup)
	is_open = true
	opened.emit()
	_update_label()
	return true

func _update_label() -> void:
	if label != null:
		label.text = "Đã mở tiếp tế" if is_open else "E · Rương tiếp tế mỏ\n%d %s + %d %s" % [int(COST[&"dust"]), MaterialCatalog.DISPLAY_NAMES[&"dust"], int(COST[&"crystal"]), MaterialCatalog.DISPLAY_NAMES[&"crystal"]]
	queue_redraw()

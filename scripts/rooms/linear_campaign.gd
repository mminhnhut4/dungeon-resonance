class_name LinearCampaign
extends DungeonRun
## Content campaign reuses Alpha room/loot/boss logic through inheritance.

var stage: int = 0
var initial_stage: int = 1
var secret_chest: TreasureChest
const STAGE_NAMES: Array[String] = ["TIỀN SẢNH", "TẦNG 1.5 · KHÁM PHÁ BÍ MẬT", "ĐẤU TRƯỜNG ĐỘT BIẾN", "GOLEM CỔ BẢO"]


func enter_room(number: int) -> bool:
	return enter_stage(initial_stage if stage == 0 else number)


func enter_stage(number: int) -> bool:
	if number < 1 or number > 4 or outcome != &"" or player.health.current_health <= 0.0:
		return false
	content.close()
	stage = number
	var base_number: int = 1 if stage <= 2 else 2 if stage == 3 else 3
	if not super.enter_room(base_number):
		return false
	secret_chest = null
	if stage == 2:
		room.set_locked(false)
		secret_chest = TreasureChest.new()
		secret_chest.player = player
		secret_chest.spawner = gear.loot
		secret_chest.relic_reward = true
		secret_chest.position = Vector2(90, 366)
		room.add_child(secret_chest)
		survival.place_campfire(Vector2(1050, 640))
		var bramble := EnvironmentBarrier.new()
		bramble.requires_fire = true
		bramble.position = Vector2(215, 300)
		bramble.size = Vector2(26, 130)
		room.add_child(bramble)
	if stage == 4:
		survival._attach_condition(boss)
	if stage == 2: record_opening_milestone(&"explored")
	return true


func _spawn_wave() -> void:
	if stage == 2:
		return
	if stage != 3:
		super._spawn_wave()
		return
	for index: int in 2:
		var slime := preload("res://scenes/enemies/mutant_slime.tscn").instantiate() as MutantSlime
		slime.position = Vector2(700 + index * 320, 640)
		slime.player = player
		slime.combat_feedback = feedback
		slime.projectile_element = &"poison" if index == 0 else &"ice"
		room.add_child(slime)
		slime.statuses.combat_feedback = feedback
		survival._attach_condition(slime)
		slime.health.died.connect(_enemy_died.bind(slime))


func advance_room() -> bool:
	if stage >= 4 or room.locked or outcome != &"" or gear.modal.is_open or content.panel_open or (is_instance_valid(floor_exit) and floor_exit.is_open):
		return false
	return enter_stage(stage + 1)


func _process(delta: float) -> void:
	super._process(delta)
	if title != null and stage >= 1:
		title.text = "%s · %d/4" % [STAGE_NAMES[stage - 1], stage]

class_name WorldCampaign
extends LinearCampaign
## Opt-in mixed roster; legacy LinearCampaign / Alpha fixtures keep their scenes.

@export var run_seed: int = 0
var spawn_rng := RandomNumberGenerator.new()
var world_deaths: int = 0
const MONSTERS: Dictionary[StringName, PackedScene] = {
	&"ancient_guard": preload("res://scenes/enemies/ancient_guard.tscn"),
	&"bloodwing_bat": preload("res://scenes/enemies/bloodwing_bat.tscn"),
	&"sword_wraith": preload("res://scenes/enemies/sword_wraith.tscn"),
	&"runic_champion": preload("res://scenes/enemies/runic_champion.tscn"),
}

func _ready() -> void:
	if run_seed == 0:
		spawn_rng.randomize()
		run_seed = spawn_rng.seed
	else:
		spawn_rng.seed = run_seed
	super._ready()
	gear.loot.drop_table = preload("res://data/loot/world_drop_table.tres")
	gear.loot.permanent_profile = survival.profile

func _spawn_wave() -> void:
	if stage == 2: return
	var roster: Array[StringName] = []
	roster.assign([&"ancient_guard", &"ancient_guard", &"bloodwing_bat", &"runic_slime"] if stage == 1 else [&"ancient_guard", &"sword_wraith", &"runic_champion", &"runic_slime"] if wave == 1 else [&"bloodwing_bat", &"sword_wraith", &"ancient_guard", &"runic_slime"])
	# Only horizontal floor anchors vary. No unsafe arbitrary platform/wall seeds.
	var positions: Array[float] = [560, 715, 870, 1020]
	for index: int in range(positions.size() - 1, 0, -1):
		var swap_index: int = spawn_rng.randi_range(0, index)
		var old: float = positions[index]
		positions[index] = positions[swap_index]
		positions[swap_index] = old
	for index: int in roster.size():
		var id: StringName = roster[index]
		if id == &"runic_slime":
			var slime: SlimeEnemy = _spawn_slime(Vector2(positions[index], 640))
			slime.set_meta(&"enemy_type", &"runic_slime")
			continue
		var enemy: BaseEnemy = MONSTERS[id].instantiate() as BaseEnemy
		enemy.position = Vector2(positions[index], 500 if id == &"bloodwing_bat" else 610 if id == &"sword_wraith" else 640)
		enemy.player = player
		enemy.combat_feedback = feedback
		enemy.is_elite = id == &"runic_champion"
		room.add_child(enemy)
		if survival.enabled: survival._attach_condition(enemy)
		enemy.defeated.connect(_world_enemy_died)

func _world_enemy_died(enemy: BaseEnemy) -> void:
	var id: int = enemy.get_instance_id()
	if processed_deaths.has(id): return
	processed_deaths[id] = true
	world_deaths += 1
	_spawn_world_loot.call_deferred(enemy.global_position, enemy.enemy_type, enemy.is_elite, room.get_instance_id())
	_check_clear.call_deferred()

func _spawn_world_loot(location: Vector2, enemy_id: StringName, elite: bool, room_id: int) -> void:
	if outcome != &"" or not is_instance_valid(room) or room.get_instance_id() != room_id: return
	gear.loot.enemy_drop(location, enemy_id, elite, false)

func _enemy_died(enemy: SlimeEnemy) -> void:
	var id: int = enemy.get_instance_id()
	if processed_deaths.has(id): return
	processed_deaths[id] = true
	world_deaths += 1
	_spawn_world_loot.call_deferred(enemy.global_position, enemy.get_meta(&"enemy_type", &"slime"), enemy.is_elite, room.get_instance_id())
	_check_clear.call_deferred()

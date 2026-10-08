class_name DepthEnemy
extends BaseEnemy
## Campaign-only derived actors. Definitions are private runtime copies.

const ART: Script = preload("res://scripts/presentation/depth_enemy_art.gd")
const BASES: Array[String] = ["ancient_guard", "bloodwing_bat", "sword_wraith", "runic_champion"]
const IDS: Array[StringName] = [&"depth_stone_guard", &"depth_root_bat", &"depth_frost_wraith", &"depth_forge_champion"]
const NAMES: Array[String] = ["Vân Thạch Trấn Vệ", "Mộc Căn Bào Dực", "Hàn Kính Kiếm Hồn", "Xích Lô Giáp Vệ"]
@export_range(1, 4) var depth_floor: int = 1

func _ready() -> void:
	depth_floor = clampi(depth_floor, 1, 4)
	definition = (load("res://data/enemies/%s.tres" % BASES[depth_floor - 1]) as WorldEnemyData).duplicate(true) as WorldEnemyData
	definition.id = IDS[depth_floor - 1]
	definition.display_name = NAMES[depth_floor - 1]
	# A committed crystal thrust can pass the target. Existing wraith data stays unchanged.
	if depth_floor == 3: definition.attack_range = 180.0
	super._ready()
	var previous: WorldEnemyVisual = visual
	remove_child(previous)
	previous.free()
	visual = ART.new() as WorldEnemyVisual
	visual.name = "DepthEnemyArt"
	add_child(visual)
	visual.bind(self)
	add_to_group(&"depth_enemies")

func tick_state(id: StringName, delta: float) -> void:
	super.tick_state(id, delta)
	if id != &"recover" or state_machine.get_state_id() != &"recover" or statuses.is_stunned(): return
	match depth_floor:
		1, 4:
			# A physical retreat opens a flank after the committed strike/field.
			if state_time < 0.28 and _has_floor_ahead(-facing):
				_desired.x = -facing * definition.chase_speed
		2:
			# The spore bat pulls up and away; its body still collides with the room.
			if state_time < 0.32:
				_desired = Vector2(-facing * definition.chase_speed, -90.0)

func tactic_hint() -> String:
	return ["Né nhát quét rồi đánh vào sườn khi trấn vệ lùi lại.", "Tránh đường bổ nhào và bào tử; đánh khi bào dực rút lên.", "Rời đường ngắm đã khóa; xoay lại sau cú xuyên của kiếm hồn.", "Rời vòng phù trận; phá giáp khi hộ vệ lùi hồi chiêu."][depth_floor - 1]

class_name MemberDungeonEncounter
extends Node2D
## Room owns actors; campaign owns drops. Removing the room cancels deferred brood.
signal enemy_defeated(enemy: BaseEnemy)
var floor_number: int=9
var player: Player
var feedback: CombatFeedback
var deaths: Dictionary[int,bool]={}
var spawned: Array[MemberEnemy]=[]
func _ready() -> void:
	set_meta(&"member_trial_generation",1)
	for row: Array in MemberEncounterCatalog.entries(floor_number):
		var enemy:=load("res://scenes/enemies/member_enemy.tscn").instantiate() as MemberEnemy
		enemy.member_type=row[0];enemy.position=Vector2(float(row[1]),640)
		enemy.balance_floor=floor_number
		enemy.campaign_lane=true;enemy.lane_limits=Vector2(float(row[2]),float(row[3]))
		enemy.player=player;enemy.combat_feedback=feedback;add_child(enemy);bind_member_enemy(enemy)
func bind_member_enemy(enemy: BaseEnemy) -> void:
	spawned.append(enemy as MemberEnemy)
	if not enemy.defeated.is_connected(_defeated):enemy.defeated.connect(_defeated)
func _defeated(enemy: BaseEnemy) -> void:
	var key: int=enemy.get_instance_id()
	if deaths.has(key):return
	deaths[key]=true;enemy_defeated.emit(enemy)
func _exit_tree() -> void:set_meta(&"member_trial_generation",int(get_meta(&"member_trial_generation",0))+1)

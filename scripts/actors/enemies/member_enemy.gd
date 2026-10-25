class_name MemberEnemy
extends BaseEnemy
## Existing FSM/motor/Hurtbox owners; actor-local extras, finite brood, no loot owner.
@export var member_type: StringName=&"member_hellhound"
@export_range(3,4) var brood_size: int=4
var member_rig: MemberConceptRig
var _hop_remaining: float=0
var _brood_issued: bool=false
var _member_dead: bool=false
var children_spawned: int=0
var campaign_lane: bool=false
var balance_floor: int=0
var lane_limits:=Vector2(-INF,INF)
func _ready() -> void:
	definition=MemberEnemyCatalog.definition(member_type,balance_floor)
	if balance_floor>=9 and balance_floor<=30:brood_size=MemberBalanceCatalog.brood_count(balance_floor)
	super._ready();visual.hide()
	add_to_group(&"member_enemies")
	member_rig=MemberConceptRig.attach_to(self,String(member_type))
func _physics_process(delta: float) -> void:
	if is_instance_valid(combat_feedback) and combat_feedback.is_frozen():return
	_hop_remaining=maxf(0.0,_hop_remaining-delta)
	super._physics_process(delta);queue_redraw()
func enter_state(id: StringName) -> void:
	super.enter_state(id)
	if id==&"telegraph" and member_type!=&"member_emperor":attack_kind=&"member_bite"
func tick_state(id: StringName,delta: float) -> void:
	if id==&"dead":
		if state_time>=.65:queue_free()
		return
	super.tick_state(id,delta)
	if campaign_lane and not is_nan(_desired.x):
		if global_position.x<=lane_limits.x+3 and _desired.x<0:_desired.x=definition.patrol_speed;facing=1
		elif global_position.x>=lane_limits.y-3 and _desired.x>0:_desired.x=-definition.patrol_speed;facing=-1
	if member_type==&"member_jiangshi" and id in [&"patrol",&"chase"] and is_on_floor() and _hop_remaining<=0 and not statuses.is_stunned():
		motor.launch_vertical(350);_hop_remaining=.72
func _can_see_target(radius: float=-1.0) -> bool:
	if campaign_lane:
		if not is_instance_valid(player) or player.global_position.x<lane_limits.x or player.global_position.x>lane_limits.y or absf(player.global_position.y-640)>80:return false
	return super._can_see_target(radius)
func _start_attack() -> void:
	attacks_started+=1
	var attack:=AttackSnapshot.new();attack.source_id=get_instance_id();attack.source_team_id=2
	attack.attack_id=CombatIds.next_id();attack.root_event_id=attack.attack_id;attack.attack_direction=locked_direction
	var rect: Rect2=_current_attack_rect()
	var shape:=RectangleShape2D.new();shape.size=rect.size;_attack_shape=shape
	attack_hitbox.activate(attack,shape,rect.get_center())
func _current_attack_rect() -> Rect2:
	var rect: Rect2=MemberEnemyCatalog.attack_rect(member_type,facing)
	if campaign_lane:
		var lane:=Rect2(Vector2(lane_limits.x-global_position.x,-300),Vector2(lane_limits.y-lane_limits.x,600))
		rect=rect.intersection(lane)
	return rect
func has_poise() -> bool:return member_type==&"member_emperor" and state_machine.get_state_id()==&"attack" and not statuses.is_stunned()
func _on_died() -> void:
	if _member_dead:return
	_member_dead=true
	var target: CharacterBody2D=player;var parent: Node=get_parent();var at: Vector2=position
	var generation: int=int(parent.get_meta(&"member_trial_generation",0))
	super._on_died()
	if member_type==&"member_spider" and not _brood_issued:
		_brood_issued=true;_spawn_brood.call_deferred(parent,target,at,generation)
func _spawn_brood(parent: Node,target: CharacterBody2D,at: Vector2,generation: int) -> void:
	if not is_inside_tree() or not is_instance_valid(parent) or not parent.is_inside_tree() or int(parent.get_meta(&"member_trial_generation",0))!=generation:return
	var allowed: int=mini(brood_size,64-get_tree().get_nodes_in_group(&"enemies").size())
	for index: int in maxi(0,allowed):
		var child:=load("res://scenes/enemies/member_enemy.tscn").instantiate() as BaseEnemy
		child.set("member_type",&"member_spiderling");child.position=at+Vector2((index-(allowed-1)*.5)*28,0)
		child.set("campaign_lane",campaign_lane);child.set("lane_limits",lane_limits)
		child.set("balance_floor",balance_floor)
		if campaign_lane:child.position.x=clampf(child.position.x,lane_limits.x+5,lane_limits.y-5)
		child.player=target if is_instance_valid(target) else null;child.combat_feedback=combat_feedback
		parent.add_child(child);children_spawned+=1
		if parent.has_method("bind_member_enemy"):parent.call("bind_member_enemy",child)
func _draw() -> void:
	if state_machine==null:return
	var id: StringName=state_machine.get_state_id()
	if id not in [&"telegraph",&"attack"]:return
	var rect: Rect2=_current_attack_rect()
	var tint:=Color("e5bd68") if id==&"telegraph" else Color("e17844")
	draw_rect(rect,Color(tint,.12),true)
	draw_rect(rect,tint,false,2)
	if id==&"telegraph":
		var progress: float=clampf(state_time/definition.windup,0,1)
		draw_line(rect.position+Vector2(0,rect.size.y+4),rect.position+Vector2(rect.size.x*progress,rect.size.y+4),tint,3)

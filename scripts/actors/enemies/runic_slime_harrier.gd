extends SlimeEnemy
## Prototype role for exactly the first opening Runic slot. Base stats/loot stay Slime.
const BOLT: Script=preload("res://scripts/actors/enemies/runic_harrier_bolt.gd")
const WINDUP: float=0.55
const RANGED_COOLDOWN: float=1.8
const MIN_RANGED_DISTANCE: float=80.0
const MAX_RANGED_DISTANCE: float=300.0
const MAX_BOLTS: int=3
@export var projectile_element: StringName=&"poison" # Existing Slime skin identity only.
var ranged_remaining: float=1.2
var ranged_windup: float=0.0
var locked_ranged_direction: Vector2=Vector2.RIGHT
var locked_ranged_point: Vector2=Vector2.ZERO
var shots_fired: int=0
var tells_started: int=0
var tells_cancelled: int=0
var _locked_target_id: int=0
var _room_id: int=0
var _bolts: Array[WeakRef]=[]
func _ready() -> void:
	_room_id=get_parent().get_instance_id()
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=ink
	super._ready()
func _physics_process(delta: float) -> void:
	if is_instance_valid(player) and not _same_scene(player):_forget_player_target()
	if health.current_health>0 and (not ai_enabled or not is_visible_in_tree() or get_parent()==null or get_parent().get_instance_id()!=_room_id):
		_cancel_tell();_clear_bolts();bite_hitbox.deactivate();queue_redraw();return
	if ai_enabled and health.current_health>0 and not (is_instance_valid(combat_feedback) and combat_feedback.is_frozen()):
		ranged_remaining=maxf(0,ranged_remaining-delta)
	_prune_bolts()
	super._physics_process(delta)
	queue_redraw()
func _same_scene(candidate: Node) -> bool:
	if not is_instance_valid(candidate) or not candidate.is_inside_tree() or candidate.is_queued_for_deletion():return false
	var scope: Node=get_parent()
	while scope!=null and scope!=candidate.get_parent() and scope!=get_tree().root:scope=scope.get_parent()
	return scope==candidate.get_parent()
func _living_target() -> bool:
	return ai_enabled and health.current_health>0 and is_visible_in_tree() and get_parent()!=null and get_parent().get_instance_id()==_room_id and is_instance_valid(player) and player is Player and _same_scene(player) and player.health.current_health>0 and not hit_aggro.sight_suppressed
func projectile_allowed(candidate: Player,parent_room: int) -> bool:
	return parent_room==_room_id and _living_target() and player==candidate
func _ranged_target_valid() -> bool:
	if not _living_target() or not _can_see_player(MAX_RANGED_DISTANCE):return false
	var distance: float=global_position.distance_to(player.global_position)
	if distance<MIN_RANGED_DISTANCE or distance>MAX_RANGED_DISTANCE:return false
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-30),player.global_position+Vector2(0,-18),1)).is_empty()
func tick_state(id: StringName,delta: float) -> void:
	if id in [&"dead",&"hurt"] or statuses.is_stunned():
		_cancel_tell();super.tick_state(id,delta);return
	if ranged_windup>0:
		_desired_velocity=0
		if not _ranged_target_valid() or player.get_instance_id()!=_locked_target_id:
			_cancel_tell();return
		ranged_windup=maxf(0,ranged_windup-delta*statuses.attack_speed_multiplier)
		if ranged_windup<=0:_fire_ranged()
		return
	if id==&"chase" and ranged_remaining<=0 and _ranged_target_valid() and _request_opening_attack():
		_start_tell();_desired_velocity=0;return
	super.tick_state(id,delta)
	if id==&"chase" and state_machine.get_state_id()==&"chase" and _ranged_target_valid():
		# Hold a ranged lane instead of walking all the way into the Guard pile.
		_desired_velocity=0
func _start_tell() -> void:
	ranged_windup=WINDUP;ranged_remaining=RANGED_COOLDOWN
	_locked_target_id=player.get_instance_id();locked_ranged_point=player.global_position+Vector2(0,-18)
	locked_ranged_direction=(locked_ranged_point-global_position-Vector2(0,-30)).normalized()
	_facing=-1 if locked_ranged_direction.x<0 else 1
	tells_started+=1
func opening_attack_committed() -> bool:
	return super.opening_attack_committed() or (ai_enabled and health.current_health>0 and is_visible_in_tree() and ranged_windup>0)
func _cancel_tell() -> void:
	if ranged_windup>0:
		tells_cancelled+=1;ranged_remaining=maxf(ranged_remaining,RANGED_COOLDOWN)
	ranged_windup=0;_locked_target_id=0;queue_redraw()
func _fire_ranged() -> void:
	if not _ranged_target_valid() or player.get_instance_id()!=_locked_target_id:return
	if not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-30),locked_ranged_point,1)).is_empty():return
	_prune_bolts()
	if _bolts.size()>=MAX_BOLTS:return
	var bolt: EnemyHazard=BOLT.new() as EnemyHazard
	bolt.player=player as Player;bolt.feedback=combat_feedback;bolt.source_id=get_instance_id()
	bolt.direction=locked_ranged_direction;bolt.position=(get_parent() as Node2D).to_local(global_position+Vector2(0,-30))
	bolt.set("source_owner",weakref(self));bolt.set("room_id",_room_id)
	get_parent().add_child(bolt);_bolts.append(weakref(bolt));shots_fired+=1
func _prune_bolts() -> void:
	for i: int in range(_bolts.size()-1,-1,-1):
		var bolt: Node=_bolts[i].get_ref() as Node
		if not is_instance_valid(bolt) or bolt.is_queued_for_deletion():_bolts.remove_at(i)
func _clear_bolts() -> void:
	for ref: WeakRef in _bolts:
		var bolt: Node=ref.get_ref() as Node
		if is_instance_valid(bolt) and not bolt.is_queued_for_deletion():bolt.queue_free()
	_bolts.clear()
func _on_hit(event: DamageEvent,result: DamageResult) -> void:
	if not result.blocked and result.actual_damage>0 and event.source_kind!=DamageEvent.SourceKind.DOT:_cancel_tell()
	super._on_hit(event,result)
func _forget_player_target() -> void:
	_cancel_tell();_clear_bolts();super._forget_player_target()
func _on_died() -> void:
	_cancel_tell();_clear_bolts();super._on_died()
func reset_at_home() -> void:
	_cancel_tell();_clear_bolts();ranged_remaining=1.2;super.reset_at_home()
func _draw() -> void:
	if ranged_windup<=0:return
	var progress: float=clampf(1-ranged_windup/WINDUP,0,1)
	var color:=Color(0.85,0.62,1.0,0.5+progress*.5)
	var center:=Vector2(0,-49)
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-8),center+Vector2(6,0),center+Vector2(0,8),center+Vector2(-6,0)]),color)
	draw_arc(center,12,0,TAU*progress,18,color,2,true)
	var origin:=Vector2(0,-30)
	# Show the committed lane to the original aim point, never a tracking reticle.
	var length: float=clampf((locked_ranged_point-global_position-Vector2(0,-30)).length(),MIN_RANGED_DISTANCE,MAX_RANGED_DISTANCE)
	var end: Vector2=origin+locked_ranged_direction*length
	draw_line(origin+locked_ranged_direction*17,end,Color(.025,.015,.04,.8),5,true)
	draw_dashed_line(origin+locked_ranged_direction*17,end,Color(color,.65),2,8,true)
	draw_line(end+Vector2(-4,-4),end+Vector2(4,4),color,2,true)
	draw_line(end+Vector2(-4,4),end+Vector2(4,-4),color,2,true)
	var font: Font=ThemeDB.fallback_font
	draw_string_outline(font,Vector2(24,-51),"PHÙ",HORIZONTAL_ALIGNMENT_LEFT,-1,12,3,Color(.02,.02,.04))
	draw_string(font,Vector2(24,-51),"PHÙ",HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
func _exit_tree() -> void:
	_clear_bolts();super._exit_tree()

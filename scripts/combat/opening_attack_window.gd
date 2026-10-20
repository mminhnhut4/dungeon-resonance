extends Node
## Opt-in opening room: one committed attack, then a visible counterattack beat.
## Room owns this Node; actors are weak references, no static lifetime or save state.
const COUNTER_BEAT: float=0.35
var feedback: CombatFeedback
var quiet_remaining: float=0.0
var grants: int=0
var releases: int=0
var _actor: WeakRef
var _source_id: int=0
var _pending: Array[Dictionary]=[]
var _tick: int=0
func _physics_process(delta: float) -> void:
	if is_instance_valid(feedback) and feedback.is_frozen():return
	_tick+=1
	if _source_id!=0:
		_retire_if_finished()
	else:quiet_remaining=maxf(0.0,quiet_remaining-delta)
func request(actor: Node2D) -> bool:
	if not is_inside_tree() or actor.get_parent()!=get_parent():return false
	var target: Node=actor.get("player") as Node
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():return false
	if not target is Player:return true # Preserve non-Player/enrage targeting outside this encounter contract.
	if target.health.current_health<=0:return false
	if target.get_parent()!=get_parent() and target.get_parent()!=get_parent().get_parent():return false
	_retire_if_finished()
	if _source_id==actor.get_instance_id():return true
	# FIFO among actors that continue to request while actually in range/ready.
	# A request expires within two non-hitstop ticks after interruption/target loss.
	for i: int in range(_pending.size()-1,-1,-1):
		var waiting: Node=_pending[i]["actor"].get_ref() as Node
		if not is_instance_valid(waiting) or waiting.is_queued_for_deletion() or waiting.get_parent()!=get_parent() or _tick-int(_pending[i]["tick"])>2:_pending.remove_at(i)
	var queued: bool=false
	for entry: Dictionary in _pending:
		if int(entry["id"])==actor.get_instance_id():entry["tick"]=_tick;queued=true;break
	if not queued:_pending.append({"actor":weakref(actor),"id":actor.get_instance_id(),"tick":_tick})
	if _source_id!=0:return false
	if quiet_remaining>0:return false
	if int(_pending[0]["id"])!=actor.get_instance_id():return false
	_pending.pop_front()
	_actor=weakref(actor);_source_id=actor.get_instance_id();grants+=1
	return true
func _retire_if_finished() -> void:
	if _source_id==0:return
	var actor: Node=_actor.get_ref() as Node if _actor!=null else null
	if is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.get_parent()==get_parent() and actor.call("opening_attack_committed"):return
	# A shot already in flight still owns the lane, even after the actor's tell ends.
	for group: StringName in [&"world_enemy_hazards",&"runic_harrier_bolts"]:
		for hazard: Node in get_tree().get_nodes_in_group(group):
			if hazard.get_parent()==get_parent() and not hazard.is_queued_for_deletion() and int(hazard.get("source_id"))==_source_id:return
	_actor=null;_source_id=0;quiet_remaining=COUNTER_BEAT;releases+=1
func current_source_id() -> int:return _source_id

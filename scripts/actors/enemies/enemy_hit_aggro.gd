class_name EnemyHitAggro
extends RefCounted
## Accepted player damage owns a 20s memory. Actor gameplay ticks own elapsed time.
const MEMORY_SECONDS: float=20.0
const MAX_RECENT_HITS: int=128
signal target_lost
var remaining: float=0.0
var sight_suppressed: bool=false
var _owner: WeakRef
var _preferred_player_id: int=0
var _target: WeakRef
var _owner_parent_id: int=0
var _target_parent_id: int=0
var _recent_hits: Dictionary[String,bool]={}
var _watched_health: HealthComponent

func bind(actor: Node,candidate: CharacterBody2D) -> void:
	_owner=weakref(actor)
	_owner_parent_id=actor.get_parent().get_instance_id() if actor.get_parent()!=null else 0
	_preferred_player_id=candidate.get_instance_id() if is_instance_valid(candidate) and candidate is Player else 0

func record(event: DamageEvent,result: DamageResult) -> bool:
	var actor: Node=_owner.get_ref() as Node if _owner!=null else null
	if actor==null or not actor.is_inside_tree() or actor.is_queued_for_deletion() or actor.health.current_health<=0.0: return false
	if result.blocked or not is_finite(result.actual_damage) or result.actual_damage<=0.0 or event.target_id!=actor.get_instance_id(): return false
	var source: Object=instance_from_id(event.source_id) if event.source_id>0 else null
	if not source is Player: return false
	var attacker:=source as Player
	if not attacker.is_inside_tree() or attacker.is_queued_for_deletion() or attacker.get_tree()!=actor.get_tree() or attacker.health.current_health<=0.0: return false
	var scope: Node=actor.get_parent()
	while scope!=null and scope!=attacker.get_parent() and scope!=actor.get_tree().root: scope=scope.get_parent()
	if scope!=attacker.get_parent(): return false # A different scene's player cannot refresh an old encounter.
	if _preferred_player_id>0 and attacker.get_instance_id()!=_preferred_player_id: return false
	if event.source_team_id!=attacker.hurtbox.team_id or not attacker.is_in_group(&"players"): return false
	var key: String="%d:%d:%d"%[event.attack_id,event.hit_window_id,event.target_id]
	if _recent_hits.has(key): return false
	if _recent_hits.size()>=MAX_RECENT_HITS: _recent_hits.erase(_recent_hits.keys()[0])
	_recent_hits[key]=true
	if target()!=attacker:
		_unwatch_target()
		_target=weakref(attacker)
		_watched_health=attacker.health
		_watched_health.died.connect(_on_target_gone)
		attacker.tree_exiting.connect(_on_target_gone)
	_target_parent_id=attacker.get_parent().get_instance_id() if attacker.get_parent()!=null else 0
	remaining=MEMORY_SECONDS
	sight_suppressed=false
	return true

func target() -> Player:
	return _target.get_ref() as Player if _target!=null else null

func active() -> bool:
	return remaining>0.0 and target()!=null

func preferred_player() -> Player:
	var candidate: Object=instance_from_id(_preferred_player_id) if _preferred_player_id>0 else null
	return candidate as Player if candidate is Player else null

func advance(delta: float) -> bool:
	if remaining<=0.0: return false
	var actor: Node=_owner.get_ref() as Node if _owner!=null else null
	var attacker: Player=target()
	if actor==null or not actor.is_inside_tree() or actor.health.current_health<=0.0 or attacker==null or not attacker.is_inside_tree() or attacker.health.current_health<=0.0:
		forget();return true
	if actor.get_parent()==null or actor.get_parent().get_instance_id()!=_owner_parent_id or attacker.get_parent()==null or attacker.get_parent().get_instance_id()!=_target_parent_id:
		forget();return true
	if is_finite(delta) and delta>0.0: remaining=maxf(0.0,remaining-delta)
	if remaining<=0.000001:
		forget();return true
	return false

func _on_target_gone() -> void:
	forget()

func _unwatch_target() -> void:
	var attacker: Player=target()
	if is_instance_valid(attacker) and attacker.tree_exiting.is_connected(_on_target_gone): attacker.tree_exiting.disconnect(_on_target_gone)
	if is_instance_valid(_watched_health) and _watched_health.died.is_connected(_on_target_gone): _watched_health.died.disconnect(_on_target_gone)
	_watched_health=null

func forget(notify: bool=true) -> void:
	var had_target: bool=remaining>0.0 or _target!=null
	_unwatch_target()
	remaining=0.0
	_target=null
	_target_parent_id=0
	sight_suppressed=true # Expiry must not instantly reacquire the same visible player.
	if had_target and notify: target_lost.emit()

func release() -> void:
	forget(false)
	_owner=null
	_preferred_player_id=0
	_recent_hits.clear()

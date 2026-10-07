class_name DamageNumberSpawner
extends Node2D
## Optional room-owned presentation. Actors use their existing number path
## unless explicitly assigned this component by the Prologue Hub.

const TEXT_SCENE: PackedScene = preload("res://scenes/effects/floating_combat_text.tscn")
const MAX_ACTIVE: int = 32
const MAX_RECENT_RESULTS: int = 64

var total_spawned: int = 0
var _active_ids: Array[int] = []
var _recent_results: Dictionary[int, bool] = {}


func spawn_damage(event: DamageEvent, result: DamageResult, world_position: Vector2, feedback: CombatFeedback = null) -> FloatingCombatText:
	if event == null or result == null or result.blocked or not is_finite(result.actual_damage) or result.actual_damage <= 0.0 or not is_inside_tree() or is_queued_for_deletion():
		return null
	var result_id: int = result.get_instance_id()
	if _recent_results.has(result_id):
		return null
	if _recent_results.size() >= MAX_RECENT_RESULTS:
		_recent_results.erase(_recent_results.keys()[0])
	_recent_results[result_id] = true
	_prune_expired()
	if _active_ids.size() >= MAX_ACTIVE:
		var oldest: Node = instance_from_id(_active_ids.pop_front()) as Node
		if is_instance_valid(oldest):
			oldest.queue_free()
	var text: FloatingCombatText = TEXT_SCENE.instantiate() as FloatingCombatText
	add_child(text)
	text.global_position = world_position
	text.setup(result.actual_damage, event.attack_direction, feedback, event.critical, &"prologue")
	_active_ids.append(text.get_instance_id())
	total_spawned += 1
	return text


func active_count() -> int:
	_prune_expired()
	return _active_ids.size()


func clear_numbers() -> void:
	for id: int in _active_ids:
		var text: Node = instance_from_id(id) as Node
		if is_instance_valid(text):
			text.queue_free()
	_active_ids.clear()
	_recent_results.clear()


func _prune_expired() -> void:
	for index: int in range(_active_ids.size() - 1, -1, -1):
		var text: Node = instance_from_id(_active_ids[index]) as Node
		if not is_instance_valid(text) or text.is_queued_for_deletion():
			_active_ids.remove_at(index)


func _exit_tree() -> void:
	_active_ids.clear()
	_recent_results.clear()

class_name ActorStateMachine
extends Node
## Explicit enter/exit lifecycle; Player owns the order of the two FSM ticks.

signal state_changed(previous_id: StringName, next_id: StringName)

@export var initial_state: ActorState
var current_state: ActorState
var _states: Dictionary[StringName, ActorState] = {}


func initialize(context: Node) -> void:
	_states.clear()
	for child: Node in get_children():
		if child is ActorState:
			var state := child as ActorState
			assert(not state.state_id.is_empty(), "State needs a state_id")
			assert(not _states.has(state.state_id), "Duplicate state_id")
			_states[state.state_id] = state
			state.setup(context)
	assert(initial_state != null and _states.has(initial_state.state_id))
	transition_to(initial_state.state_id)


func transition_to(next_id: StringName) -> void:
	assert(_states.has(next_id), "Unknown state: %s" % next_id)
	if current_state == _states[next_id]:
		return
	var previous_id: StringName = get_state_id()
	if current_state != null:
		current_state.exit(next_id)
	current_state = _states[next_id]
	current_state.enter(previous_id)
	state_changed.emit(previous_id, next_id)


func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func register_state(state: ActorState, context: Node) -> bool:
	# Add actor-owned actions without reinitializing the live FSM.
	if state == null or state.state_id.is_empty() or _states.has(state.state_id): return false
	add_child(state)
	state.setup(context)
	_states[state.state_id] = state
	return true


func unregister_state(id: StringName) -> bool:
	if not _states.has(id) or current_state == _states[id] or initial_state == _states[id]: return false
	var state: ActorState = _states[id]
	_states.erase(id)
	state.queue_free()
	return true


func get_state_id() -> StringName:
	return current_state.state_id if current_state != null else &""

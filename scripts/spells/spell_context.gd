class_name SpellContext
extends RefCounted
## One cast's finite proc/target ledger, shared by its three branching blades.

var snapshot: SpellSnapshot
var primary_targets: Dictionary[int, bool] = {}
var visited_targets: Dictionary[int, bool] = {}
var remaining_chain: int = 0
var effect_triggered: bool = false


func _init(payload: SpellSnapshot = null) -> void:
	snapshot = payload
	if payload != null:
		remaining_chain = payload.chain_targets

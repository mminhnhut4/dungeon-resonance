class_name OpeningProgress
extends RefCounted
## Optional, bounded v1 milestones. Observation never gates travel or combat.
const IDS: Array[StringName] = [&"explored", &"golem_defeated", &"reward_collected", &"returned_to_hub", &"thanh_vy_met", &"first_upgrade"]

static func empty() -> Dictionary:
	return {"version": 1, "completed": []}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1 or not data.get("completed") is Array or data["completed"].size() > IDS.size(): return false
	var seen: Array[StringName] = []
	for value: Variant in data["completed"]:
		if not (value is String or value is StringName): return false
		var id := StringName(value)
		if id not in IDS or id in seen: return false
		seen.append(id)
	return true

static func future(data: Variant) -> bool:
	if not data is Dictionary: return false
	var version: Variant = data.get("version", 0)
	return (version is int or version is float) and float(version) > 1.0

static func with_event(data: Dictionary, id: StringName) -> Dictionary:
	var next: Dictionary = data.duplicate(true)
	if id in IDS and not next["completed"].has(String(id)): next["completed"].append(String(id))
	return next

static func snapshot(data: Dictionary) -> Dictionary:
	var completed: Array = data["completed"].duplicate()
	var next_id: StringName = &""
	for id: StringName in IDS:
		if not completed.has(String(id)):
			next_id = id
			break
	return {"version": 1, "completed": completed, "next_id": next_id, "complete": next_id == &""}

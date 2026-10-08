class_name DepthProgress
extends RefCounted
## Additive expedition receipts use the existing sealed profile transaction owner.
const SCOPE: String = "depth_expedition_v1"
var profile: SanctuaryProfile

func initialize(owner: SanctuaryProfile) -> void:
	profile = owner
	profile.register_extension_validator(SCOPE, valid)

static func empty() -> Dictionary:
	return {"version": 1, "accepted": false, "cleared": 0, "boss_defeated": false}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4: return false
	if value.get("version") != 1 or not value.get("accepted") is bool or not value.get("boss_defeated") is bool: return false
	var cleared: Variant = value.get("cleared")
	if not (cleared is int or cleared is float) or float(cleared) != floorf(float(cleared)) or cleared < 0 or cleared > 5: return false
	return (cleared == 0 or value["accepted"]) and (not value["boss_defeated"] or cleared == 5)

func state() -> Dictionary:
	var stored: Dictionary = profile.extension_state(SCOPE)
	return empty() if stored.is_empty() else stored

func available() -> bool:
	return profile != null and profile.profile_version == 2 and profile.extension_transactions_available(SCOPE)

func unlocked() -> bool:
	return profile != null and profile.opening_progress.get("completed", []).has("golem_defeated")

func can_start_floor(floor_number: int) -> bool:
	# Read-only replay policy: clearing N does not unlock a direct launch into N+1.
	if floor_number < 1 or floor_number > 5 or not unlocked() or not available(): return false
	var current: Dictionary = state()
	return valid(current) and current["accepted"] and floor_number <= maxi(1,int(current["cleared"]))

func accept() -> bool:
	if not unlocked() or not available(): return false
	var next: Dictionary = state()
	if next["accepted"]: return true
	next["accepted"] = true
	return _commit("depth_accept_v1", next)

func record(event_id: StringName, floor_number: int) -> bool:
	if not available() or floor_number < 1 or floor_number > 5: return false
	var next: Dictionary = state()
	if not next["accepted"]: return false
	if event_id == &"depth_boss_defeated":
		if floor_number != 5: return false
		if next["boss_defeated"]: return true
		if int(next["cleared"]) < 4: return false
		next["cleared"] = 5
		next["boss_defeated"] = true
	elif String(event_id) == "depth_floor_%d" % floor_number:
		if int(next["cleared"]) >= floor_number: return true
		if floor_number > int(next["cleared"]) + 1: return false
		next["cleared"] = floor_number
	else: return false
	return _commit(String(event_id), next)

func _commit(event_id: String, next: Dictionary) -> bool:
	return bool(profile.commit_extension_event(SCOPE, event_id, {}, 0, next, profile.extension_revision(SCOPE)).get("ok", false))

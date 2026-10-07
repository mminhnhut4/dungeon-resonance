class_name ExteriorProgress
extends RefCounted
## Independently versioned, additive v1 extension. Contains no item/HP ledger.
static func empty() -> Dictionary:
	return {"version":1,"room_id":String(ExteriorRouteCatalog.HUB),"region_id":String(ExteriorRouteCatalog.HUB),"route_id":"main","anchor_id":"road","discovered_rooms":[],"notes":[],"sc01_open":false}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or not (data.get("version",null) is int or data.get("version",null) is float) or data.get("version",0) != 1: return false
	for field: String in ["room_id","region_id","route_id","anchor_id"]:
		if not data.get(field,null) is String: return false
	var room := StringName(data["room_id"])
	if String(ExteriorRouteCatalog.region(room)) != data["region_id"] or not ExteriorRouteCatalog.valid_anchor(room,StringName(data["route_id"]),StringName(data["anchor_id"])): return false
	if not data.get("sc01_open",null) is bool: return false
	if not _valid_ids(data.get("discovered_rooms",null),ExteriorRouteCatalog.ROOMS) or not _valid_ids(data.get("notes",null),ExteriorRouteCatalog.NOTES): return false
	return true

static func _valid_ids(values: Variant, allowed: Array[StringName]) -> bool:
	if not values is Array or values.size() > allowed.size(): return false
	var seen: Array[String] = []
	for value: Variant in values:
		if not value is String or StringName(value) not in allowed or seen.has(value): return false
		seen.append(value)
	return true

static func future(data: Variant) -> bool:
	return data is Dictionary and (data.get("version",null) is int or data.get("version",null) is float) and float(data.get("version",0)) > 1.0

static func used(data: Dictionary) -> bool:
	return data["room_id"] != String(ExteriorRouteCatalog.HUB) or data["sc01_open"] or not data["discovered_rooms"].is_empty() or not data["notes"].is_empty()

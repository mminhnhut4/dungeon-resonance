class_name TraversalLabCheckpoint
extends RefCounted
## A QA-only checkpoint. No discovery, quest reward or carried item ledger.
var path: String = "user://verification/traversal_lab_anchor_v1.json"
var room: StringName = TraversalLabRoom.IDS[0]
var anchor: StringName = &"west"
var gate_open: bool = false
var reject_commit: bool = false
var recovered_backup: bool = false

func payload() -> Dictionary:
	return {"version":1,"room_id":String(room),"anchor_id":String(anchor),"gate_open":gate_open}

func valid(data: Variant) -> bool:
	if not data is Dictionary or not (data.get("version",null) is int or data.get("version",null) is float) or data.get("version",0) != 1: return false
	if not data.get("room_id",null) is String or StringName(data["room_id"]) not in TraversalLabRoom.IDS: return false
	if not data.get("anchor_id",null) is String or data["anchor_id"] not in ["west","east","checkpoint"]: return false
	if data["anchor_id"] == "checkpoint" and data["room_id"] != String(TraversalLabRoom.IDS[2]): return false
	return data.get("gate_open",null) is bool

func save() -> bool:
	if reject_commit or not path.begins_with("user://verification/") or not valid(payload()): return false
	if _future(_read(path)): return false
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(payload()))
	file.flush()
	var wrote: bool = file.get_error() == OK
	file.close()
	if not wrote or not valid(_read(path+".tmp")): return false
	var atomic := SanctuaryProfile.new()
	if valid(_read(path)):
		if atomic._copy_file(path,path+".bak.tmp") != OK or not atomic._replace_file(path+".bak.tmp",path+".bak"): return false
	return atomic._replace_file(path+".tmp",path)

func load_checkpoint() -> bool:
	var data: Variant = _read(path)
	recovered_backup = false
	if _future(data): return false
	if not valid(data):
		data = _read(path+".bak")
		recovered_backup = true
	if not valid(data): return false
	room = StringName(data["room_id"])
	anchor = StringName(data["anchor_id"])
	gate_open = data["gate_open"]
	return true

func _future(data: Variant) -> bool:
	return data is Dictionary and (data.get("version",null) is int or data.get("version",null) is float) and float(data.get("version",0)) > 1.0

func _read(source: String) -> Variant:
	var file := FileAccess.open(source,FileAccess.READ)
	if file == null: return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return data

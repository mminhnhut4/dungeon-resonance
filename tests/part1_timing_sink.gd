extends RefCounted
static var enabled: bool = false
static var events: Array[Dictionary] = []
static func record(label: String, started: int) -> void:
	if not enabled or events.size()>=20000: return
	events.append({"label":label,"from_usec":started,"to_usec":Time.get_ticks_usec(),"process_frame":Engine.get_process_frames()})

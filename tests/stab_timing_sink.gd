extends RefCounted
static var enabled: bool=true
static var events: Array[Dictionary]=[]
static var hitstops: Array[Dictionary]=[]
static func record(label: String,started: int) -> void:
	if enabled and events.size()<30000:events.append({"label":label,"start":started,"end":Time.get_ticks_usec(),"frame":Engine.get_process_frames()})
static func hitstop(started: int,deadline: int) -> void:
	if enabled and deadline>started:hitstops.append({"start":started,"end":deadline})

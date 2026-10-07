class_name CombatIds
extends RefCounted
## Session serial stored as scalar metadata on the current MainLoop.
## Avoid retained GDScript static-variable resources during validation/unload.


static func next_id() -> int:
	var loop: MainLoop = Engine.get_main_loop()
	var serial: int = int(loop.get_meta(&"dungeon_combat_serial", 0)) + 1
	loop.set_meta(&"dungeon_combat_serial", serial)
	return serial

static func reserve_through(uid: int) -> void:
	var loop: MainLoop = Engine.get_main_loop()
	loop.set_meta(&"dungeon_combat_serial", maxi(uid, int(loop.get_meta(&"dungeon_combat_serial", 0))))

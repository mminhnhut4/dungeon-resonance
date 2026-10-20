class_name TanDangHomeCatalog
extends RefCounted
## The existing Tàn Đăng order's home. Progress remains owned by TanDangProgress.
const ROOM: StringName = &"td01_lantern_court"
const REGION: StringName = &"tan_dang"
const HUB_DOOR: StringName = &"tan_dang_home"
const TITLE: String = "Tàn Đăng Môn · Sân đèn"
const WIDTH: float = 2200.0
const FLOOR_Y: float = 640.0
const DEPUTY_X: float = 700.0
const LEADER_X: float = 1550.0

static func layout() -> Dictionary:
	# Match the existing heightfield conversion (BASE_Y=2100, H=115) without
	# loading ExteriorRouteCatalog back through its preload of this catalog.
	var height: float = (2100.0-FLOOR_Y)/115.0
	return {"start":height,"beats":[Vector2(WIDTH,height)]}

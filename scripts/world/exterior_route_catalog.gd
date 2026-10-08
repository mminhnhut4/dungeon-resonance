class_name ExteriorRouteCatalog
extends RefCounted
## Authored first prototype. Widths follow the measured motor, not diagram scale.
const HUB: StringName = &"h00_traveler_hub"
const MAIN: StringName = &"main"
const TUNNEL: StringName = &"guard_corridor"
const ROOMS: Array[StringName] = [&"o01_p01",&"o01_p02",&"o01_p03",&"o01_p04",&"o02_b01",&"o02_b02",&"o02_b03",&"o02_b04"]
const NOTES: Array[StringName] = [&"water_marks",&"post_office_record",&"shipyard_record",&"hanh_encounter"]
const TITLES: Array[String] = ["Đèn nghiêng và bậc đá","Cầu dây và khe nước","Miếu đèn và con dấu","Ba terrace xuống bến","Cột nước chân núi","Phố thấp / quảng trường cao","Bưu trạm cũ và kho","Xưởng Hạnh và cầu tàu"]
const H: float = 115.0
const U: float = 229.0
const B: float = 20.0
const C: float = 36.0
const SAFE_ANGLE: float = 10.0
const BASE_Y: float = 2100.0

static func all_rooms() -> Array[StringName]:
	var rooms: Array[StringName]=ROOMS.duplicate()
	rooms.append_array(SectRouteCatalog.ROOMS)
	return rooms

static func region(room: StringName) -> StringName:
	if room in SectRouteCatalog.ROOMS: return StringName(SectRouteCatalog.faction(room))
	if room == HUB: return HUB
	var index: int = ROOMS.find(room)
	return &"o01_duong_hanh_huong" if index >= 0 and index < 4 else &"o02_ben_tram" if index >= 4 else &""

static func valid_route(room: StringName, route: StringName) -> bool:
	return (room == HUB or room in ROOMS or room in SectRouteCatalog.ROOMS) and (route == MAIN or (room == ROOMS[1] and route == TUNNEL))

static func valid_anchor(room: StringName, route: StringName, anchor: StringName) -> bool:
	if not valid_route(room,route): return false
	if room == HUB: return anchor == &"road"
	if anchor == &"sect" and route == MAIN: return room in [&"o01_p03",&"o02_b04"]
	if anchor in [&"west",&"east"]: return true
	if route == TUNNEL: return false
	return (anchor == &"tunnel" and room in [ROOMS[0],ROOMS[2]]) or (anchor == &"shrine" and room == ROOMS[2]) or (anchor == &"water" and room == ROOMS[4]) or (anchor == &"shipyard" and room == ROOMS[7])

static func title(room: StringName, route: StringName = MAIN) -> String:
	if room == HUB: return "Căn Cứ Lữ Khách"
	if room in SectRouteCatalog.ROOMS: return SectRouteCatalog.title(room)
	var index: int = ROOMS.find(room)
	if index < 0: return ""
	return "P02 · Đường giữ đèn" if route == TUNNEL else ("P%02d" % (index+1) if index < 4 else "B%02d" % (index-3)) + " · " + TITLES[index]

static func layout(room: StringName, route: StringName) -> Dictionary:
	if not valid_route(room,route) or room == HUB: return {}
	if room in SectRouteCatalog.ROOMS: return SectRouteCatalog.layout(room)
	if route == TUNNEL: return {"start":5.0,"beats":[Vector2(800,5),Vector2(680,4),Vector2(360,4)]}
	match room:
		&"o01_p01": return {"start":5.0,"beats":[Vector2(400,5),Vector2(860,6.3),Vector2(360,6.3),Vector2(540,5.5),Vector2(260,5.5)]}
		&"o01_p02": return {"start":5.5,"beats":[Vector2(240,5.5),Vector2(480,6.2),Vector2(460,6.2),Vector2(1260,4.3),Vector2(360,4.3),Vector2(220,4),Vector2(260,4)]}
		&"o01_p03": return {"start":4.0,"beats":[Vector2(400,4),Vector2(740,5.1),Vector2(600,5.1),Vector2(680,4.1),Vector2(260,4.1)]}
		# Refined T07: three long descending terraces, continuous x progress.
		# Literal stacked right-left-right hairpins remain superseded, not passed.
		&"o01_p04": return {"start":4.1,"beats":[Vector2(240,4.1),Vector2(340,4.6),Vector2(320,4.6),Vector2(860,3.3),Vector2(360,3.3),Vector2(180,3.05),Vector2(160,3.05),Vector2(560,2.2),Vector2(400,2.2),Vector2(680,1.2),Vector2(360,1.2),Vector2(280,0.8),Vector2(260,0.8)]}
		&"o02_b01": return {"start":0.8,"beats":[Vector2(260,0.8),Vector2(540,1.6),Vector2(460,1.6),Vector2(540,0.8),Vector2(260,0.8)]}
		&"o02_b02": return {"start":0.8,"beats":[Vector2(280,0.8),Vector2(340,1.3),Vector2(700,1.3),Vector2(340,0.8),Vector2(280,0.8)]}
		&"o02_b03": return {"start":0.8,"beats":[Vector2(280,0.8),Vector2(940,2.2),Vector2(600,2.2),Vector2(820,1),Vector2(480,1),Vector2(260,1)]}
		&"o02_b04": return {"start":1.0,"beats":[Vector2(260,1),Vector2(220,1.3),Vector2(600,1.3),Vector2(340,0.8),Vector2(600,0.8),Vector2(260,0.8)]}
	return {}

static func link(room: StringName, route: StringName, door: StringName) -> Dictionary:
	if route==MAIN and (room in SectRouteCatalog.ROOMS or door==&"sect_branch"): return SectRouteCatalog.link(room,door)
	if route == TUNNEL:
		return {"room":ROOMS[0] if door == &"door_west" else ROOMS[2],"route":MAIN,"anchor":&"tunnel"}
	if door == &"tunnel": return {"room":ROOMS[1],"route":TUNNEL,"anchor":&"west" if room == ROOMS[0] else &"east"}
	var index: int = ROOMS.find(room)
	if index < 0: return {}
	if door == &"door_west": return {"room":HUB,"route":MAIN,"anchor":&"road"} if index == 0 else {"room":ROOMS[index-1],"route":MAIN,"anchor":&"east"}
	if door == &"door_east" and index < ROOMS.size()-1: return {"room":ROOMS[index+1],"route":MAIN,"anchor":&"west"}
	return {}

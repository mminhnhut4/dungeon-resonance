class_name SectRouteCatalog
extends RefCounted
## Additive branches. The original eight-room road keeps its stable IDs and order.
const ROOMS: Array[StringName] = [&"tv01_cloud_gate",&"tv02_pine_court",&"xl01_red_causeway",&"xl02_cooling_yard"]
const FACTIONS: Array[String] = ["thanh_van","xich_lo"]
const LABELS: Dictionary = {"thanh_van":"Thanh Vân Môn","xich_lo":"Xích Lô Phái"}
const NAMES: Array[String] = ["Vân Quan","Tùng Đình","Đê Đất Đỏ","Sân Dẫn Thủy"]
const STEWARDS: Dictionary = {"thanh_van":"thanh_van_steward_01","xich_lo":"xich_lo_steward_01"}
const ROAD_ROOMS: Dictionary = {"thanh_van":&"o01_p03","xich_lo":&"o02_b04"}
const ROAD_X: Dictionary = {"thanh_van":1240.0,"xich_lo":580.0}
const MARKERS: Dictionary = {"thanh_van":[850.0,1520.0],"xich_lo":[800.0,1780.0]}
const DESCRIPTIONS: Dictionary = {
	"thanh_van":["Cột dây gió phía tây: dây còn căng, nhưng dấu niêm đã quay ngược chiều gió. Không thấy dấu người cố ý cắt dây.","Đèn dẫn đường phía đông: bệ đá còn nguyên, dấu mực cùng kiểu với cột phía tây. Cần giữ cả hai ghi chép trước khi kết luận."],
	"xich_lo":["Miệng kênh trên đê: vạch nước thấp hơn dấu cũ, không có vật chắn mới. Một vạch nước chưa cho biết ai chịu trách nhiệm.","Van đồng phía đông: mối nối còn kín, lớp cặn đi cùng hướng dòng cũ. Ghi riêng quan sát này để đối chiếu với miệng kênh."]
}

static func faction(room: StringName) -> String:
	var index: int=ROOMS.find(room)
	return "" if index<0 else FACTIONS[0 if index<2 else 1]

static func first(faction_id: String) -> StringName:
	return ROOMS[0] if faction_id=="thanh_van" else ROOMS[2] if faction_id=="xich_lo" else &""

static func title(room: StringName) -> String:
	var index: int=ROOMS.find(room)
	return "" if index<0 else "%s · %s" % [LABELS[faction(room)],NAMES[index]]

static func layout(room: StringName) -> Dictionary:
	match room:
		&"tv01_cloud_gate": return {"start":5.1,"beats":[Vector2(400,5.1),Vector2(620,6.0),Vector2(400,6.0),Vector2(540,6.5),Vector2(640,6.5)]}
		&"tv02_pine_court": return {"start":6.5,"beats":[Vector2(600,6.5),Vector2(500,6.9),Vector2(750,6.9),Vector2(600,6.5),Vector2(450,6.5)]}
		&"xl01_red_causeway": return {"start":1.0,"beats":[Vector2(600,1.0),Vector2(500,1.35),Vector2(650,1.35),Vector2(500,.9),Vector2(550,.9)]}
		&"xl02_cooling_yard": return {"start":.9,"beats":[Vector2(800,.9),Vector2(400,1.3),Vector2(1000,1.3),Vector2(400,.9),Vector2(600,.9)]}
	return {}

static func link(room: StringName, door: StringName) -> Dictionary:
	for id: String in FACTIONS:
		if room==ROAD_ROOMS[id] and door==&"sect_branch": return {"room":first(id),"route":&"main","anchor":&"west"}
	var index: int=ROOMS.find(room)
	if index<0: return {}
	if door==&"door_west":
		return {"room":ROAD_ROOMS[faction(room)],"route":&"main","anchor":&"sect"} if index%2==0 else {"room":ROOMS[index-1],"route":&"main","anchor":&"east"}
	if door==&"door_east" and index%2==0: return {"room":ROOMS[index+1],"route":&"main","anchor":&"west"}
	return {}

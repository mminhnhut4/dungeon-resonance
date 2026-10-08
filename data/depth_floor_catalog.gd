class_name DepthFloorCatalog
extends RefCounted
## Read-only five-floor expedition content. Rewards still use the existing loot owner.
const FLOOR_COUNT: int = 5
const ENTRY: Vector2 = Vector2(180,640)
const EXIT: Vector2 = Vector2(1230,640)
const PORTAL: Vector2 = Vector2(1160,640)
const FLOORS: Array[Dictionary] = [
	{"id":&"van_thach","name":"VÂN THẠCH · Tàn tích canh giữ","enemy":&"depth_stone_guard","count":3,"tactic":"Né nhát quét đã báo; đánh vào lúc vệ binh hồi phục. Bùa theo hướng chuột.","palette":Color("697b83"),"ambient":Color(.72,.77,.84),"shelves":[Rect2(90,548,120,16),Rect2(200,452,280,16),Rect2(450,356,230,16),Rect2(800,452,290,16),Rect2(1080,548,100,16)],"secret":Vector2(560,356)},
	{"id":&"moc_can","name":"MỘC CĂN · Vòm rễ nấm","enemy":&"depth_root_bat","count":4,"tactic":"Gần: bổ nhào; xa: bào tử. Rời hướng ngắm đã khóa; đánh khi bào dực rút lên.","palette":Color("638573"),"ambient":Color(.68,.84,.71),"shelves":[Rect2(70,546,110,16),Rect2(210,452,250,16),Rect2(450,356,290,16),Rect2(780,452,280,16),Rect2(1080,546,100,16)],"secret":Vector2(580,356)},
	{"id":&"han_kinh","name":"HÀN KÍNH · Sảnh gương lạnh","enemy":&"depth_frost_wraith","count":4,"tactic":"Kiếm hồn khóa hướng trước cú xuyên; lướt lệch đường ngắm, phản công lúc hồi chiêu.","palette":Color("7a9fae"),"ambient":Color(.72,.85,.94),"shelves":[Rect2(70,552,110,16),Rect2(210,460,200,16),Rect2(400,368,230,16),Rect2(670,368,220,16),Rect2(920,460,180,16),Rect2(1100,552,80,16)],"secret":Vector2(515,368)},
	{"id":&"xich_lo","name":"XÍCH LÔ · Lò rèn phong ấn","enemy":&"depth_forge_champion","count":3,"tactic":"Rời vòng phù trận dưới chân; phá giáp khi hộ vệ lùi hồi chiêu, tung bùa cộng hưởng.","palette":Color("aa785a"),"ambient":Color(.92,.76,.64),"shelves":[Rect2(70,536,120,16),Rect2(210,438,250,16),Rect2(440,340,290,16),Rect2(790,438,280,16),Rect2(1100,536,80,16)],"secret":Vector2(585,340)},
	{"id":&"u_minh_thap","name":"U MINH THÁP · Thủ lĩnh phong ấn","enemy":&"depth_seal_warden","count":1,"tactic":"Đọc dấu báo đòn; pha hai đổi nhịp và gọi hộ vệ. Tận dụng hồi phục để phản công.","palette":Color("8871a3"),"ambient":Color(.79,.69,.9),"shelves":[Rect2(60,540,180,16),Rect2(1040,540,180,16)],"secret":Vector2.ZERO}
]
static func valid(number: int) -> bool: return number >= 1 and number <= FLOOR_COUNT
static func floor_data(number: int) -> Dictionary:
	return FLOORS[number-1].duplicate(true) if valid(number) else {}
static func background_path(number: int) -> String:
	return "res://assets/environment/depth_v1/floor_%d.png" % number if valid(number) else ""
static func enemy_anchors(number: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not valid(number): return result
	var count: int = int(FLOORS[number-1]["count"])
	for index: int in count:
		result.append(Vector2(580+index*155,520 if number==2 else 560 if number==3 else 640))
	return result

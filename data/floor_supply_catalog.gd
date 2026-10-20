extends RefCounted
## One read-only source contract for drops and the separate M board.
## These are guaranteed supplements, never an exclusive-item claim or a loot-pool rewrite.
const Floors=preload("res://data/depth_floor_catalog.gd")
const Progress=preload("res://scripts/runtime/depth_progress.gd")
const VERSION: int=2
const SOURCES: Array[Dictionary]=[
	{"id":&"seal_van_thach_dust","floor":1,"floor_id":&"van_thach","global_floor":4,"item":&"dust","quantity":2,"chance":1.0,"exclusive":false},
	{"id":&"seal_moc_can_crystal","floor":2,"floor_id":&"moc_can","global_floor":5,"item":&"crystal","quantity":1,"chance":1.0,"exclusive":false},
	{"id":&"seal_moc_can_dust_v2","floor":2,"floor_id":&"moc_can","global_floor":5,"item":&"dust","quantity":2,"chance":1.0,"exclusive":false}
]
static func sources_for_floor(number: int) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for source: Dictionary in SOURCES:
		if source["floor"]==number:result.append(source.duplicate(true))
	return result
static func drop_point(number: int) -> Vector2:
	return Vector2(Floors.room_width(number)-320.0,640)
static func view(source: Dictionary,profile: SanctuaryProfile,inventory: GearInventory) -> Dictionary:
	var state: Dictionary=Progress.empty()
	var gate: String="Hạ Golem tầng3, nhận bản đồ ở Lạc Ấn."
	var can_revisit: bool=false
	if profile!=null:
		var progress: RefCounted=Progress.new();progress.initialize(profile);state=progress.state()
		can_revisit=progress.can_start_floor(int(source["floor"]))
		if not progress.available():gate="Hồ sơ tầng sâu chưa sẵn sàng; không thay đổi tiến độ."
		elif not progress.unlocked():gate="Hạ Golem tầng3 để mở hành trình tầng4–8."
		elif not state["accepted"]:gate="Gặp Lạc Ấn tại căn cứ → Nhận bản đồ."
		elif not can_revisit:gate="Chưa hoàn tất tầng này. Dọn tầng trước rồi qua cửa E để đi tiếp."
		else:gate="Đã hoàn tất · Lạc Ấn → chọn tầng%d để quay lại."%source["global_floor"]
	var item: StringName=source["item"]
	var required: int=int(RuneLearningService.CRAFT_COST.get(item,0))
	var have: int=int(inventory.materials.get(item,0)) if inventory!=null else 0
	return {"id":source["id"],"title":"TẦNG %d · %s"%[source["global_floor"],Floors.floor_data(source["floor"])["name"]],"objective":"Dọn quái rồi nhặt gói vật liệu trên đường gần cuối tầng.","source":"%s ×%d · Bảo đảm100%% sau khi dọn; một lần mỗi chuyến mới."%[MaterialCatalog.DISPLAY_NAMES[item],source["quantity"]],"unlock":gate,"progress":"Túi %d/%d cho một lần chế · %s"%[have,required,"đủ" if have>=required else "thiếu %d"%maxi(0,required-have)],"can_revisit":can_revisit,"have":have,"required":required,"exclusive":false}

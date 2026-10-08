class_name CultivatorCatalog
extends RefCounted
## Combat/presentation prototype only. NpcPilotCatalog owns world placement.
const IDS: Array[String] = ["thanh_van_disciple_01", "xich_lo_guard_01"]
const PORTRAITS: Dictionary = {
	"thanh_van_disciple_01": preload("res://assets/npc/cultivators/thanh_van_disciple.png"),
	"xich_lo_guard_01": preload("res://assets/npc/cultivators/xich_lo_guard.png")
}
const SPECS: Dictionary = {
	"thanh_van_disciple_01": {"sect":"Thanh Vân Môn", "style":"Kiếm · Giữ khoảng trống", "tint":Color(0.68,0.90,1.0), "damage":8.0, "speed":70.0, "spacing":62.0, "reach":88.0, "height":48.0, "tell":0.65, "active":0.14, "recover":0.7, "hurt":0.35, "aggro":8.0, "leash":180.0},
	"xich_lo_guard_01": {"sect":"Xích Lô Phái", "style":"Hộ vệ · Trọng đòn", "tint":Color(1.0,0.76,0.57), "damage":14.0, "speed":44.0, "spacing":38.0, "reach":70.0, "height":56.0, "tell":0.95, "active":0.18, "recover":1.05, "hurt":0.4, "aggro":8.0, "leash":180.0}
}

static func definition(id: String) -> Dictionary:
	return SPECS.get(id,{}).duplicate(true)

static func portrait(id: String) -> Texture2D:
	return PORTRAITS.get(id)

static func dialogue_lines(id: String) -> Array[String]:
	match id:
		"thanh_van_disciple_01": return [
			"Ta là đệ tử Thanh Vân, được cử giữ đoạn đường này. Người qua núi mang theo hàng hóa, thư từ và cả lời đồn. Giữ đường thông thì dễ; giữ cho lời kể còn nguyên mới khó.",
			"Có lời đồn dấu niêm ở miếu đèn không khớp với bản ghi tại bưu trạm Bến Trầm. Ta chưa thấy đủ hai bản để kết tội ai. Miếu còn đó, hồ sơ dưới bến cũng còn; chuyện này cần người chịu nhìn cho kỹ."
		]
		"xich_lo_guard_01": return [
			"Ta là hộ vệ Xích Lô. Người dưới bến sống nhờ lò, xưởng và những chuyến hàng còn qua được đường núi. Ta mang đao để giữ lối về; không phải ai mặc giáp đỏ cũng muốn gây chuyện.",
			"Ta cũng nghe chuyện dấu niêm khác nhau. Nhưng một lời đồn chưa đủ buộc tội cả xưởng. Bưu trạm cũ ở Bến Trầm vẫn giữ hồ sơ trên nền cao; hãy để dấu mực lên tiếng trước khi rút kiếm."
		]
	return []

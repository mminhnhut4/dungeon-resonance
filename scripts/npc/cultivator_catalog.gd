class_name CultivatorCatalog
extends RefCounted
## Combat/presentation prototype only. NpcPilotCatalog owns world placement.
const IDS: Array[String] = ["thanh_van_disciple_01", "xich_lo_guard_01", "thanh_van_steward_01", "xich_lo_steward_01"]
const TAN_DANG_IDS: Array[String] = ["tan_dang_moc_yen", "tan_dang_lam_tuoc", "tan_dang_du_hanh"]
const UNIFORMS: Dictionary={"thanh_van_steward_01":"thanh_van_disciple_01","xich_lo_steward_01":"xich_lo_guard_01"}
const PORTRAITS: Dictionary = {
	"thanh_van_disciple_01": preload("res://assets/npc/cultivators/thanh_van_disciple.png"),
	"xich_lo_guard_01": preload("res://assets/npc/cultivators/xich_lo_guard.png")
}
const SPECS: Dictionary = {
	"thanh_van_disciple_01": {"sect":"Thanh Vân Môn", "style":"Kiếm · Giữ khoảng trống", "skill":"Vân Kiếm", "pattern":"thrust", "tint":Color(0.68,0.90,1.0), "damage":8.0, "speed":70.0, "spacing":62.0, "reach":88.0, "height":48.0, "tell":0.65, "active":0.14, "recover":0.7, "cooldown":1.5, "hurt":0.35, "aggro":20.0, "leash":180.0},
	"xich_lo_guard_01": {"sect":"Xích Lô Phái", "style":"Hộ vệ · Trọng đòn", "skill":"Xích Lô Trảm", "pattern":"cleave", "tint":Color(1.0,0.76,0.57), "damage":14.0, "speed":44.0, "spacing":38.0, "reach":70.0, "height":56.0, "tell":0.95, "active":0.18, "recover":1.05, "cooldown":2.2, "hurt":0.4, "aggro":20.0, "leash":180.0},
	"tan_dang_moc_yen": {"sect":"Tàn Đăng Môn", "style":"Phù ấn · Khóa điểm đã báo", "skill":"Hộ Đăng Ấn", "pattern":"seal", "tint":Color(1.0,0.79,0.38), "damage":10.0, "speed":35.0, "spacing":96.0, "reach":136.0, "height":68.0, "radius":34.0, "tell":1.1, "active":0.16, "recover":0.9, "cooldown":3.0, "hurt":0.4, "aggro":20.0, "leash":180.0},
	"tan_dang_lam_tuoc": {"sect":"Tàn Đăng Môn", "style":"Song thức · Hai nhịp báo riêng", "skill":"Song Đăng Thiết", "pattern":"double_cut", "tint":Color(0.72,1.0,0.72), "damage":5.0, "speed":62.0, "spacing":48.0, "reach":82.0, "height":46.0, "tell":0.7, "followup_tell":0.65, "active":0.12, "recover":0.85, "cooldown":2.8, "hurt":0.35, "aggro":20.0, "leash":180.0},
	"tan_dang_du_hanh": {"sect":"Tàn Đăng Môn", "style":"Đột kiếm · Bước ngắn có vật cản", "skill":"Hồi Bộ Thứ", "pattern":"lunge", "tint":Color(0.79,0.77,1.0), "damage":11.0, "speed":46.0, "spacing":62.0, "reach":90.0, "height":42.0, "lunge_speed":90.0, "tell":0.85, "active":0.18, "recover":1.1, "cooldown":2.4, "hurt":0.4, "aggro":20.0, "leash":180.0}
}

static func definition(id: String) -> Dictionary:
	var result: Dictionary = SPECS.get(UNIFORMS.get(id,id),{}).duplicate(true)
	if result.is_empty(): return result
	result["stage_id"] = NpcPilotCatalog.cultivation_stage(id)
	var stage: int = CultivatorCombatScaling.stage_index(result["stage_id"])
	var config: Dictionary = OpeningCultivationState.default_config()
	result["stage_label"] = str(config["stage_labels"][stage]) if stage >= 0 else ""
	result["damage"] = CultivatorCombatScaling.outgoing_damage(result["stage_id"],float(result["damage"]))
	return result

static func portrait(id: String) -> Texture2D:
	return PORTRAITS.get(UNIFORMS.get(id,id))

static func dialogue_lines(id: String) -> Array[String]:
	match id:
		"thanh_van_steward_01": return ["Ta là Phùng Yên Trúc, chấp sự giữ sổ. Đọc mốc tây và đông rồi nộp ở sổ tiếp nhận bên phải; quyền khách mở lối vào Tùng Đình. Ta sẽ không kết tội một môn phái chỉ vì một lời đồn."]
		"xich_lo_steward_01": return ["Ta là Tống Hồng Diệp. Ghi mực nước và dấu cặn trên đê; sổ tiếp nhận phía đông đối chiếu đủ hai mốc sẽ mở Sân Dẫn Thủy. Người trọng thương được nghỉ, nhưng việc đã làm vẫn được nhớ."]
		"thanh_van_disciple_01": return [
			"Ta là đệ tử Thanh Vân, được cử giữ đoạn đường này. Người qua núi mang theo hàng hóa, thư từ và cả lời đồn. Giữ đường thông thì dễ; giữ cho lời kể còn nguyên mới khó.",
			"Có lời đồn dấu niêm ở miếu đèn không khớp với bản ghi tại bưu trạm Bến Trầm. Ta chưa thấy đủ hai bản để kết tội ai. Miếu còn đó, hồ sơ dưới bến cũng còn; chuyện này cần người chịu nhìn cho kỹ."
		]
		"xich_lo_guard_01": return [
			"Ta là hộ vệ Xích Lô. Người dưới bến sống nhờ lò, xưởng và những chuyến hàng còn qua được đường núi. Ta mang đao để giữ lối về; không phải ai mặc giáp đỏ cũng muốn gây chuyện.",
			"Ta cũng nghe chuyện dấu niêm khác nhau. Nhưng một lời đồn chưa đủ buộc tội cả xưởng. Bưu trạm cũ ở Bến Trầm vẫn giữ hồ sơ trên nền cao; hãy để dấu mực lên tiếng trước khi rút kiếm."
		]
	return []

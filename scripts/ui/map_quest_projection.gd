class_name MapQuestProjection
extends RefCounted
## Read-only views of canonical opening milestones and saved exterior discoveries.

static func known_rooms(profile: SanctuaryProfile) -> Dictionary:
	var known: Dictionary = {ExteriorRouteCatalog.HUB:true}
	if profile == null or profile.exterior_progress_quarantined or not ExteriorProgress.valid(profile.exterior_progress): return known
	for room: String in profile.exterior_progress["discovered_rooms"]:
		known[StringName(room)] = true
	return known

static func shortcut_known(profile: SanctuaryProfile, known: Dictionary) -> bool:
	return profile != null and not profile.exterior_progress_quarantined and bool(profile.exterior_progress.get("sc01_open",false)) and known.has(&"o01_p01") and known.has(&"o01_p03")

static func rows(profile: SanctuaryProfile, inventory: GearInventory = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if profile == null or profile.opening_progress_quarantined or not OpeningProgress.valid(profile.opening_progress): return result
	var snapshot: Dictionary = profile.opening_objectives()
	var completed: Array = snapshot["completed"]
	var boss_known: bool = profile.bounty_accepted or profile.boss_proofs.get(&"golem",0) > 0 or completed.has("golem_defeated")
	var healer_known: bool = completed.has("thanh_vy_met")
	for id: StringName in OpeningProgress.IDS:
		var title: String
		var body: String
		var target: StringName = &""
		match id:
			&"explored":
				title = "Bước ra đường bộ"
				body = "Theo lối đường bộ ở căn cứ để bắt đầu khám phá vùng ngoại cảnh."
				target = ExteriorRouteCatalog.HUB
			&"golem_defeated":
				title = "Vượt qua Golem Cổ Bảo" if boss_known else "Tiếp tục hành trình hầm ngục"
				body = "Mục tiêu đã biết nằm trong hầm ngục, ngoài sơ đồ đường bộ này." if boss_known else "Mục tiêu cụ thể sẽ hiện khi bạn đã nhận lời hẹn hoặc gặp dấu mốc. Không có vị trí đã biết để đánh dấu trên sơ đồ này."
			&"reward_collected":
				title = "Thu nhận phần thưởng"
				body = "Thu nhận phần thưởng trong hành trình mở đầu. Vị trí này chưa được đánh dấu trên sơ đồ đường bộ."
			&"returned_to_hub":
				title = "Trở về căn cứ"
				body = "Trở về căn cứ sau hành trình để chuẩn bị cho chuyến đi tiếp theo."
				target = ExteriorRouteCatalog.HUB
			&"thanh_vy_met":
				title = "Cuộc gặp Thanh Vy" if healer_known else "Tìm người giúp đỡ"
				body = "Bạn đã gặp Thanh Vy tại căn cứ." if healer_known else "Gặp người giúp đỡ tại căn cứ để tiếp tục hành trình mở đầu."
				target = ExteriorRouteCatalog.HUB
			&"first_upgrade":
				title = "Chuẩn bị bước tiếp theo"
				body = "Hoàn tất lần nâng cấp đầu tiên tại căn cứ để chuẩn bị hành trang."
				target = ExteriorRouteCatalog.HUB
		var row: Dictionary = {"id":id,"title":title,"body":body,"target":target,"done":completed.has(String(id)),"next":snapshot["next_id"] == id}
		if inventory != null:
			var guide: Dictionary = OpeningProgressionGuide.for_milestone(id, profile, inventory)
			if not guide.is_empty():
				row["guide"] = guide
				row["body"] += "\n\nHÀNH TRANG & SỨC MẠNH · "+guide["topic"]+"\n"+guide["body"]
		result.append(row)
	result.append_array(SectJourneyProgress.rows(profile))
	return result

static func room_name(room: StringName) -> String:
	if room == ExteriorRouteCatalog.HUB: return "Căn Cứ Lữ Khách"
	if room in SectRouteCatalog.ROOMS: return SectRouteCatalog.title(room)
	var index: int = ExteriorRouteCatalog.ROOMS.find(room)
	return ExteriorRouteCatalog.TITLES[index] if index >= 0 else ""

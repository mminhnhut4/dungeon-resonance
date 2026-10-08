class_name OpeningQuestCards
extends RefCounted
## Projection of existing quest/receipt owners. No quest flags, IO or rewards.
const Cultivation = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const WORLD_LOOT: DropTableResource = preload("res://data/loot/world_drop_table.tres")

static func decorate(rows: Array[Dictionary], profile: SanctuaryProfile, inventory: GearInventory) -> Array[Dictionary]:
	var result: Array[Dictionary] = rows.duplicate(true)
	if profile == null or inventory == null or result.is_empty(): return result
	var completed: Array = profile.opening_objectives()["completed"]
	for row: Dictionary in result:
		var id: StringName = row["id"]
		var card: Dictionary = _base(row)
		match id:
			&"explored":
				card.merge({"title":"Khảo sát đường bộ", "action":"Đến biển ĐƯỜNG BỘ ở sân căn cứ, nhấn E và bước qua cửa để vào vùng ngoài.", "location":"Căn Cứ Lữ Khách · lối đường bộ cạnh sân luyện", "prerequisite":"Đang ở vùng chơi; đóng bảng để đi và tương tác.", "reward":"+1 lĩnh ngộ khám phá", "reward_mode":"Tự ghi vào tu luyện một lần khi mốc khám phá được lưu."},true)
				_insight(card,profile,"explored")
			&"golem_defeated":
				card = _bounty(profile,inventory)
				row["target"] = ExteriorRouteCatalog.HUB if not profile.bounty_accepted or int(card["count"]) >= 1 else &""
			&"reward_collected":
				card.merge({"title":"Nhặt phần rơi sau thủ lĩnh", "action":"Sau khi hạ thủ lĩnh, tới Tàn Hồn đã rơi và nhấn E trước khi rời tầng.", "location":"Đấu trường cuối hành trình hầm ngục", "prerequisite":"Có Tàn Hồn của thủ lĩnh đã rơi để nhặt.", "reward":"%d Tàn Hồn nếu nhặt được phần rơi của thủ lĩnh" % WORLD_LOOT.boss_souls, "reward_mode":"Nhặt vật phẩm để ghi vào profile; bảng nhiệm vụ không cấp lại.", "reward_status":"Đã ghi lần nhặt đầu" if row["done"] else "Chờ vật phẩm rơi và nhặt · phần rơi có thể trống"},true)
				# The current source permits an empty boss drop. It cannot be a
				# mandatory next instruction after a successful return without loot.
				card["optional"] = completed.has("returned_to_hub") and not row["done"]
			&"returned_to_hub":
				card.merge({"title":"Mang hành trang về căn cứ", "action":"Sau tầng đã dọn, đến lối ra bên phải, E → Trở về sảnh để giữ đồ đã nhặt hoặc Ở lại nhặt đồ. Mốc nhiệm vụ này chỉ ghi khi hạ Golem rồi về qua cổng cuối; về sớm không tính thắng Golem.", "location":"Lối ra từng tầng / cổng cuối → Căn Cứ Lữ Khách", "prerequisite":"Tầng đã hoàn thành; hoàn tất retry nếu phần thưởng đang chờ lưu.", "reward":"Giữ đồ đã nhặt và Linh Thạch khi về sảnh theo luật hành trình", "reward_mode":"Lưu hành trang/Linh Thạch một lần; không tự nhặt đồ còn trên đất và không cấp thêm gói thưởng.", "reward_status":"Đã ghi lần trở về sau Golem" if row["done"] else "Có thể về sớm · mốc còn chờ thắng Golem"},true)
			&"thanh_vy_met":
				card.merge({"title":"Gặp Thanh Vy", "action":"Đến Thanh Vy ở sân căn cứ, nhấn E để mở lời thoại.", "location":"Căn Cứ Lữ Khách · Thanh Vy, gần Kho Căn Cứ", "prerequisite":"Đóng bảng, đứng gần NPC rồi tương tác.", "reward":"+1 lĩnh ngộ từ cuộc gặp", "reward_mode":"Tự ghi vào tu luyện một lần khi cuộc gặp được lưu."},true)
				_insight(card,profile,"thanh_vy_met")
			&"first_upgrade":
				card = _upgrade(profile,inventory,row)
		if String(id).begins_with("sect_"):
			var faction_id: String=String(id).trim_prefix("sect_")
			var saved: Dictionary=profile.extension_state(SectJourneyProgress.SCOPE)
			if SectJourneyProgress.valid(saved) and faction_id in SectRouteCatalog.FACTIONS:
				var entry: Dictionary=saved[faction_id]
				card.merge({"location":SectRouteCatalog.title(SectRouteCatalog.first(faction_id)),"progress":"%d/2 quan sát · %s" % [entry["markers"].size(),"Đã có quyền khách" if entry["guest"] else "Chưa trình đủ ghi chép"],"count":entry["markers"].size(),"prerequisite":"Nhận việc ở sổ gần cổng; tới từng mốc và chọn Ghi quan sát.","reward":"Quyền khách vào sân trong của môn phái này","reward_mode":"Trình hai ghi chép tại sổ trong khuôn viên; không mất tiền, không có thưởng tiền/đồ.","reward_status":"Đã mở sân trong" if entry["guest"] else "Chờ trình ghi chép","optional":true},true)
		row["card"] = card
		if row.has("guide"):
			row["body"] = "HÀNH TRANG & SỨC MẠNH · %s\n%s" % [row["guide"]["topic"],row["guide"]["body"]]
		if id in [&"golem_defeated",&"first_upgrade"]:
			row["body"] += "\n\nLƯỢT CHƠI ĐẦU · Bùa → sức mạnh → chuyến tiếp\n" + OpeningProgressionGuide.first_loop(profile,inventory)["body"]
	# Expose the route before the opening is complete; it stays optional until
	# the required opening milestones finish and never invents a quest reward.
	var opening_complete: bool = OpeningProgress.IDS.all(func(id: StringName) -> bool: return id == &"reward_collected" or completed.has(str(id)))
	if Cultivation.valid(profile.cultivation_progress,profile.material_stash):
		var progress: Dictionary = profile.cultivation_progress
		if Cultivation.valid(progress,profile.material_stash) and int(progress["actors"]["player"]["stage"]) < 3:
			var guide: Dictionary = OpeningProgressionGuide.for_milestone(&"first_upgrade",profile,inventory)
			result.append({"id":&"cultivation_breakthrough","title":"Đột phá Trúc Cơ lần đầu","body":guide["body"],"target":ExteriorRouteCatalog.HUB,"done":false,"next":false,"card":{"title":"Đột phá Trúc Cơ lần đầu","action":"Đến SÂN LUYỆN → TU LUYỆN. Rèn đòn trúng mộc nhân, điều tức và xem các điều kiện; tại bước cuối chọn một nhánh rồi đột phá.","location":"Căn Cứ Lữ Khách · Sân Luyện","progress":"Cảnh giới %d/3" % progress["actors"]["player"]["stage"],"count":int(progress["actors"]["player"]["stage"]),"prerequisite":"Năng lượng, thông thạo, lĩnh ngộ, tài nguyên và chứng tích đúng bảng tu luyện.","reward":"Học 1 động tác: Hồi Phong Kiếm hoặc Tỏa Linh Ấn (G)","reward_mode":"Nhận một lần cùng đột phá cuối; cần trả chi phí đang ghi trên bảng.","reward_status":"Chưa học nhánh","complete":false,"optional":false,"command":&"","command_label":"","command_enabled":false}})
			result[-1]["card"]["optional"] = not opening_complete
			result[-1]["card"]["action"] = OpeningProgressionGuide.cultivation_next_step(profile)
			result[-1]["body"] = "LỘ TRÌNH TRÚC CƠ · Làm từng bước, giữ tiến độ qua chuyến đi.\n" + guide["body"]
		elif opening_complete:
			result.append({"id":&"prepare_next_run","title":"Chuẩn bị chuyến đi tiếp theo","body":"Các mốc mở đầu và Trúc Cơ đã hoàn tất. Chuyến đi tiếp theo là mục tiêu tự chọn.","target":ExteriorRouteCatalog.HUB,"done":false,"next":false,"card":{"title":"Chuẩn bị chuyến đi tiếp theo","action":"Mở Hành trang để trang bị, gặp Thiết Lão để sửa hoặc cường hóa nếu đủ vật liệu, rồi vào cổng hầm ngục.","location":"Căn Cứ Lữ Khách · Thiết Lão → cổng hầm ngục","progress":"Mục tiêu tự chọn · không có hạn","count":0,"prerequisite":"Vũ khí dùng được; vật liệu/Linh Thạch theo giá hiện tại nếu chọn nâng cấp.","reward":"Đồ rơi và Tàn Hồn tùy chuyến đi, không bảo đảm một gói thưởng nhiệm vụ","reward_mode":"Nhặt và mang về theo luật hành trình hiện có.","reward_status":"Không có thưởng nhiệm vụ mới để nhận","complete":false,"optional":true,"command":&"","command_label":"","command_enabled":false}})
	# Victory/reward can finish before enough random Souls for Thanh Vy. Give a
	# real preparation/next-trip goal without forging the permanent-upgrade flag.
	if completed.has("returned_to_hub") and profile.bounty_claimed and not completed.has("first_upgrade"):
		var loop: Dictionary = OpeningProgressionGuide.first_loop(profile,inventory)
		result.append({"id":&"first_loop_next","title":"Chuẩn bị lượt tiếp theo","body":loop["body"],"target":ExteriorRouteCatalog.HUB,"done":false,"next":false,"card":{"title":"Chuẩn bị lượt tiếp theo","action":loop["action"],"location":"Căn Cứ Lữ Khách · Tab / Thiết Lão / SÂN LUYỆN → cổng hầm ngục","progress":loop["progress"],"count":0,"prerequisite":"Dùng đồ đang sở hữu và đúng giá/điều kiện trên các bảng; chuyến mới bắt đầu từ Tiền Sảnh.","reward":"Bùa đã ghép / nâng cấp đã mua; không có gói thưởng nhiệm vụ mới","reward_mode":"Trang bị/thử bùa; nâng sức mạnh qua giao dịch hiện có. Tịnh hóa Thanh Vy vẫn là mốc riêng.","reward_status":"Mục tiêu chuẩn bị · không nhận thêm tiền/đồ","complete":false,"optional":true,"command":&"","command_label":"","command_enabled":false}})
	var active_id: StringName = &""
	for row: Dictionary in result:
		var card: Dictionary = row["card"]
		if card.get("command") == &"bounty_claim" and card.get("command_enabled",false): active_id = row["id"]; break
	if active_id == &"":
		for row: Dictionary in result:
			if row["id"] == &"first_loop_next": active_id = row["id"]; break
	if active_id == &"":
		for row: Dictionary in result:
			if not row["card"]["complete"] and not row["card"].get("optional",false): active_id = row["id"]; break
	if active_id == &"":
		for row: Dictionary in result:
			if row["id"] == &"prepare_next_run": active_id = row["id"]; break
	for row: Dictionary in result:
		row["card"]["active"] = row["id"] == active_id
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return _rank(a) < _rank(b))
	return result

static func _rank(row: Dictionary) -> int:
	var order: int = OpeningProgress.IDS.find(row["id"])
	if order < 0: order = OpeningProgress.IDS.size()
	if row["card"]["active"]: return order
	if row["card"]["complete"]: return 48+order
	return (32 if row["card"].get("optional",false) else 16)+order

static func insights_ready(profile: SanctuaryProfile) -> bool:
	if profile == null or not Cultivation.valid(profile.cultivation_progress,profile.material_stash): return false
	for id: String in Cultivation.OBSERVATIONS:
		if profile.opening_progress["completed"].has(id) and not profile.cultivation_progress["actors"]["player"]["insight_ids"].has(id): return false
	return true

static func _base(row: Dictionary) -> Dictionary:
	return {"title":row["title"],"action":row["body"],"location":"Căn Cứ Lữ Khách","progress":"%d/1" % (1 if row["done"] else 0),"count":1 if row["done"] else 0,"prerequisite":"Theo mục tiêu đang ghi.","reward":"","reward_mode":"","reward_status":"Đã ghi" if row["done"] else "Chưa ghi","complete":row["done"],"optional":false,"command":&"","command_label":"","command_enabled":false}

static func _insight(card: Dictionary,profile: SanctuaryProfile,id: String) -> void:
	var ready: bool = Cultivation.valid(profile.cultivation_progress,profile.material_stash)
	var earned: bool = ready and profile.cultivation_progress["actors"]["player"]["insight_ids"].has(id)
	card["reward_status"] = "Đã nhận · một lần" if earned else "Chờ đồng bộ phần thưởng" if card["complete"] else "Tự nhận khi hoàn thành"
	if not ready:
		card["reward_status"] = "Chưa xác minh lĩnh ngộ; phiên tu luyện chưa sẵn sàng."
	elif card["complete"] and not earned:
		card["complete"] = false
		card["command"] = &"retry_insights"
		card["command_label"] = "Thử lưu lại lĩnh ngộ"
		card["command_enabled"] = not profile.read_only and Cultivation.valid(profile.cultivation_progress,profile.material_stash)

static func _quotes(profile: SanctuaryProfile,inventory: GearInventory) -> EconomySession:
	var economy := EconomySession.new(); economy.profile = profile; economy.inventory = inventory
	return economy

static func _bounty(profile: SanctuaryProfile,inventory: GearInventory) -> Dictionary:
	var quote: Dictionary = _quotes(profile,inventory).quote_bounty(WorldProgressionCatalog.BOUNTY_ID)
	var count: int = int(quote["progress"])
	var claimed: bool = profile.bounty_claimed
	var card: Dictionary = {"title":"Lời hẹn của Vô Danh","action":"","location":"Căn Cứ Lữ Khách · Vô Danh cạnh cổng hầm ngục","progress":"Chứng tích sau lời hẹn %d/1" % count,"count":count,"prerequisite":"Nhận lời hẹn trước khi hạ thủ lĩnh; túi cần trống 1 ô để nhận kiếm.","reward":"1 Kiếm Lữ Hành · Liên Thức (Thường), thêm đòn đâm sau 3 nhát chém","reward_mode":"Nhận thưởng một lần tại căn cứ; bí kíp được giữ sau khi chết.","reward_status":"Đã nhận · một lần" if claimed else "Chưa nhận lời" if not profile.bounty_accepted else "Đủ chứng tích, chờ nhận" if count >= 1 else "Chưa đủ chứng tích","complete":claimed,"optional":false,"command":&"","command_label":"","command_enabled":false}
	if claimed:
		card["action"] = "Đã nhận bí kíp. Tab → chọn kiếm thưởng trong túi để trang bị, thử liên thức và bùa ở SÂN LUYỆN; xem mục Chuẩn bị lượt tiếp theo. Nếu mất kiếm khi chết, gặp Vô Danh để luyện lại liên thức trên kiếm khởi đầu."
	elif not profile.bounty_accepted:
		card["action"] = "Nhận lời hẹn của Vô Danh tại căn cứ; sau đó vào cổng hầm ngục và tiến tới thủ lĩnh cuối hành trình."
		card["command"] = &"bounty_accept"; card["command_label"] = "Nhận lời hẹn của Vô Danh"; card["command_enabled"] = bool(quote["can_accept"])
	elif count < 1:
		card["action"] = OpeningProgressionGuide.first_loop(profile,inventory)["action"] + " Hạ Golem Cổ Bảo ở chặng cuối; chứng tích phải được ghi sau khi nhận lời hẹn."
		card["location"] = "Cổng hầm ngục / rương KHÁM PHÁ BÍ MẬT → sảnh chuẩn bị → Golem"
	else:
		card["action"] = "Về căn cứ và nhận Kiếm Lữ Hành · Liên Thức. Thưởng vào túi; mở Hành trang để so sánh rồi trang bị."
		card["command"] = &"bounty_claim"; card["command_label"] = "Nhận Kiếm Lữ Hành · Liên Thức"; card["command_enabled"] = bool(quote["can_claim"])
		if not quote["can_claim"]: card["prerequisite"] = "Túi trang bị đã đầy; phân giải một món dự phòng rồi nhận lại. Phần thưởng chưa bị trừ."
	if profile.read_only or profile.hub_inventory_quarantined:
		card["command_enabled"] = false; card["prerequisite"] = "Hồ sơ cần được kiểm tra trước khi lưu phần thưởng."
	return card

static func _upgrade(profile: SanctuaryProfile,inventory: GearInventory,row: Dictionary) -> Dictionary:
	var card: Dictionary = _base(row)
	card.merge({"title":"Tịnh hóa lần đầu","location":"Căn Cứ Lữ Khách · Thanh Vy","action":"Gặp Thanh Vy → chọn một nâng cấp vĩnh viễn và xác nhận giá Tàn Hồn.","prerequisite":"Đủ Tàn Hồn và còn cấp nâng được.","reward_mode":"Hiệu quả nâng cấp được mua bằng Tàn Hồn; không có gói thưởng miễn phí riêng.","reward_status":"Đã mua lần đầu" if row["done"] else "Chờ mua nâng cấp"},true)
	if row["done"]:
		card["reward"] = "Nâng cấp vĩnh viễn đã mua; xem chỉ số hiện tại tại Thanh Vy."
		return card
	var economy: EconomySession = _quotes(profile,inventory)
	var names: Dictionary = {&"max_hp":"Máu tối đa",&"max_mana":"Mana tối đa",&"mana_regen":"Hồi năng lượng",&"rune_capacity":"Ô Catalyst"}
	for id: StringName in WorldProgressionCatalog.UPGRADES:
		var quote: Dictionary = economy.quote_upgrade(id)
		if int(quote["level"]) >= int(quote["max_level"]): continue
		card["reward"] = "%s +%.0f → +%.0f %s · giá %d Tàn Hồn (đang có %d)" % [names[id],quote["value"],float(quote["value"])+float(WorldProgressionCatalog.VALUES[id]),quote["unit"],quote["cost"],profile.souls]
		break
	if card["reward"] == "": card["reward"] = "Các nâng cấp hiện có đã đạt giới hạn."
	return card

static func detail(card: Dictionary) -> String:
	return "HÀNH ĐỘNG: %s\nĐỊA ĐIỂM: %s\nTIẾN ĐỘ: %s\nĐIỀU KIỆN: %s\nPHẦN THƯỞNG: %s\nNHẬN THƯỞNG: %s\nTRẠNG THÁI: %s" % [card["action"],card["location"],card["progress"],card["prerequisite"],card["reward"],card["reward_mode"],card["reward_status"]]

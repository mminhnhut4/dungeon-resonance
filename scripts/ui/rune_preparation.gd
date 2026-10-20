extends RefCounted
## Optional preparation projection. RAM metadata only; never a writer or grant owner.
const KEY: StringName = &"rune_preparation_session"
const Supplies = preload("res://data/floor_supply_catalog.gd")
const Mine = preload("res://data/shattered_mine_supply_catalog.gd")
const TITLE: String = "Một lá bùa cho chuyến sau"
const USE: String = "Tab → chọn trang bị → ghép vào ô bùa. Thử ở Sân Luyện; trang bị quyết định bộ đòn, ghép bùa là cách tấn công chính. Không tự đổi bộ bùa đang lắp."

static func session(profile: SanctuaryProfile) -> Dictionary:
	if profile == null: return {}
	if not profile.has_meta(KEY): profile.set_meta(KEY, {"selected":&"", "notice":{}, "last_offer":"", "make_extra":false})
	return profile.get_meta(KEY)

static func choose(profile: SanctuaryProfile, id: StringName) -> void:
	if profile == null or (id != &"" and id not in RuneLearningService.IDS): return
	var state: Dictionary = session(profile)
	if state["selected"] != id:
		state["selected"] = id
		state["notice"] = {}
		state["make_extra"] = false

static func prepare_extra(profile: SanctuaryProfile) -> void:
	var state: Dictionary=session(profile)
	if state.is_empty() or state["selected"] not in RuneLearningService.IDS:return
	state["make_extra"]=true;state["notice"]={}

static func result(profile: SanctuaryProfile, id: StringName, offer_key: String, committed: bool, quantity: int) -> void:
	var state: Dictionary = session(profile)
	if state.is_empty() or state["selected"] != id or offer_key.is_empty() or state["last_offer"] == offer_key: return
	state["last_offer"] = offer_key
	state["notice"] = {"ok":committed and quantity > 0, "quantity":quantity}

static func owned(inventory: GearInventory, id: StringName) -> int:
	var count: int = 0
	if inventory != null:
		for item: GearItem in inventory.items.values():
			if item.kind == &"rune" and item.definition_id == id: count += 1
	return count

static func view(profile: SanctuaryProfile, inventory: GearInventory, service: RuneLearningService = null) -> Dictionary:
	var out: Dictionary = {"state":"unavailable", "title":TITLE, "selected":&"", "body":"Chưa xác nhận được hành trang hoặc dữ liệu lưu. Mở lại khi dữ liệu sẵn sàng; bước chuẩn bị vẫn là tự chọn.", "progress":"", "sources":"", "reward":"Nhận được: chính bùa đã sở hữu hoặc bùa được chế và lưu sau khi trả giá. Không có gói thưởng thêm.", "use":USE, "options":[], "missing":{}, "owned":0}
	if profile == null or inventory == null or profile.profile_version != 2 or profile.read_only or profile.hub_inventory_quarantined or not profile.extension_transactions_available(RuneLearningService.SCOPE): return out
	var knowledge: Dictionary = profile.extension_state(RuneLearningService.SCOPE)
	if knowledge.is_empty(): knowledge = RuneLearningService.empty()
	if not RuneLearningService.valid(knowledge) or profile.extension_revision(RuneLearningService.SCOPE) != knowledge["learned"].size(): return out
	if service != null and (service.economy == null or service.economy.profile != profile or service.economy.inventory != inventory or service.economy._busy): return out
	var state: Dictionary = session(profile)
	var selected: StringName = state["selected"]
	out["selected"] = selected
	for id: StringName in RuneLearningService.IDS:
		out["options"].append({"id":id, "text":"%s · %s" % [RuneLearningService.NAMES[id], "đang có %d" % owned(inventory,id) if owned(inventory,id)>0 else "đã học" if knowledge["learned"].has(String(id)) else "chưa học"]})
	if selected not in RuneLearningService.IDS:
		out["state"] = "choose_rune"
		out["body"] = "Chuyến sau con muốn mang bùa nào? Chọn lá đang có hoặc loại con đã học; ta sẽ chỉ phần còn thiếu. Không cần chế lại bùa đã có."
		return out
	var name_text: String = RuneLearningService.NAMES[selected]
	var count: int = owned(inventory, selected)
	out["owned"] = count
	var progress: Array[String] = ["Mục tiêu tự chọn: chuẩn bị bùa %s · đang mang %d lá." % [name_text,count]]
	if count>0:progress.append("Đã có thể dùng ngay. Chi phí dưới đây chỉ áp dụng nếu tự chọn chế thêm.")
	var missing: Dictionary = {}
	var stash: Array[String] = []
	for id: StringName in RuneLearningService.CRAFT_COST:
		var required: int = int(RuneLearningService.CRAFT_COST[id])
		var have: int = int(inventory.materials.get(id,0))
		var shortage: int = maxi(0,required-have)
		progress.append("%s: túi %d/%d · thiếu %d · kho %d" % [MaterialCatalog.DISPLAY_NAMES[id],have,required,shortage,int(profile.material_stash.get(id,0))])
		if shortage > 0:
			missing[id] = shortage
			if int(profile.material_stash.get(id,0)) > 0: stash.append("%d %s" % [mini(shortage,int(profile.material_stash[id])),MaterialCatalog.DISPLAY_NAMES[id]])
	out["progress"] = "\n".join(progress)
	out["missing"] = missing
	var notice: Dictionary = state["notice"]
	if not notice.is_empty() and notice.get("ok",false):
		out["state"] = "crafted_this_session"
		out["body"] = "Đã chế và lưu %d bùa %s vào hành trang trong phiên này. Tab để xem hoặc ghép; Sân Luyện để thử. Không có gói thưởng khác cần nhận." % [int(notice["quantity"]),name_text]
		return out
	if count > 0 and not state.get("make_extra",false):
		out["state"] = "already_prepared"
		out["body"] = "Con đã có bùa %s. Có thể dùng ngay; không cần chế thêm để xong bước chuẩn bị này. Nếu muốn chế thêm, đó là giao dịch mới trả đủ giá." % name_text
		return out
	if not notice.is_empty():
		out["state"] = "save_failed"
		out["body"] = "Chưa hoàn tất giao dịch nên chưa nhận bùa. Kiểm tra thông báo của dịch vụ và chọn lại khi dữ liệu sẵn sàng."
		return out
	var quote: Dictionary = service.quote(selected) if service != null else {}
	if quote.get("can_craft",false):
		out["state"] = "ready_to_craft"
		out["body"] = "Đã đủ nguyên liệu trong túi. Thanh Vy → Học & chế bùa → %s → Chế. Xem số lượng và tổng chi phí trước khi xác nhận." % name_text
		return out
	if not knowledge["learned"].has(String(selected)):
		out["state"] = "learn_first"
		out["body"] = "Chưa học cách chế bùa %s. Bùa nhặt được vẫn dùng ngay; muốn chế thêm thì xem điều kiện và giá học tại Thanh Vy. %s" % [name_text,str(quote.get("learn_lock_hint",""))]
		return out
	if inventory.items.size() >= GearInventoryCodec.MAX_ITEMS:
		out["state"] = "inventory_full"
		out["body"] = "Chưa đủ ô vật phẩm để nhận bùa. Bán hoặc tháo món dự phòng đủ điều kiện rồi mở lại báo giá. Cất nguyên liệu vào kho không giải phóng ô UID. Vật liệu chưa được dùng."
		return out
	if service == null or not service.economy.hub_access or not service.economy.persist_safe_inventory or missing.is_empty():
		out["state"] = "craft_blocked"
		out["body"] = "Chưa thể chế: %s" % str(quote.get("craft_lock_hint","trở về Thanh Vy ở căn cứ để xem báo giá hiện tại."))
		return out
	if not stash.is_empty():
		out["state"] = "withdraw_materials"
		out["body"] = "Kho đang có phần túi còn thiếu: %s. Rút phần cần ở Kho Căn Cứ rồi xem lại; chỉ vật liệu trong túi được dùng để chế. Chuyến đi kiếm thêm là tự chọn." % ", ".join(stash)
	else:
		out["state"] = "collect_missing"
		out["body"] = "Kiếm phần còn thiếu, nhặt vào túi rồi trở về Thanh Vy. Vật liệu ở nguồn khác vẫn dùng được; không cần thu lại phần đã đủ."
	var source_lines: Array[String] = []
	if profile.get_meta(&"rune_preparation_mine",false):
		var amounts: Array[String] = []
		for id: StringName in missing: amounts.append("%d %s" % [int(Mine.COST[id]),MaterialCatalog.DISPLAY_NAMES[id]])
		source_lines.append("Nguồn bổ sung đã có trong mẫu mỏ: rương cho %s mỗi chuyến. %s Đồ còn trên đất không tự mang về." % [" + ".join(amounts),Mine.ROUTE])
	else:
		for source: Dictionary in Supplies.SOURCES:
			if not missing.has(source["item"]): continue
			var supply: Dictionary = Supplies.view(source,profile,inventory)
			source_lines.append("%s\n%s\n%s" % [supply["title"],supply["source"],supply["unlock"]])
			if not supply.get("can_revisit",false) and out["state"] != "withdraw_materials": out["state"] = "route_locked"
	out["sources"] = "\n".join(source_lines)
	return out

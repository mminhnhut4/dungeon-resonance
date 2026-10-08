class_name RuneLearningService
extends RefCounted
## Permanent knowledge and finite rune items share the existing profile commit.
## Looted runes remain usable without knowledge; this service never gates equip.
const SCOPE: String = "rune_learning_v1"
const IDS: Array[StringName] = [&"fire", &"wind", &"lightning", &"ice", &"poison"]
const COSTS: Dictionary = {&"fire":5, &"wind":5, &"lightning":10, &"ice":10, &"poison":15}
const NAMES: Dictionary = {&"fire":"Hỏa", &"wind":"Phong", &"lightning":"Lôi", &"ice":"Băng", &"poison":"Độc"}
const CRAFT_COST: Dictionary = {&"dust":2, &"crystal":1}
var economy: EconomySession

func initialize(owner: EconomySession) -> void:
	economy = owner
	if economy != null and economy.profile != null:
		economy.profile.register_extension_validator(SCOPE, valid)

static func empty() -> Dictionary:
	return {"schema":1, "learned":[]}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2 or not (value.get("schema") is int or value.get("schema") is float) or value["schema"] != 1 or not value.get("learned") is Array or value["learned"].size() > IDS.size(): return false
	var seen: Array[StringName] = []
	for element: Variant in value["learned"]:
		if not (element is String or element is StringName): return false
		var id := StringName(element)
		if id not in IDS or id in seen: return false
		seen.append(id)
	return true

func state() -> Dictionary:
	if economy == null or economy.profile == null or not economy.profile.extension_transactions_available(SCOPE): return {}
	var stored: Dictionary = economy.profile.extension_state(SCOPE)
	if stored.is_empty(): stored = empty()
	# One receipt per learned element; crafting has no receipt counter to fill.
	if not valid(stored) or economy.profile.extension_revision(SCOPE) != stored["learned"].size(): return {}
	return stored

func quote(id: StringName) -> Dictionary:
	var knowledge: Dictionary = state()
	var learned: bool = not knowledge.is_empty() and knowledge["learned"].has(String(id))
	var common: String = _common_lock(id,knowledge)
	var learn_hint: String = common
	var craft_hint: String = common
	if common.is_empty():
		if learned: learn_hint = "Bạn đã học bùa này."
		else:
			learn_hint = _milestone_lock(id)
			if learn_hint.is_empty() and economy.profile.souls < int(COSTS[id]): learn_hint = "Chưa đủ Tàn Hồn để học bùa."
		if not learned: craft_hint = "Học bùa trước khi chế thêm. Bùa nhặt được vẫn có thể ghép ngay."
		elif not economy._has_costs(CRAFT_COST): craft_hint = "Cần 2 %s và 1 %s trong kho để chế thêm." % [MaterialCatalog.DISPLAY_NAMES[&"dust"],MaterialCatalog.DISPLAY_NAMES[&"crystal"]]
	return {"id":String(id), "name":NAMES.get(id,""), "learned":learned,
		"can_learn":learn_hint.is_empty(), "can_craft":craft_hint.is_empty(),
		"cost":int(COSTS.get(id,0)), "craft_materials":CRAFT_COST.duplicate(),
		"lock_hint":craft_hint if learned else learn_hint,
		"learn_lock_hint":learn_hint, "craft_lock_hint":craft_hint}

func _common_lock(id: StringName, knowledge: Dictionary) -> String:
	if id not in IDS: return "Không có bùa này trong danh mục."
	if economy == null or economy.profile == null or economy.inventory == null: return "Chưa mở được dịch vụ học bùa."
	if economy.profile.profile_version != 2 or economy.profile.read_only or knowledge.is_empty(): return "Dữ liệu học bùa chưa đọc được; giữ nguyên hồ sơ để khôi phục."
	if economy.profile.hub_inventory_quarantined: return "Hành trang lưu đang chờ khôi phục."
	if not economy.hub_access or not economy.persist_safe_inventory: return "Trở về nơi an toàn để học hoặc chế bùa."
	if economy._busy: return "Giao dịch trước đang được lưu."
	if economy.inventory.items.size() >= GearInventoryCodec.MAX_ITEMS: return "Hành trang đã đầy; hãy cất bớt vật phẩm."
	return ""

func _milestone_lock(id: StringName) -> String:
	var completed: Array = economy.profile.opening_progress.get("completed",[])
	if id in [&"lightning",&"ice"] and not completed.has("explored"): return "Qua ĐƯỜNG BỘ ở sân căn cứ để ghi mốc khám phá, rồi quay về học bùa này."
	if id == &"poison" and not completed.has("golem_defeated"): return "Đánh bại Golem Cổ Bảo để mở cách học bùa Độc."
	return ""

func learn(id: StringName) -> bool:
	var offer: Dictionary = quote(id)
	if not offer["can_learn"]: return false
	economy._busy = true
	var previous_ledger: Dictionary = economy.profile.hub_inventory
	var previous_bag: int = economy.inventory.bag[id]
	var item: GearItem = _add_rune(id)
	var next: Dictionary = state()
	next["learned"].append(String(id))
	economy.profile.hub_inventory = GearInventoryCodec.encode(economy.inventory)
	var result: Dictionary = economy.profile.commit_extension_event(SCOPE,"learn_"+String(id)+"_v1",{},int(offer["cost"]),next,economy.profile.extension_revision(SCOPE))
	# A stale receipt may return already_committed without saving provisional
	# inventory. Only a new committed transaction can publish this new UID.
	if not result.get("ok",false) or result.get("status") != "committed":
		economy.inventory.items.erase(item.uid)
		economy.inventory.bag[id] = previous_bag
		economy.profile.hub_inventory = previous_ledger
		economy._busy = false
		return false
	economy._publish_commit()
	return true

func craft(id: StringName) -> bool:
	if not quote(id)["can_craft"]: return false
	economy._busy = true
	var previous_bag: int = economy.inventory.bag[id]
	var item: GearItem = _add_rune(id)
	for material: StringName in CRAFT_COST: economy.profile.material_stash[material] -= int(CRAFT_COST[material])
	if not economy._save_safe():
		for material: StringName in CRAFT_COST: economy.profile.material_stash[material] += int(CRAFT_COST[material])
		economy.inventory.items.erase(item.uid)
		economy.inventory.bag[id] = previous_bag
		economy._busy = false
		return false
	economy._publish_commit()
	return true

func _add_rune(id: StringName) -> GearItem:
	# Avoid provisional changed signals; publish once only after durable commit.
	var item: GearItem = economy.inventory.add_item(&"rune",id,GearItem.Quality.COMMON)
	item.source = &"crafted"
	item.loot_rolled = true
	economy.inventory.bag[id] += 1
	return item

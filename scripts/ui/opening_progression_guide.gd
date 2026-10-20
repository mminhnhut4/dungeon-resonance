class_name OpeningProgressionGuide
extends RefCounted
## Detached, read-only hints. Existing quest, inventory and profile owners decide
## rewards, travel, transactions and completion. Never initialize a save/session.
const Cultivation = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const CultivationLabels = preload("res://scripts/cultivation/opening_cultivation_labels.gd")
const FIRESTORM: ResonanceDefinition = preload("res://data/resonances/firestorm.tres")
const RECIPES: Array[ResonanceDefinition] = [
	preload("res://data/resonances/basic.tres"), preload("res://data/resonances/fire_bolt.tres"),
	preload("res://data/resonances/wind_bolt.tres"), preload("res://data/resonances/lightning_bolt.tres"),
	FIRESTORM, preload("res://data/resonances/overload.tres"), preload("res://data/resonances/charged_slash.tres"),
	preload("res://data/resonances/astral_firestorm.tres"), preload("res://data/resonances/eclipse_blades.tres"),
	preload("res://data/resonances/ice_bolt.tres"), preload("res://data/resonances/poison_bolt.tres"),
	preload("res://data/resonances/thermal_shock.tres"), preload("res://data/resonances/superconduct.tres"),
	preload("res://data/resonances/blizzard.tres"), preload("res://data/resonances/combustion.tres"),
	preload("res://data/resonances/frost_venom.tres"), preload("res://data/resonances/miasma_cloud.tres"),
	preload("res://data/resonances/neurotoxin.tres")]

static func for_milestone(id: StringName, profile: SanctuaryProfile, inventory: GearInventory) -> Dictionary:
	if profile == null or inventory == null: return _view("Hành trang", "unavailable", "Chưa đọc được hành trang hiện tại. Mở lại bảng sau khi vào vùng chơi.")
	match id:
		&"explored": return _equipment(inventory)
		&"golem_defeated": return _materials(profile, inventory)
		&"reward_collected": return _enhancement(profile, inventory)
		&"returned_to_hub": return _talisman(inventory,profile)
		&"thanh_vy_met": return _permanent_upgrade(profile, inventory)
		&"first_upgrade": return _cultivation(profile, inventory)
	return {}

static func _view(topic: String, status: String, body: String, blockers: Array[String] = []) -> Dictionary:
	return {"topic":topic, "status":status, "body":body, "blockers":blockers.duplicate()}

static func _equipment(inventory: GearInventory) -> Dictionary:
	var item: GearItem = inventory.items.get(inventory.equipped_weapon_uid)
	var text: String = "Hành trang · Tab: hover hoặc focus món đồ để xem so sánh với món đang mặc; chọn món trong túi để trang bị, chuột phải / Backspace ở ô mặc để tháo. Vũ khí đang dùng quyết định bộ đòn đánh."
	if item != null and item.kind == &"weapon" and item.can_equip():
		return _view("Nhận đồ → so sánh → trang bị", "equipped", "Đang dùng %s · %s · +%d.\n%s\nĐồ mua ở Kael hoặc nhặt trong chuyến đi được đưa vào hành trang; kiểm tra lại ô vũ khí sau khi thay." % [ItemArtCatalog.gear_name(item), GearItem.NAMES[clampi(item.quality, 0, 5)], item.enhancement_level, text])
	for candidate: GearItem in inventory.items.values():
		if candidate.kind == &"weapon" and candidate.can_equip():
			return _view("Nhận đồ → so sánh → trang bị", "equip_needed", "Đang tay không; có vũ khí dùng được trong túi.\n"+text, ["weapon_not_equipped"])
	return _view("Nhận đồ → so sánh → trang bị", "weapon_needed", "Chưa có vũ khí dùng được. Tại căn cứ, xem hàng Kael và giá Linh Thạch; đồ hỏng cần sửa ở trạm thợ rèn, phôi cần bản chế tạo và vật liệu.\n"+text, ["usable_weapon_required"])

static func _materials(profile: SanctuaryProfile, inventory: GearInventory) -> Dictionary:
	var text: String = "Vật liệu nhặt được nằm trong hành trang. Rèn, sửa, cường hóa, chế và điều tức dùng nguyên liệu đang mang. Kho chỉ cất/rút; rút về túi trước khi sử dụng. Vật liệu đã cất được giữ qua lần tử trận."
	text += "\nĐang mang: %d Tinh Thạch · %d Bột Phép · %d đá cấp 1. Trong kho: %d · %d · %d." % [inventory.materials.get(&"crystal", 0), inventory.materials.get(&"dust", 0), inventory.materials.get(&"enhancement_stone_1", 0), profile.material_stash.get(&"crystal", 0), profile.material_stash.get(&"dust", 0), profile.material_stash.get(&"enhancement_stone_1", 0)]
	text += "\nQuái và rương trong chuyến đi có thể rơi vật liệu/đá; phần rơi thay đổi, không đảm bảo mỗi lần. Tháo món dự phòng rồi phân giải để lấy Kim Loại/Bột Phép. Kael mua đồ đủ điều kiện từ túi; xem danh sách và tổng tiền trước khi bán tất cả để đổi Linh Thạch; cân nhắc giữ Tinh Thạch cho điều tức."
	var carried: bool = false
	for material_id: StringName in MaterialCatalog.IDS:
		if inventory.materials.get(material_id, 0) > 0 and not MaterialCatalog.material_policy(material_id)["lineage_bound"]: carried = true
	return _view("Kiếm vật liệu → dùng từ túi", "carried_ready" if carried else "collect_or_withdraw", text)

static func _quotes(profile: SanctuaryProfile, inventory: GearInventory) -> EconomySession:
	# Quote methods only read these references. No initialize(), writer, IO,
	# inventory clone, UID allocation or transaction callbacks are used here.
	var economy := EconomySession.new()
	economy.profile = profile
	economy.inventory = inventory
	return economy

static func _enhancement(profile: SanctuaryProfile, inventory: GearInventory) -> Dictionary:
	var item: GearItem = inventory.items.get(inventory.equipped_weapon_uid)
	var equipped: bool = item != null and item.kind == &"weapon"
	if not equipped:
		var uids: Array[int] = inventory.items.keys()
		uids.sort()
		for uid: int in uids:
			if inventory.items[uid].kind == &"weapon" and inventory.items[uid].can_equip(): item = inventory.items[uid]; break
	if item == null or item.kind != &"weapon": return _view("Cường hóa vũ khí", "weapon_needed", "Cần một vũ khí. Xem đồ đang sở hữu trong Hành trang hoặc hàng Kael tại căn cứ.", ["weapon_required"])
	if not item.can_equip(): return _view("Cường hóa vũ khí", "repair_needed", "Món đang chọn bị hỏng hoặc là phôi. Sửa / rèn phục hồi tại căn cứ trước khi cường hóa.", ["usable_weapon_required"])
	if item.enhancement_level >= 12: return _view("Cường hóa vũ khí", "capped", "%s đã +12. Giữ món này; có thể xem món khác ở bảng cường hóa hoặc tiếp tục tu luyện. Phẩm cấp vẫn là %s." % [ItemArtCatalog.gear_name(item), GearItem.NAMES[clampi(item.quality, 0, 5)]])
	var quote: Dictionary = _quotes(profile, inventory).quote_enhance(item.uid)
	var blockers: Array[String] = []
	var missing_stone: int = maxi(0, 1 - int(inventory.materials.get(quote["stone_id"], 0)))
	var missing_coins: int = maxi(0, int(quote["coin_cost"]) - profile.coins)
	if missing_stone > 0: blockers.append("carried_stone_required")
	if missing_coins > 0: blockers.append("bank_coins_required")
	if profile.read_only or profile.hub_inventory_quarantined: blockers.append("save_unavailable")
	var text: String = "%s · +%d → +%d: %d Linh Thạch + 1 %s trong túi.\nHệ số sát thương của món: %.2f → %.2f; cộng 3%% sát thương gốc, giữ phẩm cấp và UID." % [ItemArtCatalog.gear_name(item), quote["level"], quote["next_level"], quote["coin_cost"], MaterialCatalog.DISPLAY_NAMES[quote["stone_id"]], item.damage_factor(), item.damage_factor() + 0.03]
	text = "Mốc phần thưởng ghi khi nhặt Tàn Hồn sau thủ lĩnh. Đang có %d Tàn Hồn; nâng vũ khí dùng Linh Thạch và đá riêng.\n" % profile.souls + text
	text += "\nTại căn cứ → Thiết Lão → Cường hóa trang bị; chọn đúng món%s. 5 đá cùng cấp ghép thành 1 đá cấp sau; đá cấp 6 dùng cho +11/+12." % (" đang mặc" if equipped else " trong túi")
	text += "\nCòn thiếu trong túi: %d đá · %d Linh Thạch." % [missing_stone, missing_coins] if not blockers.is_empty() else "\nĐủ vật liệu và Linh Thạch cho mức này; bảng cường hóa sẽ kiểm tra lại khi chọn."
	if missing_stone > 0: text += "\nNếu đã có trong kho, rút về túi tại KHO CĂN CỨ. Nguồn đá: quái/rương trong hầm ngục có thể rơi đúng cấp; 5 đá cấp trước ghép thành 1 ở Thiết Lão. Không bảo đảm mỗi lượt có đá cần tìm."
	if missing_coins > 0: text += "\nNguồn Linh Thạch: nhặt Linh Thạch rồi về sảnh để giữ trong hồ sơ; Kael mua đồ đủ điều kiện từ túi theo giá trên thẻ Bán; rút đồ trong kho về túi trước nếu muốn bán. Giữ Tinh Thạch cho điều tức nếu cần."
	if blockers.has("save_unavailable"): text += "\nDữ liệu lưu cần được kiểm tra trước khi giao dịch."
	return _view("NPC / chi phí / trước → sau", "resources_ready" if blockers.is_empty() else "blocked", text, blockers)

static func _recipe_available(recipe: ResonanceDefinition,available: Dictionary) -> bool:
	var left: Dictionary = available.duplicate()
	for id: StringName in recipe.recipe_rune_ids:
		if int(left.get(id,0)) <= 0: return false
		left[id] -= 1
	return true

static func _opening_recipe(installed: Array[StringName],available: Dictionary,capacity: int) -> ResonanceDefinition:
	var resolver := ResonanceResolver.new()
	var current: ResonanceDefinition = resolver.resolve(installed,capacity,RECIPES)
	if current != null and not current.recipe_rune_ids.is_empty(): return current
	if capacity >= FIRESTORM.recipe_rune_ids.size() and _recipe_available(FIRESTORM,available): return FIRESTORM
	# Any owned single rune can start the loop; never require all 18 recipes or
	# downgrade an older valid exact loadout. Resources remain the spell authority.
	for recipe: ResonanceDefinition in RECIPES:
		if recipe.recipe_rune_ids.size() == 1 and capacity >= 1 and _recipe_available(recipe,available): return recipe
	# Start with one learnable rune when nothing is owned. The two-rune example
	# is a later option; it must not look like an entry fee for a first trip.
	for recipe: ResonanceDefinition in RECIPES:
		if recipe.recipe_rune_ids.size()==1 and capacity>=1:return recipe
	return FIRESTORM

static func _talisman(inventory: GearInventory,profile: SanctuaryProfile = null) -> Dictionary:
	var installed: Array[StringName] = []
	var available: Dictionary = inventory.bag.duplicate()
	for index: int in GearInventory.CATALYST_INDICES:
		if index >= inventory.slots.size(): continue
		var rune_id: StringName = inventory.slots[index]
		if rune_id == &"": continue
		installed.append(rune_id)
		available[rune_id] = int(available.get(rune_id, 0)) + 1
	for index: int in [3, 6, 7]:
		if index < inventory.slots.size() and inventory.slots[index] != &"":
			var rune_id: StringName = inventory.slots[index]
			available[rune_id] = int(available.get(rune_id, 0)) + 1
	var resolver := ResonanceResolver.new()
	var recipe: ResonanceDefinition = _opening_recipe(installed,available,inventory.catalyst_capacity)
	var exact: bool = resolver.canonical_key(installed) == resolver.canonical_key(recipe.recipe_rune_ids) and installed.size() <= inventory.catalyst_capacity
	var catalyst: GearItem = inventory.items.get(inventory.catalyst_uid)
	var blockers: Array[String] = []
	if catalyst == null or catalyst.kind != &"catalyst" or not catalyst.can_equip(): blockers.append("catalyst_required")
	if inventory.catalyst_capacity < recipe.recipe_rune_ids.size(): blockers.append("catalyst_slots_required")
	var remaining: Dictionary = available.duplicate()
	var ingredients: Array[String] = []
	for id: StringName in recipe.recipe_rune_ids:
		ingredients.append(inventory.get_rune(id).display_name)
		if int(remaining.get(id, 0)) <= 0: blockers.append("rune_"+String(id)+"_required")
		else: remaining[id] -= 1
	var text: String = "Một bộ để thử: %s · %s. Hành trang (Tab) → Bùa → chọn các ô Catalyst và đúng RuneShard; ô bùa trên vũ khí là phần riêng. Tháo rune thừa: bộ phải khớp đủ số lượng, kể cả rune trùng.\nCatalyst: %d ô; đang lắp %d rune. Không cần học đủ 18 công thức." % [recipe.display_name," + ".join(ingredients),inventory.catalyst_capacity,installed.size()]
	if not blockers.is_empty(): text += "\nCòn thiếu Catalyst/ô hoặc RuneShard đúng bộ. Tìm rương ở phía trái trên bục cao của chặng KHÁM PHÁ BÍ MẬT; đến gần rồi E mở, E nhặt rune đã rơi; rương nhỏ có 2, rương lớn có 3 rune ngẫu nhiên. Chưa có đúng bộ thì dùng một rune đang có; hướng dẫn sẽ chọn phép đơn hiện có."
	elif exact: text += "\nĐúng bộ. Đóng Hành trang, hướng vào mộc nhân tại SÂN LUYỆN rồi dùng I / chuột phải để thử khi đủ năng lượng chiến đấu; xem thanh năng lượng. Hồi nền %.1f giây, hiệu ứng trang bị có thể đổi thời gian hồi thực tế." % recipe.cooldown_seconds
	else: text += "\nĐã sở hữu đủ RuneShard cho bộ này. Tháo rune ở vũ khí nếu cần rồi lắp đúng bộ vào Catalyst; thử I / chuột phải trên mộc nhân."
	text += "\nKhi chết chỉ mất nguyên liệu mới nhặt trong chuyến; giữ trang bị, bùa, thuốc còn lại, Linh Thạch và nguyên liệu mang từ căn cứ chưa dùng. Sau tầng đã hoàn thành, tới lối ra bên phải, E → Trở về sảnh để giữ đồ đã nhặt; không tự nhặt đồ còn trên đất. E → Tiếp tục xuống tầng nếu muốn đi tiếp, hoặc Ở lại nhặt đồ. Về sớm không tính thắng thủ lĩnh; lượt sau bắt đầu từ Tiền Sảnh. Mốc nhiệm vụ không cấp rune."
	var teacher: String = "Thanh Vy" if profile != null and profile.opening_progress["completed"].has("thanh_vy_met") else "người giúp đỡ tại căn cứ"
	text += "\nCó thể học nguyên tố tại %s → Học & chế bùa: học một lần nhận 1 bản bùa Thường, giữ kiến thức sau khi chết; chế thêm dùng nguyên liệu đang mang. Bùa nhặt từ rương vẫn lắp được dù chưa học." % teacher
	var view: Dictionary = _view("Ghép đúng bộ → thử bùa", "blocked" if not blockers.is_empty() else "exact_set" if exact else "install_needed", text, blockers)
	view["recipe_id"] = recipe.id; view["recipe_ids"] = recipe.recipe_rune_ids.duplicate()
	return view

static func first_loop(profile: SanctuaryProfile,inventory: GearInventory) -> Dictionary:
	if profile == null or inventory == null: return {"action":"Mở lại bảng sau khi vào vùng chơi.","body":"Chưa đọc được phiên hiện tại.","progress":"Chưa khả dụng","spell_ready":false,"power_ready":false}
	var spell: Dictionary = _talisman(inventory,profile)
	var enhancement: Dictionary = _enhancement(profile,inventory)
	var power: bool = false
	var weapon: GearItem = inventory.items.get(inventory.equipped_weapon_uid)
	if weapon != null and weapon.can_equip() and weapon.enhancement_level >= 1: power = true
	if weapon != null and weapon.can_equip() and weapon.definition_id == WorldProgressionCatalog.BOUNTY_REWARD and profile.bounty_claimed and profile.unlocked_weapons.has(WorldProgressionCatalog.BOUNTY_REWARD): power = true
	if Cultivation.valid(profile.cultivation_progress,profile.material_stash) and int(profile.cultivation_progress["actors"]["player"]["stage"]) >= 1: power = true
	for id: StringName in WorldProgressionCatalog.UPGRADES:
		if profile.permanent_upgrades.get(id,0) > 0: power = true
	var exact: bool = spell["status"] == "exact_set"
	var boss_name: String = "Golem" if profile.bounty_accepted or int(profile.boss_proofs.get(&"golem",0)) > 0 else "thủ lĩnh"
	var action: String
	if not exact:
		action = "Chuẩn bị một bùa trước %s: " % boss_name + ("vào hầm ngục, qua Tiền Sảnh tới KHÁM PHÁ BÍ MẬT, E mở rương/nhặt rune rồi E ở lối ra để về sảnh nếu cần." if spell["status"] == "blocked" else "Tab → Bùa, lắp đúng bộ đang đề nghị vào Catalyst; đóng bảng rồi thử I / chuột phải trên mộc nhân ở SÂN LUYỆN.")
	elif not power:
		action = "Bùa đã đúng bộ. Đến Thiết Lão → Cường hóa, chọn vũ khí đang mặc và xác nhận giá đang có." if enhancement["status"] == "resources_ready" else "Bùa đã đúng bộ. " + cultivation_next_step(profile, inventory)
	else:
		action = "Bùa và sức mạnh đã chuẩn bị. Nếu chưa có chứng tích sau lời hẹn, vào cổng hầm ngục và tiến tới %s; sau khi nhận kiếm, trang bị bằng Tab rồi thử bộ đòn và bùa ở lượt tiếp theo từ Tiền Sảnh." % boss_name
	var body: String = "1. Nhận lời hẹn Vô Danh tại căn cứ trước khi hạ %s; M / View xem tiến độ, nhận thưởng một lần khi đủ chứng tích.\n2. %s\n%s\n3. Chọn cường hóa hoặc tu luyện, không cần hoàn tất cả hai.\n%s\n%s\n4. Về sảnh: giữ nguyên liệu cần dùng trong túi; KHO CĂN CỨ chỉ cất phần muốn bảo quản hoặc rút về khi cần. Nhận kiếm nếu đủ lời hẹn, Tab so sánh/trang bị rồi trở lại cổng hầm ngục; chuyến mới bắt đầu từ Tiền Sảnh. Về sớm chưa mở khóa thưởng thủ lĩnh." % [boss_name,action,spell["body"],enhancement["body"],_cultivation(profile, inventory)["body"]]
	return {"action":action,"body":body,"progress":"Bùa %d/1 · sức mạnh %d/1" % [1 if exact else 0,1 if power else 0],"spell_ready":exact,"power_ready":power,"recipe_id":spell["recipe_id"]}

static func _permanent_upgrade(profile: SanctuaryProfile, inventory: GearInventory) -> Dictionary:
	var healer_known: bool = profile.opening_progress["completed"].has("thanh_vy_met")
	var names: Dictionary = {&"max_hp":"Máu tối đa", &"max_mana":"Mana tối đa", &"mana_regen":"Hồi năng lượng", &"rune_capacity":"Ô bùa Catalyst"}
	var text: String = "Tại căn cứ → %s → chọn nâng cấp vĩnh viễn. Đây là thao tác ghi mốc nâng cấp đầu tiên; cường hóa vũ khí dùng một bảng khác.\nĐang có %d Tàn Hồn." % ["Thanh Vy" if healer_known else "người giúp đỡ", profile.souls]
	var affordable: bool = false
	var has_level: bool = false
	var economy: EconomySession = _quotes(profile, inventory)
	for id: StringName in WorldProgressionCatalog.UPGRADES:
		var quote: Dictionary = economy.quote_upgrade(id)
		if int(quote["level"]) >= int(quote["max_level"]): text += "\n%s: đã đạt giới hạn." % names[id]; continue
		has_level = true
		affordable = affordable or bool(quote["can_buy"])
		text += "\n%s: +%.0f → +%.0f %s · %d Tàn Hồn (thiếu %d)." % [names[id], quote["value"], float(quote["value"]) + float(WorldProgressionCatalog.VALUES[id]), quote["unit"], quote["cost"], maxi(0, int(quote["cost"]) - profile.souls)]
	if profile.read_only or profile.hub_inventory_quarantined: return _view("Nâng cấp vĩnh viễn", "blocked", text+"\nDữ liệu lưu cần được kiểm tra trước khi mua.", ["save_unavailable"])
	var blockers: Array[String] = []
	if has_level and not affordable: blockers.append("souls_required")
	return _view("Nâng cấp vĩnh viễn", "resources_ready" if affordable else "souls_required" if has_level else "capped", text, blockers)

static func _cultivation(profile: SanctuaryProfile, inventory: GearInventory = null) -> Dictionary:
	var view: Dictionary = cultivation_view(profile, inventory)
	var blockers: Array[String] = []
	blockers.assign(view["blockers"])
	return _view("Tu luyện → đột phá", view["status"], view["body"], blockers)

static func cultivation_view(profile: SanctuaryProfile, inventory: GearInventory) -> Dictionary:
	var unavailable: Dictionary = {"status":"unavailable", "action":"Về SÂN LUYỆN → TU LUYỆN để kiểm tra trạng thái lưu và hành trang.", "location":"Căn Cứ Lữ Khách · Sân Luyện", "progress":"Chưa đọc được tiến độ", "reward":"Chưa xác minh", "body":"Chưa đọc được tu luyện và vật liệu đang mang.", "blockers":["profile_unavailable"]}
	if profile == null or inventory == null or profile.read_only or profile.hub_inventory_quarantined or not Cultivation.valid(profile.cultivation_progress, profile.material_stash): return unavailable
	var progress: Dictionary = profile.cultivation_progress
	var actor: Dictionary = progress["actors"]["player"]
	var config: Dictionary = progress["config"]
	var stage: int = int(actor["stage"])
	if stage >= 3:
		var done: String = "Đã lên Trúc Cơ. Tab → Bùa, ghép đúng bộ từ 2 bùa; đóng bảng rồi dùng I / chuột phải để thử Liên Ấn trên các mộc nhân gần nhau. Nhánh G đã chọn vẫn giữ nguyên."
		return {"status":"opening_complete", "action":done, "location":"Căn Cứ Lữ Khách · Sân Luyện", "progress":"Cảnh giới 3/3 · hoàn tất vòng đầu", "reward":FoundationResonance.description(), "body":done + "\n" + FoundationResonance.description() + " Cảnh giới tiếp theo chưa có trong vòng này.", "blockers":[]}
	var energy: int = maxi(0, int(config["energy_thresholds"][stage]) - int(actor["energy"]))
	var mastery: int = maxi(0, int(config["mastery_thresholds"][stage]) - int(actor["mastery"]))
	var insight: int = maxi(0, int(config["insight_thresholds"][stage]) - actor["insight_ids"].size())
	var dust_cost: int = int(config["final_dust_cost"] if stage == 2 else config["interim_dust_cost"])
	var dust: int = maxi(0, dust_cost - int(inventory.materials.get(&"dust", 0)))
	var crystal: int = maxi(0, int(config["training_cost"]) - int(inventory.materials.get(&"crystal", 0)))
	var souls: int = maxi(0, int(config["final_soul_cost"]) - profile.souls) if stage == 2 else 0
	var proof: int = maxi(0, int(config["final_golem_proof"]) - int(profile.boss_proofs.get(&"golem", 0))) if stage == 2 else 0
	var blockers: Array[String] = []
	var missing: Array[String] = []
	if energy > 0: blockers.append("energy_required"); missing.append("%d tu vi" % energy)
	if mastery > 0: blockers.append("mastery_required"); missing.append("%d thông thạo" % mastery)
	if insight > 0: blockers.append("insight_required"); missing.append("%d lĩnh ngộ" % insight)
	if dust > 0: blockers.append("carried_dust_required"); missing.append("%d Bột Phép trong túi" % dust)
	if souls > 0: blockers.append("souls_required"); missing.append("%d Tàn Hồn" % souls)
	if proof > 0: blockers.append("boss_proof_required"); missing.append("%d chứng tích Golem" % proof)
	if energy > 0 and crystal > 0: blockers.append("training_crystal_required"); missing.append("%d Tinh Thạch trong túi cho một phiên điều tức" % crystal)
	var action: String = "Đủ điều kiện lên %s: về SÂN LUYỆN → TU LUYỆN → %s%s." % [config["stage_labels"][stage + 1], CultivationLabels.breakthrough_action(stage), " và chọn Hồi Phong Kiếm hoặc Tỏa Linh Ấn" if stage == 2 else ""]
	var location: String = "Căn Cứ Lữ Khách · Sân Luyện"
	if mastery > 0:
		action = "Đến mộc nhân ở SÂN LUYỆN; đánh cận chiến trúng thêm %d lần hợp lệ để đủ thông thạo cho %s." % [mastery, config["stage_labels"][stage + 1]]
	elif energy > 0:
		if crystal > 0:
			action = "Cần thêm %d Tinh Thạch trong túi cho một phiên điều tức. %s" % [crystal, _material_source(profile, &"crystal", crystal)]
			location = "Kho Căn Cứ" if int(profile.material_stash.get(&"crystal", 0)) > 0 else "Hầm ngục · quái / rương"
		else:
			action = "Đến SÂN LUYỆN → TU LUYỆN → Bắt đầu điều tức, đóng bảng và đứng tại sân. Còn thiếu %d tu vi; mỗi phiên dùng %d Tinh Thạch đang mang." % [energy, config["training_cost"]]
	elif insight > 0:
		var next_id: String = ""
		for id: String in ["explored", "thanh_vy_met", "golem_defeated"]:
			if not actor["insight_ids"].has(id): next_id = id; break
		if profile.opening_progress["completed"].has(next_id):
			action = "Còn thiếu %d lĩnh ngộ; mốc đã hoàn thành nhưng đang chờ lưu thưởng. Mở M → chọn nhiệm vụ tương ứng → Thử lưu lại lĩnh ngộ tại căn cứ." % insight
		elif next_id == "explored":
			action = "Còn thiếu %d lĩnh ngộ. Đến biển ĐƯỜNG BỘ ở sân căn cứ, E qua cửa để nhận 1 lĩnh ngộ khám phá." % insight
			location = "Căn Cứ Lữ Khách · lối Đường Bộ"
		elif next_id == "thanh_vy_met":
			action = "Còn thiếu %d lĩnh ngộ. Đến Thanh Vy tại căn cứ, E nói chuyện để nhận 1 lĩnh ngộ từ cuộc gặp." % insight
			location = "Căn Cứ Lữ Khách · Thanh Vy"
		else:
			action = "Còn thiếu %d lĩnh ngộ. Xuống hầm ngục và hạ Golem để nhận lĩnh ngộ từ chiến thắng; trở về sân luyện." % insight
			location = "Hầm ngục · Golem Cổ Bảo"
	elif dust > 0:
		action = "Cần thêm %d Bột Phép trong túi để đột phá. %s" % [dust, _material_source(profile, &"dust", dust)]
		location = "Kho Căn Cứ" if int(profile.material_stash.get(&"dust", 0)) > 0 else "Hầm ngục · quái / rương"
	elif proof > 0:
		action = "Hạ Golem trong hầm ngục để ghi thêm %d chứng tích cho đột phá Trúc Cơ; không cần có đồ rơi để ghi chiến thắng." % proof
		location = "Hầm ngục · Golem Cổ Bảo"
	elif souls > 0:
		action = "Nhặt thêm %d Tàn Hồn từ phần rơi của quái/thủ lĩnh bằng E; phần rơi có thể trống. Tàn Hồn đã nhặt được giữ sau chuyến đi." % souls
		location = "Hầm ngục · quái / thủ lĩnh"
	var counts: String = "%s → %s · Tu vi %d/%d · Thông thạo %d/%d · Lĩnh ngộ %d/%d · Bột Phép trong túi %d/%d" % [config["stage_labels"][stage], config["stage_labels"][stage + 1], actor["energy"], config["energy_thresholds"][stage], actor["mastery"], config["mastery_thresholds"][stage], actor["insight_ids"].size(), config["insight_thresholds"][stage], inventory.materials.get(&"dust", 0), dust_cost]
	if stage == 2: counts += " · Chứng tích Golem %d/%d · Tàn Hồn %d/%d" % [profile.boss_proofs.get(&"golem", 0), config["final_golem_proof"], profile.souls, config["final_soul_cost"]]
	var reward: String = FoundationResonance.description()+" Chọn 1 động tác: Hồi Phong Kiếm hoặc Tỏa Linh Ấn (G)." if stage == 2 else "Tiến lên %s và mở mốc tu luyện tiếp theo" % config["stage_labels"][stage + 1]
	var text: String = "VIỆC TIẾP THEO: %s\nNƠI ĐẾN: %s\nTIẾN ĐỘ: %s\n%s\nKẾT QUẢ: %s" % [action, location, counts, "SẴN SÀNG ĐỘT PHÁ · Chọn nút tại Sân Luyện để xác nhận chi phí." if blockers.is_empty() else "CÒN THIẾU: " + "; ".join(missing), reward]
	text += "\nTu vi tích lũy khác mana chiến đấu. Điều tức: %d Tinh Thạch đang mang / phiên %.1f giây chơi, nhận %d năng lượng cơ bản; tư chất ảnh hưởng lượng thực nhận. Đóng bảng để luyện; pause/bảng mở không tích thời gian." % [config["training_cost"], float(config["training_session_ticks"]) / float(config["ticks_per_second"]), config["training_gain"]]
	text += "\nNguồn: thông thạo từ đòn cận chiến trúng mộc nhân/quái; lĩnh ngộ từ Đường Bộ, Thanh Vy và Golem, mỗi mốc một lần. Vật liệu lấy từ quái/rương hoặc rút ở kho; Bột Phép còn có từ phân giải đồ dự phòng đã tháo. Đồ rơi không bảo đảm mỗi lượt."
	text += "\nTài trợ người hái thuốc là tùy chọn; người này rút lui dưỡng thương không chặn tu luyện của lữ khách."
	return {"status":"requirements_ready" if blockers.is_empty() else "blocked", "action":action, "location":location, "progress":counts, "reward":reward, "body":text, "blockers":blockers}

static func _material_source(profile: SanctuaryProfile, id: StringName, missing: int) -> String:
	var stored: int = int(profile.material_stash.get(id, 0))
	if stored > 0: return "Đến KHO CĂN CỨ → Rút %d %s; đang có %d trong kho.%s" % [mini(missing, stored), MaterialCatalog.DISPLAY_NAMES[id], stored, " Phần còn thiếu kiếm từ quái/rương trong hầm ngục." if stored < missing else ""]
	if id==&"crystal":return OpeningRewardCatalog.source_hint(id)
	return "Kiếm từ quái/rương trong hầm ngục rồi nhặt bằng E; phần rơi không bảo đảm." + (" Có thể phân giải món dự phòng đã tháo để lấy Bột Phép." if id == &"dust" else "")

static func cultivation_next_step(profile: SanctuaryProfile, inventory: GearInventory = null) -> String:
	return cultivation_view(profile, inventory)["action"]

static func cultivation_station(profile: SanctuaryProfile, carried: GearInventory = null) -> StringName:
	if profile == null or not Cultivation.valid(profile.cultivation_progress, profile.material_stash): return &"training"
	var actor: Dictionary = profile.cultivation_progress["actors"]["player"]
	var config: Dictionary = profile.cultivation_progress["config"]
	var stage: int = int(actor["stage"])
	if stage >= 3 or int(actor["mastery"]) < int(config["mastery_thresholds"][stage]): return &"training"
	var materials: Dictionary = profile.cultivation_materials(carried)
	if int(actor["energy"]) < int(config["energy_thresholds"][stage]):
		if int(materials.get(&"crystal",0)) >= int(config["training_cost"]): return &"training"
		return &"stash" if int(profile.material_stash.get(&"crystal",0)) > 0 else &"portal"
	if actor["insight_ids"].size() < int(config["insight_thresholds"][stage]):
		if not actor["insight_ids"].has("explored"): return &"exterior_road"
		if not actor["insight_ids"].has("thanh_vy_met"): return NpcCatalog.HEALER
		return &"portal"
	var dust: int = int(config["final_dust_cost"] if stage == 2 else config["interim_dust_cost"])
	if int(materials.get(&"dust",0)) < dust: return &"stash" if int(profile.material_stash.get(&"dust",0)) > 0 else &"portal"
	if stage == 2 and (int(profile.boss_proofs.get(&"golem",0)) < int(config["final_golem_proof"]) or profile.souls < int(config["final_soul_cost"])): return &"portal"
	return &"training"

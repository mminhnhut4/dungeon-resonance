class_name OpeningProgressionGuide
extends RefCounted
## Detached, read-only hints. Existing quest, inventory and profile owners decide
## rewards, travel, transactions and completion. Never initialize a save/session.
const Cultivation = preload("res://scripts/cultivation/opening_cultivation_state.gd")
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
		&"first_upgrade": return _cultivation(profile)
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
	var text: String = "Vật liệu nhặt được nằm trong hành trang. Về căn cứ → KHO CĂN CỨ → Gửi vật liệu; cường hóa và điều tức dùng vật liệu trong kho. Vật liệu đã gửi được giữ qua lần tử trận."
	text += "\nĐang mang: %d Tinh Thạch · %d Bột Phép · %d đá cấp 1. Trong kho: %d · %d · %d." % [inventory.materials.get(&"crystal", 0), inventory.materials.get(&"dust", 0), inventory.materials.get(&"enhancement_stone_1", 0), profile.material_stash.get(&"crystal", 0), profile.material_stash.get(&"dust", 0), profile.material_stash.get(&"enhancement_stone_1", 0)]
	text += "\nQuái và rương trong chuyến đi có thể rơi vật liệu/đá; phần rơi thay đổi, không đảm bảo mỗi lần. Tháo món dự phòng rồi phân giải để lấy Kim Loại/Bột Phép. Kael mua Tinh Thạch/Tinh Chất Slime từ túi từng món hoặc cả số đã cất trong kho để đổi Linh Thạch; cân nhắc giữ Tinh Thạch cho điều tức."
	var carried: bool = false
	for material_id: StringName in MaterialCatalog.IDS:
		if inventory.materials.get(material_id, 0) > 0 and not MaterialCatalog.material_policy(material_id)["lineage_bound"]: carried = true
	return _view("Kiếm vật liệu → gửi kho", "deposit_needed" if carried else "collect_or_use_bank", text)

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
	var missing_stone: int = maxi(0, 1 - int(profile.material_stash.get(quote["stone_id"], 0)))
	var missing_coins: int = maxi(0, int(quote["coin_cost"]) - profile.coins)
	if missing_stone > 0: blockers.append("bank_stone_required")
	if missing_coins > 0: blockers.append("bank_coins_required")
	if profile.read_only or profile.hub_inventory_quarantined: blockers.append("save_unavailable")
	var text: String = "%s · +%d → +%d: %d Linh Thạch + 1 %s trong kho.\nHệ số sát thương của món: %.2f → %.2f; cộng 3%% sát thương gốc, giữ phẩm cấp và UID." % [ItemArtCatalog.gear_name(item), quote["level"], quote["next_level"], quote["coin_cost"], MaterialCatalog.DISPLAY_NAMES[quote["stone_id"]], item.damage_factor(), item.damage_factor() + 0.03]
	text = "Mốc phần thưởng ghi khi nhặt Tàn Hồn sau thủ lĩnh. Đang có %d Tàn Hồn; nâng vũ khí dùng Linh Thạch và đá riêng.\n" % profile.souls + text
	text += "\nTại căn cứ → Thiết Lão → Cường hóa trang bị; chọn đúng món%s. 5 đá cùng cấp ghép thành 1 đá cấp sau; đá cấp 6 dùng cho +11/+12." % (" đang mặc" if equipped else " trong túi")
	text += "\nCòn thiếu trong kho: %d đá · %d Linh Thạch." % [missing_stone, missing_coins] if not blockers.is_empty() else "\nĐủ vật liệu và Linh Thạch cho mức này; bảng cường hóa sẽ kiểm tra lại khi chọn."
	if missing_stone > 0: text += "\nNguồn đá: quái/rương trong hầm ngục có thể rơi đúng cấp; 5 đá cấp trước ghép thành 1 ở Thiết Lão. Không bảo đảm mỗi lượt có đá cần tìm."
	if missing_coins > 0: text += "\nNguồn Linh Thạch: nhặt Linh Thạch rồi về sảnh để giữ trong hồ sơ; Kael mua Tinh Thạch/Tinh Chất Slime từ túi từng món hoặc cả số trong kho theo giá trên thẻ Bán. Giữ Tinh Thạch cho điều tức nếu cần."
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
	text += "\nĐồ đang mang mất khi chết. Sau tầng đã hoàn thành, tới lối ra bên phải, E → Trở về sảnh để giữ đồ đã nhặt; không tự nhặt đồ còn trên đất. E → Tiếp tục xuống tầng nếu muốn đi tiếp, hoặc Ở lại nhặt đồ. Về sớm không tính thắng thủ lĩnh; lượt sau bắt đầu từ Tiền Sảnh. Mốc nhiệm vụ không cấp rune."
	var teacher: String = "Thanh Vy" if profile != null and profile.opening_progress["completed"].has("thanh_vy_met") else "người giúp đỡ tại căn cứ"
	text += "\nCó thể học nguyên tố tại %s → Học & chế bùa: học một lần nhận 1 bản bùa Thường, giữ kiến thức sau khi chết; chế thêm dùng vật liệu trong kho. Bùa nhặt từ rương vẫn lắp được dù chưa học." % teacher
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
		action = "Bùa đã đúng bộ. Đến Thiết Lão → Cường hóa, chọn vũ khí đang mặc và xác nhận giá đang có." if enhancement["status"] == "resources_ready" else "Bùa đã đúng bộ. Chọn một đường tăng sức mạnh: kiếm đá/Linh Thạch để cường hóa tại Thiết Lão, hoặc xem điều kiện TU LUYỆN ở SÂN LUYỆN."
	else:
		action = "Bùa và sức mạnh đã chuẩn bị. Nếu chưa có chứng tích sau lời hẹn, vào cổng hầm ngục và tiến tới %s; sau khi nhận kiếm, trang bị bằng Tab rồi thử bộ đòn và bùa ở lượt tiếp theo từ Tiền Sảnh." % boss_name
	var body: String = "1. Nhận lời hẹn Vô Danh tại căn cứ trước khi hạ %s; M / View xem tiến độ, nhận thưởng một lần khi đủ chứng tích.\n2. %s\n%s\n3. Chọn cường hóa hoặc tu luyện, không cần hoàn tất cả hai.\n%s\n%s\n4. Về sảnh: KHO CĂN CỨ → Gửi toàn bộ vật liệu đang mang. Nhận kiếm nếu đủ lời hẹn, Tab so sánh/trang bị rồi trở lại cổng hầm ngục; chuyến mới bắt đầu từ Tiền Sảnh. Về sớm chưa mở khóa thưởng thủ lĩnh." % [boss_name,action,spell["body"],enhancement["body"],_cultivation(profile)["body"]]
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

static func _cultivation(profile: SanctuaryProfile) -> Dictionary:
	if profile.read_only or not Cultivation.valid(profile.cultivation_progress, profile.material_stash): return _view("Tu luyện → đột phá", "unavailable", "Chưa đọc được tiến triển tu luyện hợp lệ. Tại căn cứ, xem bảng TU LUYỆN ở SÂN LUYỆN; cần dữ liệu lưu hợp lệ để bắt đầu.", ["cultivation_unavailable"])
	var progress: Dictionary = profile.cultivation_progress
	var config: Dictionary = progress["config"]
	var actor: Dictionary = progress["actors"]["player"]
	var stage: int = actor["stage"]
	var text: String = "%s · Thông số sơ bộ hiện tại. Tại căn cứ → SÂN LUYỆN → TU LUYỆN. Rèn đòn cận chiến trúng mộc nhân/quái để tăng thông thạo; dấu mốc đã ghi đem lại lĩnh ngộ." % config["stage_labels"][stage]
	text += "\nĐiều tức: %d Tinh Thạch trong kho / phiên %.1f giây chơi, nhận %d năng lượng cơ bản. Tư chất ảnh hưởng lượng thực nhận. Đóng bảng để luyện; pause/bảng mở không tích thời gian." % [config["training_cost"], float(config["training_session_ticks"]) / float(config["ticks_per_second"]), config["training_gain"]]
	text += "\nNăng lượng tu luyện là tu vi tích lũy, khác mana dùng tung chiêu. Tài trợ người hái thuốc là tùy chọn; người này rút lui dưỡng thương không chặn tu luyện của lữ khách."
	text += "\nBa lĩnh ngộ: bước qua ĐƯỜNG BỘ, nói chuyện với Thanh Vy, hạ Golem. Mỗi mốc chỉ ghi một lần; đánh mộc nhân nhiều lần không thay lĩnh ngộ."
	if stage >= 3: return _view("Tu luyện → đột phá", "opening_complete", text+"\nĐã hoàn thành vòng tu luyện mở đầu. Nhánh đã chọn dùng G; cảnh giới tiếp theo chưa có trong vòng này.")
	var blockers: Array[String] = []
	for field: String in ["energy", "mastery"]:
		if int(actor[field]) < int(config[field+"_thresholds"][stage]): blockers.append(field+"_required")
	if actor["insight_ids"].size() < int(config["insight_thresholds"][stage]): blockers.append("insight_required")
	var dust: int = int(config["final_dust_cost"] if stage == 2 else config["interim_dust_cost"])
	if int(profile.material_stash.get(&"dust", 0)) < dust: blockers.append("bank_dust_required")
	text += "\nĐột phá tới %s: năng lượng %d/%d · thông thạo %d/%d · lĩnh ngộ %d/%d · Bột Phép trong kho %d/%d." % [config["stage_labels"][stage+1], actor["energy"], config["energy_thresholds"][stage], actor["mastery"], config["mastery_thresholds"][stage], actor["insight_ids"].size(), config["insight_thresholds"][stage], profile.material_stash.get(&"dust", 0), dust]
	if stage == 2:
		var proof: int = int(profile.boss_proofs.get(&"golem", 0))
		if proof < int(config["final_golem_proof"]): blockers.append("boss_proof_required")
		if profile.souls < int(config["final_soul_cost"]): blockers.append("souls_required")
		var boss_known: bool = profile.bounty_accepted or proof > 0 or profile.opening_progress["completed"].has("golem_defeated")
		text += "\nChứng tích %s %d/%d · Tàn Hồn %d/%d; chọn một nhánh ở nút đột phá." % ["Golem" if boss_known else "thủ lĩnh", proof, config["final_golem_proof"], profile.souls, config["final_soul_cost"]]
	text += "\nCòn điều kiện chưa đủ; kiểm tra các số trước dấu / và tiếp tục rèn luyện hoặc kiếm tài nguyên." if not blockers.is_empty() else "\nCác điều kiện hiển thị đã đủ; chọn nút đột phá trên bảng để xác nhận."
	if int(actor["energy"]) < int(config["energy_thresholds"][stage]) and int(profile.material_stash.get(&"crystal", 0)) < int(config["training_cost"]):
		blockers.append("training_crystal_required")
		text += "\nKho chưa đủ Tinh Thạch cho một phiên điều tức."
	if blockers.has("training_crystal_required") or blockers.has("bank_dust_required"):
		text += "\nNguồn Tinh Thạch/Bột Phép: quái/rương có thể rơi; nhặt rồi về sảnh → KHO CĂN CỨ → Gửi toàn bộ vật liệu. Tháo và phân giải món dự phòng để lấy Bột Phép; không phân giải món đang mặc. Mỗi lượt có thể không đủ tài nguyên."
	return _view("Tu luyện → đột phá", "requirements_ready" if blockers.is_empty() else "blocked", text, blockers)

static func cultivation_next_step(profile: SanctuaryProfile) -> String:
	if profile == null or not Cultivation.valid(profile.cultivation_progress, profile.material_stash):
		return "Về SÂN LUYỆN → TU LUYỆN để kiểm tra trạng thái lưu."
	var progress: Dictionary = profile.cultivation_progress
	var actor: Dictionary = progress["actors"]["player"]
	var config: Dictionary = progress["config"]
	var stage: int = int(actor["stage"])
	if stage >= 3: return "Đã lên Trúc Cơ. Trang bị đúng loại vũ khí của nhánh đã học, đóng bảng và dùng G để thử skill."
	var needed_mastery: int = int(config["mastery_thresholds"][stage]) - int(actor["mastery"])
	if needed_mastery > 0: return "Đến mộc nhân ở SÂN LUYỆN; đánh cận chiến trúng thêm %d đòn để đủ thông thạo cho %s." % [needed_mastery,config["stage_labels"][stage+1]]
	if int(actor["energy"]) < int(config["energy_thresholds"][stage]):
		if int(profile.material_stash[&"crystal"]) < int(config["training_cost"]):
			return "Nhặt Tinh Thạch từ quái/rương, về KHO CĂN CỨ → Gửi vật liệu. Điều tức dùng Tinh Thạch trong kho, không dùng Linh Thạch."
		return "Đến SÂN LUYỆN → TU LUYỆN → bắt đầu điều tức cho bản thân, rồi đóng bảng và đứng tại sân. Tu vi còn thiếu %d." % [int(config["energy_thresholds"][stage])-int(actor["energy"])]
	if actor["insight_ids"].size() < int(config["insight_thresholds"][stage]):
		if not actor["insight_ids"].has("explored"): return "Đến biển ĐƯỜNG BỘ ở sân căn cứ, E qua cửa để nhận lĩnh ngộ khám phá."
		if not actor["insight_ids"].has("thanh_vy_met"): return "Đến Thanh Vy ở căn cứ, E nói chuyện để nhận lĩnh ngộ từ cuộc gặp."
		return "Xuống hầm ngục và hạ Golem để nhận lĩnh ngộ cuối; nhặt phần rơi rồi quay về sân luyện."
	var dust: int = int(config["final_dust_cost"] if stage == 2 else config["interim_dust_cost"])
	if int(profile.material_stash[&"dust"]) < dust: return "Cất thêm %d Bột Phép vào KHO CĂN CỨ. Kiếm từ quái/rương hoặc phân giải món dự phòng đã tháo." % [dust-int(profile.material_stash[&"dust"])]
	if stage == 2 and int(profile.boss_proofs[&"golem"]) < int(config["final_golem_proof"]): return "Hạ Golem trong hầm ngục để có chứng tích cho đột phá Trúc Cơ."
	if stage == 2 and profile.souls < int(config["final_soul_cost"]): return "Nhặt thêm %d Tàn Hồn từ phần rơi của quái/thủ lĩnh trước khi đột phá Trúc Cơ." % [int(config["final_soul_cost"])-profile.souls]
	return "Đủ điều kiện lên %s: về SÂN LUYỆN → TU LUYỆN → Đột phá%s." % [config["stage_labels"][stage+1]," và chọn Hồi Phong Kiếm hoặc Tỏa Linh Ấn" if stage == 2 else ""]

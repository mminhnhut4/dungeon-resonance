class_name PowerProgressionGuide
extends RefCounted
## Read-only route across existing bag, quotes and cultivation. No flags or grants.
const Guide = preload("res://scripts/ui/opening_progression_guide.gd")
const Cultivation = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const ID: StringName = &"power_next"

static func requirement(id: StringName, name: String, have: int, need: int, icon: Texture2D = null) -> Dictionary:
	return {"id":id,"name":name,"have":have,"need":need,"missing":maxi(0,need-have),"icon":icon if icon != null else ItemArtCatalog.icon(id)}

static func rune_counts(inventory: GearInventory) -> Dictionary:
	var counts: Dictionary=inventory.bag.duplicate()
	for id: StringName in inventory.slots:
		if id!=&"":counts[id]=int(counts.get(id,0))+1
	return counts

static func _spell(profile: SanctuaryProfile, inventory: GearInventory, foundation: bool) -> Dictionary:
	var hint: Dictionary=Guide._talisman(inventory,profile)
	var ids: Array[StringName]=[]
	ids.assign(hint["recipe_ids"])
	var recipe: ResonanceDefinition=Guide.RECIPES.filter(func(r: ResonanceDefinition) -> bool:return r.id==hint["recipe_id"])[0]
	var seek_pair: bool=foundation and recipe.recipe_rune_ids.size()<2
	if seek_pair:
		recipe=Guide.FIRESTORM;ids.assign(recipe.recipe_rune_ids)
	var owned: Dictionary=rune_counts(inventory)
	var needs: Dictionary={}
	for id: StringName in ids:needs[id]=int(needs.get(id,0))+1
	var requirements: Array[Dictionary]=[]
	var missing: Array[StringName]=[]
	for id: StringName in needs:
		requirements.append(requirement(id,"Bùa "+RuneLearningService.NAMES[id]+" đang mang / đang lắp",owned.get(id,0),needs[id],ItemArtCatalog.RUNE_ICONS[id]))
		if owned.get(id,0)<needs[id]:missing.append(id)
	if seek_pair:hint["status"]="install_needed" if missing.is_empty() and inventory.catalyst_capacity>=ids.size() and not hint["blockers"].has("catalyst_required") else "blocked"
	var station: StringName=&"training"
	var action: String="Tab → Bùa: lắp đúng %s vào Catalyst; tháo bùa thừa, đóng bảng rồi dùng I / chuột phải thử ở Sân Luyện."%recipe.display_name
	var source: String="Bùa nhặt được dùng ngay. Rương KHÁM PHÁ BÍ MẬT có rune ngẫu nhiên; E mở rồi E nhặt. Vũ khí quyết định bộ đòn, bùa là đòn tấn công chính."
	if not missing.is_empty():
		var economy: EconomySession=Guide._quotes(profile,inventory)
		economy.hub_access=true;economy.persist_safe_inventory=true
		var learning:=RuneLearningService.new();learning.economy=economy
		var offer: Dictionary=learning.quote(missing[0])
		station=NpcCatalog.HEALER if offer["can_learn"] or offer["can_craft"] else &"portal"
		if offer["learned"]:
			for material: StringName in offer["craft_materials"]:
				requirements.append(requirement(material,MaterialCatalog.DISPLAY_NAMES[material]+" trong túi / 1 bản chế",inventory.materials.get(material,0),offer["craft_materials"][material]))
			action="Thiếu bùa %s. Thanh Vy → Học & chế bùa → Chế; mỗi bản dùng vật liệu trong túi như bên dưới."%offer["name"]
		else:
			requirements.append(requirement(&"souls","Tàn Hồn để học "+offer["name"],profile.souls,offer["cost"],ItemArtCatalog.icon(&"crystal")))
			action="Thiếu bùa %s. Thanh Vy → Học & chế bùa: học một lần nhận 1 bản, hoặc tìm rương trong hầm ngục. %s"%[offer["name"],offer["learn_lock_hint"]]
			if not offer["can_learn"] and offer["cost"]>profile.souls:
				action="Học bùa %s cần %d Tàn Hồn (đang %d). Dùng kiếm đi ngục → E nhặt đồ rơi; tầng đã dọn, E ở lối ra → Về sảnh. Bùa chưa bắt buộc cho chuyến đầu."%[offer["name"],offer["cost"],profile.souls]
		if offer["learned"] and not offer["can_craft"]:
			for material: StringName in offer["craft_materials"]:
				if inventory.materials.get(material,0)<int(offer["craft_materials"][material]) and profile.material_stash.get(material,0)>0:station=&"stash";break
		if station==&"stash":action="Kho Căn Cứ → Rút vật liệu về túi, rồi Thanh Vy → Học & chế bùa → Chế. Chi phí đọc từ túi bên dưới."
	elif hint["blockers"].has("catalyst_required"):
		station=&"training";action="Tab → Bùa: chọn Catalyst dùng được trước khi lắp bộ. Xem Catalyst đang sở hữu; không cần học lại rune đã nhặt."
	return {"key":&"runes","title":"Ghép bùa","done":hint["status"]=="exact_set","station":station,"action":action,"requirements":requirements,"result":"%s · sát thương nền công thức %.0f · hồi nền %.1fs · %.0f mana/lần."%[recipe.display_name,recipe.base_damage,recipe.cooldown_seconds,ResonanceController.CAST_ENERGY_COST],"source":source,"recipe":recipe}

static func _upgrade(profile: SanctuaryProfile, inventory: GearInventory) -> Dictionary:
	var weapon: GearItem=inventory.items.get(inventory.equipped_weapon_uid)
	var done: bool=weapon!=null and weapon.can_equip() and weapon.enhancement_level>=1
	for id: StringName in WorldProgressionCatalog.UPGRADES:done=done or profile.permanent_upgrades.get(id,0)>0
	var requirements: Array[Dictionary]=[]
	var station: StringName=NpcCatalog.SMITH
	var result: String="Cường hóa giữ UID/phẩm chất, mỗi +1 thêm 3% sát thương nền."
	var action: String="Thiết Lão → Cường hóa, chọn vũ khí và xem báo giá."
	var ready: bool=false
	var economy: EconomySession=Guide._quotes(profile,inventory)
	economy.hub_access=true;economy.persist_safe_inventory=true
	if weapon!=null and weapon.can_equip() and weapon.enhancement_level<12:
		var quote: Dictionary=economy.quote_enhance(weapon.uid)
		ready=quote["can_enhance"]
		requirements.append(requirement(quote["stone_id"],MaterialCatalog.DISPLAY_NAMES[quote["stone_id"]]+" trong túi",inventory.materials.get(quote["stone_id"],0),1))
		requirements.append(requirement(&"coins","Linh Thạch",profile.coins,quote["coin_cost"]))
		result="%s +%d → +%d · hệ số sát thương món %.2f → %.2f."%[ItemArtCatalog.gear_name(weapon),quote["level"],quote["next_level"],weapon.damage_factor(),weapon.damage_factor()+0.03]
		if not ready:
			station=&"stash" if inventory.materials.get(quote["stone_id"],0)<1 and profile.material_stash.get(quote["stone_id"],0)>0 else &"portal"
			action="Cường hóa ở Thiết Lão dùng đúng đá trong túi và Linh Thạch. Rút đá đã cất hoặc nhặt từ quái/rương; 5 đá cấp trước ghép thành 1 đá cấp sau."
	var mana: Dictionary=economy.quote_upgrade(&"max_mana")
	if not ready and mana["can_buy"]:
		ready=true;station=NpcCatalog.HEALER
		requirements=[requirement(&"souls","Tàn Hồn",profile.souls,mana["cost"],ItemArtCatalog.icon(&"crystal"))]
		action="Thanh Vy → Mana tối đa → xem giá rồi xác nhận. Nâng dung lượng không tự hồi đầy mana."
		result="Mana tối đa vĩnh viễn +%.0f → +%.0f. Hồi mana là nâng cấp riêng."%[mana["value"],float(mana["value"])+WorldProgressionCatalog.VALUES[&"max_mana"]]
	return {"key":&"upgrade","title":"Nâng cấp","done":done,"station":station,"action":action,"requirements":requirements,"result":result,"ready":ready,"source":"Nâng cấp là một lựa chọn; không bắt buộc mua trước khi tu luyện. Giá được kiểm lại ở bảng dịch vụ. Kho chỉ cất/rút; dịch vụ lấy vật liệu đang mang."}

static func _cultivation(profile: SanctuaryProfile, inventory: GearInventory) -> Dictionary:
	var hint: Dictionary=Guide.cultivation_view(profile,inventory)
	var ready: bool=Cultivation.valid(profile.cultivation_progress,profile.material_stash)
	var requirements: Array[Dictionary]=[]
	var stage: int=0
	if ready:
		var actor: Dictionary=profile.cultivation_progress["actors"]["player"]
		var config: Dictionary=profile.cultivation_progress["config"]
		stage=int(actor["stage"])
		if stage<3:
			requirements.append(requirement(&"energy","Tu vi tích lũy",actor["energy"],config["energy_thresholds"][stage],ItemArtCatalog.icon(&"crystal")))
			requirements.append(requirement(&"mastery","Đòn cận chiến hợp lệ",actor["mastery"],config["mastery_thresholds"][stage],ItemArtCatalog.icon(&"broken_sword")))
			requirements.append(requirement(&"insight","Lĩnh ngộ riêng biệt",actor["insight_ids"].size(),config["insight_thresholds"][stage],ItemArtCatalog.icon(&"blueprint")))
			var scaled: int=maxi(0,(int(config["energy_thresholds"][stage])-int(actor["energy"]))*10000-int(actor["remainder"]))
			var per_session: int=int(config["training_gain"])*(10000+int(actor["aptitude"])*int(config["aptitude_rate_bps"]))
			var sessions: int=ceili(float(scaled)/float(per_session))
			if sessions>0:requirements.append(requirement(&"crystal","Tinh Thạch trong túi / %d phiên còn cần"%sessions,inventory.materials.get(&"crystal",0),sessions*int(config["training_cost"])))
			requirements.append(requirement(&"dust","Bột Phép trong túi",inventory.materials.get(&"dust",0),int(config["final_dust_cost"] if stage==2 else config["interim_dust_cost"])))
			if stage==2 and int(config["final_soul_cost"])>0:requirements.append(requirement(&"souls","Tàn Hồn",profile.souls,config["final_soul_cost"],ItemArtCatalog.icon(&"crystal")))
			if stage==2 and int(config["final_golem_proof"])>0:requirements.append(requirement(&"proof","Chứng tích Golem",profile.boss_proofs.get(&"golem",0),config["final_golem_proof"],ItemArtCatalog.icon(&"blueprint")))
	var sources: Array[String] = ["Đòn cận chiến trúng mộc nhân/quái tăng thông thạo. Đường Bộ, Thanh Vy và Golem cho lĩnh ngộ một lần. Điều tức: Sân Luyện → TU LUYỆN → Đóng bảng và bắt đầu điều tức; đứng tại sân, đóng các bảng để phiên luyện chạy."]
	for need: Dictionary in requirements:
		if need["missing"] > 0 and need["id"] in [&"crystal", &"dust"]:
			sources.append("%s: %s" % [MaterialCatalog.DISPLAY_NAMES[need["id"]], Guide._material_source(profile,need["id"],need["missing"])])
	return {"key":&"cultivation","title":"Tu luyện","done":stage==3,"stage":stage,"configuration_valid":ready,"station":Guide.cultivation_station(profile,inventory),"action":hint["action"],"requirements":requirements,"result":hint["reward"],"ready":hint["status"]=="requirements_ready","source":"\n".join(sources)}

static func resource_legend(profile: SanctuaryProfile, inventory: GearInventory) -> String:
	var energy: String = "chưa khả dụng"
	if Cultivation.valid(profile.cultivation_progress,profile.material_stash): energy = str(profile.cultivation_progress["actors"]["player"]["energy"])
	return "PHÂN BIỆT TÀI NGUYÊN\nLinh Thạch: %d đã giữ trong hồ sơ; tiền mua đồ/cường hóa theo báo giá.\nTàn Hồn: %d; học bùa/nâng vĩnh viễn theo giá của Thanh Vy.\nTinh Thạch: %d trong túi, %d trong kho; nguyên liệu điều tức/chế bùa, khác Linh Thạch. Dịch vụ dùng phần đang mang.\nTu vi tích lũy: %s; năng lượng tu luyện để xét tiến tầng/đột phá, khác mana dùng tung chiêu." % [profile.coins,profile.souls,inventory.materials.get(&"crystal",0),profile.material_stash.get(&"crystal",0),energy]

static func row(profile: SanctuaryProfile, inventory: GearInventory) -> Dictionary:
	var card: Dictionary={"title":"Bước tiếp theo để mạnh hơn","action":"Chưa đọc được dữ liệu; vào lại vùng chơi và mở bảng.","location":"Chưa xác minh","progress":"Chưa khả dụng","prerequisite":"Cần hồ sơ và túi hợp lệ.","reward":"Chưa xác minh","reward_mode":"Thực hiện tại bảng đang có; hướng dẫn không phát đồ hoặc ghi tiến độ.","reward_status":"Chưa khả dụng","complete":false,"optional":true,"active":false,"count":0,"command":&"","command_label":"","command_enabled":false}
	var result: Dictionary={"id":ID,"title":card["title"],"body":"","target":ExteriorRouteCatalog.HUB,"done":false,"next":false,"card":card,"power":{}}
	if profile==null or inventory==null or profile.read_only or profile.hub_inventory_quarantined or profile.opening_progress_quarantined:return result
	var weapon: GearItem=inventory.items.get(inventory.equipped_weapon_uid)
	var equipped: bool=weapon!=null and weapon.can_equip()
	var cultivation: Dictionary=_cultivation(profile,inventory)
	var foundation: bool=cultivation["done"]
	var spell: Dictionary=_spell(profile,inventory,foundation)
	var upgrade: Dictionary=_upgrade(profile,inventory)
	var next: Dictionary=cultivation if not cultivation["done"] else upgrade
	var bounty: Dictionary=Guide._quotes(profile,inventory).quote_bounty(WorldProgressionCatalog.BOUNTY_ID)
	var no_runes: bool=true
	for count: int in rune_counts(inventory).values():no_runes=no_runes and count==0
	if not equipped:next={"key":&"equipment","title":"Trang bị","done":false,"station":&"training","action":"Tab → Trang bị: so sánh và mặc vũ khí dùng được đang sở hữu. Nếu chưa có, xem hàng Kael; vũ khí hỏng cần sửa tại Thiết Lão.","requirements":[],"result":"Vũ khí đang mặc quyết định bộ đòn; không có class cố định.","source":"Bùa Catalyst là đòn tấn công chính; ô rune trên vũ khí là phần riêng."}
	elif not profile.bounty_accepted and not profile.bounty_claimed and profile.boss_proofs.get(&"golem",0)==0 and no_runes and not upgrade["done"] and cultivation["stage"]==0:
		next={"key":&"first_quest","station":NpcCatalog.WANDERER,"action":"Vô Danh → E → Nhận lời hạ Golem trước chuyến đầu. Sau đó đi cổng Hầm Ngục; kiếm và đòn thường đã dùng được, chưa cần ghép hai bùa.","requirements":[requirement(&"bounty","Lời hẹn Vô Danh",0,1)],"result":"Lời hẹn theo dõi Golem thật; phần thưởng nhận qua chủ nhiệm vụ khi đủ chứng tích.","source":"Lời hẹn không khóa cổng. Nhận trước giúp bạn không bỏ lỡ chứng tích; không cấp đồ hoặc sức mạnh miễn phí."}
	elif bounty.get("can_claim",false):
		next={"key":&"bounty","station":NpcCatalog.WANDERER,"action":"Đã đủ chứng tích. Trở lại Vô Danh → E → Nhận thưởng lời hẹn; rồi mở lại Mạnh hơn để xem bước dùng được với đồ/vật liệu vừa mang về.","requirements":[requirement(&"proof","Chứng tích lời hẹn",int(bounty["progress"]),1)],"result":"Nhận đúng phần thưởng nhiệm vụ đã hứa một lần; hướng dẫn không phát thêm.","source":"Chứng tích và receipt do nhiệm vụ hiện có giữ. Nhận lại hoặc tải lại không tạo thêm phần thưởng."}
	elif not upgrade["done"] and upgrade["ready"]:next=upgrade
	elif not spell["done"]:next=spell
	elif cultivation["done"] and upgrade["done"]:
		next={"key":&"journey","title":"Thử Liên Ấn","station":&"training","action":"Tab → Bùa: chọn đúng bộ từ 2 bùa. Ở Sân Luyện, hướng chuột và dùng I / chuột phải vào các mộc nhân gần nhau; sau đó chuẩn bị chuyến tiếp theo.","requirements":[],"result":FoundationResonance.description(),"source":"Cảnh giới sau Trúc Cơ chưa có trong vòng đầu. Nhánh G đã học không thay thế bộ bùa."}
	var counts: String="Trang bị %s · Bùa %s · Nâng cấp %s · Cảnh giới %d/3"%["✓" if equipped else "0/1","✓" if spell["done"] else "0/1","✓" if upgrade["done"] else "0/1",cultivation["stage"]]
	var lines: Array[String]=[]
	for need: Dictionary in next["requirements"]:lines.append("%s: %d/%d · thiếu %d"%[need["name"],need["have"],need["need"],need["missing"]])
	card.merge({"action":next["action"],"location":_location(next["station"]),"progress":counts,"prerequisite":"\n".join(lines) if not lines.is_empty() else "Dùng đồ đang sở hữu, ghép đúng công thức; giao dịch kiểm lại giá tại nơi thực hiện.","reward":next["result"],"reward_status":"Đã mở Liên Ấn" if foundation else "Trúc Cơ sẽ mở Liên Ấn"},true)
	var current: String="%s · %s"%[profile.cultivation_progress["config"]["stage_labels"][cultivation["stage"]] if cultivation["configuration_valid"] else "Tu luyện chưa sẵn sàng",ItemArtCatalog.gear_name(weapon) if equipped else "Chưa mặc vũ khí dùng được"]
	if cultivation["configuration_valid"] and cultivation["stage"] < 3:
		current = "%s → %s\n%s" % [profile.cultivation_progress["config"]["stage_labels"][cultivation["stage"]],profile.cultivation_progress["config"]["stage_labels"][cultivation["stage"]+1],ItemArtCatalog.gear_name(weapon) if equipped else "Chưa mặc vũ khí dùng được"]
	result["power"]={"station":next["station"],"key":next["key"],"requirements":next["requirements"],"current":current,"spell_ids":spell["recipe"]["recipe_rune_ids"],"foundation":foundation,"guidance":"NGUỒN / CÁCH THỰC HIỆN\n"+next["source"]+"\n\n"+resource_legend(profile,inventory)}
	result["body"]="HIỆN TẠI · "+current+"\n"+next["source"]+"\n\nTRÚC CƠ · "+FoundationResonance.description()+"\n"+FoundationLesson.example_text()+" Bùa đơn không có thêm liên kết. Tab → Bùa cho biết bộ hiện tại / lý do chưa dùng được. Hai bia Sân Luyện tự hồi, không đánh trả; đứng giữa, nhắm bia phải để thấy bia sau lưng nhận liên kết. Không cấp rune miễn phí.\n\nCÁC ĐƯỜNG SỨC MẠNH\nTrang bị: Tab để so sánh/mặc.\nGhép bùa: Tab → Bùa; học/chế ở Thanh Vy hoặc tìm rương.\nNâng cấp: Thiết Lão / Thanh Vy theo giá thực.\nTu luyện: Sân Luyện; theo từng điều kiện trên đây."
	return result

static func _location(station: StringName) -> String:
	return {&"training":"Căn Cứ · Sân Luyện / Tab",&"stash":"Căn Cứ · Kho Căn Cứ (rút về túi)",&"portal":"Cổng hầm ngục → quái / rương",NpcCatalog.SMITH:"Căn Cứ · Thiết Lão",NpcCatalog.HEALER:"Căn Cứ · Thanh Vy",NpcCatalog.WANDERER:"Căn Cứ · Vô Danh",&"exterior_road":"Căn Cứ · Đường Bộ"}.get(station,"Căn Cứ · đóng bảng và theo mũi tên")

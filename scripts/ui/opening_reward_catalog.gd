class_name OpeningRewardCatalog
extends RefCounted
## Read-only presentation of existing receipts and balances; never awards or saves.
const ID: StringName=&"opening_rewards"
const BOUNTY: EquipmentData=preload("res://data/equipment/ancient_sword_bounty.tres")
const LOOT: DropTableResource=preload("res://data/loot/world_drop_table.tres")

static func receipt_stamp(profile: SanctuaryProfile) -> String:
	if profile==null or profile.read_only or profile.hub_inventory_quarantined:return "unavailable"
	var actors: Variant=profile.cultivation_progress.get("actors",{})
	var actor: Variant=actors.get("player",{}) if actors is Dictionary else {}
	var insights: Variant=actor.get("insight_ids",[]) if actor is Dictionary else []
	return JSON.stringify([profile.bounty_claimed,insights,OpeningExplorationProgress.state_for(profile)["cache_claimed"]])

static func _entry(id: StringName,name: String,amount: int,icon: Texture2D,destination: String,use: String,balance: String,quest: StringName) -> Dictionary:
	return {"id":id,"name":name,"amount":amount,"icon":icon,"destination":destination,"use":use,"balance":balance,"quest":quest}

static func bounty(inventory: GearInventory,claimed: bool=true) -> Dictionary:
	var count: int=0;var equipped: bool=false
	if inventory!=null:
		for item: GearItem in inventory.items.values():
			if item.definition_id==BOUNTY.id:count+=1;equipped=equipped or item.uid==inventory.equipped_weapon_uid
	var balance: String="Chưa nhận · cần trống 1 ô túi" if not claimed else "Hiện mang %d · %s"%[count,"đang trang bị" if equipped else "chưa trang bị kiếm thưởng" if count>0 else "không còn trong túi; hỏi Vô Danh để luyện lại"]
	return _entry(&"bounty",BOUNTY.item_name,1,ItemArtCatalog.GEAR_ICON_OVERRIDES[BOUNTY.id],"Túi trang bị · không tự thay món đang mặc","Tab → Hành trang: so sánh rồi trang bị; nối đòn đâm sau 3 nhát chém.",balance,&"golem_defeated")

static func received(profile: SanctuaryProfile,inventory: GearInventory) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if profile==null or profile.read_only or profile.hub_inventory_quarantined:return result
	if profile.bounty_claimed:result.append(bounty(inventory))
	if not profile.opening_progress_quarantined and OpeningCultivationState.valid(profile.cultivation_progress,profile.material_stash):
		var actor: Dictionary=profile.cultivation_progress["actors"]["player"]
		for pair: Array in [["explored","Khám phá"],["thanh_vy_met","Cuộc gặp Thanh Vy"],["golem_defeated","Hạ Golem"]]:
			if actor["insight_ids"].has(pair[0]):result.append(_entry(StringName("insight_"+pair[0]),"Lĩnh ngộ · "+pair[1],1,ItemArtCatalog.icon(&"blueprint"),"Tu luyện · không phải vật phẩm trong túi","Đáp ứng điều kiện lĩnh ngộ tại Sân Luyện; mỗi mốc một lần.","Hiện có %d lĩnh ngộ riêng biệt"%actor["insight_ids"].size(),StringName(pair[0])))
	if profile.extension_transactions_available(OpeningExplorationProgress.SCOPE) and OpeningExplorationProgress.state_for(profile)["cache_claimed"]:
		var bag: int=int(inventory.materials.get(&"dust",0)) if inventory!=null else 0
		result.append(_entry(&"p03_cache",MaterialCatalog.DISPLAY_NAMES[&"dust"],OpeningExplorationProgress.REWARD,ItemArtCatalog.icon(&"dust"),"Kho Căn Cứ · rút về túi trước khi dùng","Thanh Vy: chế bùa đã học; Thiết Lão: sửa đồ. Không thay Đá Cường Hóa.","Hiện: túi %d · kho %d"%[bag,profile.material_stash.get(&"dust",0)],&"opening_exploration"))
	return result

static func journal_row(profile: SanctuaryProfile,inventory: GearInventory) -> Dictionary:
	var entries: Array[Dictionary]=received(profile,inventory)
	if entries.is_empty():return {}
	return {"id":ID,"title":"Thưởng đã nhận","body":"Chỉ đối chiếu receipt đã lưu; số đã nhận khác số còn giữ. Đồ đã dùng hoặc mất không được cấp lại ở nhật ký. Mạnh hơn giữ hướng dẫn bước tiếp theo.","target":&"","done":true,"next":false,"rewards":entries,"card":{"title":"Thưởng đã nhận","action":"Xem vật phẩm, nơi nhận và công dụng bên dưới. Mạnh hơn xem điều kiện của bước kế tiếp.","location":"Nhật ký · chỉ xem","progress":"%d phần thưởng đã ghi"%entries.size(),"prerequisite":"Túi và kho là hai số dư riêng. Dịch vụ dùng đồ đã nhặt/rút vào túi.","reward":"Số đã nhận và số đang giữ được tách riêng.","reward_mode":"Không có nút nhận lại ở nhật ký này.","reward_status":"Receipt hiện có · đã lưu","complete":true,"optional":true,"active":false,"count":entries.size(),"command":&"","command_label":"","command_enabled":false}}

static func source_hint(id: StringName) -> String:
	var sources: Array[String]=[]
	if id in MaterialCatalog.WORLD_CHEST_POOL:sources.append("rương hầm ngục (E mở, E nhặt)")
	if id in LOOT.material_pool(&"golem"):sources.append("phần rơi Golem")
	return "Nguồn: %s; ngẫu nhiên, không bảo đảm mỗi chuyến. Sau tầng đã dọn, E ở lối ra → Trở về sảnh để giữ đồ đã nhặt."%" / ".join(sources) if not sources.is_empty() else "Chưa có nguồn mở đầu trong catalog."

static func material_use(id: StringName,profile: SanctuaryProfile,inventory: GearInventory) -> String:
	if id==&"crystal" and profile!=null and OpeningCultivationState.valid(profile.cultivation_progress,profile.material_stash):
		return "Sân Luyện → Điều tức: %d Tinh Thạch trong túi / phiên."%int(profile.cultivation_progress["config"]["training_cost"])
	if id==&"dust":return "Chế bùa đã học ở Thanh Vy / sửa đồ ở Thiết Lão; dùng vật liệu trong túi."
	if String(id).begins_with("enhancement_stone_"):
		var economy:=EconomySession.new();economy.profile=profile;economy.inventory=inventory
		var quote: Dictionary=economy.quote_enhance(inventory.equipped_weapon_uid)
		return "Thiết Lão → Cường hóa: %d Linh Thạch + 1 đá trong túi."%int(quote["coin_cost"]) if quote["stone_id"]==id else "Thiết Lão → Cường hóa / ghép đá theo báo giá."
	return {&"metal":"Thiết Lão → Sửa / đúc theo nguyên liệu của món.",&"healing_herb":"Lửa trại / Thanh Vy → chế thuốc theo công thức.",&"linen_fiber":"Chế băng hoặc đúc trang bị theo công thức.",&"detox_root":"Chế thuốc giải theo công thức.",&"slime_essence":"Nguyên liệu / bán tại Kael theo giá đang có.",&"armor_scrap":"Thiết Lão → tra công thức đúc trang bị."}.get(id,"Xem công thức và báo giá tại căn cứ; không tự dùng từ kho.")

static func pickup(pickup: LootPickup,profile: SanctuaryProfile,inventory: GearInventory) -> Dictionary:
	var destination: String="Túi chuyến đi · về sảnh để giữ"
	var use: String="Tab → Hành trang: so sánh rồi trang bị."
	var balance: String=""
	if pickup.kind==&"material":
		use=material_use(pickup.item_id,profile,inventory);balance="Túi %d · kho %d"%[inventory.materials.get(pickup.item_id,0),profile.material_stash.get(pickup.item_id,0)]
	elif pickup.kind==&"soul":destination="Ví Tàn Hồn · đã lưu";use="Thanh Vy → học bùa / tịnh hóa theo báo giá.";balance="Đang có %d Tàn Hồn"%profile.souls
	elif pickup.kind==&"coins":destination="Linh Thạch đang mang · về sảnh cộng vào ví";use="Thiết Lão / Kael dùng ví tại căn cứ.";balance="Đang mang %d · ví %d"%[inventory.run_coins,profile.coins]
	elif pickup.kind==&"rune":destination="Túi bùa";use="Tab → Bùa: chọn ô Catalyst rồi lắp đúng bộ."
	elif pickup.kind==&"blueprint":destination="Bản chế tạo đã học";use="Thiết Lão → Đúc; vẫn cần nguyên liệu trong túi."
	elif pickup.kind==&"consumable":destination="Túi thuốc";use="Lửa trại → Sử dụng khi cần."
	elif pickup.kind==&"relic":destination="Cổ vật đang sở hữu";use="Lửa trại → Cổ vật: xem và trang bị."
	elif pickup.kind==&"potion":destination="Hồi phục tại chỗ";use="Hồi máu ngay; không vào túi thuốc."
	if pickup.runtime_item!=null and pickup.runtime_item.broken:
		var economy:=EconomySession.new();economy.profile=profile;economy.inventory=inventory
		var quote: Dictionary=economy.quote_repair(pickup.runtime_item.uid)
		destination="Túi trang bị · món hỏng"
		use="Thiết Lão → Đúc theo bản chế tạo; phôi này chưa thể sửa để dùng." if quote["requires_forging"] else "Thiết Lão → Sửa: %d kim loại + %d Bột Phép trong túi; chưa trang bị được."%[quote["metal"],quote["dust"]]
	return _entry(&"pickup",ItemArtCatalog.pickup_name(pickup),pickup.quantity,ItemArtCatalog.pickup_icon(pickup),destination,use,balance,&"")

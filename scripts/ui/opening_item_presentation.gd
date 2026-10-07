class_name OpeningItemPresentation
extends RefCounted
## Read-only names, art and camp action quotes. Never owns a UID or transaction.
const MISSING_ICON: Texture2D = preload("res://assets/ui/antique/campfire_missing.svg")

const KIND_NAMES: Dictionary = {&"weapon":"Vũ khí", &"armor":"Áo", &"pants":"Quần", &"boots":"Giày", &"gloves":"Găng", &"ring":"Nhẫn", &"amulet":"Dây chuyền", &"catalyst":"Pháp khí", &"rune":"Bùa", &"relic":"Cổ vật"}
const CONSUMABLE_NAMES: Dictionary = {&"potion":"Thuốc Hồi Máu", &"bandage":"Băng Gạc", &"antidote":"Thuốc Giải Độc", &"trap":"Bẫy Sàn"}
const CONSUMABLE_DETAILS: Dictionary = {&"potion":"Hồi tối đa 30 máu; không tiêu hao khi máu đầy.", &"bandage":"Cầm máu khi đang bị chảy máu.", &"antidote":"Xóa độc khi đang bị nhiễm độc.", &"trap":"Đặt trên mặt đất; tối đa 8 bẫy đang tồn tại."}

static func definition(item: GearItem) -> Resource:
	if item == null: return null
	if item.equipment_definition != null: return item.equipment_definition
	if item.kind == &"rune":
		for rune: RuneData in GearInventory.RUNES:
			if rune.id == item.definition_id: return rune
	if item.kind == &"relic":
		for relic: RelicData in RelicRuntime.CATALOG:
			if relic.id == item.definition_id: return relic
	var directory: String = "weapons" if item.kind == &"weapon" else "catalysts" if item.kind == &"catalyst" else "equipment"
	var path: String = "res://data/%s/%s.tres" % [directory,item.definition_id]
	return load(path) as Resource if ResourceLoader.exists(path) else null

static func _property(resource: Object, key: StringName) -> Variant:
	if resource != null:
		for entry: Dictionary in resource.get_property_list():
			if StringName(entry["name"]) == key: return resource.get(key)
	return null

static func item_name(item: GearItem) -> String:
	if item == null: return "Chưa chọn vật phẩm"
	if item.definition_id == &"starter_catalyst": return "Pháp Khí Khởi Đầu"
	var resource: Resource = definition(item)
	var title: Variant = _property(resource,&"item_name")
	if not title is String or title.is_empty(): title = _property(resource,&"display_name")
	if title is String and not title.is_empty(): return ("Bùa " if item.kind == &"rune" else "") + title
	return KIND_NAMES.get(item.kind,"Vật phẩm") + " chưa có tên riêng"

static func item_icon(item: GearItem) -> Texture2D:
	if item == null: return null
	if item.broken and item.kind in [&"weapon",&"armor",&"gloves"]: return ItemArtCatalog.gear_icon(item)
	var direct: Texture2D = ItemArtCatalog.icon(item.definition_id)
	if direct != null: return direct
	if item.kind == &"rune": return ItemArtCatalog.RUNE_ICONS.get(item.definition_id) as Texture2D
	if item.broken and item.kind not in [&"weapon",&"armor",&"gloves"]:
		return _property(definition(item),&"icon_texture") as Texture2D
	var mapped: Texture2D = ItemArtCatalog.gear_icon(item)
	if mapped != null and mapped != ItemArtCatalog.FALLBACK: return mapped
	return _property(definition(item),&"icon_texture") as Texture2D

static func description(item: GearItem) -> String:
	if item == null: return "Chọn một món trong danh sách để xem trạng thái và thao tác."
	var text: Variant = _property(definition(item),&"description")
	if text is String and not text.is_empty(): return text
	if item.kind == &"catalyst": return "Pháp khí dùng để lắp các bùa cộng hưởng. Số ô mở phụ thuộc phẩm cấp và tiến triển đã có."
	if item.kind == &"rune": return "Bùa cộng hưởng. Chọn ô trong hành trang để khảm vào pháp khí hoặc vũ khí."
	return "Vật phẩm đang thuộc hành trang của lữ khách."

static func state(item: GearItem, inventory: GearInventory) -> String:
	if item == null: return "Chưa chọn món"
	if item.broken: return "Hỏng · Cần sửa trước khi trang bị"
	if item.is_forging_blank(): return "Phôi · Cần thợ rèn chế tạo"
	if item.uid == inventory.equipped_weapon_uid or item.uid == inventory.catalyst_uid or inventory.equipment_uids.has(item.uid): return "Đang trang bị"
	if inventory.slot_uids.has(item.uid): return "Đang khảm"
	return "Trong túi"

static func craft_quote(inventory: GearInventory, id: StringName, uid: int = 0) -> Dictionary:
	var metal: int = 0
	var dust: int = 0
	var reason: String = ""
	match id:
		&"upgrade":
			var item: GearItem = inventory.items.get(uid)
			if item == null or item.kind != &"weapon": reason = "Chọn một vũ khí Thường để rèn lên Hiếm."
			elif item.quality >= GearItem.Quality.RARE: reason = "Vũ khí Hiếm trở lên cần thợ rèn."
			else:
				metal = 6 + item.quality * 3
				dust = 4 + item.quality * 2
		&"potion": dust = 4
		&"bandage": dust = 2
		&"trap": metal = 4
		_: reason = "Không có công thức này."
	if reason.is_empty() and (inventory.materials.get(&"metal",0) < metal or inventory.materials.get(&"dust",0) < dust): reason = "Thiếu nguyên liệu đang mang theo."
	return {"metal":metal,"dust":dust,"allowed":reason.is_empty(),"reason":reason}

static func cost_text(quote: Dictionary, inventory: GearInventory) -> String:
	var parts: Array[String] = []
	if quote["metal"] > 0: parts.append("%d Kim Loại (có %d)" % [quote["metal"],inventory.materials.get(&"metal",0)])
	if quote["dust"] > 0: parts.append("%d Bột Phép (có %d)" % [quote["dust"],inventory.materials.get(&"dust",0)])
	return " · ".join(parts)

static func dismantle_allowed(item: GearItem, inventory: GearInventory) -> bool:
	if item == null or item.kind == &"relic" or item.uid == inventory.catalyst_uid or item.uid == inventory.equipped_weapon_uid or inventory.equipment_uids.has(item.uid) or inventory.slot_uids.has(item.uid): return false
	if item.quality < 0 or item.quality > 5: return false
	var metal: int = 0 if item.kind == &"rune" else 3 + item.quality * 2
	var dust: int = 2 + item.quality if item.kind == &"rune" else 1 + item.quality
	return MaterialCatalog.valid_count(inventory.materials[&"metal"]) and MaterialCatalog.valid_count(inventory.materials[&"dust"]) and inventory.materials[&"metal"] <= MaterialCatalog.MAX_COUNT - metal and inventory.materials[&"dust"] <= MaterialCatalog.MAX_COUNT - dust and (item.kind != &"rune" or inventory.bag.get(item.definition_id,0) > 0)

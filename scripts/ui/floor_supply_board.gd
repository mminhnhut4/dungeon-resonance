extends VBoxContainer
## Read-only modal page. Existing inventory/DepthProgress remain authoritative.
const Catalog=preload("res://data/floor_supply_catalog.gd")
var cells: Array[Dictionary]=[]
var overview: Label
var scroll: ScrollContainer
var service_hint: Label
var preparation_panel: VBoxContainer
var intro: Label
var repeat_hint: Label
func _ready() -> void:
	add_theme_constant_override("separation",8)
	overview=label(self,"TẦNG & VẬT LIỆU · Một vòng chế thêm bùa",18)
	intro=label(self,"Biết cần gì → Lạc Ấn chọn tầng đã hoàn tất → dọn và nhặt → về %s chế bùa đã học."%NpcCatalog.NAMES[NpcCatalog.HEALER],14)
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",12);scroll.add_child(list)
	preparation_panel=preload("res://scripts/ui/rune_preparation_panel.gd").new();preparation_panel.name="RunePreparationPanel";list.add_child(preparation_panel);list.add_child(AntiqueSkin.divider())
	for source: Dictionary in Catalog.SOURCES:
		var card:=VBoxContainer.new();card.add_theme_constant_override("separation",4);list.add_child(card)
		var row: Dictionary={"record":source}
		for field: String in ["title","objective","source","unlock","progress"]:
			row[field]=label(card,"",16 if field=="title" else 14)
		cells.append(row);list.add_child(AntiqueSkin.divider())
	service_hint=label(list,"DÙNG TẠI CĂN CỨ · %s → Học & chế bùa → Chế thêm bùa đã học. Giữ trang bị quyết định bộ đòn; bùa dùng để ghép cộng hưởng."%NpcCatalog.NAMES[NpcCatalog.HEALER],14)
	label(list,"Đây là nguồn bảo đảm bổ sung; vật liệu vẫn có thể rơi ở nguồn cũ. Đồ trên đất không tự mang về. Tiến độ trên bảng là số đang mang, không phải biên nhận đã nhặt của nguồn này.",13)
	repeat_hint=label(list,"Mỗi chuyến mới có thể thu lại sau khi dọn tầng; cùng chuyến không cấp lại do callback hay dựng lại phòng. Tầng chưa hoàn tất vẫn phải mở theo hành trình cũ.",13)
func label(parent: Node,text: String,size: int) -> Label:
	var out:=Label.new();out.text=text;out.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;out.size_flags_horizontal=Control.SIZE_EXPAND_FILL;out.mouse_filter=Control.MOUSE_FILTER_IGNORE;out.set_meta(&"debug_keep",true);out.add_theme_font_size_override("font_size",size);parent.add_child(out);return out
func present(profile: SanctuaryProfile,inventory: GearInventory,service: RuneLearningService=null) -> void:
	if not is_instance_valid(overview):return
	preparation_panel.call("present",profile,inventory,service)
	var mine: bool=profile!=null and bool(profile.get_meta(&"rune_preparation_mine",false))
	intro.text="Bản thử mỏ: xem phần còn thiếu → rút kho hoặc tự chọn đi mỏ → nhặt → về Thanh Vy chế. Bùa đang có dùng được ngay." if mine else "Biết cần gì → Lạc Ấn chọn tầng đã hoàn tất → dọn và nhặt → về %s chế bùa đã học."%NpcCatalog.NAMES[NpcCatalog.HEALER]
	repeat_hint.visible=not mine
	var needs: Array[String]=[]
	for id: StringName in RuneLearningService.CRAFT_COST:needs.append("%d %s"%[RuneLearningService.CRAFT_COST[id],MaterialCatalog.DISPLAY_NAMES[id]])
	overview.text="TẦNG & VẬT LIỆU · Một lần chế cần "+" + ".join(needs)
	for row: Dictionary in cells:
		(row["title"] as Label).get_parent().visible=not mine
		var view: Dictionary=Catalog.view(row["record"],profile,inventory)
		for field: String in ["title","objective","source","unlock","progress"]:(row[field] as Label).text=view[field]
		(row["progress"] as Label).add_theme_color_override("font_color",AntiqueSkin.JADE if view["have"]>=view["required"] else AntiqueSkin.WARM)

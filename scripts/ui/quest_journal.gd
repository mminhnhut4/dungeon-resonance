class_name QuestJournal
extends VBoxContainer
## Unified map/mission page. Read-only canonical state, no HUD tracker or save owner.
var profile: SanctuaryProfile
var inventory: GearInventory
var context_provider: Callable
var extension_rows_provider: Callable
var quest_action_provider: Callable
var navigation_provider: Callable
var navigation_label: Label
var cancel_navigation: Button
var action_button: Button
var action_notice: Label
var state_label: Label
var map_info: Label
var legend: Label
var objective_label: Label
var detail_sections: VBoxContainer
var detail_fields: Dictionary = {}
var detail_headers: Dictionary = {}
var detail_icons: Dictionary = {}
var reward_ready_label: Label
var reward_list: VBoxContainer
var guide_label: Label
var detail_title: Label
var graph: MapRouteGraph
var quest_scroll: ScrollContainer
var detail_scroll: ScrollContainer
var quest_list: VBoxContainer
var quest_buttons: Dictionary = {}
var rows: Array[Dictionary] = []
var selected_id: StringName = &""
var columns: HBoxContainer
var map_column: VBoxContainer
var quest_column: VBoxContainer
var legend_scroll: ScrollContainer
var map_title: Label
var quest_title: Label
var _projection_dirty: bool = false
var _rows_dirty: bool = true
var power_button: Button
var relations_button: Button
var requirement_list: VBoxContainer
var power_preview: HBoxContainer
var power_overview: VBoxContainer
var power_scroll: ScrollContainer
var power_current: Label
var power_steps: Label
var _compact_layout: bool = false

func _enter_tree() -> void:
	if profile != null and not profile.changed.is_connected(_request_refresh): profile.changed.connect(_request_refresh)
	if inventory != null and not inventory.changed.is_connected(_request_refresh): inventory.changed.connect(_request_refresh)

func _exit_tree() -> void:
	if profile != null and profile.changed.is_connected(_request_refresh): profile.changed.disconnect(_request_refresh)
	if inventory != null and inventory.changed.is_connected(_request_refresh): inventory.changed.disconnect(_request_refresh)

func _ready() -> void:
	visibility_changed.connect(_flush_projection)
	add_theme_constant_override("separation",6)
	# Keep untrack beside the title, above the two-column scroll content.
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation",8)
	add_child(heading)
	heading.add_child(_label("BẢN ĐỒ & NHIỆM VỤ",20))
	power_button = Button.new()
	power_button.text = "Mạnh hơn"
	power_button.icon = ItemArtCatalog.icon(&"crystal")
	power_button.expand_icon = true
	power_button.add_theme_constant_override("icon_max_width",20)
	power_button.tooltip_text = "Bước tiếp theo để mạnh hơn · đồ đang mang, số thiếu, nơi đến và lợi ích"
	power_button.pressed.connect(_toggle_power)
	heading.add_child(power_button)
	relations_button=Button.new()
	relations_button.text="Quan hệ"
	relations_button.tooltip_text="Nhật ký quan hệ Tàn Đăng · ai biết việc gì và bước tiếp theo"
	relations_button.icon=ItemArtCatalog.icon(&"blueprint");relations_button.expand_icon=true
	relations_button.add_theme_constant_override("icon_max_width",20)
	relations_button.pressed.connect(func() -> void:_choose_quest(&"tan_dang_relations"))
	heading.add_child(relations_button)
	relations_button.hide()
	cancel_navigation = Button.new()
	cancel_navigation.text = "Bỏ theo dõi nhiệm vụ"
	cancel_navigation.custom_minimum_size.y = 30
	cancel_navigation.disabled = true
	cancel_navigation.pressed.connect(func() -> void: if navigation_provider.is_valid(): navigation_provider.call(&""))
	heading.add_child(cancel_navigation)
	state_label = _label("",13)
	add_child(state_label)
	columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation",14)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(columns)
	map_column = VBoxContainer.new()
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_column.size_flags_stretch_ratio = 1.0
	map_column.add_theme_constant_override("separation",5)
	columns.add_child(map_column)
	map_title = _label("ĐƯỜNG BỘ · Sơ đồ tuyến",15)
	map_column.add_child(map_title)
	power_scroll=ScrollContainer.new()
	power_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	power_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	power_scroll.custom_minimum_size.y=120
	map_column.add_child(power_scroll)
	power_overview = VBoxContainer.new()
	power_overview.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	power_overview.add_theme_constant_override("separation",9)
	power_scroll.add_child(power_overview)
	var power_title: Label=_label("LỘ TRÌNH SỨC MẠNH",17)
	power_title.add_theme_color_override("font_color",AntiqueSkin.WARM)
	power_overview.add_child(power_title)
	power_current=_label("",15);power_overview.add_child(power_current)
	power_overview.add_child(AntiqueSkin.divider())
	power_steps=_label("",14);power_steps.add_theme_color_override("font_color",AntiqueSkin.JADE);power_overview.add_child(power_steps)
	power_overview.add_child(AntiqueSkin.divider())
	var unlock_title: Label=_label("TRÚC CƠ · LIÊN ẤN",15);unlock_title.add_theme_color_override("font_color",AntiqueSkin.WARM);power_overview.add_child(unlock_title)
	power_overview.add_child(_label(FoundationResonance.description(),14))
	power_preview=HBoxContainer.new();power_preview.add_theme_constant_override("separation",6);power_overview.add_child(power_preview)
	power_overview.add_child(_label("Trang bị quyết định bộ đòn; bùa là đòn tấn công chính. Kho chỉ cất/rút, dịch vụ dùng nguyên liệu đang mang.",13))
	power_scroll.hide()
	graph = MapRouteGraph.new()
	map_column.add_child(graph)
	graph.room_selected.connect(_room_selected)
	legend = _label("Bạn · Đã tới · ? Chưa khảo sát\n─ Lối đã biết · Sơ đồ không theo tỷ lệ",12)
	legend_scroll = ScrollContainer.new()
	legend_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	legend_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_column.add_child(legend_scroll)
	legend_scroll.add_child(legend)
	map_info = _label("",13)
	map_column.add_child(map_info)
	navigation_label = _label("Chọn một nhiệm vụ để theo dõi đường đi.",13)
	map_column.add_child(navigation_label)
	quest_column = VBoxContainer.new()
	quest_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_column.size_flags_stretch_ratio = 1.1
	quest_column.custom_minimum_size.x = 290
	quest_column.add_theme_constant_override("separation",6)
	columns.add_child(quest_column)
	quest_title = _label("DẤU MỐC MỞ ĐẦU",15)
	quest_column.add_child(quest_title)
	quest_scroll = ScrollContainer.new()
	quest_scroll.custom_minimum_size.y = 130
	quest_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	quest_scroll.follow_focus = true
	quest_column.add_child(quest_scroll)
	quest_list = VBoxContainer.new()
	quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_scroll.add_child(quest_list)
	detail_title = _label("",17)
	quest_column.add_child(detail_title)
	quest_column.add_child(_label("PgUp/PgDn · Cần phải: cuộn chi tiết",12))
	detail_scroll = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.custom_minimum_size.y = 120
	detail_scroll.follow_focus = true
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quest_column.add_child(detail_scroll)
	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_box)
	action_notice = _label("",13)
	action_notice.hide()
	detail_box.add_child(action_notice)
	detail_sections = VBoxContainer.new()
	detail_sections.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_sections.add_theme_constant_override("separation",8)
	detail_box.add_child(detail_sections)
	_build_detail_sections()
	objective_label = _label("",14)
	objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_child(objective_label)
	action_button = Button.new()
	action_button.custom_minimum_size.y = 40
	action_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	action_button.pressed.connect(_request_action)
	quest_column.add_child(action_button)
	refresh()

func _build_detail_sections() -> void:
	for spec: Array in [[&"objective","MỤC TIÊU",&"blueprint"],[&"progress","TIẾN ĐỘ",&"crystal"],[&"requirements","ĐIỀU KIỆN",&"enhancement_stone_1"],[&"reward","PHẦN THƯỞNG",&"coins"]]:
		if not detail_fields.is_empty(): detail_sections.add_child(AntiqueSkin.divider())
		var group := VBoxContainer.new()
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_theme_constant_override("separation",5)
		detail_sections.add_child(group)
		var heading := HBoxContainer.new()
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.add_theme_constant_override("separation",8)
		group.add_child(heading)
		var icon := TextureRect.new()
		icon.texture = ItemArtCatalog.icon(spec[2])
		icon.custom_minimum_size = Vector2(22,22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.add_child(icon)
		detail_icons[spec[0]] = icon
		var title: Label = _label(spec[1],15)
		title.add_theme_color_override("font_color",AntiqueSkin.WARM)
		heading.add_child(title)
		detail_headers[spec[0]] = title
		if spec[0] == &"reward":
			reward_ready_label = _label("✓ SẴN SÀNG NHẬN THƯỞNG",14)
			reward_ready_label.add_theme_color_override("font_color",AntiqueSkin.JADE)
			group.add_child(reward_ready_label)
			reward_list=VBoxContainer.new();reward_list.add_theme_constant_override("separation",9);group.add_child(reward_list)
		var body: Label = _label("",16 if spec[0] == &"progress" else 14)
		body.add_theme_color_override("font_color",AntiqueSkin.JADE if spec[0] == &"progress" else AntiqueSkin.TEXT)
		group.add_child(body)
		detail_fields[spec[0]] = body
		if spec[0] == &"requirements":
			requirement_list = VBoxContainer.new()
			requirement_list.add_theme_constant_override("separation",5)
			group.add_child(requirement_list)
	detail_sections.add_child(AntiqueSkin.divider())
	guide_label = _label("",14)
	guide_label.add_theme_color_override("font_color",AntiqueSkin.TEXT)
	detail_sections.add_child(guide_label)

func _present_detail(card: Dictionary,guide: String) -> void:
	# Keep the established flat text API for read-only readers and extension rows.
	# Visible card sections reuse its exact fields; they are not another quest owner.
	objective_label.hide()
	detail_sections.show()
	detail_fields[&"objective"].text = "HÀNH ĐỘNG: %s\nĐỊA ĐIỂM: %s" % [card["action"],card["location"]]
	detail_fields[&"progress"].text = card["progress"]
	detail_fields[&"requirements"].text = card["prerequisite"]
	for child: Node in requirement_list.get_children():requirement_list.remove_child(child);child.queue_free()
	for child: Node in power_preview.get_children():power_preview.remove_child(child);child.queue_free()
	var power: Dictionary = {}
	var rewards: Array[Dictionary]=[]
	for row: Dictionary in rows:
		if row["id"] == selected_id:power=row.get("power",{});rewards.assign(row.get("rewards",[]));break
	if selected_id==&"golem_defeated":rewards=[OpeningRewardCatalog.bounty(inventory,profile!=null and profile.bounty_claimed)]
	for child: Node in reward_list.get_children():reward_list.remove_child(child);child.queue_free()
	for entry: Dictionary in rewards:
		var line:=HBoxContainer.new();line.add_theme_constant_override("separation",8);reward_list.add_child(line)
		var image:=TextureRect.new();image.texture=entry["icon"];image.custom_minimum_size=Vector2(32,32);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(image)
		var wording: String="%s ×%d\n%s\n%s\n%s"%[entry["name"],entry["amount"],entry["destination"],entry["balance"],entry["use"]]
		line.add_child(_label(wording,14))
	_power_layout(not power.is_empty())
	if not power.is_empty():
		power_current.text=power["current"]
		power_steps.text=card["progress"].replace(" · ","\n")
		detail_fields[&"objective"].text="%s\nĐẾN: %s"%[card["action"],card["location"]]
	(detail_fields[&"progress"] as Label).get_parent().visible=power.is_empty()
	(detail_fields[&"requirements"] as Label).visible = power.is_empty() or power["requirements"].is_empty()
	for need: Dictionary in power.get("requirements",[]):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation",8)
		requirement_list.add_child(line)
		var icon := TextureRect.new()
		icon.texture=need["icon"];icon.custom_minimum_size=Vector2(24,24)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.add_child(icon)
		var text: Label=_label("%s · %d/%d · %s"%[need["name"],need["have"],need["need"],"Đủ" if need["missing"]==0 else "thiếu %d"%need["missing"]],14)
		text.add_theme_color_override("font_color",AntiqueSkin.JADE if need["missing"]==0 else AntiqueSkin.WARM)
		line.add_child(text)
	if not power.is_empty():
		for id: StringName in [&"fire",&"wind"]:
			var icon := TextureRect.new();icon.texture=ItemArtCatalog.RUNE_ICONS[id]
			icon.custom_minimum_size=Vector2(26,26);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.tooltip_text=RuneLearningService.NAMES[id];power_preview.add_child(icon)
		power_preview.add_child(_label("Ví dụ Hỏa + Phong\nTrước 0 → Trúc Cơ 1 liên kết",13))
	detail_fields[&"reward"].text = "PHẦN THƯỞNG: %s\nNHẬN THƯỞNG: %s\nTRẠNG THÁI: %s" % [card["reward"],card["reward_mode"],card["reward_status"]]
	guide_label.text = guide
	guide_label.visible=power.is_empty()
	var history: bool=selected_id==OpeningRewardCatalog.ID
	for section: StringName in [&"objective",&"requirements"]:(detail_fields[section] as Label).get_parent().visible=not history
	(detail_fields[&"progress"] as Label).get_parent().visible=not history and power.is_empty()
	detail_headers[&"reward"].text="THƯỞNG ĐÃ NHẬN" if history else "PHẦN THƯỞNG"
	detail_fields[&"reward"].visible=not history
	if history:guide_label.hide()
	elif not rewards.is_empty():detail_fields[&"reward"].text="NHẬN THƯỞNG: %s\nTRẠNG THÁI: %s"%[card["reward_mode"],card["reward_status"]]
	var reward_icon: Texture2D = ItemArtCatalog.GEAR_ICON_OVERRIDES[&"ancient_sword_bounty"] if selected_id == &"golem_defeated" else ItemArtCatalog.icon(&"coins")
	if selected_id in [PowerProgressionGuide.ID,&"cultivation_breakthrough"]:reward_icon=ItemArtCatalog.icon(&"crystal")
	(detail_icons[&"reward"] as TextureRect).texture = reward_icon
	if not rewards.is_empty():(detail_icons[&"reward"] as TextureRect).texture=rewards[0]["icon"]
	var ready: bool = card.get("command",&"") == &"bounty_claim" and not action_button.disabled
	reward_ready_label.visible = ready
	if ready:
		action_button.icon = reward_icon
		action_button.expand_icon = true
		action_button.add_theme_constant_override("icon_max_width",20)
		action_button.add_theme_color_override("font_color",AntiqueSkin.JADE)

func _label(text: String, font_size: int) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size",font_size)
	return result

func apply_visual_theme(shared_theme: Theme) -> void:
	# Shared antique-theme worker owns decoration/tokens; this page inherits them.
	theme = shared_theme
	if is_instance_valid(graph): graph.queue_redraw()

func set_compact_layout(compact: bool) -> void:
	_compact_layout=compact
	# Keep the target, navigation and action outside the scroll regions at 800x600.
	# The complete legend remains readable in its own compact scroll; desktop
	# retains its natural height. Both graph sizes reserve room for a wrapped
	# navigation hint; the 60px route pins still fit at the compact 188px.
	map_title.visible = not compact and selected_id != PowerProgressionGuide.ID
	quest_title.visible = not compact
	add_theme_constant_override("separation",4 if compact else 6)
	map_column.add_theme_constant_override("separation",3 if compact else 5)
	quest_column.add_theme_constant_override("separation",4 if compact else 6)
	graph.custom_minimum_size.y = 188 if compact else 200
	legend_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if compact else ScrollContainer.SCROLL_MODE_DISABLED
	legend_scroll.custom_minimum_size.y = 44 if compact else 0
	quest_scroll.custom_minimum_size.y = 90 if compact else 130
	detail_scroll.custom_minimum_size.y = 96 if compact else 120

func bind_progress(source: SanctuaryProfile, carried: GearInventory) -> void:
	if profile != null and profile.changed.is_connected(_request_refresh): profile.changed.disconnect(_request_refresh)
	if inventory != null and inventory.changed.is_connected(_request_refresh): inventory.changed.disconnect(_request_refresh)
	profile = source
	inventory = carried
	if is_inside_tree():
		if profile != null: profile.changed.connect(_request_refresh)
		if inventory != null: inventory.changed.connect(_request_refresh)
	refresh()

func projection_rows() -> Array[Dictionary]:
	# Navigation needs current data even while hidden UI rebuilds are deferred.
	if not _rows_dirty: return rows
	_rows_dirty = false
	var canonical: Array[Dictionary] = MapQuestProjection.rows(profile, inventory)
	if profile != null and not profile.opening_progress_quarantined and not profile.exterior_progress_quarantined:
		canonical.append_array(TanDangProgress.rows(profile))
	rows = OpeningQuestCards.decorate(canonical,profile,inventory)
	if profile != null and inventory != null and not profile.read_only and not profile.hub_inventory_quarantined and not profile.opening_progress_quarantined and not profile.exterior_progress_quarantined:rows.push_front(PowerProgressionGuide.row(profile,inventory))
	# Future rows read their existing canonical owner. No state/save is created.
	if extension_rows_provider.is_valid():
		var extras: Variant = extension_rows_provider.call()
		if extras is Array:
			for raw: Variant in extras.slice(0,16):
				if raw is Dictionary and (raw.get("id") is StringName or raw.get("id") is String) and raw.get("title") is String and raw.get("body") is String:
					var id := StringName(raw["id"])
					var duplicate_id: bool = id == &""
					for existing: Dictionary in rows:
						if existing["id"] == id: duplicate_id = true
					if duplicate_id: continue
					var target: Variant = raw.get("target","")
					rows.append({"id":id,"title":String(raw["title"]).left(256),"body":String(raw["body"]).left(4096),"target":StringName(target) if target is String or target is StringName else &"","done":bool(raw.get("done",false)),"next":false})
	var history: Dictionary=OpeningRewardCatalog.journal_row(profile,inventory)
	if not history.is_empty():rows.insert(1 if not rows.is_empty() and rows[0]["id"]==PowerProgressionGuide.ID else 0,history)
	return rows

func refresh() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or state_label == null: return
	_projection_dirty=false
	var focused: Control = get_viewport().gui_get_focus_owner()
	var keep_focus: bool = focused != null and quest_list.is_ancestor_of(focused)
	_rows_dirty = true
	projection_rows()
	relations_button.visible=rows.any(func(row: Dictionary) -> bool:return row["id"]==&"tan_dang_relations")
	for child: Node in quest_list.get_children():
		quest_list.remove_child(child)
		child.queue_free()
	quest_buttons.clear()
	var completed: int = 0
	var canonical_total: int = 0
	for row: Dictionary in rows:
		if row["id"] in OpeningProgress.IDS:
			canonical_total += 1
			if row["done"]: completed += 1
		var button := Button.new()
		var card: Dictionary = row.get("card",{})
		button.text = ("[Đã xong] " if row["done"] else "[Tiếp theo] " if row["next"] else "[Chưa xong] ")+row["title"]
		if not card.is_empty():
			button.text = ("CẦN LÀM TIẾP · " if card["active"] else "✓ ĐÃ HOÀN THÀNH · " if card["complete"] else "TÙY CHỌN · " if card.get("optional",false) else "CHƯA XONG · ")+card["title"]+"\n"+card["progress"]+" · "+card["location"]
			button.custom_minimum_size.y = 64
			if card["active"]:
				for state: StringName in [&"normal",&"hover",&"pressed",&"focus"]:
					button.add_theme_stylebox_override(state,AntiqueSkin.texture_style(AntiqueSkin.BUTTONS[&"focus"],18,10))
				button.add_theme_color_override("font_color",AntiqueSkin.WARM)
			elif card["complete"]: button.add_theme_color_override("font_color",AntiqueSkin.MUTED)
		if row["id"]==OpeningRewardCatalog.ID:button.text="THƯỞNG ĐÃ NHẬN · %d mục"%row["rewards"].size()
		if row["id"] == PowerProgressionGuide.ID:
			button.text = "BƯỚC TIẾP THEO ĐỂ MẠNH HƠN\n"+card["progress"]
			button.add_theme_color_override("font_color",AntiqueSkin.WARM)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = OpeningQuestCards.detail(card) if not card.is_empty() else row["title"]
		button.add_theme_font_size_override("font_size",14)
		if card.is_empty(): button.custom_minimum_size.y = 36
		button.pressed.connect(_choose_quest.bind(row["id"]))
		button.focus_entered.connect(select_quest.bind(row["id"]))
		quest_list.add_child(button)
		quest_buttons[row["id"]] = button
	if not quest_buttons.has(selected_id): selected_id = recommended_id()
	var context: Dictionary = _context()
	state_label.text = "Hiện tại: %s\nDấu mốc đã ghi: %d / %d%s" % [context["label"],completed,canonical_total," · Đã hoàn tất" if canonical_total > 0 and completed == canonical_total else ""]
	legend.text = "Bạn · Đích · Đã tới · ? Chưa khảo sát\n─ Lối đã biết · Đích: mục tiêu" + (" · ┄ Lối tắt" if MapQuestProjection.shortcut_known(profile,MapQuestProjection.known_rooms(profile)) else "") + "\nSơ đồ không theo tỷ lệ · Không chuyển vùng\nM / View: bản đồ · Esc / B: tiếp tục"
	select_quest(selected_id)
	if keep_focus: focus_first.call_deferred()

func _request_refresh() -> void:
	_rows_dirty = true
	# Mastery publishes immediately, but a hidden map must not rebuild dozens
	# of buttons on the hit's physics tick. Explicit refresh stays synchronous.
	if is_visible_in_tree(): refresh()
	else: _projection_dirty=true

func _flush_projection() -> void:
	if _projection_dirty and is_visible_in_tree(): refresh()

func _context() -> Dictionary:
	if context_provider.is_valid(): return context_provider.call()
	if profile == null or profile.exterior_progress_quarantined or not ExteriorProgress.valid(profile.exterior_progress): return {"room":&"","label":"Vị trí chưa khả dụng"}
	var room: StringName = StringName(profile.exterior_progress["room_id"])
	return {"room":room,"label":MapQuestProjection.room_name(room)}

func select_quest(id: StringName) -> void:
	if selected_id!=id:detail_scroll.scroll_vertical=0
	selected_id = id
	_power_layout(false)
	var known: Dictionary = MapQuestProjection.known_rooms(profile)
	var context: Dictionary = _context()
	var target: StringName = &""
	var finished: bool = false
	detail_title.text = "Chưa có nhiệm vụ khả dụng"
	detail_sections.hide()
	objective_label.show()
	action_button.icon = null
	action_button.remove_theme_color_override("font_color")
	objective_label.text = "Tiến triển chưa khả dụng trong phiên này. Không có vị trí nhiệm vụ để đánh dấu."
	action_button.hide()
	for row: Dictionary in rows:
		if row["id"] != id: continue
		detail_title.text = row["title"]
		objective_label.text = ("Đã ghi hoàn tất.\n\n" if row["done"] else "Chưa ghi hoàn tất.\n\n")+row["body"]
		finished = row["done"]
		var card: Dictionary = row.get("card",{})
		if not card.is_empty():
			detail_title.text = ("CẦN LÀM TIẾP · " if card["active"] else "✓ " if card["complete"] else "")+card["title"]
			objective_label.text = OpeningQuestCards.detail(card)+"\n\n"+row["body"]
			finished = card["complete"]
			if card.get("command",&"") != &"":
				action_button.show()
				action_button.text = card["command_label"]
				action_button.tooltip_text = "Chỉ thực hiện tại căn cứ; owner kiểm tra lại điều kiện và lưu phần thưởng." if context["room"] != ExteriorRouteCatalog.HUB else card["prerequisite"]
				action_button.disabled = not card.get("command_enabled",false) or context["room"] != ExteriorRouteCatalog.HUB or not quest_action_provider.is_valid()
			_present_detail(card,row["body"])
		if not finished and known.has(row["target"]): target = row["target"]
		break
	graph.set_state(known,context["room"],target,MapQuestProjection.shortcut_known(profile,known))
	map_info.text = "Mục tiêu đã biết: "+MapQuestProjection.room_name(target) if target != &"" else "Chưa có vị trí mục tiêu đã biết\ntrên sơ đồ đường bộ này."
	if finished: map_info.text = "Dấu mốc đã hoàn tất.\nKhông còn mục tiêu đang chờ."
	if id==OpeningRewardCatalog.ID:map_info.text="Thưởng đã nhận · không cấp lại\nSố đang giữ theo túi/kho hiện tại."

func _choose_quest(id: StringName) -> void:
	select_quest(id)
	if id!=OpeningRewardCatalog.ID and navigation_provider.is_valid(): navigation_provider.call(id)

func _toggle_power() -> void:
	if selected_id==PowerProgressionGuide.ID:select_quest(recommended_id())
	else:_choose_quest(PowerProgressionGuide.ID)

func _power_layout(enabled: bool) -> void:
	if not is_instance_valid(power_overview):return
	power_overview.visible=enabled;power_scroll.visible=enabled
	graph.visible=not enabled;legend_scroll.visible=not enabled;map_info.visible=not enabled
	map_title.visible=not enabled and not _compact_layout
	quest_scroll.visible=not enabled
	quest_title.text="LÀM MỘT VIỆC TIẾP THEO" if enabled else "DẤU MỐC MỞ ĐẦU"
	power_button.text="Nhiệm vụ" if enabled else "Mạnh hơn"
	power_button.tooltip_text="Xem bản đồ và danh sách nhiệm vụ" if enabled else "Bước tiếp theo để mạnh hơn · số đang mang, còn thiếu, nơi đến và lợi ích"

func present_navigation(id: StringName,hint: String) -> void:
	if not is_instance_valid(navigation_label): return
	var title: String = ""
	for row: Dictionary in rows:
		if row["id"] == id: title = row.get("card",{}).get("title",row["title"]); break
	navigation_label.text = ("➜ %s\n" % title if id != &"" else "")+hint
	cancel_navigation.disabled = id == &""

func _room_selected(room: StringName) -> void:
	if not MapQuestProjection.known_rooms(profile).has(room): return
	map_info.text = "Khu đã đến: "+MapQuestProjection.room_name(room)+"\nChọn khu để đọc sơ đồ, không chuyển vùng."

func focus_first() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	if selected_id==PowerProgressionGuide.ID and power_overview.visible:power_button.grab_focus();return
	if quest_buttons.has(selected_id): (quest_buttons[selected_id] as Button).grab_focus()
	elif not quest_buttons.is_empty(): (quest_buttons.values()[0] as Button).grab_focus()
	else: (graph.buttons[ExteriorRouteCatalog.HUB] as Button).grab_focus()

func recommended_id() -> StringName:
	for row: Dictionary in rows:
		if row.get("card",{}).get("active",false): return row["id"]
	return rows[0]["id"] if not rows.is_empty() else &""

func focus_recommended() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	select_quest(selected_id if selected_id in [PowerProgressionGuide.ID,&"tan_dang_relations",OpeningRewardCatalog.ID] and quest_buttons.has(selected_id) else recommended_id())
	focus_first()

func _request_action() -> void:
	if action_button.disabled or not quest_action_provider.is_valid(): return
	var command: StringName = &""
	for row: Dictionary in rows:
		if row["id"] == selected_id: command = row.get("card",{}).get("command",&""); break
	if command == &"": return
	action_button.disabled = true
	var response: Variant = quest_action_provider.call(command)
	action_notice.text = String(response.get("notice","Chưa thể hoàn tất. Mở lại bảng và kiểm tra điều kiện.")) if response is Dictionary else "Chưa thể hoàn tất."
	action_notice.show()
	refresh()
	focus_recommended.call_deferred()

func scroll_detail(pixels: int) -> void:
	detail_scroll.scroll_vertical += pixels

func tracker_text() -> String:
	return "" # Gameplay never displays a persistent mission overlay.

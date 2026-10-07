class_name AntiqueSkin
extends RefCounted
## Shared antique presentation. Owns no inventory, price, transaction or save data.

const WOOD := Color("211811")
const SURFACE := Color("35271c")
const GOLD := Color("ad8852")
const LACQUER := Color("512722")
const TEXT := Color("eee0c5")
const MUTED := Color("c3ae8b")
const JADE := Color("92bca7")
const WARM := Color("e2be7e")
const PANEL: Texture2D = preload("res://assets/ui/antique/panel.svg")
const CARD: Texture2D = preload("res://assets/ui/antique/card.svg")
const SLOT: Texture2D = preload("res://assets/ui/antique/slot.svg")
const HEADER: Texture2D = preload("res://assets/ui/antique/header.svg")
const DIVIDER: Texture2D = preload("res://assets/ui/antique/divider.svg")
const BUTTONS: Dictionary = {
	&"normal": preload("res://assets/ui/antique/button.svg"),
	&"hover": preload("res://assets/ui/antique/button_hover.svg"),
	&"pressed": preload("res://assets/ui/antique/button_pressed.svg"),
	&"disabled": preload("res://assets/ui/antique/button_disabled.svg"),
	&"focus": preload("res://assets/ui/antique/focus.svg"),
}

static func texture_style(texture: Texture2D, slice: int = 18, margin: int = 12) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, slice)
		style.set_content_margin(side, margin)
	return style

static func panel_style(margin: int = 18) -> StyleBoxTexture:
	return texture_style(PANEL, 32, margin)

static func flat_style(margin: int = 16) -> StyleBoxFlat:
	# Compatibility API for callers that still request a mutable StyleBoxFlat.
	var style := StyleBoxFlat.new()
	style.bg_color = WOOD
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(margin)
	return style

static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 16
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_shadow_color", "Label", Color("120e0b"))
	result.set_constant("shadow_offset_y", "Label", 1)
	result.set_type_variation("AntiqueTitle", "Label")
	result.set_font_size("font_size", "AntiqueTitle", 23)
	result.set_color("font_color", "AntiqueTitle", WARM)
	result.set_type_variation("AntiqueMuted", "Label")
	result.set_color("font_color", "AntiqueMuted", MUTED)
	result.set_font_size("font_size", "AntiqueMuted", 14)
	for type_name: StringName in [&"Button", &"OptionButton"]:
		for state: StringName in BUTTONS:
			result.set_stylebox(state, type_name, texture_style(BUTTONS[state], 18, 10))
		for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
			result.set_color(state, type_name, TEXT)
		result.set_color("font_disabled_color", type_name, MUTED)
		result.set_constant("outline_size", type_name, 1)
		result.set_color("font_outline_color", type_name, Color("100c09"))
	result.set_stylebox("panel", "PanelContainer", panel_style())
	result.set_stylebox("panel", "Panel", panel_style())
	result.set_stylebox("panel", "TabContainer", texture_style(CARD, 16, 10))
	for type_name: StringName in [&"TabContainer", &"TabBar"]:
		result.set_stylebox("tab_selected", type_name, texture_style(HEADER, 18, 10))
		result.set_stylebox("tab_unselected", type_name, texture_style(BUTTONS[&"normal"], 18, 10))
		result.set_stylebox("tab_hovered", type_name, texture_style(BUTTONS[&"hover"], 18, 10))
		result.set_stylebox("tab_focus", type_name, texture_style(BUTTONS[&"focus"], 18, 10))
		result.set_color("font_selected_color", type_name, WARM)
		result.set_color("font_unselected_color", type_name, MUTED)
		result.set_font_size("font_size", type_name, 16)
	result.set_stylebox("panel", "TooltipPanel", texture_style(CARD, 16, 12))
	result.set_color("font_color", "TooltipLabel", TEXT)
	result.set_font_size("font_size", "TooltipLabel", 15)
	for type_name: StringName in [&"VScrollBar", &"HScrollBar"]:
		var track := flat_style(0)
		track.bg_color = Color("15110d")
		track.border_color = Color("53402b")
		var grip := flat_style(0)
		grip.bg_color = Color("927044")
		grip.border_color = Color("c2a06b")
		result.set_stylebox("scroll", type_name, track)
		result.set_stylebox("grabber", type_name, grip)
		var hover: StyleBoxFlat = grip.duplicate()
		hover.bg_color = GOLD
		result.set_stylebox("grabber_highlight", type_name, hover)
		result.set_stylebox("grabber_pressed", type_name, hover)
		result.set_constant("minimum_grab_length", type_name, 28)
	result.set_stylebox("panel", "ItemList", texture_style(CARD, 16, 8))
	result.set_stylebox("selected", "ItemList", texture_style(HEADER, 18, 5))
	result.set_stylebox("selected_focus", "ItemList", texture_style(HEADER, 18, 5))
	result.set_color("font_color", "ItemList", TEXT)
	result.set_color("font_selected_color", "ItemList", WARM)
	return result

static func apply_panel(panel: PanelContainer) -> void:
	panel.theme = make_theme()
	panel.add_theme_stylebox_override("panel", panel_style())

static func apply_tree(control: Control) -> void:
	# Called after inventory has built its existing cells; changes presentation only.
	if not is_instance_valid(control): return
	if control is PanelContainer:
		control.add_theme_stylebox_override("panel", panel_style())
	if control is Button:
		var is_slot: bool = control.custom_minimum_size.y >= 46 and control.expand_icon
		for state: StringName in BUTTONS:
			var texture: Texture2D = SLOT if is_slot and state == &"normal" else BUTTONS[state]
			control.add_theme_stylebox_override(state, texture_style(texture, 18, 5 if is_slot else 10))
	if control is Label and control.text == control.text.to_upper() and control.text.length() > 3:
		control.add_theme_color_override("font_color", WARM)
	for child: Node in control.get_children():
		if child is Control: apply_tree(child)

static func divider() -> TextureRect:
	var result := TextureRect.new()
	result.texture = DIVIDER
	result.custom_minimum_size.y = 12
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_SCALE
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func update_rune_art(slots: Array[Button], runes: Array[Button], inventory: GearInventory) -> void:
	for index: int in slots.size():
		var id: StringName = inventory.slots[index] if index < inventory.slots.size() else &""
		slots[index].icon = ItemArtCatalog.RUNE_ICONS.get(id, null) as Texture2D
		slots[index].expand_icon = true
		slots[index].add_theme_constant_override("icon_max_width", 28)
	for index: int in mini(runes.size(), GearInventory.RUNES.size()):
		runes[index].icon = ItemArtCatalog.RUNE_ICONS.get(GearInventory.RUNES[index].id, null) as Texture2D
		runes[index].expand_icon = true
		runes[index].add_theme_constant_override("icon_max_width", 28)

static func section(text: String) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.add_child(DungeonUI.label(text, 16, WARM))
	row.add_child(divider())
	return row

static func item_description(id: StringName) -> String:
	var descriptions: Dictionary = {
		&"metal": "Kim loại cũ dùng sửa và đúc trang bị.",
		&"dust": "Bột phép dùng sửa đồ và chế vật phẩm.",
		&"crystal": "Tinh thạch có thể bán cho Kael.",
		&"slime_essence": "Tinh chất từ Slime; Kael thu mua.",
		&"origin_divine_stone": "Nguyên liệu rèn cao cấp. Chưa có nguồn rơi hiện tại.",
		&"armor_scrap": "Phế liệu giáp dùng trong công thức rèn.",
		&"healing_herb": "Thảo dược dùng chế thuốc hồi máu.",
		&"linen_fiber": "Sợi vải dùng chế băng gạc.",
		&"aptitude_herb": "Linh thảo theo nguồn đã hái; dùng trong bảng Tu luyện. Không chuyển vào hành trang.",
		&"aptitude_pill": "Đan dược theo nguồn linh thảo; dùng một lần trong bảng Tu luyện. Không chuyển vào hành trang.",
		&"detox_root": "Rễ thảo dược dùng chế thuốc giải độc.",
		&"potion": "Thuốc hồi máu. Mua hoặc chế rồi cất trong túi.",
		&"bandage": "Băng gạc dùng băng bó vết thương.",
		&"antidote": "Thuốc giải độc cất trong túi tiêu hao.",
		&"trap": "Bẫy chế tại lửa trại, đặt trong thế giới.",
	}
	if String(id).begins_with("enhancement_stone_"):
		var grade: int = int(String(id).get_slice("_", 2))
		return "Cường hóa mốc +%d / +%d.%s" % [grade * 2 - 1, grade * 2, " Ghép 5 viên để lên cấp." if grade < 6 else " Cấp đá cao nhất."]
	return descriptions.get(id, "")

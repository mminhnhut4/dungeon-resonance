class_name ServiceItemCard
extends Button
## One read-only projection plus the original Button callback and stable NodePath.

var action_button: Button
var item_icon: TextureRect
var item_title: Label
var detail_label: Label
var quantity_label: Label
var _margin: MarginContainer
var _row: HBoxContainer
var _action_panel: PanelContainer
var _slot: PanelContainer
var _action_label: Label
var compact: bool = false

static func create(icon: Texture2D, title: String, details: String, quantity: String, action: String, callback: Callable, use_compact: bool = false) -> ServiceItemCard:
	var card := ServiceItemCard.new()
	card.action_button = card
	# Keep the native action text for accessibility and existing UI automation.
	# The child layout draws it with the item details, avoiding a second caption.
	card.text = action + " " + title
	card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_disabled_color"]:
		card.add_theme_color_override(state, Color.TRANSPARENT)
	card.add_theme_constant_override("outline_size", 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 96
	for state: StringName in AntiqueSkin.BUTTONS:
		var texture: Texture2D = AntiqueSkin.CARD if state == &"normal" else AntiqueSkin.BUTTONS[state]
		card.add_theme_stylebox_override(state, AntiqueSkin.texture_style(texture, 18, 10))
	card.tooltip_text = "%s\n%s\n%s" % [title, details, quantity]
	card._margin = MarginContainer.new()
	card._margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		card._margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(card._margin)
	card._row = HBoxContainer.new()
	card._row.add_theme_constant_override("separation", 12)
	card._margin.add_child(card._row)
	var slot := PanelContainer.new()
	card._slot = slot
	slot.custom_minimum_size = Vector2(76, 76)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", AntiqueSkin.texture_style(AntiqueSkin.SLOT, 18, 7))
	card._row.add_child(slot)
	card.item_icon = TextureRect.new()
	card.item_icon.name = "ItemImage"
	card.item_icon.texture = icon
	card.item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(card.item_icon)
	if icon == null:
		var pending := DungeonUI.label("Chưa có\nảnh riêng", 12, AntiqueSkin.MUTED)
		pending.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(pending)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 3)
	card._row.add_child(text)
	card.item_title = DungeonUI.label(title, 18, AntiqueSkin.TEXT)
	text.add_child(card.item_title)
	card.detail_label = DungeonUI.label(details, 14, AntiqueSkin.MUTED)
	card.detail_label.visible = not details.is_empty()
	text.add_child(card.detail_label)
	card.quantity_label = DungeonUI.label(quantity, 14, AntiqueSkin.JADE)
	card.quantity_label.visible = not quantity.is_empty()
	text.add_child(card.quantity_label)
	card._action_panel = PanelContainer.new()
	card._action_panel.custom_minimum_size = Vector2(100, 44)
	card._action_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card._action_panel.add_theme_stylebox_override("panel", AntiqueSkin.texture_style(AntiqueSkin.BUTTONS[&"normal"], 18, 10))
	var action_label := DungeonUI.label(action, 16, AntiqueSkin.TEXT)
	card._action_label = action_label
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	card._action_panel.add_child(action_label)
	card._row.add_child(card._action_panel)
	_ignore_children(card._margin)
	card._row.minimum_size_changed.connect(card._update_height)
	card.resized.connect(card._update_height)
	card.set_compact(use_compact)
	if callback.is_valid(): card.pressed.connect(callback)
	return card

func set_display_only() -> void:
	# action_button aliases this card; only the action chip should disappear.
	_action_panel.hide()
	disabled = true
	focus_mode = Control.FOCUS_NONE
	text = item_title.text

func set_compact(value: bool) -> void:
	compact = value
	var margin: int = 8 if compact else 10
	for side: String in ["left", "top", "right", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, margin)
	_row.add_theme_constant_override("separation", 8 if compact else 12)
	_slot.custom_minimum_size = Vector2(56, 56) if compact else Vector2(76, 76)
	_action_panel.custom_minimum_size = Vector2(58, 44) if compact else Vector2(100, 44)
	_action_panel.add_theme_stylebox_override("panel", AntiqueSkin.texture_style(AntiqueSkin.BUTTONS[&"normal"], 18, 6 if compact else 10))
	_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if compact else TextServer.AUTOWRAP_OFF
	item_title.add_theme_font_size_override("font_size", 16 if compact else 18)
	detail_label.visible = not compact and not detail_label.text.is_empty()
	_update_height()

static func _ignore_children(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in control.get_children():
		if child is Control: _ignore_children(child)

func _update_height() -> void:
	if _row != null:
		custom_minimum_size.y = maxf(76 if compact else 96, _row.get_combined_minimum_size().y + (16 if compact else 20))

func _draw() -> void:
	if _action_panel != null:
		_action_panel.modulate = Color("aaa091") if disabled else Color.WHITE

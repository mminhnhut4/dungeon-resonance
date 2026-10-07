class_name DungeonUI
extends RefCounted
## Local presentation theme; no project settings or shared editor resources.

const INK := AntiqueSkin.WOOD
const SURFACE := AntiqueSkin.SURFACE
const TEXT := AntiqueSkin.TEXT
const MUTED := AntiqueSkin.MUTED
const JADE := AntiqueSkin.JADE
const WARM := AntiqueSkin.WARM

static func panel_style(margin: int = 16) -> StyleBoxFlat:
	return AntiqueSkin.flat_style(margin)

static func make_theme() -> Theme:
	return AntiqueSkin.make_theme()

static func label(text: String, font_size: int = 16, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

static func is_navigation(event: InputEvent) -> bool:
	for action: StringName in [&"ui_accept", &"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_focus_next", &"ui_focus_prev"]:
		if event.is_action(action):
			return true
	return false

static func dispatch_controller(viewport: Viewport, event: InputEvent, axes: Dictionary) -> bool:
	# Engine defaults in this project contain keyboard UI events only. Translate
	# controller input inside an open modal without changing the shared Input Map.
	if not event is InputEventJoypadMotion and (is_navigation(event) or event.is_action(&"ui_cancel")): return false
	if event is InputEventJoypadButton:
		var actions: Dictionary = {JOY_BUTTON_A: &"ui_accept", JOY_BUTTON_B: &"ui_cancel", JOY_BUTTON_DPAD_UP: &"ui_up", JOY_BUTTON_DPAD_DOWN: &"ui_down", JOY_BUTTON_DPAD_LEFT: &"ui_left", JOY_BUTTON_DPAD_RIGHT: &"ui_right"}
		if not actions.has(event.button_index): return false
		_push_controller_action(viewport, actions[event.button_index], event.pressed)
		return true
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var key: String = "%d:%d" % [event.device, event.axis]
		var direction: int = int(signf(event.axis_value)) if absf(event.axis_value) >= 0.55 else 0
		var previous: int = int(axes.get(key, 0))
		if direction == previous: return true
		axes[key] = direction
		var negative: StringName = &"ui_left" if event.axis == JOY_AXIS_LEFT_X else &"ui_up"
		var positive: StringName = &"ui_right" if event.axis == JOY_AXIS_LEFT_X else &"ui_down"
		if previous != 0: _push_controller_action(viewport, negative if previous < 0 else positive, false)
		if direction != 0: _push_controller_action(viewport, negative if direction < 0 else positive, true)
		return true
	return false

static func _push_controller_action(viewport: Viewport, action: StringName, pressed: bool) -> void:
	var translated := InputEventAction.new()
	translated.action = action
	translated.pressed = pressed
	translated.strength = 1.0 if pressed else 0.0
	viewport.push_input(translated, true)

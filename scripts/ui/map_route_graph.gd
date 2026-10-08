class_name MapRouteGraph
extends Control
## Diagram of authored links, not terrain or a fast-travel interface.
signal room_selected(room: StringName)
var buttons: Dictionary = {}
var known: Dictionary = {}
var current_room: StringName = &""
var objective_room: StringName = &""
var shortcut: bool = false
var ids: Array[StringName] = [ExteriorRouteCatalog.HUB]

func _ready() -> void:
	custom_minimum_size = Vector2(250,300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ids.append_array(ExteriorRouteCatalog.all_rooms())
	for room: StringName in ids:
		var button := Button.new()
		button.add_theme_font_size_override("font_size",13)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(func() -> void: room_selected.emit(room))
		add_child(button)
		buttons[room] = button
	resized.connect(_layout)
	_layout()

func set_state(discoveries: Dictionary, current: StringName, target: StringName, opened_shortcut: bool) -> void:
	known = discoveries.duplicate()
	current_room = current if known.has(current) else &""
	objective_room = target if known.has(target) else &""
	shortcut = opened_shortcut
	for room: StringName in buttons:
		var button: Button = buttons[room]
		var seen: bool = known.has(room)
		button.disabled = not seen
		button.tooltip_text = MapQuestProjection.room_name(room) if seen else ""
		var code: String = "Căn cứ" if room == ExteriorRouteCatalog.HUB else String(room).split("_")[0].to_upper() if room in SectRouteCatalog.ROOMS else String(room).trim_prefix("o01_").trim_prefix("o02_").to_upper()
		var marker: String = "Bạn · Đích" if room == current_room and room == objective_room else "Bạn" if room == current_room else "Đích" if room == objective_room else "Đã tới"
		button.text = "?" if not seen else code+(" ●" if room==current_room else " ◆" if room==objective_room else "")
		if seen: button.tooltip_text += " · "+marker
	queue_redraw()

func _layout() -> void:
	var locations: Array[Vector2] = [Vector2(.125,.125),Vector2(.375,.125),Vector2(.625,.125),Vector2(.875,.125),Vector2(.875,.375),Vector2(.625,.375),Vector2(.375,.375),Vector2(.125,.375),Vector2(.125,.625),Vector2(.625,.625),Vector2(.875,.625),Vector2(.125,.875),Vector2(.375,.875)]
	var box := Vector2(minf(100,size.x*.235),minf(52,size.y*.22))
	for index: int in ids.size():
		var button: Button = buttons[ids[index]]
		button.size = box
		button.position = locations[index]*size-box/2
	queue_redraw()

func _draw() -> void:
	if buttons.is_empty(): return
	var ink: Color = get_theme_color("font_color","Label").darkened(.3)
	if known.has(&"o01_p01"): _edge(ExteriorRouteCatalog.HUB,&"o01_p01",ink)
	for room: StringName in ExteriorRouteCatalog.ROOMS:
		var link: Dictionary = ExteriorRouteCatalog.link(room,ExteriorRouteCatalog.MAIN,&"door_east")
		if not link.is_empty() and known.has(room) and known.has(link["room"]): _edge(room,link["room"],ink)
	for faction_id: String in SectRouteCatalog.FACTIONS:
		var first: StringName=SectRouteCatalog.first(faction_id)
		var parent: StringName=SectRouteCatalog.ROAD_ROOMS[faction_id]
		if known.has(first) and known.has(parent): _edge(parent,first,ink)
		var target: Dictionary=SectRouteCatalog.link(first,&"door_east")
		if known.has(first) and known.has(target["room"]): _edge(first,target["room"],ink)
	if shortcut:
		var start: Vector2 = (buttons[&"o01_p01"] as Button).get_rect().get_center()
		var end: Vector2 = (buttons[&"o01_p03"] as Button).get_rect().get_center()
		for step: int in 8:
			draw_line(start.lerp(end,float(step)/8),start.lerp(end,(float(step)+.55)/8),ink,2,true)

func _edge(from: StringName, to: StringName, color: Color) -> void:
	draw_line((buttons[from] as Button).get_rect().get_center(),(buttons[to] as Button).get_rect().get_center(),color,2,true)

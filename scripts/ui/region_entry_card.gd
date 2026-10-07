class_name RegionEntryCard
extends CanvasLayer
## A nonmodal area-name frame. No travel, writes, focus or time ownership.

const INK := Color("211716")
const TEXT := Color("f0d9a6")
const GOLD := Color("bd995a")
const RED := Color("93443d")
## Current ArtHUD frame and three rune sockets, including their outer margins.
const HUD_SAFE_RECT := Rect2(16,16,380,180)

class AntiqueFrame extends PanelContainer:
	func _ready() -> void:
		resized.connect(queue_redraw)
	func _draw() -> void:
		# Square lacquer-red frame, aged-gold rules and mirrored meander corners.
		# Vector strokes scale with the Control; no screenshot or texture asset.
		draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),GOLD,false,1.5,true)
		draw_rect(Rect2(Vector2(7,7),size-Vector2(14,14)),RED,false,2.0,true)
		draw_rect(Rect2(Vector2(10,10),size-Vector2(20,20)),Color(GOLD,0.58),false,1.0,true)
		for corner: Vector2 in [Vector2(13,13),Vector2(size.x-13,13),Vector2(13,size.y-13),size-Vector2(13,13)]:
			var direction := Vector2(1 if corner.x < size.x/2 else -1,1 if corner.y < size.y/2 else -1)
			_corner(corner,direction)
		for y: float in [7.0,size.y-7.0]:
			var middle := Vector2(size.x/2,y)
			draw_colored_polygon(PackedVector2Array([middle+Vector2(-5,0),middle+Vector2(0,-3),middle+Vector2(5,0),middle+Vector2(0,3)]),GOLD)
	func _corner(origin: Vector2, direction: Vector2) -> void:
		var outer := PackedVector2Array()
		for point: Vector2 in [Vector2(0,20),Vector2.ZERO,Vector2(20,0)]: outer.append(origin+point*direction)
		draw_polyline(outer,GOLD,2.0,true)
		var curl := PackedVector2Array()
		for point: Vector2 in [Vector2(5,18),Vector2(5,5),Vector2(18,5),Vector2(18,13),Vector2(11,13),Vector2(11,9)]: curl.append(origin+point*direction)
		draw_polyline(curl,Color(GOLD,0.82),1.5,true)

var panel: PanelContainer
var title_label: Label
var current_key: String = ""
var dismissed_key: String = ""
var destination: Dictionary = {}
var _portal_world: Vector2
var _actor_world: Vector2
var _layout_queued: bool = false
var _reserved_rects: Array[Rect2] = []

func set_reserved_rects(rectangles: Array[Rect2]) -> void:
	if _reserved_rects == rectangles: return
	_reserved_rects = rectangles.duplicate()
	_queue_layout()

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = AntiqueFrame.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK,0.97)
	style.border_color = RED
	style.set_border_width_all(4)
	style.set_content_margin_all(22)
	style.content_margin_left = 42
	style.content_margin_right = 42
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	title_label = _label("",22,TEXT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(title_label)
	panel.minimum_size_changed.connect(_queue_layout)
	get_viewport().size_changed.connect(_queue_layout)
	panel.hide()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	return label

func show_destination(key: String, target: Dictionary, _visited: bool, portal_world: Vector2, actor_world: Vector2) -> void:
	_portal_world = portal_world
	_actor_world = actor_world
	if current_key != key:
		current_key = key
		destination = target.duplicate()
		var room: StringName = target["room"]
		var route: StringName = target["route"]
		var area_name: String = ExteriorRouteCatalog.title(room,route)
		title_label.text = area_name if room == ExteriorRouteCatalog.HUB else area_name.get_slice(" · ",1)
	panel.visible = key != dismissed_key and not get_tree().paused
	_queue_layout()

func hide_preview(left_range: bool = false) -> void:
	panel.hide()
	if left_range:
		current_key = ""
		dismissed_key = ""
		destination.clear()

func dismiss() -> void:
	dismissed_key = current_key
	panel.hide()

func _process(_delta: float) -> void:
	if get_tree().paused: panel.hide()

func _queue_layout() -> void:
	if _layout_queued or is_queued_for_deletion(): return
	_layout_queued = true
	_layout.call_deferred()

func _layout() -> void:
	_layout_queued = false
	if not is_inside_tree() or is_queued_for_deletion(): return
	var extent: Vector2 = get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2.ZERO
	panel.size = Vector2(minf(340,extent.x-32),0)
	panel.size.y = panel.get_combined_minimum_size().y
	var camera: Transform2D = get_viewport().get_canvas_transform()
	var door: Vector2 = camera * _portal_world
	var actor: Vector2 = camera * _actor_world
	var x: float = maxf(door.x,actor.x)+60
	if x + panel.size.x > extent.x-16: x = minf(door.x,actor.x)-panel.size.x-60
	var y: float = actor.y-panel.size.y-28
	panel.position = Vector2(x,y).clamp(Vector2(16,80),(extent-panel.size-Vector2(16,16)).max(Vector2(16,80)))
	if panel.get_global_rect().intersects(HUD_SAFE_RECT):
		panel.position.y = minf(HUD_SAFE_RECT.end.y+8,extent.y-panel.size.y-16)
	# Stay close to the doorway while reserving the actual visible UI and actor.
	# Edge candidates give bounded layout work and keep the world margins intact.
	var preferred: Vector2 = panel.position
	var blockers: Array[Rect2] = [HUD_SAFE_RECT.grow(8), Rect2(actor+Vector2(-23,-66),Vector2(46,66)).grow(8)]
	for rectangle: Rect2 in _reserved_rects: blockers.append(rectangle.grow(8))
	var xs: Array[float] = [preferred.x]
	var ys: Array[float] = [preferred.y]
	for rectangle: Rect2 in blockers:
		xs.append(rectangle.position.x-panel.size.x)
		xs.append(rectangle.end.x)
		ys.append(rectangle.position.y-panel.size.y)
		ys.append(rectangle.end.y)
	var minimum := Vector2(16,80)
	var maximum: Vector2 = (extent-panel.size-Vector2(16,16)).max(minimum)
	var closest: Vector2 = preferred
	var closest_distance: float = INF
	for candidate_x: float in xs:
		for candidate_y: float in ys:
			var candidate: Vector2 = Vector2(candidate_x,candidate_y).clamp(minimum,maximum)
			var rectangle := Rect2(candidate,panel.size)
			var clear: bool = true
			for blocker: Rect2 in blockers:
				if rectangle.intersects(blocker):
					clear = false
					break
			var distance: float = candidate.distance_squared_to(preferred)
			if clear and distance < closest_distance:
				closest = candidate
				closest_distance = distance
	panel.position = closest

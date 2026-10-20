class_name TanDangCaptionLayout
extends RefCounted
## Room-local caption placement. The population supplies fresh base anchors.

const MAX_CAPTIONS: int = 3
const GAP: float = 2.0
const LANES: Array[Vector2] = [
	Vector2.ZERO,
	Vector2(0.0, -40.0),
	Vector2(0.0, 40.0),
	Vector2(0.0, -80.0),
	Vector2(0.0, 80.0),
	Vector2(96.0, 0.0),
	Vector2(-96.0, 0.0),
	Vector2(96.0, -40.0),
	Vector2(-96.0, -40.0),
	Vector2(96.0, 40.0),
	Vector2(-96.0, 40.0),
	Vector2(0.0, -120.0),
]


static func place(labels: Array[Label], anchors: Array[Vector2], viewport_rect: Rect2, reserved: Array[Rect2] = []) -> Dictionary:
	var occupied: Array[Rect2] = reserved.duplicate()
	var considered: int = 0
	var unresolved: int = 0
	for index: int in mini(MAX_CAPTIONS, mini(labels.size(), anchors.size())):
		var label: Label = labels[index]
		if not is_instance_valid(label) or not label.is_inside_tree() or not label.is_visible_in_tree() or not label.get_parent() is Node2D:
			continue
		var parent: Node2D = label.get_parent() as Node2D
		var anchor: Vector2 = anchors[index]
		label.position = anchor
		# A caption may enter the frame before its owner. Keep such edge labels
		# at the authored anchor instead of pulling them away from that owner.
		var actor_screen: Vector2 = parent.get_global_transform_with_canvas() * Vector2.ZERO
		if not viewport_rect.grow(24.0).has_point(actor_screen):
			continue
		var baseline: Rect2 = _rect(label)
		if not baseline.intersects(viewport_rect):
			continue
		considered += 1
		var chosen: Vector2 = anchor
		var chosen_rect: Rect2 = baseline
		var best_cost: float = INF
		var clean_distance: float = INF
		for lane: Vector2 in LANES:
			label.position = anchor + lane.rotated(-parent.rotation)
			var rect: Rect2 = _rect(label)
			var overlap: float = 0.0
			for previous: Rect2 in occupied:
				overlap += rect.grow(GAP).intersection(previous.grow(GAP)).get_area()
			var outside: float = maxf(0.0, rect.get_area() - rect.intersection(viewport_rect).get_area())
			var cost: float = overlap * 1000.0 + outside * 100.0 + lane.length()
			var clean: bool = overlap <= 0.001 and outside <= 0.001
			if (clean and lane.length() < clean_distance) or (clean_distance == INF and cost < best_cost):
				if clean: clean_distance = lane.length()
				best_cost = cost
				chosen = label.position
				chosen_rect = rect
			if clean and lane == Vector2.ZERO:
				break # An undisturbed anchor cannot be improved by another lane.
		label.position = chosen
		occupied.append(chosen_rect)
		if clean_distance == INF:
			unresolved += 1
	return {"considered": considered, "unresolved": unresolved}


static func _rect(label: Label) -> Rect2:
	# The authored 72 px Control is taller than its glyphs. Reserve only the
	# occupied lines, or nearby residents would be pushed away for empty space.
	var line_height: float = label.get_line_height()
	var line_count: int = maxi(1, label.get_line_count())
	var content_height: float = line_height * line_count + float(label.get_theme_constant("line_spacing")) * maxi(0, line_count - 1)
	var size: Vector2 = Vector2(label.size.x, content_height)
	var transform: Transform2D = label.get_global_transform_with_canvas()
	var bounds: Rect2 = Rect2(transform * Vector2.ZERO, Vector2.ZERO)
	for point: Vector2 in [Vector2(size.x, 0.0), Vector2(0.0, size.y), size]:
		bounds = bounds.expand(transform * point)
	return bounds.abs()

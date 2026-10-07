class_name ServiceItemGrid
extends Container
## Row-major item pairs and full-width service headings share one scroll surface.
## Children stay direct descendants, preserving the original action NodePaths.

var columns: int = 1:
	set(value):
		columns = clampi(value, 1, 2)
		update_minimum_size()
		queue_sort()
var footer_focus: Control
var right_inset: float = 0.0:
	set(value):
		right_inset = maxf(0, value)
		queue_sort()
const GAP: float = 12.0

func _rows() -> Array[Array]:
	var result: Array[Array] = []
	var pair: Array[Control] = []
	for node: Node in get_children():
		if not node is Control or not node.visible: continue
		var child := node as Control
		if child is ServiceItemCard:
			pair.append(child)
			if pair.size() == columns:
				result.append(pair)
				pair = []
		else:
			if not pair.is_empty():
				result.append(pair)
				pair = []
			result.append([child])
	if not pair.is_empty(): result.append(pair)
	return result

func _get_minimum_size() -> Vector2:
	var height: float = 0.0
	var rows := _rows()
	for row: Array in rows:
		var row_height: float = 0.0
		for child: Control in row: row_height = maxf(row_height, child.get_combined_minimum_size().y)
		height += row_height
	return Vector2(0, height + maxf(0, rows.size() - 1) * GAP)

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN: return
	var rows := _rows()
	var y: float = 0.0
	for row: Array in rows:
		var row_height: float = 0.0
		for child: Control in row: row_height = maxf(row_height, child.get_combined_minimum_size().y)
		var is_pair: bool = row[0] is ServiceItemCard
		var inner_width: float = maxf(0, size.x - right_inset)
		var width: float = (inner_width - GAP * (columns - 1)) / columns if is_pair else inner_width
		for index: int in row.size(): fit_child_in_rect(row[index], Rect2(Vector2(index * (width + GAP), y), Vector2(width, row_height)))
		y += row_height + GAP
	_configure_focus(rows)

func _configure_focus(rows: Array[Array]) -> void:
	var enabled: Array[Control] = []
	for row: Array in rows:
		for child: Control in row:
			if child is Button and not child.disabled: enabled.append(child)
	for index: int in enabled.size():
		var child: Control = enabled[index]
		child.focus_previous = child.get_path_to(enabled[index - 1]) if index > 0 else NodePath()
		child.focus_next = child.get_path_to(enabled[index + 1]) if index + 1 < enabled.size() else child.get_path_to(footer_focus) if is_instance_valid(footer_focus) else NodePath()
	for row_index: int in rows.size():
		var row: Array = rows[row_index]
		for column: int in row.size():
			var child := row[column] as Control
			if not child is Button or child.disabled: continue
			child.focus_neighbor_left = child.get_path_to(row[column - 1]) if column > 0 and not row[column - 1].disabled else child.get_path_to(child)
			child.focus_neighbor_right = child.get_path_to(row[column + 1]) if column + 1 < row.size() and not row[column + 1].disabled else child.get_path_to(child)
			for direction: int in [-1, 1]:
				var target: Control
				var target_row: int = row_index + direction
				while target_row >= 0 and target_row < rows.size():
					var candidates: Array = rows[target_row]
					var candidate := candidates[mini(column, candidates.size() - 1)] as Control
					if candidate is Button and not candidate.disabled:
						target = candidate
						break
					target_row += direction
				if direction > 0 and target == null: target = footer_focus
				var path: NodePath = child.get_path_to(target) if is_instance_valid(target) else child.get_path_to(child)
				if direction < 0: child.focus_neighbor_top = path
				else: child.focus_neighbor_bottom = path
	if is_instance_valid(footer_focus) and not enabled.is_empty():
		footer_focus.focus_previous = footer_focus.get_path_to(enabled.back())
		footer_focus.focus_neighbor_top = footer_focus.focus_previous

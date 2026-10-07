class_name DungeonDebugOverlay
extends Node
## Room-owned visibility registry. Modal controls and damage numbers stay usable.

var world: Node2D
var enabled: bool = false
var widgets: Dictionary[int, WeakRef] = {}
var _generation: int = 0

func _enter_tree() -> void:
	if is_instance_valid(world):
		_watch_tree()
		# Other room children may still be entering; register after their ready.
		_rescan.call_deferred(_generation)

func initialize(owner_world: Node2D) -> void:
	_generation += 1
	_release_widgets()
	world = owner_world
	world.set_meta(&"debug_visible", enabled)
	_rescan(_generation)
	_watch_tree()

func _is_active() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() and world.is_ancestor_of(self)

func _watch_tree() -> void:
	if _is_active() and not get_tree().node_added.is_connected(_node_added):
		get_tree().node_added.connect(_node_added)

func _rescan(generation: int) -> void:
	if generation != _generation or not _is_active():
		return
	for node: Node in world.find_children("*", "Label", true, false):
		_register(node)
	for node: Node in world.find_children("*", "ProgressBar", true, false):
		if node.name != &"HealthBar" and node != world.get("hp_bar") and node != world.get("boss_hp"):
			_register(node)
	if world.get("debug_hud") != null:
		_register(world.get("debug_hud").get_node("Panel"))

func _node_added(node: Node) -> void:
	if node is Label and _is_active():
		# Resolving a live ID inside the callback avoids deferred argument casts
		# failing before _register can reject a freed Node.
		_register_added.call_deferred(node.get_instance_id(), _generation)

func _register_added(node_id: int, generation: int) -> void:
	if generation != _generation or not _is_active() or not is_instance_id_valid(node_id):
		return
	_register(instance_from_id(node_id) as Node)

func _register(node: Node) -> void:
	if not _is_active() or not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion() or not world.is_ancestor_of(node) or node.get_meta(&"debug_keep", false):
		return
	var ancestor: Node = node
	while ancestor != world:
		if ancestor is PanelContainer or ancestor.is_in_group(&"combat_text"):
			return
		ancestor = ancestor.get_parent()
	var id: int = node.get_instance_id()
	if widgets.has(id):
		return
	widgets[id] = weakref(node)
	node.tree_exiting.connect(_unregister.bind(id), CONNECT_ONE_SHOT)
	(node as CanvasItem).visible = enabled

func _unregister(id: int) -> void:
	widgets.erase(id)

func set_enabled(value: bool) -> void:
	enabled = value
	if is_instance_valid(world):
		world.set_meta(&"debug_visible", value)
	for id: int in widgets.keys():
		var widget: CanvasItem = widgets[id].get_ref() as CanvasItem
		if widget == null:
			widgets.erase(id)
		else:
			widget.visible = value

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay") and not event.is_echo():
		set_enabled(not enabled)
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	_generation += 1
	var tree: SceneTree = get_tree()
	if tree.node_added.is_connected(_node_added):
		tree.node_added.disconnect(_node_added)
	_release_widgets()

func _release_widgets() -> void:
	for id: int in widgets.keys():
		var widget: CanvasItem = widgets[id].get_ref() as CanvasItem
		var callback: Callable = _unregister.bind(id)
		if is_instance_valid(widget) and widget.tree_exiting.is_connected(callback):
			widget.tree_exiting.disconnect(callback)
	widgets.clear()

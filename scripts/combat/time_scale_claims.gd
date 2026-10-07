class_name TimeScaleClaims
extends RefCounted
## Global scale is composed from finite owners; metadata contains scalar IDs only.

const META_KEY: StringName = &"dungeon_time_scale_claims_v1"


static func acquire(owner: Node, scale: float) -> void:
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return
	var tree: SceneTree = owner.get_tree()
	var state: Dictionary = tree.get_meta(META_KEY, {})
	if state.is_empty():
		state = {"base": Engine.time_scale, "owners": {}}
	var owners: Dictionary = state["owners"]
	owners[owner.get_instance_id()] = clampf(scale, 0.001, 1.0)
	tree.set_meta(META_KEY, state)
	_reconcile(tree)


static func release(owner: Node) -> void:
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return
	var tree: SceneTree = owner.get_tree()
	var state: Dictionary = tree.get_meta(META_KEY, {})
	if state.is_empty():
		return
	(state["owners"] as Dictionary).erase(owner.get_instance_id())
	_reconcile(tree)


static func release_subtree(owner: Node) -> void:
	# Call before detaching the old run. Claims outside it remain in force.
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return
	var tree: SceneTree = owner.get_tree()
	var state: Dictionary = tree.get_meta(META_KEY, {})
	if state.is_empty():
		return
	var owners: Dictionary = state["owners"]
	for id: int in owners.keys():
		var claimant: Node = instance_from_id(id) as Node
		if not is_instance_valid(claimant) or claimant == owner or owner.is_ancestor_of(claimant):
			owners.erase(id)
	_reconcile(tree)


static func owner_count(tree: SceneTree) -> int:
	_reconcile(tree)
	var state: Dictionary = tree.get_meta(META_KEY, {})
	return (state["owners"] as Dictionary).size() if not state.is_empty() else 0


static func _reconcile(tree: SceneTree) -> void:
	var state: Dictionary = tree.get_meta(META_KEY, {})
	if state.is_empty():
		return
	var owners: Dictionary = state["owners"]
	var scale: float = float(state["base"])
	for id: int in owners.keys():
		var claimant: Node = instance_from_id(id) as Node
		if not is_instance_valid(claimant) or not claimant.is_inside_tree():
			owners.erase(id)
		else:
			scale = minf(scale, float(owners[id]))
	Engine.time_scale = scale
	if owners.is_empty():
		tree.remove_meta(META_KEY)

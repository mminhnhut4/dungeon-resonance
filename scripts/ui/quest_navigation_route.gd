class_name QuestNavigationRoute
extends RefCounted
## Bounded next-door query over the existing authored graph. No discovery writes.
static func next_door(room: StringName,route: StringName,target: StringName,known: Dictionary,shortcut: bool,right_of_gate: bool = false) -> StringName:
	if not known.has(room) or not known.has(target) or not ExteriorRouteCatalog.valid_route(room,route): return &""
	if room == target: return &""
	var queue: Array[Dictionary] = [{"room":room,"route":route,"first":&""}]
	var visited: Dictionary = {}
	while not queue.is_empty() and visited.size() < 18:
		var state: Dictionary = queue.pop_front()
		var key: String = "%s:%s" % [state["room"],state["route"]]
		if visited.has(key): continue
		visited[key] = true
		if state["room"] == target: return state["first"]
		for door: StringName in [&"door_west",&"door_east",&"tunnel"]:
			var link: Dictionary
			if state["room"] == ExteriorRouteCatalog.HUB:
				if door != &"door_east": continue
				link = {"room":ExteriorRouteCatalog.ROOMS[0],"route":ExteriorRouteCatalog.MAIN}
			else:
				if door == &"tunnel" and (not shortcut or state["route"] != ExteriorRouteCatalog.MAIN or state["room"] not in [ExteriorRouteCatalog.ROOMS[0],ExteriorRouteCatalog.ROOMS[2]]): continue
				if state["route"] == ExteriorRouteCatalog.TUNNEL:
					if door == &"tunnel": continue
					if not shortcut and door != (&"door_east" if right_of_gate else &"door_west"): continue
				link = ExteriorRouteCatalog.link(state["room"],state["route"],door)
			if link.is_empty() or not known.has(link["room"]): continue
			queue.append({"room":link["room"],"route":link["route"],"first":door if state["first"] == &"" else state["first"]})
	return &""

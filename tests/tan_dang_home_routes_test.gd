extends SceneTree
const HomeCatalog = preload("res://scripts/world/tan_dang_home_catalog.gd")
const HomeArt = preload("res://scripts/presentation/tan_dang_home_art.gd")
## Geography/layout contracts only. Actual E traversal and save receipts have separate integration QA.
const LEGACY_ROADS: Array[StringName] = [&"o01_p01",&"o01_p02",&"o01_p03",&"o01_p04",&"o02_b01",&"o02_b02",&"o02_b03",&"o02_b04"]
const LEGACY_BRANCHES: Array[StringName] = [&"tv01_cloud_gate",&"tv02_pine_court",&"xl01_red_causeway",&"xl02_cooling_yard"]
var checks: int = 0
var failures: int = 0
var owned_refs: Array[WeakRef] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: Tàn Đăng home route QA requires isolated user://")
		quit(2)
		return
	_catalog_and_routes()
	_geography_round_trip()
	_room_geometry()
	await _map_layout()
	# Return from the nested layout coroutine before the independent teardown
	# check. This diagnoses pending fixture work; it does not clear script caches.
	call_deferred("_finish")

func _finish() -> void:
	await process_frame
	await process_frame
	for ref: WeakRef in owned_refs:
		_check(ref.get_ref() == null,"A fixture-owned room/art/graph/button has been freed")
	owned_refs.clear()
	print("RESULT tan_dang_home_routes checks=%d failures=%d" % [checks,failures])
	call_deferred("quit",0 if failures == 0 else 1)

func _catalog_and_routes() -> void:
	var all_rooms: Array[StringName] = ExteriorRouteCatalog.all_rooms()
	_check(ExteriorRouteCatalog.ROOMS == LEGACY_ROADS,"Original eight road IDs and their order are preserved")
	_check(SectRouteCatalog.ROOMS == LEGACY_BRANCHES,"Original four branch IDs and their order are preserved")
	_check(SectRouteCatalog.FACTIONS == ["thanh_van","xich_lo"],"Home does not enter the independent two-faction observation ledger")
	_check(all_rooms.size() == 13 and all_rooms.count(HomeCatalog.ROOM) == 1,"Exactly one home is added to exterior geography")
	var known: Dictionary = {ExteriorRouteCatalog.HUB:true}
	for id: StringName in all_rooms:
		_check(not known.has(id),"Geography contains no duplicate: "+String(id))
		known[id] = true
		_check(not MapQuestProjection.room_name(id).is_empty(),"Every known location has a display name")
	_check(ExteriorRouteCatalog.region(HomeCatalog.ROOM) == HomeCatalog.REGION,"Home has its own Tàn Đăng region")
	_check(ExteriorRouteCatalog.valid_route(HomeCatalog.ROOM,ExteriorRouteCatalog.MAIN),"Home accepts the ordinary walking route")
	_check(not ExteriorRouteCatalog.valid_route(HomeCatalog.ROOM,ExteriorRouteCatalog.TUNNEL),"Home cannot impersonate the guard corridor")
	var entry: Dictionary = ExteriorRouteCatalog.link(ExteriorRouteCatalog.HUB,ExteriorRouteCatalog.MAIN,HomeCatalog.HUB_DOOR)
	_check(entry == {"room":HomeCatalog.ROOM,"route":ExteriorRouteCatalog.MAIN,"anchor":&"west"},"Physical hub station targets the home west entrance")
	var back: Dictionary = ExteriorRouteCatalog.link(HomeCatalog.ROOM,ExteriorRouteCatalog.MAIN,&"door_west")
	_check(back == {"room":ExteriorRouteCatalog.HUB,"route":ExteriorRouteCatalog.MAIN,"anchor":HomeCatalog.HUB_DOOR},"Home return preserves the distinct hub station anchor")
	_check(ExteriorRouteCatalog.link(HomeCatalog.ROOM,ExteriorRouteCatalog.MAIN,&"door_east").is_empty(),"There is no fake onward map door")
	_check(ExteriorRouteCatalog.link(HomeCatalog.ROOM,ExteriorRouteCatalog.MAIN,&"tunnel").is_empty(),"The home cannot accidentally enter SC01")
	_check(ExteriorRouteCatalog.link(LEGACY_ROADS[0],ExteriorRouteCatalog.MAIN,&"door_west")["anchor"] == &"road","Original road return anchor remains unchanged")
	_check(QuestNavigationRoute.next_door(ExteriorRouteCatalog.HUB,ExteriorRouteCatalog.MAIN,HomeCatalog.ROOM,known,false) == HomeCatalog.HUB_DOOR,"Known home is reached through its physical hub station")
	_check(QuestNavigationRoute.next_door(HomeCatalog.ROOM,ExteriorRouteCatalog.MAIN,ExteriorRouteCatalog.HUB,known,false) == &"door_west","Home navigation points to the return door")
	_check(QuestNavigationRoute.next_door(HomeCatalog.ROOM,ExteriorRouteCatalog.MAIN,LEGACY_ROADS[2],known,false) == &"door_west","Home-to-road guidance traverses the hub")
	_check(QuestNavigationRoute.next_door(LEGACY_BRANCHES[3],ExteriorRouteCatalog.MAIN,HomeCatalog.ROOM,known,false) == &"door_west","Farthest existing branch still finds the home within the bounded graph")
	_check(QuestNavigationRoute.next_door(ExteriorRouteCatalog.HUB,ExteriorRouteCatalog.MAIN,LEGACY_ROADS[0],known,false) == &"door_east","Original hub road guidance remains intact")
	known.erase(HomeCatalog.ROOM)
	_check(QuestNavigationRoute.next_door(ExteriorRouteCatalog.HUB,ExteriorRouteCatalog.MAIN,HomeCatalog.ROOM,known,false) == &"","Unknown home does not gain an undiscovered map route")

func _geography_round_trip() -> void:
	var old_state: Dictionary = ExteriorProgress.empty()
	for id: StringName in LEGACY_ROADS+LEGACY_BRANCHES:
		old_state["discovered_rooms"].append(String(id))
	old_state["room_id"] = String(LEGACY_BRANCHES[1])
	old_state["region_id"] = "thanh_van"
	old_state["anchor_id"] = "west"
	_check(ExteriorProgress.valid(JSON.parse_string(JSON.stringify(old_state))),"An old v1 geography with all twelve prior rooms still loads")
	var home_state: Dictionary = old_state.duplicate(true)
	home_state["room_id"] = String(HomeCatalog.ROOM)
	home_state["region_id"] = String(HomeCatalog.REGION)
	home_state["discovered_rooms"].append(String(HomeCatalog.ROOM))
	_check(ExteriorProgress.valid(JSON.parse_string(JSON.stringify(home_state))),"Home and all prior discoveries survive a JSON save/load boundary")
	home_state["room_id"] = String(ExteriorRouteCatalog.HUB)
	home_state["region_id"] = String(ExteriorRouteCatalog.HUB)
	home_state["anchor_id"] = String(HomeCatalog.HUB_DOOR)
	_check(ExteriorProgress.valid(JSON.parse_string(JSON.stringify(home_state))),"New hub return anchor is a valid cold-load location")
	home_state["anchor_id"] = "road"
	_check(ExteriorProgress.valid(home_state),"Existing hub road anchor stays valid")
	home_state["anchor_id"] = "unknown_home_anchor"
	_check(not ExteriorProgress.valid(home_state),"Unknown hub anchors remain rejected")
	home_state["anchor_id"] = String(HomeCatalog.HUB_DOOR)
	home_state["discovered_rooms"].append(String(HomeCatalog.ROOM))
	_check(not ExteriorProgress.valid(home_state),"Duplicate discovery receipts remain rejected")

func _room_geometry() -> void:
	var room := ExteriorRoom.new()
	owned_refs.append(weakref(room))
	_check(room.configure(HomeCatalog.ROOM,ExteriorRouteCatalog.MAIN,false),"Home creates a real ExteriorRoom without another session")
	_check(is_equal_approx(room.width,2200.0),"Home occupies the authored 2200-pixel walking room")
	_check(room.dry_anchor(&"west") and room.dry_anchor(&"east"),"Both saved anchors stand on dry flat floor")
	for x: float in [90.0,150.0,HomeCatalog.DEPUTY_X,HomeCatalog.LEADER_X,2050.0]:
		_check(is_equal_approx(room.floor_y(x),640.0),"Continuous floor supports doors and officers at x=%.0f" % x)
		var supported: bool = false
		for child: Node in room.get_children():
			if not child is StaticBody2D: continue
			for shape: Node in child.get_children():
				if shape is CollisionPolygon2D and Geometry2D.is_point_in_polygon(Vector2(x,645),(shape as CollisionPolygon2D).polygon):
					supported = true
		_check(supported,"A physical solid supports the route at x=%.0f" % x)
	_check(room.interactions.has(&"door_west") and not room.interactions.has(&"door_east"),"Only the real return door is offered")
	var art := room.get_node_or_null("TanDangHomeArt") as Node2D
	_check(art != null,"Home scenery is attached to the actual room")
	if art != null:
		owned_refs.append(weakref(art))
		_check(art.get_node_or_null("GateTitle") != null and art.get_node_or_null("CourtTitle") != null and art.get_node_or_null("HallTitle") != null,"Gate, courtyard and main hall are visibly named")
		_check(art.find_children("*","CollisionObject2D",true,false).is_empty(),"Decorative architecture adds no hidden collision barrier")
		_check(HomeArt.attach(room) == art,"Repeated art attachment cannot duplicate scenery")
	_check(room.bounds.has_point(Vector2(HomeCatalog.LEADER_X,640)),"Camera bounds include the leader's floor")
	room.free()
	art = null
	room = null

func _map_layout() -> void:
	var graph := MapRouteGraph.new()
	owned_refs.append(weakref(graph))
	root.add_child(graph)
	await process_frame
	var known: Dictionary = {ExteriorRouteCatalog.HUB:true}
	for id: StringName in ExteriorRouteCatalog.all_rooms(): known[id] = true
	graph.set_state(known,HomeCatalog.ROOM,ExteriorRouteCatalog.HUB,false)
	_check(graph.buttons.size() == 14,"Map includes the hub and thirteen exterior locations")
	for extent: Vector2 in [Vector2(250,300),Vector2(480,340)]:
		graph.size = extent
		graph._layout()
		var rectangles: Array[Rect2] = []
		for button: Button in graph.buttons.values():
			var rect: Rect2 = button.get_rect()
			_check(Rect2(Vector2.ZERO,graph.size).encloses(rect),"Map button remains within %.0fx%.0f" % [extent.x,extent.y])
			for prior: Rect2 in rectangles:
				_check(not prior.intersects(rect),"Map buttons remain separate at %.0fx%.0f" % [extent.x,extent.y])
			rectangles.append(rect)
	var home_button: Button = graph.buttons[HomeCatalog.ROOM]
	owned_refs.append(weakref(home_button))
	_check(not home_button.disabled and home_button.tooltip_text.contains(HomeCatalog.TITLE),"Discovered home has a usable named map node")
	known.erase(HomeCatalog.ROOM)
	graph.set_state(known,ExteriorRouteCatalog.HUB,&"",false)
	_check(home_button.disabled and home_button.text == "?" and home_button.tooltip_text.is_empty(),"Undiscovered home stays hidden")
	graph.free()
	home_button = null
	graph = null

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+message)

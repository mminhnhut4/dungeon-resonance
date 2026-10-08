class_name QuestNavigator
extends Control
## One session selection; canonical quests, travel, rewards and save stay owned.
const TRACKED: StringName = &"quest_navigation_id"
const Route = preload("res://scripts/ui/quest_navigation_route.gd")
var profile: SanctuaryProfile
var inventory: GearInventory
var world_ref: WeakRef
var player_ref: WeakRef
var screen_ref: WeakRef
var journal_ref: WeakRef
var state: Dictionary = {"status":"idle","hint":"Chọn một nhiệm vụ để theo dõi đường đi."}
var direction := Vector2.RIGHT
var arrived: bool = false
var _remaining: float = 0.0

func initialize(source: SanctuaryProfile,carried: GearInventory,world: Node,actor: Node2D,screen: Node,journal: Node) -> void:
	profile = source; inventory = carried
	world_ref = weakref(world); player_ref = weakref(actor); screen_ref = weakref(screen); journal_ref = weakref(journal)
	mouse_filter = Control.MOUSE_FILTER_IGNORE; size = Vector2(28,28)
	hide(); update_navigation()

static func property(host: Object,key: StringName,fallback: Variant = null) -> Variant:
	if not is_instance_valid(host): return fallback
	for entry: Dictionary in host.get_property_list():
		if StringName(entry["name"]) == key: return host.get(key)
	return fallback

func tracked_id() -> StringName:
	return StringName(profile.get_meta(TRACKED,&"")) if profile != null else &""

func track(id: StringName) -> void:
	var journal: Node = journal_ref.get_ref() as Node
	if profile == null or not is_instance_valid(journal): return
	if id != &"":
		var found: bool = false
		for row: Dictionary in journal.get("rows"):
			if row["id"] == id: found = true; break
		if not found: return
	profile.set_meta(TRACKED,id) # Runtime only: never exported to the save schema.
	update_navigation()

func _fallback(status: String,hint: String) -> Dictionary:
	return {"status":status,"hint":hint}

func _point(point: Vector2,hint: String,anchor: StringName) -> Dictionary:
	return {"status":"point","hint":hint,"point":point,"anchor":anchor}

func _station(world: Node,id: StringName) -> Dictionary:
	var stations: Dictionary = property(world,&"stations",{})
	var marker: Node2D = stations.get(id) as Node2D
	if id in [NpcCatalog.HEALER,NpcCatalog.WANDERER,NpcCatalog.SMITH]:
		var npcs: Dictionary = property(world,&"npcs",{})
		var npc: Node = npcs.get(id) as Node
		if not is_instance_valid(npc) or npc.is_queued_for_deletion(): return _fallback("npc_missing","NPC cần gặp chưa hiện diện; không có vị trí hợp lệ. Đọc hướng dẫn nhiệm vụ hoặc trở lại căn cứ sau.")
		var health: Object = property(npc,&"health")
		if bool(npc.get_meta(&"dead",false)) or (is_instance_valid(health) and float(property(health,&"current_health",0.0)) <= 0.0): return _fallback("npc_dead","NPC cần gặp đã chết / không còn hoạt động; nhiệm vụ chưa tự hoàn tất. Không có mũi tên tới NPC này.")
	if not is_instance_valid(marker) or marker.is_queued_for_deletion(): return _fallback("anchor_missing","Chưa có điểm tương tác hợp lệ cho bước này; xem chi tiết nhiệm vụ.")
	var names: Dictionary = {&"exterior_road":"ĐƯỜNG BỘ",&"portal":"cổng hầm ngục",&"training":"SÂN LUYỆN"}
	return _point(marker.global_position,"Đi tới %s rồi nhấn E; hướng dẫn và giá thực nằm ở thẻ nhiệm vụ." % NpcCatalog.NAMES.get(id,names.get(id,"điểm tương tác")),id)

func _outside(world: Node,actor: Node2D,target: StringName) -> Dictionary:
	var exterior: Node2D = property(world,&"exterior") as Node2D
	if not is_instance_valid(exterior): return _fallback("map_missing","Vùng hiện tại chưa sẵn sàng; mũi tên tạm dừng.")
	var known: Dictionary = MapQuestProjection.known_rooms(profile)
	var room := StringName(property(exterior,&"room_id",&""))
	var route := StringName(property(exterior,&"route_id",&""))
	if not known.has(target): return _fallback("map_unknown","Đích chưa khảo sát / chưa có quyền chỉ đường; xem hướng dẫn để khám phá, không mở map tự động.")
	if room == target: return _fallback("in_region","Đã tới khu mục tiêu; xem hướng dẫn tương tác trong nhiệm vụ.")
	var door: StringName = Route.next_door(room,route,target,known,MapQuestProjection.shortcut_known(profile,known),exterior.to_local(actor.global_position).x > 640.0)
	var interactions: Dictionary = property(exterior,&"interactions",{})
	if door == &"" or not interactions.has(door): return _fallback("route_locked","Chưa có tuyến hợp lệ đã biết tới đích; lối khóa vẫn giữ nguyên. Đọc sơ đồ / hướng dẫn.")
	return _point(exterior.to_global(interactions[door]),"Theo cửa %s của tuyến đã biết; E đi qua, mũi tên cập nhật ở vùng kế tiếp." % ("trái" if door == &"door_west" else "phải" if door == &"door_east" else "đường giữ đèn"),door)

func _exit_goal(world: Node) -> Dictionary:
	if StringName(property(world,&"outcome",&"")) != &"": return _fallback("return_pending","Đang chờ chuyển vùng / lưu phần thưởng; dùng nút retry hiện có nếu lưu thất bại.")
	var room: Node2D = property(world,&"room") as Node2D
	if not is_instance_valid(room) or bool(property(room,&"locked",true)): return _fallback("exit_locked","Cửa tầng còn khóa; hoàn tất đợt địch hiện tại. Mũi tên không chỉ xuyên cửa khóa.")
	if bool(property(world,&"portal_active",false)): return _point(Vector2(1160,640),"Đến cổng cuối, E → Trở về sảnh; chỉ thắng Golem rồi về mới ghi mốc chiến thắng.",&"victory_portal")
	if int(property(world,&"room_number",3)) >= 3: return _fallback("exit_locked","Cổng cuối chưa mở; cần hoàn tất thủ lĩnh hiện tại.")
	# Positions are the existing DungeonRun floor-exit thresholds, not new doors.
	return _point(Vector2(1240,640),"Đến lối ra phải, E chọn tiếp tục / về sảnh / ở lại. Về sớm không tính thắng Golem.",&"floor_exit")

func _dungeon_goal(world: Node,actor: Node2D,id: StringName) -> Dictionary:
	if id == &"reward_collected":
		var gear: Node = property(world,&"gear") as Node
		var loot: Node = property(gear,&"loot") as Node
		if is_instance_valid(loot):
			for pickup: Node in loot.get_children():
				if property(pickup,&"kind",&"") == &"soul" and not bool(property(pickup,&"collected_once",false)) and not pickup.is_queued_for_deletion(): return _point((pickup as Node2D).global_position,"Đến Tàn Hồn đã rơi và E nhặt; phần rơi có thể trống.",&"soul_pickup")
		return _fallback("loot_missing","Chưa có Tàn Hồn đã rơi trong tầng này; không có đích để đánh dấu và không cấp loot thay thế.")
	if id != &"returned_to_hub" and world.has_method("living_enemies"):
		var enemies: Array = world.call("living_enemies")
		var closest: Node2D
		for raw: Node2D in enemies:
			if is_instance_valid(raw) and not raw.is_queued_for_deletion() and (closest == null or actor.global_position.distance_squared_to(raw.global_position) < actor.global_position.distance_squared_to(closest.global_position)): closest = raw
		if is_instance_valid(closest): return _point(closest.global_position,"Hoàn tất mục tiêu sống trong tầng hiện tại; không chỉ tới thủ lĩnh / tầng chưa mở.",&"live_enemy")
	return _exit_goal(world)

func resolve() -> Dictionary:
	var id: StringName = tracked_id()
	if id == &"": return _fallback("idle","Chọn một nhiệm vụ để theo dõi đường đi.")
	var world: Node = world_ref.get_ref() as Node
	var actor: Node2D = player_ref.get_ref() as Node2D
	var journal: Node = journal_ref.get_ref() as Node
	if not is_instance_valid(world) or world.is_queued_for_deletion() or not is_instance_valid(actor) or not is_instance_valid(journal): return _fallback("world_missing","Vùng / nhân vật chưa sẵn sàng; mũi tên tạm dừng.")
	if profile == null or profile.read_only or profile.opening_progress_quarantined or profile.exterior_progress_quarantined: return _fallback("state_unavailable","Tiến triển chưa xác minh / hồ sơ đang khóa; không chỉ tới đích chưa hợp lệ.")
	var selected: Dictionary = {}
	for row: Dictionary in journal.get("rows"):
		if row["id"] == id: selected = row; break
	if selected.is_empty(): return _fallback("quest_missing","Nhiệm vụ theo dõi không còn trong danh sách hiện tại; chọn lại hoặc bỏ theo dõi.")
	if bool(selected.get("card",{}).get("complete",selected.get("done",false))):
		profile.set_meta(TRACKED,&"")
		return _fallback("complete","Nhiệm vụ đã hoàn tất; mũi tên đã dừng. Chọn nhiệm vụ tiếp theo nếu muốn.")
	if selected.get("card",{}).get("command",&"") == &"retry_insights": return _fallback("reward_pending","Dấu mốc đã ghi nhưng lĩnh ngộ còn chờ lưu; về căn cứ và dùng nút thử lưu lại trên thẻ nhiệm vụ.")
	if String(id).begins_with("sect_"): return _sect_goal(world,actor,String(id).trim_prefix("sect_"))
	var hub_goal: StringName
	match id:
		&"explored": hub_goal = &"exterior_road"
		&"golem_defeated": hub_goal = NpcCatalog.WANDERER if not profile.bounty_accepted or profile.boss_proofs.get(&"golem",0)-profile.bounty_start_proofs >= 1 else &"portal"
		&"thanh_vy_met",&"first_upgrade": hub_goal = NpcCatalog.HEALER
		&"cultivation_breakthrough": hub_goal = &"training"
		&"first_loop_next",&"prepare_next_run": hub_goal = &"portal"
		&"returned_to_hub": hub_goal = &"portal"
		&"reward_collected": return _dungeon_goal(world,actor,id) if world.has_method("living_enemies") else _fallback("loot_missing","Phần thưởng nằm trong hành trình; chưa có vật phẩm rơi để chỉ ở căn cứ.")
		_: return _outside(world,actor,selected.get("target",&"")) if bool(property(world,&"outside",false)) else _fallback("unsupported","Chưa có điểm tương tác đã xác minh cho nhiệm vụ này; xem phần Hành động / Địa điểm.")
	if bool(property(world,&"outside",false)): return _outside(world,actor,ExteriorRouteCatalog.HUB)
	if bool(property(world,&"inside_house",false)):
		var home: Node = property(world,&"house") as Node
		var exit: Node2D = property(home,&"exit_point") as Node2D
		return _point(exit.global_position,"Ra sân bằng cửa nhà, E tương tác; sau đó theo mũi tên tới mục tiêu.",&"home_exit") if is_instance_valid(exit) else _fallback("anchor_missing","Cửa ra sân chưa sẵn sàng.")
	if world.has_method("living_enemies"):
		if id == &"golem_defeated" and not profile.bounty_accepted: return _fallback("quest_gate","Chưa nhận lời hẹn trước thủ lĩnh. Khi tầng đã dọn, E ở lối ra → về sảnh để nhận lời Vô Danh; hạ trước không tính chứng tích nhiệm vụ.")
		if hub_goal == NpcCatalog.WANDERER: return _exit_goal(world)
		return _dungeon_goal(world,actor,id)
	return _station(world,hub_goal)

func _sect_goal(world: Node, actor: Node2D, faction_id: String) -> Dictionary:
	if faction_id not in SectRouteCatalog.FACTIONS: return _fallback("quest_missing","Nhiệm vụ môn phái không hợp lệ.")
	if world.has_method("living_enemies"): return _fallback("outside_goal","Nhiệm vụ môn phái nằm trên đường bộ. Trở về căn cứ để tiếp tục.")
	if bool(property(world,&"inside_house",false)):
		var home: Node=property(world,&"house") as Node
		var exit_point: Node2D=property(home,&"exit_point") as Node2D
		return _point(exit_point.global_position,"Ra sân bằng cửa nhà, E tương tác; sau đó tới lối đường bộ.",&"home_exit") if is_instance_valid(exit_point) else _fallback("anchor_missing","Cửa ra sân chưa sẵn sàng.")
	if not bool(property(world,&"outside",false)): return _station(world,&"exterior_road")
	var room: ExteriorRoom=property(world,&"exterior") as ExteriorRoom
	if not is_instance_valid(room): return _fallback("world_missing","Đường đi chưa sẵn sàng.")
	var stored: Dictionary=profile.extension_state(SectJourneyProgress.SCOPE)
	if not SectJourneyProgress.valid(stored): return _fallback("state_unavailable","Hồ sơ nhiệm vụ môn phái chưa sẵn sàng.")
	var entry: Dictionary=stored[faction_id]
	var target: StringName=SectRouteCatalog.first(faction_id)
	var key: StringName=&""
	if room.room_id==SectRouteCatalog.ROAD_ROOMS[faction_id]: key=&"sect_branch"
	elif room.room_id==target:
		key=&"sect_marker_west" if not entry["markers"].has("west") else &"sect_marker_east" if not entry["markers"].has("east") else &"sect_register"
	if key!=&"" and room.interactions.has(key): return _point(room.to_global(room.interactions[key]),"Đi theo mũi tên; E đọc mốc / sổ tiếp nhận, chọn xác nhận để lưu.",key)
	var known: Dictionary=MapQuestProjection.known_rooms(profile)
	return _outside(world,actor,target if known.has(target) else SectRouteCatalog.ROAD_ROOMS[faction_id])

func update_navigation() -> void:
	if world_ref == null: return
	state = resolve(); hide()
	var journal: Node = journal_ref.get_ref() as Node
	if is_instance_valid(journal): journal.call("present_navigation",tracked_id(),state["hint"])
	_place_arrow()

func _place_arrow() -> void:
	var actor: Node2D = player_ref.get_ref() as Node2D
	var screen: Node = screen_ref.get_ref() as Node
	var health: Object = property(actor,&"health")
	if state["status"] != "point" or not is_instance_valid(actor) or not is_instance_valid(screen) or bool(property(screen,&"is_open",true)) or not bool(property(actor,&"controls_enabled",false)) or not is_instance_valid(health) or float(property(health,&"current_health",0.0)) <= 0 or get_tree().paused: return
	var canvas: Transform2D = actor.get_global_transform_with_canvas()
	var point: Vector2 = canvas * actor.to_local(state["point"])
	var player_point: Vector2 = canvas.origin
	var bounds: Rect2 = get_viewport_rect()
	if not bounds.has_point(player_point): return
	position = (player_point+Vector2(0,-78)).clamp(Vector2(20,94),bounds.size-Vector2(48,40))
	direction = (point-player_point).normalized()
	arrived = actor.global_position.distance_to(state["point"]) <= 80.0
	show(); queue_redraw()

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0: update_navigation(); _remaining = .12
	else: _place_arrow()
	# Hide immediately when another modal/pause/death blocks play.
	var actor: Node2D = player_ref.get_ref() as Node2D if player_ref != null else null
	var screen: Node = screen_ref.get_ref() as Node if screen_ref != null else null
	if get_tree().paused or not bool(property(actor,&"controls_enabled",false)) or bool(property(screen,&"is_open",true)): hide()

func _draw() -> void:
	if arrived: draw_circle(Vector2(14,14),5,AntiqueSkin.JADE); return
	draw_set_transform(Vector2(14,14),direction.angle())
	draw_polyline(PackedVector2Array([Vector2(-6,-7),Vector2(7,0),Vector2(-6,7)]),Color(.06,.09,.1,.9),6,true)
	draw_polyline(PackedVector2Array([Vector2(-6,-7),Vector2(7,0),Vector2(-6,7)]),AntiqueSkin.WARM,3,true)

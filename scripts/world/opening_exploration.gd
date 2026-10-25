class_name OpeningExploration
extends Node
## Existing geometry/doors and profile owners; optional P03 landings only.
const CACHE: StringName=&"p03_recess_cache"
const LEDGES: Array[Rect2]=[Rect2(1840,1468.5,150,10),Rect2(2050,1418.5,260,10)]
const CACHE_POINT:=Vector2(2240,1418.5)
var hub: ExteriorHub
var progress:=OpeningExplorationProgress.new()
var cache_sprite: Sprite2D
var aftermath: Node2D
var scene_choice: String="unset"
var _pending: bool=false

func initialize(owner: ExteriorHub) -> void:
	hub=owner;progress.initialize(hub.profile)
	hub.profile.changed.connect(refresh)
	hub.zone_changed.connect(_zone)
	hub.dialogue.choice_selected.connect(_choice)
	hub.dialogue.closed.connect(_closed)
	(hub.gear.modal as InventoryScreen).journal.extension_rows_provider=journal_rows
	refresh()

static func author(room: ExteriorRoom) -> void:
	if room.room_id!=&"o01_p03" or room.route_id!=ExteriorRouteCatalog.MAIN:return
	for i: int in LEDGES.size():
		var body: StaticBody2D=room._solid(room._rect(LEDGES[i]),Color("b3a383"),true)
		body.name="RecessLanding%d"%i
		var brace:=Line2D.new();brace.points=PackedVector2Array([Vector2(LEDGES[i].position.x+22,room.floor_y(LEDGES[i].position.x+22)),LEDGES[i].position+Vector2(22,10),Vector2(LEDGES[i].end.x-18,LEDGES[i].position.y+10)])
		brace.width=5;brace.default_color=Color("746d5b");brace.z_index=-2;room.add_child(brace)
		var rim:=Line2D.new();rim.points=PackedVector2Array([LEDGES[i].position,Vector2(LEDGES[i].end.x,LEDGES[i].position.y)])
		rim.width=3;rim.default_color=Color("bdac7f");room.add_child(rim)
	room.interactions[CACHE]=CACHE_POINT
	# Warm exposed scratches are a visible clue, on the landings themselves.
	for p: Vector2 in [Vector2(1880,1468.5),Vector2(1940,1468.5),Vector2(2090,1418.5)]:
		var clue:=Line2D.new();clue.points=PackedVector2Array([p+Vector2(-8,-3),p+Vector2(2,-11),p+Vector2(9,-3)])
		clue.width=2;clue.default_color=Color("edc97b");room.add_child(clue)
	var chest:=Sprite2D.new();chest.name="RecessCache";chest.texture=preload("res://assets/environment/props/chest.png")
	chest.scale=Vector2.ONE*minf(48.0/chest.texture.get_width(),32.0/chest.texture.get_height())
	chest.position=CACHE_POINT-Vector2(0,chest.texture.get_height()*chest.scale.y*.5)
	room.add_child(chest)
	# Reuse the current room's painted terrain skin, before the normal attach.
	room._sign(Vector2(1810,room.floor_y(1810)),"Vệt vàng leo lên gờ đá",true)

func _zone(_id: StringName) -> void:
	_pending=false
	refresh()

func journal_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary]=hub.tan_dang.relation_rows()
	if not hub.profile.exterior_progress["discovered_rooms"].has("o01_p03"):return rows
	var claimed: bool=OpeningExplorationProgress.state_for(hub.profile)["cache_claimed"]
	var shortcut_line: String="SC01: cơ cấu đường giữ đèn đã mở." if OpeningExplorationProgress.shortcut_open(hub.profile) else "SC01: hoàn tất Trở về nhận phần mình sẽ mở cơ cấu của hành lang giữ đèn. Cũng có thể dùng cơ cấu P03 như trước."
	rows.append({"id":&"opening_exploration","title":"Dấu vệt vàng · Đường giữ đèn","body":"P03: những vệt vàng dẫn lên hai gờ đá ở phía đông miếu. Đường chính phía dưới vẫn thông; nhảy lên gờ thấp rồi tới hốc khô, có thể trở xuống hai phía.\n"+("Đã nhận 2 Bột Phép vào kho; rút về túi để dùng dịch vụ. Hộp không đầy lại." if claimed else "Một hộp vật tư cũ dùng được một lần cho save này; không cần NPC còn sống.")+"\n"+shortcut_line+" Đi qua cửa hầm ở P01/P03 rồi đi bộ xuyên cổng vật lý, thay cho đường chính P02 dài hơn.\nLựa chọn cứu/giữ và đời sống đã ghi vẫn giữ nguyên.","target":&"o01_p03","done":claimed,"next":false})
	return rows

func refresh() -> void:
	if hub.outside and is_instance_valid(hub.exterior):
		cache_sprite=hub.exterior.get_node_or_null("RecessCache") as Sprite2D
		if is_instance_valid(cache_sprite):cache_sprite.modulate=Color(.42,.42,.42) if OpeningExplorationProgress.state_for(hub.profile)["cache_claimed"] else Color.WHITE
		if hub.exterior.route_id==ExteriorRouteCatalog.TUNNEL:hub.exterior.set_gate(OpeningExplorationProgress.shortcut_open(hub.profile))
	var choice: String=TanDangProgress.state_for(hub.profile)["choice"]
	if scene_choice==choice:return
	scene_choice=choice
	if is_instance_valid(aftermath):aftermath.get_parent().remove_child(aftermath);aftermath.queue_free()
	aftermath=Node2D.new();aftermath.name="TanDangChoiceAftermath";aftermath.position=Vector2(1010,640);aftermath.z_index=-1;hub.yard.add_child(aftermath)
	if choice.is_empty():return
	# Purely decorative consequences. The required road stays identical.
	var timber:=Line2D.new();timber.width=7;timber.default_color=Color("80765f")
	timber.points=PackedVector2Array([Vector2(-24,-8),Vector2(26,-20),Vector2(40,-4)]) if choice=="rescue" else PackedVector2Array([Vector2(0,0),Vector2(0,-83),Vector2(22,-83)])
	aftermath.add_child(timber)
	var cloth:=Polygon2D.new();cloth.color=Color("6e8b7b") if choice=="gate" else Color("756a59")
	cloth.polygon=PackedVector2Array([Vector2(3,-78),Vector2(24,-78),Vector2(22,-40),Vector2(3,-48)]) if choice=="gate" else PackedVector2Array([Vector2(-20,-5),Vector2(5,-13),Vector2(18,-3),Vector2(-12,0)])
	aftermath.add_child(cloth)

func interact() -> bool:
	if not hub._can_travel() or not _at_cache():return false
	_pending=true
	hub._dialogue_previous_controls=hub.player.controls_enabled;hub.player.suspend_controls(true)
	(hub.gear.modal as InventoryScreen).open_button.hide();TimeScaleClaims.acquire(hub.dialogue,.1)
	var claimed: bool=OpeningExplorationProgress.state_for(hub.profile)["cache_claimed"]
	var choices: Array[Dictionary]=[{"id":&"explore_cache_claim","text":"Nhận 2 Bột Phép vào kho","enabled":progress.available() and not claimed,"requires_confirmation":true,"confirm_text":"Nhận vật liệu một lần cho save này. Bột Phép vào kho; rút về túi để dùng dịch vụ."},{"id":&"explore_cache_later","text":"Để lại"}]
	hub.dialogue.open("Hốc đá có vệt vàng",["Chiếc hộp cũ nằm trên gờ khô. Các vệt vàng dẫn từ lối chính tới đây.","Hộp đã được lấy; gờ đá vẫn dùng để quan sát và quay xuống đường." if claimed else "Còn hai phần Bột Phép dùng cho chế bùa, sửa trang bị hoặc tu luyện hiện có. Vào kho; rút về túi trước khi dùng. Không hồi lại khi rời phòng."],choices)
	return true

func _at_cache() -> bool:
	if not hub.outside or not is_instance_valid(hub.exterior) or hub.exterior.room_id!=&"o01_p03" or hub.exterior.route_id!=ExteriorRouteCatalog.MAIN or hub.nearest_station()!=CACHE or not hub.player.motor.is_grounded():return false
	var local: Vector2=hub.exterior.to_local(hub.player.global_position)
	return absf(local.y-CACHE_POINT.y)<=8 and local.x>=LEDGES[1].position.x and local.x<=LEDGES[1].end.x

func _closed() -> void:call_deferred("_clear_pending")
func _clear_pending() -> void:
	if not hub.dialogue.is_open:_pending=false

func _choice(id: StringName) -> void:
	if not _pending or id not in [&"explore_cache_claim",&"explore_cache_later"]:return
	_pending=false
	if id==&"explore_cache_claim" and hub._can_travel() and _at_cache():
		var result: Dictionary=progress.claim()
		hub.prompt.text="Đã cất 2 Bột Phép vào kho · chỉ một lần" if result.get("ok",false) else "Chưa xác minh việc nhận. Tải lại nếu cần khôi phục giao dịch."
	refresh()

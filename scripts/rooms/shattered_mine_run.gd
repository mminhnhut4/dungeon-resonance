extends DungeonRun
const MINE = preload("res://scripts/rooms/shattered_mine_room.gd")
const SUPPLY = preload("res://scripts/rooms/shattered_mine_supply.gd")
const EXIT = preload("res://scripts/rooms/shattered_mine_exit.gd")
var supply_cache: TreasureChest
var supply_claimed: bool = false
var route_hint: Label
var mine_title: Label
var _interaction_armed: bool = false

func _ready() -> void:
	# Direct scene launch is still isolated; the entry scene supplies its profile.
	if profile == null:
		profile = SanctuaryProfile.new()
		profile.save_path = "user://shattered-mine-prototype/profile.json"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile.save_path.get_base_dir()))
		profile.load_profile()
	super._ready()
	remove_child(floor_exit)
	floor_exit.queue_free()
	floor_exit = EXIT.new()
	add_child(floor_exit)
	floor_exit.initialize(self)
	# Sample encounter composition excludes random survival incidents.
	survival.set_enabled(false)
	var hud := CanvasLayer.new()
	hud.layer = 16
	add_child(hud)
	mine_title = _label(hud,Vector2(350,18),"MỎ LINH THẠCH VỠ · BẢN THỬ RIÊNG",20)
	mine_title.set_meta(&"debug_keep",true)
	mine_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_hint = _label(hud,Vector2(350,48),"",16)
	route_hint.set_meta(&"debug_keep",true)
	route_hint.size = Vector2(650,75)
	route_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	get_viewport().size_changed.connect(_layout_mine_hud)
	_layout_mine_hud()

func _layout_mine_hud() -> void:
	var width: float = maxf(180,get_viewport().get_visible_rect().size.x-444)
	mine_title.position = Vector2(420,18)
	mine_title.size = Vector2(width,48)
	mine_title.add_theme_font_size_override("font_size",18)
	route_hint.position = Vector2(420,70)
	route_hint.size = Vector2(width,110)
	route_hint.add_theme_font_size_override("font_size",14)

func enter_room(number: int) -> bool:
	if number != 1 or outcome != &"" or player.health.current_health <= 0 or is_instance_valid(room): return false
	if is_instance_valid(floor_exit) and floor_exit.is_open: floor_exit.close()
	gear.modal.close()
	content.close()
	survival.clear_room()
	feedback.reset_feedback()
	executor.clear_entities()
	gear.loot.clear()
	gear.loot.process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(room):
		remove_child(room)
		room.queue_free()
	room_number = 1
	wave = 1
	boss = null
	reward_chest = null
	portal_active = false
	portal_visual = null
	processed_deaths.clear()
	supply_claimed = false
	room = MINE.new()
	room.name = "ShatteredMineRoom"
	add_child(room)
	PlayerTravel.relocate(player,MINE.ENTRY,PlayerTravel.Kind.INTRA_EXPEDITION)
	player.controls_enabled = true
	var camera: Camera2D = player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_right = int(MINE.WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = 790
	_spawn_wave()
	supply_cache = SUPPLY.new()
	supply_cache.name = "ShatteredMineSupplyCache"
	supply_cache.player = player
	supply_cache.spawner = gear.loot
	supply_cache.position = MINE.SUPPLY
	supply_cache.opened.connect(func() -> void: supply_claimed = true)
	room.add_child(supply_cache)
	transition_pending = false
	presentation.rebuild(false)
	# Shared combat/actor presentation stays; fixed 1280px room paint is replaced.
	presentation.foyer_art.clear()
	presentation.atmosphere.room_art.hide()
	presentation.atmosphere.ambient.color = Color(0.68,0.73,0.78)
	return true

func _spawn_wave() -> void:
	for x: float in [2140.0,2420.0,2680.0]:
		_spawn_slime(Vector2(x,640))

func _check_clear() -> void:
	if outcome != &"" or not living_enemies().is_empty(): return
	var label: Label = room.get("lever_label") as Label
	label.text = "E · MỞ CẦU TẮT VỀ CỬA MỎ\nNhánh tiếp tế ở bên phải →"

func activate_shortcut() -> bool:
	if not _can_interact() or not living_enemies().is_empty() or player.global_position.distance_to(MINE.LEVER)>85:
		return false
	return bool(room.call("open_shortcut"))

func _can_interact() -> bool:
	return _interaction_armed and outcome == &"" and player.health.current_health>0 and player.controls_enabled and player.motor.is_grounded() and not gear.modal.is_open and not content.panel_open and not survival.panel.is_open and not (is_instance_valid(floor_exit) and floor_exit.is_open)

func can_choose_floor_exit() -> bool:
	# FloorExitPanel suspends controls while asking; accept its confirmed return.
	return _interaction_armed and outcome == &"" and not transition_pending and player.health.current_health>0 and not gear.modal.is_open and not content.panel_open and not survival.panel.is_open and player.global_position.distance_to(MINE.ENTRY)<85

func advance_room() -> bool:
	return false

func retry() -> void:
	if outcome == &"": return
	if world_building_enabled and save_retry_requested.has_connections():
		super.retry()
		return
	if is_instance_valid(room):
		remove_child(room)
		room.queue_free()
		room = null
	super.retry()

func _process(_delta: float) -> void:
	if gear == null: return
	# The Hub portal's E can still be held/just-pressed when this scene is added.
	# Observe a fully released frame before permitting a new interaction here.
	if not _interaction_armed and not Input.is_action_pressed(&"interact") and not Input.is_action_just_pressed(&"interact"):
		_interaction_armed = true
	hp_bar.value = player.health.current_health
	hp_bar.max_value = player.health.maximum_health
	energy_bar.value = player.energy.current
	boss_panel.hide()
	if route_hint != null:
		var remaining: int = living_enemies().size()
		route_hint.text = "A/D đi · Chuột trái đánh · Chuột phải bùa · E dùng · Tab túi\n" + ("Cầu tắt đã mở ← Cửa về. Nhánh tiếp tế →" if bool(room.get("shortcut_open")) else "Xuống lòng mỏ, lên dốc đông · Slime còn %d · Cần gạt phía đông" % remaining)
		if player.global_position.distance_to(MINE.LEVER)<110 and remaining>0:
			route_hint.text += "\nCầu chỉ mở khi đã dọn Slime; vẫn có thể đi bộ về theo dốc."
	if _can_interact() and Input.is_action_just_pressed(&"interact"):
		if can_choose_floor_exit(): floor_exit.open()
		elif player.global_position.distance_to(MINE.LEVER)<85: activate_shortcut()

func finish(result: StringName) -> void:
	super.finish(result)
	if result == &"defeat": end_title.text = "Gục ngã trong mỏ"

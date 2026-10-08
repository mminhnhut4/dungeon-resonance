class_name PrologueHub
extends Node2D
## Safe preparation world: existing combat, equipment and room-owned presentation.

signal run_requested
signal campaign_requested
signal interaction_requested(station_id: StringName, hub: PrologueHub)
signal zone_changed(zone_id: StringName)
signal smith_requested(hub: PrologueHub)
signal permanent_upgrade_requested(id: StringName, hub: PrologueHub)
signal bounty_requested(id: StringName, hub: PrologueHub)

const RARE_SWORD: EquipmentData = preload("res://data/equipment/test_rare_lightning_sword.tres")
const KAEL: Texture2D = preload("res://assets/sprites/npc/npc_merchant_kael.png")
const YARD_WIDTH: float = 2400.0
const HOUSE_ORIGIN: Vector2 = Vector2(3200, 0)
const INTERACTION_RANGE: float = 85.0
var cultivation_session: Node
var profile: SanctuaryProfile
var from_defeat: bool = false
var session_state: Dictionary = {}
var world_building_enabled: bool = false
## The sample chest belongs to explicitly enabled QA fixtures, never progression.
@export var qa_tools_enabled: bool = false
var player: Player
var gear: GearSession
var feedback: CombatFeedback
var executor: SpellExecutor
var presentation: SlicePresentation
var safety: SafeHubComponent
var condition: BodyConditionComponent
var economy: EconomySession
var rune_learning: RuneLearningService
var courier: CourierOpportunity
var dummy: TrainingDummy
var training_slime: HubTrainingSlime
var damage_numbers: DamageNumberSpawner
var training_aggression: bool = false
var house: PlayerHome
var inside_house: bool = false
var yard: Node2D
var stations: Dictionary[StringName, Marker2D] = {}
var test_chest: TreasureChest
var station_title: Label
var station_caption: Label
var _station_heading_set: bool = false
var station_panel: PanelContainer
var station_content: ServiceItemGrid
var station_scroll: ScrollContainer
var station_close: Button
var station_open: bool = false
var current_station: StringName = &""
var prompt: Label
var summary: Label
var _previous_controls: bool = true
var _slime_respawn_remaining: float = -1.0
var npcs: Dictionary[StringName, HubNpc] = {}
var npc_portraits: Dictionary[StringName, Texture2D] = {}
var dialogue: DialogueBox
var current_npc: StringName = &""
var _dialogue_previous_controls: bool = true
var station_notice: String = ""
var _pending_sale_uid: int = 0
var _pending_purchase: Dictionary = {}
var _purchase_serial: int = 0
var _upgrade_offers: Dictionary = {}
var forge_rng := RandomNumberGenerator.new()

func _ready() -> void:
	forge_rng.randomize()
	if profile == null:
		profile = SanctuaryProfile.new()
		profile.load_profile()
	yard = Node2D.new()
	yard.name = "Yard"
	add_child(yard)
	_build_yard()
	house = preload("res://scenes/hub/player_home.tscn").instantiate() as PlayerHome
	house.position = HOUSE_ORIGIN
	add_child(house)
	house.hide()
	player = preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	player.position = Vector2(430, 640)
	add_child(player)
	feedback = CombatFeedback.new()
	feedback.name = "CombatFeedback"
	add_child(feedback)
	player.combat_feedback = feedback
	player.equipped_weapon.hit_confirmed.connect(feedback.on_hit_confirmed)
	player.hurtbox.damage_resolver.status_controller.combat_feedback = feedback
	executor = SpellExecutor.new()
	executor.name = "SpellExecutor"
	executor.projectile_scene = preload("res://scenes/projectiles/spell_projectile.tscn")
	executor.firestorm_scene = preload("res://scenes/effects/firestorm_effect.tscn")
	executor.combat_feedback = feedback
	add_child(executor)
	player.resonance_controller.initialize(player, executor, feedback)
	gear = GearSession.new()
	gear.name = "GearSession"
	add_child(gear)
	var carried: GearInventory = session_state.get(&"inventory") as GearInventory
	if carried == null or carried.items.is_empty():
		carried = HubPreparation.starter_inventory(profile if world_building_enabled else null)
		session_state[&"inventory"] = carried
	gear.initialize(player, feedback, self, false, carried)
	gear.allow_interaction = false
	player.gear_switch_enabled = false # Preparation uses the real click-to-equip UI.
	player.health.reset_health()
	player.energy.reset()
	safety = SafeHubComponent.new()
	add_child(safety)
	safety.initialize(player.health)
	condition = BodyConditionComponent.new()
	condition.name = "BodyConditionComponent"
	condition.actor = player
	condition.feedback = feedback
	condition.enabled = false # Quiet Hub does not create wounds or mental breaks.
	player.add_child(condition)
	economy = EconomySession.new()
	economy.initialize(profile, gear.inventory)
	rune_learning = RuneLearningService.new()
	rune_learning.initialize(economy)
	if world_building_enabled:
		courier = OpeningCourierRuntime.new()
		courier.initialize(profile, profile)
	economy.changed.connect(refresh_summary)
	profile.changed.connect(refresh_summary)
	damage_numbers = DamageNumberSpawner.new()
	damage_numbers.name = "DamageNumberSpawner"
	add_child(damage_numbers)
	dummy = preload("res://scenes/training_dummy.tscn").instantiate() as TrainingDummy
	dummy.position = Vector2(620, 640)
	dummy.combat_feedback = feedback
	dummy.damage_number_spawner = damage_numbers
	yard.add_child(dummy)
	dummy.hurtbox.damage_resolver.status_controller.combat_feedback = feedback
	_spawn_slime()
	if qa_tools_enabled:
		test_chest = TreasureChest.new()
		test_chest.player = player
		test_chest.spawner = gear.loot
		test_chest.locked = true # QA grants exact demo items, no RNG loot.
		test_chest.position = stations[&"test_chest"].position
		test_chest.is_open = bool(session_state.get(&"test_chest_claimed", false))
		yard.add_child(test_chest)
	_build_ui()
	if cultivation_session!=null: cultivation_session.ui_changed.connect(_cultivation_ui_changed)
	presentation = SlicePresentation.new()
	presentation.name = "SlicePresentation"
	add_child(presentation)
	presentation.initialize(self, player, feedback, executor)
	presentation.rebuild()
	# Yard lighting/art stays behind an adapter; approved Hub art can replace it.
	presentation.atmosphere.ambient.color = Color(0.70, 0.76, 0.80)
	_set_camera_bounds(false)
	refresh_summary()
	_build_npcs()
	var router := Node.new()
	router.name = "PrologueInputRouter"
	router.set_script(preload("res://scripts/hub/prologue_input_router.gd"))
	router.set("hub", self)
	add_child(router)

func _build_npcs() -> void:
	var placements: Dictionary[StringName, Vector2] = {
		NpcCatalog.SMITH: Vector2(2050, 640),
		NpcCatalog.HEALER: Vector2(1550, 640),
		NpcCatalog.WANDERER: Vector2(2290, 640),
	}
	for id: StringName in placements:
		if not world_building_enabled: continue
		_station(id, placements[id], "%s · Phác thảo NPC" % NpcCatalog.NAMES[id])
		var actor := HubNpc.new()
		actor.npc_id = id
		actor.name = String(id).to_pascal_case()
		var portrait_path: String = "res://assets/sprites/npc/regions/%s.tres" % {NpcCatalog.SMITH: "thiet_lao", NpcCatalog.HEALER: "thanh_vy", NpcCatalog.WANDERER: "vo_danh"}[id]
		if ResourceLoader.exists(portrait_path):
			actor.set_approved_portrait(load(portrait_path) as Texture2D)
			(stations[id].get_child(0) as Label).text = NpcCatalog.NAMES[id]
		stations[id].add_child(actor)
		npcs[id] = actor
		if actor.portrait != null and not actor.alpha_geometry.is_empty():
			var bounds: Rect2i = actor.alpha_geometry["bounds"]
			var cropped := AtlasTexture.new()
			cropped.atlas = actor.portrait
			cropped.region = Rect2(bounds.position, Vector2(bounds.size.x, bounds.size.y * 0.48))
			cropped.filter_clip = true
			npc_portraits[id] = cropped
	dialogue = preload("res://scenes/ui/dialogue_box.tscn").instantiate() as DialogueBox
	dialogue.auto_input = false # The last Hub router keeps this ahead of Inventory.
	add_child(dialogue)
	dialogue.closed.connect(_dialogue_closed)
	dialogue.choice_selected.connect(_dialogue_choice)

func open_npc(id: StringName, extra_line: String = "", courier_detail: bool = false) -> bool:
	if not npcs.has(id) or station_open or gear.modal.is_open or dialogue.is_open:
		return false
	if world_building_enabled and id == NpcCatalog.HEALER:
		profile.record_opening_event(&"thanh_vy_met")
	current_npc = id
	_dialogue_previous_controls = player.controls_enabled
	player.suspend_controls(true)
	TimeScaleClaims.acquire(dialogue, 0.1)
	(gear.modal as InventoryScreen).open_button.hide()
	var lines: Array[String] = NpcCatalog.dialogue(id)
	if id == NpcCatalog.HEALER: lines.append("Đang có %d Tàn Hồn. Tịnh hóa dùng Tàn Hồn; mua thuốc dùng Linh Thạch." % profile.souls)
	if extra_line != "": lines.append(extra_line)
	if courier != null and id == NpcCatalog.HEALER:
		courier.arm(&"healer")
		if courier_detail: lines.append_array(courier.lines(&"healer"))
	dialogue.open(NpcCatalog.NAMES[id], lines, _npc_choices(id, courier_detail), npc_portraits.get(id) as Texture2D)
	return true

func _economy_quote(method: StringName, id: StringName) -> Dictionary:
	if not economy.has_method(method): return {}
	var result: Variant = economy.call(method, id)
	return result if result is Dictionary else {}

func _npc_choices(id: StringName, courier_detail: bool = false) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	_upgrade_offers.clear()
	if courier_detail and courier != null and id == NpcCatalog.HEALER:
		choices.append_array(courier.choices(&"healer"))
		choices.append({"id": &"goodbye", "text": "Để sau · Tiếp tục hành trình"})
		return choices
	match id:
		NpcCatalog.SMITH:
			choices.append({"id": &"smith_repair", "text": "Sửa trang bị bằng vật liệu trong kho"})
			choices.append({"id": &"smith_forge", "text": "Tra cứu bản chế tạo và đúc trang bị"})
			choices.append({"id": &"smith_enhance", "text": "Cường hóa trang bị · +0 đến +12 · Thành công 100%"})
			choices.append({"id": &"smith_stones", "text": "Ghép Đá Cường Hóa · 5 viên cùng cấp thành 1 viên cấp sau"})
		NpcCatalog.HEALER:
			var names: Dictionary[StringName, String] = {&"max_hp": "Tịnh hóa thể chất · Máu tối đa", &"max_mana": "Dưỡng thần · Mana tối đa", &"mana_regen": "Điều tức · Hồi năng lượng", &"rune_capacity": "Khai mạch · Ô bùa Catalyst"}
			for upgrade_id: StringName in WorldProgressionCatalog.UPGRADES:
				var quote: Dictionary = _economy_quote(&"quote_upgrade", upgrade_id)
				var upgrade_name: String = names.get(upgrade_id,String(upgrade_id))
				var value: float = float(quote.get("value", 0))
				var next_value: float = value + float(WorldProgressionCatalog.VALUES.get(upgrade_id,0))
				var text: String = "%s · +%.0f → +%.0f %s · %d Tàn Hồn" % [upgrade_name, value, next_value, quote.get("unit", ""), quote.get("cost", 0)]
				text += " · Đang có %d Tàn Hồn · Thiếu %d" % [profile.souls, maxi(0, int(quote.get("cost", 0)) - profile.souls)]
				if quote.get("level", 0) >= quote.get("max_level", 0): text = "%s · Đã đạt giới hạn" % upgrade_name
				_upgrade_offers[upgrade_id] = {"level":quote.get("level",0),"cost":quote.get("cost",0)}
				choices.append({"id": StringName("upgrade_" + String(upgrade_id)), "text": text, "enabled": quote.get("can_buy", false), "requires_confirmation":true, "confirm_text":"%s\nGiá: %d Tàn Hồn. Sau khi mua còn %d Tàn Hồn.\nXác nhận tịnh hóa?" % [upgrade_name,int(quote.get("cost",0)),maxi(0,profile.souls-int(quote.get("cost",0)))]})
			choices.append({"id": &"healer_consumables", "text": "Mua thuốc và chế thuốc, băng gạc, thuốc giải độc"})
			choices.append({"id": &"rune_learning", "text": "Học & chế bùa · Học vĩnh viễn, nhận 1 bùa Thường"})
			if courier != null: choices.append({"id": &"courier_open", "text": "Hỏi việc đưa vật tư · Phiếu tiếp tế tùy chọn"})
		NpcCatalog.WANDERER:
			var quote: Dictionary = _economy_quote(&"quote_bounty", &"golem_hunt")
			choices.append({"id": &"bounty_accept", "text": "Nhận lời · Hạ Golem Cổ Bảo ở Tầng 4", "enabled": quote.get("can_accept", false)})
			choices.append({"id": &"bounty_claim", "text": "Báo tin hạ Golem · Nhận biến thể combo", "enabled": quote.get("can_claim", false)})
			if quote.get("can_reclaim", false): choices.append({"id": &"bounty_relearn", "text": "Luyện lại liên thức trên kiếm khởi đầu", "enabled": true})
	choices.append({"id": &"goodbye", "text": "Cáo từ"})
	return choices

func _dialogue_closed() -> void:
	TimeScaleClaims.release(dialogue)
	player.suspend_controls(not _dialogue_previous_controls)
	(gear.modal as InventoryScreen).open_button.show()
	current_npc = &""
	call_deferred("_clear_courier_context")

func _clear_courier_context() -> void:
	if courier != null and not dialogue.is_open: courier.arm(&"")

func _dialogue_choice(id: StringName) -> void:
	if String(id).begins_with("courier_"):
		if courier != null and courier.context == &"healer":
			if id == &"courier_open":
				open_npc(NpcCatalog.HEALER, "", true)
				return
			var response: Dictionary = courier.apply_action(id)
			if response["handled"]: open_npc(NpcCatalog.HEALER, response["message"], true)
		return
	if id == &"smith_repair":
		smith_requested.emit(self)
		open_station(&"blacksmith")
	elif id == &"smith_forge":
		smith_requested.emit(self)
		open_station(&"smith_forge")
	elif id in [&"smith_enhance", &"smith_stones"]:
		smith_requested.emit(self)
		open_station(id)
	elif id in [&"healer_consumables", &"rune_learning"]:
		open_station(id)
	elif String(id).begins_with("upgrade_"):
		var upgrade_id := StringName(String(id).trim_prefix("upgrade_"))
		var offered: Dictionary = _upgrade_offers.get(upgrade_id,{})
		_upgrade_offers.clear()
		var current: Dictionary = _economy_quote(&"quote_upgrade",upgrade_id)
		if offered.is_empty() or not current.get("can_buy",false) or current.get("level") != offered.get("level") or current.get("cost") != offered.get("cost") or profile.read_only:
			open_npc(NpcCatalog.HEALER,"Điều kiện hoặc giá đã thay đổi. Chưa trừ Tàn Hồn; hãy chọn lại nâng cấp.")
			return
		permanent_upgrade_requested.emit(upgrade_id, self)
		var success: bool = economy.has_method(&"buy_upgrade") and bool(economy.call(&"buy_upgrade", upgrade_id))
		open_npc(NpcCatalog.HEALER, "Tịnh hóa hoàn tất. Tiến triển được giữ sau khi chết." if success else "Chưa thể tịnh hóa: kiểm tra Tàn Hồn hoặc trạng thái lưu dữ liệu.")
	elif id in [&"bounty_accept", &"bounty_claim", &"bounty_relearn"]:
		bounty_requested.emit(&"golem_hunt", self)
		var method: StringName = &"accept_bounty" if id == &"bounty_accept" else &"reclaim_bounty_moveset" if id == &"bounty_relearn" else &"claim_bounty"
		var success: bool = economy.has_method(method) and bool(economy.call(method, &"golem_hunt"))
		var message: String = "Lời hẹn đã được ghi lại. Hạ Golem rồi quay về gặp ta." if id == &"bounty_accept" else "Biến thể combo đã được ghi lại. Hãy luyện nó trên mộc nhân trước khi vào ải."
		open_npc(NpcCatalog.WANDERER, message if success else "Chưa thể hoàn tất: kiểm tra chứng tích hoặc trạng thái lưu dữ liệu.")

func _build_yard() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.name = "YardFloor"
	floor_body.position = Vector2(YARD_WIDTH * 0.5, 680)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(YARD_WIDTH, 80)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-1200, -40), Vector2(1200, -40), Vector2(1200, 40), Vector2(-1200, 40)])
	visual.color = Color(0.28, 0.31, 0.27)
	floor_body.add_child(visual)
	yard.add_child(floor_body)
	for x: float in [-20.0, YARD_WIDTH + 20.0]:
		var boundary := StaticBody2D.new()
		boundary.position = Vector2(x, 350)
		var boundary_shape := RectangleShape2D.new()
		boundary_shape.size = Vector2(40, 700)
		var boundary_collision := CollisionShape2D.new()
		boundary_collision.shape = boundary_shape
		boundary.add_child(boundary_collision)
		yard.add_child(boundary)
	_station(&"training", Vector2(210, 640), "SÂN LUYỆN")
	if qa_tools_enabled: _station(&"test_chest", Vector2(980, 640), "RƯƠNG ĐỒ THỬ")
	_station(&"house", Vector2(1210, 640), "NHÀ LỮ KHÁCH")
	_station(&"stash", Vector2(1440, 640), "KHO CĂN CỨ")
	_station(&"merchant", Vector2(1760, 640), "KAEL · THƯƠNG NHÂN")
	_station(&"blacksmith", Vector2(1980, 640), "THỢ RÈN · SỬA TRANG BỊ")
	_station(&"portal", Vector2(2210, 640), "CỔNG VÀO HẦM NGỤC")
	var kael := Sprite2D.new()
	kael.name = "KaelSprite"
	kael.texture = KAEL
	kael.centered = false
	kael.scale = Vector2.ONE * (80.0 / KAEL.get_height())
	kael.position = stations[&"merchant"].position + Vector2(-40, -80)
	yard.add_child(kael)
	var table := Polygon2D.new()
	table.name = "KaelStoneTable"
	table.position = Vector2(1840, 640)
	table.polygon = PackedVector2Array([Vector2(-40, 0), Vector2(-40, -20), Vector2(40, -20), Vector2(40, 0)])
	table.color = Color(0.43, 0.48, 0.44)
	yard.add_child(table)

func _station(id: StringName, location: Vector2, caption: String) -> void:
	var marker := Marker2D.new()
	marker.name = String(id).to_pascal_case() + "Station"
	marker.position = location
	yard.add_child(marker)
	stations[id] = marker
	var label := Label.new()
	label.text = caption
	label.position = Vector2(-90, -95)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta(&"debug_keep", true)
	marker.add_child(label)

func _spawn_slime() -> void:
	training_slime = preload("res://scenes/hub/training_slime.tscn").instantiate() as HubTrainingSlime
	training_slime.position = Vector2(270, 640)
	training_slime.patrol_speed = 25.0
	training_slime.chase_speed = 65.0
	training_slime.telegraph_seconds = 0.45
	training_slime.aggro_radius = 160.0
	training_slime.combat_feedback = feedback
	training_slime.damage_number_spawner = damage_numbers
	yard.add_child(training_slime)
	training_slime.statuses.combat_feedback = feedback
	training_slime.health.died.connect(_training_slime_died)
	set_training_aggression(training_aggression)

func _training_slime_died() -> void:
	_slime_respawn_remaining = 1.2

func set_training_aggression(enabled: bool) -> void:
	training_aggression = enabled
	if is_instance_valid(training_slime) and training_slime.health.current_health > 0.0:
		training_slime.player = player if enabled and not inside_house else null
		training_slime.contact_damage_enabled = enabled and not inside_house
		if not enabled or inside_house:
			training_slime.bite_hitbox.deactivate()
			if training_slime.state_machine.get_state_id() == &"attack":
				training_slime.state_machine.transition_to(&"patrol")

func claim_test_chest() -> bool:
	if not qa_tools_enabled or not is_instance_valid(test_chest): return false
	if bool(session_state.get(&"test_chest_claimed", false)) or gear.inventory.equipment_bag_uids().size() + 8 > GearInventory.EQUIPMENT_BAG_CAPACITY:
		return false
	for definition: EquipmentData in GearInventory.STARTER_CLOTHING:
		gear.inventory.add_equipment(definition)
	gear.inventory.add_equipment(GearInventory.COMMON_SWORD)
	gear.inventory.add_equipment(RARE_SWORD, GearItem.Quality.RARE)
	for id: StringName in [&"fire", &"wind", &"lightning"]:
		gear.inventory.add_rune(id)
	session_state[&"test_chest_claimed"] = true
	test_chest.is_open = true
	test_chest._update_label()
	return true

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HubUI"
	canvas.layer = 20
	add_child(canvas)
	summary = _label(canvas, Vector2(440, 25), "")
	prompt = _label(canvas, Vector2(400, 665), "")
	station_panel = PanelContainer.new()
	AntiqueSkin.apply_panel(station_panel)
	canvas.add_child(station_panel)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	station_panel.add_child(shell)
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", AntiqueSkin.texture_style(AntiqueSkin.HEADER, 18, 12))
	shell.add_child(header)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 3)
	header.add_child(heading)
	station_title = DungeonUI.label("", 23, AntiqueSkin.WARM)
	heading.add_child(station_title)
	station_caption = DungeonUI.label("", 14, AntiqueSkin.TEXT)
	heading.add_child(station_caption)
	shell.add_child(AntiqueSkin.divider())
	station_scroll = ScrollContainer.new()
	station_scroll.name = "StationScroll"
	station_scroll.follow_focus = true
	station_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	station_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	station_scroll.get_v_scroll_bar().custom_minimum_size.x = 12.0
	station_scroll.custom_minimum_size.y = 72.0
	station_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(station_scroll)
	station_content = ServiceItemGrid.new()
	station_content.right_inset = 14.0 # Reserve the 12px overlay scroll thumb and a small gap.
	station_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	station_scroll.add_child(station_content)
	station_close = Button.new()
	station_close.name = "CloseStation"
	station_close.text = "Tiếp tục · E / Tab"
	station_close.custom_minimum_size.y = 44.0
	station_close.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	station_close.pressed.connect(close_station)
	station_content.footer_focus = station_close
	shell.add_child(station_close)
	get_viewport().size_changed.connect(_resize_station_panel)
	_resize_station_panel()
	station_panel.hide()

func _label(parent_node: Node, location: Vector2, text: String) -> Label:
	if parent_node == station_content and not _station_heading_set:
		_station_heading_set = true
		_set_station_heading(text)
		return station_title
	var label := Label.new()
	label.position = location
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta(&"debug_keep", true)
	if parent_node == station_content:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent_node.add_child(label)
	return label

func refresh_summary() -> void:
	if summary != null:
		summary.text = "CĂN CỨ LỮ KHÁCH · Khu an toàn\nLinh Thạch %d · Tàn Hồn %d · Tab: Hành trang" % [profile.coins, profile.souls]

func nearest_station() -> StringName:
	if cultivation_session!=null and cultivation_session.herb_near(INTERACTION_RANGE): return &"aptitude_herb"
	if inside_house:
		if player.global_position.distance_to(house.exit_point.global_position) <= INTERACTION_RANGE:
			return &"home_exit"
		if player.global_position.distance_to(house.bed_point.global_position) <= INTERACTION_RANGE:
			return &"bed"
		return &""
	var nearest: StringName = &""
	var distance: float = INTERACTION_RANGE
	for id: StringName in stations:
		var next: float = player.global_position.distance_to(stations[id].global_position)
		if next < distance:
			distance = next
			nearest = id
	return nearest

func interact_station(id: StringName) -> bool:
	if gear.modal.is_open or station_open or dialogue.is_open or not player.controls_enabled or (player.hit_reaction != null and player.hit_reaction.blocks_controls()):
		return false
	if id != nearest_station():
		return false
	if id==&"aptitude_herb": return cultivation_session!=null and cultivation_session.harvest_near()
	interaction_requested.emit(id, self)
	if npcs.has(id): return open_npc(id)
	match id:
		&"house": return enter_house()
		&"home_exit": return leave_house()
		&"bed":
			condition.clear()
			player.health.heal(player.health.maximum_health)
			player.energy.reset()
			return true
		&"portal":
			campaign_requested.emit()
			return true
		&"training", &"test_chest", &"stash", &"merchant", &"blacksmith":
			open_station(id)
			return true
	return false

func open_station(id: StringName) -> void:
	if id == &"test_chest" and not qa_tools_enabled: return
	if station_open or gear.modal.is_open or dialogue.is_open:
		return
	station_open = true
	current_station = id
	station_notice = ""
	_pending_sale_uid = 0
	_pending_purchase.clear()
	_previous_controls = player.controls_enabled
	player.suspend_controls(true)
	TimeScaleClaims.acquire(self, 0.1)
	station_panel.show()
	(gear.modal as InventoryScreen).open_button.hide()
	_refresh_station()
	_resize_station_panel()

func close_station() -> void:
	if not station_open:
		return
	station_open = false
	_pending_sale_uid = 0
	_pending_purchase.clear()
	current_station = &""
	TimeScaleClaims.release(self)
	player.suspend_controls(not _previous_controls)
	station_panel.hide()
	(gear.modal as InventoryScreen).open_button.show()

func _refresh_station() -> void:
	_station_heading_set = false
	station_content.columns = 2 if current_station in [&"stash", &"merchant"] else 1
	for node: Node in station_content.get_children():
		station_content.remove_child(node)
		node.queue_free()
	if not _pending_purchase.is_empty():
		_build_purchase_confirmation()
		station_scroll.scroll_vertical = 0
		_resize_station_panel.call_deferred()
		return
	match current_station:
		&"training":
			_label(station_content, Vector2.ZERO, "SÂN LUYỆN · Không thể chết tại căn cứ\nMộc nhân đo sát thương; Slime cắn nhẹ để thử Hurt.")
			_button("Slime: %s" % ("Đang tấn công" if training_aggression else "Hiền · bật tấn công"), _toggle_training)
			if cultivation_session!=null: preload("res://scripts/cultivation/opening_cultivation_panel.gd").build(self,cultivation_session,station_content)
		&"test_chest":
			_label(station_content, Vector2.ZERO, "RƯƠNG ĐỒ THỬ · Một lần mỗi phiên\nĐủ 7 ô, kiếm Thường và kiếm Lôi Hiếm.\nNhận rồi mở Tab để click thay đồ và lắp bùa.")
			_button("Đã nhận bộ thử" if session_state.get(&"test_chest_claimed", false) else "Nhận bộ trang bị thử", _claim_chest)
		&"stash":
			_build_stash_menu()
		&"merchant":
			_label(station_content, Vector2.ZERO, "KAEL · THƯƠNG NHÂN · Linh Thạch %d" % profile.coins)
			_build_sale_menu()
			if world_building_enabled: _build_trader_stock()
		&"blacksmith":
			_label(station_content, Vector2.ZERO, "THỢ RÈN · SỬA TRANG BỊ\nDùng vật liệu trong kho; giữ nguyên UID và thuộc tính đã rơi.")
			var found: bool = false
			for item: GearItem in gear.inventory.items.values():
				if not item.broken:
					continue
				found = true
				var quote: Dictionary = economy.quote_repair(item.uid)
				var name_text: String = item.equipment_definition.item_name if item.equipment_definition != null else String(item.definition_id)
				if quote["requires_forging"]:
					var blank: Button = _item_card(ItemArtCatalog.gear_icon(item), name_text, "Phôi cần công thức và rèn; chưa thể sửa để dùng.", GearItem.NAMES[item.quality], "Cần đúc", Callable())
					blank.disabled = true
				else:
					var repair: Button = _item_card(ItemArtCatalog.gear_icon(item), name_text, "%d Kim Loại + %d Bột Phép" % [quote["metal"], quote["dust"]], "%s · Hỏng" % GearItem.NAMES[item.quality], "Sửa", _repair_item.bind(item.uid))
					repair.disabled = not quote["can_repair"]
			if not found:
				_label(station_content, Vector2.ZERO, "Chưa có trang bị hỏng cần sửa.")
		&"smith_forge":
			_build_forge_menu()
		&"smith_enhance":
			_build_enhancement_menu()
		&"smith_stones":
			_build_stone_menu()
		&"healer_consumables":
			_build_consumable_menu()
		&"rune_learning":
			_build_rune_learning_menu()
	if station_notice != "": _label(station_content, Vector2.ZERO, station_notice)
	station_scroll.scroll_vertical = 0
	_resize_station_panel.call_deferred()

func _build_stash_menu() -> void:
	_label(station_content, Vector2.ZERO, "KHO CĂN CỨ · Đồ gửi kho được giữ khi chết")
	var stored: bool = false
	for id: StringName in MaterialCatalog.IDS:
		var count: int = profile.material_stash.get(id, 0)
		if count <= 0: continue
		stored = true
		var capability: Dictionary = economy.material_capability(id)
		var transferable: bool = bool(capability.get("ordinary_transfer", false))
		var description: String = AntiqueSkin.item_description(id) if transferable else "Vật liệu có nguồn riêng; không thể rút bằng giao dịch vật liệu thường."
		var withdraw: Button = _item_card(ItemArtCatalog.icon(id), MaterialCatalog.DISPLAY_NAMES[id], description, "Trong kho %d" % count, "Rút 1" if transferable else "Chỉ hiển thị", _withdraw.bind(id) if transferable else Callable())
		withdraw.disabled = not capability.get("can_withdraw", false)
		withdraw.name = "WithdrawMaterial_" + String(id)
	if not stored:
		var empty: Label = _label(station_content, Vector2.ZERO, "Kho rỗng")
		empty.name = "StashEmpty"
	_label(station_content, Vector2.ZERO, "VẬT LIỆU ĐANG MANG · Chọn món để cất vào kho")
	var carried: bool = false
	var can_all: bool = true
	for id: StringName in MaterialCatalog.IDS:
		var count: int = gear.inventory.materials.get(id, 0)
		if count <= 0: continue
		carried = true
		var capability: Dictionary = economy.material_capability(id, count)
		can_all = can_all and bool(capability.get("can_deposit", false))
		var deposit: Button = _item_card(ItemArtCatalog.icon(id), MaterialCatalog.DISPLAY_NAMES[id], "Vật liệu trong hành trang; chưa nằm trong kho.", "Đang mang %d" % count, "Cất 1", _deposit.bind(id))
		deposit.name = "DepositMaterial_" + String(id)
		deposit.disabled = not economy.material_capability(id).get("can_deposit", false)
		if capability.get("lineage_bound", false): deposit.tooltip_text = "Vật liệu có nguồn riêng được quản lý qua bảng tu luyện."
	if not carried: _label(station_content, Vector2.ZERO, "Không có vật liệu đang mang để cất.")
	var all_button: Button = _button("Cất toàn bộ vật liệu đang mang", _deposit_all)
	all_button.name = "DepositAllMaterials"
	all_button.disabled = not carried or not can_all

func _build_sale_menu() -> void:
	_label(station_content, Vector2.ZERO, "BÁN TỪ HÀNH TRANG · Giá và số lượng được kiểm tra khi xác nhận")
	var found: bool = false
	for id: StringName in MaterialCatalog.SELL_PRICES:
		var quote: Dictionary = economy.quote_bag_material_sale(id)
		if quote["owned"] <= 0: continue
		found = true
		var sell: Button = _item_card(ItemArtCatalog.icon(id), MaterialCatalog.DISPLAY_NAMES[id], "Giá %d Linh Thạch / món" % quote["unit_price"], "Trong túi %d · Bán 1 nhận %d Linh Thạch" % [quote["owned"], quote["total"]], "Bán 1", _sell_bag_material.bind(id))
		sell.name = "SellBagMaterial_" + String(id)
		sell.disabled = not quote["can_sell"]
	for uid: int in gear.inventory.equipment_bag_uids():
		var quote: Dictionary = economy.quote_bag_equipment_sale(uid)
		if not quote["eligible"]: continue
		found = true
		var item: GearItem = gear.inventory.items[uid]
		var sell: Button = _item_card(ItemArtCatalog.gear_icon(item), ItemArtCatalog.gear_name(item), "%s · Giá bán sơ bộ %d Linh Thạch" % [GearItem.NAMES[item.quality], quote["total"]], "Hành trang · 1 món", "Chọn bán", _request_gear_sale.bind(uid))
		sell.name = "SellBagEquipment_%d" % uid
		sell.disabled = not quote["can_sell"]
	if not found: _label(station_content, Vector2.ZERO, "Chưa có món phù hợp để bán từ hành trang.")
	if _pending_sale_uid != 0:
		var quote: Dictionary = economy.quote_bag_equipment_sale(_pending_sale_uid)
		if quote["can_sell"]:
			var item: GearItem = gear.inventory.items[_pending_sale_uid]
			_label(station_content, Vector2.ZERO, "Bán 1 %s, nhận %d Linh Thạch? Trang bị sẽ rời hành trang." % [ItemArtCatalog.gear_name(item), quote["total"]])
			var confirm: Button = _button("Xác nhận bán · %d Linh Thạch" % quote["total"], _sell_bag_equipment.bind(_pending_sale_uid))
			confirm.name = "ConfirmEquipmentSale"
			_button("Giữ món đồ · Hủy bán", _request_gear_sale.bind(0))
		else: _pending_sale_uid = 0
	_label(station_content, Vector2.ZERO, "Đồ đang trang bị, bùa, vật phẩm nhiệm vụ và đồ có nguồn đặc biệt được giữ lại. Bán trang bị cơ bản Thường/Hiếm; món cao hơn giữ để rèn.")
	var stored: bool = false
	for id: StringName in MaterialCatalog.SELL_PRICES:
		var quote: Dictionary = economy.quote_material_sale(id)
		if quote["quantity"] <= 0: continue
		if not stored: _label(station_content, Vector2.ZERO, "BÁN VẬT LIỆU ĐÃ CẤT · Lấy trực tiếp từ kho căn cứ")
		stored = true
		var sell: Button = _item_card(ItemArtCatalog.icon(id), MaterialCatalog.DISPLAY_NAMES[id], "%d Linh Thạch / món" % quote["unit_price"], "Trong kho %d · Tổng %d Linh Thạch" % [quote["quantity"], quote["total"]], "Bán cả số trong kho", _sell_material.bind(id))
		sell.name = "SellMaterial_" + String(id)
		sell.disabled = not quote["can_sell"] or profile.read_only

func _request_gear_sale(uid: int) -> void:
	_pending_sale_uid = uid
	_refresh_station()

func _sell_bag_equipment(uid: int) -> void:
	var success: bool = _pending_sale_uid == uid and economy.sell_bag_equipment(uid)
	_pending_sale_uid = 0
	station_notice = "Đã bán. Linh Thạch đã được lưu." if success else "Chưa bán được; món đồ và Linh Thạch được giữ nếu lưu thất bại."
	_refresh_station()

func _sell_bag_material(id: StringName) -> void:
	var success: bool = economy.sell_bag_material(id)
	station_notice = "Đã bán 1 món từ hành trang. Linh Thạch đã được lưu." if success else "Chưa bán được; kiểm tra số lượng, giới hạn Linh Thạch và lưu dữ liệu."
	_refresh_station()

func _set_station_heading(text: String) -> void:
	var lines: PackedStringArray = text.split("\n")
	var first: String = lines[0]
	var parts: PackedStringArray = first.split(" · ")
	station_title.text = parts[0]
	station_caption.text = " · ".join(parts.slice(1))
	if lines.size() > 1:
		station_caption.text += ("\n" if not station_caption.text.is_empty() else "") + "\n".join(lines.slice(1))
	station_caption.visible = not station_caption.text.is_empty()

func _item_card(icon: Texture2D, title: String, details: String, quantity: String, action: String, callback: Callable) -> Button:
	var card: ServiceItemCard = ServiceItemCard.create(icon, title, details, quantity, action, callback, station_content.columns == 2)
	station_content.add_child(card)
	return card.action_button

func _equipment_icon(data: EquipmentData) -> Texture2D:
	return ItemArtCatalog.GEAR_ICON_OVERRIDES.get(data.id, data.icon_texture) as Texture2D if data != null else null

func _materials_text(costs: Dictionary) -> String:
	var fragments: Array[String] = []
	for id: StringName in costs:
		fragments.append("%d %s" % [costs[id], MaterialCatalog.DISPLAY_NAMES.get(id, String(id))])
	return ", ".join(fragments)

func _build_forge_menu() -> void:
	_label(station_content, Vector2.ZERO, "THIẾT LÃO · ĐÚC TRANG BỊ\nTừ Cực hiếm cần bản chế tạo đã học và vật liệu trong kho. Thần thánh có xác suất 50%; thất bại mất vật liệu lần thử, công thức được giữ.")
	if not economy.has_method(&"quote_forge"): return
	var recipes: Dictionary = economy.get("forge_recipes")
	var ids: Array = recipes.keys()
	ids.sort()
	for id: StringName in ids:
		var recipe: ForgeRecipe = recipes[id]
		var quote: Dictionary = _economy_quote(&"quote_forge", id)
		var quality: int = int(quote.get("quality", recipe.quality))
		var chance: int = roundi(float(quote.get("chance", recipe.success_chance)) * 100.0)
		var learned: bool = profile.learned_blueprints.has(StringName(quote.get("blueprint_id", recipe.equipment.id)))
		var button: Button = _item_card(_equipment_icon(recipe.equipment), recipe.display_name, "%d Linh Thạch · Thành công %d%%\n%s" % [quote.get("coin_cost", 0), chance, _materials_text(quote.get("materials", {}))], GearItem.NAMES[clampi(quality, 0, 5)] if learned else "Chưa học bản chế tạo", "Đúc", _forge_item.bind(id))
		button.name = "ForgeButton_" + String(id)
		button.disabled = not bool(quote.get("can_forge", false))
	if ids.is_empty(): _label(station_content, Vector2.ZERO, "Chưa có công thức phù hợp để tra cứu.")

func _forge_item(id: StringName) -> void:
	var result: Dictionary = economy.call(&"forge", id, forge_rng)
	station_notice = "Đúc thành công. Vật phẩm đã vào hành trang." if result.get("committed", false) and result.get("success", false) else "Lần đúc chưa thành. Vật liệu lần thử đã tiêu hao; bản chế tạo vẫn được giữ." if result.get("committed", false) else "Chưa thể đúc: kiểm tra bản chế tạo, vật liệu, Linh Thạch, chỗ trống và trạng thái lưu dữ liệu."
	_refresh_station()

func _build_enhancement_menu() -> void:
	_label(station_content, Vector2.ZERO, "THIẾT LÃO · CƯỜNG HÓA\nTối đa +12 · Thành công 100% · Mỗi cấp cộng 3% sát thương gốc. Cường hóa không đổi phẩm cấp; Thường vẫn giữ hiệu ứng đơn giản.")
	if not economy.has_method(&"quote_enhance"): return
	var found: bool = false
	for item: GearItem in gear.inventory.items.values():
		if item.kind != &"weapon": continue
		found = true
		var quote: Dictionary = economy.call(&"quote_enhance", item.uid)
		var name_text: String = ItemArtCatalog.gear_name(item)
		var level: int = int(quote.get("level", 0))
		var stone_id := StringName(quote.get("stone_id", ""))
		var text: String = "%s · +%d → +%d · %d Linh Thạch +1 %s" % [name_text, level, quote.get("next_level", level), quote.get("coin_cost", 0), MaterialCatalog.DISPLAY_NAMES.get(stone_id, "Đá Cường Hóa")]
		if level >= 12: text = "%s · +12 · Đã đạt giới hạn cường hóa" % name_text
		var button: Button = _item_card(ItemArtCatalog.gear_icon(item), name_text, text.trim_prefix(name_text + " · "), GearItem.NAMES[item.quality], "Cường hóa", _enhance_item.bind(item.uid))
		button.name = "EnhanceWeapon_%d" % item.uid
		button.disabled = not bool(quote.get("can_enhance", false))
	if not found: _label(station_content, Vector2.ZERO, "Chưa có vũ khí để cường hóa.")

func _enhance_item(uid: int) -> void:
	var success: bool = bool(economy.call(&"enhance_item", uid))
	station_notice = "Cường hóa thành công. UID và phẩm cấp được giữ nguyên." if success else "Chưa thể cường hóa: kiểm tra đá, Linh Thạch, giới hạn và trạng thái lưu dữ liệu."
	_refresh_station()

func _build_stone_menu() -> void:
	_label(station_content, Vector2.ZERO, "THIẾT LÃO · GHÉP ĐÁ\n5 viên cùng cấp thành 1 viên cấp tiếp theo · 6 cấp đá. Mỗi cấp đá phục vụ hai mốc cường hóa; đá cấp 6 dùng cho +11 và +12.")
	if not economy.has_method(&"quote_combine_stones"): return
	for grade: int in range(1, 6):
		var quote: Dictionary = economy.call(&"quote_combine_stones", grade, 1)
		var source_id := StringName(quote.get("source_id", ""))
		var target_id := StringName(quote.get("target_id", ""))
		var button: Button = _item_card(ItemArtCatalog.icon(source_id), MaterialCatalog.DISPLAY_NAMES.get(source_id, "Đá"), "Ghép %d đá cấp %d → %d đá cấp %d" % [quote.get("input_count", 5), grade, quote.get("output_count", 1), grade + 1], "%d trong kho · Đá cấp %d: %d" % [profile.material_stash.get(source_id, 0), grade + 1, profile.material_stash.get(target_id, 0)], "Ghép", _combine_stones.bind(grade))
		button.name = "CombineStone_%d" % grade
		button.disabled = not bool(quote.get("can_combine", false))

func _combine_stones(grade: int) -> void:
	var success: bool = bool(economy.call(&"combine_stones", grade, 1))
	station_notice = "Ghép đá hoàn tất. Đá cấp mới được giữ trong kho căn cứ." if success else "Chưa thể ghép: cần đủ 5 viên cùng cấp và lưu dữ liệu thành công."
	_refresh_station()

func _build_trader_stock() -> void:
	var stock_heading: Label = _label(station_content, Vector2.ZERO, "TRANG BỊ THƯỜNG / HIẾM")
	stock_heading.tooltip_text = "Kiếm và bộ đồ khởi đầu có bán ở Kael. Dòng vũ khí đã học có thêm lựa chọn; Cực hiếm trở lên cần đúc tại Thiết Lão."
	stock_heading.mouse_filter = Control.MOUSE_FILTER_PASS
	stock_heading.add_theme_color_override("font_color", AntiqueSkin.WARM)
	if not economy.has_method(&"quote_buy"): return
	var stock: Array[EquipmentData] = [GearInventory.COMMON_SWORD]
	stock.append_array(GearInventory.STARTER_CLOTHING)
	for path: String in DirAccess.get_files_at("res://data/equipment"):
		if not path.begins_with("world_") or not path.ends_with(".tres"): continue
		var data: EquipmentData = load("res://data/equipment/" + path) as EquipmentData
		if data == null: continue
		stock.append(data)
	for data: EquipmentData in stock:
		# The starter sword's persistent gear ID is ancient_sword; the shop uses
		# its existing common_sword resource key for quotes and purchases.
		var shop_id: StringName = &"common_sword" if data == GearInventory.COMMON_SWORD else data.id
		for quality: int in [GearItem.Quality.COMMON, GearItem.Quality.RARE]:
			var quote: Dictionary = economy.call(&"quote_buy", shop_id, quality)
			var button: Button = _item_card(_equipment_icon(data), data.item_name, "%d Linh Thạch · %s" % [quote.get("coin_cost", 0), data.description], "%s · %d Linh Thạch" % [GearItem.NAMES[quality], quote.get("coin_cost", 0)], "Mua", _buy_weapon.bind(shop_id, quality))
			button.name = "BuyWeapon_%s_%d" % [shop_id, quality]
			button.disabled = not bool(quote.get("can_buy", false))
			if String(shop_id).begins_with("world_") and not profile.learned_blueprints.has(shop_id): button.tooltip_text += "\nChưa học dòng vũ khí này. Khám phá hầm ngục để tìm bản chế tạo."

func _buy_weapon(id: StringName, quality: int) -> void:
	_request_purchase(&"equipment",id,quality)

func _build_consumable_menu() -> void:
	_label(station_content, Vector2.ZERO, "THANH VY · THUỐC VÀ BĂNG GẠC\nMua bằng Linh Thạch hoặc dùng nguyên liệu trong kho căn cứ. Thuốc được cất vào túi, không tự uống khi mua/chế.")
	var names: Dictionary[StringName, String] = {&"potion": "Thuốc Hồi Máu", &"bandage": "Băng Gạc", &"antidote": "Thuốc Giải Độc"}
	if economy.has_method(&"quote_buy_consumable"):
		var purchase: Dictionary = _economy_quote(&"quote_buy_consumable", &"potion")
		var buy: Button = _item_card(ItemArtCatalog.icon(&"potion"), names[&"potion"], "Mua · %d Linh Thạch" % purchase.get("coin_cost", 0), "%d trong túi" % gear.inventory.consumables.get(&"potion", 0), "Mua", _buy_consumable.bind(&"potion"))
		buy.name = "BuyConsumable_potion"
		buy.disabled = not bool(purchase.get("can_buy", false))
	for id: StringName in names:
		var quote: Dictionary = _economy_quote(&"quote_consumable", id)
		var craft: Button = _item_card(ItemArtCatalog.icon(id), names[id], "%s\n%s" % [AntiqueSkin.item_description(id), _materials_text(quote.get("materials", {}))], "%d trong túi" % gear.inventory.consumables.get(id, 0), "Chế", _craft_consumable.bind(id))
		craft.name = "CraftConsumable_" + String(id)
		craft.disabled = not bool(quote.get("can_craft", false))

func _buy_consumable(id: StringName) -> void:
	_request_purchase(&"consumable",id)

func _build_rune_learning_menu() -> void:
	_label(station_content,Vector2.ZERO,"THANH VY · HỌC & CHẾ BÙA\nHọc một lần để nhớ vĩnh viễn và nhận 1 bùa Thường. Bùa nhặt được vẫn ghép được ngay.\nSau khi học, chế thêm bằng nguyên liệu trong kho. Mở Hành trang → chọn trang bị → ghép vào ô bùa.")
	for id: StringName in RuneLearningService.IDS:
		var quote: Dictionary = rune_learning.quote(id)
		var learned: bool = bool(quote.get("learned",false))
		var action: StringName = &"rune_craft" if learned else &"rune_learn"
		var cost: String = "Chế 1 bùa Thường · %s trong kho\n%s" % [_materials_text(quote["craft_materials"]),_rune_material_snapshot(quote["craft_materials"])] if learned else "Học · %d Tàn Hồn · Đang có %d\nTặng 1 bùa Thường; sau đó có thể chế thêm." % [int(quote["cost"]),profile.souls]
		var hint: String = str(quote.get("lock_hint",""))
		var button: Button = _item_card(ItemArtCatalog.RUNE_ICONS.get(id) as Texture2D,"Bùa %s · %s" % [quote["name"],"Đã học" if learned else "Chưa học"],hint if not hint.is_empty() else "Cách học được giữ sau khi chết. Bùa là vật phẩm riêng để ghép vào trang bị.",cost,"Chế 1" if learned else "Học",_request_rune_purchase.bind(action,id))
		button.name = "RuneService_"+String(id)
		button.disabled = not bool(quote.get("can_craft" if learned else "can_learn",false))

func _rune_material_snapshot(costs: Dictionary) -> String:
	var fragments: Array[String] = []
	for id: StringName in costs:
		fragments.append("%s %d/%d" % [MaterialCatalog.DISPLAY_NAMES.get(id,String(id)),int(profile.material_stash.get(id,0)),int(costs[id])])
	return "Trong kho: "+", ".join(fragments)

func _request_rune_purchase(kind: StringName, id: StringName) -> void:
	if not station_open or current_station != &"rune_learning" or not _pending_purchase.is_empty() or kind not in [&"rune_learn",&"rune_craft"]: return
	var quote: Dictionary = rune_learning.quote(id)
	if not quote.get("can_learn" if kind == &"rune_learn" else "can_craft",false): return
	_purchase_serial += 1
	_pending_purchase = {"token":_purchase_serial,"kind":kind,"id":id,"quality":0,"station":current_station,"cost":int(quote["cost"]),"materials":quote["craft_materials"].duplicate(true),"learned":quote["learned"]}
	station_notice = ""
	_refresh_station()

func _purchase_quote(kind: StringName, id: StringName, quality: int) -> Dictionary:
	return economy.quote_buy(id,quality) if kind == &"equipment" else economy.quote_buy_consumable(id) if kind == &"consumable" else {}

func _request_purchase(kind: StringName, id: StringName, quality: int = 0) -> void:
	var required_station: StringName = &"merchant" if kind == &"equipment" else &"healer_consumables"
	if not station_open or current_station != required_station or not _pending_purchase.is_empty() or profile.read_only or profile.hub_inventory_quarantined: return
	var quote: Dictionary = _purchase_quote(kind,id,quality)
	if not quote.get("can_buy",false): return
	_purchase_serial += 1
	_pending_purchase = {"token":_purchase_serial,"kind":kind,"id":id,"quality":quality,"station":current_station,"cost":int(quote["coin_cost"])}
	station_notice = ""
	_refresh_station()

func _build_purchase_confirmation() -> void:
	station_content.columns = 1
	_label(station_content,Vector2.ZERO,"XÁC NHẬN MUA\nKiểm tra món đồ và giá trước khi thanh toán.")
	var kind: StringName = _pending_purchase["kind"]
	var id: StringName = _pending_purchase["id"]
	var quality: int = int(_pending_purchase["quality"])
	var cost: int = int(_pending_purchase["cost"])
	var token: int = int(_pending_purchase["token"])
	var item_name: String = "Thuốc Hồi Máu"
	var icon: Texture2D = ItemArtCatalog.icon(id)
	var detail: String = AntiqueSkin.item_description(id)
	var price_text: String = "Số lượng 1 · Giá %d Linh Thạch\nĐang có %d · Sau khi mua còn %d Linh Thạch" % [cost,profile.coins,maxi(0,profile.coins-cost)]
	var confirm_text: String = "Xác nhận mua · %d Linh Thạch" % cost
	if kind == &"equipment":
		var data: EquipmentData = load("res://data/equipment/%s.tres" % id) as EquipmentData
		item_name = data.item_name
		icon = _equipment_icon(data)
		detail = "%s · %s" % [GearItem.NAMES[quality],data.description]
	elif kind in [&"rune_learn",&"rune_craft"]:
		icon = ItemArtCatalog.RUNE_ICONS.get(id) as Texture2D
		item_name = "Bùa "+str(RuneLearningService.NAMES[id])
		if kind == &"rune_learn":
			detail = "Học vĩnh viễn và nhận 1 bùa Thường để ghép. Bùa nhặt được vẫn dùng được dù chưa học."
			price_text = "Giá học %d Tàn Hồn · Đang có %d · Sau khi học còn %d" % [cost,profile.souls,maxi(0,profile.souls-cost)]
			confirm_text = "Xác nhận học · %d Tàn Hồn" % cost
		else:
			detail = "Chế 1 bùa Thường để ghép vào trang bị. Cách học đã được lưu vĩnh viễn."
			price_text = "Giá chế: %s\n%s" % [_materials_text(_pending_purchase["materials"]),_rune_material_snapshot(_pending_purchase["materials"])]
			confirm_text = "Xác nhận chế · 1 bùa Thường"
	var preview: ServiceItemCard = _item_card(icon,item_name,detail,price_text,"Đang chọn",Callable()) as ServiceItemCard
	preview.name = "PurchaseItemPreview"
	preview.set_display_only()
	var confirm: Button = _button(confirm_text,_confirm_purchase.bind(token))
	confirm.name = "ConfirmPurchase"
	var cancel: Button = _button("Hủy · Quay lại",_cancel_purchase.bind(token))
	cancel.name = "CancelPurchase"
	# A second Enter from selecting the item cannot also pay for it.
	cancel.grab_focus.call_deferred()

func _cancel_purchase(token: int) -> void:
	if _pending_purchase.is_empty() or int(_pending_purchase["token"]) != token: return
	_pending_purchase.clear()
	if station_open: _refresh_station()

func _confirm_purchase(token: int) -> void:
	if not station_open or _pending_purchase.is_empty() or int(_pending_purchase["token"]) != token: return
	var offer: Dictionary = _pending_purchase.duplicate()
	# Consume before calling the owner: reentrant signals/stale buttons cannot pay twice.
	_pending_purchase.clear()
	if offer["kind"] in [&"rune_learn",&"rune_craft"]:
		_confirm_rune_purchase(offer)
		return
	var quote: Dictionary = _purchase_quote(offer["kind"],offer["id"],int(offer["quality"]))
	var permitted: bool = current_station == offer["station"] and not profile.read_only and not profile.hub_inventory_quarantined and bool(quote.get("can_buy",false)) and int(quote.get("coin_cost",-1)) == int(offer["cost"])
	var success: bool = false
	if permitted:
		success = economy.buy_weapon(offer["id"],int(offer["quality"])) if offer["kind"] == &"equipment" else economy.buy_consumable(offer["id"])
	station_notice = ("Mua thành công. Trang bị đã vào hành trang." if offer["kind"] == &"equipment" else "Mua thuốc thành công. Thuốc đã vào túi tiêu hao.") if success else "Chưa mua được. Kiểm tra lại giá, Linh Thạch, chỗ trống và dữ liệu lưu; hãy chọn lại món đồ."
	_refresh_station()

func _confirm_rune_purchase(offer: Dictionary) -> void:
	var quote: Dictionary = rune_learning.quote(offer["id"])
	var learning: bool = offer["kind"] == &"rune_learn"
	var permitted: bool = current_station == offer["station"] and quote.get("can_learn" if learning else "can_craft",false) and quote.get("learned") == offer["learned"] and int(quote.get("cost",-1)) == int(offer["cost"]) and quote.get("craft_materials",{}) == offer["materials"]
	var success: bool = false
	if permitted: success = rune_learning.learn(offer["id"]) if learning else rune_learning.craft(offer["id"])
	station_notice = ("Đã học vĩnh viễn và nhận 1 bùa Thường. Mở Hành trang để ghép bùa vào trang bị." if learning else "Đã chế 1 bùa Thường và cất vào hành trang.") if success else "Chưa hoàn tất. Điều kiện, chi phí hoặc dữ liệu lưu đã thay đổi; hãy chọn lại bùa."
	_refresh_station()

func _craft_consumable(id: StringName) -> void:
	var success: bool = bool(economy.call(&"craft_consumable", id))
	station_notice = "Chế tạo hoàn tất. Vật phẩm đã vào túi tiêu hao." if success else "Chưa thể chế: kiểm tra nguyên liệu trong kho, giới hạn túi và trạng thái lưu dữ liệu."
	_refresh_station()

func _resize_station_panel() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or station_panel == null:
		return
	var extent: Vector2 = get_viewport().get_visible_rect().size
	var available: Vector2 = (extent - Vector2(48, 56)).max(Vector2(160, 180))
	var width: float = minf(760.0, available.x)
	var min_height: float = minf(300.0, available.y)
	var max_height: float = minf(600.0, available.y)
	station_panel.custom_minimum_size = Vector2.ZERO
	station_panel.size = Vector2(width, clampf(extent.y * 0.72, min_height, max_height))
	station_panel.position = (extent - station_panel.size) * 0.5

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = text
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size.y = 44.0
	button.pressed.connect(action)
	station_content.add_child(button)
	return button

func _toggle_training() -> void:
	set_training_aggression(not training_aggression)
	_refresh_station()

func _claim_chest() -> void:
	claim_test_chest()
	_refresh_station()

func _deposit(id: StringName) -> void:
	var success: bool = economy.deposit(id, 1)
	station_notice = "Đã cất 1 món vào kho." if success else "Chưa cất được; đồ đang mang được giữ nếu lưu thất bại."
	_refresh_station()

func _withdraw(id: StringName) -> void:
	var success: bool = economy.withdraw(id, 1)
	station_notice = "Đã rút 1 món vào hành trang." if success else "Chưa rút được; kiểm tra chỗ trống, giới hạn và lưu dữ liệu."
	_refresh_station()

func _deposit_all() -> void:
	var success: bool = economy.deposit_all()
	station_notice = "Đã cất vật liệu đang mang vào kho." if success else "Chưa cất được; kiểm tra giới hạn kho và lưu dữ liệu."
	_refresh_station()

func _sell_material(id: StringName) -> void:
	economy.sell_material(id)
	_refresh_station()

func _repair_item(uid: int) -> void:
	economy.repair_item(uid)
	_refresh_station()

func enter_house() -> bool:
	if inside_house or dialogue.is_open or station_open or gear.modal.is_open:
		return false
	executor.clear_entities()
	feedback.reset_feedback()
	inside_house = true
	yard.hide()
	house.show()
	set_training_aggression(training_aggression)
	PlayerTravel.relocate(player, house.entry_point.global_position)
	_set_camera_bounds(true)
	zone_changed.emit(&"home")
	return true

func leave_house() -> bool:
	if not inside_house or dialogue.is_open or station_open or gear.modal.is_open:
		return false
	executor.clear_entities()
	feedback.reset_feedback()
	inside_house = false
	yard.show()
	house.hide()
	PlayerTravel.relocate(player, stations[&"house"].global_position)
	_set_camera_bounds(false)
	set_training_aggression(training_aggression)
	zone_changed.emit(&"yard")
	return true

func _set_camera_bounds(home: bool) -> void:
	var camera: Camera2D = player.get_node("Camera2D") as Camera2D
	camera.limit_left = int(HOUSE_ORIGIN.x) if home else 0
	camera.limit_right = int(HOUSE_ORIGIN.x + 1280.0) if home else int(YARD_WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = 720
	camera.reset_smoothing()
	camera.force_update_scroll()

func route_world_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if dialogue.is_open:
		if dialogue.handle_input(event): get_viewport().set_input_as_handled()
		return
	if station_open and (event.is_action_pressed(&"inventory") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel")):
		if event.is_action_pressed(&"ui_cancel") and not _pending_purchase.is_empty(): _cancel_purchase(int(_pending_purchase["token"]))
		else: close_station()
		get_viewport().set_input_as_handled()
	elif not station_open and event.is_action_pressed(&"interact") and not gear.modal.is_open:
		var station: StringName = nearest_station()
		if station != &"":
			# A portal callback replaces this Hub synchronously; consume before it.
			get_viewport().set_input_as_handled()
			interact_station(station)

func _process(delta: float) -> void:
	var id: StringName = nearest_station()
	prompt.text = "Space / E · Tiếp tục thoại" if dialogue != null and dialogue.is_open else "E · Trò chuyện với %s" % NpcCatalog.NAMES[id] if npcs.has(id) else "E · Tiến vào Hầm Ngục (Tầng 1)" if id == &"portal" else "E · Vào nhà" if id == &"house" else "E · Tương tác" if id != &"" else "A/D: Di chuyển · Space: Nhảy · Chuột: Chém / Bùa · Tab: Hành trang"
	if _slime_respawn_remaining >= 0.0:
		_slime_respawn_remaining -= delta
		if _slime_respawn_remaining < 0.0:
			if is_instance_valid(training_slime):
				training_slime.queue_free()
			_spawn_slime()
	if player.global_position.y > 850.0:
		executor.clear_entities()
		player.relocate(house.entry_point.global_position if inside_house else Vector2(430, 640))

func _exit_tree() -> void:
	TimeScaleClaims.release(self)
	if is_instance_valid(dialogue): TimeScaleClaims.release(dialogue)

func _cultivation_ui_changed() -> void:
	if station_open and current_station==&"training": call_deferred("_refresh_station")

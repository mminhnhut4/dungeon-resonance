class_name SurvivalSession
extends Node
## Wires optional deep systems to the existing run without global singletons.

var player: Player
var gear: GearSession
var world: Node2D
var feedback: CombatFeedback
var profile: SanctuaryProfile
var condition: BodyConditionComponent
var director: StorytellerDirector
var panel: SurvivalPanel
var campfire: Campfire
var shrine: Node2D
var merchant: Node2D
var merchant_panel: PanelContainer
var merchant_trade_used: bool = false
var merchant_choices: Dictionary = {}
var merchant_resources: Label
var merchant_status: Label
var merchant_location := Vector2(90, 366)
var hud: Label
var stress_bar: ProgressBar
var announcement: Label
var enabled: bool = true
var debug_keys: bool = false
var actor_scan_remaining: float = 0.0


func initialize(actor: Player, equipment: GearSession, owner_world: Node2D, combat: CombatFeedback, permanent: SanctuaryProfile = null, playground: bool = false) -> void:
	player = actor
	gear = equipment
	world = owner_world
	feedback = combat
	profile = permanent
	if profile == null:
		profile = SanctuaryProfile.new()
		profile.load_profile()
	debug_keys = playground
	condition = _attach_condition(player)
	condition.mental_break_started.connect(_mental_break)
	director = StorytellerDirector.new()
	director.player = player
	director.condition = condition
	director.inventory = gear.inventory
	director.world = world
	director.feedback = feedback
	director.style = profile.style
	director.automatic = not playground
	add_child(director)
	director.incident_started.connect(_incident_started)
	director.incident_ended.connect(_incident_ended)
	gear.loot.quality_enabled = true
	panel = SurvivalPanel.new()
	panel.session = self
	add_child(panel)
	gear.modal.secondary_panel = panel
	_build_hud()
	player.health.died.connect(_on_died)
	player.resonance_controller.resonance_prepared.connect(_discover)
	if playground:
		place_campfire(Vector2(670, 640))
	place_shrine(Vector2(240, 640))


func set_enabled(value: bool) -> void:
	enabled = value
	director.enabled = value
	gear.loot.quality_enabled = value
	condition.enabled = value
	if not value:
		condition.clear()
		director.end_incident()
		panel.close()
	for node: Node in get_tree().get_nodes_in_group(&"body_conditions"):
		if world.is_ancestor_of(node):
			node.enabled = value
			if not value:
				node.clear()


func _attach_condition(actor: CharacterBody2D) -> BodyConditionComponent:
	for child: Node in actor.get_children():
		if child is BodyConditionComponent:
			return child
	var component := BodyConditionComponent.new()
	component.name = "BodyConditionComponent"
	component.actor = actor
	component.feedback = feedback
	component.enabled = enabled
	actor.add_child(component)
	component.add_to_group(&"body_conditions")
	return component


func _physics_process(delta: float) -> void:
	if not enabled or player == null:
		return
	actor_scan_remaining -= delta
	if actor_scan_remaining <= 0.0:
		actor_scan_remaining = 0.25
		for actor: Node in get_tree().get_nodes_in_group(&"enemies"):
			if world.is_ancestor_of(actor) and actor.health.current_health > 0.0:
				_attach_condition(actor as CharacterBody2D)
	player.hurtbox.sanctuary_safe = is_instance_valid(campfire) and player.global_position.distance_to(campfire.global_position) < campfire.safe_radius
	if player.hurtbox.sanctuary_safe:
		condition.add_stress(-delta * 4.0)


func _input(event: InputEvent) -> void:
	if not enabled or player == null:
		return
	if event.is_action_pressed(&"body_panel"):
		if panel.is_open:
			panel.close()
		else:
			panel.open(is_near_campfire())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"interact") and is_near_campfire() and not gear.modal.is_open:
		panel.open(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"interact") and is_instance_valid(merchant) and player.global_position.distance_to(merchant.global_position) < 80.0:
		merchant_panel.show()
		player.suspend_controls(true)
		get_viewport().set_input_as_handled()
	elif debug_keys and event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				director.end_incident()
				var options: Array[StringName] = [&"toxic", &"swarm", &"eclipse"]
				director.trigger(options[director.rng.randi_range(0, 2)])
			KEY_F2:
				condition.inflict(&"bleeding")
				condition.inflict(&"crippled")
			KEY_F3:
				profile.add_souls(100)
				panel.open(true)


func is_near_campfire() -> bool:
	return is_instance_valid(campfire) and player.global_position.distance_to(campfire.global_position) < 100.0


func place_campfire(location: Vector2) -> void:
	if is_instance_valid(campfire):
		campfire.queue_free()
	campfire = Campfire.new()
	campfire.position = location
	world.add_child(campfire)


func clear_room() -> void:
	panel.close()
	director.end_incident()
	if is_instance_valid(campfire):
		campfire.queue_free()
	campfire = null
	player.hurtbox.sanctuary_safe = false
	for node: Node in get_tree().get_nodes_in_group(&"floor_traps") + get_tree().get_nodes_in_group(&"phantoms"):
		if world.is_ancestor_of(node):
			node.queue_free()


func place_shrine(location: Vector2) -> void:
	director.shrine_position = location
	shrine = Node2D.new()
	world.add_child(shrine)
	shrine.position = location
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([-14, 0, -14, -38, 0, -52, 14, -38, 14, 0])
	polygon.color = Color(0.5, 0.95, 0.8)
	shrine.add_child(polygon)
	var label := Label.new()
	label.text = "ĐÀI THANH TẨY"
	label.position = Vector2(-66, -75)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shrine.add_child(label)


func use_consumable(id: StringName) -> bool:
	if player.health.current_health <= 0.0 or not gear.inventory.consumables.has(id) or gear.inventory.consumables[id] <= 0:
		return false
	match id:
		&"potion":
			if player.health.heal(30.0) <= 0.0:
				return false
		&"bandage":
			if not condition.bleeding:
				return false
			condition.bandage()
		&"antidote":
			var status: ElementStatusController = player.hurtbox.damage_resolver.status_controller as ElementStatusController
			if status == null or not status.clear_poison():
				return false
		&"trap":
			if not player.is_on_floor():
				return false
			if get_tree().get_nodes_in_group(&"floor_traps").size() >= 8:
				return false
			var trap := preload("res://scripts/environment/floor_trap.gd").new() as Node2D
			trap.source_id = player.get_instance_id()
			trap.feedback = feedback
			trap.position = player.global_position
			world.add_child(trap)
		_: return false
	gear.inventory.consumables[id] -= 1
	gear.inventory.changed.emit()
	return true


func weapon_definition(id: StringName) -> WeaponDefinition:
	var path: String = "res://data/weapons/%s.tres" % id
	return load(path) as WeaponDefinition if ResourceLoader.exists(path) else Player.SWORD


func _discover(recipe: ResonanceDefinition) -> void:
	if enabled and recipe != null:
		profile.discover(recipe.id)


func _mental_break(kind: StringName) -> void:
	announcement.text = "KHỦNG HOẢNG · %s" % ("ẢO GIÁC" if kind == &"phantoms" else "CUỒNG LOẠN")
	if kind == &"phantoms":
		for index: int in 3:
			var phantom := preload("res://scripts/story/phantom_visual.gd").new() as Node2D
			phantom.feedback = feedback
			phantom.position = player.global_position + Vector2((index - 1) * 80, -45)
			world.add_child(phantom)
			phantom.add_to_group(&"phantoms")


func _incident_started(id: StringName) -> void:
	var names: Dictionary = {&"toxic": "XÂM THỰC ĐỘC KHÍ · Đài thanh tẩy / Phong để trú", &"swarm": "BẦY ĐÀN QUÁ TẢI · Quái đánh cả đồng loại", &"smuggler": "BÍ THƯƠNG BẤT NGỜ · Tìm phòng ẩn", &"eclipse": "THỰC THẦN · Hỏa / Lôi gây sát thương gấp đôi"}
	announcement.text = names[id]
	if id == &"smuggler":
		merchant_trade_used = false
		merchant = Node2D.new()
		merchant.position = merchant_location
		world.add_child(merchant)
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([-12, 0, -12, -38, 12, -38, 12, 0])
		body.color = Color(0.65, 0.25, 0.85)
		merchant.add_child(body)
		var label := Label.new()
		label.text = "E · BÍ THƯƠNG"
		label.position = Vector2(-60, -62)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		merchant.add_child(label)


func trade(currency: StringName) -> bool:
	if director.current_incident != &"smuggler" or merchant_trade_used or player.health.current_health <= 0.0:
		return false
	if gear.inventory.equipment_bag_uids().size() >= GearInventory.EQUIPMENT_BAG_CAPACITY:
		return false
	if currency == &"souls":
		if not profile.spend(15):
			return false
	elif currency == &"blood":
		if player.health.maximum_health <= 30.0:
			return false
		player.health.maximum_health -= 10.0
		player.health.current_health = minf(player.health.current_health, player.health.maximum_health)
		player.health.health_changed.emit(player.health.current_health, player.health.maximum_health)
	else:
		return false
	merchant_trade_used = true
	gear.inventory.add_item(&"weapon", &"shadow_dagger", GearItem.Quality.RARE)
	gear.inventory.changed.emit()
	return true


func _incident_ended(_id: StringName) -> void:
	if is_instance_valid(merchant):
		merchant.queue_free()
	merchant = null
	if merchant_panel != null and merchant_panel.visible:
		merchant_panel.hide()
		player.suspend_controls(player.health.current_health <= 0.0)
	announcement.text = "Biến cố đã qua · Bình tâm và chuẩn bị."


func _on_died() -> void:
	panel.close()
	director.end_incident()
	merchant_panel.hide()


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 18
	add_child(canvas)
	var overlay := preload("res://scripts/story/incident_overlay.gd").new() as Control
	overlay.director = director
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var environment_canvas := CanvasLayer.new()
	environment_canvas.layer = 8
	add_child(environment_canvas)
	environment_canvas.add_child(overlay)
	hud = Label.new()
	hud.position = Vector2(48, 290 if debug_keys else 180)
	hud.add_theme_font_size_override("font_size", 14)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	stress_bar = ProgressBar.new()
	stress_bar.position = Vector2(48, 180 if debug_keys else 154)
	stress_bar.size = Vector2(260, 12)
	stress_bar.show_percentage = false
	stress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(stress_bar)
	announcement = Label.new()
	announcement.position = Vector2(350, 110)
	announcement.add_theme_font_size_override("font_size", 17)
	announcement.add_theme_color_override("font_color", Color(1.0, 0.8, 0.28))
	announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(announcement)
	merchant_panel = PanelContainer.new()
	AntiqueSkin.apply_panel(merchant_panel)
	canvas.add_child(merchant_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	merchant_panel.add_child(column)
	column.add_child(AntiqueSkin.section("BÍ THƯƠNG"))
	var product := GearItem.new()
	product.kind = &"weapon"
	product.definition_id = &"shadow_dagger"
	product.quality = GearItem.Quality.RARE
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",AntiqueSkin.texture_style(AntiqueSkin.CARD,18,10))
	column.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	frame.add_child(row)
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(64,64)
	slot.add_theme_stylebox_override("panel",AntiqueSkin.texture_style(AntiqueSkin.SLOT,18,6))
	row.add_child(slot)
	var image := TextureRect.new()
	image.texture = OpeningItemPresentation.item_icon(product)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(image)
	if image.texture == null:
		var pending := DungeonUI.label("Chưa có\nảnh riêng",12,AntiqueSkin.MUTED)
		pending.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(pending)
	var product_text := VBoxContainer.new()
	product_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(product_text)
	product_text.add_child(DungeonUI.label(OpeningItemPresentation.item_name(product),18))
	product_text.add_child(DungeonUI.label("Hiếm · Vũ khí\nMỗi biến cố chỉ giao dịch một món.",14,AntiqueSkin.MUTED))
	merchant_resources = DungeonUI.label("",14,AntiqueSkin.JADE)
	column.add_child(merchant_resources)
	for currency: StringName in [&"souls", &"blood"]:
		var button := Button.new()
		button.name = "Trade_"+String(currency)
		button.text = "Trả 15 Tàn Hồn" if currency == &"souls" else "Hiến 10 máu tối đa · trong lượt này"
		button.custom_minimum_size.y = 44
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(trade.bind(currency))
		merchant_choices[currency] = button
		column.add_child(button)
	merchant_status = DungeonUI.label("",14,AntiqueSkin.MUTED)
	column.add_child(merchant_status)
	var close_button := Button.new()
	close_button.name = "CloseSmuggler"
	close_button.text = "Rời quầy"
	close_button.custom_minimum_size.y = 44
	close_button.pressed.connect(func() -> void: merchant_panel.hide(); player.suspend_controls(false))
	column.add_child(close_button)
	get_viewport().size_changed.connect(_resize_merchant)
	merchant_panel.minimum_size_changed.connect(_schedule_merchant_resize)
	_resize_merchant.call_deferred()
	merchant_panel.hide()

func _resize_merchant() -> void:
	if merchant_panel == null or not is_inside_tree(): return
	var extent: Vector2 = get_viewport().get_visible_rect().size
	merchant_panel.size = Vector2(minf(620,extent.x-32),minf(420,extent.y-32))
	merchant_panel.position = (extent-merchant_panel.size)*0.5
	merchant_panel.queue_sort()

func _schedule_merchant_resize() -> void:
	if is_inside_tree(): _resize_merchant.call_deferred()

func _refresh_merchant_view() -> void:
	if merchant_resources == null: return
	var count: int = gear.inventory.equipment_bag_uids().size()
	merchant_resources.text = "Tàn Hồn %d · Máu tối đa %.0f · Túi trang bị %d/%d" % [profile.souls,player.health.maximum_health,count,GearInventory.EQUIPMENT_BAG_CAPACITY]
	var available: bool = director.current_incident == &"smuggler" and not merchant_trade_used and player.health.current_health>0 and count<GearInventory.EQUIPMENT_BAG_CAPACITY
	merchant_choices[&"souls"].disabled = not available or profile.souls<15 or OpeningItemPresentation._property(profile,&"read_only")==true
	merchant_choices[&"blood"].disabled = not available or player.health.maximum_health<=30
	merchant_choices[&"souls"].text = "Trả 15 Tàn Hồn · Có %d · Thiếu %d" % [profile.souls, maxi(0, 15 - profile.souls)]
	merchant_choices[&"souls"].tooltip_text = "Cần 15 Tàn Hồn và chỗ trống trong túi trang bị. Linh Thạch không thay thế giá nghi thức này."
	merchant_choices[&"blood"].tooltip_text = "Giảm 10 máu tối đa trong lượt hiện tại. Cần máu tối đa trên 30 và chỗ trống trong túi."
	merchant_status.text = "Đã giao dịch một món trong biến cố này." if merchant_trade_used else "Túi trang bị đã đầy." if count>=GearInventory.EQUIPMENT_BAG_CAPACITY else "Chọn một cách trả; kiểm tra giá trước khi mua."


func _process(_delta: float) -> void:
	if merchant_panel != null and merchant_panel.visible: _refresh_merchant_view()
	if hud == null:
		return
	hud.visible = enabled and bool(world.get_meta(&"debug_visible", false))
	stress_bar.visible = enabled and bool(world.get_meta(&"debug_visible", false))
	announcement.visible = enabled and bool(world.get_meta(&"debug_visible", false))
	stress_bar.value = condition.stress
	hud.text = "Áp Lực %d/100 · Tàn Hồn %d · Nguy cơ %.0f\n%s\nC · Vết thương / chế tạo%s" % [roundi(condition.stress), profile.souls, director.threat_points(), condition.summary(), " · F1/F2/F3: Debug" if debug_keys else ""]

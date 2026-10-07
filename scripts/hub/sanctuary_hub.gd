class_name SanctuaryHub
extends Node2D

signal run_requested
signal campaign_requested
var profile: SanctuaryProfile
var player: Player
var info: Label
var stations: PanelContainer
var status: Label
var start_selector: OptionButton
var archive_rows: VBoxContainer
var unlock_buttons: Dictionary[StringName, Button] = {}
var from_defeat: bool = false
var starter_inventory: GearInventory
var starter_stats: EquipmentStats
var starter_visual: EquipmentVisual


func _ready() -> void:
	if profile == null:
		profile = SanctuaryProfile.new()
		profile.load_profile()
	player = preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	player.position = Vector2(640, 620)
	add_child(player)
	_install_starter_outfit()
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(640, 660)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1280, 80)
	collider.shape = shape
	floor_body.add_child(collider)
	add_child(floor_body)
	var camera := Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)
	camera.make_current()
	_build_ui()
	profile.changed.connect(refresh)
	refresh()


func _install_starter_outfit() -> void:
	# A disposable Hub display uses the same definitions as the fresh-run kit.
	# Dungeon loot, spell executors and inventory modals remain room-owned.
	starter_inventory = GearInventory.new()
	var sword: GearItem = starter_inventory.add_equipment(GearInventory.COMMON_SWORD)
	starter_inventory.equip_equipment(sword.uid)
	starter_inventory.install_starter_clothing()
	starter_stats = EquipmentStats.new()
	add_child(starter_stats)
	starter_stats.initialize(player, starter_inventory)
	player.equipped_weapon.damage_multiplier = 1.0 + starter_stats.attack_bonus / maxf(1.0, player.equipped_weapon.definition.base_damage)
	player.health.reset_health()
	starter_visual = EquipmentVisual.new()
	starter_visual.player = player
	starter_visual.inventory = starter_inventory
	player.get_node("Visuals").add_child(starter_visual)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	info = Label.new()
	info.position = Vector2(48, 28)
	info.add_theme_font_size_override("font_size", 28)
	canvas.add_child(info)
	stations = PanelContainer.new()
	AntiqueSkin.apply_panel(stations)
	stations.position = Vector2(48, 100)
	stations.size = Vector2(1184, 400)
	canvas.add_child(stations)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	stations.add_child(columns)
	var forge := VBoxContainer.new()
	forge.custom_minimum_size.x = 320
	columns.add_child(forge)
	_label(forge, "ĐÀI RÈN ĐÚC\nMở khóa dòng vũ khí vĩnh viễn")
	unlock_buttons[&"blade_fan"] = _button(forge, "Quạt Phi Đao · 50 Tàn Hồn", _unlock.bind(&"blade_fan"))
	unlock_buttons[&"ritual_staff"] = _button(forge, "Trượng Trì Chú · 75 Tàn Hồn", _unlock.bind(&"ritual_staff"))
	_label(forge, "Vũ khí khởi đầu cho run kế")
	start_selector = OptionButton.new()
	start_selector.item_selected.connect(_select_start)
	forge.add_child(start_selector)
	var archive_scroll := ScrollContainer.new()
	archive_scroll.custom_minimum_size = Vector2(420, 350)
	columns.add_child(archive_scroll)
	archive_rows = VBoxContainer.new()
	archive_rows.custom_minimum_size.x = 420
	archive_scroll.add_child(archive_rows)
	var settings := VBoxContainer.new()
	columns.add_child(settings)
	_label(settings, "QUẢN TRÒ")
	for style: StringName in [&"steady", &"balanced", &"chaotic"]:
		var names: Dictionary = {&"steady": "Ổn định", &"balanced": "Cân bằng", &"chaotic": "Hỗn loạn ngẫu nhiên"}
		_button(settings, names[style], _set_style.bind(style))
	_button(settings, "Đi ải · 3 tầng + phòng bí mật", campaign_requested.emit)
	_button(settings, "Alpha · 3 phòng gốc", run_requested.emit)
	_button(settings, "Thoát", get_node("/root/AudioManager").request_quit)
	status = Label.new()
	status.position = Vector2(48, 515)
	canvas.add_child(status)
	for index: int in 3:
		var marker := Polygon2D.new()
		marker.position = Vector2(350 + index * 290, 620)
		marker.polygon = PackedVector2Array([-25, 0, -25, -45, 25, -45, 25, 0])
		marker.color = Color(0.85, 0.55, 0.2) if index == 0 else Color(0.4, 0.7, 1.0) if index == 1 else Color(0.6, 0.35, 0.9)
		add_child(marker)
	_label(canvas, "A/D: đi trong căn cứ · E: xem công trình · Nút Bắt đầu để vào hầm ngục", Vector2(48, 680))


func refresh() -> void:
	info.text = "%sTẾ ĐÀN TỊ NẠN · Tàn Hồn %d · Quản trò %s" % ["Thất Bại · Đã trở về\n" if from_defeat else "", profile.souls, profile.style]
	for id: StringName in unlock_buttons:
		var cost: int = 50 if id == &"blade_fan" else 75
		unlock_buttons[id].text = "%s · %d Tàn Hồn · Có %d · Thiếu %d" % ["Quạt Phi Đao" if id == &"blade_fan" else "Trượng Trì Chú", cost, profile.souls, maxi(0, cost - profile.souls)]
		unlock_buttons[id].disabled = profile.read_only or profile.unlocked_weapons.has(id) or profile.souls < cost
	start_selector.clear()
	for id: StringName in profile.unlocked_weapons:
		var definition: WeaponDefinition = load("res://data/weapons/%s.tres" % id) as WeaponDefinition
		start_selector.add_item(definition.display_name)
		if id == profile.starting_weapon:
			start_selector.select(start_selector.item_count - 1)
	for child: Node in archive_rows.get_children():
		archive_rows.remove_child(child)
		child.queue_free()
	_label(archive_rows, "THƯ VIỆN CỔ · Công thức đã khám phá")
	for id: StringName in SanctuaryProfile.RECIPES:
		var recipe: ResonanceDefinition = load("res://data/resonances/%s.tres" % id) as ResonanceDefinition
		if profile.archived_recipes.has(id):
			_label(archive_rows, "%s\n%s" % [recipe.display_name, " + ".join(recipe.recipe_rune_ids)])
		elif profile.discovered_recipes.has(id):
			_button(archive_rows, "Lưu %s · 5 Tàn Hồn · Có %d · Thiếu %d" % [recipe.display_name, profile.souls, maxi(0, 5 - profile.souls)], _archive.bind(id))
		else:
			_label(archive_rows, "??? · Hãy lắp bùa trong hầm ngục")
	status.text = "Mở khóa: %s\nTàn Hồn được giữ khi chết. Trang bị, vết thương và nguyên liệu được làm mới mỗi run." % [", ".join(profile.unlocked_weapons)]


func _unlock(id: StringName) -> void:
	if profile.unlocked_weapons.has(id):
		status.text = "Dòng vũ khí này đã được mở khóa."
	elif profile.souls < (50 if id == &"blade_fan" else 75):
		status.text = "Chưa đủ Tàn Hồn: có %d, cần %d, thiếu %d." % [profile.souls, 50 if id == &"blade_fan" else 75, maxi(0, (50 if id == &"blade_fan" else 75) - profile.souls)]
	elif profile.unlock_weapon(id):
		status.text = "Đã mở khóa vĩnh viễn."
	else:
		status.text = "Không thể lưu giao dịch. Tàn Hồn chưa bị trừ; hãy thử lại."


func _archive(id: StringName) -> void:
	if not profile.discovered_recipes.has(id) or profile.archived_recipes.has(id):
		status.text = "Công thức chưa được khám phá hoặc đã lưu."
	elif profile.souls < 5:
		status.text = "Chưa đủ Tàn Hồn: có %d, cần 5, thiếu %d." % [profile.souls, maxi(0, 5 - profile.souls)]
	elif profile.archive(id):
		status.text = "Đã lưu công thức."
	else:
		status.text = "Không thể lưu giao dịch. Tàn Hồn chưa bị trừ; hãy thử lại."


func _select_start(index: int) -> void:
	if index < 0 or index >= profile.unlocked_weapons.size():
		return
	if not profile.set_starting_weapon(profile.unlocked_weapons[index]):
		refresh()
		status.text = "Không thể lưu lựa chọn. Vũ khí khởi đầu trước đó được giữ lại."

func _set_style(next_style: StringName) -> void:
	profile.set_style(next_style)
	if not profile.last_save_ok:
		status.text = "Không thể lưu tùy chọn. Phong cách Quản trò trước đó được giữ lại."


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		stations.visible = not stations.visible


func _button(parent_node: Node, text: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callable)
	parent_node.add_child(button)
	return button


func _label(parent_node: Node, text: String, location: Vector2 = Vector2.ZERO) -> void:
	var label := Label.new()
	label.text = text
	label.position = location
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_node.add_child(label)

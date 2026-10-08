class_name ArtHUD
extends CanvasLayer
## Read-only art overlay. Legacy bars retain their API, values and visibility.

const PLAYER_FRAME: Texture2D = preload("res://assets/ui/hud_player_frame.png")
const BOSS_FRAME: Texture2D = preload("res://assets/ui/hud_boss_frame.png")
const FIRE_ICON: Texture2D = preload("res://assets/ui/icons/icon_fire.png")
const WIND_ICON: Texture2D = preload("res://assets/ui/icons/icon_wind.png")
const SWORD_ICON: Texture2D = preload("res://assets/ui/icons/icon_sword.png")
const SHIELD_ICON: Texture2D = preload("res://assets/ui/icons/icon_shield.png")

var player_panel: Control
var player_frame: TextureRect
var hp_bar: TextureProgressBar
var energy_bar: TextureProgressBar
var hp_text: Label
var energy_text: Label
var soul_text: Label
var currency_text: Label
var _profile: SanctuaryProfile
var rune_icons: Array[TextureRect] = []
var rune_ids: Array[StringName] = []
var weapon_icon: TextureRect
var weapon_name: Label
var weapon_id: StringName = &""
var boss_panel: Control
var boss_frame: TextureRect
var boss_emblem: TextureRect
var boss_hp: TextureProgressBar
var boss_name: Label
var boss_text: Label
var boss_id: int = 0
var _actor_id: int = 0
var _world_id: int = 0
var _legacy: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	layer = 14
	_build_ui()
	refresh_hud()


func bind(owner_world: Node2D, player: Player, legacy_player_hp: ProgressBar = null, legacy_boss_hp: ProgressBar = null, legacy_boss_name: Label = null) -> void:
	_restore_legacy()
	if _profile != null and _profile.changed.is_connected(refresh_hud): _profile.changed.disconnect(refresh_hud)
	_profile = _live_property(owner_world, &"profile") as SanctuaryProfile
	if _profile == null:
		var survival: SurvivalSession = _live_property(owner_world, &"survival") as SurvivalSession
		if is_instance_valid(survival): _profile = survival.profile
	if _profile != null and not _profile.changed.is_connected(refresh_hud): _profile.changed.connect(refresh_hud)
	_world_id = owner_world.get_instance_id() if is_instance_valid(owner_world) else 0
	_actor_id = player.get_instance_id() if is_instance_valid(player) else 0
	boss_id = 0
	for widget: CanvasItem in [legacy_player_hp, legacy_boss_hp, legacy_boss_name]:
		_hide_legacy(widget)
	if is_instance_valid(owner_world):
		_hide_legacy(_live_property(owner_world, &"hp_bar") as CanvasItem)
		_hide_legacy(_live_property(owner_world, &"energy_bar") as CanvasItem)
		var debug: DebugHUD = _live_property(owner_world, &"debug_hud") as DebugHUD
		if is_instance_valid(debug):
			_hide_legacy(debug.hp_bar)
		var gear: GearSession = _live_property(owner_world, &"gear") as GearSession
		if is_instance_valid(gear):
			_hide_legacy(gear.energy_bar)
	if is_node_ready():
		refresh_hud()


func _build_ui() -> void:
	player_panel = Control.new()
	player_panel.name = "PlayerArtHUD"
	player_panel.position = Vector2(24, 20)
	player_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player_panel)
	# Frame has two alpha sockets around its central orb (2172x724 source).
	# Texture fills draw behind its ornate rim, never over the dragon or orb.
	hp_bar = _bar(player_panel, "PlayerHP", Vector2(48, 62), Vector2(86, 14), Color(0.92, 0.16, 0.20))
	energy_bar = _bar(player_panel, "PlayerEnergy", Vector2(228, 62), Vector2(90, 14), Color(0.18, 0.75, 0.96))
	player_frame = _texture(player_panel, "PlayerFrame", PLAYER_FRAME, Vector2.ZERO, Vector2(360, 120))
	hp_text = _label(player_panel, Vector2(48, 59), Vector2(86, 22), 11)
	energy_text = _label(player_panel, Vector2(228, 59), Vector2(90, 22), 11)
	for index: int in 3:
		var icon: TextureRect = _texture(player_panel, "RuneSlot%d" % (index + 1), SHIELD_ICON, Vector2(44 + index * 52, 119), Vector2(44, 44))
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		rune_icons.append(icon)
	soul_text = _label(player_panel, Vector2(44, 168), Vector2(300, 24), 16)
	soul_text.name = "SoulBalance"
	soul_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	soul_text.add_theme_color_override("font_color", Color(0.78, 0.87, 1.0))
	currency_text = _label(player_panel, Vector2(44, 192), Vector2(320, 24), 14)
	currency_text.name = "SpiritStoneBalance"
	currency_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	currency_text.add_theme_color_override("font_color", Color(0.98, 0.88, 0.60))
	weapon_icon = _texture(player_panel, "EquippedWeaponIcon", SWORD_ICON, Vector2(4, 590), Vector2(56, 56))
	weapon_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	weapon_name = _label(player_panel, Vector2(64, 608), Vector2(260, 36), 15)
	weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	boss_panel = Control.new()
	boss_panel.name = "BossArtHUD"
	boss_panel.position = Vector2(430, 629)
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boss_panel)
	# The source emblem is tall. Two AtlasTexture regions keep its proportions
	# without stretching the dragon into a thin horizontal health strip.
	var frame_region := AtlasTexture.new()
	frame_region.atlas = BOSS_FRAME
	frame_region.region = Rect2(0, 690, 1536, 334)
	var emblem_region := AtlasTexture.new()
	emblem_region.atlas = BOSS_FRAME
	emblem_region.region = Rect2(330, 0, 870, 714)
	boss_hp = _bar(boss_panel, "BossHP", Vector2(47, 20), Vector2(328, 35), Color(0.88, 0.25, 0.12))
	boss_frame = _texture(boss_panel, "BossFrame", frame_region, Vector2.ZERO, Vector2(420, 91))
	# Keep the smaller portrait alongside the footer, not above it where a grounded
	# Player can walk behind it. Both art regions remain below the gameplay floor.
	boss_emblem = _texture(boss_panel, "BossDragonEmblem", emblem_region, Vector2(-70, 20), Vector2(60, 49.24))
	boss_name = _label(boss_panel, Vector2(47, 20), Vector2(328, 19), 16)
	boss_name.text = "Golem Cổ Bảo"
	boss_name.add_theme_color_override("font_color", Color(0.98, 0.88, 0.60))
	boss_text = _label(boss_panel, Vector2(47, 39), Vector2(328, 16), 12)
	boss_panel.visible = false


func _texture(parent: Node, widget_name: String, texture: Texture2D, location: Vector2, extent: Vector2) -> TextureRect:
	var widget := TextureRect.new()
	widget.name = widget_name
	widget.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Ignore the source PNG minimum BEFORE assigning it. Setting this after size
	# lets the natural 1254/2172px dimensions clamp the requested HUD rectangle.
	widget.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	widget.stretch_mode = TextureRect.STRETCH_SCALE
	widget.texture = texture
	widget.position = location
	widget.size = extent
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(widget)
	return widget


func _bar(parent: Node, widget_name: String, location: Vector2, extent: Vector2, color: Color) -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.name = widget_name
	bar.position = location
	bar.size = extent
	bar.max_value = 100.0
	bar.nine_patch_stretch = true
	bar.texture_under = _gradient_texture(Color(0.025, 0.035, 0.045), Color(0.06, 0.08, 0.10))
	bar.texture_progress = _gradient_texture(color.darkened(0.30), color.lightened(0.30))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar


func _gradient_texture(low: Color, high: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, high)
	gradient.set_color(1, low)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 8
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	return texture


func _label(parent: Node, location: Vector2, extent: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.set_meta(&"debug_keep", true)
	label.position = location
	label.size = extent
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.97, 0.97, 0.94))
	label.add_theme_color_override("font_outline_color", Color(0.025, 0.03, 0.04))
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	return label


func _process(_delta: float) -> void:
	refresh_hud()


func refresh_hud() -> void:
	if player_panel == null:
		return
	var player: Player = instance_from_id(_actor_id) as Player if _actor_id != 0 and is_instance_id_valid(_actor_id) else null
	player_panel.visible = is_instance_valid(player) and player.is_inside_tree()
	if not player_panel.visible:
		_clear_boss_hud()
		return
	hp_bar.max_value = player.health.maximum_health
	hp_bar.value = player.health.current_health
	energy_bar.max_value = player.energy.maximum
	energy_bar.value = player.energy.current
	hp_text.text = "%d / %d" % [roundi(player.health.current_health), roundi(player.health.maximum_health)]
	energy_text.text = "%d / %d" % [roundi(player.energy.current), roundi(player.energy.maximum)]
	energy_bar.tooltip_text = "Năng lượng · Lướt và phép dùng chung"
	var installed: Array[RuneData] = player.resonance_controller.catalyst_a.runtime_state.installed_runes
	rune_ids.clear()
	for index: int in rune_icons.size():
		var rune: RuneData = installed[index] if index < installed.size() else null
		var icon: TextureRect = rune_icons[index]
		rune_ids.append(rune.id if rune != null else &"")
		icon.texture = (ItemArtCatalog.RUNE_ICONS.get(rune.id, SHIELD_ICON) as Texture2D) if rune != null else SHIELD_ICON
		icon.modulate = Color.WHITE if rune != null and ItemArtCatalog.RUNE_ICONS.has(rune.id) else rune.display_color if rune != null else Color(0.55, 0.58, 0.62, 0.45)
		icon.tooltip_text = "%s · %s" % [rune.display_name, String(rune.id)] if rune != null else "Ô bùa %d · Trống" % (index + 1)
	var definition: WeaponDefinition = player.equipped_weapon.definition
	weapon_id = definition.id if definition != null else &""
	weapon_icon.texture = SWORD_ICON if definition != null and definition.attack_kind == &"melee" else SHIELD_ICON
	weapon_icon.modulate = Color.WHITE if definition != null and definition.attack_kind == &"melee" else Color(0.48, 0.82, 1.0)
	weapon_name.text = definition.display_name if definition != null else "Chưa trang bị"
	var gear_actor: GearSession = _live_property(instance_from_id(_world_id) if _world_id != 0 and is_instance_id_valid(_world_id) else null, &"gear") as GearSession
	soul_text.visible = _profile != null
	currency_text.visible = _profile != null
	if _profile != null:
		soul_text.text = "Tàn Hồn %d" % _profile.souls
		var carried_coins: int = gear_actor.inventory.run_coins if is_instance_valid(gear_actor) else 0
		currency_text.text = "Linh Thạch %d" % _profile.coins + (" · Mang %d" % carried_coins if carried_coins > 0 else "")
		currency_text.tooltip_text = "Linh Thạch dùng mua bán. Phần đang mang được giữ khi về sảnh; Tàn Hồn là tài nguyên riêng."
	if is_instance_valid(gear_actor):
		var equipped: GearItem = gear_actor.inventory.items.get(gear_actor.inventory.equipped_weapon_uid)
		if equipped != null and equipped.equipment_definition != null and equipped.equipment_definition.moveset == definition:
			weapon_icon.texture = equipped.equipment_definition.icon_texture
			weapon_name.text = equipped.equipment_definition.item_name
		elif definition != null and definition.id == &"unarmed":
			weapon_icon.texture = null
	weapon_icon.tooltip_text = "%s · %s" % [weapon_name.text, String(weapon_id)]
	var world: Node2D = instance_from_id(_world_id) as Node2D if _world_id != 0 and is_instance_id_valid(_world_id) else null
	# A typed world property can still contain a freed Object after Boss Dead FSM
	# queues it for deletion. Validate the raw Variant before attempting a cast.
	var boss: BossGolem = _live_property(world, &"boss") as BossGolem
	if is_instance_valid(boss) and boss.is_inside_tree() and boss.health.current_health > 0.0 and player.health.current_health > 0.0:
		boss_id = boss.get_instance_id()
		boss_panel.visible = true
		boss_hp.max_value = boss.health.maximum_health
		boss_hp.value = boss.health.current_health
		boss_text.text = "%d / %d" % [roundi(boss.health.current_health), roundi(boss.health.maximum_health)]
		boss_hp.tooltip_text = "%d / %d" % [roundi(boss.health.current_health), roundi(boss.health.maximum_health)]
	else:
		_clear_boss_hud()
	_layout_footer()


func _layout_footer() -> void:
	# Keep the 1280x720 composition while anchoring the footer to smaller windows.
	var extent: Vector2 = get_viewport().get_visible_rect().size
	boss_panel.position = Vector2((extent.x - 420.0) * 0.5, extent.y - 91.0)
	var lift: float = 92.0 if extent.x < 1000.0 and boss_panel.visible else 0.0
	weapon_icon.position.y = extent.y - 130.0 - lift
	weapon_name.position.y = extent.y - 112.0 - lift


func _live_property(source: Object, property: StringName) -> Object:
	if not is_instance_valid(source):
		return null
	var value: Variant = source.get(property)
	return value if typeof(value) == TYPE_OBJECT and is_instance_valid(value) else null


func _clear_boss_hud() -> void:
	boss_panel.visible = false
	boss_id = 0
	boss_hp.value = 0.0
	boss_text.text = ""
	boss_hp.tooltip_text = ""


func _restore_legacy() -> void:
	for entry: Dictionary in _legacy.values():
		var value: Variant = (entry["ref"] as WeakRef).get_ref()
		var widget: CanvasItem = value as CanvasItem if is_instance_valid(value) else null
		if is_instance_valid(widget):
			widget.self_modulate = entry["self_modulate"]
	_legacy.clear()


func _hide_legacy(widget: CanvasItem) -> void:
	if not is_instance_valid(widget) or _legacy.has(widget.get_instance_id()):
		return
	_legacy[widget.get_instance_id()] = {"ref": weakref(widget), "self_modulate": widget.self_modulate}
	widget.self_modulate.a = 0.0


func _exit_tree() -> void:
	if _profile != null and _profile.changed.is_connected(refresh_hud): _profile.changed.disconnect(refresh_hud)
	_profile = null
	_restore_legacy()
	_actor_id = 0
	_world_id = 0
	boss_id = 0
	rune_ids.clear()

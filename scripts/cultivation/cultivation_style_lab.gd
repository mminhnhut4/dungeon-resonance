extends "res://scripts/rooms/test_level.gd"
## Explicit candidate fixture; never instantiated by GameFlow or real unlocks.
@export var fixture_unlocks: bool = false
var techniques: CultivationStyleRuntime
var candidate_hint: Label
var fixture_enemies: Array[BaseEnemy] = []
func _ready() -> void:
	super._ready()
	survival.set_enabled(false)
	techniques = CultivationStyleRuntime.new()
	player.add_child(techniques)
	techniques.initialize(player, self)
	if fixture_unlocks: techniques.apply_progress_snapshot([&"cloud_return", &"tether_sigil"], &"cloud_return")
	candidate_hint = Label.new()
	candidate_hint.position = Vector2(48, 300)
	candidate_hint.add_theme_font_size_override("font_size", 16)
	candidate_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(candidate_hint)
	_spawn_fixture_enemies()
func _spawn_fixture_enemies() -> void:
	for enemy: BaseEnemy in fixture_enemies:
		if is_instance_valid(enemy):
			enemy.attack_hitbox.deactivate()
			enemy.ai_enabled = false
			enemy.queue_free()
	fixture_enemies.clear()
	for id: String in ["ancient_guard", "bloodwing_bat", "runic_champion"]:
		var enemy: BaseEnemy = (load("res://scenes/enemies/%s.tscn" % id) as PackedScene).instantiate() as BaseEnemy
		enemy.position = Vector2(580 if id == "ancient_guard" else 920, 500 if id == "bloodwing_bat" else 640)
		enemy.player = player
		enemy.combat_feedback = combat_feedback
		add_child(enemy)
		fixture_enemies.append(enemy)
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not fixture_unlocks: return
	if event.physical_keycode == KEY_F9: techniques.apply_progress_snapshot([&"cloud_return", &"tether_sigil"], &"cloud_return")
	elif event.physical_keycode == KEY_F10: techniques.apply_progress_snapshot([&"cloud_return", &"tether_sigil"], &"tether_sigil")
	elif event.physical_keycode == KEY_G: techniques.request_skill(player.aim.target_position)
	else: return
	get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(techniques) or candidate_hint == null: return
	var id: StringName = techniques.selected
	var name: String = techniques.DATA[id].display_name if id != &"" else "Chưa học"
	var cost: String = "né 25 + phản kích 12" if id == &"cloud_return" else "đặt 18 + kích 8"
	candidate_hint.text = "CANDIDATE · PHÒNG THỬ CÔNG PHÁP · mở khóa chỉ trong fixture\nF9: Hồi Phong · F10: Tỏa Linh · G: kỹ năng · I/chuột phải: ghép bùa cũ\n%s · %s · hồi %.1fs · cửa phản kích %.2fs" % [name, cost, float(techniques.cooldowns.get(id, 0)), techniques.counter_remaining]
func reset_room() -> void:
	if is_instance_valid(techniques): techniques.cancel_for_room_transition()
	super.reset_room()
	_spawn_fixture_enemies()

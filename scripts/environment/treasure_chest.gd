class_name TreasureChest
extends Node2D

signal opened
var player: Player
var spawner: LootSpawner
var locked: bool = false
var is_open: bool = false
var large: bool = false
var relic_reward: bool = false
var label: Label


func _ready() -> void:
	add_to_group(&"chests")
	z_index = 5
	label = Label.new()
	label.position = Vector2(-90, -55)
	label.size.x = 180
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)
	_update_label()


func interact() -> bool:
	if locked or is_open or not is_instance_valid(player) or player.health.current_health <= 0.0 or player.global_position.distance_to(global_position) > 85.0:
		return false
	is_open = true
	spawner.chest_drop(global_position, large)
	if relic_reward:
		var relic: RelicData = RelicRuntime.CATALOG[spawner.rng.randi_range(0, 3)]
		spawner.spawn(&"relic", relic.id, global_position + Vector2(0, -16))
	opened.emit()
	_update_label()
	return true


func unlock() -> void:
	locked = false
	_update_label()


func reset() -> void:
	is_open = false
	_update_label()


func _update_label() -> void:
	if label != null:
		label.text = "Đã mở" if is_open else "Bị khóa" if locked else "E · Rương báu"
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-24, -28, 48, 28), Color(0.48, 0.3, 0.12))
	draw_rect(Rect2(-26, -34 if is_open else -28, 52, 8), Color(0.95, 0.73, 0.28))
	draw_rect(Rect2(-3, -19, 6, 10), Color(0.7, 0.9, 1.0) if locked else Color(1.0, 0.92, 0.65))

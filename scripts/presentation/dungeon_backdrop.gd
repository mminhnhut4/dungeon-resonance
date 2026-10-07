class_name DungeonBackdrop
extends Node2D
## Original geometric masonry; decorative only, never adds collision.

var boss_room: bool = false
var bake_mode: bool = false
const FOYER: Texture2D = preload("res://assets/presentation/backdrop_foyer.png")
const BOSS: Texture2D = preload("res://assets/presentation/backdrop_boss.png")
const TEMPLE: Texture2D = preload("res://assets/environment/backgrounds/dungeon_temple_v1.png")

func _ready() -> void:
	z_index = -20
	# Masonry receives the real torch/projectile lights rather than painted glows.
	modulate = Color(1.4, 1.4, 1.4)
	if not bake_mode:
		var sprite := Sprite2D.new()
		sprite.name = "PaintedTemple"
		sprite.centered = false
		var region := AtlasTexture.new()
		region.atlas = TEMPLE
		region.region = Rect2(0, 0, TEMPLE.get_width(), TEMPLE.get_height() * 0.74)
		sprite.texture = region
		sprite.scale = Vector2(1280, 640) / region.region.size
		var material := CanvasItemMaterial.new()
		material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		sprite.material = material
		sprite.modulate = Color(0.62, 0.65, 0.74) if boss_room else Color(0.78, 0.81, 0.87)
		add_child(sprite)
	queue_redraw()

func _draw() -> void:
	if not bake_mode:
		return
	draw_rect(Rect2(0, 0, 1280, 720), Color("111624"))
	for row: int in 14:
		for column: int in 14:
			var x: float = column * 100.0 - (50.0 if row % 2 else 0.0)
			var y: float = row * 48.0
			var tint: float = 0.012 * sin(float(row * 17 + column * 13))
			draw_rect(Rect2(x + 2, y + 2, 96, 44), Color(0.082 + tint, 0.097 + tint, 0.15 + tint))
			draw_line(Vector2(x + 4, y + 3), Vector2(x + 96, y + 3), Color("20283a"), 1)
	for column: int in 4:
		var center: float = 150.0 + column * 325.0
		var arch := PackedVector2Array([Vector2(center - 72, 605), Vector2(center - 72, 292)])
		for index: int in 21:
			var angle: float = PI + float(index) * PI / 20.0
			arch.append(Vector2(center, 292) + Vector2(cos(angle), sin(angle)) * 72.0)
		arch.append(Vector2(center + 72, 605))
		draw_colored_polygon(arch, Color("080e1a"))
		draw_polyline(arch, Color("35405a"), 9, true)
		draw_polyline(arch, Color("222d43"), 4, true)
		draw_rect(Rect2(center - 88, 275, 12, 330), Color("263047"))
		draw_rect(Rect2(center + 76, 275, 12, 330), Color("1b253a"))
		for stone: int in 8:
			draw_line(Vector2(center - 88, 285 + stone * 40), Vector2(center - 76, 285 + stone * 40), Color("48536b"), 2)
			draw_line(Vector2(center + 76, 285 + stone * 40), Vector2(center + 88, 285 + stone * 40), Color("313d55"), 2)
	for crack: int in 16:
		var base := Vector2(65 + crack * 75, 126 + (crack % 4) * 108)
		draw_polyline(PackedVector2Array([base, base + Vector2(10, 22), base + Vector2(4, 30), base + Vector2(18, 46)]), Color("080d17"), 2)
	if boss_room:
		draw_circle(Vector2(850, 480), 102, Color("1d243d"))
		draw_arc(Vector2(850, 480), 94, 0, TAU, 64, Color("46506b"), 2, true)
		draw_arc(Vector2(850, 480), 82, 0, TAU, 64, Color("343b55"), 2, true)
		for rune: int in 8:
			var point: Vector2 = Vector2(850, 480) + Vector2.from_angle(rune * TAU / 8.0) * 70.0
			draw_polyline(PackedVector2Array([point + Vector2(-5, -8), point, point + Vector2(5, -8), point + Vector2(5, 8)]), Color("68638b"), 2)

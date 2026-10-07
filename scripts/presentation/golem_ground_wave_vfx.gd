class_name GolemGroundWaveVFX
extends Node2D
## Stone crest follows an existing wave body/hitbox; this node never moves it.
const MAX_VISUALS: int = 8
var wave: EnemyHazard
var age: float = 0.0
var _original_modulate: Color = Color.WHITE

func _ready() -> void:
	var ink := CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ink.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = ink

func bind(owner_wave: EnemyHazard) -> void:
	wave = owner_wave
	name = "GolemGroundWaveVFX"
	add_to_group(&"golem_ground_wave_vfx")
	process_physics_priority = 20
	_original_modulate = wave.self_modulate
	wave.self_modulate.a = 0.0 # Parent drawing only; the detailed child stays visible.
	z_index = 0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(wave):
		return
	if is_instance_valid(wave.feedback) and wave.feedback.is_frozen():
		return
	age += maxf(0.0, delta)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(wave):
		return
	var sign_x: float = -1.0 if wave.direction.x < 0.0 else 1.0
	var crest := PackedVector2Array()
	for point: Vector2 in [Vector2(-14, 12), Vector2(-10, 2), Vector2(-7, -5), Vector2(-2, -2), Vector2(1, -11), Vector2(7, -8), Vector2(10, -3), Vector2(14, 12)]:
		crest.append(Vector2(point.x * sign_x, point.y))
	draw_colored_polygon(crest, Color(0.19, 0.13, 0.08))
	var stone := PackedVector2Array([Vector2(-7, 8), Vector2(-4, -2), Vector2(1, -1), Vector2(3, -7), Vector2(8, -4), Vector2(11, 8)])
	for index: int in stone.size():
		stone[index].x *= sign_x
	draw_colored_polygon(stone, Color(0.55, 0.35, 0.15))
	draw_polyline(PackedVector2Array([Vector2(sign_x * -7, -5), Vector2(sign_x * -2, -2), Vector2(sign_x, -11), Vector2(sign_x * 7, -8), Vector2(sign_x * 10, -3)]), Color(0.92, 0.68, 0.29), 1.6, true)
	draw_line(Vector2(sign_x * 2, -3), Vector2(sign_x * -1, 7), Color(0.10, 0.08, 0.05), 1.4, true)
	# Trailing disconnected dust is cosmetic; dangerous head stays at the real body.
	for index: int in 4:
		var travel: float = fmod(age * 11.0 + index * 0.25, 1.0)
		var x: float = -sign_x * (16.0 + index * 5.0 + travel * 4.0)
		var y: float = 8.0 - sin(travel * PI) * (5.0 + index)
		var size: float = 1.2 + index * 0.25
		draw_colored_polygon(PackedVector2Array([Vector2(x-size,y),Vector2(x,y-size),Vector2(x+size,y),Vector2(x,y+size)]), Color(0.49, 0.37, 0.22, (1.0-travel)*0.5))

func snapshot() -> Dictionary:
	return {"source_id": wave.source_id if is_instance_valid(wave) else 0, "kind": wave.kind if is_instance_valid(wave) else &"", "age": age, "max_draw_commands": 8, "lights": 0, "damage_emitters": 0}

func restore_source() -> void:
	if is_instance_valid(wave):
		wave.self_modulate = _original_modulate
	wave = null
	visible = false

func _exit_tree() -> void:
	restore_source()

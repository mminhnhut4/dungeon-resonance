class_name ElementFieldVFX
extends Node2D
## Room-owned presentation only. Reads the field's real clock and snapshot;
## never adds damage, light, particles, collision, or a second gameplay timer.
const ART = preload("res://scripts/presentation/rendered_spell_art.gd")

var owner_id: int = 0
var tracked_root_id: int = 0
var style_id: StringName
var tint: Color = Color.WHITE
var committed_direction: Vector2 = Vector2.RIGHT
var elapsed: float = 0.0
var radius: float = 0.0
var duration: float = 0.0
var alpha: float = 0.0
var _art_layers: Array[Sprite2D] = []
var _art_ready: bool = false


func _ready() -> void:
	process_physics_priority = 20
	# ElementField itself is already at world z6.
	z_index = 0
	var ink := CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = ink
	visible = false


func bind(field: ElementField) -> void:
	owner_id = field.get_instance_id() if is_instance_valid(field) else 0
	if owner_id != 0 and field.context != null:
		var payload: SpellSnapshot = field.context.snapshot
		tracked_root_id = payload.root_id
		style_id = payload.behavior_id
		tint = payload.color
		committed_direction = payload.direction
	if _art_layers.is_empty(): _art_layers = ART.make_layers(self)
	_art_ready = ART.configure(_art_layers, ART.FIELD, style_id)
	refresh_visual()


func _physics_process(_delta: float) -> void:
	refresh_visual()


func refresh_visual() -> void:
	visible = false
	if owner_id == 0 or not is_instance_id_valid(owner_id):
		return
	var field: ElementField = instance_from_id(owner_id) as ElementField
	if field == null or field.is_queued_for_deletion() or field.context == null:
		return
	var payload: SpellSnapshot = field.context.snapshot
	elapsed = field.age
	radius = maxf(0.0, payload.effect_radius)
	duration = maxf(0.001, payload.effect_duration)
	# The contact ring appears immediately, settles, then fades during the
	# field's last authored 0.2 seconds. Hitstop freezes field.age upstream.
	alpha = (0.55 + 0.45 * clampf(elapsed / 0.10, 0.0, 1.0)) * clampf((duration - elapsed) / 0.20, 0.0, 1.0)
	visible = radius > 0.0 and alpha > 0.0
	ART.seek(_art_layers, Vector2.ONE * radius * 2.0, alpha * 0.66, elapsed, ART.FIELD, style_id, tint)
	queue_redraw()


func _draw() -> void:
	if _art_ready:
		# The original damage radius remains explicit beneath the painted field.
		draw_arc(Vector2.ZERO,radius,0.0,TAU,48,Color(tint,alpha*0.35),1.0,true)
		return
	if style_id == &"blizzard":
		_draw_blizzard()
	elif style_id == &"miasma_cloud":
		_draw_miasma()


func _draw_blizzard() -> void:
	var edge := Color(0.015, 0.04, 0.065, 0.82 * alpha)
	var pale: Color = tint.lerp(Color.WHITE, 0.65)
	pale.a = alpha * 0.92
	draw_circle(Vector2.ZERO, radius, Color(tint, alpha * 0.10))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, edge, 5.5, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(tint, alpha * 0.65), 2.0, true)
	for strand: int in 3:
		var wind := PackedVector2Array()
		for point: int in 25:
			var progress: float = point / 24.0
			var angle: float = committed_direction.angle() - elapsed * 1.8 + strand * TAU / 3.0 + progress * PI * 1.1
			wind.append(Vector2.from_angle(angle) * radius * (0.28 + 0.60 * progress))
		draw_polyline(wind, edge, 5.0, true)
		draw_polyline(wind, Color(tint, alpha * 0.78), 2.4, true)
	for flake: int in 10:
		var angle: float = flake * TAU / 10.0 + elapsed * 0.65
		var distance: float = radius * (0.30 + 0.48 * fposmod(flake * 0.618 + elapsed * 0.12, 1.0))
		var center: Vector2 = Vector2.from_angle(angle) * distance
		var size: float = 4.0 + float(flake % 3)
		for spoke: int in 3:
			var arm: Vector2 = Vector2.from_angle(spoke * PI / 3.0 + angle) * size
			draw_line(center - arm, center + arm, edge, 4.0, true)
			draw_line(center - arm, center + arm, pale, 1.6, true)


func _draw_miasma() -> void:
	var edge := Color(0.025, 0.055, 0.015, 0.78 * alpha)
	var pale: Color = tint.lerp(Color(0.85, 1.0, 0.50), 0.45)
	draw_circle(Vector2.ZERO, radius, Color(tint, alpha * 0.11))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, edge, 5.5, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(tint, alpha * 0.60), 2.0, true)
	for wisp: int in 6:
		var angle: float = wisp * TAU / 6.0 + elapsed * 0.30
		var distance: float = radius * (0.30 + 0.20 * sin(elapsed * 1.3 + wisp * 1.7))
		var center: Vector2 = Vector2.from_angle(angle) * distance
		var size: float = radius * (0.17 + 0.035 * sin(elapsed * 1.8 + wisp))
		var cloud := PackedVector2Array()
		for point: int in 17:
			var turn: float = point * TAU / 16.0
			var ripple: float = 1.0 + 0.12 * sin(turn * 4.0 + elapsed * 1.6 + wisp)
			var offset := Vector2(cos(turn) * size * 1.2, sin(turn) * size * 0.72) * ripple
			cloud.append(center + offset.rotated(committed_direction.angle()))
		draw_colored_polygon(cloud, Color(tint, alpha * 0.19))
		draw_polyline(cloud, edge, 3.2, true)
		draw_polyline(cloud, Color(pale, alpha * 0.63), 1.3, true)
	for mote: int in 8:
		var angle: float = mote * TAU / 8.0 - elapsed * 0.4
		var point: Vector2 = Vector2.from_angle(angle) * radius * (0.55 + 0.18 * sin(elapsed + mote))
		draw_circle(point, 3.3, edge)
		draw_circle(point, 1.6, Color(pale, alpha * 0.8))


func _exit_tree() -> void:
	owner_id = 0
	tracked_root_id = 0
	_art_layers.clear()

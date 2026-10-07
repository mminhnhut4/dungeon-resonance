class_name ActorShadow
extends Node2D
## Actor-owned ellipse projected only against World (layer 1). Cosmetic queries
## are bounded to 30 Hz and reuse geometry/query data; never affect collisions.

const MAX_PROJECTION: float = 512.0
const FADE_HEIGHT: float = 320.0
const QUERY_INTERVAL: float = 1.0 / 30.0
const ELLIPSE_SEGMENTS: int = 24

var ground_position: Vector2 = Vector2.ZERO
var drop_height: float = 0.0
var shadow_strength: float = 0.32
var ellipse_scale: float = 1.0
var projection_count: int = 0
var has_ground: bool = false
var _actor_id: int = 0
var _feedback_id: int = 0
var _foot_offset: Vector2 = Vector2.ZERO
var _width: float = 24.0
var _height: float = 5.0
var _query_elapsed: float = QUERY_INTERVAL
var _points: PackedVector2Array = PackedVector2Array()
var _ray: PhysicsRayQueryParameters2D


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 1
	process_physics_priority = 30
	var canvas_material := CanvasItemMaterial.new()
	canvas_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = canvas_material
	_ray = PhysicsRayQueryParameters2D.new()
	_ray.collision_mask = 1
	_ray.collide_with_areas = false
	_ray.hit_from_inside = false
	_rebuild_ellipse()


func bind(actor: CharacterBody2D, foot_offset: Vector2 = Vector2.ZERO, width: float = 24.0, height: float = 5.0, feedback: Node = null) -> void:
	_actor_id = actor.get_instance_id() if is_instance_valid(actor) else 0
	_feedback_id = feedback.get_instance_id() if is_instance_valid(feedback) else 0
	_foot_offset = foot_offset
	_width = clampf(width, 8.0, 100.0)
	_height = clampf(height, 2.0, 20.0)
	_query_elapsed = QUERY_INTERVAL
	visible = _actor_id != 0
	_rebuild_ellipse()


func _rebuild_ellipse() -> void:
	_points.resize(ELLIPSE_SEGMENTS)
	for point: int in ELLIPSE_SEGMENTS:
		var angle: float = TAU * float(point) / float(ELLIPSE_SEGMENTS)
		_points[point] = Vector2(cos(angle) * _width * 0.5, sin(angle) * _height * 0.5)
	queue_redraw()


func set_feedback(feedback: Node) -> void:
	_feedback_id = feedback.get_instance_id() if is_instance_valid(feedback) else 0


func _physics_process(delta: float) -> void:
	if _actor_id == 0 or not is_instance_id_valid(_actor_id):
		visible = false
		return
	if _feedback_id != 0 and is_instance_id_valid(_feedback_id):
		var feedback: Node = instance_from_id(_feedback_id) as Node
		if feedback.has_method("is_frozen") and bool(feedback.call("is_frozen")):
			return
	var actor: CharacterBody2D = instance_from_id(_actor_id) as CharacterBody2D
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return
	var foot: Vector2 = actor.to_global(_foot_offset)
	_query_elapsed += maxf(delta, 0.0)
	if _query_elapsed >= QUERY_INTERVAL:
		_query_elapsed = 0.0
		_ray.from = foot + Vector2(0, -2.0)
		_ray.to = foot + Vector2(0, MAX_PROJECTION)
		var contact: Dictionary = actor.get_world_2d().direct_space_state.intersect_ray(_ray)
		projection_count += 1
		has_ground = not contact.is_empty()
		ground_position = contact["position"] if has_ground else foot
	# Follow cached ground horizontally between queries. Height may change every
	# physics tick, without another ray or a new Image/Texture allocation.
	global_position = Vector2(foot.x, ground_position.y - 0.5)
	rotation = 0.0
	drop_height = maxf(0.0, ground_position.y - foot.y) if has_ground else 0.0
	var altitude: float = clampf(drop_height / FADE_HEIGHT, 0.0, 1.0)
	ellipse_scale = lerpf(1.0, 0.4, altitude)
	shadow_strength = 0.32 * pow(1.0 - altitude, 1.2) if has_ground else 0.10
	scale = Vector2(ellipse_scale, ellipse_scale)
	queue_redraw()


func _draw() -> void:
	if _points.size() == ELLIPSE_SEGMENTS:
		draw_colored_polygon(_points, Color(0.015, 0.025, 0.04, shadow_strength))


func _exit_tree() -> void:
	_actor_id = 0
	_feedback_id = 0
	_ray = null

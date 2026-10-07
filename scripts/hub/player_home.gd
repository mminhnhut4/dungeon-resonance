class_name PlayerHome
extends Node2D
## A separate indoor scene beside the yard; PrologueHub keeps the same Player.

var entry_point: Marker2D
var exit_point: Marker2D
var bed_point: Marker2D
var floor_body: StaticBody2D

func _ready() -> void:
	var wall := Polygon2D.new()
	wall.polygon = PackedVector2Array([Vector2(0, 180), Vector2(1280, 180), Vector2(1280, 640), Vector2(0, 640)])
	wall.color = Color(0.14, 0.12, 0.10)
	wall.z_index = -15
	add_child(wall)
	floor_body = StaticBody2D.new()
	floor_body.name = "HomeFloor"
	floor_body.position = Vector2(640, 680)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1280, 80)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	var floor_visual := Polygon2D.new()
	floor_visual.polygon = PackedVector2Array([Vector2(-640, -40), Vector2(640, -40), Vector2(640, 40), Vector2(-640, 40)])
	floor_visual.color = Color(0.28, 0.22, 0.15)
	floor_body.add_child(floor_visual)
	add_child(floor_body)
	entry_point = _marker("EntryPoint", Vector2(200, 640), "NHÀ LỮ KHÁCH")
	exit_point = _marker("ExitPoint", Vector2(130, 640), "E · Trở ra sân")
	bed_point = _marker("BedPoint", Vector2(800, 640), "E · Nghỉ ngơi")
	var bed := Polygon2D.new()
	bed.position = bed_point.position
	bed.polygon = PackedVector2Array([Vector2(-55, 0), Vector2(-55, -30), Vector2(55, -30), Vector2(55, 0)])
	bed.color = Color(0.40, 0.29, 0.22)
	add_child(bed)

func _marker(node_name: String, location: Vector2, caption: String) -> Marker2D:
	var marker := Marker2D.new()
	marker.name = node_name
	marker.position = location
	add_child(marker)
	var label := Label.new()
	label.text = caption
	label.position = Vector2(-90, -85)
	label.set_meta(&"debug_keep", true)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(label)
	return marker


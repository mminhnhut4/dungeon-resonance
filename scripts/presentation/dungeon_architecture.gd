class_name DungeonArchitecture
extends Node2D
## Existing stone textures + masonry supports. Never adds physics or rewards.
const STONE: AtlasTexture = preload("res://assets/environment/tilesets/regions/foyer_floor_stone.tres")
const COLUMN: AtlasTexture = preload("res://assets/environment/tilesets/regions/foyer_chained_talisman_column.tres")
const KEY: Shader = preload("res://shaders/foyer_stone_key.gdshader")
var grounded_props: Array[Sprite2D] = []
var stone_material: ShaderMaterial

func initialize(room: DungeonRoom) -> void:
	name = "DungeonArchitecture"
	stone_material = ShaderMaterial.new()
	stone_material.shader = KEY
	stone_material.set_shader_parameter("jade_emission",0.05)
	# Back-plane pillars carry balcony arches down to the unchanged stone floor.
	# They deliberately do not obstruct the foreground combat lane.
	for x: float in ([57,450,807,1100] if room.room_number==1 else [57,510,757,1100] if room.room_number==2 else [75,1140]):
		var column := _sprite(COLUMN,Vector2(x-16,640-196),Vector2(32,196))
		column.name = "GroundedMasonryColumn"
		column.z_index = -3
		grounded_props.append(column)
	if room.room_number < 3:
		# Enclosed wall alcove carries the existing secret chest at (90,366).
		_face(Rect2(32,219,12,163),Color("344d51"),-4)
		_face(Rect2(32,382,300,44),Color("304448"),-4)
		_arch(Vector2(180,460),Vector2(470 if room.room_number==1 else 540,460))
		_arch(Vector2(790 if room.room_number==1 else 740,460),Vector2(1120,460))
		# Peripheral stair treads are visually attached to a back-wall stair stringer.
		_stringer(PackedVector2Array([Vector2(40,640),Vector2(40,546),Vector2(130,546),Vector2(180,460)]))
		_stringer(PackedVector2Array([Vector2(1178,640),Vector2(1178,546),Vector2(1092,546),Vector2(1120,460)]))
	else:
		# Boss room has an uninterrupted arena; side pilasters frame the retreat.
		_arch(Vector2(52,316),Vector2(1165,316))
	for body: Node in room.get_children():
		if not body is StaticBody2D or not body.has_meta(&"dungeon_architectural_surface"): continue
		var shape := body.get_node("Shape") as CollisionShape2D
		var rectangle: Rect2 = Rect2(body.position-shape.shape.size*0.5,shape.shape.size)
		for visual: Node in body.get_children():
			if visual is Polygon2D: visual.hide()
		var count: int = ceili(rectangle.size.x/100)
		for index: int in count:
			_sprite(STONE,rectangle.position+Vector2(index*rectangle.size.x/count,0),Vector2(rectangle.size.x/count,rectangle.size.y))
		var edge := Line2D.new()
		edge.points = PackedVector2Array([rectangle.position,Vector2(rectangle.end.x,rectangle.position.y)])
		edge.default_color = Color("b6ba9b")
		edge.width = 2
		add_child(edge)

func _arch(a: Vector2, b: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([a+Vector2(0,16),a.lerp(b,0.25)+Vector2(0,50),a.lerp(b,0.5)+Vector2(0,64),a.lerp(b,0.75)+Vector2(0,50),b+Vector2(0,16)])
	line.default_color = Color("506564")
	line.width = 9
	line.z_index = -4
	add_child(line)

func _stringer(points: PackedVector2Array) -> void:
	var line := Line2D.new()
	line.points = points
	line.default_color = Color("4e6461")
	line.width = 10
	line.z_index = -4
	add_child(line)

func _sprite(texture: Texture2D, at: Vector2, size: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = at
	sprite.scale = size/texture.get_size()
	sprite.material = stone_material
	add_child(sprite)
	return sprite

func _face(rectangle: Rect2, color: Color, order: int) -> void:
	var face := Polygon2D.new()
	face.polygon = PackedVector2Array([rectangle.position,Vector2(rectangle.end.x,rectangle.position.y),rectangle.end,Vector2(rectangle.position.x,rectangle.end.y)])
	face.color = color
	face.z_index = order
	add_child(face)

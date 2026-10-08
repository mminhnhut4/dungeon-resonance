class_name SectRoomArt
extends Node2D
## Four distinct painted plates; lifetime owned by current room, no actor/collision edits.
static func attach(room: ExteriorRoom) -> Node2D:
	if room.room_id not in SectRouteCatalog.ROOMS: return null
	var art:=SectRoomArt.new(); art.name="SectRoomArt"; room.add_child(art)
	var texture: Texture2D=load("res://assets/environment/sects_v1/%s.png" % room.room_id) as Texture2D
	if texture==null: art.queue_free(); return null
	var sprite:=Sprite2D.new(); sprite.name="PaintedSectBackdrop"; sprite.texture=texture
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.position=room.bounds.get_center()
	var ratio: float=maxf(room.bounds.size.x/texture.get_width(),room.bounds.size.y/texture.get_height())
	sprite.scale=Vector2.ONE*ratio; sprite.z_index=-30
	var material:=CanvasItemMaterial.new(); material.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED; sprite.material=material
	art.add_child(sprite)
	for child: Node in room.get_children():
		if child is Polygon2D and child.z_index<=-18: child.hide()
	ExistingRouteTerrain.attach(room)
	return art

class_name DepthTerrainArt
extends Node2D
## Bounded atlas skin only; the supplied StaticBody2D rectangles remain authoritative.
const ATLAS_PATH: String="res://assets/environment/depth_v1/depth_terrain.png"
const FALLBACK: AtlasTexture=preload("res://assets/environment/tilesets/regions/foyer_floor_stone.tres")
const TILE_WIDTH: float=128.0
const MAX_SPRITES: int=64
const GUTTER: float=4.0
## The delivered atlas has cap/body seam at ~.345h; select actual painted bands.
const ROW_BANDS: Array[Vector2]=[Vector2(.24,.34),Vector2(.35,1.0)]
var raster_bound: bool=false
var floor_number: int=0
var sprites: Array[Sprite2D]=[]
var surface_roots: Array[Node2D]=[]
var regions: Array[AtlasTexture]=[]
var _hidden: Array[Dictionary]=[]
func rebuild(surfaces: Array[StaticBody2D],number: int,palette: Color) -> bool:
	clear()
	if number<1 or number>5: return false
	floor_number=number
	var atlas: Texture2D
	if ResourceLoader.exists(ATLAS_PATH): atlas=load(ATLAS_PATH) as Texture2D
	raster_bound=atlas!=null and atlas.get_width()>=50 and atlas.get_height()>=20
	for row: int in 2:
		var region:=AtlasTexture.new()
		if raster_bound:
			region.atlas=atlas
			var column: float=atlas.get_width()/5.0
			var band: Vector2=ROW_BANDS[row]
			var start:=Vector2(ceilf((number-1)*column)+GUTTER,ceilf(band.x*atlas.get_height())+GUTTER)
			var end:=Vector2(floorf(number*column)-GUTTER,floorf(band.y*atlas.get_height())-GUTTER)
			region.region=Rect2(start,end-start)
		else:
			region.atlas=FALLBACK.atlas; region.region=FALLBACK.region
		region.filter_clip=true; regions.append(region)
	for body: StaticBody2D in surfaces:
		if not is_instance_valid(body): continue
		var shape: CollisionShape2D=body.get_node_or_null("Shape") as CollisionShape2D
		if shape==null or not shape.shape is RectangleShape2D: continue
		var size: Vector2=(shape.shape as RectangleShape2D).size
		if size.x<=0 or size.y<=0: continue
		for child: Node in body.get_children():
			if child is Polygon2D:
				_hidden.append({"visual":weakref(child),"visible":child.visible}); child.hide()
		var decoration:=Node2D.new(); decoration.name="DepthTerrainSurface"; decoration.z_index=-2
		body.add_child(decoration); surface_roots.append(decoration)
		var cap_height: float=minf(size.y,12.0 if size.y>=40.0 else 8.0)
		var origin: Vector2=shape.position-size*.5
		for row: int in 2:
			var height: float=cap_height if row==0 else size.y-cap_height
			if height<=0: continue
			var offset: float=0.0
			while offset<size.x-.001:
				if sprites.size()>=MAX_SPRITES:
					clear(); return false
				var width: float=minf(TILE_WIDTH,size.x-offset)
				var source: AtlasTexture=regions[row]
				var tile:=AtlasTexture.new(); tile.atlas=source.atlas; tile.filter_clip=true
				tile.region=source.region; tile.region.size.x*=width/TILE_WIDTH
				if raster_bound:
					# Keep comparable texel density on narrow shelves instead of squeezing the full wall panel.
					var source_height: float=minf(source.region.size.y,source.region.size.x*height/TILE_WIDTH)
					if row==0: tile.region.position.y+=(source.region.size.y-source_height)*.5
					tile.region.size.y=source_height
				var sprite:=Sprite2D.new(); sprite.name="TerrainCap" if row==0 else "TerrainBody"
				sprite.set_meta(&"depth_terrain_row",row)
				sprite.centered=false; sprite.texture=tile; sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
				sprite.position=origin+Vector2(offset,0 if row==0 else cap_height)
				sprite.scale=Vector2(width,height)/tile.get_size()
				sprite.modulate=Color.WHITE if raster_bound else palette.lightened(.15)
				decoration.add_child(sprite); sprites.append(sprite); offset+=width
	return not sprites.is_empty()
func clear() -> void:
	for record: Dictionary in _hidden:
		var visual: Object=(record["visual"] as WeakRef).get_ref()
		if is_instance_valid(visual): (visual as CanvasItem).visible=bool(record["visible"])
	_hidden.clear()
	for decoration: Node2D in surface_roots:
		if is_instance_valid(decoration):
			decoration.get_parent().remove_child(decoration); decoration.queue_free()
	surface_roots.clear(); sprites.clear(); regions.clear(); raster_bound=false; floor_number=0
func _exit_tree() -> void: clear()

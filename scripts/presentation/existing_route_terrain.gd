class_name ExistingRouteTerrain
extends Node2D
## Texture/UV skin only. Existing polygon vertices and physical owners remain untouched.
const PATH: String="res://assets/environment/exterior/rendered_v2/route_terrain.png"
const FALLBACK: Texture2D=preload("res://assets/environment/exterior/pilgrimage_v1/pilgrimage_terrain_material.png")
const THEMES: Dictionary[StringName,int]={&"o01_p03":0,&"o01_p04":1,&"o02_b01":2,&"o02_b02":3,&"o02_b03":3,&"o02_b04":2}
const TILE_WIDTH: float=128.0
const MAX_POLYGONS: int=48
const MAX_FLOOR_POINTS: int=32
const GUTTER: float=4.0
const CAP_BAND: Vector2=Vector2(22.0/887.0,125.0/887.0)
const BODY_BAND: Vector2=Vector2(253.0/887.0,1.0)
const CODE: String="""shader_type canvas_item;
render_mode unshaded;
uniform vec4 body_region;
uniform vec4 cap_region;
uniform float cap_depth = 0.0;
uniform vec2 floor_points[32];
uniform int floor_count = 0;
void fragment(){
 vec2 px = UV / TEXTURE_PIXEL_SIZE;
 // Cartesian UV must remain affine across the authored polygon's triangles.
 // Flattening all top vertices to UV.y=0 collapses triangles on sloped maps.
 if(floor_count > 1){
  float floor_y = floor_points[0].y;
  for(int i=0; i<31; i++){
   if(i >= floor_count-1){break;}
   vec2 a = floor_points[i];
   vec2 b = floor_points[i+1];
   if(px.x >= a.x && px.x <= b.x){
    floor_y = mix(a.y,b.y,(px.x-a.x)/(b.x-a.x));
    break;
   }
  }
  px.y -= floor_y;
 }
 vec4 region = body_region;
 if(cap_depth > 0.0 && px.y >= 0.0 && px.y < cap_depth){region = cap_region;}
 vec2 phase = fract(px / region.zw);
 vec2 sample_px = region.xy + vec2(0.5) + phase * (region.zw - vec2(1.0));
 COLOR = texture(TEXTURE, sample_px * TEXTURE_PIXEL_SIZE);
}
"""
static var _shader: Shader
var raster_bound: bool=false
var owner_id: int=0
var skinned: Array[Dictionary]=[]
var source_regions: Array[Rect2]=[]
static func attach(room: ExteriorRoom) -> Node2D:
	if not THEMES.has(room.room_id) or room.route_id!=ExteriorRouteCatalog.MAIN: return null
	var existing: Node2D=room.get_node_or_null("ExistingRouteTerrain") as Node2D
	if existing==null:
		existing=ExistingRouteTerrain.new(); existing.name="ExistingRouteTerrain"; room.add_child(existing)
	existing.rebuild(room); return existing
func rebuild(room: ExteriorRoom) -> bool:
	clear()
	if not is_instance_valid(room) or not THEMES.has(room.room_id) or room.route_id!=ExteriorRouteCatalog.MAIN: return false
	var texture: Texture2D=load(PATH) as Texture2D if ResourceLoader.exists(PATH) else FALLBACK
	raster_bound=texture!=FALLBACK
	owner_id=room.get_instance_id()
	if _shader==null: _shader=Shader.new(); _shader.code=CODE
	var column: float=texture.get_width()/4.0 if raster_bound else float(texture.get_width())
	var theme: int=int(THEMES[room.room_id]) if raster_bound else 0
	for band: Vector2 in [CAP_BAND,BODY_BAND]:
		var start:=Vector2(ceilf(theme*column)+GUTTER,ceilf(band.x*texture.get_height())+GUTTER)
		var end:=Vector2(floorf((theme+1)*column)-GUTTER,floorf(band.y*texture.get_height())-GUTTER)
		source_regions.append(Rect2(start,end-start))
	var source_scale: float=source_regions[1].size.x/TILE_WIDTH
	for child: Node in room.get_children():
		if child is StaticBody2D and child!=room.gate:
			for visual: Node in child.get_children():
				if visual is Polygon2D and visual.color.a>=.99: _skin(visual as Polygon2D,room,texture,source_scale,true)
		elif child is Polygon2D and child!=room.gate_visual and child.z_index>=-13 and child.z_index<=-1 and child.color.a>=.99:
			_skin(child as Polygon2D,room,texture,source_scale,false)
	return not skinned.is_empty()
func _skin(polygon: Polygon2D,room: ExteriorRoom,texture: Texture2D,source_scale: float,physical: bool) -> void:
	if skinned.size()>=MAX_POLYGONS: return
	var mapping:=PackedVector2Array()
	var ground: bool=physical and polygon.polygon.size()==room.surface.size()*2
	if ground and room.surface.size()>MAX_FLOOR_POINTS: return
	for point: Vector2 in polygon.polygon:
		var world: Vector2=room.to_local(polygon.to_global(point))
		mapping.append(world*source_scale)
	skinned.append({"item":weakref(polygon),"texture":polygon.texture,"material":polygon.material,"uv":polygon.uv.duplicate(),"color":polygon.color,"ground":ground,"scale":source_scale})
	var ink:=ShaderMaterial.new(); ink.shader=_shader
	ink.set_shader_parameter("body_region",Vector4(source_regions[1].position.x,source_regions[1].position.y,source_regions[1].size.x,source_regions[1].size.y))
	ink.set_shader_parameter("cap_region",Vector4(source_regions[0].position.x,source_regions[0].position.y,source_regions[0].size.x,source_regions[0].size.y))
	ink.set_shader_parameter("cap_depth",8.0*source_scale if ground else 0.0)
	var floor_points:=PackedVector2Array()
	for index: int in MAX_FLOOR_POINTS:
		floor_points.append(room.surface[mini(index,room.surface.size()-1)]*source_scale if ground else Vector2.ZERO)
	ink.set_shader_parameter("floor_points",floor_points)
	ink.set_shader_parameter("floor_count",room.surface.size() if ground else 0)
	polygon.texture=texture; polygon.material=ink; polygon.uv=mapping; polygon.color=Color.WHITE
func clear() -> void:
	for record: Dictionary in skinned:
		var item: Object=(record["item"] as WeakRef).get_ref()
		if is_instance_valid(item):
			var polygon: Polygon2D=item as Polygon2D
			polygon.texture=record["texture"]; polygon.material=record["material"]; polygon.uv=record["uv"]; polygon.color=record["color"]
	skinned.clear(); source_regions.clear(); owner_id=0; raster_bound=false
func _exit_tree() -> void: clear()

extends SceneTree
## Golden physical signatures predate terrain polish; raster checks cannot certify native pixels.
const RoomScript=preload("res://scripts/rooms/depth_room.gd")
const TerrainScript=preload("res://scripts/presentation/depth_terrain_art.gd")
const Catalog=preload("res://data/depth_floor_catalog.gd")
const GOLDEN: Array[String]=["09498099ae66e13eef2211755ba86b58fb782cfea7ef2e990181fbaa5be4488d","03bef92cea49c3b5dd244fa8f6fcfa7d037dfe4377c7868e6832fa7f87948194","09498099ae66e13eef2211755ba86b58fb782cfea7ef2e990181fbaa5be4488d","9eca28432e950d2b6fe3e803e441687416a720b1ce2f21fb1eee1cff50b598dc","973cdd4428cfc21d35ac42e7e611a7820a073e66691e7bbcd7c56540a99a353a","9eca28432e950d2b6fe3e803e441687416a720b1ce2f21fb1eee1cff50b598dc","8baf91136635ea98afa17867abdd6837e0741d73a1112bde8b13ab2e45a366fa","ef1f84b73d28907cbb14e4b4c9b8331a093dc4180f388cfd6d1bd6c454d1c8ec","8baf91136635ea98afa17867abdd6837e0741d73a1112bde8b13ab2e45a366fa","677600b609a2093e7e0a6af58825c3d6c965e61e67a61f334a6e800d235e8018","528d987ae34a94bb0b12cddf4fb3238468046475fae0926c963f35064f955f50","677600b609a2093e7e0a6af58825c3d6c965e61e67a61f334a6e800d235e8018","f3c22e4ec355d18e748cbd1794b42e38caacb3ef35e8cac969e4f5bafdd64d5c","f24cb745e572c95835f5dc96519d46e5011370f0da4c4ab11ba656086863403c","f3c22e4ec355d18e748cbd1794b42e38caacb3ef35e8cac969e4f5bafdd64d5c"] # Filled once from the frozen pre-terrain room, not current implementation.
var checks: int=0
var failures: int=0
var hz: int=60
var require_raster: bool=false
func _initialize() -> void: _run.call_deferred()
func _step(count: int=3) -> void:
	for _index: int in count: await physics_frame; await process_frame
func _check(ok: bool,text: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS: " if ok else "FAIL: ")+text)
static func physical_signature(room: DungeonRoom) -> String:
	var bodies: Array[Dictionary]=[]
	for candidate: Node in room.get_children():
		if not candidate is StaticBody2D: continue
		var body: StaticBody2D=candidate as StaticBody2D
		var shape: CollisionShape2D=body.get_node("Shape") as CollisionShape2D
		var rectangle: RectangleShape2D=shape.shape as RectangleShape2D
		bodies.append({"name":String(body.name),"position":[body.position.x,body.position.y],"scale":[body.scale.x,body.scale.y],"rotation":body.rotation,"layer":body.collision_layer,"mask":body.collision_mask,"disable_mode":body.disable_mode,"shape_position":[shape.position.x,shape.position.y],"shape_scale":[shape.scale.x,shape.scale.y],"shape_rotation":shape.rotation,"size":[rectangle.size.x,rectangle.size.y],"disabled":shape.disabled,"one_way":shape.one_way_collision,"margin":shape.one_way_collision_margin})
	var points: Dictionary={}
	for key: StringName in room.traversal_points:
		var point: Vector2=room.traversal_points[key]; points[String(key)]=[point.x,point.y]
	return JSON.stringify({"bodies":bodies,"points":points,"number":room.room_number,"locked":room.locked},"",true,true).sha256_text()
func _inspect_art(room: DungeonRoom) -> void:
	var art: Node2D=room.get("terrain_art") as Node2D
	_check(art!=null and art.get("sprites").size()>0 and art.get("sprites").size()<=TerrainScript.MAX_SPRITES,"Depth%d bounded textured skin exists" % room.room_number)
	if art==null: return
	_check(not require_raster or art.get("raster_bound"),("Depth%d required dedicated raster bound" if require_raster else "Depth%d textured fallback/raster binding allowed during asset staging") % room.room_number)
	var rows: Array=art.get("regions")
	_check(rows.size()==2 and rows.all(func(texture: AtlasTexture)->bool:return texture.filter_clip),"Depth%d row regions clip atlas filtering" % room.room_number)
	if art.get("raster_bound"):
		for row: int in 2:
			var column: float=rows[row].atlas.get_width()/5.0
			var band: Vector2=TerrainScript.ROW_BANDS[row]
			var expected:=Rect2(Vector2((room.room_number-1)*column,band.x*rows[row].atlas.get_height()),Vector2(column,(band.y-band.x)*rows[row].atlas.get_height()))
			_check(expected.encloses(rows[row].region) and rows[row].region.position.x>=expected.position.x+TerrainScript.GUTTER-.01 and rows[row].region.end.x<=expected.end.x-TerrainScript.GUTTER+.01,"Dedicated region stays inside its theme/row with anti-bleed gutter")
	for body: StaticBody2D in room.get("surfaces"):
		var shape: CollisionShape2D=body.get_node("Shape") as CollisionShape2D
		var size: Vector2=(shape.shape as RectangleShape2D).size
		var origin: Vector2=shape.position-size*.5
		var decoration: Node2D=body.get_node("DepthTerrainSurface") as Node2D
		_check(decoration!=null and decoration.z_index<0 and decoration.get_parent()==body,"Foreground skin follows actual body behind actors")
		var area: float=0.0
		var exact: bool=true
		var left: Array[float]=[origin.x,origin.x]
		var cap: float=minf(size.y,12.0 if size.y>=40 else 8.0)
		for sprite: Sprite2D in decoration.get_children():
			var row: int=int(sprite.get_meta(&"depth_terrain_row",-1))
			var rendered: Vector2=sprite.texture.get_size()*sprite.scale
			area+=rendered.x*rendered.y
			exact=exact and absf(sprite.position.x-left[row])<.001 and absf(sprite.position.y-origin.y-(0 if row==0 else cap))<.001 and absf(rendered.y-(cap if row==0 else size.y-cap))<.001 and rendered.x<=TerrainScript.TILE_WIDTH+.001
			left[row]+=rendered.x
			var texture: AtlasTexture=sprite.texture as AtlasTexture
			exact=exact and texture.filter_clip and texture.atlas==rows[row].atlas and rows[row].region.encloses(texture.region)
		# Compare area as average covered height in pixels; Vector2 uses float32.
		if not exact or absf(area/size.x-size.y)>=.001 or absf(left[0]-origin.x-size.x)>=.001 or absf(left[1]-origin.x-size.x)>=.001:
			print("TERRAIN RECT_DEBUG ",JSON.stringify({"body":String(body.name),"exact":exact,"area":area,"expected_area":size.x*size.y,"left":left,"origin":[origin.x,origin.y],"size":[size.x,size.y]}))
		_check(exact and absf(area/size.x-size.y)<.001 and absf(left[0]-origin.x-size.x)<.001 and absf(left[1]-origin.x-size.x)<.001,"Cap/body cover collider rectangle within .001pixel with clipped final tile")
		_check(body.get_children().filter(func(child: Node)->bool:return child is Polygon2D).all(func(poly: Polygon2D)->bool:return not poly.visible),"Only the replaced placeholder is hidden")
	var before: String=physical_signature(room)
	art.clear(); await _step()
	_check(physical_signature(room)==before and art.get("sprites").is_empty() and room.find_children("DepthTerrainSurface","Node2D",true,false).is_empty(),"Skin clear removes all decorations without mutating physics")
	_check(room.get("surfaces").all(func(body: StaticBody2D)->bool:return body.get_children().filter(func(child: Node)->bool:return child is Polygon2D).all(func(poly: Polygon2D)->bool:return poly.visible)),"Skin clear restores original placeholder visibility")
	_check(art.rebuild(room.get("surfaces"),room.room_number,Catalog.floor_data(room.room_number)["palette"]),"Same room rebinds without duplicate sprites")
	_check(physical_signature(room)==before,"Skin rebind keeps byte-equivalent physics/traversal")
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz=int(argument.trim_prefix("--hz="))
	require_raster=OS.get_cmdline_user_args().has("--require-raster")
	if DisplayServer.get_name()!="headless" or hz not in [60,120]: print("FAIL: terrain test needs headless60/120"); quit(2); return
	Engine.physics_ticks_per_second=hz; AudioServer.set_bus_mute(0,true)
	_check(GOLDEN.size()==15,"Physical golden covers five floors × locked/unlocked/relocked")
	if GOLDEN.size()!=15: quit(2); return
	if require_raster:
		var atlas: Texture2D=load(TerrainScript.ATLAS_PATH) as Texture2D
		var picture: Image=atlas.get_image() if atlas!=null else null
		_check(picture!=null and not picture.is_empty(),"Dedicated raster source decodes as actual pixels")
		if picture==null or picture.is_empty(): quit(2); return
		var fingerprints: Dictionary={}
		for number: int in [1,2,3,4,5]:
			for row: int in 2:
				var column: float=picture.get_width()/5.0
				var band: Vector2=TerrainScript.ROW_BANDS[row]
				var height: float=(band.y-band.x)*picture.get_height()
				var colors: Dictionary={}; var samples: Array[String]=[]; var opaque: bool=true
				for y: int in 8:
					for x: int in 8:
						var pixel: Color=picture.get_pixel(int((number-1)*column+(x+.5)*column/8),int(band.x*picture.get_height()+(y+.5)*height/8))
						colors[pixel.to_html()]=true; samples.append(pixel.to_html()); opaque=opaque and pixel.a>=.99
				var fingerprint: String=JSON.stringify(samples).sha256_text()
				_check(colors.size()>4 and opaque,"Theme%d row%d has opaque material detail rather than flat/empty pixels" % [number,row])
				_check(not fingerprints.has(fingerprint),"Theme/row sample differs from previously visited material")
				fingerprints[fingerprint]=true
	for number: int in [1,2,3,4,5]:
		var room: DungeonRoom=RoomScript.new() as DungeonRoom; room.room_number=number; root.add_child(room); await _step()
		for variant: int in [0,1,2]:
			room.set_locked(variant!=1); await _step()
			_check(physical_signature(room)==GOLDEN[(number-1)*3+variant],"Depth%d collider/transforms/door/traversal byte-equivalent variant%d" % [number,variant])
		await _inspect_art(room)
		var ids: Array[int]=[]
		for sprite: Sprite2D in room.get("terrain_art").get("sprites"): ids.append(sprite.get_instance_id())
		room.queue_free(); await _step(5)
		_check(ids.all(func(id: int)->bool:return not is_instance_id_valid(id)),"Room teardown releases every terrain sprite")
	root.get_node("AudioManager").call("shutdown")
	print("RESULT DepthTerrain checks=%d failures=%d hz=%d raster_required=%s" % [checks,failures,hz,require_raster]); quit(0 if failures==0 else 1)

extends SceneTree
const Terrain=preload("res://scripts/presentation/existing_route_terrain.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void: _run.call_deferred()
func _step(count: int=3) -> void:
	for _index: int in count: await physics_frame; await process_frame
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)
func _snapshot(room: ExteriorRoom) -> String:
	var records: Array[Dictionary]=[]
	for child: Node in room.get_children():
		if child is StaticBody2D:
			var shapes: Array[Dictionary]=[]
			for shape: Node in child.get_children():
				if shape is CollisionPolygon2D: shapes.append({"id":shape.get_instance_id(),"polygon":shape.polygon,"transform":shape.transform,"disabled":shape.disabled,"one_way":shape.one_way_collision,"margin":shape.one_way_collision_margin})
			records.append({"id":child.get_instance_id(),"transform":child.transform,"layer":child.collision_layer,"mask":child.collision_mask,"shapes":shapes})
		elif child is Label: records.append({"id":child.get_instance_id(),"transform":child.get_transform(),"visible":child.visible,"text":child.text})
		elif child is Line2D: records.append({"id":child.get_instance_id(),"points":child.points,"transform":child.transform,"width":child.width,"visible":child.visible})
		if child is Polygon2D: records.append({"id":child.get_instance_id(),"polygon":child.polygon,"transform":child.transform,"z":child.z_index,"visible":child.visible})
		if child is StaticBody2D:
			for paint: Node in child.get_children():
				if paint is Polygon2D: records.append({"id":paint.get_instance_id(),"polygon":paint.polygon,"transform":paint.transform,"z":paint.z_index,"visible":paint.visible})
	return JSON.stringify({"records":records,"room_transform":room.transform,"surface":room.surface,"anchors":room.anchors,"interactions":room.interactions,"jumps":room.jumps,"bounds":room.bounds,"width":room.width},"",true,true).sha256_text()
func _run() -> void:
	var hz: int=60
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz=int(argument.trim_prefix("--hz="))
	if DisplayServer.get_name()!="headless" or hz not in [60,120]: print("FAIL: headless60/120 required"); quit(2); return
	Engine.physics_ticks_per_second=hz; AudioServer.set_bus_mute(0,true)
	for key: StringName in Terrain.THEMES:
		var room:=ExteriorRoom.new(); _check(room.configure(key,ExteriorRouteCatalog.MAIN,true),"Existing room constructor succeeds")
		room.position=Vector2(3500,100); root.add_child(room); await _step()
		var before: String=_snapshot(room)
		var art: Node2D=Terrain.attach(room)
		_check(art!=null and art.get("raster_bound") and art.get("skinned").size()>0 and art.get("skinned").size()<=Terrain.MAX_POLYGONS,"Dedicated raster skins bounded authored polygons: "+str(key))
		_check(_snapshot(room)==before,"Collider/vertices/transforms/labels/lines/traversal remain byte-equivalent: "+str(key))
		for record: Dictionary in art.get("skinned"):
			var paint: Polygon2D=record["item"].get_ref() as Polygon2D
			var exact: bool=paint.uv.size()==paint.polygon.size()
			for index: int in paint.polygon.size():
				var world: Vector2=room.to_local(paint.to_global(paint.polygon[index]))
				var expected: Vector2=world*float(record["scale"])
				exact=exact and paint.uv[index].distance_to(expected)<.001
			_check(exact and paint.texture!=null and paint.material is ShaderMaterial,"UV follows physical localworld at fixed128px density without vertex movement")
			_check(paint.texture==load(Terrain.PATH) and paint!=room.gate_visual,"Dedicated source bound; gate paint excluded")
			# Verify the rendering failure mode independently of the mapping formula:
			# nonzero physical triangles must retain nonzero texture-space area.
			var triangles: PackedInt32Array=Geometry2D.triangulate_polygon(paint.polygon)
			var valid_triangles: bool=not triangles.is_empty()
			for triangle: int in range(0,triangles.size(),3):
				var a: int=triangles[triangle]; var b: int=triangles[triangle+1]; var c: int=triangles[triangle+2]
				var area: float=absf((paint.polygon[b]-paint.polygon[a]).cross(paint.polygon[c]-paint.polygon[a]))
				var uv_area: float=absf((paint.uv[b]-paint.uv[a]).cross(paint.uv[c]-paint.uv[a]))
				valid_triangles=valid_triangles and (area<.01 or uv_area>.01)
			_check(valid_triangles,"Authored triangulation has no collapsed UV triangles")
			if record["ground"]:
				var old_collapsed: int=0
				for triangle: int in range(0,triangles.size(),3):
					var a: Vector2=paint.polygon[triangles[triangle]]; var b: Vector2=paint.polygon[triangles[triangle+1]]; var c: Vector2=paint.polygon[triangles[triangle+2]]
					var old_a:=Vector2(a.x,a.y-room.floor_y(a.x)); var old_b:=Vector2(b.x,b.y-room.floor_y(b.x)); var old_c:=Vector2(c.x,c.y-room.floor_y(c.x))
					if absf((b-a).cross(c-a))>.01 and absf((old_b-old_a).cross(old_c-old_a))<.01: old_collapsed+=1
				print("REPRO old flattened-UV nonzero-area triangles collapsed: %s=%d" % [str(key),old_collapsed])
				var material: ShaderMaterial=paint.material as ShaderMaterial
				var floor_points: PackedVector2Array=material.get_shader_parameter("floor_points")
				var valid_floor: bool=int(material.get_shader_parameter("floor_count"))==room.surface.size() and floor_points.size()==Terrain.MAX_FLOOR_POINTS
				for index: int in room.surface.size(): valid_floor=valid_floor and floor_points[index].distance_to(room.surface[index]*float(record["scale"]))<.001
				_check(valid_floor,"Fragment receives exact authored heightfield for cap/body depth")
		art.clear(); _check(_snapshot(room)==before,"Clear leaves identical geometry/markers")
		_check(art.get("skinned").is_empty() and art.rebuild(room),"Clear/rebuild finite and idempotent")
		_check(_snapshot(room)==before,"Rebind still preserves geometry/markers")
		var ref: WeakRef=weakref(art); room.queue_free(); await _step(5)
		_check(ref.get_ref()==null,"Room teardown removes its adapter")
	var tunnel:=ExteriorRoom.new(); tunnel.configure(&"o01_p03",ExteriorRouteCatalog.TUNNEL,false); root.add_child(tunnel); await _step()
	var gate_before: String=_snapshot(tunnel)
	_check(Terrain.attach(tunnel)==null and _snapshot(tunnel)==gate_before,"SC01/tunnel unsupported route retains gate and all source geometry")
	tunnel.queue_free(); await _step(5)
	root.get_node("AudioManager").call("shutdown")
	print("RESULT ExistingRouteTerrain checks=%d failures=%d hz=%d" % [checks,failures,hz]); quit(0 if failures==0 else 1)

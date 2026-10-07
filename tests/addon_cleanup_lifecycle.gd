extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _build_world() -> Node2D:
	var world := Node2D.new()
	world.name = "AddonLifecycleWorld"
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	world.add_child(camera)
	camera.owner = world
	var host := PhantomCameraHost.new()
	host.name = "PhantomCameraHost"
	camera.add_child(host)
	host.owner = world
	var phantom := PhantomCamera2D.new()
	phantom.name = "PhantomCamera2D"
	phantom.position = Vector2(100, 80)
	phantom.priority = 10
	phantom.tween_on_load = false
	phantom.tween_resource.duration = 0.0
	world.add_child(phantom)
	phantom.owner = world
	var shape := SS2D_Shape.new()
	shape.name = "SmartShape"
	world.add_child(shape)
	shape.owner = world
	var points := SS2D_Point_Array.new()
	for point: Vector2 in [Vector2(0, 180), Vector2(180, 180), Vector2(180, 260), Vector2(0, 260)]:
		points.add_point(point)
	shape.set_point_array(points)
	var tree := BeehaveTree.new()
	tree.name = "BeehaveTree"
	tree.process_thread = BeehaveTree.ProcessThread.MANUAL
	var action := ActionLeaf.new()
	action.name = "ActionLeaf"
	tree.add_child(action)
	world.add_child(tree)
	tree.owner = world
	action.owner = world
	return world


func _run() -> void:
	if OS.get_cmdline_user_args().has("--make-editor-fixture"):
		var world: Node2D = _build_world()
		var scene := PackedScene.new()
		_check(scene.pack(world) == OK, "pack actual addon nodes for the editor gate")
		_check(ResourceSaver.save(scene, "res://addons/rmsmartshape/addon_cleanup_editor_fixture.tscn") == OK, "save actual addon editor fixture")
		world.free()
		print("RESULT: %d checks, %d failures" % [checks, failures])
		quit(0 if failures == 0 else 1)
		return
	# Warm up shader/script/resource caches before testing repeated scene lifetime.
	await _cycle(false)
	for frame: int in 6:
		await process_frame
	var start_objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var start_resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for iteration: int in 10:
		await _cycle(iteration % 2 == 0)
	for frame: int in 6:
		await process_frame
	var end_objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var end_resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	_check(end_objects == start_objects, "ten addon scene cycles return to the warmed object baseline")
	_check(end_resources == start_resources, "ten addon scene cycles return to the warmed resource baseline")
	print("ADDON_LIFETIME: objects %d -> %d, resources %d -> %d" % [start_objects, end_objects, start_resources, end_resources])
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _cycle(monitored: bool) -> void:
	var world: Node2D = _build_world()
	root.add_child(world)
	var host: PhantomCameraHost = world.get_node("Camera2D/PhantomCameraHost")
	var phantom: PhantomCamera2D = world.get_node("PhantomCamera2D")
	var camera: Camera2D = world.get_node("Camera2D")
	var shape: SS2D_Shape = world.get_node("SmartShape")
	var tree: BeehaveTree = world.get_node("BeehaveTree")
	tree.custom_monitor = monitored
	tree.blackboard.set_value("lifecycle", 17)
	tree.tick()
	for frame: int in 5:
		await process_frame
	_check(host.get_active_pcam() == phantom and camera.position.distance_to(phantom.position) < 0.1, "Phantom camera tracks a real camera in each scene")
	phantom.draw_limits = monitored
	_check(root.get_node("PhantomCameraManager").draw_limits_2d == monitored, "shared camera debug preference uses manager lifetime")
	_check(shape.get_point_array().get_point_count() == 4, "SmartShape retains actual editable geometry")
	_check(tree.blackboard.get_value("lifecycle") == 17 and tree.status == BeehaveTree.SUCCESS, "Beehave ticks and owns its blackboard")
	var world_ref: WeakRef = weakref(world)
	var points_ref: WeakRef = weakref(shape.get_point_array())
	var board_ref: WeakRef = weakref(tree.blackboard)
	var metric_name: String = tree._process_time_metric_name
	world.queue_free()
	for frame: int in 6:
		await process_frame
	_check(world_ref.get_ref() == null and points_ref.get_ref() == null and board_ref.get_ref() == null, "nodes, SmartShape points and blackboard are released")
	_check(root.get_node("PhantomCameraManager").phantom_camera_2ds.is_empty() and root.get_node("PhantomCameraManager").phantom_camera_hosts.is_empty(), "Phantom registries are empty after freeing a world")
	_check(root.get_node("BeehaveGlobalDebugger")._registered_trees.is_empty() and not Performance.has_custom_monitor(metric_name), "Beehave debugger and performance monitors are released")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

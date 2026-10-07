extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled")
	for directory: String in ["phantom_camera", "rmsmartshape", "beehave", "AsepriteWizard"]:
		var path: String = "res://addons/%s/plugin.cfg" % directory
		var config := ConfigFile.new()
		var installed: bool = config.load(path) == OK
		var mode_valid: bool = not enabled.has(path) if directory == "AsepriteWizard" else enabled.has(path)
		_check(installed and mode_valid, "%s installed in expected enabled/manual mode" % directory)
		# EditorPlugin dependencies are compiled by the separate real editor gate.
		# A gameplay process loads only runtime nodes, matching exported game use.
		var entry_path: String = path.get_base_dir().path_join(config.get_value("plugin", "script"))
		_check(FileAccess.file_exists(entry_path), "%s editor entrypoint is installed" % directory)
	_check(Engine.has_singleton("PhantomCameraManager"), "Phantom manager is registered at runtime")
	var world := Node2D.new()
	root.add_child(world)
	var camera := Camera2D.new()
	world.add_child(camera)
	var host := PhantomCameraHost.new()
	camera.add_child(host)
	var phantom := PhantomCamera2D.new()
	phantom.position = Vector2(100, 80)
	phantom.priority = 10
	phantom.tween_on_load = false
	world.add_child(phantom)
	for frame: int in 5:
		await process_frame
	_check(host.get_active_pcam() == phantom, "Phantom host activates a real 2D camera")
	_check(camera.position.distance_to(phantom.position) < 0.1, "Phantom camera drives Camera2D position")
	var shape := SS2D_Shape.new()
	world.add_child(shape)
	_check(shape.get_point_array() != null, "SmartShape initializes runtime point data")
	var tree := BeehaveTree.new()
	tree.enabled = false
	world.add_child(tree)
	_check(tree.blackboard != null, "Beehave initializes a blackboard")
	world.queue_free()
	for frame: int in 5:
		await process_frame
	var manager: Node = root.get_node("PhantomCameraManager")
	_check(manager.phantom_camera_2ds.is_empty() and manager.phantom_camera_hosts.is_empty(), "Phantom registries release removed cameras")
	var debugger: Node = root.get_node("BeehaveGlobalDebugger")
	_check(debugger._registered_trees.is_empty(), "Beehave debugger releases removed trees without custom monitors")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

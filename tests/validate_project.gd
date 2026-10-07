extends SceneTree
## Fail script warnings as errors in this validation process only.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("debug/gdscript/warnings/treat_warnings_as_errors", true)
	var paths: Array[String] = []
	_collect("res://scripts", paths)
	var failures: int = 0
	for path: String in paths:
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			failures += 1
			print("FAIL script: ", path)
	print("VALIDATE scripts=%d failures=%d" % [paths.size(), failures])
	var scenes: Array[String] = []
	_collect_scenes("res://scenes", scenes)
	for path: String in scenes:
		var scene: PackedScene = load(path) as PackedScene
		if scene == null or not scene.can_instantiate():
			failures += 1
			print("FAIL scene: ", path)
	print("VALIDATE scenes=%d failures=%d" % [scenes.size(), failures])
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)


func _collect(directory: String, paths: Array[String]) -> void:
	var access: DirAccess = DirAccess.open(directory)
	for file: String in access.get_files():
		if file.ends_with(".gd"):
			paths.append(directory.path_join(file))
	for child: String in access.get_directories():
		_collect(directory.path_join(child), paths)


func _collect_scenes(directory: String, paths: Array[String]) -> void:
	var access: DirAccess = DirAccess.open(directory)
	for file: String in access.get_files():
		if file.ends_with(".tscn"):
			paths.append(directory.path_join(file))
	for child: String in access.get_directories():
		_collect_scenes(directory.path_join(child), paths)

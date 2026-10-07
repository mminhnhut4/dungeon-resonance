extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var paths: Array[String] = []
	_collect("res://data", paths)
	for path: String in paths:
		checks += 1
		var resource: Resource = load(path)
		if resource == null or resource.get_script() == null:
			failures += 1
			print("FAIL: Custom Resource could not load: ", path)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _collect(directory: String, paths: Array[String]) -> void:
	var access: DirAccess = DirAccess.open(directory)
	for file: String in access.get_files():
		if file.ends_with(".tres"):
			paths.append(directory.path_join(file))
	for folder: String in access.get_directories():
		_collect(directory.path_join(folder), paths)

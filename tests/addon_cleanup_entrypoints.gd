extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Isolated compiler gate: this process does not instantiate gameplay classes.
	# The real headless editor additionally opens the addon world fixture.
	for directory: String in ["phantom_camera", "rmsmartshape", "beehave", "AsepriteWizard"]:
		var config := ConfigFile.new()
		var config_path: String = "res://addons/%s/plugin.cfg" % directory
		_check(config.load(config_path) == OK, "%s plugin metadata loads" % directory)
		var entry_path: String = config_path.get_base_dir().path_join(config.get_value("plugin", "script"))
		var entry: GDScript = load(entry_path) as GDScript
		_check(entry != null and entry.can_instantiate(), "%s editor entrypoint compiles" % directory)
	for frame: int in 5:
		await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

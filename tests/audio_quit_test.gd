extends SceneTree
## Closes while real spatial playback is active; output remains muted locally.

var manager: Node
var room: Node2D
var checks: int = 0
var failures: int = 0
var close_start: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	manager = root.get_node_or_null("AudioManager")
	_check(manager != null, "Quit integration locates the configured audio autoload")
	if manager == null:
		quit(1)
		return
	_check(not auto_accept_quit and manager._handles_window_quit, "Autoload defers automatic window quit until audio cleanup completes")
	AudioServer.set_bus_mute(AudioServer.get_bus_index(manager.bus_name), true)
	room = Node2D.new()
	root.add_child(room)
	for index: int in range(12):
		manager.play_event(&"spell_explosion", Vector2(index * 20, 50), room)
	_check(manager.get_active_voice_count() == 12, "Quit probe begins with twelve owned spatial cues")
	await physics_frame
	await process_frame
	manager.shutdown_complete.connect(_on_shutdown_complete, CONNECT_ONE_SHOT)
	close_start = Time.get_ticks_msec()
	manager.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	manager.request_quit()


func _on_shutdown_complete() -> void:
	# Re-entering during the first close must return, without another shutdown.
	manager.request_quit()
	_check(manager._quit_requested and not manager.enabled and manager.get_active_voice_count() == 0, "Repeated window/button close requests share one completed shutdown")
	var elapsed: int = Time.get_ticks_msec() - close_start
	_check(AudioServer.get_driver_name() == "Dummy" or elapsed >= 80, "Real mixer receives a wall-clock drain interval before process quit")
	print("AUDIO QUIT: driver=%s, drain=%d ms" % [AudioServer.get_driver_name(), elapsed])
	print("RESULT: %d checks, %d failures" % [checks, failures])
	if failures > 0:
		quit(1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

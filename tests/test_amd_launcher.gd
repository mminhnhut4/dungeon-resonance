extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var ok: bool = AmdSlotStore.isolated()
	var boot: AmdBoot = preload("res://scenes/amd201_boot.tscn").instantiate() as AmdBoot
	root.add_child(boot)
	await process_frame
	ok = ok and not is_instance_valid(boot.flow) and boot.user_id == "" and boot.api.access_token == ""
	ok = ok and not FileAccess.file_exists("user://sanctuary_v1.json") and boot.auth_box.visible
	ok = ok and ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/maps/prologue_hub.tscn"
	ok = ok and boot.api.base_url == OS.get_environment("AMD201_API_URL").trim_suffix("/")
	root.remove_child(boot); boot.queue_free(); await process_frame
	print("RESULT AMD_LAUNCHER isolated=%s no_profile_before_login=%s normal_main_preserved=%s" % [str(AmdSlotStore.isolated()),str(not FileAccess.file_exists("user://sanctuary_v1.json")),str(ok)])
	quit(0 if ok else 1)

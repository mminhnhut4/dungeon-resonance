extends SceneTree
## Finite secondary-screen preview. Input events stay inside this Godot process.

var campaign: LinearCampaign
var captures: int = 0
var failed: bool = false

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_run")

func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("DungeonSFX"), true)
	campaign = preload("res://scenes/linear_campaign.tscn").instantiate() as LinearCampaign
	campaign.profile = SanctuaryProfile.new()
	campaign.profile.save_path = "user://verification/preview_art.json"
	root.add_child(campaign)
	current_scene = campaign
	campaign.survival.director.automatic = false
	campaign.feedback.hit_stop_seconds = 0.0
	campaign.player.energy.enabled = false
	for enemy: Node2D in campaign.living_enemies():
		enemy.ai_enabled = false
	campaign.player.relocate(Vector2(540, 640))
	_pointer(Vector2(750, 600))
	await _time(0.4)
	await _capture("art_foyer_idle_right")
	await _verify_glow()
	_pointer(Vector2(310, 600))
	await _time(0.25)
	await _capture("art_foyer_idle_left")
	_pointer(Vector2(900, 610))
	var old_x: float = campaign.player.position.x
	Input.action_press(&"move_right")
	await _time(0.22)
	await _capture("art_player_running")
	Input.action_release(&"move_right")
	if campaign.player.position.x <= old_x + 10.0:
		print("FAIL: Preview movement did not advance Player")
		failed = true
	Input.action_press(&"jump")
	await _time(0.16)
	await _capture("art_player_jumping")
	Input.action_release(&"jump")
	await _time(0.55)
	campaign.player.relocate(Vector2(630, 640))
	_pointer(Vector2(820, 600))
	Input.action_press(&"attack")
	await _time(0.025)
	Input.action_release(&"attack")
	await _time(0.13)
	await _capture("art_player_slash")
	await _time(0.5)
	Input.action_press(&"spell_cast")
	await _time(0.025)
	Input.action_release(&"spell_cast")
	await _time(0.18)
	await _capture("art_player_cast")
	campaign.queue_free()
	for frame: int in 5:
		await process_frame
	await audio.shutdown()
	print("ART PREVIEW: %d captures; movement %s" % [captures, "FAIL" if failed else "PASS"])
	quit(1 if failed else 0)

func _pointer(world_position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = campaign.player.aim.get_canvas_transform() * world_position
	Input.parse_input_event(event)
	campaign.player.aim.sample_cursor()

func _time(seconds: float) -> void:
	await create_timer(seconds).timeout

func _verify_glow() -> void:
	# Freeze scene/particles so a pixel difference represents post processing.
	campaign.process_mode = Node.PROCESS_MODE_DISABLED
	campaign.presentation.atmosphere.dust.speed_scale = 0.0
	for frame: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var with_glow: Image = root.get_texture().get_image()
	var environment: Environment = campaign.presentation.atmosphere.glow_environment.environment
	environment.glow_enabled = false
	for frame: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var without_glow: Image = root.get_texture().get_image()
	with_glow.convert(Image.FORMAT_RGBA8)
	without_glow.convert(Image.FORMAT_RGBA8)
	var changed: bool = with_glow.get_data() != without_glow.get_data()
	if not changed:
		failed = true
	print("GLOW PIXEL COMPARISON: ", "PASS" if changed else "FAIL")
	with_glow.save_png(ProjectSettings.globalize_path("res://docs/verification/art_glow_on.png"))
	without_glow.save_png(ProjectSettings.globalize_path("res://docs/verification/art_glow_off.png"))
	environment.glow_enabled = true
	campaign.presentation.atmosphere.dust.speed_scale = 1.0
	campaign.process_mode = Node.PROCESS_MODE_INHERIT

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://docs/verification/" + label + ".png")
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		failed = true
	print("CAPTURE ", label, ": ", error_string(status))
	captures += 1

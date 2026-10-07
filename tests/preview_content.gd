extends SceneTree
## Finite render captures, isolated from the player's persistent save.

var campaign: LinearCampaign
var directory: String


func _initialize() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	call_deferred("_run")


func _run() -> void:
	directory = ProjectSettings.globalize_path("res://docs/verification")
	var profile := SanctuaryProfile.new()
	profile.save_path = "user://verification/preview_content.json"
	profile.souls = 100
	var hub := preload("res://scenes/hub/sanctuary_hub.tscn").instantiate() as SanctuaryHub
	hub.profile = profile
	root.add_child(hub)
	current_scene = hub
	await _capture("content_hub")
	hub.queue_free()
	await process_frame
	campaign = preload("res://scenes/linear_campaign.tscn").instantiate() as LinearCampaign
	campaign.profile = profile
	root.add_child(campaign)
	campaign.content.qa_tools_enabled = true # Explicit private fixture capability.
	current_scene = campaign
	campaign.survival.director.automatic = false
	campaign.player.suspend_controls(true)
	campaign.content.cycle_weapon()
	campaign.content.unlock_secret()
	campaign.content.select_recipe(&"thermal_shock")
	for enemy: Node2D in campaign.living_enemies():
		enemy.ai_enabled = false
	await _capture("content_foyer")
	campaign.gear.modal.open()
	await _capture("content_inventory")
	campaign.gear.modal.close()
	campaign.survival.panel.open(true)
	await _capture("content_crafting")
	campaign.survival.panel.close()
	campaign.content.open()
	await _capture("content_matrix")
	campaign.content.close()
	campaign.enter_stage(2)
	campaign.player.relocate(Vector2(350, 430))
	await _capture("content_secret")
	campaign.enter_stage(3)
	for enemy: Node2D in campaign.living_enemies():
		enemy.ai_enabled = false
	await _capture("content_mutants")
	campaign.enter_stage(4)
	campaign.player.relocate(Vector2(500, 640))
	campaign.boss.ai_enabled = false
	campaign.boss.health.current_health = 249.0
	campaign.boss.phase = 2
	campaign.survival.director.trigger(&"eclipse")
	await _capture("content_boss_eclipse")
	campaign.queue_free()
	for frame: int in 4:
		await process_frame
	quit()


func _capture(label: String) -> void:
	for frame: int in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
	print("CAPTURE %s: %s" % [label, error_string(result)])

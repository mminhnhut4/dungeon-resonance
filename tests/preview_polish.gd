extends SceneTree
## Finite real-render captures; the production save and editor stay untouched.
var campaign: LinearCampaign

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_run")

func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("DungeonSFX"), true)
	campaign = preload("res://scenes/linear_campaign.tscn").instantiate() as LinearCampaign
	campaign.profile = SanctuaryProfile.new()
	campaign.profile.save_path = "user://verification/preview_polish.json"
	root.add_child(campaign)
	campaign.content.qa_tools_enabled = true # Explicit private fixture capability.
	current_scene = campaign
	campaign.survival.director.automatic = false
	campaign.player.suspend_controls(true)
	campaign.player.energy.enabled = false
	for enemy: Node2D in campaign.living_enemies():
		enemy.ai_enabled = false
	campaign.player.relocate(Vector2(520, 640))
	await _capture("polish_foyer")
	for id: StringName in ContentSession.WEAPON_IDS:
		campaign.player.equipped_weapon.equip(campaign.survival.weapon_definition(id))
		var cursor := InputEventMouseMotion.new()
		cursor.position = campaign.player.aim.get_canvas_transform() * Vector2(700, 575)
		Input.parse_input_event(cursor)
		campaign.player.aim.sample_cursor()
		campaign.player.equipped_weapon.start_combo()
		campaign.player.equipped_weapon.advance(campaign.player.equipped_weapon.definition.combo_steps[0].windup_seconds + 0.04)
		campaign.player.equipped_weapon.set_process(false)
		campaign.player.set_physics_process(false)
		campaign.presentation.trail.refresh_visual()
		await _capture("polish_trail_" + str(id))
		campaign.player.equipped_weapon.cancel_combo()
	campaign.enter_stage(4)
	campaign.boss.ai_enabled = false
	campaign.player.relocate(Vector2(520, 640))
	campaign.content.select_recipe(&"firestorm")
	var controller: ResonanceController = campaign.player.resonance_controller
	controller.reset_runtime()
	var spell: SpellSnapshot = controller.commit_cast()
	spell.origin = Vector2(710, 580)
	spell.direction = Vector2.RIGHT
	campaign.executor.spawn_firestorm(Vector2(825, 605), SpellContext.new(spell))
	campaign.presentation.spawn_impact(Vector2(880, 590), Color(1, 0.4, 0.1), &"fire")
	await _capture("polish_boss_firestorm")
	campaign.queue_free()
	for frame: int in 4:
		await process_frame
	await audio.shutdown()
	quit()

func _capture(label: String) -> void:
	for frame: int in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://docs/verification/" + label + ".png")
	print("CAPTURE ", label, ": ", error_string(root.get_texture().get_image().save_png(path)))

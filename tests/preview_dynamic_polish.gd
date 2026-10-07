extends "res://tests/preview_combat_art.gd"
## Real GPU poses and actual melee/FSM contacts; finite isolated play profile.

func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	if DisplayServer.get_name() == "headless":
		print("FAIL: Dynamic preview requires a real GPU display")
		await audio.shutdown()
		quit(1)
		return
	campaign = preload("res://scenes/linear_campaign.tscn").instantiate() as LinearCampaign
	campaign.profile = SanctuaryProfile.new()
	campaign.profile.save_path = "user://verification/preview_dynamic_polish.json"
	root.add_child(campaign)
	current_scene = campaign
	campaign.survival.director.automatic = false
	campaign.player.energy.enabled = false
	_freeze_input_and_ai()
	campaign.player.relocate(Vector2(520, 640))
	_pointer(Vector2(900, 610))
	await _frames(16)
	await _capture("foyer_idle_shadow")
	campaign.player.suspend_controls(false)
	_press(KEY_D, true)
	await _frames(12)
	var rig: PlayerVisualRig = campaign.player.get_node("Visuals") as PlayerVisualRig
	_verify(absf(rig.concept_dynamics.rotation) > 0.05, "Running real input must lean the visual layer")
	await _capture("player_running_lean")
	_press(KEY_D, false)
	_press(KEY_SPACE, true)
	await _frames(13)
	_verify(rig.actor_shadow.drop_height > 40, "Airborne shadow must remain below the physical Player")
	await _capture("player_jump_shadow")
	_press(KEY_SPACE, false)
	var dust_before: int = campaign.presentation.foot_dust_count
	_press(KEY_SHIFT, true)
	await _frames(2)
	_press(KEY_SHIFT, false)
	_verify(campaign.presentation.foot_dust_count > dust_before, "Actual Air Dash must create finite dust")
	await _capture("player_air_dash_dust")
	dust_before = campaign.presentation.foot_dust_count
	for frame: int in 90:
		await _frames(1)
		if campaign.presentation.foot_dust_count > dust_before:
			break
	_verify(campaign.presentation.foot_dust_count > dust_before, "Actual landing must create one puff")
	await _capture("player_landing_dust")
	_freeze_input_and_ai()
	var slime: SlimeEnemy = campaign.living_enemies()[0] as SlimeEnemy
	campaign.player.relocate(Vector2(620, 640))
	slime.global_position = Vector2(710, 640)
	_pointer(slime.hurtbox.global_position)
	await _frames(4)
	slime.state_machine.transition_to(&"attack")
	slime._state_time = 0.20
	var skin: SlimeSpriteSkin = slime.get_node("SlimeSpriteSkin") as SlimeSpriteSkin
	skin.refresh_skin()
	await _capture("slime_anticipation")
	slime._state_time = slime.telegraph_seconds + 0.06
	skin.refresh_skin()
	await _capture("slime_visual_hop")
	slime._state_time = slime.telegraph_seconds + 0.20
	skin.refresh_skin()
	await _capture("slime_land_squash")
	slime.state_machine.transition_to(&"patrol")
	await _capture_real_melee(slime, "slime_actual_white_hitstop", Vector2(674, 640))
	await _frames(18)
	campaign.player.health.reset_health()
	campaign.enter_stage(4)
	_freeze_input_and_ai()
	campaign.player.relocate(Vector2(640, 640))
	_pointer(campaign.boss.hurtbox.global_position)
	await _frames(12)
	await _capture("boss_idle_shadow")
	await _capture_real_melee(campaign.boss, "boss_actual_heavy_hitstop", Vector2(824, 640))
	await _frames(18)
	campaign.player.relocate(Vector2(510, 640))
	campaign.boss.health.apply_damage(260)
	for enemy: Node2D in campaign.living_enemies():
		if enemy is SlimeEnemy:
			(enemy as SlimeEnemy).ai_enabled = false
			(enemy as SlimeEnemy).contact_damage_enabled = false
	campaign.boss.ai_enabled = true
	campaign.boss.fsm.transition_to(&"stomp")
	var waves: int = campaign.boss.shockwave_count
	for frame: int in 130:
		await _frames(1)
		if campaign.boss.shockwave_count > waves:
			break
	campaign.boss.ai_enabled = false
	_verify(campaign.boss.shockwave_count == waves + 2, "Real Boss stomp must emit two waves")
	_verify((campaign.player.get_node("Camera2D") as PlayerCamera).trauma > 0.4, "Stomp must trigger its stronger camera cue")
	await _capture("boss_stomp_dust_shake")
	# Keep the HUD alive past the Boss's genuine dead-state queue_free. Merely
	# setting HP to zero leaves a valid actor and misses dangling world properties.
	var defeated_boss: WeakRef = weakref(campaign.boss)
	var final_hit := DamageEvent.new()
	final_hit.source_id = campaign.player.get_instance_id()
	final_hit.source_team_id = 1
	final_hit.target_id = campaign.boss.hurtbox.get_actor_id()
	final_hit.attack_id = CombatIds.next_id()
	final_hit.root_event_id = final_hit.attack_id
	final_hit.hit_window_id = 1
	final_hit.base_damage = 1000.0
	final_hit.attack_direction = Vector2.RIGHT
	campaign.boss.ai_enabled = true
	campaign.boss.hurtbox.take_damage(final_hit)
	await _frames(100)
	var art_hud: ArtHUD = campaign.presentation.art_hud
	_verify(defeated_boss.get_ref() == null and campaign.portal_active, "Actual dead-state teardown must remove Boss and unlock victory portal")
	_verify(not art_hud.boss_panel.visible and art_hud.boss_id == 0 and art_hud.player_panel.visible, "Live HUD must hide a freed Boss without losing Player bars")
	await _capture("boss_removed_hud_released")
	campaign.player.relocate(Vector2(1160, 640))
	campaign.player.suspend_controls(false)
	_press(KEY_E, true)
	await _frames(2)
	_press(KEY_E, false)
	_verify(campaign.outcome == &"victory" and campaign.end_panel.visible, "Victory portal input remains usable after Boss node is freed")
	await _capture("boss_victory_flow")
	campaign.queue_free()
	await _frames(5)
	_verify(is_equal_approx(Engine.time_scale, 1.0), "Preview teardown restores transient time claims")
	await audio.shutdown()
	print("DYNAMIC POLISH PREVIEW: %d captures; %s" % [captures, "FAIL" if failed else "PASS"])
	quit(1 if failed else 0)

func _capture_real_melee(target: Node2D, label: String, player_position: Vector2) -> void:
	campaign.player.relocate(player_position)
	campaign.player.suspend_controls(false)
	_pointer((target.get("hurtbox") as Hurtbox).global_position)
	await _frames(3)
	campaign.player.equipped_weapon.equip(preload("res://data/weapons/ancient_sword.tres"))
	var hp_before: float = (target.get("health") as HealthComponent).current_health
	_press(KEY_J, true)
	await _frames(1)
	_press(KEY_J, false)
	var contacted: bool = false
	for frame: int in 40:
		await _frames(1)
		if (target.get("health") as HealthComponent).current_health < hp_before:
			contacted = true
			break
	_verify(contacted and campaign.feedback.is_frozen() and is_equal_approx(Engine.time_scale, 0.05), "Real %s contact must resolve damage and global hitstop" % label)
	await _capture(label)
	campaign.player.suspend_controls(true)

func _press(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	# Continuous movement/jump reads Input's held state; unlike pointer events,
	# keyboard events have no viewport stretch conversion to compensate for.
	Input.parse_input_event(event)

func _verify(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		print("FAIL: ", message)

func _capture(label: String) -> void:
	await super._capture("dynamic_" + label)

extends SceneTree
## Finite real-GPU mixed AI benchmark; no headless/fixed-fps inference.
var target_fps: int = 60

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fps="): target_fps = int(arg.trim_prefix("--fps="))
	Engine.max_fps = target_fps
	Engine.physics_ticks_per_second = target_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	call_deferred("_run")

func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	if DisplayServer.get_name() == "headless":
		print("FAIL: GPU benchmark requires a renderer")
		await audio.shutdown(); quit(1); return
	var campaign: WorldCampaign = preload("res://scenes/world_campaign.tscn").instantiate() as WorldCampaign
	campaign.profile = SanctuaryProfile.new()
	campaign.profile.save_path = "user://verification/world_render_%d.json" % target_fps
	campaign.initial_stage = 3
	root.add_child(campaign)
	current_scene = campaign
	campaign.survival.set_enabled(false)
	campaign.feedback.hit_stop_seconds = 0.0
	campaign.player.controls_enabled = false
	campaign.player.relocate(Vector2(620, 640))
	campaign.player.health.maximum_health = 100000.0
	campaign.player.health.current_health = 100000.0
	# Add the flyer to stage3's real guard/wraith/champion/slime wave.
	var bat: BaseEnemy = WorldCampaign.MONSTERS[&"bloodwing_bat"].instantiate() as BaseEnemy
	bat.player = campaign.player
	bat.combat_feedback = campaign.feedback
	bat.position = Vector2(770, 510)
	campaign.room.add_child(bat)
	var enemies: Array[BaseEnemy] = []
	for candidate: Node in get_nodes_in_group(&"world_enemies"):
		if campaign.room.is_ancestor_of(candidate):
			var enemy: BaseEnemy = candidate as BaseEnemy
			enemy.health.maximum_health = 100000.0
			enemy.health.current_health = 100000.0
			enemy.global_position.x = 690 + enemies.size() * 38
			enemies.append(enemy)
	var begin: int = Time.get_ticks_usec()
	var previous: int = begin
	var measured: int = 0
	var frame_ms: Array[float] = []
	var next_cast: float = 0.0
	var next_loot: float = 0.0
	var next_impact: float = 0.0
	var count: int = 0
	var peak_hazards: int = 0
	var peak_fields: int = 0
	var peak_entities: int = 0
	var peak_loot: int = 0
	var peak_lights: int = 0
	var peak_voices: int = 0
	var physics_ms: float = 0.0
	while Time.get_ticks_usec() - begin < 8000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var elapsed: float = (now - begin) / 1000000.0
		campaign.player.health.current_health = 100000.0
		if elapsed >= next_cast:
			var shot := SpellSnapshot.new()
			shot.source_id = campaign.player.get_instance_id()
			shot.root_id = CombatIds.next_id()
			shot.origin = Vector2(620, 590)
			shot.direction = Vector2.from_angle(sin(elapsed) * 0.45)
			shot.behavior_id = &"fan_blades" if count % 2 == 0 else &"arcane_wave"
			shot.damage = 0.1
			shot.lifetime = 1.2
			shot.weapon_family_visual = true
			shot.cosmetic_quality = count % 6
			shot.cosmetic_element = &"lightning" if count % 2 == 0 else &"fire"
			shot.color = AttackSnapshot.tint_for_element(shot.cosmetic_element)
			campaign.executor.spawn_cast(shot)
			count += 1
			next_cast = elapsed + 0.1
		if elapsed >= next_loot:
			var pickup: LootPickup = campaign.gear.loot.spawn(&"material", &"enhancement_stone_1", Vector2(1050, 620))
			if pickup != null: pickup.life = 1.5; pickup.automatic = false
			next_loot = elapsed + 0.1
		if elapsed >= next_impact:
			campaign.presentation.spawn_impact(Vector2(810, 600), Color(1, 0.4, 0.1), &"fire", Vector2.RIGHT)
			next_impact = elapsed + 0.05
		peak_hazards = maxi(peak_hazards, get_nodes_in_group(&"world_enemy_hazards").size())
		peak_fields = maxi(peak_fields, get_nodes_in_group(&"world_slow_fields").size())
		peak_entities = maxi(peak_entities, get_nodes_in_group(&"spell_entities").size())
		peak_loot = maxi(peak_loot, get_nodes_in_group(&"loot").size())
		peak_lights = maxi(peak_lights, campaign.presentation.light_owners.size())
		peak_voices = maxi(peak_voices, audio.get_active_voice_count())
		if elapsed >= 2.0:
			if measured == 0: measured = now
			else: frame_ms.append((now - previous) / 1000.0)
			physics_ms = maxf(physics_ms, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
		previous = now
	var seconds: float = (Time.get_ticks_usec() - measured) / 1000000.0
	frame_ms.sort()
	var fps: float = frame_ms.size() / seconds
	var p95: float = frame_ms[mini(frame_ms.size() - 1, int(frame_ms.size() * 0.95))]
	var attacks: Dictionary = {}
	for enemy: BaseEnemy in enemies: attacks[enemy.enemy_type] = enemy.attacks_started
	var all_attacked: bool = attacks.size() == 4
	for amount: int in attacks.values(): all_attacked = all_attacked and amount > 0
	var passed: bool = fps >= target_fps * 0.95 and p95 <= 1000.0 / target_fps * 1.4 and all_attacked and peak_hazards > 0 and peak_hazards <= 16 and peak_fields > 0 and peak_fields <= 4 and peak_lights <= 12 and peak_voices <= 16
	var result: Dictionary = {"engine": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"), "window_size": str(DisplayServer.window_get_size()), "target_render_fps": target_fps, "physics_ticks_per_second": target_fps, "warmup_seconds": 2, "measurement_seconds": seconds, "average_render_fps": fps, "p95_frame_ms_including_cap_wait": p95, "peak_physics_ms": physics_ms, "enemy_attacks_started": attacks, "peak_enemy_hazards": peak_hazards, "peak_slow_fields": peak_fields, "peak_spell_entities": peak_entities, "peak_loot": peak_loot, "peak_projectile_lights": peak_lights, "peak_spatial_voices": peak_voices, "passed": passed, "scenario": "Real world campaign stage3 + flyer: guard, bat, wraith, shield champion and runic Slime active AI. Approved alpha sprites and observed-motion telegraphs/trails, 10 alternate fan/wave casts/s cycling6rarities, 20 impacts/s and10 finite material pickups/s, lights/particles/audio mixer. HP held, spell damage0.1 and hitstop disabled only in this private throughput fixture; Master privately muted. Two-second warmup/six-second sample, finite teardown; not a whole-run or every-machine FPS guarantee."}
	var file: FileAccess = FileAccess.open("res://docs/verification/world_render_%d.json" % target_fps, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t")); file.close()
	print("WORLD RENDER ", JSON.stringify(result))
	campaign.queue_free()
	for frame: int in 6: await process_frame
	await audio.shutdown()
	quit(0 if passed else 1)

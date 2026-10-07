extends SceneTree
## Finite, silent GPU evidence of actual pilot states and existing dialogue UI.
var flow: GameFlow
var hub: ExteriorHub
var population: NpcPopulation
var pilot: NpcPilotActor
var captures: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/npc_visual_%d.json" % Time.get_ticks_usec()
	root.add_child(flow)
	current_scene = flow
	await _step(10)
	hub = flow.active_scene as ExteriorHub
	hub.enter_exterior(&"o01_p01")
	await _step(5)
	population = hub.npc_population
	pilot = population.actors["pilot_traveler"]
	_approach()
	await _step(15)
	await _capture("npc_p01_walk")
	population.set_process(false)
	for index: int in 120:
		if population.state.records[pilot.stable_id]["mode"] == "work": break
		population.state.advance_ticks(1)
	pilot.sync_record(false)
	_approach()
	await _capture("npc_p01_work")
	for index: int in 120:
		if population.state.records[pilot.stable_id]["mode"] == "rest": break
		population.state.advance_ticks(1)
	pilot.sync_record(false)
	_approach()
	await _capture("npc_p01_rest")
	if not population.interact(pilot.stable_id): failures += 1
	pilot.sync_record(false)
	hub.dialogue.advance()
	await _capture("npc_p01_talk")
	hub.dialogue.close()
	await _step(4)
	var hit := DamageEvent.new()
	hit.source_id = hub.player.get_instance_id()
	hit.target_id = pilot.get_instance_id()
	hit.source_team_id = 1
	hit.attack_id = CombatIds.next_id()
	hit.hit_window_id = 1
	hit.root_event_id = hit.attack_id
	hit.base_damage = 9999
	hit.attack_origin = hub.player.global_position
	var result: DamageResult = pilot.hurtbox.take_damage(hit)
	if result.killed or pilot.health.current_health != 1: failures += 1
	pilot.sync_record(false)
	await _capture("npc_p01_downed")
	if not population.interact(pilot.stable_id): failures += 1
	hub.dialogue.advance()
	await _capture("npc_p01_spare_choice")
	hub.dialogue.select_choice(&"pilot_ask_kill")
	hub.dialogue.advance()
	await _capture("npc_p01_kill_confirmation")
	hub.dialogue.select_choice(&"pilot_cancel_kill")
	hub.dialogue.advance()
	hub.dialogue.select_choice(&"pilot_spare")
	await _step(4)
	pilot.sync_record(false)
	await _capture("npc_p01_recovering")
	if population.state.records[pilot.stable_id]["mode"] != "recovering": failures += 1
	hub.return_to_hub()
	await _step(5)
	if not population.actors.is_empty(): failures += 1
	flow.queue_free()
	await _step(6)
	if not get_nodes_in_group(&"npc_pilot_actor").is_empty(): failures += 1
	print("RESULT NPCVisualCapture %d captures, %d failures; actual DamageEvent/UI/room, private profile, QA master muted" % [captures,failures])
	quit(0 if failures == 0 else 1)

func _approach() -> void:
	var x: float = pilot.global_position.x-55
	PlayerTravel.relocate(hub.player,Vector2(x,ExteriorHub.ORIGIN.y+hub.exterior.floor_y(x-ExteriorHub.ORIGIN.x)))

func _capture(label: String) -> void:
	hub._process(0)
	population._process(0)
	await _step(8)
	await RenderingServer.frame_post_draw
	captures += 1
	if root.get_texture().get_image().save_png("res://docs/verification/combined_"+label+".png") != OK: failures += 1

func _step(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame

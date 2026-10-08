extends SceneTree
## Controlled executor casts and physical stone contacts in actual WorldCampaign.
var checks: int = 0
var failures: int = 0
var legacy: int = 0
var contacts: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var capture: bool = false
var flow: GameFlow
var run: WorldCampaign
func _initialize() -> void: _run.call_deferred()
func _step(count: int = 1) -> void:
	for index: int in count:
		await physics_frame
		await process_frame
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)
func _legacy(_position: Vector2, _color: Color, _direction: Vector2) -> void: legacy += 1
func _committed(position: Vector2, _color: Color, direction: Vector2, recipe: StringName, root_id: int, source_id: int) -> void:
	contacts.append({"position":position,"direction":direction,"recipe":recipe,"root":root_id,"source":source_id})
func _picture(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	var path: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join(label + ".png")
	_check(root.get_texture().get_image().save_png(path) == OK,"Native wall capture " + label)
func _cast(recipe: StringName, behavior: StringName, expected: int) -> void:
	var payload := SpellSnapshot.new()
	payload.source_id = run.player.get_instance_id(); payload.root_id = CombatIds.next_id()
	payload.recipe_id = recipe; payload.behavior_id = behavior
	payload.origin = Vector2(900, 100); payload.direction = Vector2.RIGHT
	payload.effect_radius = 80; payload.effect_duration = 1.0; payload.damage = 2
	var before: int = run.presentation.impact_count
	legacy = 0; contacts.clear()
	run.executor.spawn_cast(payload)
	for attempt: int in 30:
		await _step()
		if legacy >= expected: break
	_check(legacy == expected and run.presentation.impact_count == before + expected + (1 if behavior == &"overload" else 0), "%s contacts preserve legacy3 API and existing Overload explosion separately" % recipe)
	_check(contacts.size() == expected and contacts.all(func(row: Dictionary) -> bool: return row.recipe == recipe and row.root == payload.root_id and row.source == payload.source_id and row.direction == payload.direction), "%s committed contact preserves exact recipe/source/root and snapshot direction" % recipe)
	var painted: int = 0
	for burst: ImpactBurst in run.presentation.impacts.get_children():
		if burst.spell_recipe_id != recipe: continue
		if burst.get_meta(&"committed_root_id",0) == payload.root_id and burst.get_meta(&"committed_source_id",0) == payload.source_id and absf(burst.global_position.x - 954) < 12 and burst._art_layers.size() == 2 and burst._art_layers[0].visible and burst._art_layers[1].visible and burst._art_layers[0].texture is AtlasTexture and burst._art_layers[1].texture is AtlasTexture and burst._art_layers[0].texture != burst._art_layers[1].texture: painted += 1
	_check(painted == expected,"%s wall contact binds both distinct resident painted elemental crops" % recipe)
	captures.append({"recipe":recipe,"root":payload.root_id,"contacts":contacts.duplicate(true),"legacy":legacy,"painted":painted,"impacts":run.presentation.impacts.get_child_count()})
	await _picture(String(recipe) + "_contact")
	if behavior == &"miasma_cloud":
		_check(run.executor.get_children().filter(func(child: Node) -> bool: return child is ElementField).size() == 1,"Physical Miasma contact still creates exactly one field")
		run.executor.wall_hit(Vector2(954,100), (run.executor.get_children().filter(func(child: Node) -> bool: return child is ElementField)[0] as ElementField).context)
		_check(run.executor.get_children().filter(func(child: Node) -> bool: return child is ElementField).size() == 1,"Repeated context contact cannot repeat its field proc")
	run.executor.clear_entities()
	await _step(ceili(0.65 * Engine.physics_ticks_per_second))
	_check(run.presentation.impacts.get_child_count() == 0 and run.presentation.field_vfx_owners.is_empty() and run.presentation.light_owners.is_empty(),"%s finite wall paint/field/light cleanup releases all owners" % recipe)
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
		if argument == "--capture": capture = true
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa + "/"):
		push_error("Isolated QA root required"); quit(2); return
	if capture and DisplayServer.get_name() == "headless": push_error("Native renderer required"); quit(2); return
	flow = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate() as GameFlow
	flow.save_path_override = "user://verification/wall_art_%d.json" % OS.get_process_id()
	root.add_child(flow); current_scene = flow
	await _step(8); flow.start_campaign(); await _step(8)
	run = flow.active_scene as WorldCampaign
	_check(run != null and run.enter_stage(2),"Configured product main opens actual campaign for controlled wall fixture")
	await _step(5)
	run.player.controls_enabled = false
	PlayerTravel.relocate(run.player,Vector2(900,300),PlayerTravel.Kind.INTRA_EXPEDITION)
	run.player.get_node("Camera2D").position = Vector2(0,-200)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(flow.profile.save_path)
	var wall := StaticBody2D.new(); wall.position = Vector2(960,100); wall.collision_layer = 1
	var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(12,220)
	collision.shape = shape; wall.add_child(collision); run.room.add_child(wall)
	run.executor.presentation_contact.connect(_legacy)
	if run.executor.has_signal(&"committed_contact"): run.executor.connect(&"committed_contact",_committed)
	await _step(3)
	for recipe: StringName in [&"firestorm",&"overload",&"miasma_cloud",&"charged_slash",&"eclipse_blades"]:
		await _cast(recipe,&"fan_blades" if recipe == &"eclipse_blades" else recipe,3 if recipe in [&"charged_slash",&"eclipse_blades"] else 1)
	_check(bytes == FileAccess.get_file_as_bytes(flow.profile.save_path),"Stone cosmetic contacts preserve exact profile bytes")
	var file := FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("wall_trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures},"\t"))
	flow.queue_free(); current_scene = null; await _step(6)
	_check(get_nodes_in_group(&"spell_entities").is_empty() and TimeScaleClaims.owner_count(self) == 0,"Campaign teardown releases entities and time claims")
	print("RESULT: CommittedWallArt %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

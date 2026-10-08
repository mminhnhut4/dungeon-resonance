extends SceneTree
## Actual main/Population binding; presentation and story have no reward authority.
var checks: int = 0
var failures: int = 0
var flow: GameFlow
var hub: ExteriorHub
const SOURCE_HASHES: Dictionary = {
	"thanh_van_disciple_01":"8c2df932c0be53c421ea1b7e81312edd5ad91d92bf0900064efd9cd3e0e4749d",
	"xich_lo_guard_01":"56aeeef27378694050124cf9117be17178605f9ae663d9b61a1734d3474f6704"
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	var qa_root: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not qa_root.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa_root+"/"):
		print("FAIL: cultivator art requires isolated QA data root")
		quit(2)
		return
	_check(CultivatorCatalog.portrait(CultivatorCatalog.IDS[0]) != CultivatorCatalog.portrait(CultivatorCatalog.IDS[1]),"Two stable IDs own distinct textures")
	_check(CultivatorCatalog.portrait("unknown") == null and CultivatorCatalog.dialogue_lines("unknown").is_empty(),"Unknown IDs cannot borrow another identity's portrait or story")
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/cultivator_art_%d_%d.json" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	root.add_child(flow)
	current_scene = flow
	await _step(6)
	hub = flow.active_scene as ExteriorHub
	for id: String in CultivatorCatalog.IDS:
		await _exercise(id)
	hub.return_to_hub(false)
	await _step(3)
	_check(get_nodes_in_group(&"npc_pilot_actor").is_empty(),"Leaving the road releases both art actors")
	flow.queue_free()
	await _step(5)
	print("RESULT cultivator_art checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

func _exercise(id: String) -> void:
	var spec: Dictionary = NpcPilotCatalog.definition(id)
	if id in NpcPilotCatalog.SECT_STEWARD_IDS:
		_check(hub.sect_journey.progress.record(SectRouteCatalog.faction(StringName(spec["room"])),"accept"),"Fixture accepts only the steward entrance quest")
	_check(hub.enter_exterior(StringName(spec["room"]),&"main",&"west",false),"Enter actual route for "+id)
	await _step(5)
	var actor: CultivatorActor = hub.npc_population.actors.get(id) as CultivatorActor
	_check(actor != null,"Population creates cultivator actor "+id)
	if actor == null: return
	var texture: Texture2D = CultivatorCatalog.portrait(id)
	_check(actor.body.texture == texture and actor.portrait == texture,"Population binds the stable ID portrait")
	_check(actor.body.modulate == Color.WHITE,"Source palette remains untinted")
	_check(actor.body.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"Small painted body uses mipmap filtering")
	_check(FileAccess.get_sha256(texture.resource_path) == SOURCE_HASHES[CultivatorCatalog.UNIFORMS.get(id,id)],"PNG is byte-identical to selected imagegen output")
	var image: Image = texture.get_image()
	_check(image != null and image.get_size() == Vector2i(1024,1536),"Full source resolution is preserved")
	if image == null: return
	if image.is_compressed(): _check(image.decompress() == OK,"Imported image is readable for alpha verification")
	_check(image.has_mipmaps(),"Imported resource contains mipmaps")
	image.convert(Image.FORMAT_RGBA8)
	_check(image.get_pixel(0,0).a == 0.0 and image.get_pixel(1023,1535).a == 0.0,"True transparent corner pixels survive import")
	var bounds: Rect2i = actor.alpha_geometry["bounds"]
	_check(bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < 1024 and bounds.end.y < 1536,"Full alpha silhouette has unclipped padding")
	_check(is_equal_approx(bounds.size.y*actor.body.scale.y,60.0),"Existing 60px body height is retained")
	var foot: Vector2 = actor.alpha_geometry["foot_pixel"]
	_check(foot.y == bounds.end.y and foot.x >= bounds.position.x and foot.x <= bounds.end.x,"Foot pivot derives from the bottom alpha footprint")
	_check(EnemySpriteArt.foot_world(actor.body,foot).distance_to(actor.global_position) < 0.001,"Sprite feet stay on the existing actor floor origin")
	var shape: CollisionShape2D = actor.hurtbox.get_child(0) as CollisionShape2D
	var capsule: CapsuleShape2D = shape.shape as CapsuleShape2D
	_check(capsule != null and capsule.radius == 11.0 and capsule.height == 52.0 and shape.position == Vector2(0,-26),"Physical hurt capsule retains its authored size and origin")
	var collider_transform: Transform2D = shape.transform
	for facing: float in [-1.0,1.0]:
		actor._facing = facing
		for phase: String in ["idle","tell","active","hurt","recover"]:
			actor.combat_phase = phase
			actor.sync_record(true)
			_check(actor.body.flip_h == (facing < 0.0) and EnemySpriteArt.foot_world(actor.body,foot).distance_to(actor.global_position) < 0.001,"Facing/phase preserves foot pivot: %s/%s" % [facing,phase])
			_check(shape.transform == collider_transform and actor.hurtbox.transform == Transform2D.IDENTITY and not actor.strike_hitbox.active,"Visual pose cannot move hurt rig or open damage: "+phase)
	actor.combat_phase = "idle"
	actor.sync_record(true)
	var lines: Array[String] = CultivatorCatalog.dialogue_lines(id)
	_check(lines.size()==(1 if id in NpcPilotCatalog.SECT_STEWARD_IDS else 2) and (lines[0].contains("sổ") if id in NpcPilotCatalog.SECT_STEWARD_IDS else lines[1].contains("Bến Trầm")),"Authored dialogue directs this identity to its actual region and role")
	lines.clear()
	_check(CultivatorCatalog.dialogue_lines(id).size() == (1 if id in NpcPilotCatalog.SECT_STEWARD_IDS else 2),"Dialogue caller cannot mutate catalog content")
	PlayerTravel.relocate(hub.player,actor.global_position+Vector2(-22,0))
	await _step(2)
	var profile_hash: String = FileAccess.get_sha256(hub.profile.save_path)
	var opening_before: Dictionary = hub.profile.opening_progress.duplicate(true)
	var geography_before: Dictionary = hub.profile.exterior_progress.duplicate(true)
	var coins_before: int = hub.profile.coins
	var souls_before: int = hub.profile.souls
	_check(hub.npc_population.interact(id),"Healthy NPC opens the actual existing dialogue modal")
	for line: String in CultivatorCatalog.dialogue_lines(id):
		_check(line in hub.dialogue.pages,"Actual modal includes authored story text")
	_check(hub.dialogue.choices.size() == 2 and hub.dialogue.choices[0]["id"] == &"pilot_greet" and hub.dialogue.choices[1]["id"] == &"pilot_leave","Story seed adds no unimplemented quest/teach/hire choices")
	_check(not hub.player.controls_enabled and not actor.strike_hitbox.active,"Story modal suspends player and NPC damage")
	hub.dialogue.close()
	await _step(3)
	_check(FileAccess.get_sha256(hub.profile.save_path) == profile_hash and hub.profile.opening_progress == opening_before and hub.profile.exterior_progress == geography_before and hub.profile.coins == coins_before and hub.profile.souls == souls_before,"Read/close story grants no profile flag, currency or write")
	_check(hub.player.controls_enabled,"Closing story restores controls")

func _step(count: int) -> void:
	for _index: int in count: await physics_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+message)

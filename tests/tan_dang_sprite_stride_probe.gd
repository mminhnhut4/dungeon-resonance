extends SceneTree
## Native component fixture, not natural NPC AI locomotion. No gameplay/save owner.
## The driver moves its real Node2D in physics; the production helper only observes.
class StrideDriver:
	extends Node2D
	var art := TanDangSpriteArt.new()
	var sprite := Sprite2D.new()
	var capsule := CapsuleShape2D.new()
	var collision := CollisionShape2D.new()
	var phase: String = "idle"
	var remaining: float = 0.0
	var mode: String = "walk"
	var facing: float = 1.0
	var pending: bool = false
	var travel: float = 0.0
	var target_x: float = 0.0
	var relocation := Vector2.ZERO
	var samples: Array[Dictionary] = []
	var spec: Dictionary = {}
	var identity: String
	func build(id: String) -> bool:
		identity = id
		process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(sprite)
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 0
		add_child(area)
		capsule.radius = 11.0
		capsule.height = 52.0
		collision.shape = capsule
		collision.position = Vector2(0,-26)
		area.add_child(collision)
		spec = CultivatorCatalog.definition(id)
		return art.configure(self,sprite,id)
	func issue(distance: float = 0.0, relocate: Vector2 = Vector2.ZERO) -> void:
		travel = distance
		target_x = position.x+distance
		relocation = relocate
		pending = true
	func _physics_process(delta: float) -> void:
		if not pending: return
		var playing: bool = not get_tree().paused
		position += relocation
		relocation = Vector2.ZERO
		if playing and travel != 0.0:
			var step_budget: float = 48.0*delta
			# Float32 Node2D coordinates can finish a nominal 0.8px step a few
			# millionths short. Clamp the final bounded step to its authored
			# target; never declare completion before the real root gets there.
			position.x = target_x if absf(target_x-position.x) <= step_budget+0.0001 else move_toward(position.x,target_x,step_budget)
			travel = target_x-position.x
		art.sync(self,phase,remaining,spec,mode,playing,delta,facing)
		if samples.size() < 6000:
			samples.append({"tick":Engine.get_physics_frames(),"x":position.x,"phase":phase,"frame":art.frame_index,"distance":art.walk_distance,"foot":[art.planted_contact_world.x,art.planted_contact_world.y],"role":art.support_role,"scale":art.draw_scale,"atlas":art.frame_atlas_path,"paused":get_tree().paused,"teleport_discarded":art.teleport_discarded})
		queue_redraw()
		if travel == 0.0: pending = false
	func _draw() -> void:
		draw_line(Vector2(-180,0),Vector2(180,0),Color(0.4,0.45,0.5),0.4,true)
		draw_line(Vector2(-2,0),Vector2(2,0),Color.WHITE,0.6,true)
		if art.available and art.has_stance_contact:
			draw_circle(to_local(art.planted_contact_world),1.0,Color(0.3,1.0,0.5))

var checks: int = 0
var failures: int = 0
var evidence: String
var fixture: StrideDriver
var stage: Node2D
var camera: Camera2D
var caption: Label
var captures: Array[Dictionary] = []
var reports: Array[Dictionary] = []
var source_alpha_checked: Dictionary = {}
var manifest: Dictionary

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var isolated: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	evidence = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").replace("\\","/").trim_suffix("/")
	if "--native-approved" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless" or isolated.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(isolated+"/") or not evidence.begins_with(isolated+"/"):
		print("FAIL: native approval and isolated user/evidence paths required"); quit(2); return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	root.transparent_bg = false
	RenderingServer.set_default_clear_color(Color(0.10,0.13,0.16))
	manifest = JSON.parse_string(FileAccess.get_file_as_string(TanDangSpriteArt.MANIFEST))
	stage = Node2D.new()
	root.add_child(stage)
	camera = Camera2D.new()
	camera.position = Vector2(0,-30)
	camera.zoom = Vector2(4,4)
	stage.add_child(camera)
	var ui := CanvasLayer.new()
	root.add_child(ui)
	caption = Label.new()
	caption.position = Vector2(24,24)
	caption.add_theme_font_size_override("font_size",20)
	ui.add_child(caption)
	for id: String in TanDangSpriteArt.IDS:
		await _identity(id)
	await _finish()

func _identity(id: String) -> void:
	fixture = StrideDriver.new()
	stage.add_child(fixture)
	_check(fixture.build(id),"Production helper configures actual atlas: "+id)
	if not fixture.art.available:
		print("FAIL detail: "+fixture.art.last_error)
		fixture.queue_free(); await process_frame; return
	var origin: Vector2 = fixture.position
	var seen: Dictionary = {}
	var prior: float = 0.0
	for distance: float in [2.0,14.0,26.0,38.0,48.0]:
		await _drive(distance-prior)
		prior = distance
		seen[fixture.art.frame_index] = true
		_metadata(id)
		if distance < 48.0: await _capture(id+"_forward_"+fixture.art.pose_name)
	_check(seen.has_all([1,2,3,4]),"Actual 48px forward displacement seeks all four walking frames: "+id)
	_check(is_equal_approx(fixture.position.x-origin.x,48.0) and is_equal_approx(fixture.art.walk_distance,48.0),"Bounded stride uses real movement and matching observed distance: "+id)
	var reverse_seen: Array[int] = []
	prior = 0.0
	for distance: float in [2.0,14.0,26.0,38.0,48.0]:
		await _drive(-(distance-prior))
		prior = distance
		reverse_seen.append(fixture.art.frame_index)
		_metadata(id)
	_check(reverse_seen == [1,4,3,2,1],"Retreat reverses authored steps while facing remains right: "+id)
	_check(fixture.position.is_equal_approx(origin),"Reverse stride returns the physical driver to its origin: "+id)
	# Pause is the real SceneTree pause; this fixture's always-process observer
	# samples once, with no movement. Production actor pause guards are separate.
	await _drive(14.0)
	var held_frame: int = fixture.art.frame_index
	var held_distance: float = fixture.art.walk_distance
	var held_position: Vector2 = fixture.position
	paused = true
	await _drive()
	_check(fixture.art.frame_index == held_frame and fixture.art.walk_distance == held_distance and fixture.position == held_position,"Paused component holds pose/distance/root: "+id)
	paused = false
	await _drive()
	_check(fixture.art.frame_index == 0,"Zero movement after resume selects idle: "+id)
	var before_teleport: float = fixture.art.walk_distance
	await _drive(0.0,Vector2(64,0))
	_check(fixture.art.teleport_discarded and fixture.art.walk_distance == before_teleport and fixture.art.frame_index == 0,"64px relocation is rejected as gait, then sampled without replay: "+id)
	await _drive(0.0,Vector2(-64,0))
	fixture.phase = "tell"
	fixture.remaining = float(fixture.spec["tell"])*0.8
	await _drive()
	_check(fixture.art.frame_index == 5,"Tell seeks authored anticipation before cancellation: "+id)
	fixture.phase = "idle"
	fixture.remaining = 0.0
	await _drive()
	_check(fixture.art.frame_index == 0,"Fixture cancellation returns to idle without an active pose: "+id)
	fixture.facing = -1.0
	await _drive(2.0)
	_check(fixture.sprite.scale.x < 0.0 and fixture.art.frame_index in [1,2,3,4],"Left-facing mirror keeps an authored walking pose: "+id)
	_metadata(id)
	_check(fixture.capsule.radius == 11.0 and fixture.capsule.height == 52.0 and fixture.collision.position == Vector2(0,-26) and fixture.collision.rotation == 0.0 and fixture.collision.scale == Vector2.ONE,"Helper leaves fixture capsule resource/local transform untouched: "+id)
	_check(fixture.rotation == 0.0 and fixture.scale == Vector2.ONE,"Presentation leaves driver root rotation/scale untouched: "+id)
	var max_contact_delta: float = 0.0
	for index: int in range(1,fixture.samples.size()):
		var a: Dictionary = fixture.samples[index-1]
		var b: Dictionary = fixture.samples[index]
		if a["frame"] == b["frame"] and a["atlas"] == b["atlas"] and not b["teleport_discarded"]:
			max_contact_delta = maxf(max_contact_delta,Vector2(a["foot"][0],a["foot"][1]).distance_to(Vector2(b["foot"][0],b["foot"][1])))
	reports.append({"id":id,"forward_frames":seen.keys(),"reverse_frames":reverse_seen,"max_adjacent_same_pose_contact_delta":max_contact_delta,"samples":fixture.samples})
	fixture.queue_free()
	await process_frame
	_check(not is_instance_valid(fixture),"Fixture sprite/capsule teardown completes: "+id)

func _drive(distance: float = 0.0, relocate: Vector2 = Vector2.ZERO) -> void:
	fixture.issue(distance,relocate)
	for _index: int in Engine.physics_ticks_per_second*4:
		await physics_frame
		await process_frame
		if not fixture.pending: return
	_check(false,"Bounded fixture driver completed within four seconds")
	fixture.pending = false

func _metadata(id: String) -> void:
	var art: TanDangSpriteArt = fixture.art
	var entry: Dictionary = manifest["actors"][id]
	var frame: Dictionary = entry["frames"][art.frame_index]
	var expected_scale: float = float(entry.get("draw_height",manifest.get("draw_height",60.0)))/float(entry["body_height_px"])*float(frame.get("scale_multiplier",1.0))
	var expected_path: String = str(frame.get("texture",entry["texture"]))
	if not expected_path.begins_with("res://"): expected_path = TanDangSpriteArt.BASE.path_join(expected_path)
	_check(art.has_stance_contact and art.frame_pivot.is_finite() and art.stance_contact_local.is_finite() and art.planted_contact_world.is_finite() and art.support_role in ["left","right","both"],"Measured stance metadata remains finite: "+id+"/"+art.pose_name)
	_check(art.frame_atlas_path == expected_path and is_equal_approx(art.draw_scale,expected_scale) and is_equal_approx(absf(fixture.sprite.scale.x),fixture.sprite.scale.y),"Correct donor source uses manifest scale with uniform XY fit: "+id+"/"+art.pose_name)
	if not source_alpha_checked.has(art.frame_atlas_path):
		var texture: Texture2D = (fixture.sprite.texture as AtlasTexture).atlas
		var image: Image = texture.get_image()
		_check(image != null and image.detect_alpha() != Image.ALPHA_NONE,"Runtime source texture retains real alpha: "+art.frame_atlas_path)
		source_alpha_checked[art.frame_atlas_path] = true

func _capture(label: String) -> void:
	caption.text = "COMPONENT FIXTURE · actual physics displacement\n%s · %s\nNot natural NPC AI walking; green dot = measured contact, not a foot-lock claim." % [fixture.identity,fixture.art.pose_name]
	await RenderingServer.frame_post_draw
	var output: String = evidence.path_join(label+".png")
	_check(root.get_texture().get_image().save_png(output) == OK,"Native true-alpha atlas capture: "+label)
	captures.append({"label":label,"path":output,"frame":fixture.art.frame_index,"atlas":fixture.art.frame_atlas_path,"scale":fixture.art.draw_scale,"driver_x":fixture.position.x})

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; print("FAIL: "+label)

func _finish() -> void:
	var output := FileAccess.open(evidence.path_join("tan_dang_sprite_stride.json"),FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"scope":"Production presentation component driven by actual physics-frame displacement in an isolated fixture; NOT natural NPC AI walking, gameplay combat cancellation, production capsule proof or foot-lock/FPS proof. Pose holds exist only to capture inspection samples.","checks":checks,"failures":failures,"physics_hz":Engine.physics_ticks_per_second,"captures":captures,"actors":reports},"\t"))
		output.close()
	stage.queue_free()
	await process_frame
	if root.has_node("AudioManager"): await root.get_node("AudioManager").shutdown()
	print("RESULT TanDangSpriteStride checks=%d failures=%d captures=%d" % [checks,failures,captures.size()])
	quit(0 if failures == 0 else 1)

extends SceneTree
const Art = preload("res://scripts/presentation/tan_dang_sprite_art.gd")
const Terrain = preload("res://scripts/presentation/existing_route_terrain.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	Engine.physics_ticks_per_second = 120 if "--hz=120" in OS.get_cmdline_user_args() else 60
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+label)
func _step() -> void:
	for _i: int in 4: await process_frame; await physics_frame
func _run() -> void:
	if DisplayServer.get_name() != "headless": quit(2); return
	AudioServer.set_bus_mute(0, true)
	var identities: Dictionary[String, int] = {}
	var live_baseline: int = 0
	for lap: int in 4:
		for id: String in Art.IDS:
			var owner_node := Node2D.new()
			var sprite := Sprite2D.new()
			owner_node.add_child(sprite); root.add_child(owner_node)
			var art := Art.new()
			_check(art.configure(owner_node, sprite, id), "Existing manifest/regions configure "+id)
			for frame: AtlasTexture in art.get("_frames"):
				var path: String = frame.atlas.resource_path
				if lap == 0: identities[path] = frame.atlas.get_instance_id()
				_check(frame.atlas.get_instance_id() == identities[path], "Same authored sheet survives actor turnover")
			var weak_actor: WeakRef = weakref(owner_node)
			var weak_art: WeakRef = weakref(art)
			owner_node.queue_free(); art = null; sprite = null; owner_node = null
			await _step()
			_check(weak_actor.get_ref() == null and weak_art.get_ref() == null, "Texture bank retains no actor or adapter")
		_check(Art.resident_atlases.size() == 7 and identities.size() == 7, "Only seven authored sheets resident")
		if lap == 0: live_baseline = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
		else: _check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) == live_baseline, "Resource count plateaus after warmup")
	var other: Texture2D = Art._atlas_texture(Terrain.FALLBACK.resource_path)
	_check(other != null and not Art.resident_atlases.has(Terrain.FALLBACK.resource_path) and Art.resident_atlases.size() == 7, "Non-catalog texture loads without joining resident bank")
	other = null
	var first: Texture2D = Terrain._texture()
	var texture_id: int = first.get_instance_id()
	var weak_texture: WeakRef = weakref(first)
	first = null
	await _step()
	_check(weak_texture.get_ref() != null and Terrain._texture().get_instance_id() == texture_id, "One terrain source survives room turnover")
	var texels: int = 0
	for texture: Texture2D in Art.resident_atlases.values(): texels += texture.get_width()*texture.get_height()
	texels += Terrain._texture().get_width()*Terrain._texture().get_height()
	print("METRIC_RESIDENT texture_count=8 rgba8_base_level_bytes=", texels*4, " (estimate excludes compression, mips and driver allocation)")
	_check(identities.size() == 7, "Custom load cannot replace authored bank members")
	root.get_node("AudioManager").call("shutdown")
	print("RESULT BoundedAtlasResidency checks=%d failures=%d hz=%d" % [checks, failures, Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

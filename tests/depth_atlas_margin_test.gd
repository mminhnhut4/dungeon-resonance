extends SceneTree
## Verify Godot's virtual Atlas padding and manual foot contract without a GPU.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var source: Texture2D = load("res://assets/sprites/depth/depth_boss_2.png") as Texture2D
	var frame := AtlasTexture.new()
	frame.atlas = source
	frame.region = Rect2(16, 349, 384, 381)
	frame.margin = Rect2(4, 4, 8, 8)
	frame.filter_clip = true
	_check(frame.get_size() == Vector2(392, 389), "Atlas draw size contains the authored virtual transparent margin")
	_check(frame.get_image().get_size() == Vector2i(384, 381), "Atlas get_image samples source region and excludes virtual draw padding")
	var sampler := DepthEnemyArt.new()
	var bank: Dictionary = sampler._multi_sheet_bank([{"path": "res://assets/sprites/depth/depth_boss_2.png", "columns": 1, "regions": [[16, 349, 384, 381]], "margin": [4, 4, 8, 8], "scale_height": 345}])
	_check(bank.frames.size() == 1 and bank.frames[0].get_size() == frame.get_size() and bank.frames[0].region == frame.region and bank.frames[0].margin == frame.margin, "Multi-sheet bank preserves exact source region and draw padding")
	var pivots: Array[Vector2] = [Vector2.ZERO]
	_check(sampler._apply_authored_pivots(pivots, [[182, 368]], bank.frames, true) and pivots[0] == Vector2(182, 368), "Authored boot pivot accounts for source region plus draw margin")
	var sprite := Sprite2D.new()
	root.add_child(sprite)
	sprite.position = Vector2(600, 640)
	sprite.texture = frame
	sprite.centered = false
	sprite.scale = Vector2.ONE * (110.0 / 345.0)
	EnemySpriteArt.set_facing(sprite, pivots[0], false)
	_check(EnemySpriteArt.foot_world(sprite, pivots[0]).is_equal_approx(sprite.global_position), "Right-facing padded raster remains at the physical foot")
	EnemySpriteArt.set_facing(sprite, pivots[0], true)
	_check(EnemySpriteArt.foot_world(sprite, pivots[0]).is_equal_approx(sprite.global_position), "Left-facing padded raster remains at the same physical foot")
	_check(frame.filter_clip, "Atlas draw clips texture filtering outside its authored source region")
	sprite.free()
	sampler.free()
	print("RESULT: AtlasMargin %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", label])

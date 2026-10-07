extends SceneTree

const MANIFEST := "res://docs/verification/asset_pipeline_manifest.json"
const PNG_MAGIC := [137, 80, 78, 71, 13, 10, 26, 10]
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_check(parsed is Dictionary, "asset manifest parses")
	if not parsed is Dictionary:
		quit(1)
		return
	var manifest: Dictionary = parsed
	var assets: Array = manifest.get("assets", [])
	_check(assets.size() == 5, "all five source images are accounted for")
	var catalog: Dictionary = {}
	for asset: Dictionary in assets:
		catalog[asset.id] = asset
		var path: String = asset.destination
		var source: String = asset.backup_path
		_check(FileAccess.file_exists(source) and FileAccess.get_sha256(source) == asset.original_sha256, "%s original source bytes archived intact" % asset.id)
		var archived_original: String = asset.get("archived_original_path", "")
		_check(FileAccess.file_exists(archived_original) and FileAccess.get_sha256(archived_original) == asset.original_sha256, "%s original staging file preserved in moved archive" % asset.id)
		_check(FileAccess.get_sha256(path) == asset.destination_sha256, "%s destination byte hash matches reviewed asset" % asset.id)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		_check(bytes.size() >= 8 and bytes.slice(0, 8) == PackedByteArray(PNG_MAGIC), "%s is real PNG encoding" % asset.id)
		var image := Image.new()
		var decode_error: Error = image.load_png_from_buffer(bytes)
		_check(decode_error == OK and image.get_size() == Vector2i(asset.width, asset.height), "%s PNG dimensions match original" % asset.id)
		_check(decode_error == OK and _pixel_hash(image) == asset.decoded_rgba8_sha256, "%s destination decoded pixels unchanged" % asset.id)
		var original_image: Image = _decode_original(source, asset.source_format)
		_check(not original_image.is_empty() and _pixel_hash(original_image) == asset.decoded_rgba8_sha256, "%s source-to-destination is pixel equivalent" % asset.id)
		var texture: Texture2D = load(path) as Texture2D
		_check(texture != null and texture.get_size() == Vector2(asset.width, asset.height), "%s imports as Texture2D" % asset.id)
		if texture != null:
			_check(_pixel_hash(texture.get_image()) == asset.decoded_rgba8_sha256, "%s imported texture retains lossless pixels" % asset.id)
		_check(image.detect_alpha() == Image.ALPHA_NONE, "%s opaque original background remains intact" % asset.id)
		var import_path: String = path + ".import"
		_check(FileAccess.file_exists(import_path) and FileAccess.get_file_as_string(import_path).contains('source_file="%s"' % path), "%s import metadata regenerated for destination" % asset.id)
		_check(FileAccess.file_exists(source + ".import") and FileAccess.get_sha256(source + ".import") == asset.get("source_metadata_sha256", ""), "%s source import metadata archived intact" % asset.id)
	if catalog.has("player_concept_closeup") and catalog.has("player_concept_closeup_duplicate_01"):
		var first: Dictionary = catalog.player_concept_closeup
		var duplicate: Dictionary = catalog.player_concept_closeup_duplicate_01
		_check(first.original_sha256 == duplicate.original_sha256 and duplicate.duplicate_of == first.id, "duplicate identity recorded from original bytes")
		_check(first.destination != duplicate.destination and first.destination_sha256 == duplicate.destination_sha256, "duplicate retained in its own meaningful path")
	if catalog.has("npc_merchant_kael"):
		var kael: Dictionary = catalog.npc_merchant_kael
		_check(kael.source_extension == "png" and kael.source_format == "jpeg" and kael.source_format_mismatch and kael.conversion == "godot_image_jpeg_decode_png_encode", "Kael renamed JPEG detected and really transcoded")
	var atlas_data: Dictionary = manifest.atlas_sample
	var atlas: AtlasTexture = load(atlas_data.path) as AtlasTexture
	_check(atlas != null and atlas.atlas != null, "sample AtlasTexture resolves the imported stone sheet")
	if atlas != null and atlas.atlas != null:
		var region: Rect2 = atlas.region
		_check(region == Rect2(32, 60, 100, 90) and Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(region), "sample region is inside the real first stone block")
		_check(atlas.filter_clip and atlas.get_size() == Vector2(100, 90), "atlas crop has exact size and edge filtering clip")
		_check(_pixel_hash(atlas.get_image()) == atlas_data.decoded_rgba8_sha256, "AtlasTexture pixels match verified source region")
		var sheet_image: Image = atlas.atlas.get_image()
		_check(_pixel_hash(sheet_image.get_region(Rect2i(region))) == atlas_data.decoded_rgba8_sha256, "atlas region hash is derived from original sheet pixels")
	_check(not atlas_data.grid_ready, "concept sheet is not misreported as a playable grid TileSet")
	for directory: String in ["res://assets/sprites/player", "res://assets/sprites/npc", "res://assets/environment/tilesets", "res://assets/environment/props"]:
		_check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)), "required asset directory exists: %s" % directory)
	_check(FileAccess.file_exists("res://assets/environment/props/README.md"), "empty props role is documented")
	_check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://staging_assets")) and manifest.staging_removed, "reviewed staging directory removed")
	_check(manifest.get("staging_disposition", "") == "archived_after_delete_auto_review_rejection" and not manifest.get("original_source_bytes_deleted", true), "original staging was archived without claiming source byte deletion")
	var stale: Array[String] = []
	for directory: String in ["res://scenes", "res://scripts", "res://data", "res://assets/sprites", "res://assets/environment"]:
		_scan_stale_references(directory, stale)
	if FileAccess.get_file_as_string("res://project.godot").contains("res://staging_assets"):
		stale.append("res://project.godot")
	_check(stale.is_empty(), "product references contain no obsolete staging path: %s" % str(stale))
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _decode_original(path: String, format: String) -> Image:
	var image := Image.new()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	match format:
		"webp": image.load_webp_from_buffer(bytes)
		"jpeg": image.load_jpg_from_buffer(bytes)
		"png": image.load_png_from_buffer(bytes)
	return image


func _pixel_hash(image: Image) -> String:
	if image == null or image.is_empty():
		return ""
	var canonical: Image = image.duplicate() as Image
	if canonical.is_compressed():
		canonical.decompress()
	canonical.clear_mipmaps()
	canonical.convert(Image.FORMAT_RGBA8)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.get_data())
	return context.finish().hex_encode()


func _scan_stale_references(path: String, stale: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	for child: String in directory.get_directories():
		_scan_stale_references(path.path_join(child), stale)
	for filename: String in directory.get_files():
		if filename.get_extension() not in ["gd", "tscn", "tres"]:
			continue
		var full_path: String = path.path_join(filename)
		if FileAccess.get_file_as_string(full_path).contains("res://staging_assets"):
			stale.append(full_path)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

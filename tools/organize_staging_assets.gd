extends SceneTree

const STAGING := "res://staging_assets"
const BACKUP := "res://docs/verification/asset_pipeline_sources"
const MANIFEST := "res://docs/verification/asset_pipeline_manifest.json"
const ARCHIVE := BACKUP + "/staging_archive"
const ATLAS := "res://assets/environment/tilesets/dungeon_stone_tile_sample.tres"
const REGION := Rect2i(32, 60, 100, 90)
const MAPPING: Array[Dictionary] = [
	{"id": "dungeon_stone_tileset", "source": "2D_horizontal_side-scrolling_platformer_dungeon_tileset_goth.webp", "destination": "res://assets/environment/tilesets/dungeon_stone_tileset.png", "role": "environment_concept_sheet"},
	{"id": "player_concept_full", "source": "2D_side_view_character_concept_art_of_an_Eastern_fantasy_wan (2).webp", "destination": "res://assets/sprites/player/player_concept_full.png", "role": "player_concept"},
	{"id": "player_concept_closeup", "source": "2D_side_view_character_concept_art_of_an_Eastern_fantasy_wan.webp", "destination": "res://assets/sprites/player/player_concept_closeup.png", "role": "player_closeup"},
	{"id": "player_concept_closeup_duplicate_01", "source": "2D_side_view_character_concept_art_of_an_Eastern_fantasy_wan (1).webp", "destination": "res://assets/sprites/player/variants/player_concept_closeup_duplicate_01.png", "role": "preserved_duplicate", "duplicate_of": "player_concept_closeup"},
	{"id": "npc_merchant_kael", "source": "davinci_2d_character_reference_model_sheet__full_body_view.png", "destination": "res://assets/sprites/npc/npc_merchant_kael.png", "role": "npc_reference_sheet"},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous: Dictionary = {}
	var previous_manifest: Dictionary = {}
	if FileAccess.file_exists(MANIFEST):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if parsed is Dictionary:
			previous_manifest = parsed
			for asset: Dictionary in parsed.get("assets", []):
				previous[asset.id] = asset
	if FileAccess.file_exists(ATLAS) and FileAccess.get_file_as_string(ATLAS) != _atlas_source():
		_fail("Refusing to overwrite a changed AtlasTexture sample")
		return
	var prepared: Array[Dictionary] = []
	# Preflight every target and original before making any changes.
	for mapping: Dictionary in MAPPING:
		var original: String = STAGING.path_join(mapping.source)
		var backup_path: String = BACKUP.path_join(mapping.source)
		var readable_source: String = original if FileAccess.file_exists(original) else backup_path
		if not FileAccess.file_exists(readable_source):
			_fail("Missing original or archived source: %s" % original)
			return
		var original_hash: String = FileAccess.get_sha256(readable_source)
		if FileAccess.file_exists(backup_path) and FileAccess.get_sha256(backup_path) != original_hash:
			_fail("Backup collision: %s" % backup_path)
			return
		if FileAccess.file_exists(mapping.destination):
			var owned: Dictionary = previous.get(mapping.id, {})
			if owned.get("original_sha256", "") != original_hash or owned.get("destination_sha256", "") != FileAccess.get_sha256(mapping.destination):
				_fail("Refusing to overwrite an unowned or changed asset: %s" % mapping.destination)
				return
		var decoded: Dictionary = _decode_source(readable_source)
		var source_image: Image = decoded.image
		if decoded.error != OK or source_image.is_empty():
			_fail("Cannot decode source: %s" % readable_source)
			return
		source_image.convert(Image.FORMAT_RGBA8)
		var record: Dictionary = mapping.duplicate()
		record.source_path = original
		record.backup_path = backup_path
		record.original_sha256 = original_hash
		record.decoded_rgba8_sha256 = _pixel_hash(source_image)
		record.width = source_image.get_width()
		record.height = source_image.get_height()
		record.opaque = source_image.detect_alpha() == Image.ALPHA_NONE
		record.source_extension = mapping.source.get_extension()
		record.source_format = decoded.format
		record.source_format_mismatch = record.source_extension != record.source_format
		record.image = source_image
		record.readable_source = readable_source
		prepared.append(record)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP)) != OK:
		_fail("Cannot create archive directory")
		return
	var assets: Array[Dictionary] = []
	for record: Dictionary in prepared:
		if not FileAccess.file_exists(record.backup_path):
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(record.readable_source), ProjectSettings.globalize_path(record.backup_path)) != OK:
				_fail("Cannot archive original: %s" % record.source_path)
				return
		var old_metadata: String = record.source_path + ".import"
		var metadata_backup: String = record.backup_path + ".import"
		if FileAccess.file_exists(old_metadata) and not FileAccess.file_exists(metadata_backup):
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(old_metadata), ProjectSettings.globalize_path(metadata_backup)) != OK:
				_fail("Cannot archive source import metadata")
				return
		if FileAccess.file_exists(metadata_backup):
			record.source_metadata_sha256 = FileAccess.get_sha256(metadata_backup)
		var archived_original: String = ARCHIVE.path_join(record.source)
		if FileAccess.file_exists(archived_original):
			if FileAccess.get_sha256(archived_original) != record.original_sha256:
				_fail("Preserved staging archive changed")
				return
			record.archived_original_path = archived_original
		if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(record.destination.get_base_dir())) != OK:
			_fail("Cannot create asset directory")
			return
		if not FileAccess.file_exists(record.destination):
			var write_error: Error = OK
			if record.source_format == "png":
				write_error = DirAccess.copy_absolute(ProjectSettings.globalize_path(record.readable_source), ProjectSettings.globalize_path(record.destination))
			else:
				write_error = (record.image as Image).save_png(record.destination)
			if write_error != OK:
				_fail("Cannot write destination: %s" % record.destination)
				return
		var destination_image := Image.new()
		if destination_image.load(ProjectSettings.globalize_path(record.destination)) != OK:
			_fail("Cannot reload destination PNG")
			return
		destination_image.convert(Image.FORMAT_RGBA8)
		if destination_image.get_size() != Vector2i(record.width, record.height) or _pixel_hash(destination_image) != record.decoded_rgba8_sha256:
			_fail("Decoded pixel mismatch: %s" % record.destination)
			return
		record.destination_sha256 = FileAccess.get_sha256(record.destination)
		record.pixel_equivalent = true
		record.conversion = "original_png_bytes_preserved" if record.source_format == "png" else "godot_image_%s_decode_png_encode" % record.source_format
		record.erase("image")
		record.erase("readable_source")
		assets.append(record)
		print("ASSET: %s %dx%d lossless pixels verified" % [record.destination, record.width, record.height])
	var sheet := Image.new()
	if sheet.load(ProjectSettings.globalize_path(MAPPING[0].destination)) != OK or not Rect2i(Vector2i.ZERO, sheet.get_size()).encloses(REGION):
		_fail("Atlas region outside the real sheet")
		return
	var crop: Image = sheet.get_region(REGION)
	var preview_path: String = BACKUP.path_join("_atlas_region_preview.png")
	if crop.save_png(preview_path) != OK:
		_fail("Cannot save atlas verification preview")
		return
	var atlas_file := FileAccess.open(ATLAS, FileAccess.WRITE)
	if atlas_file == null:
		_fail("Cannot save AtlasTexture")
		return
	atlas_file.store_string(_atlas_source())
	atlas_file.close()
	var manifest: Dictionary = {
		"schema_version": 1,
		"engine_version": Engine.get_version_info().string,
		"assets": assets,
		"atlas_sample": {"path": ATLAS, "source": MAPPING[0].destination, "region": [REGION.position.x, REGION.position.y, REGION.size.x, REGION.size.y], "decoded_rgba8_sha256": _pixel_hash(crop), "verification_preview": preview_path, "grid_ready": false},
		"staging_removed": not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(STAGING)),
		"source_import_metadata": "archived only; regenerate destination .import through Godot editor import",
		"product_references_changed": false,
	}
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ARCHIVE)):
		manifest.archived_path = ARCHIVE
		manifest.staging_disposition = "archived_after_delete_auto_review_rejection"
		manifest.original_source_bytes_deleted = false
	manifest.destination_images_visually_inspected = previous_manifest.get("destination_images_visually_inspected", false)
	var manifest_file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Cannot save asset manifest")
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()
	print("RESULT: 5 source images archived and organized; source removal requires reviewed PNGs and native PowerShell checks")
	quit()


func _pixel_hash(image: Image) -> String:
	var canonical: Image = image.duplicate() as Image
	canonical.convert(Image.FORMAT_RGBA8)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.get_data())
	return context.finish().hex_encode()


func _atlas_source() -> String:
	return "[gd_resource type=\"AtlasTexture\" load_steps=2 format=3]\n\n[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1_sheet\"]\n\n[resource]\natlas = ExtResource(\"1_sheet\")\nregion = Rect2(%d, %d, %d, %d)\nfilter_clip = true\n" % [MAPPING[0].destination, REGION.position.x, REGION.position.y, REGION.size.x, REGION.size.y]


func _decode_source(path: String) -> Dictionary:
	# File signatures take precedence over names: the Kael .png is JPEG/JFIF.
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var image := Image.new()
	var format: String = "unknown"
	var result: Error = ERR_FILE_UNRECOGNIZED
	if bytes.size() >= 8 and bytes.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		format = "png"
		result = image.load_png_from_buffer(bytes)
	elif bytes.size() >= 3 and bytes[0] == 255 and bytes[1] == 216 and bytes[2] == 255:
		format = "jpeg"
		result = image.load_jpg_from_buffer(bytes)
	elif bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		format = "webp"
		result = image.load_webp_from_buffer(bytes)
	return {"image": image, "format": format, "error": result}


func _fail(message: String) -> void:
	print("FAIL: %s" % message)
	quit(1)

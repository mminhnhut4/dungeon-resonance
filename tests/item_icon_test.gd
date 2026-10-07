extends SceneTree
## Focused art binding fixture. No world, profile, economy transaction or GPU.

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + description)

func _run() -> void:
	print("ICON ENV user_dir=%s renderer=%s" % [OS.get_user_data_dir(), DisplayServer.get_name()])
	var mappings: Dictionary = {
		&"potion": "03_medicine_flask.png",
		&"metal": "04_iron_ore.png",
		&"healing_herb": "05_moonleaf_herb.png",
		&"crystal": "08_resonance_shard.png",
	}
	for id: StringName in mappings:
		var texture: Texture2D = ItemArtCatalog.icon(id)
		_check(texture != null and texture.resource_path.ends_with(mappings[id]), "Existing %s resolves to its verified icon" % id)
		_check(texture != null and texture.get_width() <= 256 and texture.get_height() <= 256, "Existing %s uses bounded runtime import dimensions" % id)
		var image: Image = texture.get_image()
		_check(image != null and image.get_pixel(0, 0).a == 0.0, "Existing %s keeps transparent source corners after import" % id)
	var inventory := GearInventory.new()
	var sword: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD)
	var bounty: GearItem = inventory.add_equipment(preload("res://data/equipment/ancient_sword_bounty.tres"))
	var ledger_before: Array = inventory.items.keys()
	var sword_damage: float = sword.damage_factor()
	var source_icon: Texture2D = GearInventory.COMMON_SWORD.icon_texture
	_check(ItemArtCatalog.gear_icon(sword).resource_path.ends_with("01_iron_jian.png") and ItemArtCatalog.gear_icon(bounty) == ItemArtCatalog.gear_icon(sword), "Both existing travel sword IDs use the shared approved sword icon")
	_check(ItemArtCatalog.gear_icon(sword).get_width() <= 256, "Sword uses bounded runtime import dimensions")
	sword.broken = true
	_check(ItemArtCatalog.gear_icon(sword) == ItemArtCatalog.icon(&"broken_sword"), "Broken equipment keeps its existing distinct broken silhouette")
	sword.broken = false
	var clothing: GearItem = inventory.add_equipment(GearInventory.STARTER_CLOTHING[0])
	_check(ItemArtCatalog.gear_icon(clothing) == clothing.equipment_definition.icon_texture, "Unmatched clothing retains its authored icon")
	_check(GearInventory.COMMON_SWORD.icon_texture == source_icon and source_icon.resource_path.ends_with("common_sword.png"), "Cached equipment/world sprite definition is not mutated by UI art override")
	_check(sword_damage == sword.damage_factor() and inventory.items.has(sword.uid) and inventory.items.has(bounty.uid) and ledger_before.size() + 1 == inventory.items.size(), "Art lookup preserves runtime factors and owned UIDs")
	_check(ItemArtCatalog.icon(&"sealed_letter") == null and ItemArtCatalog.icon(&"sect_token") == null and ItemArtCatalog.icon(&"travel_talisman") == null, "Unmatched art does not invent inventory IDs")
	_check(ItemArtCatalog.RUNE_ICONS[&"fire"].resource_path.ends_with("icon_fire.png") and ItemArtCatalog.RUNE_ICONS[&"wind"].resource_path.ends_with("icon_wind.png"), "Element-specific rune art is preserved")
	print("RESULT item_icons checks=%d failures=%d" % [checks, failures])
	await root.get_node("AudioManager").shutdown()
	quit(0 if failures == 0 else 1)

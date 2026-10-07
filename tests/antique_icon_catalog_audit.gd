extends SceneTree
## Bounded inventory presentation audit; data is read, never added or purchased.

var entries: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for id: StringName in MaterialCatalog.IDS:
		_add("material", id, MaterialCatalog.DISPLAY_NAMES[id], ItemArtCatalog.icon(id), AntiqueSkin.item_description(id), "missing_final" if ItemArtCatalog.icon(id) == null else "covered")
	for id: StringName in [&"potion", &"bandage", &"antidote", &"trap"]:
		_add("consumable", id, ItemArtCatalog.display_name(id) if id != &"trap" else "Bẫy", ItemArtCatalog.icon(id), AntiqueSkin.item_description(id), "missing" if ItemArtCatalog.icon(id) == null else "covered")
	for path: String in DirAccess.get_files_at("res://data/equipment"):
		if not path.ends_with(".tres"): continue
		var data: EquipmentData = load("res://data/equipment/" + path) as EquipmentData
		var item := GearItem.new()
		item.equipment_definition = data
		item.definition_id = data.id
		item.kind = EquipmentData.SLOT_KINDS[data.slot_type]
		_add("equipment", data.id, data.item_name, ItemArtCatalog.gear_icon(item), data.description, "partial_body_cutout" if data.id in [&"starter_top", &"starter_pants"] else "covered")
	for rune: RuneData in GearInventory.RUNES:
		_add("rune", rune.id, rune.display_name, ItemArtCatalog.RUNE_ICONS.get(rune.id, ItemArtCatalog.FALLBACK), "Bùa khảm theo nguyên tố thật", "generic_fallback" if not ItemArtCatalog.RUNE_ICONS.has(rune.id) else "covered")
	for path: String in DirAccess.get_files_at("res://data/weapons"):
		if not path.ends_with(".tres"): continue
		var data: WeaponDefinition = load("res://data/weapons/" + path) as WeaponDefinition
		if data.id == &"unarmed" or data.id == &"training_sword" or WeaponVariantCatalog.IDS.has(data.id): continue
		var runtime := GearItem.new()
		runtime.kind = &"weapon"
		runtime.definition_id = data.id
		if data.id == &"ancient_sword": runtime.equipment_definition = GearInventory.COMMON_SWORD
		if data.id == &"ancient_sword_bounty": runtime.equipment_definition = preload("res://data/equipment/ancient_sword_bounty.tres")
		var icon: Texture2D = ItemArtCatalog.gear_icon(runtime)
		_add("legacy_weapon_runtime", data.id, data.display_name, icon, "WeaponDefinition runtime; no EquipmentData assigned in legacy add_item path", "generic_fallback" if icon == ItemArtCatalog.FALLBACK else "covered")
	var catalyst: CatalystData = preload("res://data/catalysts/starter_catalyst.tres")
	_add("catalyst", catalyst.id, catalyst.display_name, ItemArtCatalog.FALLBACK, "Bộ xúc tác ba ô khởi đầu", "generic_fallback")
	for path: String in DirAccess.get_files_at("res://data/relics"):
		if not path.ends_with(".tres"): continue
		var relic: RelicData = load("res://data/relics/" + path) as RelicData
		_add("relic", relic.id, relic.display_name, ItemArtCatalog.FALLBACK, relic.description, "generic_fallback")
	var counts: Dictionary = {}
	var missing: Array[Dictionary] = []
	for item: Dictionary in entries:
		counts[item["kind"]] = int(counts.get(item["kind"],0)) + 1
		if item["status"] != "covered": missing.append(item)
	DirAccess.make_dir_recursive_absolute("res://docs/verification/antique_ui")
	var file: FileAccess = FileAccess.open("res://docs/verification/antique_ui/catalog_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"counts":counts,"entries":entries,"pending":missing,"weapon_variants":"60 quality definitions share 10 authored family model icons; not 60 missing artworks", "scope":"Actual materials, consumables, equipment definitions, five runes, legacy runtime weapon definitions, catalyst and relics. Excludes unarmed/training fixture as non-inventory content."},"\t"))
	file.close()
	print("RESULT AntiqueIconCatalog entries=%d pending=%d counts=%s" % [entries.size(),missing.size(),str(counts)])
	await root.get_node("AudioManager").shutdown()
	quit()

func _add(kind: String, id: StringName, title: String, icon: Texture2D, function: String, status: String) -> void:
	entries.append({"kind":kind,"id":String(id),"name":title,"current_icon":icon.resource_path if icon != null else null,"function":function,"status":status})

extends SceneTree
## Approved world/item/campfire adapters through actual scenes and pickup owners.

var flow: GameFlow
var hub: PrologueHub
var art: PrologueHubArt
var audio: Node
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	# Preserve this milestone's original fixture; World suites cover the new main.
	flow.world_building_enabled = false
	flow.campaign_scene = null
	flow.save_path_override = "user://verification/prologue_visual_%d.json" % Engine.physics_ticks_per_second
	root.add_child(flow)
	current_scene = flow
	hub = flow.active_scene as PrologueHub
	art = hub.get_node("PrologueHubArt") as PrologueHubArt
	audio = root.get_node("AudioManager")
	hub.feedback.hit_stop_seconds = 0.0
	var terrain_before: Dictionary = _terrain(hub)
	var player_shape: CollisionShape2D = hub.player.get_node("BodyCollision") as CollisionShape2D
	var player_shape_id: int = player_shape.shape.get_instance_id()
	var player_shape_transform: Transform2D = player_shape.transform
	await _step(12)
	print("PROLOGUE VISUAL TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	_check(art.hub == hub and art.yard_art != null and art.home_art != null, "Actual opt-in Prologue scene mounts its deferred approved art adapter")
	_check(_terrain(hub) == terrain_before and player_shape.shape.get_instance_id() == player_shape_id and player_shape.transform == player_shape_transform, "Deferred world art leaves terrain and Player shape identities/transforms untouched")
	_check(hub.player.motor.is_grounded() and is_equal_approx(hub.player.global_position.y, 640.0), "Modular Player stands naturally on the real yard collision top")
	await _test_world_art()
	await _test_pickups()
	await _test_campfire()
	await _test_campfire_rebuild()
	await _test_spawn_lifetime()
	await _test_dungeon()
	flow.queue_free()
	await _step(5)
	_check(get_nodes_in_group(&"loot").is_empty() and get_nodes_in_group(&"campfires").is_empty() and audio.get_active_voice_count() == 0, "Final Hub/Dungeon teardown releases pickups, fires and ambient owners")
	_check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "Visual adapters leave global time and pause neutral")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_world_art() -> void:
	var hud: ArtHUD = hub.presentation.art_hud
	var starter_uid: int = hub.gear.inventory.equipped_weapon_uid
	var starter: GearItem = hub.gear.inventory.items[starter_uid]
	hud.refresh_hud()
	_check(starter.quality == GearItem.Quality.COMMON and starter.equipment_definition == GearInventory.COMMON_SWORD and hud.weapon_icon.texture == starter.equipment_definition.icon_texture and hud.weapon_name.text == starter.equipment_definition.item_name, "Actual starter HUD reads the owned Common item's icon/name rather than the generic moveset presentation")
	var rare: GearItem = hub.gear.inventory.add_equipment(PrologueHub.RARE_SWORD, GearItem.Quality.RARE)
	var equipped: bool = hub.gear.inventory.equip_equipment(rare.uid)
	await _step(2)
	hud.refresh_hud()
	_check(equipped and hub.gear.inventory.equipped_weapon_uid == rare.uid and rare.definition_id != hub.player.equipped_weapon.definition.id and hud.weapon_icon.texture == rare.equipment_definition.icon_texture and hud.weapon_name.text == rare.equipment_definition.item_name and hub.player.equipped_weapon.additional_runes.has(rare.equipment_definition.intrinsic_runes[0]), "Actual Rare equip refreshes HUD from its owned UID and intrinsic rune rather than the differently named moveset")
	hub.gear.inventory.equip_equipment(starter_uid)
	await _step(2)
	var yard_sprites: Array[Node] = art.yard_art.find_children("*", "Sprite2D", true, false)
	var yard_background: Sprite2D = yard_sprites[0] as Sprite2D
	var yard_floor: Sprite2D = yard_sprites[1] as Sprite2D
	var yard_region: AtlasTexture = yard_background.texture as AtlasTexture
	_check(yard_region.atlas == PrologueHubArt.YARD and yard_background.z_index < 0 and (yard_background.material as CanvasItemMaterial).light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "Courtyard uses the approved cropped painting behind actors without an opaque foreground sheet")
	_check(yard_floor.global_position.y == 640.0 and yard_floor.texture.get_size() * yard_floor.scale == Vector2(2400, 80), "Painted yard floor begins at the actual 640px collision surface")
	var home_sprites: Array[Node] = art.home_art.find_children("*", "Sprite2D", true, false)
	var home_floor: Sprite2D = home_sprites[1] as Sprite2D
	_check((home_sprites[0] as Sprite2D).texture is AtlasTexture and ((home_sprites[0] as Sprite2D).texture as AtlasTexture).atlas == PrologueHubArt.HOME and home_floor.global_position.y == 640.0, "Indoor painting and its floor are separate crops aligned to the existing home floor")
	var placeholders_hidden: bool = true
	for candidate: Node in hub.yard.find_children("*", "StaticBody2D", true, false):
		for child: Node in candidate.get_children():
			if child is Polygon2D:
				placeholders_hidden = placeholders_hidden and not child.visible
	_check(placeholders_hidden and not hub.presentation.atmosphere.room_art.visible and hub.presentation.foyer_art.decoration == null, "Approved courtyard suppresses the old flat floor and dungeon decoration overlays")
	var kael: Sprite2D = hub.yard.get_node("KaelSprite") as Sprite2D
	var geometry: Dictionary = EnemySpriteArt.alpha_geometry(kael.texture)
	_check(kael.texture == PrologueHubArt.KAEL and kael.texture != PrologueHub.KAEL and _alpha(kael.texture), "Kael renders the approved side sprite with alpha instead of the full concept sheet")
	_check(EnemySpriteArt.foot_world(kael, geometry["foot_pixel"]).is_equal_approx(hub.stations[&"merchant"].global_position), "Kael's solid alpha feet anchor to the merchant's ground marker")
	for id: StringName in [&"house", &"portal", &"stash", &"blacksmith"]:
		var sprites: Array[Node] = hub.stations[id].find_children("*", "Sprite2D", true, false)
		var prop: Sprite2D = sprites[0] as Sprite2D
		var atlas: AtlasTexture = prop.texture as AtlasTexture
		_check(sprites.size() == 1 and atlas != null and atlas.atlas == PrologueHubArt.PROPS and _alpha(atlas) and absf(prop.to_global(Vector2(0, prop.texture.get_height())).y - 640.0) < 0.01, "Station %s draws one transparent approved crop with its base at ground" % id)
	var art_children: int = art.yard_art.get_child_count()
	var prop_count: int = hub.yard.find_children("*", "Sprite2D", true, false).size()
	art.initialize(hub)
	art.initialize(hub)
	await _step(2)
	_check(art.yard_art.get_child_count() == art_children and hub.yard.find_children("*", "Sprite2D", true, false).size() == prop_count and get_nodes_in_group(&"campfires").size() == 1, "Repeated deferred initialization cannot duplicate props or the courtyard campfire")


func _test_pickups() -> void:
	hub.player.relocate(Vector2(430, 640))
	var expected_names: Array[String] = ["Tinh Thạch Vụn", "Tinh Chất Slime", "Mảnh Kim Loại Cổ", "Bột Tinh Thể Phép", "Kiếm Mẻ", "Dao Gãy", "Trượng Nứt", "Áo Vải Rách", "Găng Da Sờn", "Thuốc Hồi Máu", "Băng Gạc", "Thuốc Giải Độc"]
	var approved_pngs: Dictionary = {
		&"crystal": "res://assets/ui/items/user_icons_v1/08_resonance_shard.png",
		&"metal": "res://assets/ui/items/user_icons_v1/04_iron_ore.png",
		&"potion": "res://assets/ui/items/user_icons_v1/03_medicine_flask.png",
	}
	var pickups: Array[LootPickup] = []
	var snapshots: Array[Array] = []
	for index: int in ItemArtCatalog.IDS.size():
		var pickup: LootPickup = _spawn_sample(index, Vector2(720 + index * 25, 640))
		pickups.append(pickup)
		snapshots.append(_item_state(pickup.runtime_item))
	await _step(3)
	for index: int in pickups.size():
		var pickup: LootPickup = pickups[index]
		var skin: LootVisualSkin = pickup.get_node("LootVisualSkin") as LootVisualSkin
		var texture: Texture2D = skin.sprite.texture
		var atlas: AtlasTexture = texture as AtlasTexture
		var id: StringName = ItemArtCatalog.IDS[index]
		var correct_source: bool = false
		var bounded_alpha: bool = false
		if approved_pngs.has(id):
			correct_source = texture != null and texture.resource_path == approved_pngs[id]
			bounded_alpha = texture != null and texture.get_width() <= 256 and texture.get_height() <= 256 and _alpha(texture)
		else:
			correct_source = atlas != null and atlas.resource_path.get_file() == "%s.tres" % id
			bounded_alpha = atlas != null and atlas.region.size == Vector2(362, 362) and Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region) and _alpha(atlas)
		_check(pickup.presentation_skin_active and pickup.find_children("*", "Sprite2D", true, false).size() == 1 and correct_source and pickup.item_label.text == expected_names[index], "Actual %s pickup receives its exact approved icon and Vietnamese display name" % id)
		_check(_item_state(pickup.runtime_item) == snapshots[index] and bounded_alpha, "Pickup %s retains its frozen UID/condition with bounded transparent approved art" % id)
	var held: LootPickup = pickups[4]
	var held_uid: int = held.runtime_item.uid
	var held_state: Array = _item_state(held.runtime_item)
	var held_icon: LootVisualSkin = held.get_node("LootVisualSkin") as LootVisualSkin
	var cursor := InputEventMouseMotion.new()
	cursor.position = root.get_final_transform() * held.get_global_transform_with_canvas().origin
	cursor.global_position = cursor.position
	Input.parse_input_event(cursor)
	await _step(1)
	held_icon.refresh()
	_check(held.item_label.visible, "Hovering the real ground pickup reveals its localized name")
	cursor.position = root.get_final_transform() * (held.get_global_transform_with_canvas() * Vector2(250, -150))
	cursor.global_position = cursor.position
	Input.parse_input_event(cursor)
	await _step(1)
	held_icon.refresh()
	_check(not held.item_label.visible, "Ground item name hides when the cursor leaves and Player is far away")
	for scan: int in 4:
		hub.presentation._scan()
	await _step(2)
	_check(pickups.all(func(pickup: LootPickup) -> bool: return pickup.find_children("LootVisualSkin", "Node2D", false, false).size() == 1 and pickup.find_children("*", "Sprite2D", true, false).size() == 1), "Repeated world scans keep exactly one skin/icon per existing pickup")
	_check(held.collect() and hub.gear.inventory.items.has(held_uid) and _item_state(hub.gear.inventory.items[held_uid]) == held_state, "Actual collection transfers the same frozen broken UID without rerolling its visual or loot state")
	_check(not held.collect(), "Double collection cannot duplicate the owned broken item")
	hub.gear.loot.clear()
	await _step(3)
	_check(get_nodes_in_group(&"loot").is_empty(), "Clearing ground loot releases every icon with its pickup owner")


func _test_campfire() -> void:
	var fire: Campfire = art.fire
	var skin: CampfireVisualSkin = fire.get_node("CampfireVisualSkin") as CampfireVisualSkin
	var flame: AnimatedSprite2D = skin.flame
	_check(fire.presentation_skin_active and fire.find_children("CampfireVisualSkin", "Node2D", false, false).size() == 1 and flame.sprite_frames.get_frame_count(&"burn") == 4 and flame.is_playing(), "Courtyard fire replaces the primitive drawing with one four-frame animation adapter")
	var foot_stable: bool = true
	var signatures: Array[int] = []
	for frame: int in 4:
		flame.frame = frame
		var texture: Texture2D = flame.sprite_frames.get_frame_texture(&"burn", frame)
		foot_stable = foot_stable and flame.to_global(flame.offset + Vector2(texture.get_width() * 0.5, 678)).is_equal_approx(fire.global_position)
		signatures.append(hash(texture.get_image().get_data()))
	_check(foot_stable and not signatures.any(func(value: int) -> bool: return signatures.count(value) > 1), "Distinct painted flame frames keep the logs' 678px foot pivot fixed on the floor")
	_check(skin.embers.amount == 8 and skin.embers.lifetime <= 1.2 and not skin.embers.emitting, "Campfire uses only eight finite embers and disables GPU emission in headless")
	var minimum: float = INF
	var maximum: float = -INF
	for frame: int in 30:
		await _step(1)
		minimum = minf(minimum, skin.light.energy)
		maximum = maxf(maximum, skin.light.energy)
	_check(maximum - minimum > 0.02 and minimum > 0.73 and maximum < 0.95 and skin.light.color.r > skin.light.color.g and not skin.light.shadow_enabled, "A real warm PointLight flickers inside its small fixed energy budget")
	audio.stop_all()
	hub.player.relocate(fire.global_position)
	await _step(3)
	_check(_owned_fire_count(skin) == 1 and skin.sound_deadline > Time.get_ticks_msec(), "Walking near the fire starts one finite Ambient cue owned by the adapter")
	var voice_count: int = audio.get_active_voice_count()
	await _step(8)
	_check(_owned_fire_count(skin) == 1 and audio.get_active_voice_count() == voice_count, "Near-fire frames do not create an audio voice every frame")
	hub.player.relocate(Vector2(430, 640))
	await _step(3)
	_check(_owned_fire_count(skin) == 0 and skin.sound_deadline == 0, "Walking beyond the fire range immediately releases its ambient owner")
	hub.player.relocate(fire.global_position)
	await _step(2)
	fire.hide()
	await _step(2)
	_check(_owned_fire_count(skin) == 0 and skin.sound_deadline == 0, "Hiding the campfire cancels its sound instead of renewing invisibly")
	fire.show()
	await _step(2)
	_check(_owned_fire_count(skin) == 1, "Showing a nearby fire starts one new finite segment")
	var player_id: int = hub.player.get_instance_id()
	var terrain: Dictionary = _terrain(hub)
	_check(hub.enter_house(), "The real home transition remains available with art and sound active")
	await _step(3)
	_check(_owned_fire_count(skin) == 0 and art.home_art.is_visible_in_tree() and not art.yard_art.is_visible_in_tree(), "Entering the painted home hides the courtyard and stops its fire ambience")
	_check(hub.player.get_instance_id() == player_id and _terrain(hub) == terrain and hub.player.global_position.is_equal_approx(hub.house.entry_point.global_position), "Indoor art transition retains the same Player and every physical terrain transform")
	_check(hub.leave_house(), "The painted home returns to the same courtyard scene")
	await _step(3)
	for scan: int in 4:
		hub.presentation._scan()
	_check(fire.find_children("CampfireVisualSkin", "Node2D", false, false).size() == 1 and skin.get_child_count() == 3, "Rescans never duplicate animated fire, light, emitters or audio adapter")
	hub.player.relocate(Vector2(430, 640))
	await _step(3)


func _test_spawn_lifetime() -> void:
	# Warm all item kinds first, then measure complete finite spawn/free cycles.
	for index: int in 12:
		_spawn_sample(index, Vector2(850, 640))
	await _step(3)
	hub.gear.loot.clear()
	await _step(3)
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for cycle: int in 4:
		for index: int in 12:
			_spawn_sample(index, Vector2(850, 640))
		await _step(3)
		hub.presentation._scan()
		hub.gear.loot.clear()
		await _step(4)
	_check(hub.gear.loot.get_child_count() == 0 and get_nodes_in_group(&"loot").is_empty(), "Four complete twelve-item spawn/scan/free cycles release all adapters")
	_check(int(Performance.get_monitor(Performance.OBJECT_COUNT)) <= objects and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= resources, "Warm finite pickup cycles retain no extra objects or texture resources")
	print("STRESS: prologue visuals objects=%d->%d resources=%d->%d" % [objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)), resources, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])

func _test_campfire_rebuild() -> void:
	var fire: Campfire = art.fire
	var skin: CampfireVisualSkin = fire.get_node("CampfireVisualSkin") as CampfireVisualSkin
	hub.player.relocate(fire.global_position)
	await _step(3)
	var old_deadline: int = skin.sound_deadline
	_check(_owned_fire_count(skin) == 1 and hub.presentation.campfire_owners.has(skin.get_instance_id()), "Real near-fire cue is audible and registered before the room presentation boundary")
	hub.presentation.rebuild()
	await _step(3)
	_check(_owned_fire_count(skin) == 0 and skin.sound_deadline == 0, "Room presentation rebuild revokes its child campfire audio owner as well as combat voices")
	# Wait past the actual former wall-time deadline: merely moving a timer
	# forward would leave the old fire silently renewing in the next room.
	while Time.get_ticks_msec() <= old_deadline + 50:
		await process_frame
	_check(_owned_fire_count(skin) == 0 and skin.sound_deadline == 0, "Old near-fire source cannot restart later when its former finite cue deadline expires")
	hub.player.relocate(Vector2(430, 640))
	await _step(3)
	hub.player.relocate(fire.global_position)
	await _step(3)
	_check(_owned_fire_count(skin) == 1, "A surviving physical fire resumes only after a real exit and new approach")
	var fresh := Campfire.new()
	fresh.position = fire.position + Vector2(25, 0)
	hub.yard.add_child(fresh)
	await _step(3)
	var fresh_skin: CampfireVisualSkin = fresh.get_node("CampfireVisualSkin") as CampfireVisualSkin
	var fresh_id: int = fresh_skin.get_instance_id()
	_check(_owned_fire_count(fresh_skin) == 1 and hub.presentation.campfire_owners.size() == 2, "New room fire binds and plays normally without inheriting the retired source's audio gate")
	fresh.queue_free()
	await _step(3)
	_check(not hub.presentation.campfire_owners.has(fresh_id) and hub.presentation.campfire_owners.size() == 1 and _owned_fire_count(skin) == 1, "Freed campfire unregisters its source without stopping another living fire")
	hub.player.relocate(Vector2(430, 640))
	await _step(3)


func _test_dungeon() -> void:
	flow.start_campaign()
	await _step(4)
	var campaign: LinearCampaign = flow.active_scene as LinearCampaign
	campaign.survival.director.automatic = false
	for enemy: Node2D in campaign.living_enemies():
		enemy.ai_enabled = false
	var terrain: Dictionary = _terrain(campaign.room)
	var backdrop: DungeonBackdrop = campaign.presentation.atmosphere.room_art.get_child(0) as DungeonBackdrop
	var painting: Sprite2D = backdrop.get_node("PaintedTemple") as Sprite2D
	_check(painting.texture is AtlasTexture and (painting.texture as AtlasTexture).atlas == DungeonBackdrop.TEMPLE and painting.z_index == 0 and backdrop.z_index < 0, "Actual dungeon floor one uses the approved temple painting behind combat")
	campaign.presentation.rebuild(false)
	await _step(3)
	_check(_terrain(campaign.room) == terrain and campaign.room.locked and not campaign.room.door_shape.disabled, "Refreshing temple presentation leaves room terrain and locked-door physics unchanged")
	_check(campaign.enter_stage(4), "Existing campaign transition enters the real Golem arena")
	campaign.boss.ai_enabled = false
	await _step(3)
	terrain = _terrain(campaign.room)
	backdrop = campaign.presentation.atmosphere.room_art.get_child(0) as DungeonBackdrop
	painting = backdrop.get_node("PaintedTemple") as Sprite2D
	var boss_shape: CollisionShape2D = campaign.boss.get_node("Body") as CollisionShape2D
	var boss_shape_id: int = boss_shape.shape.get_instance_id()
	var boss_transform: Transform2D = boss_shape.transform
	_check(backdrop.boss_room and (painting.texture as AtlasTexture).atlas == DungeonBackdrop.TEMPLE and painting.modulate.r < 0.7, "Golem arena uses the same approved temple with its restrained darker boss tint")
	campaign.presentation.rebuild(true)
	await _step(3)
	_check(_terrain(campaign.room) == terrain and boss_shape.shape.get_instance_id() == boss_shape_id and boss_shape.transform == boss_transform and campaign.boss.health.maximum_health == 500.0, "Boss art refresh leaves terrain, boss collision resources and original 500HP unchanged")


func _spawn_sample(index: int, location: Vector2) -> LootPickup:
	var id: StringName = ItemArtCatalog.IDS[index]
	var pickup: LootPickup
	if index < 4:
		pickup = hub.gear.loot.spawn(&"material", id, location)
	elif index < 9:
		var item := GearItem.new()
		item.uid = CombatIds.next_id()
		item.quality = GearItem.Quality.COMMON
		item.kind = &"weapon"
		if index == 4:
			item.definition_id = &"ancient_sword"
			item.equipment_definition = GearInventory.COMMON_SWORD
		elif index == 5:
			item.definition_id = &"shadow_dagger"
		elif index == 6:
			item.definition_id = &"storm_arcane_staff"
		else:
			item.equipment_definition = GearInventory.STARTER_CLOTHING[0 if index == 7 else 3]
			item.kind = EquipmentData.SLOT_KINDS[item.equipment_definition.slot_type]
			item.definition_id = item.equipment_definition.id
		var rng := RandomNumberGenerator.new()
		rng.seed = index * 71 + 2
		LootAffixRoller.roll_once(item, rng, &"drop", true)
		pickup = hub.gear.loot.spawn_gear(item, location)
	else:
		pickup = hub.gear.loot.spawn(&"consumable", id, location)
	if pickup != null:
		pickup.automatic = false
		pickup.launch_velocity = Vector2.ZERO
	return pickup


func _item_state(item: GearItem) -> Array:
	return [] if item == null else [item.uid, item.kind, item.definition_id, item.quality, item.source, item.drop_bonus, item.affix_id, item.affix_value, item.broken, item.loot_rolled]


func _owned_fire_count(owner: Node) -> int:
	var count: int = 0
	for record: Dictionary in audio._voices.values():
		var voice: AudioStreamPlayer2D = record["player"] as AudioStreamPlayer2D
		if int(record["owner_id"]) == owner.get_instance_id() and is_instance_valid(voice) and voice.stream == audio.get_fire_stream() and voice.bus == &"Ambient":
			count += 1
	return count


func _terrain(world: Node) -> Dictionary:
	var result: Dictionary = {}
	for candidate: Node in world.find_children("*", "StaticBody2D", true, false):
		var body: StaticBody2D = candidate as StaticBody2D
		var values: Array = [body.collision_layer, body.collision_mask, body.transform, body.disable_mode]
		for child: Node in body.get_children():
			if child is CollisionShape2D:
				var shape: Shape2D = child.shape
				values.append([shape.get_instance_id(), shape.size if shape is RectangleShape2D else Vector2.ZERO, child.transform, child.disabled])
		result[body.get_instance_id()] = values
	return result


func _alpha(texture: Texture2D) -> bool:
	var image: Image = texture.get_image()
	return image != null and image.detect_alpha() != Image.ALPHA_NONE and image.get_pixel(0, 0).a < 0.1 and image.get_used_rect().has_area()


func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

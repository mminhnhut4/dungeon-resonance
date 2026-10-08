class_name GameFlow
extends Node2D
## Persistent profile outlives disposable Hub/Run scenes; no autoload cycles.

var cultivation_session: Node
var social_runtime: RefCounted
var profile: SanctuaryProfile
var active_scene: Node2D
var returning: bool = false
var return_remaining: float = 0.0
var save_path_override: String = ""
var return_from_defeat: bool = false
## Opt-in replacement; legacy scenes keep the original Sanctuary and test APIs.
@export var hub_scene: PackedScene
@export var campaign_scene: PackedScene
@export var world_building_enabled: bool = false
## Opt in only from dedicated fixtures; all product entrypoints default to false.
@export var qa_tools_enabled: bool = false
@export var depth_expansion_enabled: bool = false
var depth_progress: RefCounted
var hub_session_state: Dictionary = {}
var return_save_pending: bool = false
var return_save_error: StringName = &""
var _return_busy: bool = false
signal return_save_changed


func _remember_hub() -> void:
	if active_scene is PrologueHub:
		hub_session_state[&"inventory"] = (active_scene as PrologueHub).gear.inventory


func _take_prepared_inventory() -> GearInventory:
	_remember_hub()
	if hub_scene == null or not hub_session_state.has(&"inventory"):
		return null
	var source: GearInventory = hub_session_state[&"inventory"] as GearInventory
	var prepared: GearInventory = HubPreparation.clone_inventory(source)
	if world_building_enabled:
		var previous: Dictionary = profile.hub_inventory
		profile.hub_inventory = {}
		if not profile.save():
			profile.hub_inventory = previous
			return null
		if active_scene is PrologueHub: active_scene.economy.hub_access = false
	# Clone mutable state, then move its ownership out of the Hub once. This also
	# prevents repeated salvage of the same preparation UID across multiple runs.
	HubPreparation.clear_carried(source)
	return prepared


func _ready() -> void:
	profile = SanctuaryProfile.new()
	if save_path_override != "":
		profile.save_path = save_path_override
	if world_building_enabled:
		social_runtime = preload("res://scripts/npc/opening_social_runtime.gd").new()
		social_runtime.configure(profile)
	profile.load_profile()
	if depth_expansion_enabled:
		depth_progress = preload("res://scripts/runtime/depth_progress.gd").new()
		depth_progress.initialize(profile)
	if world_building_enabled:
		cultivation_session=preload("res://scripts/cultivation/opening_cultivation_session.gd").new()
		cultivation_session.name="OpeningCultivationSession"
		add_child(cultivation_session)
		cultivation_session.initialize(profile,self)
		social_runtime.migrate_legacy()
	if world_building_enabled and not profile.hub_inventory.is_empty():
		var stored: GearInventory = GearInventoryCodec.decode(profile.hub_inventory)
		if stored != null: hub_session_state[&"inventory"] = stored
	show_hub()


func _clear() -> void:
	if cultivation_session!=null: cultivation_session.detach_scene()
	if is_instance_valid(active_scene):
		TimeScaleClaims.release_subtree(active_scene)
		remove_child(active_scene)
		active_scene.queue_free()
	active_scene = null
	returning = false
	return_save_pending = false
	return_save_error = &""


func _wait_for_return_save(reason: StringName, from_defeat: bool) -> bool:
	returning = false
	return_from_defeat = from_defeat
	return_save_pending = true
	return_save_error = reason
	if active_scene is DungeonRun: active_scene.set_return_save_error(reason)
	return_save_changed.emit()
	_return_busy = false
	return false


func return_save_state() -> Dictionary:
	return {"pending": return_save_pending, "error": return_save_error, "from_defeat": return_from_defeat, "busy": _return_busy}


func retry_pending_return() -> bool:
	if _return_busy or not return_save_pending or not active_scene is DungeonRun: return false
	_return_busy = true
	if not active_scene.retry_pending_rewards():
		return _wait_for_return_save(&"pending_rewards", return_from_defeat)
	_return_busy = false
	return show_hub(return_from_defeat, true)


func _on_run_return_requested() -> void:
	if return_save_pending:
		retry_pending_return()
	elif active_scene is DungeonRun and active_scene.outcome != &"":
		show_hub(active_scene.outcome == &"defeat")


func show_hub(from_defeat: bool = false, explicit_retry: bool = false) -> bool:
	if _return_busy or (return_save_pending and not explicit_retry): return false
	if active_scene is DungeonRun and active_scene.outcome == &"": return false
	_return_busy = true
	_remember_hub()
	if active_scene is DungeonRun:
		var run: DungeonRun = active_scene as DungeonRun
		if run.has_pending_rewards(): return _wait_for_return_save(&"pending_rewards", from_defeat)
		var bank_inventory: bool = hub_scene != null and run.outcome in [&"victory", &"retreat"] and hub_session_state.has(&"inventory")
		var run_inventory: GearInventory = run.gear.inventory
		if world_building_enabled:
			if bank_inventory and profile.coins > MaterialCatalog.MAX_COUNT - run_inventory.run_coins:
				return _wait_for_return_save(&"coin_capacity", from_defeat)
			var previous_inventory: Dictionary = profile.hub_inventory
			var previous_coins: int = profile.coins
			var previous_opening: Dictionary = profile.opening_progress
			if bank_inventory:
				profile.hub_inventory = GearInventoryCodec.encode(run_inventory)
				profile.hub_inventory["run_coins"] = 0
				profile.coins += run_inventory.run_coins
			if run.outcome == &"victory":
				profile.opening_progress = OpeningProgress.with_event(profile.opening_progress, &"returned_to_hub")
			if (bank_inventory or profile.opening_progress != previous_opening) and not profile.save():
				profile.coins = previous_coins
				profile.hub_inventory = previous_inventory
				profile.opening_progress = previous_opening
				return _wait_for_return_save(&"write_failed", from_defeat)
			if bank_inventory: run_inventory.run_coins = 0
			profile.changed.emit()
		if bank_inventory:
			hub_session_state[&"inventory"] = HubPreparation.clone_inventory(run_inventory)
			HubPreparation.clear_carried(run_inventory)
	_clear()
	var hub: Node2D = (hub_scene if hub_scene != null else preload("res://scenes/hub/sanctuary_hub.tscn")).instantiate() as Node2D
	hub.profile = profile
	hub.from_defeat = from_defeat
	if hub is PrologueHub:
		hub.session_state = hub_session_state
		hub.world_building_enabled = world_building_enabled
		hub.qa_tools_enabled = qa_tools_enabled
		hub.cultivation_session=cultivation_session
	add_child(hub)
	if world_building_enabled and hub is PrologueHub:
		var persistence := SafeInventoryPersistence.new()
		hub.add_child(persistence)
		persistence.initialize(hub.economy)
		var progression := PermanentProgressionComponent.new()
		hub.add_child(progression)
		progression.initialize(hub.gear, profile)
	hub.run_requested.connect(start_run)
	hub.campaign_requested.connect(start_campaign)
	active_scene = hub
	if depth_expansion_enabled and world_building_enabled and hub is PrologueHub:
		var guide := preload("res://scripts/npc/depth_guide.gd").new()
		guide.name = "DepthGuide"
		hub.add_child(guide)
		guide.initialize(hub)
		guide.expedition_requested.connect(_on_depth_campaign_requested.bind(guide))
	if cultivation_session!=null: cultivation_session.bind_scene(hub)
	_return_busy = false
	return_save_changed.emit()
	return true


func start_run() -> void:
	if _return_busy or active_scene is DungeonRun: return
	var prepared: GearInventory = _take_prepared_inventory()
	if world_building_enabled and prepared == null: return
	_clear()
	var run := preload("res://scenes/dungeon_run.tscn").instantiate() as DungeonRun
	run.profile = profile
	run.world_building_enabled = world_building_enabled
	run.starting_inventory = prepared
	add_child(run)
	run.content.qa_tools_enabled = qa_tools_enabled
	active_scene = run
	if prepared == null:
		run.player.available_weapons.clear()
		for id: StringName in profile.unlocked_weapons:
			var definition: WeaponDefinition = run.survival.weapon_definition(id)
			run.player.available_weapons.append(definition)
			if id == profile.starting_weapon:
				run.player.gear_index = run.player.available_weapons.size() - 1
				run.player.equipped_weapon.equip(definition)
		run.gear.reset_inventory()
	if hub_scene != null:
		run.gear.loot.set("crystal_drops_enabled", true)
		run.gear.loot.set("prologue_drops_enabled", true)
	# Fresh-run boundary: rebuilding gear can clamp HP while slots are empty.
	# Refill once here, after the confirmed starter outfit is completely installed.
	run.player.health.reset_health()
	run.player.energy.reset()
	run.player.health.died.connect(_on_run_died)
	run.save_retry_requested.connect(_on_run_return_requested)
	run.floor_return_requested.connect(_on_run_return_requested)
	if cultivation_session!=null: cultivation_session.bind_scene(run)


func _on_run_died() -> void:
	if return_save_pending: return
	returning = true
	return_from_defeat = true
	return_remaining = 1.2


func start_depth_campaign() -> bool:
	if not depth_expansion_enabled or _return_busy or active_scene is DungeonRun or depth_progress == null: return false
	if not depth_progress.unlocked() or not depth_progress.available() or not depth_progress.state()["accepted"]: return false
	var scene: PackedScene = load("res://scenes/rooms/depth_campaign.tscn") as PackedScene
	if scene == null: return false
	var prepared: GearInventory = _take_prepared_inventory()
	if world_building_enabled and prepared == null: return false
	_clear()
	var campaign: DungeonRun = scene.instantiate() as DungeonRun
	campaign.profile = profile
	campaign.world_building_enabled = world_building_enabled
	campaign.starting_inventory = prepared
	campaign.set("depth_progress_committer", depth_progress.record)
	add_child(campaign)
	campaign.content.qa_tools_enabled = qa_tools_enabled
	active_scene = campaign
	campaign.player.health.reset_health()
	campaign.player.energy.reset()
	campaign.gear.loot.set("crystal_drops_enabled", true)
	campaign.gear.loot.set("prologue_drops_enabled", true)
	campaign.player.health.died.connect(_on_run_died)
	campaign.save_retry_requested.connect(_on_run_return_requested)
	campaign.floor_return_requested.connect(_on_run_return_requested)
	if cultivation_session != null: cultivation_session.bind_scene(campaign)
	return true


func _on_depth_campaign_requested(guide: Node) -> void:
	if start_depth_campaign(): return
	if is_instance_valid(guide) and guide.open():
		guide.notice.text = "Chưa xuống được tầng sâu. Hãy thử lại sau khi lưu trang bị; hành trang và tiến độ được giữ."


func start_campaign() -> void:
	if _return_busy or active_scene is DungeonRun: return
	var prepared: GearInventory = _take_prepared_inventory()
	if world_building_enabled and prepared == null: return
	_clear()
	var campaign := (campaign_scene if campaign_scene != null else preload("res://scenes/linear_campaign.tscn")).instantiate() as DungeonRun
	campaign.profile = profile
	campaign.world_building_enabled = world_building_enabled
	campaign.starting_inventory = prepared
	add_child(campaign)
	campaign.content.qa_tools_enabled = qa_tools_enabled
	active_scene = campaign
	if prepared == null:
		for id: StringName in profile.unlocked_weapons:
			if not campaign.gear.inventory.items.values().any(func(item: GearItem) -> bool: return item.kind == &"weapon" and item.definition_id == id):
				campaign.gear.inventory.add_item(&"weapon", id)
			if id == profile.starting_weapon:
				campaign.player.equipped_weapon.equip(campaign.survival.weapon_definition(id))
		for id: StringName in ContentSession.WEAPON_IDS:
			campaign.gear.inventory.add_item(&"weapon", id)
	campaign.gear.inventory.changed.emit()
	campaign.player.health.reset_health()
	campaign.player.energy.reset()
	if hub_scene != null:
		campaign.gear.loot.set("crystal_drops_enabled", true)
		campaign.gear.loot.set("prologue_drops_enabled", true)
	campaign.player.health.died.connect(_on_run_died)
	campaign.save_retry_requested.connect(_on_run_return_requested)
	campaign.floor_return_requested.connect(_on_run_return_requested)
	if cultivation_session!=null: cultivation_session.bind_scene(campaign)


func _process(delta: float) -> void:
	if return_save_pending or _return_busy: return
	if returning:
		if active_scene is DungeonRun and active_scene.outcome == &"" and active_scene.player.health.current_health > 0.0:
			returning = false
			return
		return_remaining -= delta
		if return_remaining <= 0.0:
			show_hub(return_from_defeat)
	elif active_scene is DungeonRun and active_scene.outcome == &"victory":
		returning = true
		return_from_defeat = false
		return_remaining = 2.0

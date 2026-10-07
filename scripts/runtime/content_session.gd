class_name ContentSession
extends Node

## Explicit fixture capability; editor/debug builds do not enable it implicitly.
@export var qa_tools_enabled: bool = false

var world: Node2D
var player: Player
var gear: GearSession
var relics: RelicRuntime
var moveset: WeaponBuildComponent
var canvas: CanvasLayer
var panel: PanelContainer
var panel_open: bool = false
var previous_controls: bool = true
var weapon_index: int = -1
var info: Label
var boss_transitioning: bool = false
const WEAPON_IDS: Array[StringName] = [&"demon_greatsword", &"gale_dual_daggers", &"storm_arcane_staff", &"blood_spiked_whip"]
const PAIR_IDS: Array[StringName] = [&"firestorm", &"overload", &"charged_slash", &"thermal_shock", &"superconduct", &"blizzard", &"combustion", &"frost_venom", &"miasma_cloud", &"neurotoxin"]


func initialize(owner_world: Node2D, actor: Player, equipment: GearSession, executor: SpellExecutor) -> void:
	world = owner_world
	player = actor
	gear = equipment
	relics = RelicRuntime.new()
	add_child(relics)
	relics.initialize(player, executor)
	gear.relics = relics
	gear.loot.relics = relics
	moveset = WeaponBuildComponent.new()
	moveset.player = player
	add_child(moveset)
	player.hurtbox.hit_resolved.connect(moveset.receive_impact)
	player.health.died.connect(close)
	_build_ui()


func cycle_weapon() -> void:
	if not qa_tools_enabled: return
	for id: StringName in WEAPON_IDS:
		if not gear.inventory.items.values().any(func(item: GearItem) -> bool: return item.kind == &"weapon" and item.definition_id == id):
			gear.inventory.add_item(&"weapon", id)
	weapon_index = (weapon_index + 1) % WEAPON_IDS.size()
	var definition: WeaponDefinition = load("res://data/weapons/%s.tres" % WEAPON_IDS[weapon_index]) as WeaponDefinition
	# Debug weapon cycling follows the same action gate as click-to-equip. Changing
	# a loadout must not erase a source-authored Hurt lock or revive a dead actor.
	if player.health.current_health > 0.0 and not (player.hit_reaction != null and player.hit_reaction.blocks_controls()):
		player.action_state_machine.transition_to(&"ready")
	gear.inventory.explicit_weapon_selection = false
	player.equipped_weapon.equip(definition)
	gear.inventory.changed.emit()


func select_recipe(id: StringName) -> bool:
	if not qa_tools_enabled: return false
	if not PAIR_IDS.has(id):
		return false
	var recipe: ResonanceDefinition = load("res://data/resonances/%s.tres" % id) as ResonanceDefinition
	for slot: int in GearInventory.CATALYST_INDICES:
		gear.inventory.equip(slot, &"")
	for rune_id: StringName in recipe.recipe_rune_ids:
		if gear.inventory.bag[rune_id] <= 0:
			gear.inventory.add_rune(rune_id)
	var ok: bool = gear.inventory.equip_catalyst_set(recipe.recipe_rune_ids)
	close()
	return ok


func unlock_secret() -> void:
	if not qa_tools_enabled: return
	var barriers: Array[Node] = []
	_collect_barriers(world, barriers)
	for barrier: EnvironmentBarrier in barriers:
		if not barrier.is_open:
			var event := DamageEvent.new()
			event.source_id = player.get_instance_id()
			event.source_team_id = 1
			event.target_id = barrier.get_instance_id()
			event.attack_id = CombatIds.next_id()
			event.root_event_id = event.attack_id
			event.hit_window_id = 1
			event.base_damage = 1.0
			event.spell_id = &"debug_unlock"
			event.burn_damage = 1.0
			barrier.hurtbox.take_damage(event)
	for relic: RelicData in RelicRuntime.CATALOG:
		if relics.acquire(relic.id):
			gear.inventory.add_item(&"relic", relic.id)
	gear.inventory.changed.emit()


func _collect_barriers(parent_node: Node, result: Array[Node]) -> void:
	for child: Node in parent_node.get_children():
		if child is EnvironmentBarrier:
			result.append(child)
		_collect_barriers(child, result)


func _input(event: InputEvent) -> void:
	if not qa_tools_enabled: return
	if not event is InputEventKey or not event.pressed or event.echo or player.health.current_health <= 0.0:
		return
	match event.physical_keycode:
		KEY_F5: cycle_weapon()
		KEY_F6:
			if panel_open:
				close()
			else:
				open()
		KEY_F7: unlock_secret()
		KEY_F8:
			close()
			if world.has_method("enter_stage"):
				world.enter_stage(4)
			elif world.has_method("enter_room"):
				world.enter_room(3)
			else:
				if not boss_transitioning:
					boss_transitioning = true
					_goto_boss.call_deferred()
		_: return
	get_viewport().set_input_as_handled()


func _goto_boss() -> void:
	if not qa_tools_enabled: return
	var campaign: Node2D = load("res://scenes/linear_campaign.tscn").instantiate()
	campaign.starting_inventory = gear.inventory
	campaign.initial_stage = 4
	campaign.profile = world.survival.profile
	var hp: float = player.health.current_health
	var maximum: float = player.health.maximum_health
	var energy: float = player.energy.current
	var cooldowns: Dictionary[StringName, float] = player.resonance_controller.loadout_state.cooldowns_by_recipe_id.duplicate()
	get_tree().root.add_child(campaign)
	campaign.content.qa_tools_enabled = qa_tools_enabled
	campaign.player.health.maximum_health = maximum
	campaign.player.health.current_health = hp
	campaign.player.energy.current = energy
	campaign.player.resonance_controller.loadout_state.cooldowns_by_recipe_id = cooldowns
	campaign.content.relics.owned.assign(relics.owned)
	campaign.content.relics.equipped.assign(relics.equipped)
	campaign.content.relics.sync()
	get_tree().current_scene = campaign
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.queue_free()


func _build_ui() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 38
	add_child(canvas)
	info = Label.new()
	info.position = Vector2(450, 155)
	info.add_theme_font_size_override("font_size", 13)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(info)
	panel = PanelContainer.new()
	panel.position = Vector2(350, 125)
	panel.size = Vector2(580, 545)
	AntiqueSkin.apply_panel(panel)
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "MA TRẬN · 10 CÔNG THỨC\nChọn để cấp bùa test; vẫn giữ năng lượng / hồi chiêu."
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(550, 365)
	column.add_child(scroll)
	var recipes_column := VBoxContainer.new()
	recipes_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(recipes_column)
	for id: StringName in PAIR_IDS:
		var recipe: ResonanceDefinition = load("res://data/resonances/%s.tres" % id) as ResonanceDefinition
		var button := Button.new()
		button.text = "%s · %s" % [recipe.display_name, " + ".join(recipe.recipe_rune_ids)]
		button.pressed.connect(select_recipe.bind(id))
		recipes_column.add_child(button)
	var close_button := Button.new()
	close_button.text = "Tiếp tục · F6"
	close_button.pressed.connect(close)
	column.add_child(close_button)
	panel.hide()


func open() -> void:
	if not qa_tools_enabled: return
	gear.modal.close()
	if world.get("survival") != null:
		world.survival.panel.close()
	previous_controls = player.controls_enabled
	panel_open = true
	player.suspend_controls(true)
	panel.show()


func close() -> void:
	if not panel_open:
		return
	panel_open = false
	panel.hide()
	player.suspend_controls(not previous_controls or player.health.current_health <= 0.0)


func _process(_delta: float) -> void:
	relics.sync()
	info.visible = qa_tools_enabled and bool(world.get_meta(&"debug_visible", false)) and not panel_open and not gear.modal.is_open and not world.survival.panel.is_open
	info.text = "F5: 4 vũ khí · F6: Ma trận · F7: Bí mật / cổ vật · F8: Boss\nCổ vật %d/3 · C để đổi cổ vật" % relics.equipped.size()

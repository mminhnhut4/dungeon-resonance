class_name DungeonRun
extends Node2D
## Owns room lifecycle. All completion/loot decisions run after damage resolution.

@onready var player: Player = $Player
@onready var feedback: CombatFeedback = $CombatFeedback
@onready var executor: SpellExecutor = $SpellExecutor
var gear: GearSession
var survival: SurvivalSession
var content: ContentSession
var presentation: SlicePresentation
var starting_inventory: GearInventory
var profile: SanctuaryProfile
var world_building_enabled: bool = false
var _boss_receipt: String = ""
var _proof_pending: bool = false
var _reward_retry_busy: bool = false
var _spawning_boss_rewards: bool = false
var _return_save_error: StringName = &""
var _opening_events_pending: Array[StringName] = []
var _pending_pickup_root: Node2D
signal pending_save_changed
signal save_retry_requested
signal floor_return_requested
var floor_exit: FloorExitPanel
signal souls_awarded(amount: int)
var room: DungeonRoom
var room_number: int = 0
var wave: int = 1
var boss: BossGolem
var reward_chest: TreasureChest
var portal_active: bool = false
var outcome: StringName = &""
var transition_pending: bool = false
var processed_deaths: Dictionary[int, bool] = {}
var title: Label
var hp_bar: ProgressBar
var energy_bar: ProgressBar
var loadout_label: Label
var boss_panel: Control
var boss_hp: ProgressBar
var boss_stagger: ProgressBar
var boss_name: Label
var end_panel: PanelContainer
var end_title: Label
var portal_visual: Polygon2D


func _ready() -> void:
	player.combat_feedback = feedback
	player.equipped_weapon.hit_confirmed.connect(feedback.on_hit_confirmed)
	player.hurtbox.damage_resolver.status_controller.combat_feedback = feedback
	executor.combat_feedback = feedback
	player.resonance_controller.initialize(player, executor, feedback)
	gear = GearSession.new()
	add_child(gear)
	gear.initialize(player, feedback, self, false, starting_inventory)
	_pending_pickup_root = Node2D.new()
	_pending_pickup_root.name = "PendingPermanentRewards"
	add_child(_pending_pickup_root)
	_pending_pickup_root.hide()
	gear.loot.pickup_spawned.connect(_on_pickup_spawned)
	if world_building_enabled and profile != null:
		gear.loot.drop_table = preload("res://data/loot/world_drop_table.tres")
		gear.loot.permanent_profile = profile
		var progression := PermanentProgressionComponent.new()
		add_child(progression)
		progression.initialize(gear, profile)
	_build_ui()
	var save_notice := RunSaveRecovery.new()
	add_child(save_notice)
	save_notice.initialize(self)
	survival = SurvivalSession.new()
	add_child(survival)
	survival.initialize(player, gear, self, feedback, profile)
	content = ContentSession.new()
	add_child(content)
	content.initialize(self, player, gear, executor)
	presentation = SlicePresentation.new()
	add_child(presentation)
	presentation.initialize(self, player, feedback, executor)
	player.health.died.connect(_player_died)
	enter_room(1)
	floor_exit = FloorExitPanel.new()
	add_child(floor_exit)
	floor_exit.initialize(self)


func enter_room(number: int) -> bool:
	if number < 1 or number > 3 or player.health.current_health <= 0.0 or outcome != &"":
		return false
	if is_instance_valid(floor_exit) and floor_exit.is_open: floor_exit.close()
	gear.modal.close()
	content.close()
	survival.clear_room()
	feedback.reset_feedback()
	executor.clear_entities()
	gear.loot.clear()
	gear.loot.process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(room):
		remove_child(room)
		room.queue_free()
	room_number = number
	wave = 1
	boss = null
	reward_chest = null
	portal_active = false
	portal_visual = null
	processed_deaths.clear()
	room = DungeonRoom.new()
	room.room_number = number
	add_child(room)
	PlayerTravel.relocate(player, Vector2(180, 640), PlayerTravel.Kind.INTRA_EXPEDITION)
	player.controls_enabled = true
	if number == 3:
		boss = preload("res://scenes/enemies/boss_golem.tscn").instantiate() as BossGolem
		boss.position = Vector2(890, 640)
		boss.player = player
		boss.feedback = feedback
		room.add_child(boss)
		boss.phase_two_started.connect(_summon_adds)
		boss.defeated.connect(_boss_defeated)
		reward_chest = TreasureChest.new()
		reward_chest.player = player
		reward_chest.spawner = gear.loot
		reward_chest.locked = true
		reward_chest.large = true
		reward_chest.position = Vector2(980, 640)
		room.add_child(reward_chest)
	else:
		_spawn_wave()
		if number == 1:
			var dummy := preload("res://scenes/training_dummy.tscn").instantiate() as TrainingDummy
			dummy.position = Vector2(400, 640)
			room.add_child(dummy)
			dummy.combat_feedback = feedback
			dummy.hurtbox.damage_resolver.status_controller.combat_feedback = feedback
	transition_pending = false
	presentation.rebuild(number == 3)
	return true


func _spawn_slime(location: Vector2) -> SlimeEnemy:
	var slime := preload("res://scenes/enemies/slime_enemy.tscn").instantiate() as SlimeEnemy
	slime.position = location
	slime.player = player
	slime.combat_feedback = feedback
	slime.contact_damage_enabled = true
	room.add_child(slime)
	slime.statuses.combat_feedback = feedback
	if survival.enabled:
		survival._attach_condition(slime)
	slime.health.died.connect(_enemy_died.bind(slime))
	return slime


func _spawn_wave() -> void:
	for index: int in 3:
		var slime: SlimeEnemy = _spawn_slime(Vector2(600 + index * 190, 640))
		slime.is_elite = room_number == 2 and index == 2


func _summon_adds() -> void:
	_spawn_slime(Vector2(710, 640))
	_spawn_slime(Vector2(1050, 640))


func _enemy_died(enemy: SlimeEnemy) -> void:
	var id: int = enemy.get_instance_id()
	if processed_deaths.has(id):
		return
	processed_deaths[id] = true
	if enemy.is_elite and survival.enabled and gear.loot.drop_table == null:
		survival.profile.add_souls(3)
		souls_awarded.emit(3)
	_spawn_death_loot.call_deferred(enemy.global_position, enemy.is_elite)
	_check_clear.call_deferred()


func _spawn_death_loot(location: Vector2, elite: bool = false) -> void:
	if outcome == &"" and is_instance_valid(room):
		gear.loot.enemy_drop(location, &"slime", elite, false)


func living_enemies() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not is_instance_valid(room):
		return result
	for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
		if room.is_ancestor_of(enemy) and enemy.health.current_health > 0.0:
			result.append(enemy as Node2D)
	return result


func _check_clear() -> void:
	if outcome != &"" or not living_enemies().is_empty() or room_number == 3:
		return
	if room_number == 2 and wave == 1:
		wave = 2
		_spawn_wave()
	else:
		room.set_locked(false)
		if survival.enabled:
			survival.place_campfire(Vector2(1090, 640))


func advance_room() -> bool:
	if room.locked or room_number >= 3 or transition_pending or outcome != &"" or gear.modal.is_open or (is_instance_valid(floor_exit) and floor_exit.is_open):
		return false
	transition_pending = true
	return enter_room(room_number + 1)


func _boss_defeated() -> void:
	_finish_boss.call_deferred()


func _finish_boss() -> void:
	if outcome != &"" or portal_active:
		return
	_spawning_boss_rewards = true
	gear.loot.enemy_drop(boss.global_position, &"golem", false, true)
	_spawning_boss_rewards = false
	if world_building_enabled and profile != null:
		_boss_receipt = "%s:%d:%d:%d" % [str(Time.get_unix_time_from_system()), OS.get_process_id(), Time.get_ticks_usec(), get_instance_id()]
		_proof_pending = not profile.record_boss_defeat(_boss_receipt)
		pending_save_changed.emit()
	if survival.enabled and gear.loot.drop_table == null:
		survival.profile.add_souls(25)
		souls_awarded.emit(25)
	for enemy: Node2D in living_enemies():
		enemy.queue_free() # Summoned adds dissolve when their creator dies.
	for hazard: Node in get_tree().get_nodes_in_group(&"enemy_hazards"):
		hazard.queue_free()
	room.set_locked(false)
	reward_chest.unlock()
	portal_active = true
	portal_visual = Polygon2D.new()
	portal_visual.position = Vector2(1160, 590)
	portal_visual.polygon = PackedVector2Array([-24, -50, 24, -50, 24, 50, -24, 50])
	portal_visual.color = Color(0.35, 0.75, 1.0, 0.7)
	room.add_child(portal_visual)
	var label := Label.new()
	label.text = "E · TRỞ VỀ SẢNH"
	label.position = Vector2(-95, -80)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portal_visual.add_child(label)


func _physics_process(_delta: float) -> void:
	if outcome != &"" or gear == null:
		return
	if player.global_position.y > 850.0:
		player.health.apply_damage(999.0)
	elif room_number < 3 and not room.locked and player.global_position.x > 1220.0 and not gear.modal.is_open:
		if player.controls_enabled and Input.is_action_just_pressed(&"interact"):
			floor_exit.open()


func _on_pickup_spawned(pickup: LootPickup) -> void:
	pickup.opening_reward = world_building_enabled and _spawning_boss_rewards and pickup.kind == &"soul"
	pickup.save_retry_required.connect(_on_pickup_save_changed)
	pickup.collected.connect(_on_pickup_save_changed)


func _on_pickup_save_changed(pickup: LootPickup) -> void:
	if pickup.save_retry_pending and not pickup.collected_once and pickup.get_parent() != _pending_pickup_root:
		# Failed permanent collection belongs to the run, not disposable room
		# loot. Room changes can clear ordinary drops without deleting escrow.
		pickup.reparent(_pending_pickup_root)
		pickup.remove_from_group(&"loot")
	pending_save_changed.emit()


func pending_reward_state() -> Dictionary:
	var pickups: int = 0
	if is_instance_valid(_pending_pickup_root):
		for pickup: LootPickup in _pending_pickup_root.get_children():
			if pickup.save_retry_pending and not pickup.collected_once: pickups += 1
	return {"boss_proof_pending": _proof_pending, "pickup_count": pickups, "objective_count": _opening_events_pending.size(), "return_error": _return_save_error, "busy": _reward_retry_busy}


func record_opening_milestone(id: StringName) -> void:
	if not world_building_enabled or profile == null or id not in OpeningProgress.IDS or id in _opening_events_pending: return
	if not profile.record_opening_event(id):
		_opening_events_pending.append(id)
		pending_save_changed.emit()


func has_pending_rewards() -> bool:
	return _proof_pending or not _opening_events_pending.is_empty() or int(pending_reward_state()["pickup_count"]) > 0


func has_pending_save() -> bool:
	return has_pending_rewards() or _return_save_error != &""


func set_return_save_error(reason: StringName) -> void:
	_return_save_error = reason
	pending_save_changed.emit()


func retry_pending_rewards() -> bool:
	if _reward_retry_busy: return false
	_reward_retry_busy = true
	if _proof_pending and profile != null:
		_proof_pending = not (profile.boss_receipts.has(_boss_receipt) or profile.record_boss_defeat(_boss_receipt))
	if profile != null:
		for id: StringName in _opening_events_pending.duplicate():
			if profile.record_opening_event(id): _opening_events_pending.erase(id)
	if is_instance_valid(_pending_pickup_root):
		for pickup: LootPickup in _pending_pickup_root.get_children():
			if pickup.save_retry_pending and not pickup.collected_once: pickup.collect()
	var complete: bool = not has_pending_rewards()
	_reward_retry_busy = false
	pending_save_changed.emit()
	return complete


func retry_pending_save() -> void:
	if _reward_retry_busy: return
	if retry_pending_rewards(): save_retry_requested.emit()


func _process(_delta: float) -> void:
	if gear == null:
		return
	title.text = "HẦM NGỤC · PHÒNG %d/3 %s" % [room_number, "· ĐỢT %d/2" % wave if room_number == 2 else "· GOLEM" if room_number == 3 else "· LUYỆN TẬP"]
	hp_bar.value = player.health.current_health
	hp_bar.max_value = player.health.maximum_health
	energy_bar.value = player.energy.current
	var recipe: ResonanceDefinition = player.resonance_controller.get_recipe()
	loadout_label.text = "HP %d/%d · Năng lượng %d/100\nBùa [%s] [%s] [%s]\n%s · Hồi chiêu %.2fs\n%s" % [roundi(player.health.current_health), roundi(player.health.maximum_health), roundi(player.energy.current), gear.inventory.slots[0], gear.inventory.slots[1], gear.inventory.slots[2], recipe.display_name if recipe != null else "Tổ hợp chưa hợp lệ", player.resonance_controller.cooldown_remaining(), "Cửa khóa · Còn %d địch" % living_enemies().size() if room.locked else "Đã dọn sạch · Lối ra bên phải: E chọn đường"]
	boss_panel.visible = room_number == 3 and is_instance_valid(boss) and boss.health.current_health > 0.0
	if boss_panel.visible:
		boss_hp.value = boss.health.current_health
		boss_stagger.value = boss.stagger
		boss_name.text = "Golem Cổ Bảo · %d/500 · Phase %d · %s" % [roundi(boss.health.current_health), boss.phase, boss.fsm.get_state_id().to_upper()] if bool(get_meta(&"debug_visible", false)) else "Golem Cổ Bảo"
	if portal_active and outcome == &"" and player.controls_enabled and Input.is_action_just_pressed(&"interact") and player.global_position.distance_to(Vector2(1160, 640)) < 90.0:
		floor_exit.open()


func can_choose_floor_exit() -> bool:
	if outcome != &"" or transition_pending or not is_instance_valid(room) or room.locked or player.health.current_health <= 0.0 or gear.modal.is_open or content.panel_open:
		return false
	if portal_active:
		return player.global_position.distance_to(Vector2(1160, 640)) < 90.0
	return room_number < 3 and living_enemies().is_empty() and player.global_position.x > 1220.0


func request_floor_return() -> bool:
	if not can_choose_floor_exit() or not floor_return_requested.has_connections(): return false
	if portal_active:
		if not win(): return false
	else:
		# A cleared-floor retreat banks carried loot, but is not a boss/run victory.
		outcome = &"retreat"
		gear.modal.close()
		content.close()
		player.suspend_controls(true)
		gear.allow_interaction = false
		room.process_mode = Node.PROCESS_MODE_DISABLED
		gear.loot.process_mode = Node.PROCESS_MODE_DISABLED
		executor.clear_entities()
	floor_return_requested.emit()
	return true


func _player_died() -> void:
	finish(&"defeat")


func win() -> bool:
	if not portal_active or player.health.current_health <= 0.0 or outcome != &"":
		return false
	finish(&"victory")
	return true


func finish(result: StringName) -> void:
	if outcome != &"":
		return
	outcome = result
	gear.modal.close()
	player.suspend_controls(true)
	gear.allow_interaction = false
	room.process_mode = Node.PROCESS_MODE_DISABLED
	gear.loot.process_mode = Node.PROCESS_MODE_DISABLED
	executor.clear_entities()
	end_title.text = "Thất Bại" if result == &"defeat" else "Chiến Thắng"
	end_panel.show()


func retry() -> void:
	if has_pending_save():
		retry_pending_save()
		return
	if world_building_enabled and save_retry_requested.has_connections() and outcome != &"":
		save_retry_requested.emit()
		return
	gear.modal.close()
	outcome = &""
	end_panel.hide()
	gear.allow_interaction = true
	gear.reset_inventory()
	survival.condition.clear()
	gear.loot.drop_serial = 0
	player.reset_movement_at(Vector2(180, 640))
	player.gear_index = 0
	player.equipped_weapon.equip(Player.SWORD)
	enter_room(1)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 15
	add_child(canvas)
	title = _label(canvas, Vector2(40, 25), "", 28)
	_label(canvas, Vector2(40, 68), "A/D · Chạy   Space · Nhảy   Shift · Lướt   Chuột trái · Chém   Chuột phải · Phép", 17)
	hp_bar = _bar(canvas, Vector2(40, 103), Vector2(270, 18), 100)
	_tint_bar(hp_bar, Color("c05767"))
	energy_bar = _bar(canvas, Vector2(40, 128), Vector2(270, 14), 100)
	_tint_bar(energy_bar, Color("58a6c4"))
	loadout_label = _label(canvas, Vector2(950, 28), "", 16)
	loadout_label.size = Vector2(285, 160)
	loadout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_panel = Control.new()
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(boss_panel)
	boss_name = _label(boss_panel, Vector2(360, 642), "Golem Cổ Bảo", 18)
	boss_name.set_meta(&"debug_keep", true)
	boss_hp = _bar(boss_panel, Vector2(360, 670), Vector2(560, 18), 500)
	_tint_bar(boss_hp, Color("c47b4b"))
	boss_stagger = _bar(boss_panel, Vector2(360, 695), Vector2(560, 8), 100)
	_tint_bar(boss_stagger, Color("a488d4"))
	end_panel = PanelContainer.new()
	end_panel.position = Vector2(400, 240)
	end_panel.size = Vector2(480, 240)
	canvas.add_child(end_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	end_panel.add_child(column)
	end_title = _label(column, Vector2.ZERO, "", 38)
	var retry_button := Button.new()
	retry_button.text = "Thử lại ngay"
	retry_button.pressed.connect(retry)
	column.add_child(retry_button)
	var quit_button := Button.new()
	quit_button.text = "Thoát"
	quit_button.pressed.connect(get_node("/root/AudioManager").request_quit)
	column.add_child(quit_button)
	end_panel.hide()


func _label(parent_node: Node, location: Vector2, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = location
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent_node.add_child(label)
	return label


func _bar(parent_node: Node, location: Vector2, size: Vector2, maximum: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = location
	bar.size = size
	bar.max_value = maximum
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_node.add_child(bar)
	return bar


func _tint_bar(bar: ProgressBar, tint: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("171c2b")
	background.border_color = Color("5a4f60")
	background.set_border_width_all(1)
	background.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)

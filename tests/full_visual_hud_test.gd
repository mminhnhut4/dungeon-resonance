extends "res://tests/survival_test_base.gd"
## Art widgets must follow live runtime values without changing combat or saves.


func _initialize() -> void:
	suite = "full_visual_hud"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.set_physics_process(false)
	player.energy.set_physics_process(false)
	var hud: ArtHUD = level.presentation.art_hud
	_check(is_instance_valid(hud) and hud.player_panel.is_visible_in_tree(), "Test room binds a live art HUD with debug initially disabled")
	_check(hud.hp_bar is TextureProgressBar and hud.energy_bar is TextureProgressBar and hud.player_frame.texture == ArtHUD.PLAYER_FRAME and hud.player_frame.size == Vector2(360, 120) and hud.rune_icons.all(func(icon: TextureRect) -> bool: return icon.size == Vector2(44, 44)), "Player texture frame and rune icons stay at their designed HUD sizes after layout instead of expanding to PNG dimensions")
	_check(level.debug_hud.hp_bar.is_visible_in_tree() and level.debug_hud.hp_bar.self_modulate.a == 0.0, "Legacy health API remains visible to callers while its flat rendering is suppressed")
	_check(level.gear.energy_bar.self_modulate.a == 0.0, "Legacy gear energy bar cannot overlap the new cyan socket")
	player.health.maximum_health = 150.0
	player.health.current_health = 85.0
	player.energy.maximum = 120.0
	player.energy.current = 44.0
	hud.refresh_hud()
	_check(hud.hp_bar.max_value == 150.0 and hud.hp_bar.value == 85.0 and hud.hp_text.text == "85 / 150", "Art health reads the current and maximum HP rather than a fixed prototype value")
	_check(hud.energy_bar.max_value == 120.0 and hud.energy_bar.value == 44.0 and hud.energy_text.text == "44 / 120", "Cyan meter reads actual shared energy, including a changed capacity")
	_check(hud.energy_bar.tooltip_text.contains("Năng lượng") and not hud.energy_bar.tooltip_text.contains("Mana"), "HUD identifies the existing dash/spell resource accurately")
	await _step(2)
	_check(level.debug_hud.hp_bar.value == 85.0 and level.debug_hud.hp_label.text.contains("85"), "Suppressed legacy HUD still updates the original health data and label API")
	level.set_rune_preset(1)
	hud.refresh_hud()
	_check(hud.rune_ids == [&"fire", &"wind", &""] and hud.rune_icons.size() == 3, "Three icon slots display the current Fire/Wind catalyst and the empty third slot")
	_check(hud.rune_icons[0].texture == ArtHUD.FIRE_ICON and hud.rune_icons[1].texture == ArtHUD.WIND_ICON and hud.rune_icons[0].modulate == Color.WHITE and hud.rune_icons[1].modulate == Color.WHITE and hud.rune_icons[2].tooltip_text.contains("Trống"), "Fire and Wind preserve their artwork palette while an empty slot stays explicitly empty")
	var lightning: RuneData = load("res://data/runes/LightningRune.tres")
	var ice: RuneData = load("res://data/runes/IceRune.tres")
	var poison: RuneData = load("res://data/runes/PoisonRune.tres")
	player.resonance_controller.catalyst_a.install_runes([lightning, ice, poison])
	hud.refresh_hud()
	_check(hud.rune_ids == [&"lightning", &"ice", &"poison"], "Dedicated rune icons retain the true IDs of Lightning, Ice and Poison")
	var accurate_tooltips: bool = true
	for index: int in 3:
		accurate_tooltips = accurate_tooltips and hud.rune_icons[index].texture == ItemArtCatalog.RUNE_ICONS[hud.rune_ids[index]] and hud.rune_icons[index].modulate == Color.WHITE and hud.rune_icons[index].tooltip_text.contains(String(hud.rune_ids[index]))
	_check(accurate_tooltips, "Dedicated rune art keeps its palette and names its real element")
	level.presentation.debug_overlay.set_enabled(true)
	hud.refresh_hud()
	_check(hud.rune_icons.all(func(icon: TextureRect) -> bool: return icon.is_visible_in_tree()) and level.gear.energy_bar.self_modulate.a == 0.0, "Debug toggle preserves all three art icons and does not restore the old flat energy rendering")
	level.presentation.debug_overlay.set_enabled(false)
	_check(hud.hp_text.is_visible_in_tree() and hud.energy_text.is_visible_in_tree() and hud.rune_icons[0].is_visible_in_tree(), "Essential art HUD labels and rune slots remain visible when debug is turned off")
	player.equipped_weapon.equip(load("res://data/weapons/gale_dual_daggers.tres"))
	hud.refresh_hud()
	_check(hud.weapon_id == &"gale_dual_daggers" and hud.weapon_icon.texture == ArtHUD.SWORD_ICON and hud.weapon_name.text == player.equipped_weapon.definition.display_name and hud.weapon_icon.size == Vector2(56, 56), "Bottom equipment slot follows the melee weapon while preserving its compact 56px rectangle")
	player.equipped_weapon.equip(load("res://data/weapons/storm_arcane_staff.tres"))
	hud.refresh_hud()
	_check(hud.weapon_id == &"storm_arcane_staff" and hud.weapon_icon.texture == ArtHUD.SHIELD_ICON and hud.weapon_icon.tooltip_text.contains("storm_arcane_staff"), "Staff uses a neutral equipment emblem with its true identity instead of a Sword claim")
	player.equipped_weapon.equip(Player.SWORD)
	level.set_rune_preset(1)
	player.action_state_machine.transition_to(&"attack")
	var snapshot: AttackSnapshot = player.equipped_weapon.snapshot
	var committed_direction: Vector2 = snapshot.attack_direction
	var committed_damage: float = snapshot.base_damage
	var installed_ids: Array[StringName] = player.resonance_controller.catalyst_a.runtime_state.installed_rune_ids.duplicate()
	var hp_before: float = player.health.current_health
	var energy_before: float = player.energy.current
	for update: int in 40:
		hud.refresh_hud()
	_check(player.equipped_weapon.snapshot == snapshot and snapshot.attack_direction == committed_direction and snapshot.base_damage == committed_damage, "Repeated HUD refreshes cannot modify an already committed attack snapshot")
	_check(player.health.current_health == hp_before and player.energy.current == energy_before and player.resonance_controller.catalyst_a.runtime_state.installed_rune_ids == installed_ids, "Read-only HUD never consumes health, energy or changes equipped rune data")
	player.action_state_machine.transition_to(&"ready")
	level.set_rune_preset(4)
	hud.refresh_hud()
	_check(hud.rune_ids == [&"", &"", &""] and hud.rune_icons.all(func(icon: TextureRect) -> bool: return icon.is_visible_in_tree()), "Removing all runes immediately restores three visible empty sockets")
	_check(not hud.boss_panel.visible and hud.boss_id == 0, "A test room without a Boss has no stale Boss portrait or bar")
	var run: DungeonRun = preload("res://scenes/dungeon_run.tscn").instantiate()
	run.profile = profile
	root.add_child(run)
	run.survival.director.automatic = false
	run.enter_room(3)
	run.player.set_physics_process(false)
	run.boss.set_physics_process(false)
	await _step(2)
	var boss_hud: ArtHUD = run.presentation.art_hud
	_check(boss_hud.boss_panel.is_visible_in_tree() and boss_hud.boss_name.text == "Golem Cổ Bảo" and boss_hud.boss_text.text == "500 / 500", "Boss encounter shows the framed name and real 500/500 health")
	_check((boss_hud.boss_frame.texture as AtlasTexture).atlas == ArtHUD.BOSS_FRAME and (boss_hud.boss_emblem.texture as AtlasTexture).atlas == ArtHUD.BOSS_FRAME and boss_hud.boss_frame.size == Vector2(420, 91) and boss_hud.boss_emblem.size.is_equal_approx(Vector2(60, 49.24)) and boss_hud.boss_frame.get_global_rect().position.y >= 625.0 and boss_hud.boss_frame.get_global_rect().end.y <= 720.0 and boss_hud.boss_emblem.get_global_rect().position.y >= 625.0, "Boss Atlas frame and portrait fit the compact footer below gameplay and remain within the 720px viewport")
	_check(run.hp_bar.self_modulate.a == 0.0 and run.energy_bar.self_modulate.a == 0.0 and run.boss_hp.self_modulate.a == 0.0 and run.boss_name.self_modulate.a == 0.0, "Campaign suppresses every legacy flat HP/energy/Boss render without changing their values")
	run.boss.health.maximum_health = 750.0
	run.boss.health.current_health = 315.0
	boss_hud.refresh_hud()
	_check(boss_hud.boss_hp.max_value == 750.0 and boss_hud.boss_hp.value == 315.0 and boss_hud.boss_text.text == "315 / 750", "Boss artwork follows dynamic maximum and damaged health")
	run.boss.health.current_health = 0.0
	boss_hud.refresh_hud()
	_check(not boss_hud.boss_panel.visible and boss_hud.boss_id == 0, "Boss with zero HP immediately retires the portrait and health bar")
	run.boss.health.current_health = 315.0
	run.player.hurtbox.set_invulnerable(false)
	run.player.hurtbox.take_damage(_damage(run.player.hurtbox, 9999.0))
	boss_hud.refresh_hud()
	_check(run.player.health.current_health == 0.0 and run.end_panel.visible and not boss_hud.boss_panel.visible, "Player death presents the existing failure flow and hides the active Boss HUD")
	var run_hud_weak: WeakRef = weakref(boss_hud)
	run.queue_free()
	await _step(4)
	_check(run_hud_weak.get_ref() == null and is_instance_valid(hud), "Boss room teardown releases its art HUD while the independent test HUD remains alive")
	hud.bind(null, null)
	_check(hud._actor_id == 0 and hud._world_id == 0 and hud._legacy.is_empty() and not hud.player_panel.visible, "Unbind releases actor/world identities and weak legacy-widget records")
	_check(level.debug_hud.hp_bar.self_modulate.a == 1.0 and level.gear.energy_bar.self_modulate.a == 1.0, "Removing the art adapter restores the original renderer state for legacy widgets")
	hud.bind(level, player)

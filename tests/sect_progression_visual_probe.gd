extends SceneTree
## Bounded native smoke: synthetic money/materials and explicit room placement.
## Real UI input, transactions, committed Player melee and NPC Hitbox clocks.
const Cultivation = preload("res://scripts/cultivation/opening_cultivation_state.gd")
var flow: GameFlow
var hub: ExteriorHub
var screen: InventoryScreen
var checks: int = 0
var failures: int = 0
var output: String
var captures: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var _contact_result: DamageResult

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	output = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").replace("\\","/")
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--native-approved") or not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or not output.is_absolute_path():
		print("FAIL: Native approval, isolated QA root and explicit evidence directory are required")
		quit(2)
		return
	Engine.physics_ticks_per_second = 60
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	var profile := SanctuaryProfile.new()
	profile.save_path = "user://verification/sect_native_%d_%d/profile.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	profile.souls = 500
	profile.coins = 200
	profile.material_stash[&"dust"] = 20
	profile.material_stash[&"crystal"] = 10
	_check(profile.save() and profile.commit_cultivation(Cultivation.initial_proposal(Cultivation.new_progress(43),profile.material_stash,profile.souls,profile.boss_proofs)),"Declared synthetic fixture: 500 Souls, 200 coins, 20 dust, 10 crystal; no quest/boss/rune grants")
	flow = GameFlow.new()
	flow.hub_scene = preload("res://scenes/hub/exterior_hub_room.tscn")
	flow.campaign_scene = preload("res://scenes/world_campaign.tscn")
	flow.world_building_enabled = true
	flow.save_path_override = profile.save_path
	root.add_child(flow)
	current_scene = flow
	await _frames(8)
	hub = flow.active_scene as ExteriorHub
	if not _check(hub != null,"Actual GameFlow creates ExteriorHub"): await _finish(); return
	screen = hub.gear.modal as InventoryScreen
	if OS.get_cmdline_user_args().has("--cultivator-only"):
		observations.append({"focused_mode":"Cultivator art sampling only; same real patrol/melee/tell/active/hurt/withdraw path as the earlier full native smoke. Fresh synthetic starter inventory, no rune or upgrade UI replay."})
		await _cultivators()
		await _finish()
		return
	if OS.get_cmdline_user_args().has("--tooltip-only"):
		await _action(&"inventory")
		for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
			await _weapon_tooltip(extent,true)
		await _action(&"inventory")
		await _finish()
		return
	await _empty_runes()
	await _soul_services()
	await _rune_services()
	await _equipment_and_guide()
	await _cultivators()
	await _corner()
	await _finish()

func _empty_runes() -> void:
	await _action(&"inventory")
	await _key(KEY_1)
	_check(screen.is_open and screen.tabs.current_tab == 1 and hub.gear.inventory.total_shards() == 0 and screen.acquisition_hint.text.contains("Thanh Vy"),"Tab and rune shortcut expose acquisition help for the actual empty starter inventory")
	await _capture("00_empty_runes_1280",{"hint":screen.acquisition_hint.text},[screen.panel,screen.acquisition_hint])
	await _action(&"inventory")

func _open_healer() -> void:
	PlayerTravel.relocate(hub.player,hub.npcs[NpcCatalog.HEALER].global_position+Vector2(-38,0))
	_reset_camera(hub.player)
	await _frames(3)
	await _action(&"interact")
	_check(hub.dialogue.is_open and hub.current_npc == NpcCatalog.HEALER,"Actual E opens Thanh Vy at her world location")
	await _reveal()

func _soul_services() -> void:
	await _resize(Vector2i(800,600))
	await _open_healer()
	var souls: int = flow.profile.souls
	var hp: float = hub.player.health.maximum_health
	var hp_quote: Dictionary = hub.economy.quote_upgrade(&"max_hp")
	await _dialogue_choice("upgrade_max_hp")
	_check(hub.dialogue.confirmation.visible and flow.profile.souls == souls,"HP choice opens confirmation before any debit")
	await _capture("01_hp_confirmation_800",{"souls":souls,"cost":hp_quote["cost"]},[hub.dialogue.panel,hub.dialogue.confirm_button,hub.dialogue.cancel_button])
	await _button(hub.dialogue.cancel_button,hub.dialogue.body_scroll)
	_check(flow.profile.souls == souls and flow.profile.permanent_upgrades[&"max_hp"] == 0,"Actual cancel preserves HP upgrade and Souls")
	await _dialogue_choice("upgrade_max_hp")
	await _button(hub.dialogue.confirm_button,hub.dialogue.body_scroll)
	await _reveal()
	_check(flow.profile.souls == souls-int(hp_quote["cost"]) and hub.player.health.maximum_health > hp,"Confirmed HP purchase applies the exact owner cost and higher maximum")
	await _resize(Vector2i(1280,720))
	var mana: float = hub.player.energy.maximum
	souls = flow.profile.souls
	var mana_quote: Dictionary = hub.economy.quote_upgrade(&"max_mana")
	await _dialogue_choice("upgrade_max_mana")
	await _capture("02_mana_confirmation_1280",{"souls":souls,"cost":mana_quote["cost"],"maximum_before":mana},[hub.dialogue.panel,hub.dialogue.confirm_button])
	await _button(hub.dialogue.cancel_button,hub.dialogue.body_scroll)
	_check(flow.profile.souls == souls and hub.player.energy.maximum == mana,"Mana cancel also leaves the displayed resource unchanged")
	await _dialogue_choice("upgrade_max_mana")
	await _button(hub.dialogue.confirm_button,hub.dialogue.body_scroll)
	await _reveal()
	_check(flow.profile.souls == souls-int(mana_quote["cost"]) and hub.player.energy.maximum > mana,"Confirmed mana upgrade changes the live maximum through existing owner")

func _rune_services() -> void:
	# Exercise the first construction at compact width, not only resize a menu
	# whose earlier wide layout may have hidden a first-open minimum-size bug.
	await _resize(Vector2i(800,600))
	await _dialogue_choice("rune_learning")
	_check(hub.station_open and hub.current_station == &"rune_learning","Actual Thanh Vy choice opens five-element rune service")
	await _capture("03_rune_service_800",{"lightning_hint":hub.rune_learning.quote(&"lightning")["lock_hint"],"poison_hint":hub.rune_learning.quote(&"poison")["lock_hint"]},[hub.station_panel])
	var before_uids: Array = hub.gear.inventory.items.keys()
	var souls: int = flow.profile.souls
	await _station_button("RuneService_fire")
	await _capture("04_fire_lesson_confirmation_800",{"before_uids":before_uids,"souls":souls},[hub.station_panel,hub.station_content.get_node("ConfirmPurchase")])
	await _station_button("CancelPurchase")
	_check(flow.profile.souls == souls and hub.gear.inventory.items.keys() == before_uids,"Lesson cancel grants no provisional rune")
	await _station_button("RuneService_fire")
	await _station_button("ConfirmPurchase")
	await _station_button("RuneService_wind")
	await _station_button("ConfirmPurchase")
	_check(flow.profile.souls == souls-10 and hub.rune_learning.state()["learned"].has("fire") and hub.rune_learning.state()["learned"].has("wind") and hub.gear.inventory.items.size() == before_uids.size()+2,"Two confirmed lessons create exactly two finite Common runes for ten Souls")
	await _resize(Vector2i(1280,720))
	await _station_button("RuneService_fire")
	var dust: int = flow.profile.material_stash[&"dust"]
	var crystal: int = flow.profile.material_stash[&"crystal"]
	await _capture("05_craft_confirmation_1280",{"stash_dust":dust,"stash_crystal":crystal},[hub.station_panel,hub.station_content.get_node("ConfirmPurchase")])
	await _station_button("ConfirmPurchase")
	_check(flow.profile.material_stash[&"dust"] == dust-2 and flow.profile.material_stash[&"crystal"] == crystal-1 and hub.gear.inventory.items.size() == before_uids.size()+3,"Actual craft confirmation consumes the stash costs and creates one additional UID")
	await _action(&"ui_cancel")
	_check(not hub.station_open and hub.player.controls_enabled,"Closing rune services releases player controls")

func _equipment_and_guide() -> void:
	await _action(&"inventory")
	await _key(KEY_1)
	await _key(KEY_F)
	await _key(KEY_2)
	await _key(KEY_G)
	var recipe: ResonanceDefinition = hub.player.resonance_controller.get_recipe()
	_check(hub.gear.inventory.slots[0] == &"fire" and hub.gear.inventory.slots[1] == &"wind" and recipe != null and recipe.id == &"firestorm","Actual rune keyboard inputs install the exact Fire+Wind catalyst recipe")
	await _capture("06_equipped_fire_wind_1280",{"slots":hub.gear.inventory.slots,"preview":screen.preview.text},[screen.panel,screen.preview])
	await _weapon_tooltip()
	await _action(&"inventory")
	await _resize(Vector2i(800,600))
	await _key(KEY_M)
	var journal: QuestJournal = screen.journal
	_check(screen.is_open and screen.tabs.current_tab == 2 and journal.quest_buttons.has(&"cultivation_breakthrough"),"M exposes the early Trúc Cơ route before dungeon completion")
	if journal.quest_buttons.has(&"cultivation_breakthrough"):
		await _button(journal.quest_buttons[&"cultivation_breakthrough"],journal.quest_scroll)
	await _capture("08_early_truc_co_map_800",{"selected":journal.selected_id,"objective":journal.objective_label.text},[screen.panel,journal.detail_scroll])
	await _resize(Vector2i(1280,720))
	for _index: int in 3: await _key(KEY_PAGEDOWN)
	_check(journal.selected_id == &"cultivation_breakthrough" and journal.detail_scroll.scroll_vertical > 0,"Actual PageDown reaches the detailed Trúc Cơ guidance")
	await _capture("09_truc_co_detail_1280",{"guide":journal.guide_label.text,"scroll":journal.detail_scroll.scroll_vertical},[screen.panel,journal.detail_scroll])
	await _key(KEY_M)
	_check(not screen.is_open and hub.player.controls_enabled,"M closes the journal without leaving a movement lock")

func _weapon_tooltip(extent: Vector2i = Vector2i(800,600), expanded: bool = false) -> void:
	await _resize(extent)
	var tabs: TabBar = screen.tabs.get_tab_bar()
	if screen.tabs.current_tab != 0:
		await _click(tabs.global_position+tabs.get_tab_rect(0).get_center())
	await _frames(3)
	var weapon: Button = screen.equipment_buttons[0]
	screen.content_scroll.ensure_control_visible(weapon)
	await _frames(2)
	await _hover(weapon.get_global_rect().get_center())
	_check(screen.tooltip.visible and screen.tooltip_body.text.contains("Đòn 1:") and screen.tooltip_body.text.contains("hồi"),"Actual equipped-weapon hover exposes numeric combo damage and timing")
	var outer_scroll: int = screen.content_scroll.scroll_vertical
	# Move over the actual tooltip surface before wheeling: lower item cards must
	# not steal hover and erase the text the player is attempting to read.
	await _hover(screen.tooltip.get_global_rect().get_center())
	_check(screen.tooltip.visible,"Entering the tooltip surface preserves the current item")
	if expanded:
		for _index: int in 20: await _wheel(screen.tooltip.get_global_rect().get_center(),MOUSE_BUTTON_WHEEL_UP)
		await _capture("tooltip_top_%d" % extent.x,_tooltip_state(outer_scroll),[screen.panel,screen.tooltip])
	for _index: int in 6:
		await _wheel(screen.tooltip.get_global_rect().get_center(),MOUSE_BUTTON_WHEEL_DOWN)
		_check(screen.tooltip.visible,"Tooltip remains visible after wheel %d" % (_index+1))
	_check(screen.tooltip_scroll.scroll_vertical > 0 and screen.content_scroll.scroll_vertical == outer_scroll,"Wheel scrolls long tooltip without moving the outer inventory")
	await _capture("tooltip_combo_%d" % extent.x if expanded else "07_weapon_combo_tooltip_800",_tooltip_state(outer_scroll),[screen.panel,screen.tooltip])
	if expanded:
		for _index: int in 20: await _wheel(screen.tooltip.get_global_rect().get_center(),MOUSE_BUTTON_WHEEL_DOWN)
		_check(screen.tooltip.visible and screen.content_scroll.scroll_vertical == outer_scroll,"Tooltip remains visible through its bottom without stealing outer scroll")
		await _capture("tooltip_bottom_%d" % extent.x,_tooltip_state(outer_scroll),[screen.panel,screen.tooltip])
		var weapon_name: String = screen.tooltip_name.text
		# Select a genuinely exposed part of another equipped item, because
		# tooltip placement changes with viewport and the triggering pointer.
		var clothing_slot: int = -1
		var clothing_point := Vector2.ZERO
		for slot: int in range(1,screen.equipment_buttons.size()):
			var rect: Rect2 = screen.equipment_buttons[slot].get_global_rect()
			for point: Vector2 in [rect.position+Vector2(5,rect.size.y*0.5),rect.end-Vector2(5,rect.size.y*0.5)]:
				if screen.content_scroll.get_global_rect().has_point(point) and not screen.tooltip.get_global_rect().has_point(point):
					clothing_slot = slot; clothing_point = point; break
			if clothing_slot >= 0: break
		_check(clothing_slot >= 0 and not screen.tooltip.get_global_rect().has_point(clothing_point),"Other item hover uses an exposed point outside the tooltip")
		await _hover(clothing_point)
		_check(clothing_slot >= 0 and screen.tooltip.visible and screen.tooltip_name.text != weapon_name and screen.tooltip_body.text.begins_with(InventoryScreen.SLOT_NAMES[clothing_slot]),"Moving away can inspect a different equipped item")

func _tooltip_state(outer_scroll: int) -> Dictionary:
	return {"tooltip":screen.tooltip_body.text,"scroll":screen.tooltip_scroll.scroll_vertical,"visible":screen.tooltip.visible,"outer_before":outer_scroll,"outer_after":screen.content_scroll.scroll_vertical}

func _cultivators() -> void:
	for id: String in CultivatorCatalog.IDS:
		var spec: Dictionary = NpcPilotCatalog.definition(id)
		_check(hub.enter_exterior(StringName(spec["room"]),&"main",&"west",false),"Declared direct room placement for native cultivator fixture: "+id)
		await _frames(6)
		var population: NpcPopulation = hub.npc_population
		if not _check(population.actors.has(id) and population.actors.size() == 2,"Cultivator and existing civilian coexist on the authored road"): continue
		var actor: CultivatorActor = population.actors[id] as CultivatorActor
		var sprite_image: Image = actor.body.texture.get_image()
		var loaded_mipmaps: bool = sprite_image != null and sprite_image.has_mipmaps()
		observations.append({"cultivator":id,"texture":actor.body.texture.resource_path,"texture_size":str(actor.body.texture.get_size()),"texture_filter":actor.body.texture_filter,"sprite_scale":str(actor.body.scale),"loaded_mipmaps":loaded_mipmaps})
		if OS.get_cmdline_user_args().has("--expect-mipmaps"):
			_check(loaded_mipmaps,"Cultivator runtime texture includes imported mipmaps: "+id)
		PlayerTravel.relocate(hub.player,actor.global_position+Vector2(-48,0))
		_reset_camera(hub.player)
		await _frames(6)
		var initial_x: float = actor.position.x
		await _frames(12)
		_check(actor.combat_phase == "idle" and actor.accepted_strikes == 0,"Neutral road cultivator has no unsolicited attack")
		if id == CultivatorCatalog.IDS[0]: await _capture("10_thanh_van_patrol",{"phase":actor.combat_phase,"motion_x":actor.position.x-initial_x,"coexisting_ids":population.actors.keys()})
		# Re-establish actual melee reach after the neutral patrol observation.
		PlayerTravel.relocate(hub.player,actor.global_position+Vector2(-32,0))
		_reset_camera(hub.player)
		await _frames(3)
		await _hover(hub.player.get_canvas_transform()*(actor.global_position+Vector2(0,-25)))
		var old_hp: float = actor.health.current_health
		Input.action_press(&"attack")
		await _frames(1)
		Input.action_release(&"attack")
		await _wait_phase(actor,"tell",3.0)
		_check(actor.health.current_health < old_hp and actor.combat_phase == "tell" and not actor.strike_hitbox.active,"Actual Player weapon provokes a nondamaging committed tell")
		if id == CultivatorCatalog.IDS[0]: await _capture("11_thanh_van_tell",_actor_state(actor))
		await _wait_phase(actor,"active",2.0)
		_check(actor.combat_phase == "active" and actor.strike_hitbox.active,"Real local FSM opens the self-defense Hitbox")
		await _capture("12_thanh_van_active" if id == CultivatorCatalog.IDS[0] else "15_xich_lo_active",_actor_state(actor))
		await _frames(3)
		_check(actor.accepted_strikes > 0,"Self-defense Hitbox physically hits the current Player")
		await _physical_probe(actor,1.0)
		_check(_contact_result != null and _contact_result.actual_damage > 0 and actor.combat_phase == "hurt" and not actor.strike_hitbox.active,"Declared query Hitbox injury cancels active strike and enters hurt")
		if id == CultivatorCatalog.IDS[0]: await _capture("13_thanh_van_hurt",_actor_state(actor))
		var escape_x: float = float(spec["left"])-150.0
		PlayerTravel.relocate(hub.player,hub.exterior.global_position+Vector2(escape_x,hub.exterior.floor_y(escape_x)))
		_reset_camera(hub.player)
		await _frames(5)
		_check(actor.combat_phase == "idle" and not actor.strike_hitbox.active and actor.reason.contains("ngừng"),"Leaving the authored leash ends pursuit without clearing memory")
		if id == CultivatorCatalog.IDS[0]: await _capture("14_thanh_van_leash_refuge",_actor_state(actor))
		PlayerTravel.relocate(hub.player,actor.global_position+Vector2(-42,0))
		await _frames(2)
		await _physical_probe(actor,9999.0)
		_check(_contact_result != null and not _contact_result.killed and population.state.records[id]["mode"] == "recovering","Declared lethal-strength query leaves a living withdrawn NPC")
		await _frames(4)
		_check(not population.actors.has(id) and population.actors.size() == 1,"Withdrawal removes only the injured cultivator and retains the civilian")
		await _frames(20)
	hub.return_to_hub(false)
	await _frames(5)
	_check(hub.player.controls_enabled and hub.npc_population.actors.is_empty(),"Ordinary Hub return cleans up both road rooms without reviving injuries")

func _corner() -> void:
	flow.start_campaign()
	await _frames(8)
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	if not _check(run != null,"Actual GameFlow transfers learned runes into WorldCampaign"): return
	run.survival.set_enabled(false)
	for enemy: Node2D in run.living_enemies(): enemy.set_physics_process(false)
	observations.append({"geometry_isolation":"Enemy AI and survival disabled only for the final corner case; not a dungeon playthrough."})
	run.player.reset_movement_at(Vector2(90,534))
	_reset_camera(run.player)
	await _frames(8)
	Input.action_press(&"move_left")
	await _frames(60)
	Input.action_release(&"move_left")
	await _frames(12)
	await _capture("16_west_corner_entry",{"position":str(run.player.position),"grounded":run.player.motor.is_grounded()})
	var casts: int = run.player.resonance_controller.cast_count
	Input.action_press(&"spell_cast")
	await _frames(1)
	Input.action_release(&"spell_cast")
	await _frames(42)
	Input.action_press(&"move_right")
	await _frames(60)
	var axis: float = run.player.move_axis
	Input.action_release(&"move_right")
	await _frames(3)
	_check(run.player.resonance_controller.cast_count == casts+1 and axis > 0 and run.player.position.x > 180 and run.player.motor.is_grounded(),"Real cast and rightward input escape the former WestStair pocket onto combat floor")
	await _capture("17_west_corner_escaped",{"position":str(run.player.position),"cast_delta":run.player.resonance_controller.cast_count-casts,"accepted_axis":axis})

func _actor_state(actor: CultivatorActor) -> Dictionary:
	return {"id":actor.stable_id,"phase":actor.combat_phase,"phase_remaining":actor.phase_remaining,"hitbox_active":actor.strike_hitbox.active,"accepted_strikes":actor.accepted_strikes,"hp":actor.health.current_health,"reason":actor.reason,"x":actor.position.x}

func _physical_probe(actor: CultivatorActor, damage: float) -> void:
	_contact_result = null
	var attack := AttackSnapshot.new()
	attack.source_id = hub.player.get_instance_id(); attack.source_team_id = 1
	attack.attack_id = CombatIds.next_id(); attack.root_event_id = attack.attack_id
	attack.base_damage = damage; attack.attack_origin = hub.player.global_position
	var probe: Hitbox = ActorCombatRig.hitbox(hub.exterior,16)
	probe.contact_detected.connect(func(target: Hurtbox, snapshot: AttackSnapshot) -> void:
		if target != actor.hurtbox: return
		var event := DamageEvent.new()
		event.source_id = snapshot.source_id; event.source_team_id = snapshot.source_team_id; event.target_id = target.get_actor_id()
		event.attack_id = snapshot.attack_id; event.root_event_id = snapshot.root_event_id; event.hit_window_id = snapshot.hit_window_id
		event.base_damage = snapshot.base_damage; event.attack_origin = snapshot.attack_origin
		_contact_result = target.take_damage(event)
	)
	var shape := RectangleShape2D.new(); shape.size = Vector2(30,54)
	probe.activate(attack,shape,actor.position+Vector2(0,-26))
	await _frames(1)
	probe.sample_contacts(); probe.deactivate(); probe.queue_free()

func _capture(label: String, detail: Dictionary = {}, controls: Array = []) -> void:
	for control: Control in controls:
		_check(is_instance_valid(control) and root.get_visible_rect().encloses(control.get_global_rect()),label+": intended control fits the native viewport")
	# Freeze only while copying the rendered frame, so tell/active screenshots
	# retain a real entered state rather than being posed by writing FSM fields.
	var was_paused: bool = paused
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	var file: String = output.path_join(label+".png")
	_check(pixels != null and pixels.get_size() == root.size and pixels.save_png(file) == OK,label+": native pixels saved")
	captures.append({"label":label,"file":file,"size":str(root.size),"detail":detail.duplicate(true),"captured_real_state_with_render_pause":true})
	paused = was_paused

func _dialogue_choice(id: String) -> void:
	await _button(hub.dialogue.choice_list.get_node_or_null("Choice_"+id) as Button,hub.dialogue.body_scroll)

func _station_button(id: String) -> void:
	await _button(hub.station_content.get_node_or_null(id) as Button,hub.station_scroll)

func _button(button: Button, scroll: ScrollContainer = null) -> void:
	if not _check(button != null and not button.disabled,"Actual clickable control is available"): return
	if scroll != null: scroll.ensure_control_visible(button)
	await _frames(3)
	_check(root.get_visible_rect().encloses(button.get_global_rect()),"Clickable control is reachable in native viewport")
	await _click(button.get_global_rect().get_center())

func _click(at: Vector2) -> void:
	await _hover(at)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new(); event.position = at; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		root.push_input(event,true)
		await _frames(2)

func _hover(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = at
	root.push_input(motion,true)
	await _frames(2)

func _wheel(at: Vector2, direction: MouseButton) -> void:
	var event := InputEventMouseButton.new(); event.position = at; event.button_index = direction; event.pressed = true
	root.push_input(event,true)
	await _frames(2)

func _action(id: StringName) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventAction.new(); event.action = id; event.pressed = pressed
		root.push_input(event,true)
		await _frames(2)

func _key(code: Key) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed
		root.push_input(event,true)
		await _frames(2)

func _reveal() -> void:
	for _index: int in 16:
		if not hub.dialogue.is_open or (not hub.dialogue.is_typing() and hub.dialogue.page_index == hub.dialogue.pages.size()-1): break
		await _key(KEY_E)
	await _frames(2)

func _resize(extent: Vector2i) -> void:
	root.size = extent
	await _frames(5)

func _reset_camera(player: Player) -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	camera.reset_smoothing(); camera.force_update_scroll()

func _wait_phase(actor: CultivatorActor, phase: String, seconds: float) -> void:
	for _index: int in int(ceil(seconds*60)):
		if actor.combat_phase == phase: return
		await _frames(1)

func _frames(count: int) -> void:
	for _index: int in count:
		await physics_frame
		await process_frame

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+label)
	return ok

func _finish() -> void:
	paused = false
	for id: StringName in [&"attack",&"spell_cast",&"move_left",&"move_right",&"jump"]: Input.action_release(id)
	if is_instance_valid(flow): flow.queue_free()
	await _frames(6)
	_check(is_equal_approx(Engine.time_scale,1.0) and get_nodes_in_group(&"npc_pilot_actor").is_empty(),"Teardown releases modal claims and all room NPC actors")
	var file := FileAccess.open(output.path_join("SECT_PROGRESSION_VISUAL_RESULT.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"observations":observations,"synthetic_grants":{"souls":500,"coins":200,"dust":20,"crystal":10},"scope":"Native controlled smoke, scripted input and room placement; not natural play, FPS benchmark or final-art approval."},"\t")); file.close()
	else: _check(false,"Write native evidence report")
	print("RESULT SectProgressionVisual checks=%d failures=%d captures=%d" % [checks,failures,captures.size()])
	quit(0 if failures == 0 else 1)

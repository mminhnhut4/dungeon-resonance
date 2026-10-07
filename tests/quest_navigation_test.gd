extends SceneTree
## Real UI/scene/save owners in an isolated user://. No GPU or balance claims.
var checks: int = 0
var failures: int = 0
var flow: GameFlow
var hub: ExteriorHub
var screen: InventoryScreen
var nav: QuestNavigator
var path: String
var samples: Array[Dictionary] = []
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks += 1; print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _step(n: int = 5) -> void:
	for _index: int in n: await physics_frame
func _bind() -> void:
	screen = flow.active_scene.get("gear").modal as InventoryScreen
	nav = screen.get_node("QuestNavigator") as QuestNavigator
func _choose(id: StringName) -> void:
	screen.open_map(); await _step()
	(screen.journal.quest_buttons[id] as Button).pressed.emit()
	nav.update_navigation()
func _close_panel() -> void:
	screen.close(); await _step(); nav.update_navigation()
func _open() -> void:
	flow = GameFlow.new(); flow.hub_scene = preload("res://scenes/hub/exterior_hub_room.tscn")
	flow.campaign_scene = preload("res://scenes/world_campaign.tscn")
	flow.world_building_enabled = true; flow.save_path_override = path
	root.add_child(flow); await _step(9)
	flow.cultivation_session.set_physics_process(false)
	hub = flow.active_scene as ExteriorHub; hub.npc_population.set_process(false); _bind()
func _record(label: String) -> void:
	samples.append({"label":label,"tracked":nav.tracked_id(),"navigation":nav.state.duplicate(true),"arrow_visible":nav.visible,"arrow_rect":nav.get_global_rect(),"panel_hint":screen.journal.navigation_label.text})
func _graph() -> void:
	var known: Dictionary = {ExteriorRouteCatalog.HUB:true}
	for room: StringName in ExteriorRouteCatalog.ROOMS: known[room] = true
	var before: String = JSON.stringify(known)
	_check(QuestNavigationRoute.next_door(&"o02_b04",&"main",ExteriorRouteCatalog.HUB,known,false) == &"door_west","Authored long return route starts at the actual west exit")
	_check(QuestNavigationRoute.next_door(ExteriorRouteCatalog.HUB,&"main",&"o02_b04",known,false) == &"door_east","Known outward route starts at Hub road instead of teleporting")
	_check(QuestNavigationRoute.next_door(&"o01_p02",ExteriorRouteCatalog.TUNNEL,ExteriorRouteCatalog.HUB,known,false,true) == &"door_east","Closed tunnel on the east side takes a valid detour without crossing its gate")
	_check(QuestNavigationRoute.next_door(&"o01_p02",ExteriorRouteCatalog.TUNNEL,ExteriorRouteCatalog.HUB,known,true,true) == &"door_west","Opened shortcut permits the existing west return")
	known.erase(&"o01_p02")
	_check(QuestNavigationRoute.next_door(&"o01_p03",&"main",ExteriorRouteCatalog.HUB,known,false) == &"","Missing discovery gap never invents a route")
	_check(QuestNavigationRoute.next_door(&"o01_p01",&"main",&"not_authored",known,true) == &"","Unknown destination has no navigation edge")
	known[&"o01_p02"] = true
	_check(JSON.stringify(known) == before,"Graph queries never open or discover rooms")
func _hub_checks() -> void:
	var bank: SanctuaryProfile = flow.profile
	screen.open_map(); await _step()
	_check(nav.tracked_id() == &"" and not nav.visible,"Reading/opening recommended quest never starts tracking automatically")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var payload: String = JSON.stringify(bank._export_payload())
	var ledger: String = JSON.stringify(GearInventoryCodec.encode(screen.inventory))
	(screen.journal.quest_buttons[&"explored"] as Button).grab_focus(); await _step()
	_check(nav.tracked_id() == &"","Controller/keyboard preview focus alone does not change the tracked quest")
	(screen.journal.quest_buttons[&"explored"] as Button).pressed.emit(); nav.update_navigation()
	_check(nav.tracked_id() == &"explored" and nav.state.get("anchor") == &"exterior_road" and not nav.visible,"Actual quest click tracks one real road objective while the modal hides the arrow")
	_check(JSON.stringify(bank._export_payload()) == payload and JSON.stringify(GearInventoryCodec.encode(screen.inventory)) == ledger and FileAccess.get_file_as_bytes(path) == bytes,"Click/navigation writes no canonical progress, inventory, currency or save bytes")
	await _close_panel()
	_check(nav.visible and nav.mouse_filter == Control.MOUSE_FILTER_IGNORE and nav.size == Vector2(28,28),"Gameplay gets only a compact non-interactive arrow")
	PlayerTravel.relocate(hub.player,Vector2(500,640)); await _step(); nav.update_navigation()
	var right: Vector2 = nav.direction
	PlayerTravel.relocate(hub.player,Vector2(950,640)); await _step(); nav.update_navigation()
	_check(right.x > 0 and nav.direction.x < 0,"Arrow direction follows real player and objective positions")
	_record("road")
	await _choose(&"thanh_vy_met"); await _close_panel()
	_check(nav.tracked_id() == &"thanh_vy_met" and nav.state.get("anchor") == NpcCatalog.HEALER,"A second click replaces the one tracked mission")
	var healer: HubNpc = hub.npcs[NpcCatalog.HEALER]
	healer.set_meta(&"dead",true); nav.update_navigation()
	_check(nav.state["status"] == "npc_dead" and not nav.visible and not bank.opening_progress["completed"].has("thanh_vy_met"),"Dead NPC fallback neither points to the actor nor completes the quest")
	healer.remove_meta(&"dead"); hub.npcs.erase(NpcCatalog.HEALER); nav.update_navigation()
	_check(nav.state["status"] == "npc_missing" and not nav.visible,"Missing NPC keeps a clear fallback without a stale station arrow")
	hub.npcs[NpcCatalog.HEALER] = healer
	_check(hub.enter_house(),"Actual existing home transition succeeds")
	nav.update_navigation()
	_check(nav.state.get("anchor") == &"home_exit" and nav.state["point"] == hub.house.exit_point.global_position,"Indoor navigation first points to the authored home exit")
	_check(hub.leave_house(),"Actual existing home exit restores the yard")
	await _choose(&"explored"); await _close_panel()
	_check(hub.enter_exterior(&"o01_p01"),"Actual road entry saves its existing exploration milestone")
	nav.update_navigation()
	_check(nav.tracked_id() == &"" and not nav.visible,"Canonical completion clears tracking and the arrow without selecting a replacement")
	await _choose(&"first_upgrade"); await _close_panel()
	_check(nav.state.get("anchor") == &"door_west","Outside Hub quest points to the real next return door")
	_check(hub.enter_exterior(&"o01_p03"),"Private fixture visits an existing distant room using its travel owner")
	nav.update_navigation()
	_check(nav.state["status"] == "route_locked" and not nav.visible,"Unknown intermediate room blocks guidance instead of exposing the map")
	_check(hub.enter_exterior(&"o01_p02") and hub.enter_exterior(&"o01_p03"),"Existing travel owner records the missing route discovery")
	nav.update_navigation()
	_check(nav.state.get("anchor") == &"door_west","Newly known route updates to the authored west door")
	_check(hub.enter_exterior(&"o01_p02",ExteriorRouteCatalog.TUNNEL,&"east"),"Existing closed tunnel fixture uses its valid east anchor")
	nav.update_navigation()
	_check(not bank.exterior_progress["sc01_open"] and nav.state.get("anchor") == &"door_east","Runtime closed gate takes the discovered detour and remains locked")
	_record("closed_tunnel")
	_check(hub.return_to_hub(),"Existing return owner restores the Hub")
	screen.open_map(); await _step(); screen.journal.cancel_navigation.pressed.emit(); nav.update_navigation()
	_check(nav.tracked_id() == &"" and not nav.visible and screen.journal.cancel_navigation.disabled,"Actual cancel button removes tracking without a quest action")
	await _close_panel(); await _choose(&"thanh_vy_met"); await _close_panel()
	var pre_reload: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_check(bank.load_profile(),"Existing save owner can reload the same canonical profile")
	screen.journal.refresh(); nav.update_navigation()
	_check(nav.state.get("anchor") == NpcCatalog.HEALER and FileAccess.get_file_as_bytes(path) == pre_reload,"Same-session load re-resolves the goal without rewriting the file")
	bank.read_only = true; nav.update_navigation()
	_check(nav.state["status"] == "state_unavailable" and not nav.visible,"Unverified/read-only state pauses guidance rather than inventing a valid target")
	bank.read_only = false
	await _choose(&"golem_defeated")
	screen.journal._request_action(); await _step()
	_check(bank.bounty_accepted,"Actual existing bounty action accepts the prerequisite")
	(screen.journal.quest_buttons[&"golem_defeated"] as Button).pressed.emit(); await _close_panel()
	_check(nav.state.get("anchor") == &"portal","Accepted bounty changes from the NPC to the existing dungeon entrance")
func _run_checks() -> void:
	flow.start_campaign(); await _step(9); _bind()
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	run.feedback.hit_stop_seconds = 0.0; run.feedback.enable_global_hitstop(false)
	run.gear.loot.drop_table = run.gear.loot.drop_table.duplicate(true)
	run.gear.loot.drop_table.none_chance = 1.0; run.gear.loot.drop_table.blueprint_chance_total = 0.0
	nav.update_navigation()
	_check(nav.tracked_id() == &"golem_defeated" and nav.state.get("anchor") == &"live_enemy","Shared profile keeps the one selection through a real Hub-to-run transition")
	flow.profile.bounty_accepted = false; screen.journal.refresh(); nav.update_navigation()
	_check(nav.state["status"] == "quest_gate" and not nav.visible,"Missing accepted prerequisite pauses the boss quest instead of directing an unearned kill")
	flow.profile.bounty_accepted = true; screen.journal.refresh(); nav.update_navigation()
	_check(nav.state.get("anchor") == &"live_enemy","Restoring the real accepted gate re-resolves the current live objective")
	await _choose(&"returned_to_hub"); await _close_panel()
	_check(nav.state["status"] == "exit_locked" and not nav.visible,"A locked combat floor never receives an exit arrow")
	await _choose(&"golem_defeated"); await _close_panel()
	for enemy: Node2D in run.living_enemies(): enemy.health.apply_damage(99999)
	await _step(); nav.update_navigation()
	_check(nav.state.get("anchor") == &"floor_exit","Actual cleared wave changes the objective to the next valid floor exit")
	PlayerTravel.relocate(run.player,Vector2(1240,640)); await _step()
	_check(run.floor_exit.open(),"Existing exit modal opens at its authored threshold")
	nav.update_navigation(); _check(not nav.visible,"Floor modal suspends the arrow with gameplay controls")
	run.floor_exit.continue_button.pressed.emit(); await _step(); nav.update_navigation()
	_check(run.stage == 2 and nav.state.get("anchor") == &"floor_exit","Existing continue advances the floor and refreshes the next valid objective")
	await _choose(&"reward_collected"); await _close_panel()
	_check(nav.state["status"] == "loot_missing" and not nav.visible,"Absent Soul loot produces a truthful fallback instead of an imaginary pickup")
	await _choose(&"golem_defeated"); await _close_panel()
	run.enter_stage(4); run.feedback.hit_stop_seconds = 0.0; run.feedback.enable_global_hitstop(false)
	run.boss.health.apply_damage(99999); await _step(); nav.update_navigation()
	_check(flow.profile.boss_proofs[&"golem"] == 1 and nav.state.get("anchor") == &"victory_portal","Actual boss completion changes navigation to the real final return portal")
	PlayerTravel.relocate(run.player,Vector2(1160,640)); await _step(); run.floor_exit.open()
	run.floor_exit.return_button.pressed.emit(); await _step(9)
	_check(flow.active_scene is ExteriorHub,"Existing victory save/return completes independently of navigation")
	if not flow.active_scene is ExteriorHub: return
	hub = flow.active_scene as ExteriorHub; hub.npc_population.set_process(false); _bind(); nav.update_navigation()
	_check(nav.state.get("anchor") == NpcCatalog.WANDERER,"Unclaimed proof redirects the existing tracked quest to its actual reward NPC")
	_record("reward_npc")
	await _choose(&"golem_defeated"); screen.journal._request_action(); await _step(); nav.update_navigation()
	_check(flow.profile.bounty_claimed and nav.tracked_id() == &"" and not nav.visible,"Actual once-only reward claim completes and clears navigation")
	_check(not screen._quest_action(&"bounty_claim")["ok"],"Navigation preserves the existing repeated-claim guard")
	for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size = Vector2i.ZERO; root.size = extent
		await _step(); screen._resize(); await _step()
		_check(root.get_visible_rect().encloses(screen.panel.get_global_rect()) and screen.journal.navigation_label.size.x > 0 and screen.journal.detail_sections.visible,"Existing guide/highlight panel remains bounded and available at %s" % extent)
	await _close_panel(); flow.queue_free(); await _step(7)
	await _open()
	_check(nav.tracked_id() == &"" and not nav.visible and flow.profile.bounty_claimed,"Cold load preserves canonical completion and asks for a fresh session selection")
	flow.queue_free(); await _step(7)
func _run() -> void:
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if DisplayServer.get_name() != "headless" or not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"): print("FAIL: isolated headless QA required"); quit(2); return
	path = "user://q/nav_%d/profile.json" % OS.get_process_id()
	AudioServer.set_bus_mute(0,true); _graph(); await _open(); await _hub_checks(); await _run_checks()
	_check(is_equal_approx(Engine.time_scale,1.0),"Navigation teardown adds no modal/time-scale ownership")
	DirAccess.make_dir_recursive_absolute("res://docs/verification/quest_navigation")
	var file := FileAccess.open("res://docs/verification/quest_navigation/samples.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(samples,"\t")); file.close()
	print("RESULT QuestNavigation checks=%d failures=%d user_data=%s" % [checks,failures,OS.get_user_data_dir()])
	quit(0 if failures == 0 else 1)

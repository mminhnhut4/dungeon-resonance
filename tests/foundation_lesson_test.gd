extends SceneTree
## Explicit unit/UI fixtures, never used as earned gameplay/video evidence.
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int=0
var failures: int=0
var flow: GameFlow
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func step(count: int=4) -> void:
	for i: int in count:await physics_frame;await process_frame
func install(hub: PrologueHub,ids: Array[StringName]) -> void:
	for index: int in GearInventory.CATALYST_INDICES:hub.gear.inventory.equip(index,&"")
	for i: int in ids.size():check(hub.gear.inventory.equip(GearInventory.CATALYST_INDICES[i],ids[i]),"Fixture owned rune installs through real inventory")
	await step(3)
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	AudioServer.set_bus_mute(0,true)
	var profile:=SanctuaryProfile.new();profile.save_path="user://lesson-unit/profile.json"
	var inventory: GearInventory=HubPreparation.starter_inventory(profile)
	for id: StringName in [&"fire",&"wind",&"lightning"]:
		for i: int in 2:inventory.add_rune(id)
	profile.hub_inventory=GearInventoryCodec.encode(inventory);check(profile.save(),"Explicit fixture is durably written")
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile.save_path;root.add_child(flow);await step(14)
	var hub: ExteriorHub=flow.active_scene as ExteriorHub
	var controller: ResonanceController=hub.player.resonance_controller
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	check(is_instance_valid(hub.link_dummy) and hub.link_dummy is TrainingDummy and hub.get_tree().get_nodes_in_group(&"training_dummy").size()==2,"Actual product safe yard contains two ordinary passive targets, no QA-only target")
	check(hub.link_dummy.hurtbox.team_id==hub.dummy.hurtbox.team_id and hub.link_dummy.health.maximum_health==hub.dummy.health.maximum_health,"Second target uses unchanged health/damage pipeline and team")
	check(hub.dummy.global_position.distance_to(hub.link_dummy.global_position)<=GearInventory.RUNES[0].chain_radius and hub.dummy.global_position.distance_to(hub.link_dummy.global_position)>FoundationLesson.EXAMPLE.effect_radius+16,"Existing yard spacing permits chain but keeps rear target outside primary firestorm AOE")
	await install(hub,[&"fire"])
	var view: Dictionary=FoundationLesson.view(controller)
	check(view["valid"] and view["before"]==0 and view["after"]==0 and "Bộ đơn" in view["reason"],"Single recipe is valid but does not promise extra links")
	await install(hub,[&"fire",&"wind"]);view=FoundationLesson.view(controller)
	check(view["recipe"]==controller.get_recipe() and view["ids"]==controller.catalyst_a.runtime_state.installed_rune_ids,"Visible recipe and multiset come from live controller, not an alternate resolver")
	check(view["before"]==0 and view["after"]==1 and not view["enabled"] and "Phép ghép hiện tại vẫn dùng" in view["reason"],"Missing stage explains the locked addition without disabling the valid composite cast")
	check("30 mana" in view["text"] and "1.20s" in view["text"] and "60%" in view["text"],"Cost/cooldown/link factor read real consumers, not authored unused recipe energy_cost")
	var save: PackedByteArray=FileAccess.get_file_as_bytes(flow.profile.save_path);var serial: int=int(get_meta(&"dungeon_combat_serial",0));var balance: float=hub.player.energy.current
	for i: int in 8:FoundationLesson.view(controller)
	check(FileAccess.get_file_as_bytes(flow.profile.save_path)==save and int(get_meta(&"dungeon_combat_serial",0))==serial and hub.player.energy.current==balance,"Repeated projection does not save, allocate UID or spend resources")
	var before: SpellSnapshot=controller.commit_cast();var cooldown: float=controller.cooldown_remaining();var spent: float=balance-hub.player.energy.current
	check(before!=null and before.chain_targets==view["before"] and spent==ResonanceController.CAST_ENERGY_COST,"Locked-stage preview matches actual committed cast and exact mana cost")
	controller.foundation_resonance_enabled=true;view=FoundationLesson.view(controller)
	check(before.chain_targets==0 and controller.cooldown_remaining()==cooldown and not controller.can_cast(),"Reading/unlocking after commit cannot rewrite projectile or clear cooldown")
	controller.reset_runtime();hub.player.energy.reset();var after: SpellSnapshot=controller.commit_cast()
	check(after.chain_targets==view["after"] and after.damage==before.damage and after.explosion_damage==before.explosion_damage and controller.cooldown_remaining()==cooldown,"Enabled preview matches actual link; primary/nuke damage and cooldown unchanged")
	check(hub.player.energy.maximum-hub.player.energy.current==spent,"Enabled cast consumes same exact mana cost")
	await install(hub,[&"wind",&"fire"]);view=FoundationLesson.view(controller)
	check(view["recipe"]==FoundationLesson.EXAMPLE and view["after"]==1,"Reverse order keeps the exact registered recipe")
	await install(hub,[&"fire",&"lightning"]);view=FoundationLesson.view(controller)
	check(view["before"]==2 and view["after"]==FoundationResonance.MAX_LINKS and "không tăng thêm" in view["reason"],"Already-capped recipe explicitly avoids promising another link")
	await install(hub,[&"wind",&"wind"]);controller.reset_runtime();hub.player.energy.reset();view=FoundationLesson.view(controller)
	check(not view["valid"] and "không thể niệm" in view["reason"] and not controller.can_cast() and controller.commit_cast()==null and hub.player.energy.current==hub.player.energy.maximum,"Invalid duplicate multiset shows reason and cannot spend or fallback")
	await install(hub,[&"fire",&"wind"]);screen.open();screen.tabs.current_tab=1;await step(5)
	check(screen.foundation_hint.text==FoundationLesson.view(controller)["text"] and screen.foundation_hint.is_visible_in_tree(),"Actual existing rune page binds current lesson projection")
	var old_size: Vector2i=root.size;var old_logical: Vector2i=root.content_scale_size
	for size: Vector2i in [Vector2i(1152,648),Vector2i(800,600)]:
		root.size=size;root.content_scale_size=size;await step(8);screen.content_scroll.ensure_control_visible(screen.foundation_hint);await step(4)
		check(screen.foundation_hint.get_global_rect().end.x<=screen.panel.get_global_rect().end.x+1 and screen.foundation_hint.autowrap_mode!=TextServer.AUTOWRAP_OFF,"Lesson wraps inside actual scroll page at viewport "+str(size))
	root.size=old_size;root.content_scale_size=old_logical;screen.close();await step(3)
	check(FoundationLesson.comparison(null)=={"before":0,"after":0} and FoundationLesson.view(null)["valid"]==false,"Missing runtime/recipe returns unavailable without initializing owners")
	flow.queue_free();await step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT FoundationLesson checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

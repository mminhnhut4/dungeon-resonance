extends SceneTree
## Real input -> Player FSM -> Weapon/Hitbox -> resolver -> live cultivation.
## Optional --seed-profile or DUNGEON_CULTIVATION_CAPTURE: read-only copied save.
## Headless wall/process timings are CPU observations, never native FPS proof.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int = 0
var failures: int = 0
var hz: int = 60
var flow: GameFlow
var campaign: WorldCampaign
var targets: Array[SlimeEnemy] = []
var frames: Array[Dictionary] = []
var hits: Array[Dictionary] = []
var resolved: Array[Dictionary] = []
var before_hit: Dictionary = {}
var unique_roots: Dictionary = {}
var mode: String = ""
var previous_usec: int = 0
var report: Dictionary = {}
var source_path: String = ""
var source_bytes: PackedByteArray
var initial_mastery: int = 0

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)
func step(count: int = 1) -> void:
	for _index: int in count: await physics_frame; await process_frame
func key(code: Key) -> void:
	var event := InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true
	Input.parse_input_event(event);await step(2)
	event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=false
	Input.parse_input_event(event)
func aim(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position=campaign.player.get_viewport().get_final_transform()*campaign.player.get_canvas_transform()*point
	Input.parse_input_event(event);await step(2)
func wait_idle() -> bool:
	var deadline: int=Time.get_ticks_usec()+2500000
	while Time.get_ticks_usec()<deadline:
		if not campaign.player.equipped_weapon.is_attacking() and not campaign.feedback.is_frozen() and is_equal_approx(Engine.time_scale,1.0): return true
		await step()
	return false

func on_frame() -> void:
	var now: int=Time.get_ticks_usec()
	if not mode.is_empty() and previous_usec>0:
		frames.append({"mode":mode,"wall_ms":(now-previous_usec)/1000.0,"time_usec":now,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"hitstop":campaign.feedback.is_frozen(),"time_scale":Engine.time_scale})
	previous_usec=now
func on_resolved(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage<=0.0: return
	resolved.append({"mode":mode,"source_kind":event.source_kind,"root":event.root_event_id,"attack":event.attack_id,"target":event.target_id,"melee":event.melee_hit,"damage":result.actual_damage})
	if event.melee_hit and event.source_kind==DamageEvent.SourceKind.DIRECT:
		before_hit["%d:%d" % [event.root_event_id,event.target_id]]=Time.get_ticks_usec()
func on_confirmed(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage<=0.0 or not event.melee_hit or event.source_kind!=DamageEvent.SourceKind.DIRECT: return
	var id: String="%d:%d" % [event.root_event_id,event.target_id]
	var end: int=Time.get_ticks_usec()
	unique_roots[event.root_event_id]=true
	hits.append({"mode":mode,"root":event.root_event_id,"attack":event.attack_id,"target":event.target_id,"wall_ms_from_resolved_to_confirmed":(end-int(before_hit.get(id,end)))/1000.0,"mastery":flow.profile.cultivation_progress["actors"]["player"]["mastery"],"hitstop":campaign.feedback.is_frozen(),"time_scale":Engine.time_scale,"remaining_hitstop_seconds":campaign.feedback.hit_stop_remaining})

func fixture_bytes() -> PackedByteArray:
	if not source_path.is_empty(): return FileAccess.get_file_as_bytes(source_path)
	# Portable strict-gate fixture; copied-real evidence is recorded separately.
	var profile := SanctuaryProfile.new();profile.profile_version=2
	profile.cultivation_progress=Model.new_progress(4)
	profile.cultivation_progress["revision"]=1024;profile.cultivation_progress["next_event"]=1025
	profile.cultivation_progress["actors"]["player"]["mastery"]=1024
	for index: int in 1024:
		profile.cultivation_progress["receipts"].append({"id":"cult_%d" % (index+1),"kind":"mastery","arguments_sha256":Writer.canonical({}).sha256_text(),"revision":index+1})
	profile.souls=29;profile.material_stash[&"crystal"]=11
	profile.hub_inventory=GearInventoryCodec.encode(HubPreparation.starter_inventory(profile))
	profile._retained_fields["combat_capture_fixture"]={"value":1.0000000000000002,"unchanged":"exact numeric field"}
	return Writer.canonical(Writer.sealed(profile._export_payload(),1313)).to_utf8_buffer()

func attack_once(label: String) -> void:
	check(await wait_idle(),label+": previous action/hitstop released")
	for index: int in targets.size():
		targets[index].motor.reset_motion();targets[index].global_position=Vector2(655+index*5 if index<2 else 740,640)
	PlayerTravel.relocate(campaign.player,Vector2(620,640),PlayerTravel.Kind.INTRA_EXPEDITION)
	await aim(targets[0].hurtbox.global_position)
	var old_roots: int=unique_roots.size()
	var old_mastery: int=flow.profile.cultivation_progress["actors"]["player"]["mastery"]
	await key(KEY_J)
	await step(6)
	check(await wait_idle(),label+": real attack recovers")
	check(unique_roots.size()==old_roots+1,label+": actual input produces one new accepted melee root")
	check(int(flow.profile.cultivation_progress["actors"]["player"]["mastery"])==old_mastery+1,label+": two targets/procs earn exactly one durable mastery")

func finish() -> void:
	mode=""
	if process_frame.is_connected(on_frame): process_frame.disconnect(on_frame)
	if is_instance_valid(campaign): campaign.feedback.reset_feedback()
	if is_instance_valid(flow): root.remove_child(flow);flow.queue_free()
	await step(4)
	check(is_equal_approx(Engine.time_scale,1.0),"Teardown releases all hitstop claims")
	if not source_path.is_empty(): check(FileAccess.get_file_as_bytes(source_path)==source_bytes,"Copied source bytes remain untouched by the entire gameplay probe")
	report.merge({"checks":checks,"failures":failures,"scope":"Headless actual gameplay CPU/wall timings; not native rendered frame-time/FPS","physics_hz":hz,"frames":frames,"confirmed_hits":hits,"resolved_events":resolved,"unique_mastery_roots":unique_roots.size()})
	var evidence: String=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	if not evidence.is_empty():
		var output := FileAccess.open(evidence+"/cultivation_combat_profile_trace.json",FileAccess.WRITE)
		output.store_string(JSON.stringify(report,"\t"));output.close()
	await root.get_node("AudioManager").shutdown()
	print("RESULT CultivationCombatProfile checks=%d failures=%d roots=%d confirmed=%d resolved=%d" % [checks,failures,unique_roots.size(),hits.size(),resolved.size()])
	quit(0 if failures==0 else 1)

func _run() -> void:
	var allowed: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if DisplayServer.get_name()!="headless" or not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: isolated headless QA directory required");quit(2);return
	source_path=OS.get_environment("DUNGEON_CULTIVATION_CAPTURE").replace("\\","/")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz=int(argument.trim_prefix("--hz="))
		if argument.begins_with("--seed-profile="): source_path=argument.trim_prefix("--seed-profile=").replace("\\","/")
	Engine.physics_ticks_per_second=hz
	source_bytes=fixture_bytes()
	var path: String="user://combat_capture_%d.json" % OS.get_process_id()
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_buffer(source_bytes);file.close()
	var original: Dictionary=Writer.read_json(path)
	check(Writer.seal_valid(original) and original.get("cultivation_progress",{}).get("receipts",[]).size()==1024,"Exact copied/portable source is a sealed 1024-receipt profile")
	if failures: await finish();return
	initial_mastery=int(original["cultivation_progress"]["actors"]["player"]["mastery"])
	report["source"]={"kind":"copied_real" if not source_path.is_empty() else "portable_fixture","path":source_path,"sha256":FileAccess.get_sha256(path),"bytes":source_bytes.size(),"initial_mastery":initial_mastery}
	flow=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate() as GameFlow
	flow.save_path_override=path;root.add_child(flow);current_scene=flow
	await step(12)
	check(flow.active_scene is ExteriorHub and flow.world_building_enabled and not flow.qa_tools_enabled,"Configured product GameFlow opens real ExteriorHub with QA helpers off")
	check(flow.cultivation_session.initialized and not flow.profile.read_only and flow.profile.cultivation_progress["schema_version"]==2,"Product startup migrates the full cultivation track before binding gameplay")
	check(flow.profile.cultivation_progress["actors"]["player"]["mastery"]==initial_mastery,"Product startup preserves every earned mastery point")
	for field: String in ["actors","origins","harvested_nodes","seed","config"]:
		check(Writer.canonical(flow.profile.cultivation_progress[field])==Writer.canonical(original["cultivation_progress"][field]),"Startup preserves cultivation "+field)
	check(Writer.canonical(flow.profile.hub_inventory)==Writer.canonical(original.get("hub_inventory",{})),"Startup preserves saved inventory including all UID/loot metadata")
	check(Writer.canonical(flow.profile.material_stash)==Writer.canonical(original["material_stash"]),"Startup preserves copied material bank")
	var backup: String=path+".cultivation_v1."+source_bytes.hex_encode().sha256_text()+".bak"
	check(FileAccess.get_file_as_bytes(backup)==source_bytes,"Actual startup creates the exact immutable pre-migration backup")
	check(Writer.seal_valid(Writer.read_json(path)),"Startup authority keeps a valid numeric seal")
	if failures: await finish();return
	flow.start_campaign();await step(8);campaign=flow.active_scene as WorldCampaign
	check(campaign!=null and campaign.stage==1 and flow.cultivation_session.scene==campaign,"Existing dungeon route starts WorldCampaign and rebinds the same cultivation owner")
	if campaign==null: await finish();return
	var original_items: Array=GearInventoryCodec.encode(campaign.gear.inventory)["items"].duplicate(true)
	check(campaign.player.equipped_weapon.definition.attack_kind==&"melee","Actual prepared equipment selects a melee moveset for this measured fixture")
	campaign.survival.director.automatic=false
	for enemy: Node2D in campaign.living_enemies(): enemy.queue_free()
	await step(4)
	for index: int in 3:
		var target: SlimeEnemy=campaign._spawn_slime(Vector2(655+index*5 if index<2 else 740,640))
		target.ai_enabled=false;target.contact_damage_enabled=false;target.health.maximum_health=100000;target.health.current_health=100000
		target.hurtbox.damage_resolver.damage_resolved.connect(on_resolved)
		targets.append(target)
	campaign.player.equipped_weapon.hit_confirmed.connect(on_confirmed)
	process_frame.connect(on_frame)
	# Test-only placement/AI isolation and one added rune through inventory APIs.
	check(campaign.gear.inventory.add_rune(&"lightning") and campaign.gear.inventory.equip(3,&"lightning"),"QA rune is added/equipped through actual inventory and binds chain proc")
	var current_items: Array=GearInventoryCodec.encode(campaign.gear.inventory)["items"]
	check(original_items.all(func(item: Dictionary) -> bool: return current_items.any(func(current: Dictionary) -> bool: return Writer.canonical(current)==Writer.canonical(item))),"Proc fixture retains every original item and its exact metadata")
	await step(4)
	for next_mode: String in ["intentional_hitstop","no_hitstop"]:
		campaign.feedback.reset_feedback();mode=next_mode
		campaign.feedback.hit_stop_seconds=0.05 if next_mode=="intentional_hitstop" else 0.0
		for index: int in 5: await attack_once("%s/%d" % [next_mode,index])
	check(hits.size()>unique_roots.size(),"Multiple real target contacts occurred in the same melee windows")
	check(campaign.player.resonance_controller.executor.chain_hit_count>0 and resolved.any(func(event: Dictionary) -> bool: return event["source_kind"]==DamageEvent.SourceKind.RESONANCE),"Actual lightning chain produced child damage without extra mastery")
	check(hits.any(func(hit: Dictionary) -> bool: return hit["mode"]=="intentional_hitstop" and hit["hitstop"]),"Intentional feedback freeze is recorded separately on accepted hits")
	check(not hits.any(func(hit: Dictionary) -> bool: return hit["mode"]=="no_hitstop" and hit["hitstop"]),"Control phase keeps mastery commits active with hitstop disabled")
	check(int(flow.profile.cultivation_progress["actors"]["player"]["mastery"])==initial_mastery+unique_roots.size(),"Only distinct real melee roots accrue mastery across contact/proc traffic")
	var cold := SanctuaryProfile.new();cold.save_path=path
	check(cold.load_profile() and not cold.read_only and Writer.seal_valid(Writer.read_json(path)),"Cold reader validates the exact post-combat profile")
	check(cold.cultivation_progress==flow.profile.cultivation_progress and cold.cultivation_progress["receipts"].size()==8,"Cold restore retains all combat mastery with bounded serial receipts")
	var stale: Dictionary=Model.propose(cold.cultivation_progress,cold.material_stash,cold.souls,cold.boss_proofs,"mastery",{},"cult_1025")
	check(not stale.get("ok",false),"First post-migration event stays rejected after eviction and cold reload")
	check(FileAccess.get_file_as_bytes(backup)==source_bytes,"Real combat never rewrites the original migration backup")
	await finish()

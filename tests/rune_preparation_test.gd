extends "res://tests/rune_learning_test.gd"
const Guide = preload("res://scripts/ui/rune_preparation.gd")
const Quantities = preload("res://scripts/runtime/bag_quantity_transactions.gd")
class QuietHub extends PrologueHub:
	func _refresh_station() -> void: pass # Only rendering is replaced; confirmation/owners are real.

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	directory="user://preparation-unit"
	var f: Dictionary=_fixture("states")
	var p: SanctuaryProfile=f["profile"]
	var inv: GearInventory=f["inventory"]
	var svc: RuneLearningService=f["service"]
	var eco: EconomySession=f["economy"]
	_check(Guide.view(p,inv,svc)["state"]=="choose_rune","No default rune selection or free grant")
	Guide.choose(p,&"poison")
	_check(Guide.view(p,inv,svc)["state"]=="already_prepared" and not svc.quote(&"poison")["learned"],"Owned looted rune precedes knowledge/depth locks")
	Guide.choose(p,&"fire")
	_check(Guide.view(p,inv,svc)["state"]=="learn_first","Unknown knowledge directs to real lesson")
	_check(svc.learn(&"fire"),"Learn prerequisite using sealed owner")
	for item: GearItem in inv.items.values().duplicate():
		if item.definition_id==&"fire":_check(inv.dismantle(item.uid),"Fixture removes prior Fire via existing dismantle")
	inv.materials[&"dust"]=2;inv.materials[&"crystal"]=1
	_check(Guide.view(p,inv,svc)["state"]=="ready_to_craft","Enough carried materials precede locked depth")
	inv.materials[&"dust"]=0;inv.materials[&"crystal"]=0;p.material_stash[&"dust"]=0;p.material_stash[&"crystal"]=0
	_check(Guide.view(p,inv,svc)["state"]=="route_locked","Closed depth directs to canonical gate")
	p.set_meta(&"rune_preparation_mine",true)
	var v: Dictionary=Guide.view(p,inv,svc)
	_check(v["state"]=="collect_missing" and v["missing"].size()==2 and v["sources"].contains("Mỏ Linh Thạch Vỡ"),"Actual prototype advertises its existing chest source")
	inv.materials[&"crystal"]=1;v=Guide.view(p,inv,svc)
	_check(v["missing"].size()==1 and v["missing"].has(&"dust") and not v["sources"].contains(MaterialCatalog.DISPLAY_NAMES[&"crystal"]),"Only missing dust is routed")
	inv.materials[&"dust"]=2;inv.materials[&"crystal"]=0;v=Guide.view(p,inv,svc)
	_check(v["missing"].size()==1 and v["missing"].has(&"crystal") and not v["sources"].contains(MaterialCatalog.DISPLAY_NAMES[&"dust"]),"Only missing crystal is routed")
	p.material_stash[&"crystal"]=1
	_check(Guide.view(p,inv,svc)["state"]=="withdraw_materials","Stash ownership does not count as carried craft cost")
	_check(eco.withdraw(&"crystal",1),"Existing stash transaction transfers required material")
	_check(Guide.view(p,inv,svc)["state"]=="ready_to_craft","Withdrawal refreshes readiness without forced expedition")
	var kept: Dictionary[int,GearItem]=inv.items.duplicate()
	while inv.items.size()<GearInventoryCodec.MAX_ITEMS:inv.add_item(&"rune",&"ice")
	_check(Guide.view(p,inv,svc)["state"]=="inventory_full","UID capacity blocks completion and explains freeing an item")
	inv.items.assign(kept)
	eco.hub_access=false
	_check(Guide.view(p,inv,svc)["state"]=="craft_blocked","Stale service outside hub cannot advertise ready")
	eco.hub_access=true;eco._busy=true
	_check(Guide.view(p,inv,svc)["state"]=="unavailable","Busy transaction cannot be declared complete")
	eco._busy=false;p.read_only=true
	_check(Guide.view(p,inv,svc)["state"]=="unavailable","Read-only recovery remains unavailable")
	p.read_only=false;p.hub_inventory_quarantined=true
	_check(Guide.view(p,inv,svc)["state"]=="unavailable","Quarantined carried ledger remains unavailable")
	p.hub_inventory_quarantined=false
	await _commits(f)
	await root.get_node("AudioManager").shutdown()
	print("RESULT RunePreparation checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)

func _commits(f: Dictionary) -> void:
	var p: SanctuaryProfile=f["profile"]
	var inv: GearInventory=f["inventory"]
	var svc: RuneLearningService=f["service"]
	var eco: EconomySession=f["economy"]
	var hub:=QuietHub.new();hub.profile=p;hub.economy=eco;hub.rune_learning=svc;hub.gear=GearSession.new();hub.gear.inventory=inv
	hub.station_open=true;hub.current_station=&"rune_learning"
	inv.materials[&"dust"]=8;inv.materials[&"crystal"]=4
	_check(eco._save_safe(),"Baseline material fixture saved by real owner")
	var before: Dictionary=GearInventoryCodec.encode(inv)
	var offer: Dictionary={"token":1,"kind":&"rune_craft","id":&"fire","station":&"rune_learning","quantity":2,"batch_offer":Quantities.quote(eco,&"rune_craft",&"fire",2,0,svc)}
	hub._pending_purchase=offer
	hub._confirm_purchase(1)
	_check(Guide.owned(inv,&"fire")==2 and inv.materials[&"dust"]==4 and inv.materials[&"crystal"]==2,"Actual batch callback creates exactly2 paid UIDs")
	_check(Guide.view(p,inv,svc)["state"]=="crafted_this_session" and hub.station_notice.contains("2 bùa Hỏa"),"Completion comes from successful saved owner result with quantity")
	var after: Dictionary=GearInventoryCodec.encode(inv)
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes(p.save_path)
	hub._confirm_purchase(1)
	_check(GearInventoryCodec.encode(inv)==after and bytes==FileAccess.get_file_as_bytes(p.save_path),"Duplicate confirmation cannot charge or grant twice")
	Guide.choose(p,&"ice")
	_check(Guide.view(p,inv,svc)["state"]=="learn_first","Changing selected ID cannot inherit prior completion")
	Guide.choose(p,&"fire")
	_check(Guide.view(p,inv,svc)["state"]=="already_prepared","Existing craft UID supports reopening without reward replay")
	Guide.prepare_extra(p)
	_check(Guide.view(p,inv,svc)["state"]=="ready_to_craft","Only explicit optional extra preparation asks for another paid craft")
	Guide.choose(p,&"");Guide.choose(p,&"fire")
	var panel: VBoxContainer=preload("res://scripts/ui/rune_preparation_panel.gd").new();root.add_child(panel)
	panel.call("present",p,inv,svc,true)
	_check(panel.get("last_view")["state"]=="already_prepared" and panel.get("body").text.contains("không cần chế thêm"),"Actual panel consumes owned-state copy")
	for i: int in 3:panel.call("present",p,inv,svc,true)
	_check(GearInventoryCodec.encode(inv)==after and bytes==FileAccess.get_file_as_bytes(p.save_path),"Repeated UI presentation is read-only")
	panel.queue_free();await process_frame
	var cold: Dictionary=_cold(p.save_path)
	_check(not cold["profile"].has_meta(Guide.KEY),"Cold load has no persistent quest receipt or stale notice")
	Guide.choose(cold["profile"],&"fire")
	_check(Guide.view(cold["profile"],cold["inventory"],cold["service"])["state"]=="already_prepared" and GearInventoryCodec.encode(cold["inventory"])==after,"Old-compatible save retains exact ledger; recomputes ownership")
	_check(svc.learn(&"wind"),"Second real lesson prepares single/failure paths")
	for item: GearItem in inv.items.values().duplicate():
		if item.definition_id==&"wind":inv.dismantle(item.uid)
	Guide.choose(p,&"wind")
	_check(eco._save_safe(),"Save pre-failure ledger")
	before=GearInventoryCodec.encode(inv);bytes=FileAccess.get_file_as_bytes(p.save_path)
	p._writer.fault_plan={"write_candidate":true}
	hub._pending_purchase={"token":2,"kind":&"rune_craft","id":&"wind","station":&"rune_learning","quantity":1,"batch_offer":Quantities.quote(eco,&"rune_craft",&"wind",1,0,svc)}
	hub._confirm_purchase(2)
	_check(Guide.view(p,inv,svc)["state"]=="save_failed" and GearInventoryCodec.encode(inv)==before and bytes==FileAccess.get_file_as_bytes(p.save_path),"Failed saved batch rolls back UID/costs and never announces completion")
	p._writer.fault_plan={}
	var q: Dictionary=svc.quote(&"wind")
	hub._pending_purchase={"token":3,"kind":&"rune_craft","id":&"wind","station":&"rune_learning","cost":q["cost"],"materials":q["craft_materials"],"learned":q["learned"]}
	hub._confirm_purchase(3)
	_check(Guide.owned(inv,&"wind")==1 and Guide.view(p,inv,svc)["state"]=="crafted_this_session","Single confirmation also publishes only saved success")
	after=GearInventoryCodec.encode(inv);hub._confirm_purchase(3)
	_check(GearInventoryCodec.encode(inv)==after,"Single stale token remains inert")
	Guide.choose(p,&"")
	_check(Guide.view(p,inv,svc)["state"]=="choose_rune","Optional guide can end without creating quest debt")
	hub.gear.free();hub.gear=null;hub.free()

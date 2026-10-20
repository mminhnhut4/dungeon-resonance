extends SceneTree
## Real LootSpawner rolls; synthetic isolated ledger, never a gameplay/farm-time claim.
const Supply=preload("res://data/floor_supply_catalog.gd")
class RecordingSpawner:
	extends LootSpawner
	var totals: Dictionary={}
	var kill_counts: Dictionary={}
	var current_kill: Dictionary={}
	var empty_kills: int=0
	func spawn(kind: StringName,id: StringName,location: Vector2,quantity: int=1,runtime_item: GearItem=null) -> LootPickup:
		var pickup: LootPickup=super.spawn(kind,id,location,quantity,runtime_item)
		if pickup!=null:
			var key: String=String(kind)+":"+String(id)
			totals[key]=int(totals.get(key,0))+quantity;current_kill[key]=true
			# Real spawn consumed its usual RNG/affix/launch values and created the item.
			# No pickup is collected, so no wallet/save write occurs in this model.
			pickup.free()
		return null
	func roll_one(enemy: StringName) -> void:
		current_kill.clear();enemy_drop(Vector2.ZERO,enemy)
		if current_kill.is_empty():empty_kills+=1
		for key: String in current_kill:kill_counts[key]=int(kill_counts.get(key,0))+1
var checks: int=0
var failures: int=0
var metrics: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+message)
func sample(table: DropTableResource,enemy: StringName,seed_value: int,count: int) -> Dictionary:
	var spawner:=RecordingSpawner.new();spawner.drop_table=table;spawner.permanent_profile=SanctuaryProfile.new();root.add_child(spawner);spawner.rng.seed=seed_value
	for i: int in count:spawner.roll_one(enemy)
	var result: Dictionary={"enemy":String(enemy),"seed":seed_value,"count":count,"totals":spawner.totals.duplicate(),"kill_counts":spawner.kill_counts.duplicate(),"empty":spawner.empty_kills}
	spawner.free();return result
func run() -> void:
	root.unfocusable=true;AudioServer.set_bus_mute(0,true)
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	var current: DropTableResource=load("res://data/loot/world_drop_table.tres")
	var baseline:=DropTableResource.new();baseline.blueprint_ids=current.blueprint_ids.duplicate()
	check(Supply.VERSION==2 and current.material_pools.size()==9,"V2 resource loads with nine explicit material pools")
	for id: StringName in baseline.material_pools:
		check(current.material_pool(id)==baseline.material_pool(id),"Preserve original pool and order: "+String(id))
	check(current.material_pool(&"depth_stone_guard")==current.material_pool(&"ancient_guard"),"Floor4 uses Guard material identity")
	check(current.material_pool(&"depth_root_bat")==current.material_pool(&"bloodwing_bat"),"Floor5 uses Bat material identity")
	check(current.material_pool(&"unknown")==baseline.material_pool(&"slime") and current.material_pool(&"depth_seal_warden")==baseline.material_pool(&"slime"),"Unknown and unmodified floor8 fallback remains explicit debt")
	check(current.none_chance==.35 and current.stone_chance==.12 and current.blueprint_chance_total==.005 and current.boss_souls==25,"Unchanged none/stone/blueprint/soul constants")
	var rng:=RandomNumberGenerator.new();rng.seed=7;var known: Array[StringName]=[]
	check(current.choose_blueprint(0,rng,known,true)!=&"" and current.choose_blueprint(.004999,rng,known,true)!=&"","Eligible blueprint lower boundary remains accepted")
	check(current.choose_blueprint(.005,rng,known,true)==&"" and current.choose_blueprint(1,rng,known,true)==&"" and current.choose_blueprint(0,rng,known,false)==&"","Blueprint upper boundary and eligibility remain exclusive")
	# Six independent seeds/type cases, with baseline/candidate coupling within each.
	for enemy: StringName in [&"depth_stone_guard",&"depth_root_bat"]:
		for seed_value: int in [261020,981731,440812]:
			var before: Dictionary=sample(baseline,enemy,seed_value,2500)
			var after: Dictionary=sample(current,enemy,seed_value,2500)
			var same: bool=before["empty"]==after["empty"]
			for key: String in before["totals"]:
				if not key in ["material:slime_essence","material:healing_herb","material:detox_root"]:
					same=same and before["totals"][key]==after["totals"].get(key,-1)
			check(same,"Same seeded non-material rewards survive alias: %s/%d"%[enemy,seed_value])
			check(absf(float(after["empty"])/2500-.35)<.04,"Observed empty chance agrees with35% within bounded tolerance")
			check(absf(float(after["kill_counts"].get("material:enhancement_stone_1",0))/2500-.078)<.02,"Actual stone chance includes none gate")
			for item: StringName in current.material_pool(enemy):
				var key: String="material:"+String(item)
				check(absf(float(after["kill_counts"].get(key,0))/2500-.65/3)<.04 and absf(float(after["totals"].get(key,0))/2500-.325)<.06,"Actual material probability/quantity: "+key)
			check(not after["totals"].has("material:slime_essence") and not after["totals"].has("material:origin_divine_stone"),"Alias removes fallback essence without introducing divine material")
			metrics.append({"baseline":before,"candidate":after})
	var floor5: Dictionary={}
	for source: Dictionary in Supply.sources_for_floor(2):floor5[source["item"]]=int(floor5.get(source["item"],0))+source["quantity"]
	check(floor5==RuneLearningService.CRAFT_COST,"One floor5 guaranteed packet equals one learned-rune recipe")
	check(Supply.sources_for_floor(1).size()==1 and Supply.sources_for_floor(3).is_empty(),"No extra grants on floor4 or floor6")
	var prior_quality: float=0
	for quality: int in 6:
		var item:=GearItem.new();item.quality=quality;item.drop_bonus=.08
		check(item.damage_factor()>=prior_quality,"Quality factor is nondecreasing; authored plateaus permitted")
		prior_quality=item.damage_factor();var previous: float=item.damage_factor()
		var all_increments: bool=true
		for level: int in range(1,13):
			item.enhancement_level=level
			all_increments=all_increments and is_equal_approx(item.damage_factor()-previous,.03);previous=item.damage_factor()
		check(all_increments,"Enhancement increases by0.03base, never compounds rarity")
	var inventory:=GearInventory.new();var weapon:=GearItem.new();weapon.uid=1;weapon.definition_id=&"ancient_sword";inventory.items[1]=weapon
	var profile:=SanctuaryProfile.new();profile.coins=1000
	for grade: int in range(1,7):inventory.materials[StringName("enhancement_stone_%d"%grade)]=10
	var economy:=EconomySession.new();economy.initialize(profile,inventory);economy.persist_safe_inventory=true
	var total_coins: int=0;var stone_equivalents: int=0;var costs_ok: bool=true
	for level: int in 12:
		weapon.enhancement_level=level
		var quote: Dictionary=economy.quote_enhance(1)
		costs_ok=costs_ok and quote["can_enhance"] and quote["coin_cost"]==(level+1)*5 and quote["stone_grade"]==ceili(float(level+1)/2)
		total_coins+=quote["coin_cost"];stone_equivalents+=int(pow(5,quote["stone_grade"]-1))
	check(costs_ok and total_coins==390 and stone_equivalents==7812,"Actual enhancement quote boundaries and full cost unchanged")
	weapon.enhancement_level=12;check(not economy.quote_enhance(1)["can_enhance"],"Enhancement cap12 remains enforced")
	var file:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("balance-distribution.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"version":Supply.VERSION,"rolls":30000,"metrics":metrics,"scope":"Actual Godot LootSpawner seeded RNG/spawn calls with synthetic profile, pickups freed without collection. Distribution/quotes only; no earned-play or farm-time claim."},"\t"));file.close()
	await root.get_node("AudioManager").shutdown()
	print("RESULT ProgressionBalance checks=%d failures=%d rolls=30000"%[checks,failures]);quit(0 if failures==0 else 1)

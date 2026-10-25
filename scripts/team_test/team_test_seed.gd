class_name TeamTestSeed
extends RefCounted
static var last_error: String=""
static func _fail(where: String,p: SanctuaryProfile) -> SanctuaryProfile:
	last_error=where+" "+str(p.last_commit);print("TEAM_SEED_REJECT "+last_error);return null
## Explicit QA grants in a new namespaced profile. All durable writes still go
## through SanctuaryProfile and its original sealed transaction owners.
static func isolated() -> bool:
	var prefix: String=OS.get_environment("TEAM_TEST_DATA_ROOT")
	if prefix.is_empty():prefix=OS.get_environment("DUNGEON_QA_DATA_ROOT")
	prefix=prefix.replace("\\","/").simplify_path().trim_suffix("/").to_lower()
	return not prefix.is_empty() and OS.get_user_data_dir().replace("\\","/").simplify_path().to_lower().begins_with(prefix+"/")
static func inventory(preset: int,branch: String="cloud_return") -> GearInventory:
	var inv:=GearInventory.new()
	inv.catalyst_uid=inv.add_item(&"catalyst",&"starter_catalyst").uid
	var sword: GearItem=inv.add_equipment(GearInventory.COMMON_SWORD)
	inv.equip_equipment(sword.uid);inv.install_starter_clothing()
	for id: StringName in TeamTestCatalog.WEAPONS:
		if id in [&"ancient_sword",&"training_sword",&"unarmed"]:continue
		var path: String="res://data/equipment/%s.tres"%id
		var item: GearItem=inv.add_equipment(load(path) as EquipmentData) if ResourceLoader.exists(path) else inv.add_item(&"weapon",id)
		if item!=null:item.source=&""
	for rune: RuneData in GearInventory.RUNES:
		for i: int in 5:inv.add_rune(rune.id,GearItem.Quality.DIVINE if preset==3 else GearItem.Quality.COMMON)
	if preset==3:inv.items[inv.catalyst_uid].quality=GearItem.Quality.DIVINE
	var wanted: StringName=&"storm_arcane_staff" if preset==2 else &"world_staff" if preset==3 and branch=="tether_sigil" else &"ancient_sword"
	for item: GearItem in inv.items.values():
		if item.kind==&"weapon":
			if preset==3:item.quality=GearItem.Quality.DIVINE;item.enhancement_level=12
			elif item.definition_id==wanted:item.enhancement_level=0 if preset==0 else 1 if preset==1 else 2
			if item.definition_id==wanted:inv.equip_equipment(item.uid)
	var runes: Array[StringName]=[]
	if preset==1:runes.assign([&"fire"])
	elif preset==2:runes.assign([&"ice",&"wind"])
	elif preset==3:runes.assign([&"fire",&"wind"])
	inv.equip_catalyst_set(runes)
	for relic: RelicData in RelicRuntime.CATALOG:inv.add_item(&"relic",relic.id)
	return inv
static func _command(p: SanctuaryProfile,kind: String,args: Dictionary,branch: String="") -> bool:
	var state: Dictionary=p.cultivation_progress
	var proposal: Dictionary=OpeningCultivationState.propose(state,p.material_stash,p.souls,p.boss_proofs,kind,args,"cult_%d"%int(state["next_event"]))
	return p.commit_cultivation(proposal,{},Callable(),branch)
static func prepare(path: String,preset: int,branch: String) -> SanctuaryProfile:
	if not isolated() or not path.begins_with("user://team_test_"):return null
	var p:=SanctuaryProfile.new();p.save_path=path
	if FileAccess.file_exists(path):return p if p.load_profile() and not p.read_only and p.extension_state("team_test_seed_v1").get("complete",false) else _fail("partial/corrupt seed; reset QA slot",p)
	p.coins=50000;p.souls=50000
	for id: StringName in MaterialCatalog.IDS:p.material_stash[id]=0 if id in [&"aptitude_herb",&"aptitude_pill"] else 200
	p.unlocked_weapons.assign(SanctuaryProfile.WEAPONS)
	p.discovered_recipes.assign(SanctuaryProfile.RECIPES);p.archived_recipes.assign(SanctuaryProfile.RECIPES)
	for variant: GearVariantData in WeaponVariantCatalog.all_variants():p.learned_blueprints.append(variant.id)
	for id: StringName in WorldProgressionCatalog.UPGRADES:
		p.permanent_upgrades[id]=WorldProgressionCatalog.MAX_LEVELS[id] if preset==3 else (2 if id in [&"max_hp",&"max_mana"] else 1 if id==&"mana_regen" else 0) if preset==2 else 0
	var inv: GearInventory=inventory(preset,branch);p.hub_inventory=GearInventoryCodec.encode(inv)
	p.exterior_progress["sc01_open"]=true
	if not p.save():return _fail("step56",p)
	var track: Dictionary
	for seed_value: int in 1000:
		track=OpeningCultivationState.new_progress(seed_value)
		if OpeningCultivationState.NODE_IDS.all(func(id:String)->bool:return OpeningCultivationState.node_available(track,id)):break
	if not p.commit_cultivation(OpeningCultivationState.initial_proposal(track,p.material_stash,p.souls,p.boss_proofs)):return _fail("initialize lineage track",p)
	for node_id: String in OpeningCultivationState.NODE_IDS:
		if not _command(p,"harvest",{"node_id":node_id}):return _fail("harvest lineage",p)
	if not _command(p,"craft_pill",{"origin_id":OpeningCultivationState.NODE_IDS[0]}):return _fail("craft lineage pill",p)
	if not p.record_boss_defeat("team_test_golem_unlock") or not p.record_opening_event(&"explored"):return _fail("step58",p)
	var depth:=DepthProgress.new();depth.initialize(p)
	if not depth.accept():return _fail("step60",p)
	for number: int in range(1,6):
		if not depth.record(StringName("depth_floor_%d"%number),number):return _fail("step62",p)
	if not depth.record(&"depth_boss_defeated",5):return _fail("step63",p)
	var member:=MemberDungeonProgress.new();member.initialize(p)
	for number: int in range(9,31):
		if not member.record(number):return _fail("step66",p)
	var sect:=SectJourneyProgress.new();sect.initialize(p)
	for faction: String in SectRouteCatalog.FACTIONS:
		for event: String in ["accept","west","east","guest"]:
			if not sect.record(faction,event):return _fail("step70",p)
	if preset==3:
		for insight: String in OpeningCultivationState.OBSERVATIONS:
			if not _command(p,"observe",{"insight_id":insight}):return _fail("step73",p)
		for i: int in 4:
			if not _command(p,"mastery",{}):return _fail("step75",p)
		if not _command(p,"train",{"actor_id":"player","sessions":2,"target_tick":16}):return _fail("step76",p)
		for stage: int in 3:
			if not _command(p,"breakthrough",{"actor_id":"player"},branch if stage==2 else ""):return _fail("step78",p)
	if not p.commit_extension_event("team_test_seed_v1","seed_complete",{},0,{"complete":true,"version":1},0).get("ok",false):return _fail("seed completion receipt",p)
	return p

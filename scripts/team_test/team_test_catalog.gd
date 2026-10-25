class_name TeamTestCatalog
extends RefCounted
## Existing content only; access is restricted to the separate TEAM TEST entry.
const WEAPONS: Array[StringName]=[&"ancient_sword",&"ancient_sword_bounty",&"blade_fan",&"blood_spiked_whip",&"demon_greatsword",&"gale_dual_daggers",&"ritual_staff",&"shadow_dagger",&"storm_arcane_staff",&"training_sword",&"unarmed",&"world_axe",&"world_chain",&"world_fan",&"world_greatsword",&"world_halberd",&"world_mace",&"world_saber",&"world_spear",&"world_staff",&"world_twinblades"]
const EQUIPMENT: Array[String]=["res://data/equipment/ancient_sword_bounty.tres","res://data/equipment/common_sword.tres","res://data/equipment/starter_amulet.tres","res://data/equipment/starter_boots.tres","res://data/equipment/starter_gloves.tres","res://data/equipment/starter_pants.tres","res://data/equipment/starter_ring.tres","res://data/equipment/starter_top.tres","res://data/equipment/test_rare_lightning_sword.tres","res://data/equipment/world_axe.tres","res://data/equipment/world_chain.tres","res://data/equipment/world_fan.tres","res://data/equipment/world_greatsword.tres","res://data/equipment/world_halberd.tres","res://data/equipment/world_mace.tres","res://data/equipment/world_saber.tres","res://data/equipment/world_spear.tres","res://data/equipment/world_staff.tres","res://data/equipment/world_twinblades.tres"]
const RECIPES: Array[String]=["res://data/resonances/astral_firestorm.tres","res://data/resonances/basic.tres","res://data/resonances/blizzard.tres","res://data/resonances/charged_slash.tres","res://data/resonances/combustion.tres","res://data/resonances/eclipse_blades.tres","res://data/resonances/firestorm.tres","res://data/resonances/fire_bolt.tres","res://data/resonances/frost_venom.tres","res://data/resonances/ice_bolt.tres","res://data/resonances/lightning_bolt.tres","res://data/resonances/miasma_cloud.tres","res://data/resonances/neurotoxin.tres","res://data/resonances/overload.tres","res://data/resonances/poison_bolt.tres","res://data/resonances/superconduct.tres","res://data/resonances/thermal_shock.tres","res://data/resonances/wind_bolt.tres"]
static func maps() -> Array[Dictionary]:
	var result: Array[Dictionary]=[{"id":"hub","label":"Căn cứ / NPC / dịch vụ","kind":"hub","value":0},{"id":"home","label":"Nhà người chơi","kind":"home","value":0}]
	for id: StringName in ExteriorRouteCatalog.all_rooms():result.append({"id":String(id),"label":ExteriorRouteCatalog.title(id),"kind":"exterior","value":id})
	result.append({"id":"corridor","label":"P02 · Hành lang SC01 đã mở","kind":"corridor","value":0})
	for i: int in 4:result.append({"id":"opening_%d"%i,"label":"Mở đầu · "+LinearCampaign.STAGE_NAMES[i],"kind":"opening","value":i+1})
	for i: int in 5:result.append({"id":"depth_%d"%i,"label":"Tầng %d · dungeon sâu"%(i+4),"kind":"depth","value":i+1})
	for i: int in range(9,31):result.append({"id":"member_%d"%i,"label":"Tầng %d · %s"%[i,MemberFloorCatalog.floor_data(i)["name"]],"kind":"member","value":i})
	for mode: String in ["alpha","linear","world"]:
		for i: int in (3 if mode=="alpha" else 4):result.append({"id":"%s_%d"%[mode,i],"label":"Legacy %s · chặng%d"%[mode,i+1],"kind":mode,"value":i+1})
	result.append({"id":"training","label":"Khu luyện combat/rig gốc","kind":"training","value":0})
	result.append({"id":"style_lab","label":"Lab công pháp G · fixture hiện có","kind":"style_lab","value":0})
	for i: int in MemberEnemyCatalog.IDS.size():result.append({"id":"actor_%d"%i,"label":"Actor · "+MemberConceptCatalog.MODELS[String(MemberEnemyCatalog.IDS[i])]["name"],"kind":"actor","value":i})
	return result

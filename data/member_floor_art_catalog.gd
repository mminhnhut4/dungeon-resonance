class_name MemberFloorArtCatalog
extends RefCounted
## Clean existing textures; decoration only, no collision/catalog mutations.
const SPECS: Dictionary={
9:[1,"8294b9","well"],10:[4,"8e827c","cold_forge"],11:[2,"77ab88","herb"],12:[5,"ae9b83","memory"],13:[1,"9aaac0","bridge"],14:[2,"74a4ad","dam"],15:[5,"ac9c85","history"],16:[2,"8ba6a0","names"],17:[1,"a5a1b9","hearing"],18:[1,"b1a28a","heart_bell"],19:[5,"ac9882","village"],20:[1,"829cae","rain_peak"],21:[4,"d49a78","earth_furnace"],22:[2,"93ad78","thorns"],23:[5,"999284","ruined_pillars"],24:[5,"a698b7","court"],25:[2,"7fadb4","river"],26:[1,"b8a080","bell_tower"],27:[4,"bd9e78","alchemy"],28:[5,"a19abf","talismans"],29:[1,"919dae","sky_steps"],30:[1,"b4a79d","echo_dais"]}
static func definition(number: int) -> Dictionary:
	var a: Array=SPECS[number]
	return {"material":a[0],"background":"res://assets/environment/depth_v1/floor_%d.png"%a[0],"tint":a[1],"motif":a[2]}

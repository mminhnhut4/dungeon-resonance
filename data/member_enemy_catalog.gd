class_name MemberEnemyCatalog
extends RefCounted
## Fresh actor definitions; optional fixed-floor balance leaves shared resources intact.
const IDS: Array[StringName]=[&"member_hellhound",&"member_emperor",&"member_jiangshi",&"member_spider",&"member_spiderling"]
const SPECS: Dictionary={
&"member_hellhound":{"hp":65.0,"body":Vector2(64,34),"height":62.0,"patrol":35.0,"speed":145.0,"range":95.0,"windup":.40,"active":.18,"recover":.40,"cooldown":.80,"damage":12.0,"attack_size":Vector2(80,30),"attack_at":Vector2(43,-23)},
&"member_emperor":{"hp":240.0,"body":Vector2(52,94),"height":130.0,"patrol":18.0,"speed":48.0,"range":125.0,"windup":.72,"active":.32,"recover":.68,"cooldown":1.25,"damage":18.0,"attack_size":Vector2(132,44),"attack_at":Vector2(64,-42)},
&"member_jiangshi":{"hp":85.0,"body":Vector2(34,65),"height":83.0,"patrol":26.0,"speed":65.0,"range":88.0,"windup":.55,"active":.22,"recover":.48,"cooldown":.95,"damage":13.0,"attack_size":Vector2(76,42),"attack_at":Vector2(40,-30)},
&"member_spider":{"hp":90.0,"body":Vector2(76,32),"height":77.0,"patrol":22.0,"speed":80.0,"range":94.0,"windup":.50,"active":.20,"recover":.45,"cooldown":.85,"damage":10.0,"attack_size":Vector2(82,30),"attack_at":Vector2(40,-20)},
&"member_spiderling":{"hp":12.0,"body":Vector2(26,16),"height":32.0,"patrol":65.0,"speed":185.0,"range":52.0,"windup":.25,"active":.13,"recover":.25,"cooldown":.55,"damage":4.0,"attack_size":Vector2(44,24),"attack_at":Vector2(24,-12)}
}
static func definition(id: StringName,number: int=0) -> WorldEnemyData:
	if id not in IDS:return null
	var spec: Dictionary=SPECS[id].duplicate(true);var result:=WorldEnemyData.new()
	spec.merge(MemberBalanceCatalog.stats(id,number),true)
	result.id=id;result.display_name=MemberConceptCatalog.MODELS[String(id)]["name"]
	result.maximum_hp=spec["hp"];result.body_size=spec["body"];result.visual_height=spec["height"]
	result.patrol_speed=spec["patrol"];result.chase_speed=spec["speed"];result.aggro_radius=450
	# The stationary target's center must fit inside the warned physical reach.
	var reach: float=float((spec["attack_at"] as Vector2).x)+float((spec["attack_size"] as Vector2).x)*.5-3.0
	result.attack_range=minf(float(spec["range"]),reach);result.windup=spec["windup"];result.active=spec["active"]
	result.recovery=spec["recover"];result.cooldown=spec["cooldown"];result.attack_damage=spec["damage"]
	return result
static func attack_rect(id: StringName,facing: float) -> Rect2:
	var spec: Dictionary=SPECS[id];var at: Vector2=spec["attack_at"];at.x*=facing
	return Rect2(at-(spec["attack_size"] as Vector2)*.5,spec["attack_size"])

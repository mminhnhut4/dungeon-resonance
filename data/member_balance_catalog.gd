class_name MemberBalanceCatalog
extends RefCounted
## Fixed authored progression. Never reads the player's loadout, wallet or save.
## Floor0 retains the original isolated actor prototype for review comparisons.
const BASE: Dictionary={
&"member_hellhound":{"hp":42.0,"damage":9.0,"windup":.55,"active":.18,"recover":.40,"cooldown":1.15},
&"member_jiangshi":{"hp":56.0,"damage":10.0,"windup":.65,"active":.22,"recover":.48,"cooldown":1.25},
&"member_spider":{"hp":56.0,"damage":8.0,"windup":.65,"active":.20,"recover":.45,"cooldown":1.20},
&"member_spiderling":{"hp":8.0,"damage":3.0,"windup":.42,"active":.13,"recover":.32,"cooldown":.90},
&"member_emperor":{"hp":154.0,"damage":15.0,"windup":.90,"active":.32,"recover":.68,"cooldown":1.60}}
static func phase(number: int) -> Vector3:
	if number>=28:return Vector3(1.4,1.25,.90)
	if number>=19:return Vector3(1.25,1.15,.97)
	if number>=14:return Vector3(1.15,1.10,1.0)
	return Vector3.ONE
static func stats(id: StringName,number: int) -> Dictionary:
	if number<9 or number>30 or not BASE.has(id):return {}
	var result: Dictionary=BASE[id].duplicate(true)
	var scale: Vector3=phase(number)
	result["hp"]=ceilf(float(result["hp"])*scale.x-0.00001)
	result["damage"]=float(result["damage"])*scale.y
	result["windup"]=float(result["windup"])*scale.z
	result["cooldown"]=float(result["cooldown"])*scale.z
	return result
static func brood_count(number: int) -> int:return 3 if number==11 else 4

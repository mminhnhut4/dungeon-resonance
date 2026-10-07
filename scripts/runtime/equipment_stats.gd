class_name EquipmentStats
extends Node
## Rebuild from base values. Equipping HP capacity never heals or revives.

var player: Player
var inventory: GearInventory
var base_health: float
var base_mana: float
var base_speed: float
var base_armor: float
var attack_bonus: float = 0.0
var armor_bonus: float = 0.0
var _last_health: float
var _last_mana: float
var _last_speed: float
var _last_armor: float
var _initial_health: float
var _initial_mana: float
var _initial_speed: float
var _initial_armor: float


func initialize(actor: Player, bag: GearInventory) -> void:
	player = actor
	inventory = bag
	base_health = player.health.maximum_health
	base_mana = player.energy.maximum
	base_speed = player.motor.run_speed
	base_armor = player.hurtbox.damage_resolver.armor_rating
	_initial_health = base_health
	_initial_mana = base_mana
	_initial_speed = base_speed
	_initial_armor = base_armor
	_last_health = base_health
	_last_mana = base_mana
	_last_speed = base_speed
	_last_armor = base_armor
	inventory.changed.connect(refresh)
	refresh()


func refresh() -> void:
	# Account for external permanent/run modifiers (e.g. the smuggler blood price).
	base_health += player.health.maximum_health - _last_health
	base_mana += player.energy.maximum - _last_mana
	base_armor += player.hurtbox.damage_resolver.armor_rating - _last_armor
	if not is_equal_approx(player.motor.run_speed, _last_speed):
		base_speed *= player.motor.run_speed / maxf(0.001, _last_speed)
	var hp: float = 0.0
	var mana: float = 0.0
	var speed: float = 0.0
	var critical: float = 0.0
	attack_bonus = 0.0
	armor_bonus = 0.0
	for slot: int in inventory.equipment_uids.size():
		var uid: int = inventory.equipped_weapon_uid if slot == 0 else inventory.equipment_uids[slot]
		var item: GearItem = inventory.items.get(uid)
		if item == null or not item.can_equip():
			continue
		var data: EquipmentData = item.equipment_definition
		if data != null:
			hp += data.bonus_hp
			armor_bonus += data.bonus_armor
			mana += data.bonus_mana
			speed += data.bonus_speed
			critical += data.bonus_crit
			attack_bonus += data.bonus_atk
		hp += item.affix_bonus(&"vitality")
		armor_bonus += item.affix_bonus(&"ward")
		mana += item.affix_bonus(&"focus")
		speed += item.affix_bonus(&"stride")
		critical += item.affix_bonus(&"precision")
	player.health.maximum_health = maxf(1.0, base_health + hp)
	player.health.current_health = minf(player.health.current_health, player.health.maximum_health)
	player.energy.maximum = maxf(1.0, base_mana + mana)
	player.energy.current = minf(player.energy.current, player.energy.maximum)
	player.motor.run_speed = base_speed * maxf(0.1, 1.0 + speed)
	player.hurtbox.damage_resolver.armor_rating = maxf(0.0, base_armor + armor_bonus)
	_last_health = player.health.maximum_health
	_last_mana = player.energy.maximum
	_last_speed = player.motor.run_speed
	_last_armor = player.hurtbox.damage_resolver.armor_rating
	player.equipped_weapon.equipment_critical_bonus = clampf(critical, 0.0, 1.0)
	player.health.health_changed.emit(player.health.current_health, player.health.maximum_health)


func reset_base_stats() -> void:
	# A new run drops external run penalties/bonuses, then rebuilds its gear stats.
	base_health = _initial_health
	base_mana = _initial_mana
	base_speed = _initial_speed
	base_armor = _initial_armor
	_last_health = player.health.maximum_health
	_last_mana = player.energy.maximum
	_last_speed = player.motor.run_speed
	_last_armor = player.hurtbox.damage_resolver.armor_rating
	refresh()

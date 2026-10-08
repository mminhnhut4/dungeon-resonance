class_name PermanentProgressionComponent
extends Node
## Opt-in permanent bonuses, never mutations of shared equipment definitions.
var gear: GearSession
var profile: SanctuaryProfile
var _hp_applied: float = 0.0
var _mana_applied: float = 0.0
var _base_regen: float = 0.0

func initialize(session: GearSession, permanent: SanctuaryProfile) -> void:
	gear = session
	profile = permanent
	_base_regen = gear.player.energy.regeneration
	profile.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var hp: float = 10.0 * profile.permanent_upgrades[&"max_hp"]
	gear.equipment_stats.base_health += hp - _hp_applied
	gear.equipment_stats._initial_health += hp - _hp_applied
	_hp_applied = hp
	var mana: float = WorldProgressionCatalog.VALUES[&"max_mana"] * profile.permanent_upgrades.get(&"max_mana", 0)
	gear.equipment_stats.base_mana += mana - _mana_applied
	gear.equipment_stats._initial_mana += mana - _mana_applied
	_mana_applied = mana
	gear.equipment_stats.refresh()
	gear.player.energy.regeneration = _base_regen + 2.0 * profile.permanent_upgrades[&"mana_regen"]
	gear.inventory.permanent_rune_capacity = profile.permanent_upgrades[&"rune_capacity"]
	gear.sync_loadout()

func _exit_tree() -> void:
	if profile != null and profile.changed.is_connected(refresh): profile.changed.disconnect(refresh)

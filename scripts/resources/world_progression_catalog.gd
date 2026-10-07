class_name WorldProgressionCatalog
extends RefCounted
## Prototype NPC prices/limits; values are explicit data, not final balance.
const UPGRADES: Array[StringName] = [&"max_hp", &"mana_regen", &"rune_capacity"]
const MAX_LEVELS: Dictionary = {&"max_hp": 5, &"mana_regen": 5, &"rune_capacity": 2}
const BASE_COSTS: Dictionary = {&"max_hp": 20, &"mana_regen": 30, &"rune_capacity": 50}
const VALUES: Dictionary = {&"max_hp": 10.0, &"mana_regen": 2.0, &"rune_capacity": 1.0}
const UNITS: Dictionary = {&"max_hp": "HP", &"mana_regen": "năng lượng/giây", &"rune_capacity": "ô Catalyst"}
const BOUNTY_ID: StringName = &"golem_hunt"
const BOUNTY_REWARD: StringName = &"ancient_sword_bounty"
const MAX_RECEIPTS: int = 128

static func empty_upgrades() -> Dictionary[StringName, int]:
	return {&"max_hp": 0, &"mana_regen": 0, &"rune_capacity": 0}

static func valid_id(id: Variant) -> bool:
	if not (id is String or id is StringName) or str(id).is_empty() or str(id).length() > 64: return false
	for character: String in str(id):
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_": return false
	return true

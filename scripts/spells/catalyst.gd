class_name Catalyst
extends Node
## Component holding an authored definition and unique runtime state.

signal loadout_changed

@export var definition: CatalystDefinition
var runtime_state: CatalystRuntime


func _ready() -> void:
	runtime_state = CatalystRuntime.new()
	runtime_state.opened_slots = definition.initial_slots


func install_runes(runes: Array[RuneData]) -> bool:
	if runes.size() > runtime_state.opened_slots:
		return false
	for rune: RuneData in runes:
		if rune == null or rune.id == &"":
			return false
	runtime_state.installed_runes.assign(runes)
	runtime_state.installed_rune_ids.clear()
	for rune: RuneData in runes:
		runtime_state.installed_rune_ids.append(rune.id)
	loadout_changed.emit()
	return true

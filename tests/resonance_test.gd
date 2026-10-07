extends SceneTree
## Exact recipes, independent catalyst runtime and definition ownership.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var resolver := ResonanceResolver.new()
	var catalog: Array[ResonanceDefinition] = []
	for id: String in ["basic", "fire_bolt", "wind_bolt", "lightning_bolt", "firestorm", "overload", "charged_slash"]:
		catalog.append(load("res://data/resonances/%s.tres" % id) as ResonanceDefinition)
	var fire: RuneData = load("res://data/runes/FireRune.tres")
	var wind: RuneData = load("res://data/runes/WindRune.tres")
	var lightning: RuneData = load("res://data/runes/LightningRune.tres")
	_check(fire.burn_damage > 0.0 and fire.burn_interval > 0.0, "Fire authors a timed burn payload")
	_check(wind.projectile_speed_multiplier > 1.0 and wind.maximum_pierced_targets > 1 and wind.knockback_multiplier > 1.0, "Wind authors speed, knockback and piercing")
	_check(lightning.chain_targets == 2, "Lightning has a bounded two-target chain")
	var pairs: Array[Array] = [[&"fire", &"wind"], [&"fire", &"lightning"], [&"wind", &"lightning"]]
	var expected: Array[StringName] = [&"firestorm", &"overload", &"charged_slash"]
	for index: int in pairs.size():
		var ids: Array[StringName] = []
		ids.assign(pairs[index])
		_check(resolver.resolve(ids, 3, catalog).id == expected[index], "Pair resolves %s" % expected[index])
		ids.reverse()
		_check(resolver.resolve(ids, 3, catalog).id == expected[index], "Reversing order preserves %s" % expected[index])
	_check(resolver.resolve([&"fire", &"fire"], 3, catalog) == null, "Duplicates do not collapse to a single rune")
	_check(resolver.resolve([&"fire", &"wind", &"lightning"], 3, catalog) == null, "Triple loadout does not run subset recipes")
	_check(resolver.resolve([&"unknown"], 3, catalog) == null, "Unknown rune has no fallback recipe")
	_check(resolver.resolve([&"fire", &"wind"], 1, catalog) == null, "Slot overflow is rejected")
	_check(resolver.resolve([], 3, catalog).id == &"basic", "Explicit empty recipe permits basic magic")
	var invalid_catalog: Array[ResonanceDefinition] = catalog.duplicate()
	invalid_catalog.append(catalog[0])
	_check(resolver.resolve([], 3, invalid_catalog) == null, "Duplicate recipe keys reject the catalog")
	var definition: CatalystDefinition = load("res://data/catalysts/starter_catalyst.tres")
	var a := Catalyst.new()
	var b := Catalyst.new()
	a.definition = definition
	b.definition = definition
	root.add_child(a)
	root.add_child(b)
	_check(a.runtime_state != b.runtime_state and a.runtime_state.opened_slots == 3, "Three-slot catalyst runtime belongs to each actor")
	_check(a.install_runes([fire, wind]) and b.runtime_state.installed_runes.is_empty(), "Installing A leaves B unchanged")
	_check(not a.install_runes([fire, wind, lightning, fire]) and a.runtime_state.installed_runes.size() == 2, "Overflow leaves installed loadout unchanged")
	_check(a.install_runes([fire, wind, lightning]), "All three slots can hold runes")
	_check(definition.initial_slots == 3 and fire.burn_damage == 3.0, "Runtime installation does not mutate shared data")
	a.queue_free()
	b.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])

class_name ResonanceResolver
extends RefCounted
## Exact multiset matching, including duplicate IDs. No subset fallback.


func canonical_key(ids: Array[StringName]) -> String:
	var sorted: Array[StringName] = ids.duplicate()
	sorted.sort()
	return "|".join(sorted)


func resolve(ids: Array[StringName], slots: int, catalog: Array[ResonanceDefinition]) -> ResonanceDefinition:
	if ids.size() > slots:
		return null
	var recipes: Dictionary[String, ResonanceDefinition] = {}
	for recipe: ResonanceDefinition in catalog:
		if recipe == null:
			return null
		var key: String = canonical_key(recipe.recipe_rune_ids)
		if recipes.has(key):
			return null
		recipes[key] = recipe
	return recipes.get(canonical_key(ids)) as ResonanceDefinition

class_name FoundationResonance
extends RefCounted
## Derived from committed cultivation. No reward ledger, counter or save schema.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const TITLE: String = "Liên Ấn"
const EXTRA_LINKS: int = 1
const MAX_LINKS: int = 2

static func unlocked(profile: SanctuaryProfile) -> bool:
	return profile != null and not profile.read_only and stage(profile)==3 and Model.valid(profile.cultivation_progress,profile.material_stash)

static func stage(profile: SanctuaryProfile) -> int:
	if profile == null:return -1
	var actors: Variant=profile.cultivation_progress.get("actors")
	if not actors is Dictionary or not actors.get("player") is Dictionary:return -1
	var value: Variant=actors["player"].get("stage")
	return int(value) if (value is int or value is float) and value in [0,1,2,3] else -1

static func links_after(before: int) -> int:
	return mini(MAX_LINKS,maxi(0,before)+EXTRA_LINKS)

static func apply(payload: SpellSnapshot, recipe: ResonanceDefinition, enabled: bool) -> void:
	if enabled and recipe != null and recipe.recipe_rune_ids.size() >= 2:
		payload.chain_targets = links_after(payload.chain_targets)

static func description() -> String:
	return "%s: bộ từ 2 bùa lan thêm %d mục tiêu gần, tổng tối đa %d liên kết; bộ đã có đủ 2 không tăng thêm. Liên kết gây %.0f%% sát thương đòn bùa, không tự nối vô hạn. Mana và hồi chiêu giữ nguyên." % [TITLE,EXTRA_LINKS,MAX_LINKS,SpellExecutor.CHAIN_DAMAGE_FACTOR*100.0]

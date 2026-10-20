class_name OpeningExplorationProgress
extends RefCounted
## One optional cache in the existing sealed profile. No second save writer.
const SCOPE: String = "opening_exploration_v1"
const REWARD: int = 2
var profile: SanctuaryProfile

func initialize(owner: SanctuaryProfile) -> void:
	profile = owner
	profile.register_extension_validator(SCOPE,valid)

static func valid(value: Variant) -> bool:
	return value is Dictionary and value.size()==2 and (value.get("version") is int or value.get("version") is float) and value.get("version")==1 and value.get("cache_claimed") is bool

static func state_for(owner: SanctuaryProfile) -> Dictionary:
	var saved: Dictionary=owner.extension_state(SCOPE)
	return saved if valid(saved) else {"version":1,"cache_claimed":false}

static func shortcut_open(owner: SanctuaryProfile) -> bool:
	# Existing manual lever saves stay authoritative. New completion grants the
	# same mechanical release, without another flag or retroactive save rewrite.
	return bool(owner.exterior_progress["sc01_open"]) or (owner.extension_transactions_available(TanDangProgress.SCOPE) and TanDangProgress.state_for(owner)["rewards"].has("q3"))

func available() -> bool:
	return profile!=null and profile.profile_version==2 and profile.extension_transactions_available(SCOPE)

func claim() -> Dictionary:
	if not available() or state_for(profile)["cache_claimed"]:return {"ok":false,"error":"unavailable_or_claimed"}
	var count: Variant=profile.material_stash.get(&"dust")
	if not MaterialCatalog.valid_count(count) or int(count)>MaterialCatalog.MAX_COUNT-REWARD:return {"ok":false,"error":"stash_full"}
	# The existing commit seals BOTH reward and receipt. Publication happens only
	# after it succeeds. Restore this adapter's proposal on refusal/uncertainty;
	# the existing writer owns any cold recovery of its decided payload.
	profile.material_stash[&"dust"]=int(count)+REWARD
	var result: Dictionary=profile.commit_extension_event(SCOPE,"p03_cache",{},0,{"version":1,"cache_claimed":true},profile.extension_revision(SCOPE))
	if not result.get("ok",false):profile.material_stash[&"dust"]=int(count)
	return result

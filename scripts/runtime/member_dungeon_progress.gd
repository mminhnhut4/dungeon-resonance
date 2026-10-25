class_name MemberDungeonProgress
extends RefCounted
## Content receipts only. The existing profile remains the sole transaction owner.
const SCOPE: String="member_dungeon_v1"
var profile: SanctuaryProfile
func initialize(owner: SanctuaryProfile) -> void:
	profile=owner;profile.register_extension_validator(SCOPE,valid)
static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=2 or value.get("version")!=1:return false
	var cleared: Variant=value.get("cleared")
	return (cleared is int or cleared is float) and is_finite(float(cleared)) and float(cleared)==floorf(float(cleared)) and cleared>=8 and cleared<=30
func state() -> Dictionary:
	var stored: Dictionary=profile.extension_state(SCOPE)
	return {"version":1,"cleared":8} if stored.is_empty() else stored
func available() -> bool:return profile!=null and profile.profile_version==2 and profile.extension_transactions_available(SCOPE)
func unlocked() -> bool:
	return available() and bool(profile.extension_state(DepthProgress.SCOPE).get("boss_defeated",false))
func record(number: int) -> bool:
	if not unlocked() or number<9 or number>30:return false
	var next: Dictionary=state()
	if not valid(next):return false
	if int(next["cleared"])>=number:return true
	if number!=int(next["cleared"])+1:return false
	next["cleared"]=number
	return bool(profile.commit_extension_event(SCOPE,"member_floor_%d"%number,{},0,next,profile.extension_revision(SCOPE)).get("ok",false))

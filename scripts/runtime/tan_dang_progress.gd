class_name TanDangProgress
extends RefCounted
const HomeCatalog = preload("res://scripts/world/tan_dang_home_catalog.gd")
## Finite quest facts only. NPC life/karma stays in NpcWorldState; one writer
## commits the quest, knowledge/bank and NPC proposal before publishing either.
const SCOPE: String = "tan_dang_mon_v1"
const MOC: String = "tan_dang_moc_yen"
const LAM: String = "tan_dang_lam_tuoc"
const DU: String = "tan_dang_du_hanh"
const NPC_IDS: Array[String] = [MOC, LAM, DU]
const LEADER: String = "tan_dang_leader"
const DEPUTY: String = "tan_dang_deputy"
const HOME_OFFICER_IDS: Array[String] = [LEADER, DEPUTY]
const RECIPE: StringName = &"firestorm"
const RECIPE_COST: int = 6
const QUEST_REWARD: int = 2
const KEYS: Array[String] = ["version","accepted","discoveries","choice","core","lamp","reports","rewards","contribution","membership","declined","recipe_claimed","recipe_paid","support_claimed","response_notices"]
var profile: SanctuaryProfile
var life: NpcWorldState
var last_result: Dictionary = {}

func initialize(owner: SanctuaryProfile, npc_owner: NpcWorldState) -> bool:
	profile = owner
	life = npc_owner
	return profile != null and profile.register_extension_validator(SCOPE, valid)

static func empty() -> Dictionary:
	return {"version":1,"accepted":false,"discoveries":[],"choice":"","core":"missing","lamp":"weak","reports":[],"rewards":[],"contribution":0,"membership":"guest","declined":false,"recipe_claimed":false,"recipe_paid":false,"support_claimed":false,"response_notices":[]}

static func _valid_set(values: Variant, allowed: Array[String], limit: int) -> bool:
	if not values is Array or values.size() > limit: return false
	var seen: Array[String] = []
	for value: Variant in values:
		if not value is String or value not in allowed or value in seen: return false
		seen.append(value)
	return true

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != KEYS.size(): return false
	for key: String in KEYS:
		if not value.has(key): return false
	if value["version"] != 1: return false
	for key: String in ["accepted","declined","recipe_claimed","recipe_paid","support_claimed"]:
		if not value[key] is bool: return false
	if not _valid_set(value["discoveries"],["lamp","lam","core"],3) or not _valid_set(value["reports"],["moc","lam"],2) or not _valid_set(value["rewards"],["q1","q2","q3"],3): return false
	if value["choice"] not in ["","gate","rescue"] or value["core"] not in ["missing","carried","installed","spent"] or value["lamp"] not in ["weak","lit","broken"] or value["membership"] not in ["guest","member","left"]: return false
	var notices: Array[String] = []
	for id: String in NPC_IDS:
		for reason: String in ["attacked","player_murder"]: notices.append(id+":"+reason)
	if not _valid_set(value["response_notices"],notices,6): return false
	if not (value["contribution"] is int or value["contribution"] is float) or not is_finite(float(value["contribution"])) or float(value["contribution"]) != floorf(float(value["contribution"])): return false
	if not value["accepted"] and (not value["discoveries"].is_empty() or not value["rewards"].is_empty()): return false
	if value["rewards"].has("q1") and value["discoveries"].size() != 3: return false
	if value["choice"] == "":
		if value["core"] != "missing" or value["lamp"] != "weak" or value["rewards"].has("q2") or not value["reports"].is_empty(): return false
	else:
		if not value["rewards"].has("q1") or not value["rewards"].has("q2"): return false
		if value["choice"] == "gate" and (value["core"] not in ["carried","installed"] or value["lamp"] != ("lit" if value["core"] == "installed" else "weak")): return false
		if value["choice"] == "rescue" and (value["core"] != "spent" or value["lamp"] != "broken"): return false
	if value["reports"].has("lam") and not value["reports"].has("moc"): return false
	if not value["reports"].is_empty() and value["core"] == "carried": return false
	if value["rewards"].has("q3") and (value["reports"].size() != 2 or not value["rewards"].has("q2")): return false
	if (value["recipe_claimed"] or value["support_claimed"] or value["membership"] != "guest" or value["declined"]) and not value["rewards"].has("q3"): return false
	if value["recipe_paid"] and not value["recipe_claimed"]: return false
	return int(value["contribution"]) == QUEST_REWARD * value["rewards"].size() - (RECIPE_COST if value["recipe_paid"] else 0) and int(value["contribution"]) >= 0

func available() -> bool:
	return profile != null and life != null and not life.read_only and not life.compound_locked and profile.profile_version == 2 and profile.extension_transactions_available(SCOPE)

func state() -> Dictionary:
	return state_for(profile)

static func state_for(owner: SanctuaryProfile) -> Dictionary:
	if owner == null: return empty()
	var saved: Dictionary = owner.extension_state(SCOPE)
	return saved if valid(saved) else empty()

func earned_merit() -> int:
	# Lifetime merit is a projection of existing, once-only quest receipts.
	# Spending contribution never changes the admission requirement.
	return QUEST_REWARD * state()["rewards"].size()

func officer_available(id: String) -> bool:
	return available() and id in HOME_OFFICER_IDS and alive(id) and life.records[id]["room"] == String(HomeCatalog.ROOM) and life.records[id]["mode"] not in ["downed","recovering"]

func alive(id: String) -> bool:
	return life != null and life.records.has(id) and life.records[id]["death"].is_empty() and life.records[id]["mode"] != "dead"

func murder_recorded() -> bool:
	for id: String in NPC_IDS:
		if life.karma(id).get("player_murdered",false): return true
	return false

func knows_murder(listener: String) -> bool:
	if listener not in NPC_IDS:return false
	for victim: String in NPC_IDS:
		if life.karma(victim).get("player_murdered",false) and (listener in life.records[victim]["causality"]["witnesses"]["player_murder"] or TanDangCausality.knows(life.records,victim,"player_murder",listener)):return true
	return false

func can_join(listener: String = MOC) -> bool:
	if listener == LEADER:
		# The leader considers the same story's surviving sponsors; a new room
		# cannot erase a grievance or turn distant murder into omniscient news.
		return officer_available(LEADER) and earned_merit() >= QUEST_REWARD * 3 and (can_join(MOC) or can_join(LAM))
	return available() and alive(listener) and listener in [MOC,LAM] and not knows_murder(listener) and life.karma(listener).get("grievance","")==""

func can_reconcile(id: String) -> bool:
	return available() and id in NPC_IDS and state()["rewards"].has("q3") and not knows_murder(id) and TanDangCausality.can_reconcile(life.records[id])

func known_recipe() -> bool:
	return profile.discovered_recipes.has(RECIPE) or profile.archived_recipes.has(RECIPE)

static func _reward(next: Dictionary, id: String) -> void:
	next["rewards"].append(id)
	next["contribution"] += QUEST_REWARD

func apply(action: String, actor_id: String = "", place: String = "") -> Dictionary:
	last_result = {"ok":false,"error":"precondition"}
	if not available(): return last_result
	if actor_id in HOME_OFFICER_IDS or place in HOME_OFFICER_IDS:
		if actor_id != place or not officer_available(place): return last_result
		var permitted: Array = ["accept","q1_reward","q3_reward","recipe","support"] if place == DEPUTY else ["join","decline","leave"]
		if action not in permitted: return last_result
	var next: Dictionary = state()
	var edits: Dictionary = {}
	var knowledge: String = ""
	var materials: Dictionary = {}
	var receipt: String = action
	var q3: bool = next["rewards"].has("q3")
	match action:
		"accept":
			if next["accepted"] or place not in ["ledger",MOC,LAM,"refuge",DEPUTY]: return last_result
			next["accepted"] = true
		"observe_lamp", "find_lam", "inspect_core":
			var fact: String = {"observe_lamp":"lamp","find_lam":"lam","inspect_core":"core"}[action]
			if not next["accepted"] or fact in next["discoveries"]: return last_result
			if (fact == "lamp" and place != "lamp") or (fact != "lamp" and place != "refuge"): return last_result
			next["discoveries"].append(fact)
		"q1_reward":
			if next["discoveries"].size() != 3 or next["rewards"].has("q1"): return last_result
			_reward(next,"q1")
		"choice_gate", "choice_rescue":
			if place != "refuge" or not next["rewards"].has("q1") or next["choice"] != "": return last_result
			if action == "choice_rescue" and not alive(DU): return last_result
			next["choice"] = "gate" if action == "choice_gate" else "rescue"
			next["core"] = "carried" if action == "choice_gate" else "spent"
			next["lamp"] = "weak" if action == "choice_gate" else "broken"
			if action == "choice_gate":
				if alive(DU): edits[DU] = {"death_context":"core_withdrawal","killer_id":"core_reclaimed"}
				if alive(MOC): edits[MOC] = {"trust_delta":2,"gratitude_delta":1,"gratitude_reason":"helped"}
				if alive(LAM): edits[LAM] = {"trust_delta":-2,"return_home":true}
			else:
				edits[DU] = {"trust_delta":2,"gratitude_delta":2,"gratitude_reason":"rescued","return_home":true}
				if alive(LAM): edits[LAM] = {"trust_delta":2,"gratitude_delta":1,"gratitude_reason":"helped","return_home":true}
				if alive(MOC): edits[MOC] = {"trust_delta":-1}
			_reward(next,"q2")
		"install_core":
			if place != "lamp" or next["core"] != "carried": return last_result
			next["core"] = "installed"
			next["lamp"] = "lit"
		"report_moc", "report_lam":
			var report_id: String = "moc" if action == "report_moc" else "lam"
			var npc: String = MOC if report_id == "moc" else LAM
			if next["choice"] == "" or next["core"] == "carried" or report_id in next["reports"]: return last_result
			if report_id == "lam" and "moc" not in next["reports"]: return last_result
			if (place == npc and not alive(npc)) or (place != npc and (place != "ledger" or alive(npc))): return last_result
			next["reports"].append(report_id)
		"q3_reward":
			if next["reports"].size() != 2 or q3: return last_result
			_reward(next,"q3")
		"recipe":
			if not q3 or next["recipe_claimed"]: return last_result
			var paid: bool = not known_recipe()
			if paid and int(next["contribution"]) < RECIPE_COST: return last_result
			next["recipe_claimed"] = true
			next["recipe_paid"] = paid
			if paid: next["contribution"] -= RECIPE_COST
			if paid: knowledge = String(RECIPE)
		"support":
			if not q3 or next["support_claimed"]: return last_result
			next["support_claimed"] = true
		"join":
			if not q3 or next["membership"] != "guest" or place not in [MOC,LAM,LEADER] or not can_join(place): return last_result
			next["membership"] = "member"
		"decline":
			if not q3 or next["declined"] or next["membership"] != "guest": return last_result
			next["declined"] = true
		"leave":
			if next["membership"] != "member": return last_result
			next["membership"] = "left"
		"assist":
			if actor_id not in NPC_IDS or place != actor_id or not alive(actor_id): return last_result
			var karma: Dictionary = life.karma(actor_id)
			if int(karma.get("gratitude",0)) <= 0 or karma.get("assistance_used",false) or karma.get("grievance","") != "" or karma.get("player_murdered",false) or life.records[actor_id]["causality"]["harmed"]: return last_result
			edits[actor_id] = {"consume_assistance":true}
			materials = {"linen_fiber":2}
			receipt = "assist_"+actor_id
		"reconcile":
			if place!=actor_id or not can_reconcile(actor_id):return last_result
			edits[actor_id]={"reconcile":true}
			receipt="reconcile_"+actor_id
		"notice":
			if actor_id not in NPC_IDS: return last_result
			var grievance: String = life.karma(actor_id).get("grievance","")
			var notice: String = actor_id+":"+grievance
			if grievance not in ["attacked","player_murder"] or notice in next["response_notices"]: return last_result
			if not TanDangCausality.knows(life.records,actor_id,grievance,place):return last_result
			next["response_notices"].append(notice)
			receipt = "notice_"+actor_id+"_"+grievance
		_: return last_result
	if not valid(next):
		last_result["error"] = "invalid_proposal"
		return last_result
	var proposal: Dictionary = life.propose_sect_changes(edits)
	if proposal.is_empty():
		last_result["error"] = "npc_proposal_rejected"
		return last_result
	last_result = profile.commit_npc_extension_event(SCOPE,receipt,next,profile.extension_revision(SCOPE),life,proposal,knowledge,materials)
	return last_result

static func rows(owner: SanctuaryProfile) -> Array[Dictionary]:
	var s: Dictionary = state_for(owner)
	var first_target: StringName = &"o01_p03" if s["accepted"] and s["discoveries"].has("lamp") else ExteriorRouteCatalog.HUB
	var q1: String = "Đèn Tàn Đăng thiếu lõi. Tiếp theo: nhận việc cạnh đèn ở căn cứ; bàn sổ cũng tiếp nhận."
	if s["accepted"]:
		if s["rewards"].has("q1"): q1 = "Đã khép ba phát hiện và nhận 2 cống hiến. Một lõi gắn với hai lời hứa: giữ cổng và cứu người."
		elif s["discoveries"].size() == 3: q1 = "Đã kiểm đèn, ghi chuyện Lâm Tước và xem lõi. Tiếp theo: khép ghi chép để nhận 2 cống hiến."
		elif not s["discoveries"].has("lamp"): q1 = "Đã nhận việc tìm lõi. Tiếp theo: E kiểm đèn tại căn cứ."
		elif not s["discoveries"].has("lam"): q1 = "Đèn thiếu lõi. Tiếp theo: theo Đường Bộ tới trú ẩn P03, nghe lời hoặc đọc ghi chép của Lâm Tước."
		else: q1 = "Lâm Tước đã mang lõi đi cứu Dư Hành. Tiếp theo: E kiểm lõi cổ phù ở trú ẩn P03."
	var result: Array[Dictionary] = [{"id":&"tan_dang_q1","title":"Ngọn đèn thiếu lõi","body":q1,"target":first_target,"done":s["rewards"].has("q1"),"next":false}]
	if s["rewards"].has("q1"):
		var q2: String = "Lõi giữ cổng cũng được mang tới cứu Dư Hành. Tiếp theo: tại trú ẩn P03, xem hậu quả và xác nhận một lựa chọn. Không có đếm ngược."
		if s["choice"] == "gate": q2 = "Đã chọn giữ cổng, thu lõi và nhận 2 cống hiến. Tiếp theo: mang lõi về lắp vào đèn căn cứ." if s["core"] == "carried" else "Đã chọn giữ cổng. Lõi đã lắp lại, đèn sáng; 2 cống hiến đã ghi."
		elif s["choice"] == "rescue": q2 = "Đã tiêu lõi để cứu Dư Hành và nhận 2 cống hiến. Đèn cổng chịu thiệt hại; lối vẫn thông. Quyết định ấy đã được ghi."
		result.append({"id":&"tan_dang_q2","title":"Một lõi, hai lời hứa","body":q2,"target":&"o01_p03","done":s["rewards"].has("q2"),"next":false})
	if s["rewards"].has("q2"):
		var q3: String = "Đã thu lõi. Tiếp theo: mang về căn cứ, lắp vào đèn rồi báo Mộc Yên." if s["core"] == "carried" else "Quyết định về lõi đã ghi. Tiếp theo: báo Mộc Yên tại căn cứ; nếu người ấy đã chết, ghi phần báo cáo vào bàn sổ."
		if s["reports"].has("moc"): q3 = "Đã ghi phần báo cáo Mộc Yên. Tiếp theo: báo Lâm Tước; nếu người ấy đã chết, ghi phần còn lại vào bàn sổ."
		if s["reports"].size() == 2: q3 = "Đã ghi đủ hai phần báo cáo. Tiếp theo: nhận phần trách nhiệm để nhận 2 cống hiến cuối."
		if s["rewards"].has("q3"):
			q3 = "Đã khép việc chiếc đèn và nhận đủ ba lần cống hiến. Tiếp theo: ghi nhận sách Hồi Đăng tại bàn sổ hoặc người tiếp nhận. Sách ghi Bão Lửa: Hỏa + Phong."
			if owner != null and (owner.discovered_recipes.has(RECIPE) or owner.archived_recipes.has(RECIPE)): q3 += " Đã biết công thức thì không trừ cống hiến."
			if s["recipe_claimed"]: q3 = "Đã ghi tri thức Hồi Đăng. Tiếp theo: nhận chỉ dẫn Trúc Cơ tại bàn sổ hoặc người tiếp nhận."
			if s["recipe_claimed"] and s["support_claimed"]: q3 = "Đã khép việc, ghi Hồi Đăng và nhận chỉ dẫn Trúc Cơ. Có thể tiếp tục bước tu luyện đang thiếu hoặc khám phá đường giữ đèn SC01 từ hầm P01/P03. Nhập môn vẫn tự nguyện."
			elif s["support_claimed"] and not s["recipe_claimed"]: q3 = "Đã nhận chỉ dẫn Trúc Cơ. Tiếp theo: ghi nhận sách Hồi Đăng tại bàn sổ hoặc người tiếp nhận; nếu đã biết Bão Lửa thì không trừ cống hiến."
		result.append({"id":&"tan_dang_q3","title":"Trở về nhận phần mình","body":q3,"target":ExteriorRouteCatalog.HUB,"done":s["rewards"].has("q3"),"next":false})
	return result

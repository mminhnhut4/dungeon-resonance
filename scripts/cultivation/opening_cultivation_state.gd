class_name OpeningCultivationState
extends RefCounted
## Pure, bounded proposals. The common profile writer commits progress and bank
## together. Hit confirmation, eligible gameplay pulses and NPC life are external
## trusted adapter inputs; this model has no IO, scene or life authority.

const SCHEMA_VERSION: int = 1
const LIMIT: int = 1000000000
const BANK_LIMIT: int = 999999
const MAX_RECEIPTS: int = 1024
const PLAYER: String = "player"
const NPC: String = "pilot_gatherer"
const NODE_IDS: Array[String] = ["h00_courtyard_01", "o01_p04_01"]
const OBSERVATIONS: Array[String] = ["explored", "golem_defeated", "thanh_vy_met"]
const NPC_INSIGHTS: Array[String] = ["practice_1", "practice_2", "practice_3"]
const COMMANDS: Array[String] = ["observe", "mastery", "train", "enroll", "breakthrough", "harvest", "craft_pill", "consume"]
const PROGRESS_KEYS: Array[String] = ["schema_version", "config", "seed", "revision", "next_event", "gameplay_tick", "actors", "origins", "harvested_nodes", "receipts"]
const ACTOR_KEYS: Array[String] = ["id", "stage", "energy", "mastery", "insight_ids", "aptitude", "remainder", "trained_ticks", "last_train_tick", "enrolled", "sessions_left"]
const CONFIG_KEYS: Array[String] = ["schema_version", "tuning_status", "ticks_per_second", "training_session_ticks", "training_gain", "training_resource", "training_cost", "max_train_sessions", "max_npc_sessions", "aptitude_rate_bps", "aptitude_cap", "stages", "stage_labels", "energy_thresholds", "mastery_thresholds", "insight_thresholds", "interim_dust_cost", "final_dust_cost", "final_soul_cost", "final_golem_proof", "pill_dust_cost", "herb_occurrence_bps", "aptitude_gains"]

static func default_config() -> Dictionary:
	# This versioned tuning proposal is persisted with each track, not canon or
	# final balance. The JSON authoring counterpart contains the same values.
	return {
		"schema_version": 1, "tuning_status": "proposal_not_final",
		"ticks_per_second": 4, "training_session_ticks": 8,
		"training_gain": 8, "training_resource": "crystal", "training_cost": 1,
		"max_train_sessions": 8, "max_npc_sessions": 6,
		"aptitude_rate_bps": 100, "aptitude_cap": -1,
		"stages": ["luyen_khi_i", "luyen_khi_ii", "luyen_khi_iii", "truc_co_so_ky"],
		"stage_labels": ["Luyện Khí I", "Luyện Khí II", "Luyện Khí III", "Trúc Cơ sơ kỳ"],
		"energy_thresholds": [12, 24, 40], "mastery_thresholds": [2, 5, 8],
		"insight_thresholds": [1, 2, 3], "interim_dust_cost": 1,
		"final_dust_cost": 2, "final_soul_cost": 5, "final_golem_proof": 1,
		"pill_dust_cost": 2, "herb_occurrence_bps": 2000,
		"aptitude_gains": {"herb": 5, "pill": 8}
	}

static func new_progress(seed_value: Variant) -> Dictionary:
	if not _integer(seed_value, 0, LIMIT): return _failure("invalid_seed")
	return {
		"schema_version": SCHEMA_VERSION, "config": default_config(), "seed": int(seed_value),
		"revision": 0, "next_event": 1, "gameplay_tick": 0,
		"actors": {PLAYER: _new_actor(PLAYER)}, "origins": {},
		"harvested_nodes": [], "receipts": []
	}

static func _new_actor(actor_id: String) -> Dictionary:
	return {"id": actor_id, "stage": 0, "energy": 0, "mastery": 0,
		"insight_ids": [], "aptitude": 0, "remainder": 0, "trained_ticks": 0,
		"last_train_tick": 0, "enrolled": actor_id == PLAYER, "sessions_left": 0}

static func valid(progress: Variant, materials: Variant) -> bool:
	if not _keys(progress, PROGRESS_KEYS) or not _integer(progress.get("schema_version"), 1, 1): return false
	if not _valid_config(progress.get("config")) or not _valid_materials(materials): return false
	for field: String in ["seed", "gameplay_tick"]:
		if not _integer(progress.get(field), 0, LIMIT): return false
	if not _integer(progress.get("revision"), 0, MAX_RECEIPTS) or not _integer(progress.get("next_event"), 1, MAX_RECEIPTS + 1): return false
	if progress["next_event"] != progress["revision"] + 1: return false
	var actors: Variant = progress.get("actors")
	if not actors is Dictionary or not actors.has(PLAYER) or actors.size() < 1 or actors.size() > 2: return false
	for actor_id: Variant in actors:
		if actor_id not in [PLAYER, NPC] or not _valid_actor(actors[actor_id], str(actor_id), progress): return false
	if not _valid_origins(progress, materials): return false
	var receipts: Variant = progress.get("receipts")
	if not receipts is Array or receipts.size() != int(progress["revision"]): return false
	var event_ids: Dictionary = {}
	for index: int in receipts.size():
		var receipt: Variant = receipts[index]
		if not _keys(receipt, ["id", "kind", "arguments_sha256", "revision"]): return false
		if not _event_id(receipt.get("id")) or event_ids.has(receipt["id"]) or receipt.get("kind") not in COMMANDS: return false
		if not _hex_digest(receipt.get("arguments_sha256")) or not _integer(receipt.get("revision"), index + 1, index + 1): return false
		event_ids[receipt["id"]] = true
	return true

static func _valid_config(config: Variant) -> bool:
	if not _keys(config, CONFIG_KEYS) or not _integer(config.get("schema_version"), 1, 1) or config.get("tuning_status") != "proposal_not_final": return false
	# Clock units and content identities stay fixed within this schema. Numeric
	# gains/costs/thresholds may be tuned and remain part of the persisted config.
	if not _integer(config.get("ticks_per_second"), 4, 4) or not _integer(config.get("training_session_ticks"), 8, 8) or config.get("training_resource") != "crystal": return false
	for field: String in ["training_gain", "training_cost", "interim_dust_cost", "final_dust_cost", "final_soul_cost", "final_golem_proof", "pill_dust_cost"]:
		if not _integer(config.get(field), 1, 10000): return false
	if not _integer(config.get("max_train_sessions"), 1, 8) or not _integer(config.get("max_npc_sessions"), 1, 6): return false
	if not _integer(config.get("aptitude_rate_bps"), 1, 1000) or not _integer(config.get("herb_occurrence_bps"), 0, 10000): return false
	if not (_integer(config.get("aptitude_cap"), -1, -1) or _integer(config.get("aptitude_cap"), 1, LIMIT)): return false
	if config.get("stages") != ["luyen_khi_i", "luyen_khi_ii", "luyen_khi_iii", "truc_co_so_ky"]: return false
	if not config.get("stage_labels") is Array or config["stage_labels"].size() != 4: return false
	for label: Variant in config["stage_labels"]:
		if not label is String or label.is_empty() or label.length() > 64 or "\n" in label or "\r" in label: return false
	for field: String in ["energy_thresholds", "mastery_thresholds", "insight_thresholds"]:
		if not config.get(field) is Array or config[field].size() != 3: return false
		var previous: int = 0
		for threshold: Variant in config[field]:
			if not _integer(threshold, previous + 1, 3 if field == "insight_thresholds" else LIMIT): return false
			previous = int(threshold)
	if not _keys(config.get("aptitude_gains"), ["herb", "pill"]): return false
	for gain: Variant in config["aptitude_gains"].values():
		if not _integer(gain, 1, 1000): return false
	return true

static func _valid_actor(actor: Variant, actor_id: String, progress: Dictionary) -> bool:
	if not _keys(actor, ACTOR_KEYS) or actor.get("id") != actor_id or not _integer(actor.get("stage"), 0, 3): return false
	var config: Dictionary = progress["config"]
	for field: String in ["energy", "mastery", "trained_ticks", "last_train_tick"]:
		if not _integer(actor.get(field), 0, LIMIT): return false
	if not _integer(actor.get("aptitude"), 0, LIMIT) or not _integer(actor.get("remainder"), 0, 9999) or not actor.get("enrolled") is bool: return false
	if int(config["aptitude_cap"]) >= 0 and actor["aptitude"] > config["aptitude_cap"]: return false
	if actor["last_train_tick"] > progress["gameplay_tick"] or actor["trained_ticks"] > actor["last_train_tick"] or int(actor["trained_ticks"]) % int(config["training_session_ticks"]) != 0: return false
	if not _integer(actor.get("sessions_left"), 0, int(config["max_npc_sessions"])): return false
	if actor_id == PLAYER and (not actor["enrolled"] or actor["sessions_left"] != 0): return false
	if actor_id == NPC and not actor["enrolled"] and actor["sessions_left"] != 0: return false
	var insights: Variant = actor.get("insight_ids")
	if not insights is Array or insights.size() > 3: return false
	var seen: Dictionary = {}
	for insight: Variant in insights:
		if insight not in (OBSERVATIONS if actor_id == PLAYER else NPC_INSIGHTS) or seen.has(insight): return false
		seen[insight] = true
	if actor_id == NPC:
		var sessions: int = int(float(actor["trained_ticks"]) / float(config["training_session_ticks"]))
		if actor["mastery"] != sessions or insights != _practice_insights(sessions): return false
	var stage: int = int(actor["stage"])
	if stage > 0 and (actor["energy"] < config["energy_thresholds"][stage - 1] or actor["mastery"] < config["mastery_thresholds"][stage - 1] or insights.size() < config["insight_thresholds"][stage - 1]): return false
	return true

static func _valid_materials(materials: Variant) -> bool:
	if not materials is Dictionary or materials.size() > 64: return false
	var seen: Dictionary = {}
	for resource_id: Variant in materials:
		if not (resource_id is String or resource_id is StringName) or not _stable_id(str(resource_id)) or not _integer(materials[resource_id], 0, BANK_LIMIT): return false
		if seen.has(str(resource_id)): return false
		seen[str(resource_id)] = true
	return true

static func _valid_origins(progress: Dictionary, materials: Dictionary) -> bool:
	var origins: Variant = progress.get("origins")
	var harvested: Variant = progress.get("harvested_nodes")
	if not origins is Dictionary or origins.size() > NODE_IDS.size() or not harvested is Array or harvested.size() != origins.size(): return false
	var seen: Dictionary = {}
	var counts: Dictionary = {"herb": 0, "pill": 0}
	var aptitude_by_actor: Dictionary = {PLAYER: 0, NPC: 0}
	for node_id: Variant in harvested:
		if node_id not in NODE_IDS or seen.has(node_id) or not origins.has(node_id) or not _node_occurs(progress, str(node_id)): return false
		seen[node_id] = true
	for origin_id: Variant in origins:
		if not seen.has(origin_id): return false
		var origin: Variant = origins[origin_id]
		if not _keys(origin, ["kind", "consumer", "consumed_lineage"]) or origin.get("kind") not in ["herb", "pill"] or not origin.get("consumer") is String or not origin.get("consumed_lineage") is String: return false
		if origin["consumer"].is_empty():
			if not origin["consumed_lineage"].is_empty(): return false
			counts[origin["kind"]] += 1
		elif not progress["actors"].has(origin["consumer"]) or origin["consumed_lineage"] != origin_id:
			return false
		else:
			aptitude_by_actor[origin["consumer"]] += int(progress["config"]["aptitude_gains"][origin["kind"]])
	for actor_id: String in progress["actors"]:
		if progress["actors"][actor_id]["aptitude"] != aptitude_by_actor[actor_id]: return false
	return int(materials.get("aptitude_herb", 0)) == counts["herb"] and int(materials.get("aptitude_pill", 0)) == counts["pill"]

static func node_available(progress: Variant, node_id: Variant) -> bool:
	# No resource mutation or random roll. Valid-state checking stays at the
	# proposal/common-codec boundary; presentation may query a detached snapshot.
	if not progress is Dictionary or node_id not in NODE_IDS or not _integer(progress.get("seed"), 0, LIMIT) or not _valid_config(progress.get("config")) or not progress.get("harvested_nodes") is Array: return false
	return not progress["harvested_nodes"].has(node_id) and _node_occurs(progress, str(node_id))

static func _node_occurs(progress: Dictionary, node_id: String) -> bool:
	var digest: String = (str(int(progress["seed"])) + "|" + node_id).sha256_text()
	var roll: int = digest.substr(0, 8).hex_to_int() % 10000
	return roll < int(progress["config"]["herb_occurrence_bps"])

static func propose(progress: Variant, materials: Variant, souls: Variant, proofs: Variant, kind: Variant, args: Variant, event_id: Variant) -> Dictionary:
	if not valid(progress, materials): return _failure("invalid_progress_or_materials")
	if not _integer(souls, 0, BANK_LIMIT) or not proofs is Dictionary or proofs.size() > 16: return _failure("invalid_souls_or_proofs")
	for proof_id: Variant in proofs:
		if not (proof_id is String or proof_id is StringName) or not _stable_id(str(proof_id)) or not _integer(proofs[proof_id], 0, BANK_LIMIT): return _failure("invalid_souls_or_proofs")
	if kind not in COMMANDS or not _valid_args(str(kind), args): return _failure("invalid_command_arguments")
	if not _event_id(event_id): return _failure("invalid_event_id")
	var arguments_hash: String = JSON.stringify(_normalize(args), "", true, true).sha256_text()
	var source_hash: String = source_fingerprint(progress,materials,souls,proofs)
	var event: Dictionary = {"id":event_id,"kind":kind,"arguments_sha256":arguments_hash}
	for receipt: Dictionary in progress["receipts"]:
		if receipt["id"] != event_id: continue
		if receipt["kind"] != kind or receipt["arguments_sha256"] != arguments_hash: return _failure("event_conflict")
		return _proposal_result(progress,materials,int(souls),true,source_hash,event,args)
	if progress["receipts"].size() >= MAX_RECEIPTS: return _failure("receipt_capacity_requires_review")
	var next: Dictionary = _normalize(progress)
	var bank: Dictionary = _normalize(materials)
	var request: Dictionary = _normalize(args)
	var error: String = ""
	var next_souls: int = int(souls)
	match str(kind):
		"observe": error = _observe(next, request["insight_id"])
		"mastery": error = _mastery(next)
		"train": error = _train(next, bank, request)
		"enroll": error = _enroll(next, request["enabled"])
		"breakthrough":
			error = _breakthrough(next, bank, int(souls), proofs, request["actor_id"])
			if error.is_empty() and next["actors"][request["actor_id"]]["stage"] == 3:
				next_souls -= int(next["config"]["final_soul_cost"])
		"harvest": error = _harvest(next, bank, request["node_id"])
		"craft_pill": error = _craft_pill(next, bank, request["origin_id"])
		"consume": error = _consume(next, bank, request["actor_id"], request["origin_id"])
	if not error.is_empty(): return _failure(error)
	next["revision"] += 1
	next["next_event"] += 1
	next["receipts"].append({"id": event_id, "kind": kind, "arguments_sha256": arguments_hash, "revision": next["revision"]})
	if not valid(next, bank) or not _integer(next_souls, 0, BANK_LIMIT): return _failure("proposal_invariant_failed")
	return _proposal_result(next,bank,next_souls,false,source_hash,event,args)

static func source_fingerprint(progress: Dictionary, materials: Dictionary, souls: int, proofs: Dictionary) -> String:
	return JSON.stringify(_normalize([progress,materials,souls,proofs]),"",true,true).sha256_text()

static func initial_proposal(progress: Dictionary, materials: Dictionary, souls: int, proofs: Dictionary) -> Dictionary:
	if not valid(progress,materials) or not _integer(souls,0,BANK_LIMIT) or not _valid_materials(proofs): return _failure("invalid_initialization")
	var fresh: Dictionary = new_progress(progress["seed"])
	fresh["config"]=progress["config"].duplicate(true)
	if _normalize(fresh)!=_normalize(progress): return _failure("initialization_requires_fresh_track")
	var request: Dictionary = {"seed":progress["seed"],"config":progress["config"].duplicate(true)}
	var event: Dictionary = {"id":"cultivation_init_v1","kind":"initialize","arguments_sha256":JSON.stringify(_normalize(request),"",true,true).sha256_text()}
	return _proposal_result(progress,materials,souls,false,source_fingerprint({},materials,souls,proofs),event,request)

static func _proposal_result(progress: Dictionary, materials: Dictionary, souls: int, replay: bool, source_hash: String, event: Dictionary, request: Dictionary) -> Dictionary:
	var result: Dictionary = _result(progress,materials,souls,replay)
	result.merge({"source_sha256":source_hash,"event":_normalize(event),"request":_normalize(request)})
	return result

static func _valid_args(kind: String, args: Variant) -> bool:
	match kind:
		"observe": return _keys(args, ["insight_id"]) and args["insight_id"] in OBSERVATIONS
		"mastery": return _keys(args, [])
		"train": return _keys(args, ["actor_id", "sessions", "target_tick"]) and args["actor_id"] in [PLAYER, NPC] and _integer(args["sessions"], 1, 8) and _integer(args["target_tick"], 0, LIMIT)
		"enroll": return _keys(args, ["enabled"]) and args["enabled"] is bool
		"breakthrough": return _keys(args, ["actor_id"]) and args["actor_id"] in [PLAYER, NPC]
		"harvest": return _keys(args, ["node_id"]) and args["node_id"] in NODE_IDS
		"craft_pill": return _keys(args, ["origin_id"]) and args["origin_id"] in NODE_IDS
		"consume": return _keys(args, ["actor_id", "origin_id"]) and args["actor_id"] in [PLAYER, NPC] and args["origin_id"] in NODE_IDS
	return false

static func _observe(progress: Dictionary, insight_id: String) -> String:
	var actor: Dictionary = progress["actors"][PLAYER]
	if actor["insight_ids"].has(insight_id): return "insight_already_observed"
	actor["insight_ids"].append(insight_id)
	return ""

static func _mastery(progress: Dictionary) -> String:
	var actor: Dictionary = progress["actors"][PLAYER]
	if actor["mastery"] >= LIMIT: return "mastery_capacity_requires_review"
	actor["mastery"] += 1
	return ""

static func _train(progress: Dictionary, materials: Dictionary, args: Dictionary) -> String:
	var actor_id: String = args["actor_id"]
	if not progress["actors"].has(actor_id): return "actor_not_found"
	var actor: Dictionary = progress["actors"][actor_id]
	var config: Dictionary = progress["config"]
	var sessions: int = args["sessions"]
	var target_tick: int = args["target_tick"]
	var trained_ticks: int = sessions * int(config["training_session_ticks"])
	if not actor["enrolled"]: return "actor_not_enrolled"
	if actor["stage"] >= 3: return "stage_complete"
	if sessions > config["max_train_sessions"] or (actor_id == NPC and sessions > actor["sessions_left"]): return "training_session_budget"
	if target_tick < maxi(int(progress["gameplay_tick"]), int(actor["last_train_tick"])) + trained_ticks: return "insufficient_gameplay_ticks"
	var cost: int = sessions * int(config["training_cost"])
	if int(materials.get("crystal", 0)) < cost: return "training_resource_required"
	var fixed_gain: int = sessions * int(config["training_gain"]) * (10000 + int(actor["aptitude"]) * int(config["aptitude_rate_bps"])) + int(actor["remainder"])
	var gain: int = int(fixed_gain / 10000.0)
	if actor["energy"] > LIMIT - gain or actor["trained_ticks"] > LIMIT - trained_ticks or (actor_id == NPC and actor["mastery"] > LIMIT - sessions): return "training_capacity_requires_review"
	materials["crystal"] = int(materials.get("crystal", 0)) - cost
	actor["energy"] += gain
	actor["remainder"] = fixed_gain % 10000
	actor["trained_ticks"] += trained_ticks
	# Accepted adapter input already proves eligible pulses. Discard any earlier
	# gap; there is no offline or retroactive catchup backlog in this track.
	actor["last_train_tick"] = target_tick
	progress["gameplay_tick"] = target_tick
	if actor_id == NPC:
		actor["sessions_left"] -= sessions
		actor["mastery"] += sessions
		actor["insight_ids"] = _practice_insights(int(float(actor["trained_ticks"]) / float(config["training_session_ticks"])))
	return ""

static func _practice_insights(sessions: int) -> Array:
	var insights: Array = []
	for index: int in NPC_INSIGHTS.size():
		if sessions >= [1, 3, 5][index]: insights.append(NPC_INSIGHTS[index])
	return insights

static func _enroll(progress: Dictionary, enabled: bool) -> String:
	if not progress["actors"].has(NPC):
		if not enabled: return "actor_not_found"
		progress["actors"][NPC] = _new_actor(NPC)
	var actor: Dictionary = progress["actors"][NPC]
	if enabled and actor["stage"] >= 3: return "stage_complete"
	actor["enrolled"] = enabled
	actor["sessions_left"] = int(progress["config"]["max_npc_sessions"]) if enabled else 0
	return ""

static func _breakthrough(progress: Dictionary, materials: Dictionary, souls: int, proofs: Dictionary, actor_id: String) -> String:
	if not progress["actors"].has(actor_id): return "actor_not_found"
	var actor: Dictionary = progress["actors"][actor_id]
	var config: Dictionary = progress["config"]
	var stage: int = actor["stage"]
	if not actor["enrolled"]: return "actor_not_enrolled"
	if stage >= 3: return "stage_complete"
	if actor["energy"] < config["energy_thresholds"][stage]: return "energy_required"
	if actor["mastery"] < config["mastery_thresholds"][stage]: return "mastery_required"
	if actor["insight_ids"].size() < config["insight_thresholds"][stage]: return "insight_required"
	var dust_cost: int = int(config["final_dust_cost"] if stage == 2 else config["interim_dust_cost"])
	if int(materials.get("dust", 0)) < dust_cost: return "breakthrough_resource_required"
	if stage == 2:
		if int(proofs.get("golem", 0)) < config["final_golem_proof"]: return "golem_proof_required"
		if souls < config["final_soul_cost"]: return "souls_required"
	materials["dust"] = int(materials.get("dust", 0)) - dust_cost
	actor["stage"] += 1 # Cumulative energy/mastery/insight remain earned.
	return ""

static func _harvest(progress: Dictionary, materials: Dictionary, node_id: String) -> String:
	if not node_available(progress, node_id): return "node_unavailable"
	if int(materials.get("aptitude_herb", 0)) >= BANK_LIMIT: return "material_capacity_requires_review"
	progress["harvested_nodes"].append(node_id)
	progress["origins"][node_id] = {"kind": "herb", "consumer": "", "consumed_lineage": ""}
	materials["aptitude_herb"] = int(materials.get("aptitude_herb", 0)) + 1
	return ""

static func _craft_pill(progress: Dictionary, materials: Dictionary, origin_id: String) -> String:
	if not progress["origins"].has(origin_id): return "origin_not_found"
	var origin: Dictionary = progress["origins"][origin_id]
	if origin["kind"] != "herb" or not origin["consumer"].is_empty(): return "unconsumed_herb_required"
	var cost: int = int(progress["config"]["pill_dust_cost"])
	if int(materials.get("dust", 0)) < cost: return "pill_resource_required"
	if int(materials.get("aptitude_pill", 0)) >= BANK_LIMIT: return "material_capacity_requires_review"
	materials["dust"] = int(materials.get("dust", 0)) - cost
	materials["aptitude_herb"] = int(materials.get("aptitude_herb", 0)) - 1
	materials["aptitude_pill"] = int(materials.get("aptitude_pill", 0)) + 1
	origin["kind"] = "pill" # Preserve the node lineage through conversion.
	return ""

static func _consume(progress: Dictionary, materials: Dictionary, actor_id: String, origin_id: String) -> String:
	if not progress["actors"].has(actor_id): return "actor_not_found"
	if not progress["origins"].has(origin_id): return "origin_not_found"
	var origin: Dictionary = progress["origins"][origin_id]
	if not origin["consumer"].is_empty(): return "origin_already_consumed"
	var actor: Dictionary = progress["actors"][actor_id]
	var gain: int = int(progress["config"]["aptitude_gains"][origin["kind"]])
	if actor["aptitude"] > LIMIT - gain: return "aptitude_capacity_requires_review"
	var proposal_cap: int = int(progress["config"]["aptitude_cap"])
	if proposal_cap >= 0 and actor["aptitude"] > proposal_cap - gain: return "aptitude_capacity_requires_review"
	var material_id: String = "aptitude_" + str(origin["kind"])
	if int(materials.get(material_id, 0)) < 1: return "aptitude_item_required"
	materials[material_id] = int(materials.get(material_id, 0)) - 1
	actor["aptitude"] += gain
	origin["consumer"] = actor_id
	origin["consumed_lineage"] = origin_id
	return ""

static func _result(progress: Dictionary, materials: Dictionary, souls: int, already_committed: bool) -> Dictionary:
	return {"ok": true, "progress": _normalize(progress), "materials": _normalize(materials), "souls": souls, "already_committed": already_committed}

static func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}

static func _keys(data: Variant, expected: Array) -> bool:
	if not data is Dictionary or data.size() != expected.size(): return false
	for key: Variant in data:
		if not key is String or key not in expected: return false
	return true

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high

static func _stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64: return false
	for letter: String in value:
		if letter not in "abcdefghijklmnopqrstuvwxyz0123456789_": return false
	return true

static func _event_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 128: return false
	for letter: String in value:
		if letter not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_:-/.": return false
	return true

static func _hex_digest(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for letter: String in value:
		if letter not in "0123456789abcdef": return false
	return true

static func _normalize(value: Variant) -> Variant:
	# All callers validate the bounded scalar/container shape first. JSON loads
	# integral numbers as floats; restore integers for canonical receipt hashes.
	if value is Dictionary:
		var copy: Dictionary = {}
		for key: Variant in value: copy[str(key)] = _normalize(value[key])
		return copy
	if value is Array:
		var copy: Array = []
		for entry: Variant in value: copy.append(_normalize(entry))
		return copy
	if value is float: return int(value)
	if value is StringName: return str(value)
	return value

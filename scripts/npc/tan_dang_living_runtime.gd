class_name TanDangLivingRuntime
extends Node
## Local representation of Lâm's finite journey and the physical P01 encounter.
## NpcWorldState owns every durable phase/life/memory bit; no second save.

const LAM: String = TanDangLivingCatalog.LAM
const HUB: String = TanDangLivingCatalog.HUB
const P01: String = TanDangLivingCatalog.P01
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/tan_dang_living_slime.tscn")
const REPORT_SECONDS: float = 3.0
const GREET_SECONDS: float = 3.0
const GREET_RADIUS: float = 140.0
const SLIME_X: float = 585.0

var hub: ExteriorHub
var population: NpcPopulation
var progress: TanDangProgress
var enemy: TanDangLivingSlime
var _heard_clock: Dictionary[String,float] = {}
var _heard_notice_clock: Dictionary[String,float] = {}
var _greet_clock: Dictionary[String,float] = {}
var _greet_reason: Dictionary[String,String] = {}
var _death_pending: int = 0

func initialize(owner: ExteriorHub, residents: NpcPopulation, journey: TanDangProgress) -> void:
	hub = owner
	population = residents
	progress = journey
	hub.zone_changed.connect(_zone_changed)
	_zone_changed(&"")

func _zone_changed(_region: StringName) -> void:
	_heard_clock.clear()
	_heard_notice_clock.clear()
	_greet_clock.clear()
	_greet_reason.clear()
	_death_pending = 0
	if is_instance_valid(population):
		for id: String in [TanDangLivingCatalog.MOC,TanDangLivingCatalog.DU]:
			var listener: CultivatorActor = population.actors.get(id) as CultivatorActor
			if is_instance_valid(listener): listener.living_hint = ""
		for id: String in NpcPilotCatalog.TAN_DANG_IDS:
			var resident: CultivatorActor = population.actors.get(id) as CultivatorActor
			if is_instance_valid(resident): resident.greeting_hint = ""
	# ExteriorHub owns old-room disposal. Never carry an encounter object into
	# another room; unresolved danger can spawn afresh only on active P01.
	if not is_instance_valid(enemy) or not is_instance_valid(hub.exterior) or enemy.get_parent() != hub.exterior: enemy = null

func _active_room() -> String:
	if not is_instance_valid(hub): return ""
	return String(hub.exterior.room_id) if hub.outside and is_instance_valid(hub.exterior) else HUB

func _playing() -> bool:
	return is_instance_valid(hub) and is_instance_valid(hub.player) and hub.player.controls_enabled and not hub.station_open and not hub.dialogue.is_open and not hub.gear.modal.is_open and not get_tree().paused

func _process(delta: float) -> void:
	if not is_instance_valid(population) or not is_instance_valid(progress) or not progress.available():
		_suspend_for_owner_lock()
		return
	var life: NpcWorldState = population.state
	if life.read_only or life.compound_locked or not life.records.has(LAM):
		_suspend_for_owner_lock()
		return
	var playing: bool = _playing()
	if is_instance_valid(enemy):
		enemy.ai_enabled = playing and is_instance_valid(hub.exterior) and enemy.get_parent() == hub.exterior and hub.exterior.room_id == StringName(P01)
		if not enemy.ai_enabled: enemy.suspend_encounter()
	if not playing:
		_clear_listeners()
		_clear_greetings()
		return
	var room: String = _active_room()
	var view: Dictionary = life.living_view(LAM)
	var phase: String = str(view.get("event_phase","none"))
	if phase == "none" and progress.state()["rewards"].has("q3") and progress.alive(LAM):
		if life.start_living_event(progress.state()): view = life.living_view(LAM); phase = str(view.get("event_phase","none"))
	# A player injury or a failed defense can move the durable owner out of
	# danger between frames. Stop the local duel before the return walk begins.
	if phase != "danger" and _current_enemy():
		enemy.resident = null
		var retreating: CultivatorActor = population.actors.get(LAM) as CultivatorActor
		if is_instance_valid(retreating): retreating.stop_living_defense()
	if phase == "outbound" and room == HUB and float(life.records[LAM]["x"]) <= 751.0:
		if life.transfer_lam(P01): population.refresh_actors()
	elif phase == "collecting" and room == P01 and float(life.records[LAM]["x"]) >= 495.0 and int(life.records[LAM]["remaining"]) == 0:
		life.advance_living_event(LAM,"collecting","danger")
	elif phase == "danger" and room == P01:
		_tick_danger(delta)
	elif phase == "returning" and room == P01 and float(life.records[LAM]["x"]) <= 151.0:
		if life.transfer_lam(HUB): population.refresh_actors()
	if room == HUB: _tick_listeners(delta)
	_tick_greetings(delta,room)

func _suspend_for_owner_lock() -> void:
	# A failed/quarantined owner cannot authorize another physical contact.
	# Stop only transient actors; do not write a provisional finite result.
	if is_instance_valid(enemy):
		enemy.ai_enabled = false
		enemy.suspend_encounter()
	if not is_instance_valid(population): return
	var defender: CultivatorActor = population.actors.get(LAM) as CultivatorActor
	if is_instance_valid(defender): defender.stop_living_defense()
	_clear_listeners()
	_clear_greetings()

func _tick_danger(delta: float) -> void:
	var life: NpcWorldState = population.state
	var actor: CultivatorActor = population.actors.get(LAM) as CultivatorActor
	if not is_instance_valid(actor) or not is_instance_valid(hub.exterior) or actor.get_parent() != hub.exterior: return
	if life.records[LAM]["mode"] in ["talk","downed","recovering","dead"]: return
	if life.living_view(LAM).get("event_phase","")!="danger": return
	# A saved completed horizon does not require spawning another threat. Failed
	# result commits retain elapsed=35 and suspend contact until a retry succeeds.
	if float(life.living_view(LAM)["danger_elapsed"])>=TanDangLivingState.DANGER_HORIZON:
		_withdraw_at_horizon(actor)
		return
	if not _current_enemy():
		_spawn_enemy(actor)
		if not _current_enemy(): return
	# The active, playable encounter has a finite retreat horizon even when a
	# player draws the threat past Lâm's leash. Pauses and off-room scenes never
	# call this tick, so they do not consume that horizon.
	if not life.advance_living_danger(delta): return
	if float(life.living_view(LAM)["danger_elapsed"])>=TanDangLivingState.DANGER_HORIZON:
		_withdraw_at_horizon(actor)
		return
	var danger_distance: float = actor.global_position.distance_to(enemy.global_position)
	if danger_distance > 300.0: return
	var actor_hp: float = float(life.records[LAM]["hp"])
	var attack: Dictionary = CultivatorCatalog.definition(LAM)
	var windows: int = 2 if attack.get("pattern","") == "double_cut" else 1
	var actor_damage: float = float(attack["damage"])*float(windows)
	var survives: int = ceili(actor_hp/TanDangLivingSlime.BITE_DAMAGE)
	var needed: int = ceili(enemy.health.current_health/maxf(1.0,actor_damage))
	if survives < maxi(2,ceili(float(needed)*0.55)):
		if life.resolve_living_event(LAM,"withdrew"):
			actor.stop_living_defense()
			enemy.resident = null
		return
	if actor.combat_phase == "idle": actor.request_living_defense(enemy)

func _withdraw_at_horizon(actor: CultivatorActor) -> void:
	actor.stop_living_defense()
	if _current_enemy():
		enemy.ai_enabled = false
		enemy.suspend_encounter()
	if population.state.resolve_living_event(LAM,"withdrew") and _current_enemy(): enemy.resident = null

func _spawn_enemy(actor: CultivatorActor) -> void:
	var room: ExteriorRoom = hub.exterior
	if not is_instance_valid(room) or room.room_id != StringName(P01) or room.route_id != ExteriorRouteCatalog.MAIN: return
	var created: TanDangLivingSlime = SLIME_SCENE.instantiate() as TanDangLivingSlime
	if created == null: return
	created.position = Vector2(SLIME_X,room.floor_y(SLIME_X))
	created.player = hub.player
	created.resident = actor
	created.combat_feedback = hub.feedback
	room.add_child(created)
	# The ordinary runtime attaches this existing painted skin after the enemy
	# enters the tree. Keep the event-local enemy visually identical to it.
	var skin := SlimeSpriteSkin.new()
	skin.name = "SlimeSpriteSkin"
	created.add_child(skin)
	enemy = created
	created.hurtbox.hit_resolved.connect(_enemy_hit)
	created.health.died.connect(_enemy_died)
	created.tree_exiting.connect(_enemy_left.bind(created.get_instance_id()),CONNECT_ONE_SHOT)

func _enemy_hit(event: DamageEvent, result: DamageResult) -> void:
	if not _current_enemy() or not is_instance_valid(hub.player) or result.blocked or result.actual_damage <= 0.0: return
	if event.target_id != enemy.get_instance_id() or event.source_id != hub.player.get_instance_id() or event.source_team_id != hub.player.hurtbox.team_id: return
	population.state.credit_living_help(LAM)

func _enemy_died() -> void:
	# Health.died precedes Hurtbox.hit_resolved for a killing blow. Resolve on
	# the deferred boundary so an accepted player final hit can be credited.
	if not _current_enemy() or _death_pending != 0: return
	_death_pending = enemy.get_instance_id()
	_finalize_enemy_death.call_deferred(_death_pending)

func _finalize_enemy_death(id: int) -> void:
	if _death_pending != id: return
	_death_pending = 0
	if not _current_enemy() or enemy.get_instance_id() != id or not is_instance_valid(population) or not population.state.records.has(LAM): return
	var actor: CultivatorActor = population.actors.get(LAM) as CultivatorActor
	if is_instance_valid(actor): actor.stop_living_defense()
	var view: Dictionary = population.state.living_view(LAM)
	if view.get("event_phase","") != "danger": return
	population.state.resolve_living_event(LAM,"helped" if bool(view.get("help_credited",false)) else "self")

func _current_enemy() -> bool:
	return is_instance_valid(enemy) and is_instance_valid(hub) and is_instance_valid(hub.exterior) and _active_room() == P01 and enemy.get_parent() == hub.exterior

func _enemy_left(id: int) -> void:
	if is_instance_valid(enemy) and enemy.get_instance_id() == id: enemy = null

func _tick_listeners(delta: float) -> void:
	var life: NpcWorldState = population.state
	var view: Dictionary = life.living_view(LAM)
	if view.get("event_phase","") not in ["returning","done"]: _clear_listeners(); return
	var source: CultivatorActor = population.actors.get(LAM) as CultivatorActor
	if not _calm(source): _clear_listeners(); return
	for id: String in [TanDangLivingCatalog.MOC,TanDangLivingCatalog.DU]:
		var known: Dictionary = life.living_view(id)
		var listener: CultivatorActor = population.actors.get(id) as CultivatorActor
		if bool(known.get("heard_materials",false)):
			_heard_clock.erase(id)
			if _heard_notice_clock.has(id) and _calm(listener):
				_heard_notice_clock[id] = maxf(0.0,_heard_notice_clock[id]-minf(delta,0.1))
				listener.living_hint = "Đã nghe Lâm kể chuyện mảnh phù"
				if _heard_notice_clock[id] <= 0.0:
					_heard_notice_clock.erase(id)
					listener.living_hint = ""
			else:
				_heard_notice_clock.erase(id)
				if is_instance_valid(listener): listener.living_hint = ""
			continue
		if not _calm(listener) or source.get_parent() != listener.get_parent() or source.global_position.distance_to(listener.global_position) > 160.0 or not source._clear_line(source.global_position+Vector2(0,-26),listener.global_position+Vector2(0,-26)):
			_heard_clock.erase(id)
			if is_instance_valid(listener): listener.living_hint = ""
			continue
		_heard_clock[id] = float(_heard_clock.get(id,0.0))+minf(delta,0.1)
		listener.living_hint = "Nghe Lâm kể chuyện mảnh phù · %.1f / 3 giây" % _heard_clock[id]
		if _heard_clock[id] < REPORT_SECONDS: continue
		if life.report_living_event(id):
			_heard_notice_clock[id] = 3.0
			listener.living_hint = "Đã nghe Lâm kể chuyện mảnh phù"
		_heard_clock.erase(id)

func _clear_listeners() -> void:
	_heard_clock.clear()
	for id: String in [TanDangLivingCatalog.MOC,TanDangLivingCatalog.DU]:
		var listener: CultivatorActor = population.actors.get(id) as CultivatorActor
		if is_instance_valid(listener): listener.living_hint = ""

func _tick_greetings(delta: float, room: String) -> void:
	var life: NpcWorldState = population.state
	var story: Dictionary = progress.state()
	for id: String in NpcPilotCatalog.TAN_DANG_IDS:
		var actor: CultivatorActor = population.actors.get(id) as CultivatorActor
		var reason: String = _greeting_reason(id,story,life) if is_instance_valid(actor) else ""
		var close: bool = not reason.is_empty() and _calm(actor) and actor._rest_reason_remaining <= 0.0 and life.records[id]["room"] == room and actor.global_position.distance_to(hub.player.global_position) <= GREET_RADIUS and actor._clear_line(actor.global_position+Vector2(0,-26),hub.player.global_position+Vector2(0,-26))
		if not close:
			_greet_clock.erase(id)
			_greet_reason.erase(id)
			if is_instance_valid(actor): actor.greeting_hint = ""
			continue
		if _greet_reason.get(id,"") != reason:
			_greet_reason[id] = reason
			_greet_clock[id] = 0.0
		var line: String = _greeting_line(id,reason)
		actor.greeting_hint = line
		# A receipt follows the visible caption, never a memory getter or an
		# occluded/rest/combat hint that the player never had a chance to read.
		if not actor.is_visible_in_tree() or not actor.caption.is_visible_in_tree() or not actor.caption.text.contains(line): continue
		_greet_clock[id] = float(_greet_clock.get(id,0.0))+minf(delta,0.1)
		if _greet_clock[id] < GREET_SECONDS: continue
		if life.mark_living_greeted(id,reason):
			_greet_clock.erase(id)
			_greet_reason.erase(id)

func _greeting_reason(id: String, story: Dictionary, life: NpcWorldState) -> String:
	if not life.records.has(id) or life.records[id]["causality"]["harmed"] or not life.karma(id)["grievance"].is_empty(): return ""
	var view: Dictionary = life.living_view(id)
	var ack: Dictionary = view.get("acknowledged",{})
	if not bool(ack.get("quest_help",false)) and bool(view.get("quest_help",false)):
		if id == TanDangLivingCatalog.DU and story["choice"] == "rescue": return "quest_help"
		if id == LAM and story["choice"] == "rescue" and life.karma(TanDangLivingCatalog.DU)["rescued"]: return "quest_help"
		if id == TanDangLivingCatalog.MOC and story["choice"] == "gate" and story["core"] == "installed": return "quest_help"
	if id == LAM and not bool(ack.get("forage_help",false)) and bool(view.get("forage_help",false)): return "forage_help"
	return ""

func _greeting_line(id: String, reason: String) -> String:
	if reason == "forage_help": return "Anh đã ra tay lúc em gặp nguy. Em nhớ."
	match id:
		TanDangLivingCatalog.MOC: return "Ngươi đem lõi về giữ cổng. Ta nhớ."
		TanDangLivingCatalog.LAM: return "Anh đã chọn cứu Dư. Em nhớ."
		TanDangLivingCatalog.DU: return "Ngươi đã cứu ta ở chỗ trú. Ta nhớ."
	return ""

func _clear_greetings() -> void:
	_greet_clock.clear()
	_greet_reason.clear()
	for id: String in NpcPilotCatalog.TAN_DANG_IDS:
		var actor: CultivatorActor = population.actors.get(id) as CultivatorActor
		if is_instance_valid(actor): actor.greeting_hint = ""

func _calm(actor: CultivatorActor) -> bool:
	return is_instance_valid(actor) and actor.is_inside_tree() and actor.combat_phase == "idle" and actor.world_state.records[actor.stable_id]["mode"] not in ["talk","dead","downed","recovering"]

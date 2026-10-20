class_name OpeningRewardNotice
extends CanvasLayer
## Ephemeral, mouse-pass-through receipt display. Durable owners remain unchanged.
var profile: SanctuaryProfile
var context_provider: Callable
var panel: PanelContainer
var item_icon: TextureRect
var title: Label
var body: Label
var pending: Array[Dictionary]=[]
var seen: Dictionary={}
var displayed: Array[StringName]=[]
var stamp: String=""
var remaining: float=0
var last_usec: int=0

func initialize(source: SanctuaryProfile,provider: Callable) -> void:
	profile=source;context_provider=provider
	stamp=OpeningRewardCatalog.receipt_stamp(profile)
	for entry: Dictionary in OpeningRewardCatalog.received(profile,_context().get("inventory")):seen[entry["id"]]=true
	profile.changed.connect(_committed)
	layer=34;process_mode=Node.PROCESS_MODE_ALWAYS
	panel=PanelContainer.new();panel.name="ReceivedReward";add_child(panel);AntiqueSkin.apply_panel(panel)
	var line:=HBoxContainer.new();line.add_theme_constant_override("separation",8);panel.add_child(line)
	item_icon=TextureRect.new();item_icon.custom_minimum_size=Vector2(32,32);item_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;item_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;line.add_child(item_icon)
	var copy:=VBoxContainer.new();copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(copy)
	title=_label(14);title.add_theme_color_override("font_color",AntiqueSkin.JADE);copy.add_child(title)
	body=_label(12);copy.add_child(body)
	for control: Control in [panel,line,item_icon,copy,title,body]:control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.hide();set_process(false)

func _label(size: int) -> Label:
	var text:=Label.new();text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.add_theme_font_size_override("font_size",size);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;return text

func _context() -> Dictionary:return context_provider.call() if context_provider.is_valid() else {}

func _committed() -> void:
	# Mastery/ordinary wallet changes do not rescan historical receipts or build UI.
	var current: String=OpeningRewardCatalog.receipt_stamp(profile)
	if current==stamp:return
	if not profile.last_save_ok:return
	stamp=current
	for entry: Dictionary in OpeningRewardCatalog.received(profile,_context().get("inventory")):
		if seen.has(entry["id"]):continue
		seen[entry["id"]]=true;entry["receipt"]=true;_enqueue(entry)

func acquired(pickup: LootPickup) -> void:
	var inventory: GearInventory=_context().get("inventory")
	if inventory==null or not pickup.collected_once:return
	var entry: Dictionary=OpeningRewardCatalog.pickup(pickup,profile,inventory);entry["receipt"]=false;entry["material_id"]=pickup.item_id;_enqueue(entry)

func _enqueue(entry: Dictionary) -> void:
	if not entry["receipt"]:
		for queued: Dictionary in pending:
			if not queued["receipt"] and queued["name"]==entry["name"] and queued["destination"]==entry["destination"]:
				queued["amount"]+=entry["amount"];queued["balance"]=entry["balance"];return
	if pending.size()>=6:
		var index: int=-1
		for i: int in pending.size():
			if not pending[i]["receipt"] and pending[i].get("material_id",&"")!=&"crystal":index=i;break
		if index>=0:pending.remove_at(index)
		elif not entry["receipt"]:return
	pending.append(entry);last_usec=Time.get_ticks_usec();set_process(true)

func _process(_delta: float) -> void:
	var now: int=Time.get_ticks_usec();var elapsed: float=float(now-last_usec)/1000000.0;last_usec=now
	var context: Dictionary=_context()
	if not context.get("safe",false):panel.hide();return
	var extent: Vector2=get_viewport().get_visible_rect().size
	panel.custom_minimum_size.x=minf(340,extent.x*.42);panel.size.x=panel.custom_minimum_size.x;panel.position=Vector2(extent.x-panel.size.x-12,116)
	if remaining>0:
		if panel.visible:remaining-=elapsed
		panel.show()
		if remaining>0:return
		panel.hide()
	if pending.is_empty():remaining=0;set_process(false);return
	var entry: Dictionary=pending.pop_front()
	item_icon.texture=entry["icon"];title.text="ĐÃ NHẬN · %s ×%d"%[entry["name"],entry["amount"]]
	body.text="%s\n%s"%[entry["destination"],entry["use"]]
	panel.tooltip_text=entry["balance"]
	remaining=4.5;displayed.append(entry["id"]);panel.show()
	if displayed.size()>16:displayed.pop_front()

func _exit_tree() -> void:
	if profile!=null and profile.changed.is_connected(_committed):profile.changed.disconnect(_committed)

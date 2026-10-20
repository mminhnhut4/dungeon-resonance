extends VBoxContainer
signal service_requested
const Guide = preload("res://scripts/ui/rune_preparation.gd")
var choice: OptionButton
var body: Label
var progress: Label
var sources: Label
var service_button: Button
var extra_button: Button
var last_view: Dictionary = {}
var _profile: SanctuaryProfile
var _inventory: GearInventory
var _service: RuneLearningService
var _offer_service: bool = false
func _ready() -> void:
	add_theme_constant_override("separation",8)
	_text(Guide.TITLE.to_upper()+" · TỰ CHỌN",18)
	choice=OptionButton.new();choice.name="PreparationRuneChoice";choice.custom_minimum_size.y=36;choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;choice.fit_to_longest_item=false;add_child(choice);choice.item_selected.connect(_selected)
	body=_text("",15);body.name="PreparationBody"
	progress=_text("",14);progress.name="PreparationProgress"
	sources=_text("",14);sources.name="PreparationSources"
	extra_button=Button.new();extra_button.name="PreparationExtra";extra_button.text="Tự chọn chế thêm một bùa · Trả đủ chi phí";extra_button.custom_minimum_size.y=36;add_child(extra_button);extra_button.pressed.connect(func()->void:Guide.prepare_extra(_profile);present(_profile,_inventory,_service,_offer_service))
	_text("Nhận được: bùa đang có hoặc bùa chế đã trả giá và lưu. Không có thưởng thêm hay nút nhận lại.",14)
	_text(Guide.USE,14)
	service_button=Button.new();service_button.text="Thanh Vy · Học & chế bùa";service_button.name="PreparationOpenService";service_button.custom_minimum_size.y=36;add_child(service_button);service_button.pressed.connect(func()->void:service_requested.emit())
	var end:=Button.new();end.text="Kết thúc hướng dẫn / chọn lại";end.name="PreparationClear";add_child(end);end.pressed.connect(func()->void:Guide.choose(_profile,&"");present(_profile,_inventory,_service,_offer_service))
	_text("Hướng dẫn không ghi hoàn thành vĩnh viễn. Bùa đã dùng hoặc không còn giữ: có thể chọn lá khác hay kết thúc, không cần kiếm lại để nhận thưởng cũ.",13)
func _text(value: String, size: int) -> Label:
	var label:=Label.new();label.text=value;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.set_meta(&"debug_keep",true);label.add_theme_font_size_override("font_size",size);add_child(label);return label
func present(profile: SanctuaryProfile, inventory: GearInventory, service: RuneLearningService = null, offer_service: bool = false) -> void:
	_profile=profile;_inventory=inventory;_service=service;_offer_service=offer_service
	if choice==null:return
	last_view=Guide.view(profile,inventory,service)
	choice.clear();choice.add_item("Chọn bùa cho chuyến sau…");choice.set_item_metadata(0,&"")
	for option: Dictionary in last_view["options"]:
		choice.add_item(option["text"]);choice.set_item_metadata(choice.item_count-1,option["id"])
		if option["id"]==last_view["selected"]:choice.select(choice.item_count-1)
	choice.disabled=last_view["state"]=="unavailable"
	body.text=last_view["body"];progress.text=last_view["progress"];sources.text=last_view["sources"]
	progress.visible=not progress.text.is_empty();sources.visible=not sources.text.is_empty()
	service_button.visible=offer_service;service_button.disabled=last_view["state"]=="unavailable"
	extra_button.visible=last_view["state"]=="already_prepared"
func _selected(index: int) -> void:
	Guide.choose(_profile,StringName(choice.get_item_metadata(index)))
	present(_profile,_inventory,_service,_offer_service)

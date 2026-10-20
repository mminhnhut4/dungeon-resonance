extends GameFlow
## Scene-only adapter; all profile/return/crafting transactions stay in GameFlow.
var prototype_banner: Label
func _ready() -> void:
	if save_path_override.is_empty():
		save_path_override = "user://shattered-mine-prototype/profile.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path_override.get_base_dir()))
	super._ready()
	profile.set_meta(&"rune_preparation_mine",true)
	var layer := CanvasLayer.new()
	layer.layer = 18
	add_child(layer)
	var banner := Label.new()
	prototype_banner = banner
	banner.text = "BẢN THỬ MỎ · Save riêng · Cổng hầm ngục dẫn tới mỏ"
	banner.add_theme_font_size_override("font_size",15)
	banner.add_theme_color_override("font_color",Color("e3c788"))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(banner)
	get_viewport().size_changed.connect(_layout_banner)
	_layout_banner()

func _layout_banner() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	prototype_banner.position = Vector2(24,size.y-30)
	prototype_banner.size.x = maxf(100,size.x-48)

func start_run() -> void:
	# Both existing Hub departure buttons enter this sample, never legacy Alpha.
	start_campaign()

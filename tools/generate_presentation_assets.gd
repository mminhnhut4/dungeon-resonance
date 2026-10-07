extends SceneTree
## Original technical PNGs; no Aseprite CLI or third-party asset license needed.

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/presentation")
	var light := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y: int in 128:
		for x: int in 128:
			var radius: float = Vector2(x - 63.5, y - 63.5).length() / 64.0
			var strength: float = pow(maxf(0.0, 1.0 - radius), 1.8)
			light.set_pixel(x, y, Color(strength, strength, strength, 1.0))
	light.save_png("res://assets/presentation/light_radial.png")
	var spark := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y: int in 8:
		for x: int in 8:
			spark.set_pixel(x, y, Color(1, 1, 1, maxf(0.0, 1.0 - Vector2(x - 3.5, y - 3.5).length() / 4.0)))
	spark.save_png("res://assets/presentation/spark.png")
	var torch := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for frame: int in 4:
		var offset: int = frame * 16
		_rect(torch, offset + 6, 18, 5, 14, Color("4d3540"))
		_rect(torch, offset + 4, 22, 9, 3, Color("b1845d"))
		_rect(torch, offset + 4, 16, 9, 4, Color("44303e"))
		for y: int in range(2, 18):
			var width: int = maxi(1, int((y - 1) * 0.30))
			var center: int = 8 + int(sin(float(y + frame * 2)) * 1.5)
			_rect(torch, offset + center - width, y, width * 2, 1, Color("ed7139"))
			if y > 7:
				_rect(torch, offset + center - maxi(1, width - 2), y, maxi(2, width * 2 - 4), 1, Color("ffe598"))
	torch.save_png("res://assets/presentation/torch_atlas.png")
	var player := Image.create(24, 40, false, Image.FORMAT_RGBA8)
	_rect(player, 7, 3, 12, 11, Color("263c58"))
	_rect(player, 9, 6, 11, 7, Color("e8c499"))
	_rect(player, 15, 8, 5, 2, Color("bdedf5"))
	_rect(player, 5, 13, 15, 21, Color("572647"))
	_rect(player, 5, 13, 5, 21, Color("913b54"))
	_rect(player, 9, 13, 10, 4, Color("e9b87a"))
	_rect(player, 8, 19, 12, 9, Color("28394b"))
	_rect(player, 9, 27, 13, 3, Color("bb895e"))
	_rect(player, 8, 33, 5, 7, Color("283341"))
	_rect(player, 16, 33, 5, 7, Color("344454"))
	_rect(player, 19, 18, 4, 11, Color("edc991"))
	player.save_png("res://assets/presentation/player.png")
	print("PRESENTATION PNG ASSETS GENERATED")
	quit()

func _rect(target: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for row: int in range(y, mini(target.get_height(), y + height)):
		for col: int in range(x, mini(target.get_width(), x + width)):
			target.set_pixel(col, row, color)

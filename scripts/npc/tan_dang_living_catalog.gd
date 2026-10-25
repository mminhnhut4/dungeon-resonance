class_name TanDangLivingCatalog
extends RefCounted
## Authored, finite ground routes for the three Tàn Đăng residents.
## The life record remains in NpcWorldState; this catalog never stores progress.

const HUB: String = "h00_traveler_hub"
const P01: String = "o01_p01"
const P03: String = "o01_p03"
const MOC: String = "tan_dang_moc_yen"
const LAM: String = "tan_dang_lam_tuoc"
const DU: String = "tan_dang_du_hanh"

# x coordinates are on each room's main, continuous ground. An off-room actor
# does not tick. The Lâm expedition is selected by TanDangLivingRuntime after q3.
const ROUTES: Dictionary = {
	"tan_dang_moc_yen": {
		"h00_traveler_hub": {"bounds":Vector2(860.0,1030.0),"speed":32.0,"stops":[
			{"x":900.0,"mode":"work","ticks":12,"label":"Đối chiếu sổ Tàn Đăng"},
			{"x":1010.0,"mode":"work","ticks":10,"label":"Chỉnh lại đèn cổng"},
			{"x":940.0,"mode":"rest","ticks":8,"label":"Nghỉ cạnh sổ"}]}
	},
	"tan_dang_lam_tuoc": {
		"o01_p03": {"bounds":Vector2(1310.0,1500.0),"speed":38.0,"stops":[
			{"x":1345.0,"mode":"rest","ticks":8,"label":"Trông nom chiếc lõi"},
			{"x":1450.0,"mode":"work","ticks":10,"label":"Kiểm đường giữ đèn"}]},
		"h00_traveler_hub": {"bounds":Vector2(710.0,1400.0),"speed":42.0,"stops":[
			{"x":1345.0,"mode":"work","ticks":10,"label":"Vá lại mảnh phù cũ"},
			{"x":1260.0,"mode":"rest","ticks":8,"label":"Nghỉ cạnh đồ sửa phù"}]},
		"o01_p01": {"bounds":Vector2(120.0,700.0),"speed":42.0,"stops":[
			{"x":150.0,"mode":"rest","ticks":4,"label":"Nhìn lối về căn cứ"},
			{"x":480.0,"mode":"work","ticks":12,"label":"Tìm mảnh phù ven đường"},
			{"x":620.0,"mode":"work","ticks":8,"label":"Xem đá kê đèn"}]}
	},
	"tan_dang_du_hanh": {
		"o01_p03": {"bounds":Vector2(1360.0,1410.0),"speed":0.0,"stops":[
			{"x":1385.0,"mode":"rest","ticks":80,"label":"Dưỡng thương bên lõi"}]},
		"h00_traveler_hub": {"bounds":Vector2(1040.0,1400.0),"speed":30.0,"stops":[
			{"x":1385.0,"mode":"rest","ticks":14,"label":"Dưỡng thương"},
			{"x":1120.0,"mode":"work","ticks":12,"label":"Sửa đồ cũ"},
			{"x":1070.0,"mode":"work","ticks":9,"label":"Luyện bước chân nhẹ"}]}
	}
}

static func has_route(id: String, room: String) -> bool:
	return ROUTES.has(id) and (ROUTES[id] as Dictionary).has(room)

static func bounds(id: String, room: String) -> Vector2:
	if not has_route(id,room): return Vector2.ZERO
	return ROUTES[id][room]["bounds"]

static func speed(id: String, room: String) -> float:
	if not has_route(id,room): return 0.0
	return float(ROUTES[id][room]["speed"])

static func stops(id: String, room: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if has_route(id,room): result.assign(ROUTES[id][room]["stops"])
	return result.duplicate(true)

static func count(id: String, room: String) -> int:
	return (ROUTES[id][room]["stops"] as Array).size() if has_route(id,room) else 0

static func stop(id: String, room: String, index: int) -> Dictionary:
	if not has_route(id,room) or index < 0 or index >= count(id,room): return {}
	return (ROUTES[id][room]["stops"] as Array)[index].duplicate(true)

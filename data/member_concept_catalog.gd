class_name MemberConceptCatalog
extends RefCounted
## Authored foot anchors from the delivered single poses; source PNGs stay intact.
const MODELS: Dictionary={
"hanh":{"file":"Hanh.png","name":"Hạnh","foot":Vector2(560,1510),"height":70.0,"right":true},
"pilot_apprentice":{"file":"HocViec.png","name":"Học việc ở bến","foot":Vector2(560,1510),"height":67.0,"right":true},
"pilot_courier":{"file":"NguoiDuaTin.png","name":"Người đưa tin","foot":Vector2(540,1510),"height":70.0,"right":true},
"pilot_gatherer":{"file":"NguoiHaiThuoc.png","name":"Người hái thuốc","foot":Vector2(540,1515),"height":70.0,"right":true},
"thanh_van_steward_01":{"file":"PhungYenTruc.png","name":"Phùng Yên Trúc","foot":Vector2(560,1520),"height":73.0,"right":true},
"xich_lo_steward_01":{"file":"TongHongDiep.png","name":"Tống Hồng Diệp","foot":Vector2(560,1510),"height":73.0,"right":true},
"member_hellhound":{"file":"HellHound.png","name":"Ngục Khuyển","foot":Vector2(790,955),"height":62.0,"right":false},
"member_emperor":{"file":"GoldenSkeletonEmperor.png","name":"Kim Cốt Đế Vương","foot":Vector2(560,1480),"height":130.0,"right":false},
"member_jiangshi":{"file":"Jiangshi.png","name":"Cương Thi","foot":Vector2(650,1510),"height":83.0,"right":false},
"member_spider":{"file":"TalismanSpider.png","name":"Phù Văn Tri Chu","foot":Vector2(790,980),"height":77.0,"right":false},
"member_spiderling":{"file":"BabyTalismanSpider.png","name":"Nhện con","foot":Vector2(790,960),"height":32.0,"right":false}
}
static func definition(id: String) -> Dictionary:return MODELS.get(id,{}).duplicate(true)
static func path(id: String) -> String:return "res://assets/sprites/member_concepts/"+String(MODELS[id]["file"]) if MODELS.has(id) else ""

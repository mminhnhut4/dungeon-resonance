class_name MemberEncounterCatalog
extends RefCounted
## New placement authored24/10 after user requested it; not member source claims.
## Entries: archetype, spawn_x, actor/aggro lane_left/right. Ground y640.
## Clear is optional. No encounter on precision trap/rest floors.
const PLACEMENTS: Dictionary={
9:[[&"member_hellhound",540,480,590]],
10:[[&"member_jiangshi",680,635,735]],
11:[[&"member_spider",920,835,960]],
12:[[&"member_hellhound",535,475,595],[&"member_spiderling",1110,1030,1160]],
13:[],
14:[[&"member_jiangshi",750,710,790]],
15:[[&"member_emperor",840,740,935]],
16:[[&"member_spider",970,900,1030]],
17:[[&"member_hellhound",530,465,600],[&"member_jiangshi",900,835,965]],
18:[],
19:[[&"member_spider",1040,950,1160]],
20:[],
21:[[&"member_hellhound",1530,1440,1600]],
22:[],
23:[[&"member_spiderling",1320,1230,1395],[&"member_spiderling",1530,1450,1600]],
24:[[&"member_hellhound",620,550,675]],
25:[],26:[],27:[],
28:[[&"member_jiangshi",955,915,990]],
29:[[&"member_emperor",865,800,925]],
30:[]}
const NOTES: Dictionary={
9:"Giới thiệu Khuyển trên khoảng đá sạch sau bãi gai đầu.",10:"Giới thiệu nhảy Cương Thi giữa khối đá và tường nứt.",11:"Giới thiệu nhện/sinh con trên bãi đất sau gai.",12:"Hai nhịp cách xa: Khuyển rồi nhện con.",13:"Nghỉ giao chiến; tập nhảy chín nhịp.",14:"Một Cương Thi giữa hai bãi gai, leash không vượt bãi.",15:"Đế Vương đơn lẻ, mini-boss tùy chọn sau tường.",16:"Nhện trong khoảng trống giữa gai và tường.",17:"Hai encounter tách bởi khối đá; không kéo cả hai tới cổng.",18:"Tầng nghỉ Tâm Chuông, không quái.",19:"Nhện ở khoảng trống trước nhánh rương; lửa không bắt buộc.",20:"Khám phá/ngắm mưa, rương Hỏa tùy chọn.",21:"Khuyển ở vùng đất sau toàn bộ chuỗi lửa/gai.",22:"Chỉ gai lệch nhịp, không thêm quái vào cửa sổ chờ.",23:"Hai nhện con ở bờ đất chắc sau vực, không trên bệ sụp.",24:"Một Khuyển trong khoảng trống giữa hai phù trận.",25:"Chỉ bè/sông; bệ giữa là chỗ nghỉ.",26:"Chỉ chuông/lối trên, không đánh khi đang né chuông.",27:"Chỉ tổ hợp lửa/bệ sụp/chuông.",28:"Cương Thi dưới khoảng trống sau vách; không aggro khi còn trên bệ cao.",29:"Đế Vương đơn lẻ sau gai, trước tường; giữ vực/rương độc lập.",30:"Đài cuối dành cho tổ hợp bẫy, không ép boss trên lối hẹp."}
static func entries(number: int) -> Array:return PLACEMENTS.get(number,[]).duplicate(true)

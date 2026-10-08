# Cốt truyện và lộ trình tông môn — 08/10/2026

**Cập nhật triển khai sau18h:** bốn phòng `tv01_cloud_gate`, `tv02_pine_court`, `xl01_red_causeway`, `xl02_cooling_yard`, hai chấp sự và nhiệm vụ mở quyền khách đã được nối trong bản nghiệm thu. Đã ghép main525355d sau strict273/273, có backup/hash guard; xem hậu kiểm và giới hạn trong báo cáo tiếp tục. Xem [báo cáo hiện hành](SECT_MAPS_RESUME_20261008.md). Các phòng thứ ba, gia nhập, thuê người, báo tin/truy nã, công pháp và kế nhiệm bên dưới vẫn là thiết kế; phần nền tảng “chưa có map” phản ánh lúc soạn ban đầu.

**Đây là tài liệu thiết kế cho bước tiếp theo, chưa triển khai hệ tông môn đầy đủ.** Soạn trong private `sect-path-repair`, theo skill portable [godot-dungeon-dev](../.agents/skills/godot-dungeon-dev/SKILL.md). Phạm vi lần giao này chỉ là tài liệu; không đổi source, map, asset, save, không chạy engine. Ưu tiên hiện tại vẫn là hiệu năng, sửa lỗi và nghiệm thu những thay đổi đang có. Mốc 17:00 giờ Việt Nam ngày 08/10, tức 10:00 UTC, không phải cam kết hoàn thành các hệ thống lớn bên dưới.

## 1. Luật đã chốt và đề xuất sáng tạo

| Người dùng đã yêu cầu/chốt | Phần tài liệu này mới đề xuất |
|---|---|
| Có môn phái, bản đồ riêng, đệ tử, khiêu chiến để có thể làm chưởng môn; học tâm pháp và võ công của phái | Tên địa danh/nhân vật mới, nguyên nhân xung đột, từng nhiệm vụ, nghi thức kế nhiệm, số phòng, điều kiện danh vọng và phần thưởng cụ thể |
| Tu tiên; class do trang bị, bùa/cộng hưởng vẫn là tấn công chính | Một ô tâm pháp chủ động chọn trước chuyến, một võ công trên phím G; công pháp bổ trợ vị trí/nhịp đánh, không thay loadout bùa |
| Cá nhân bị đánh có thể tự vệ; cả phái chỉ biết qua nhân chứng/báo tin/bằng chứng | Thời gian mang tin, mức tin cậy, cấp phản ứng và cách hòa giải; cần playtest, chưa chốt số |
| Tự vệ trước người chủ động truy sát không tăng truy nã; đánh người đang rút lui là vụ gây hấn mới | Ranh giới AoE lỡ tay, cách báo cảnh cáo và cửa dừng giao tranh cụ thể |
| Mọi NPC chỉ trọng thương/rút lui, không chết vĩnh viễn; trở lại sau một chuyến hoàn tất hoặc quay về, giữ ký ức | Cách dàn cảnh cấp cứu, người nhận đơn thay, nhịp tái đấu và đối thoại sau trận |
| Thuê một người cho một chuyến; phí Linh Thạch cố định trả trước, không chia loot | Mức phí, hoàn phí khi về sớm, vai trò và điều kiện từ chối lệnh/rời đội |
| Làm sau các ưu tiên đang sửa; chưa kịp thì ghi lại | Các phase, API và file dự kiến bên dưới là kế hoạch triển khai, không phải tính năng đã nối |

Hai tên **Thanh Vân Môn** và **Xích Lô Phái**, cùng hai stable ID tuần tra, đã có trong lát cắt private. Các tên riêng khác trong tài liệu đều là đề xuất sáng tạo, cần review trước đưa vào nội dung chính. Không tự chốt damage, giá, ngưỡng quan hệ, thời lượng chương hoặc tỷ lệ thưởng.

## 2. Điểm nối với thế giới hiện hành

Nguồn nội bộ đã đối chiếu: [Project State](PROJECT_STATE.md), [Decisions](DECISIONS.md), [kiến trúc](PROJECT_ARCHITECTURE.md), [ngoại cảnh hiện có](EXTERIOR_FIRST_SLICE_20261002.md), [tiếp nối năm tầng](CONTINUATION_20261008.md), [hợp đồng nhân quả](SECT_CAUSALITY_DESIGN_20261008.md), [roadmap tu luyện](CULTIVATION_RUN_ROADMAP.md), [công pháp mở đầu](CULTIVATION_STYLES_CANDIDATE.md), [Map Guide](team/MAP_GUIDE.md), [Character Guide](team/CHARACTER_GUIDE.md), [Spell Guide](team/SPELL_GUIDE.md). Báo cáo cũ chỉ dùng cho định hướng; trạng thái nguồn mới và chỉ dẫn người dùng có ưu tiên.

Những mối nối có thật:

- H00 Căn Cứ Lữ Khách nối tuyến P01–P04 của Đường Hành Hương rồi B01–B04 của Bến Trầm. P03 có miếu và cơ cấu SC01, B03 có bưu trạm, B04 có xưởng Hạnh. Đây là địa lý/mốc hiện hữu, chưa tự chứng minh nguyên nhân lũ hoặc âm mưu tông môn.
- Thiết Lão, Thanh Vy, Vô Danh là dịch vụ/câu chuyện opening. Thanh Vy nói đến bùa bị oán khí ăn mòn; Vô Danh hướng người chơi vào lõi phù trận Golem. Không sửa họ thành người phát thưởng môn phái trùng owner hiện có.
- Lạc Ấn mở hành trình năm tầng sau Golem mở đầu. Tầng 4 đã mang tên **Xích Lô · Lò rèn phong ấn**, tầng 5 là U Minh Tháp. Tông môn trên mặt đất phải dùng room ID và tên hiển thị phân biệt rõ với tầng 4; không đổi `DepthFloorCatalog` hoặc tiến độ đã lưu chỉ để khớp cốt truyện mới.
- Hiện mới có hai tu sĩ tuần tra/tự vệ và vòng trọng thương–trở lại. Chưa có map tông môn, tư cách gia nhập, nhân chứng báo cả phái, thuê đồng hành, võ đài kế nhiệm hoặc tâm pháp riêng của phái.

**Mạch truyện đề xuất — “Hai lời thề giữ đường”:** các chuyến hàng mang vật liệu phù trận qua Bến Trầm bị sai dấu niêm. Thanh Vân cho rằng xưởng hạ lưu che giấu vật liệu nhiễm oán khí; Xích Lô cho rằng các trạm trên núi đánh dấu nhầm để giành quyền kiểm soát đường. Người chơi thấy cả hai lập luận thiếu một phần chứng cứ. Dấu niêm cũ dưới Ngũ Tầng giúp giải thích kỹ thuật đã thất truyền; Hạnh và Lạc Ấn là người giúp đối chiếu, không tự trở thành kẻ chủ mưu.

Nguyên nhân cuối đề xuất là hệ phù trận cũ mất đồng bộ và hồ sơ chuyển giao bị thất lạc. Một số người che sai sót vì sợ bị quy trách nhiệm, nhưng không định sẵn “một phái tốt, một phái xấu”. Tuyến đầu kết thúc bằng việc công khai bản ghi và sửa cách giám sát chung. Trở thành chưởng môn là nhánh trách nhiệm lâu dài mở sau đó, không phải phần thưởng bắt buộc để đi tầng tiếp theo.

## 3. Hai khu vực có bản sắc riêng

Các room ID dưới đây là **ID dự kiến**, chưa nằm trong catalog/validator. Cả hai nhánh dùng cửa và anchor thật, đi bộ được hai chiều bằng motor hiện có. Nhảy/dash chỉ dành cho đường thưởng tùy chọn; không thêm bay, leo thang, bơi hoặc nền chuyển động để ép topology.

| Phái | Biome, hình khối và cảm giác | Topology đề xuất | Điểm sinh hoạt và chiến đấu |
|---|---|---|---|
| **Thanh Vân Môn** | Núi đá nhạt, thông thưa, mây thấp; xanh ngọc/trắng xám, khoảng âm rộng. Cao độ đi lên theo sườn núi; kiến trúc nhẹ, sân thoáng cho kiếm giữ khoảng cách | Nhánh mới từ P03: `tv01_cloud_gate` Vân Quan → `tv02_pine_court` Tùng Đình → `tv03_oath_terrace` Đài Giữ Gió. Cửa nhánh không thay cửa SC01 hoặc anchor miếu cũ | Vân Quan tiếp khách/báo tin; Tùng Đình học và thuê; Đài Giữ Gió luận kiếm/kế nhiệm. Đường ngoài võ đài đủ rộng để nói chuyện, đi qua và rút lui |
| **Xích Lô Phái** | Lòng chảo đá đỏ và bãi sa khoáng, mái gốm thấp, kênh làm nguội lộ thiên; đỏ đất/đồng trầm/xanh nước. Trục ngang rộng, sân thấp và cầu cạn ngắn. Không sao chép hành lang lò rèn dưới tầng 4 | Nhánh mới từ B04: `xl01_red_causeway` Đê Đất Đỏ → `xl02_cooling_yard` Sân Dẫn Thủy → `xl03_foundry_court` Đình Giữ Lò | Đê Đất Đỏ nhận hàng/báo tin; Sân Dẫn Thủy học/thuê/bảo dưỡng; Đình Giữ Lò diễn võ/kế nhiệm. Hơi nước là trình diễn; chưa mặc định có damage vùng |

Lát cắt map đầu chỉ nên dựng Vân Quan và Tùng Đình với một vòng đi–về, một NPC tiếp nhận và một nhiệm vụ. Ba phòng mỗi phái là đích nội dung, không yêu cầu đồng thời dựng sáu phòng trước khi kiểm đầu tiên. Art mới cần pipeline và QA riêng; sprite tu sĩ hiện dùng prototype không được tự gọi là ngoại hình cuối của phái.

## 4. Dàn nhân vật và vai trò

| Phái | Nhân vật đề xuất | Vai trò và động cơ | Ràng buộc runtime/cốt truyện |
|---|---|---|---|
| Thanh Vân | **Kiều Vân Sinh**, đệ tử tuần tra | Muốn bảo vệ đường nhưng thường suy đoán sớm; dẫn người chơi đến Vân Quan, có thể được thuê khi đủ tín nhiệm | Chính là vai trò của `thanh_van_disciple_01`; nếu duyệt tên chỉ đổi nhãn, không sinh ID mới/xóa ký ức |
| Thanh Vân | **Phùng Yên Trúc**, chấp sự giữ sổ | Nhận lời khai, đối chiếu mốc giờ; quan tâm sự thật hơn thể diện phái | Nhận/giải thích báo cáo và tư cách khiêu chiến; không tự cộng tiền từ lời thoại |
| Thanh Vân | **Ninh Tố**, giáo tập | Dạy giữ nhịp, dừng đòn khi đối phương xin lui; phản đối thắng bằng truy sát | Dạy tâm pháp/võ công và chấm thử thách; có người tiếp nhận hồ sơ khi đang dưỡng thương |
| Thanh Vân | **Từ Hoài Sơn**, chưởng môn | Giỏi kiếm và giữ trật tự nhưng đã tin sổ cũ quá lâu; chấp nhận kế nhiệm có chứng cứ và nghi thức | Đấu có đồng thuận, không permadeath. Sau chuyển quyền vẫn có vai trò cố vấn và nhớ trận đấu |
| Xích Lô | **Đỗ Nham**, hộ vệ đường hàng | Nặng lời nhưng bảo vệ người yếu; biết các dấu móp trên hàng vận chuyển | Giữ `xich_lo_guard_01`; ứng viên đồng hành thiên bảo hộ/trọng đòn, không tự chặn mọi sát thương |
| Xích Lô | **Tống Hồng Diệp**, chấp sự kho lò | Phụ trách sổ vật liệu và người bị thương; muốn sửa sai thay vì bỏ xưởng | Nhận bằng chứng/đăng ký môn phái; không tạo kho vật liệu/writer thứ hai |
| Xích Lô | **Hứa An**, giáo tập dẫn thủy | Dạy nhường khoảng đứng và bảo vệ đường lui; nối kiến thức phù trận với lao động thường ngày | Dạy tâm pháp/võ công, nêu rõ hành vi hợp lệ khi thi đấu |
| Xích Lô | **Lâm Trọng Nghiêm**, chưởng môn | Sợ mất sinh kế nếu công khai lỗi nhưng chịu trách nhiệm trước chứng cứ | Có trận diễn võ và phiên chuyển giao. Thất bại không biến toàn phái thành địch |

Không cần spawn cả tám người cùng một phòng. NPC lịch/đối thoại/combat dùng owner phù hợp; không biến mọi NPC dịch vụ thành actor chiến đấu chỉ để đủ roster. Khi người nhận nhiệm vụ dưỡng thương, chấp sự hoặc bảng tiếp nhận trong cùng phái giữ đường nộp; không nhân bản nhân vật/UID để chống softlock.

## 5. Nhiệm vụ dẫn nhập và Thanh Vân

Phần thưởng ghi dưới là **quyền mở nội dung/hành vi đề xuất**. Giá, vật liệu và số thưởng chỉ được điền sau review economy. Cờ quest/mốc đã commit giữ sau thua; item đang mang trong dungeon vẫn theo luật mất đồ hiện hành. Không biến tài liệu này thành quyền phục hồi toàn bộ loot khi chết.

| ID dự kiến / nhiệm vụ | Mục tiêu và địa điểm | Điều kiện bắt đầu/hoàn tất | Phần thưởng một lần | Khi thua, rút lui hoặc ghi lỗi |
|---|---|---|---|---|
| `sect_intro_01` — Hai lời kể | Nói chuyện tuần tra P01 và P02; so lời khai tại bưu trạm B03 | Opening đã giới thiệu đường bộ; nghe đủ hai lời kể và đọc bản ghi đúng owner, không yêu cầu gây chiến | Journal mở hai nhánh, đánh dấu Vân Quan/Đê Đất Đỏ khi route được triển khai | Đối thoại hủy không commit; NPC dưỡng thương cho phép gửi lời hỏi tại đầu mối phái; không ép đánh để mở quest |
| `tv_01` — Đường phải còn người về | Đi P03→Vân Quan, xác nhận ba điểm cần giữ lối và trở về gặp Yên Trúc | Có lời giới thiệu; đến các marker bằng traversal thật, không lấy tọa độ tức thời làm bằng chứng | Quyền khách và tuyến vào Tùng Đình | Bỏ dở giữ các mốc đã commit, không thưởng trước; kẹt hình học phải sửa map, không chữa bằng teleport thưởng |
| `tv_02` — Dấu niêm ngược gió | Đối chiếu bản niêm tại miếu P03 và bản giao B03; trình hai bản cho chấp sự | Hoàn thành `tv_01`; hai nguồn khác nhau cùng chỉ một chuyến hàng | Quyền dự buổi học; mở thông tin nguyên nhân, chưa tăng truy nã phái khác | Không coi lời đồn là bằng chứng thủ phạm; chứng cứ quest đã ghi giữ, loot chưa về theo luật run |
| `tv_03` — Biết dừng kiếm | Đấu tập với Ninh Tố tại Tùng Đình: đọc tell, tạo khoảng và dừng khi đối phương xin lui | Đăng ký/đọc luật; accepted combat chứng minh hành vi, không đếm miss/callback giả | Tư cách đệ tử; quyền học tâm pháp đầu tiên, quyền đăng ký thử võ công | Thua chỉ kết thúc trận, không trừ quan hệ; không mất gear/quest trong trận huấn luyện. Ghi thưởng lỗi giữ trạng thái có thể nhận lại đúng một lần |
| `tv_04` — Bản ghi dưới phong ấn | Cùng tuyến Lạc Ấn đã mở, tìm bản khắc tại tầng 1 rồi mang thông tin về | Giữ gate Golem/DepthProgress hiện có; không mở tầng chỉ vì gia nhập | Quyền học biến thể võ công Thanh Vân và hồ sơ ứng viên tin cậy | Retreat không tự hoàn thành marker chưa lấy; không tặng Boss proof. Chứng cứ đã commit không cần farm lại, vật liệu run vẫn theo luật chung |
| `tv_05` — Một lời khai đầy đủ | Chọn công khai bằng chứng có lợi lẫn bất lợi cho phái tại Vân Quan; giải quyết vụ việc của chính mình nếu có | `tv_02`, `tv_04`; không còn incident nghiêm trọng chưa xét. Hòa giải gắn đúng incident, không mua xóa ký ức | Tư cách ứng viên luận kiếm; quyền thuê Vân Sinh khi hợp đồng được triển khai | Chưa đủ bằng chứng thì hồ sơ chờ bổ sung; sai lựa chọn có đường giải thích/sửa hồ sơ, không khóa vĩnh viễn cả tuyến |
| `tv_06` — Đài Giữ Gió | Đấu với Hoài Sơn theo luật đã xác nhận, sau đó nhận hoặc từ chối chuyển giao | Giáo tập xác nhận năng lực, chấp sự xác nhận hồ sơ; hai bên đồng thuận, đúng võ đài | Danh hiệu người thắng; nếu nhận chuyển giao và được công nhận thì thành chưởng môn | Thua/rời biên/đầu hàng không thành tội, không tước kỹ năng đã học; mở tái đấu sau một mốc nghỉ rõ trong UI. Lỗi commit danh hiệu: chưa trao quyền, retry cùng match ID |

## 6. Tuyến Xích Lô và chương chung

| ID dự kiến / nhiệm vụ | Mục tiêu và địa điểm | Điều kiện bắt đầu/hoàn tất | Phần thưởng một lần | Khi thua, rút lui hoặc ghi lỗi |
|---|---|---|---|---|
| `xl_01` — Nước nguội, đường thông | Từ xưởng Hạnh B04 đến Đê Đất Đỏ; ghi trạng thái ba mốc dẫn thủy và báo Hồng Diệp | Có lời giới thiệu; route mới mở hợp lệ; không yêu cầu swimming/đốt van bằng kỹ năng chưa có | Quyền khách, mở Sân Dẫn Thủy | Rút lui không mất chứng cứ đã xác nhận; không khóa lối về vì chưa hoàn tất nhiệm vụ |
| `xl_02` — Vật liệu có nguồn | So hồ sơ xưởng B04 với dấu niêm kho phái, xác định kiện hàng bị gán sai nguồn | `xl_01`; tương tác đủ hai nguồn thật, không chỉ giao một chồng vật liệu farm được | Quyền học nghề phái và thấy quan điểm của Đỗ Nham | Không trừ kho trước xác nhận; nếu yêu cầu mẫu vật ở slice sau, quote→confirm→commit→rollback theo economy |
| `xl_03` — Chừa đường lui | Đấu tập ở Sân Dẫn Thủy: giữ một vùng bảo hộ và ngừng giao tranh khi người diễn tập rút lui | Đồng thuận và mốc an toàn đã dựng; đo mục tiêu còn an toàn/địch hợp lệ, không đếm số damage đơn thuần | Tư cách đệ tử và quyền học tâm pháp đầu tiên | Mục tiêu trọng thương hoặc người chơi thua kết thúc buổi tập; không NPC chết/quest terminal, không phạt truy nã do đòn hợp lệ trong buổi tập |
| `xl_04` — Lò dưới lòng đất | Theo tuyến Lạc Ấn đến tầng 4 Xích Lô; đọc sơ đồ niêm cũ rồi rút an toàn | Giữ thứ tự/gate tầng hiện có; bản đồ tông môn không phải đường tắt xuống tầng 4 | Quyền học võ công Xích Lô, thông tin liên hệ giữa tên lò cũ và phái hiện nay | Về sớm trước lấy sơ đồ không tính xong; đọc rồi chết giữ cờ chứng cứ nhưng loot run xử lý như trước; không sinh đá Thần Thạch |
| `xl_05` — Nhận phần sai của mình | Công bố phần sổ bị bỏ sót; đưa kế hoạch sửa ca trực và báo tin tại Đình Giữ Lò | `xl_02`, `xl_04`; giải quyết incident nghiêm trọng của ứng viên nếu có | Tư cách ứng viên diễn võ; quyền thuê Đỗ Nham khi hệ thuê sẵn sàng | Có người phản đối thì hiện việc cần giải thích; không bắt trả khoản vô hạn hoặc farm lặp để vượt ngưỡng ẩn |
| `xl_06` — Đình Giữ Lò | Trận với Trọng Nghiêm gồm nhịp đòn nặng và bảo vệ lối rút đã báo trước | Đủ tư cách và chưởng môn nhận lời; không có đơn truy bắt đang hiệu lực đối với ứng viên | Người thắng đủ quyền nhận chức sau buổi công nhận | Thua chỉ đóng match; các giáo tập/NPC vẫn sống. Save/load giữa trận theo quy tắc hủy trận chưa chốt thắng, không restore vào active hit |
| `sect_joint_01` — Sổ chung của hai đường | Mang hai bản đối chiếu tới đầu mối trung lập tại B03; Hạnh/Lạc Ấn xác nhận chuyên môn phù hợp | Hoàn thành hai nhánh chứng cứ, không bắt buộc gia nhập/cầm quyền cả hai phái | Hai phái có cùng bản ghi vụ hàng; mở công việc hợp tác và lựa chọn đồng hành | Chưa nhận bản tin thì phái chưa đổi thái độ. Phát hiện bằng chứng mới cho phép bổ sung, không âm thầm reset toàn bộ quan hệ |
| `sect_joint_02` — Người giữ lời thề | Sau U Minh Tháp, dùng bằng chứng đã có để quyết định cách hai phái kiểm tra niêm trong tương lai | Chiến thắng tầng 5 do DepthProgress xác nhận; mọi nút lựa chọn mô tả hậu quả trước khi nhận | Kết chương: thay đối thoại, nhiệm vụ hợp tác và vai trò lãnh đạo; không cần thêm Boss mới | Người chơi có thể tiếp tục làm khách/đệ tử; không nhận chức vẫn hoàn tất cốt truyện. Không cấp lại thưởng tầng 5 |

Nhiệm vụ điều tra có nhánh đối thoại nhưng slice đầu không cần hệ suy luận tự do hay hàng trăm trạng thái. Cờ mục tiêu, địa điểm tiếp theo và lý do khóa phải thấy trong Journal/quest card ở 800×600. Khi người giao bị trọng thương, ghi rõ nơi nhận thay hoặc thời điểm trở lại, không chỉ hiện “NPC không khả dụng”.

## 7. Khiêu chiến và chuyển giao quyền lãnh đạo

Luồng đề xuất: **khách → được công nhận là đệ tử → hoàn thành việc của phái → giáo tập xác nhận năng lực → đăng ký khiêu chiến → đấu có đồng thuận → công nhận kết quả → người chơi nhận hoặc từ chối chức vụ**. Trận thắng và quyền cai quản là hai mốc khác nhau để người chơi hiểu vì sao cả phái chấp nhận mình.

- Đánh chưởng môn ngoài võ đài là incident bình thường. Không gọi đó là khiêu chiến hợp lệ, không trao chức khi HP họ chạm 1. Đơn đang xét hoặc truy bắt phải được giải quyết qua luật nhân quả trước đăng ký, không khóa vô hạn vì quan hệ cá nhân chỉ hơi thấp.
- Trước trận, UI hiện mục tiêu thắng, biên võ đài, tín hiệu đầu hàng, điều kiện hủy, phần thưởng và việc không mất đồ vì một trận luyện tập. Slice đầu đề xuất không thu phí dự thi; nếu sau này có phí thì phải quote/confirm và định nghĩa hoàn phí riêng.
- Đạt điều kiện thắng thì owner đóng mọi hitbox/proc thuộc trận và tuyên bố dừng. NPC còn ít nhất 1 HP; hiệu ứng đang bay không được đánh tiếp người đã xin lui. Trận đấu không tạo wanted với các participant đã đồng thuận; đòn ngoài phạm vi hay người ngoài cuộc vẫn theo luật incident.
- Chỉ tin `match_id`, participant stable ID, điều khoản được chấp thuận và accepted event thuộc match. UI callback, HP bị set bởi debug hoặc đổi scene không là chứng minh chiến thắng.
- Thua/đầu hàng/rời biên giữ kiến thức, nhiệm vụ và quan hệ trước trận. Hồi phục sau tập là chính sách instance đề xuất, không thay quy tắc chết/loot ở dungeon hay tự chữa mọi NPC ngoài trời. Nếu đối thủ thật sự trọng thương, chấp sự thông báo họ quay lại sau chuyến hoàn tất/quay về như luật hiện hành.
- Save/load khi match chưa có kết quả: hủy trận sạch về khu chờ, giữ sự đồng thuận/lịch sử đăng ký nhưng không ghi thắng/thua giả. Kết quả đã commit nhận lại được đúng một lần; writer lỗi không đổi leader và không xóa kết quả có thể retry.
- Khi nhận chức, chưởng môn cũ ở lại làm cố vấn; roster/life IDs và ký ức vẫn giữ. Quyền quản lý đầu tiên nên gọn: chọn một việc ưu tiên và chỉ định lịch bảo vệ đã author; không quản trị hàng trăm NPC hoặc thu thuế tự động trong slice đầu.
- **Đề xuất chưa chốt:** một tư cách thành viên chính thức và tối đa một chức chưởng môn cùng lúc. Có thể học kiến thức cơ bản qua quan hệ với phái khác; chuyển phái cần quy trình rõ. Không thu hồi bùa/gear/công pháp đã học của save cũ. Việc có cho lãnh đạo cả hai phái hay không để quyết định riêng.

## 8. Tâm pháp và võ công giữ vai trò bổ trợ

Kiến thức là tiến triển lâu dài; món bùa/trang bị là UID hữu hạn; trạng thái tác chiến/cooldown thuộc actor. Gia nhập phái không biến Player thành class cố định, không cấp mọi rune, không đổi resolver exact multiset và không tạo recipe trùng chỉ để gắn tên phái.

| Phái | Tâm pháp passive đề xuất | Võ công G đề xuất | Lối chơi được khuyến khích và giới hạn |
|---|---|---|---|
| Thanh Vân | **Tĩnh Phong Quyết:** một lợi ích hồi năng lượng nhỏ sau lần né một đòn hostile thật đúng điều kiện; có cooldown riêng và giới hạn hồi | **Hồi Phong Kiếm:** tiếp nối kỹ thuật `cloud_return` đã có nền tảng, dạy phản kích sau né đúng nhịp. Nếu đã học kỹ thuật cũ thì ghi nhận tương đương, không bắt mua lại | Gear phù hợp mới thực hiện chiêu kiếm; gear khác vẫn dùng bùa/cộng hưởng bình thường. Không thưởng vì dash vào không khí, đòn đồng minh hoặc tự tạo proc |
| Xích Lô | **Tức Lô Tâm Kinh:** sau một lần đứng giữ vị trí đủ điều kiện rồi né/đỡ hợp lệ, tạo lợi ích phòng thủ hữu hạn cho lần trao đổi kế tiếp | **Trấn Lô Ấn:** đặt một vùng giữ lối rồi kích hoạt bằng G, tham khảo kiến trúc `tether_sigil`; tên/hành vi cuối cần review, không tự sửa chiêu đã học | Dành khoảng trống cho một cast cộng hưởng kế tiếp, không vùng damage tự động vô hạn. Không mặc định Player có parry; điều kiện “đỡ” chỉ dùng nếu gear/runtime thực sự hỗ trợ, slice đầu chọn điều kiện né/đứng rõ ràng |

Đề xuất một tâm pháp đang chọn và một võ công đang chọn; không cộng dồn tất cả sách đã học. Dạy/học có mục tiêu thử trong sân tập trước chuyến. UI ghi hiệu lực, trigger, phí, cooldown, gear tương thích và lý do chưa dùng được; chỉ số chưa có consumer không được quảng cáo là tác dụng thật.

Học và chọn qua owner progression hiện có; runtime nhận snapshot đã xác thực. Chọn/đổi tâm pháp hoặc gear không reset cooldown, không sửa projectile đã bay, không mở slot rune miễn phí. G và phép ghép bùa dùng cùng nguồn năng lượng với luật hiện hữu; không sửa chi phí cast bằng cách chỉ đổi trường Resource chưa được consumer đọc. Hurt/modal/chuyển phòng đóng transient đúng lifetime. Passive lấy accepted causal event, chống lặp root/proc và không tự nhận thưởng quest từ signal trình diễn.

## 9. Nhân quả và đồng hành trong cốt truyện

Kịch bản phải cho thấy chuỗi **khơi mào → quan sát → mang tin → tiếp nhận → phản ứng**, không dùng lời thoại biết hết. Mỗi phái có chấp sự nhận tin và đường về hợp lệ. Trước khi báo tới nơi, chỉ nạn nhân/nhân chứng biết; khi tới nơi, UI nói rõ vụ gì và bằng chứng nào khiến thái độ đổi. Nhân chứng nghe lại cùng một lời kể không thành hai nguồn độc lập.

AoE lỡ tay là tình huống cần QA riêng: accepted hit gây phòng vệ tại chỗ; lời cảnh cáo cho cơ hội ngừng. Đề xuất gộp child/DOT cùng root vào một vụ, xét mức thương tích và hành vi tiếp diễn; không miễn trách nhiệm chỉ vì mọi damage đến từ một root. Tự vệ trước kẻ truy sát giữ ngữ cảnh người khơi mào; tấn công người đã rút lui tạo vụ mới. Rời scene không xóa tin và NPC không đuổi xuyên scene vô hạn.

Mỗi event dùng để quy trách nhiệm cần source/target stable life identity, root causal context và thời điểm commit/rút lui, để callback cũ không gán sang actor mới. Phase2 phải chốt riêng trường hợp đạn/AoE đã commit trước khi đối phương rút lui nhưng chạm sau đó; không dùng riêng thời điểm callback làm bằng chứng người chơi cố tình ra lệnh tấn công mới. Đây là chi tiết attribution cần thiết kế, không tự thay luật người dùng về tấn công người đang rút lui.

Hợp đồng đồng hành phải hiển thị trước xác nhận: **một người/một chuyến, tổng phí Linh Thạch cố định trả trước, không chia loot**, vai trò, điều kiện rút lui và nơi quay về. Vân Sinh giữ khoảng trống, Đỗ Nham bảo vệ tuyến sau bằng đòn nặng; cả hai không bất tử và không chết vĩnh viễn. HP chạm ngưỡng trọng thương khiến họ ngừng đánh, rút khỏi chuyến và trở lại sau chuyến, giữ danh tính/ký ức.

Nếu người chơi ra lệnh gây hấn với đồng môn, đồng hành báo lý do từ chối; tái phạm có thể rời đội theo điều khoản đã xem. Tự vệ của đồng hành không tự động là người chơi ra lệnh hành hung. Bị kẹt đường thì dùng cơ chế tái nhập ở anchor an toàn do room owner xác nhận, không nhân actor hoặc tặng heal/cooldown qua cửa. **Đề xuất hoàn phí chưa chốt:** hủy trước khi bước vào dungeon hoàn toàn bộ; sau khi bắt đầu chuyến phí trả cho sự tham gia, không hoàn do tự về sớm; lỗi hệ thống chưa cung cấp NPC cần rollback phí. Chưa triển khai thì UI không bán hợp đồng giả.

## 10. Kế hoạch implementation và hợp đồng API dự kiến

Tên API/file mới dưới là đề xuất để chia owner trước code, không phải API đã tồn tại. Tái dùng source hiện có sau khi đọc consumer. Không đưa tất cả state vào NpcPilotCatalog hoặc nhét phe vào `team == 1`; combat team không là danh tính môn phái/căn cứ pháp lý.

| Phase | Kết quả nhỏ có thể chơi | API/owner dự kiến | File dự kiến tác động và gate kết thúc |
|---|---|---|---|
| **0 — Khóa nền hiện tại** | Hoàn tất FPS/save, shop/rune, hồi phục NPC và đường kẹt; có checkpoint để mở map | Root giữ GameFlow/profile integration; mỗi agent đóng băng phần mình | Không thêm hệ tông môn lớn trước nghiệm thu; kiểm strict + actual main input/native/performance phù hợp. Lập bảng budget save/scope/receipt, không lấy số gate cũ làm PASS |
| **1 — Một cửa vào Thanh Vân** | P03↔Vân Quan↔Tùng Đình; `sect_intro_01`, `tv_01`; một chấp sự thật | `SectCatalog.definition(id)`; `SectQuestService.quote/accept/record/claim`; `SectProgress.snapshot()` dùng SanctuaryProfile | Dự kiến mới `scripts/sects/sect_catalog.gd`, `sect_progress.gd`, `sect_quest_service.gd`; thay `exterior_route_catalog.gd`, `exterior_room.gd`, `exterior_hub.gd`, geography validation, Journal adapter. Không đổi IDs cũ. Test đi hai chiều60/120, quest một lần, save/cold/quarantine, modal800 |
| **2 — Một vụ việc được báo** | Hai người Thanh Vân, một nhân chứng đưa một báo cáo đến Vân Quan; minh oan/hòa giải tối thiểu | `SectIncidentService.observe_accepted_hit(event,result,context)`; `observe_witness(incident,witness,evidence)`; `deliver_report(report_id,receiver)`; `quote_resolution/resolve` | Mới causal adapter/incident service; nối accepted result và stable IDs từ NPC owner, mở rộng population/schedule theo contract. Test miss/block/rootduplicate/AoE/tự vệ/rút lui, LOS, tin qua scene/cold, bounded history và writer faults |
| **3 — Xích Lô và hai hồ sơ** | B04↔Đê Đất Đỏ↔Sân Dẫn Thủy; `xl_01/02`, `tv_02`, tuyến điều tra chung | Dùng cùng catalog/quest/incident API, không fork writer/service cho từng phái | Author room definitions/geo validator/dialogue/quest catalog; thêm giáo tập có stable ID qua migration rõ. Gate topology/art riêng, NPC schedule/grounding, quest khi NPC recovering, không bypass gate Lạc Ấn |
| **4 — Học tâm pháp/võ công** | Mỗi phái một bài luyện, một passive và một võ công có UI chọn/dùng thật | `SectTechniqueService.quote_learn/learn/select`; adapter cấp snapshot cho `CultivationStyleRuntime`; passive component đọc accepted events | Đọc `opening_cultivation_state/session`, `cultivation_style_runtime/data`, GearSession/EquipmentStats trước chia owner. Đề xuất mới definitions/helper passive; không viết lại motor/FSM. Gate cooldown/energy/snapshot/proc/room cleanup, gear swap, cast5đơn/10cặp không hồi quy và native tell/contact |
| **5 — Một đồng hành cho một chuyến** | Thuê Vân Sinh hoặc Đỗ Nham tại hub/phái, đi/đánh/rút/về | `CompanionContractService.quote/hire/cancel`; `begin_trip(run_id)`; `bind_room`; `finish_trip(result)`; một authoritative slot | Mới contract/runtime adapter; root nối GameFlow expedition lifecycle; NPCWorldState giữ recovering/identity. Chi tiền và cấp hợp đồng cùng profile owner. Test doubleconfirm/door/cold/fault/retreat/defeat/finished/runaway, một actor, không lootshare hoặc revive qua đổi phòng |
| **6 — Khiêu chiến có tính chính danh** | Một phái trước: registered duel→nonlethal result→ratification→leader; sau đó mở phái còn lại | `SectChallengeService.quote/register/start/settle/ratify`; `match_id`; explicit duel participants/context; `SectProgress.leader_id` | Mới duel controller/match state/arena authoring/UI; NPC actor adapter cancel/withdraw theo owner. Gate quyền đăng ký, damage thật/interrupt/cheatcallback, load-midmatch, retryidempotency, mất ghi giữa thắng và nhận quyền, giữ NPC cũ |
| **7 — Kết chương và chơi tự nhiên** | Hai bản ghi đối chiếu, lựa chọn trách nhiệm, quản lý tối thiểu sau kế nhiệm | Quest/catalog và read-only projection từ owners đã có; không thêm simulator toàn thế giới | Hai khu vực native art/âm thanh/occlusion, từng tuyếnquest/companion/duel tự nhiên; đọc lý do đủ ở800×600; đo frame-time khi incident/save/đaNPC. Cân số sau bằng chứng, không dùng headless thay pacing/game feel |

### Persistence và điểm phải review trước khi code

- `SanctuaryProfile`/`ProfileCommitWriter` vẫn là cổng ghi tiến triển người chơi. NpcWorldState vẫn giữ life/schedule/cá nhân. Đề xuất một scope tông môn chứa state hữu hạn cho nhiều phái; không một scope hoặc file save riêng cho từng NPC/phái. Phải audit scope đang dùng và giới hạn bytes/receipt trước khi chốt schema.
- Không ghi mỗi hit/bước chân thành receipt. Học/nhận thưởng/danh hiệu có event ID hữu hạn; giao tranh gộp theo incident, lưu trạng thái hiện tại và lịch sử có giới hạn. Compaction cần preimage/audit/rollback; không tự xóa chứng cứ đang mở hoặc phạt oan vì mất lịch sử.
- Crossing giữa life sidecar và profile cần contract rõ: incident/cause có stable ID, owner xác nhận sự thật, projection đọc và reconcile idempotent. Không giả định ghi hai file là atomic. Trước nhận phí/trao chức phải thiết kế fence hoặc transaction boundary hợp lệ; lỗi một owner phải fail closed, UI chỉ đường retry, không trao thưởng nửa chừng.
- Luật tên/roster thay đổi không tái tạo identity. Save cũ giữ kỹ năng, gear UID, nhiệm vụ, người trọng thương và ký ức. Unknown schema/quarantine giữ nguyên dữ liệu; không reset profile để vào phái.
- Gate schema không được mở map bằng cách nhét ID chưa được validator hiểu vào save. Route/anchor/cửa, life IDs, quest target và UI phải phát hành cùng migration tương thích.

## 11. Những việc chưa chốt và điểm dừng hiện tại

Các quyết định nhỏ cần review ở phase tương ứng: tên nhân vật/địa danh; một hay nhiều tư cách phái/chức lãnh đạo; chi phí học và thuê; hoàn phí; ngưỡng ứng viên; nhịp tái đấu; chỉ số passive và tương thích gear của G; thời gian truyền tin; cách Player bị hạ ngoài võ đài. Các mục này không chặn việc hoàn thành tài liệu hoặc sửa các lỗi ưu tiên đã được giao.

**Bàn giao lần này:** đã ghi hướng cốt truyện, hai biome/map riêng, vai trò NPC, tuyến nhiệm vụ, thua/retry, kế nhiệm nonlethal, tâm pháp/võ công, nhân quả và hợp đồng đồng hành, cùng phases/API/file dự kiến. **Chưa triển khai bất kỳ hệ/map/asset mới nào từ roadmap này.** Không chạy test/engine cho một tài liệu thiết kế. Bắt đầu phase1 chỉ sau checkpoint ổn định hiện tại và phân owner; nếu đến hạn chưa đủ thời gian thì giữ roadmap ở trạng thái thiết kế, không ghép một hệ tông môn dở vào bản đang chơi.

## 12. Bổ sung 08/10: chọn lại tầng, đi sâu và tầng rộng hơn

Người dùng yêu cầu lúc khoảng09:00UTC: nếu còn thời gian làm tầng sâu hơn, thêm nhiều quái có skill/cách đánh/animation riêng, tầng rộng hơn và hành trình dài hơn; đồng thời chọn lại tầng đã đánh xong để không phải đi lại từ đầu. Hạn làm việc mới18:00VN/11:00UTC. Nội dung dưới tách yêu cầu đã chốt khỏi phương án chưa triển khai.

**Slice chọn tầng đã được kiểm trên bản riêng:** gặp Lạc Ấn tại căn cứ, chọn tầng Depth trong1..tầng cao nhất đã hoàn tất. Chưa hoàn tất tầng nào thì bắt đầu tầng1 như cũ. Việc chọn không cấp vật phẩm, không ghi một lần hoàn tất mới, không mở tầng kế chưa vượt qua; kiểm lại quyền trước khi chuyển inventory vào chuyến. Save cũ dùng trường `cleared` hiện có. Chức năng này không áp cho các chặng opening chưa có ledger hoàn tất theo tầng. Trạng thái nghiệm thu phải xem báo cáo chọn tầng, không suy ra từ đoạn thiết kế này.

**Hiện trạng cần cải thiện:** baseline có năm tầng Depth, mỗi tầng là một phòng1280×720 với đường đánh liên tục và các bục phụ. Candidate hiện mở rộng riêng Vân Thạch lên1920×720 với một rương nhánh; tầng2–5 giữ1280×720. Bốn nhóm quái có chiến thuật riêng và tầng5 có boss; đây chưa phải hành trình khám phá dài nhiều nhánh. Chỉ tăng chiều ngang rồi kéo giãn PNG hoặc tăng số lượng cùng một quái sẽ không đáp ứng yêu cầu mới.

**Phương án cho lượt mở rộng sau checkpoint:** mở một tầng mới thành2–3 khu nối nhau: lối tiếp cận có thông tin về hiểm họa, khu chiến đấu chính, nhánh tùy chọn và lối tắt quay về. Mỗi khu có bố cục và nền/tiền cảnh riêng, điểm mốc nhận diện, anchor hợp lệ và camera theo người chơi. Giữ cửa về/nhặt nốt rõ ràng. Không ép đi bộ qua đoạn trống để kéo dài thời lượng; đo thời gian thực với người chơi trước khi chốt độ dài.

- **Tầng6 đề xuất — Tàng Thư Trầm Mặc:** thư khố chìm, hành lang cầu giấy niêm và bể mực. Kẻ Chép Ấn khóa hướng rồi vẽ tuyến đạn; Giấy Khuyết tiếp cận theo nhịp gió và chỉ lao khi đã báo. Quyết định chiến đấu là giữ một lối rút, di chuyển sau khi hướng khóa và phá tuyến bắn từ sườn. Chưa có map, quái, animation hoặc balance runtime.
- **Tầng7 đề xuất — Mạch Đồng Đứt Gãy:** mỏ đồng dưới lò, thang máy bỏ hoang và kênh giải nhiệt. Phu Giáp báo nhát búa nặng; Linh Đăng neo vùng nguy hiểm có thời gian tắt để vượt qua. Quyết định chiến đấu là phân biệt nguồn tạo vùng và quái che chắn, chọn thứ tự xử lý. Không dùng sàn gây sát thương vô hình hoặc đổi màu cùng bộ địch rồi gọi là quái mới.
- Mỗi loại mới cần bảng pha đi/đứng/báo đòn/active/recover/hurt/rút, silhouette khác, VFX cast→travel→impact khớp snapshot/hitbox, thời gian đủ đọc ở800×600. Art phải gắn vào actor thật rồi chụp/đo trong trận. Atlas hoặc rig mới không được tự điều khiển damage qua method track.

**Điểm chặn kỹ thuật trước mở tầng6:** `DepthProgress.valid` đang giới hạn0..5, bossflag gắn tầng5; Catalog/Guide/Campaign có giả định5tầng và terminalboss. Không chỉ tăng FLOOR_COUNT. Cần migration tương thích giữ tiến độ cũ và vị trí chiến thắng boss5, làm rõ cách mở chặng sau boss, mở rộng checkpoint UI/quest/return/loot contracts cùng lúc. Giữ oldGolem receipts riêng, không coi lựa chọn tầng hoặc đi qua lối tắt là bằng chứng hạ boss.

**Gate kết thúc của một tầng rộng:** đi toàn tuyến và nhánh bằng input60/120 không kẹt; mỗi exit quay lại đúng anchor; camera/occlusion/UI không hở nền; quái không đồng loạt aggro xuyên nhiều khu; entity/light/voice budgets được giữ theo room lifetime; nhận nhiệm vụ→đánh→nhặt→về→nâng→coldload giữ UID và tiến độ. Đo frame-time với profile đã chơi lâu và nhiều accepted hit. Thời gian đi, mức thú vị và độ rõ đòn cần playtest; ảnh hoặc test logic chỉ chứng minh phần tương ứng.

# Native smoke NPC và tiến triển — 08/10/2026

Trạng thái 09:12 UTC: tooltip đã sửa bằng deferred hover + vị trí event, giữ click xuyên card; native45/45 và hai regression click54/54,40/40 đạt cùng source cuối, exit0 và diagnostics rỗng. Đã xem pixel top/combo/bottom800 và1280; không còn popup mặc định che chữ. Hai NPC cũng đã có native32/32 với PNG riêng mới. Root giữ quyền strict/backup/ghép; chưa ghép bản chính. Các kết quả lỗi và phương án STOP cũ dưới đây là lịch sử, không là bản cuối.

tests/sect_progression_visual_probe.gd yêu cầu --native-approved, renderer khác headless, DUNGEON_QA_DATA_ROOT riêng và DUNGEON_QA_EVIDENCE_ROOT tuyệt đối trước mọi write. Dùng GameFlow thật với ExteriorHub và WorldCampaign. Fixture khai báo cấp sẵn 500 Tàn Hồn, 200 Linh Thạch, 20 dust, 10 crystal; không cấp trước rune, mốc khám phá/boss hay level tu luyện. Profile được tạo qua owner SanctuaryProfile và cultivation initialization hiện hành.

Lần chạy đầu tạo 18 PNG, gồm hai viewport 1280×720 và 800×600: Tab/bùa trống; xác nhận HP và mana; danh sách học bùa dựng lần đầu ở 800; xác nhận học Hỏa và chế lại; Fire+Wind được lắp qua input; tooltip số combo ở 800; M với hướng Trúc Cơ sớm và chi tiết; Thanh Vân tuần tra/báo đòn/ra đòn/hurt/dừng truy đuổi; Xích Lô ra đòn; góc WestStair trước/sau thoát.

Mở Thanh Vy bằng E tại vị trí thật, chọn nút bằng mouse events qua viewport, hủy và xác nhận Soul upgrades; học Hỏa/Phong rồi chế thêm Hỏa bằng nút UI. Kiểm tra chi phí, số UID và maximum live. Tab/M/ô bùa dùng input thực. Tooltip có cuộn bằng mouse wheel; nhiệm vụ có PageDown. Assertions kiểm tra control/capture nằm trong viewport, nhưng chưa thay cho root xem từng pixel.

NPC được đặt kiểm tra trong hai room có thật bằng API chuyển phòng (khai báo setup, không coi là người chơi tự tìm đường). Đòn đầu dùng attack input của Player hiện tại; tự vệ dùng FSM/Hitbox thật. Hai query Hitbox do fixture tạo dùng để lấy state hurt và trọng thương xác định, đều đi qua DamageEvent/Hurtbox/resolver. Khi chụp frame, pause cây trong thời gian copy ảnh để giữ đúng phase đã đi vào thật; không đặt giả combat_phase để dựng ảnh. Kiểm tra NPC dân thường cùng tồn tại, NPC dừng ở leash và rút lui không chết.

Góc WestStair dùng spawn/reset có khai báo tại90,534 rồi input đi trái, cast, đi phải. Riêng case hình học này tắt AI quái và survival để cô lập va chạm; không là chứng cứ chơi trọn dungeon hoặc FPS. Không sửa collider hay actor/movement logic.

Output từng PNG và SECT_PROGRESSION_VISUAL_RESULT.json nằm trong evidence directory do runner cấp. Helper dùng dạng native với -Script res://tests/sect_progression_visual_probe.gd -UserArgs --native-approved; không truyền -Headless. Runner kiểm tra chỉ một Godot GPU process, WindowStyle Hidden, màn phụ và AppData/LocalAppData/QA root riêng. Bằng chứng được chép nguyên vào [verification/sect_progression_visual_20261008](verification/sect_progression_visual_20261008); thư mục này bị gitignore theo quy tắc bằng chứng của dự án, cần root bảo toàn khi bàn giao.

## Kết quả thực chạy và giới hạn

- `sect_visual_native_0817`, 08:17:05–08:17:27 UTC: 117 checks, 0 failures, 18 PNG, exit 0, diagnostics rỗng. Renderer Compatibility/OpenGL3.3 NVIDIA RTX5080. Đây là kết quả logic native ban đầu, **không được gọi là nghiệm thu toàn bộ hình ảnh**: xem PNG07 phát hiện tooltip đã mất trước lúc chụp, còn inventory bị cuộn xuống. Assertion cũ chỉ kiểm tooltip trước các wheel events nên bỏ sót lỗi.
- `sect_tooltip_before_0821`, 08:21:13–08:21:22 UTC: fixture được tăng cường với `--tooltip-only`, 43 checks, 18 failures, 6 PNG, exit 1, không timeout, không script/runtime ERROR. Cả 800×600 và1280×720 đều mất tooltip ngay khi con trỏ vào vùng tooltip; wheel sau đó cuộn inventory bên dưới. Đã giữ toàn bộ FAIL/raw logs, không lọc.
- Root đã xác minh và sửa nguyên nhân: panel tooltip có `MOUSE_FILTER_IGNORE` khiến pointer chạm ô túi rỗng bên dưới; hover ô rỗng gọi hide, wheel tiếp theo tới outer ScrollContainer. Hậu quả thật: không đọc/cuộn được chỉ số dài. Root đổi panel sang `MOUSE_FILTER_STOP`; nội dung con vẫn không chiếm input, owner `_input` giữ wheel cho tooltip.
- `sect_tooltip_after_0823`, 08:23:44–08:23:52 UTC: 43 checks, 1 failure, 6 PNG, exit1. Giữ/mở/cuộn tooltip đều đạt ở cả hai kích thước; lỗi cuối do fixture chọn tâm ô áo ở1280 đang nằm dưới chính tooltip. Đó chưa phải hành vi “di ra ngoài”. Đã sửa fixture chọn mép trái ô áo còn nhìn thấy và thêm assertion điểm này nằm ngoài tooltip; không sửa product cho trường hợp đó.
- `sect_tooltip_after_r2_0825`, thực chạy 08:24:35–08:24:43 UTC: **45/45 checks, 6 PNG, exit0, diagnostics rỗng**. Mouse move giữ tooltip, từng wheel và cuộn tới cuối giữ tooltip; scroll tooltip tăng và outer giữ nguyên ở800/1280; di tới phần ô áo nhìn thấy đổi món thành công. Teardown sạch. Đã nhả engine lane ngay sau hoàn tất; không chạy lại toàn bộ18capture flow vì thay đổi chỉ nằm ở pointer surface tooltip.

Pixel đã trực tiếp xem: 00 bùa trống có chỉ dẫn Thanh Vy;01 xác nhận HP800;03 menu học lần đầu800;04 xác nhận học800;07 tooltip mất;08 mục Trúc Cơ800;09 chi tiết cuộn1280;11 báo đòn;12 ra đòn;17 thoát góc. Các chữ/chức năng trong 00/01/03/04/08 đọc được và nằm trong panel;09 đã cuộn tới phần dưới nên không thay bằng chứng đọc toàn bộ hướng dẫn. NPC có nhãn trạng thái và tell/active tương ứng số clock trong JSON, nhưng sprite/VFX của NPC vẫn prototype; static PNG không chứng minh hoạt ảnh đã hoàn thiện hoặc cảm giác giao chiến.

Fixture focused mới kiểm top/combo/bottom ở hai kích thước, giữ tooltip sau mouse move và từng wheel, scroll tooltip tăng trong khi outer không đổi; chuyển ra ngoài vẫn chọn được món khác. Đây là kiểm bổ sung có lý do từ lỗi pixel thực, không thay các gate save/cost/cold-load đã có. Các source hash lấy sau lần chạy được ghi thời điểm rõ trong BEFORE_FIX_SOURCE_MANIFEST.json; lần native đầy đủ có trước phần bổ sung assertion tooltip, không gán nhầm hash fixture mới cho lần cũ.

Đã trực tiếp xem cả6 PNG final (`tooltip_top`, `tooltip_combo`, `tooltip_bottom` ở800/1280): chữ tên/chỉ số và damage/ba nhịp combo đọc được trong khung; cuộn cuối thấy cả dòng mô tả và hướng dẫn tháo. Panel tạm che một phần túi trong lúc đọc, nhưng vẫn có lối hover phần món đồ lộ ra và close vẫn nằm ngoài panel. Đây là chứng cứ đọc/cuộn tooltip hiện tại, không phải đánh giá thẩm mỹ toàn game.

Manifest cuối: `FINAL_EVIDENCE_MANIFEST.json`, gồm4lượt raw run và14source hashes lấy08:25:17UTC. Probe cuốiSHA256 `2224DA094F4BC3FE6F0EE142A7B0B5EF318B351FD7A3ACC4918BA77034E1BC50`; InventoryScreen sau sửa `6A06718748DEB37B8B4D182B73F9E97F10C7007C656D7CBBE1AF2D5B726B4082`. Bản before/after fixture được lưu dạng `.gd.txt` dưới thư mục evidence bị `.gdignore`, không tạo script runtime thứ hai. Không đụng save thật, không cài gì, không ghép bản chính. Root chịu trách nhiệm strict gate, backup/merge và quyết định checkpoint.

## Bổ sung sampling NPC sau mipmaps

Ảnh NPC lần đầu cho thấy nhiều điểm màu gắt khi giảm texture1028×1530 xuống chiều cao60pixel. Root đối chiếu HubNpc dùng LINEAR_WITH_MIPMAPS nhưng texture import chưa tạo mipmap, rồi bật mipmaps trong `.import` và chạy import sạch; nguồn PNG không sửa. Agent chỉ thêm mode `--cultivator-only` và metadata texture vào fixture, không sửa actor/art product.

`sect_cultivator_mipmaps_0830`, 08:30:47–08:30:57 UTC: **32/32 checks, 6 PNG, exit0, diagnostics rỗng**. Hai runtime texture đều xác nhận `loaded_mipmaps=true`, cùng path `assets/sprites/player/player_swordsman.png`, kích thước1028×1530, scale x0.0395, filter4. Đòn Player thực dẫn đến tell không damage, active Hitbox trúng Player, query injury hủy đòn sang hurt, leash dừng và trọng thương rút lui vẫn đạt. Không chạy lại học bùa/shop/dungeon.

Đã xem patrol/tell/active/hurt Thanh Vân và active Xích Lô sau import: hình nhân vật ở kích thước thật mượt hơn, các vùng áo/tóc liên tục thay những hạt màu gắt trong ảnh trước. Đây là đánh giá sampling từ native pixel cùng sprite, không phải phép đo định lượng chất lượng hay hoàn thiện animation. Chuyến fixture mới có inventory và thời gian patrol khác, nên không gọi ảnh trước/sau là A/B căn từng pixel. Hai NPC vẫn dùng sprite prototype chung và các pose/VFX đơn giản; cần art/animation riêng ở milestone sau.

Bằng chứng bổ sung giữ nguyên trong `sect_cultivator_mipmaps_0830`, `CULTIVATOR_MIPMAP_MANIFEST.json` và snapshot fixture mới. Hash fixture bổ sung `8991093FC5F072CF57C612F728FFD34B460EC8405C3047725B519C1A3539D3F3`; UID được engine import tạo `uid://doitffh84eowy`. Không ghi đè manifest08:25 vốn thuộc bộ tooltip. Đã nhả GPU/engine lúc08:30:57 để root chạy strict gate.

## Strict R1: giới hạn của sửa tooltip bằng STOP

Root bắt đầu strict lúc08:31, source đóng băng. Log60Hz cho thấy `inventory_equipment` và `modular_equipment` lỗi ở click trái/phải thật: panel STOP che tâm ô đồ nên click không tới Button. Native45 chỉ kiểm đọc/cuộn và di sang phần áo còn lộ, nên không phủ tương tác click xuyên panel vốn có. Đây là hồi quy product của phương án STOP, không đổi test để bỏ những click contracts đó.

Readonly review đề xuất root: trả panel về IGNORE, chặn riêng `_bag_hover`/`_equipment_hover` khi con trỏ đang nằm trong tooltip hiển thị để ô rỗng bên dưới không thay/hide; giữ `_input` nhận wheel trước GUI. Không guard focus/click hoặc `_show_tooltip` chung, vì keyboard/confirm/refresh phải hoạt động. Cần kiểm lại cả native45 và những suite click bị lỗi sau sửa; chưa có kết quả cho phương án này. Rủi ro cần theo dõi: di ra khỏi tooltip nhưng còn nằm trên cùng Button bên dưới có thể không phát thêm mouse_entered, cần kiểm đường di pointer thật ngoài trường hợp teleport điểm của fixture.

Nhóm60Hz strict NPC/học bùa đã hiện PASS trong log đọc lúc08:40: cultivator60, nonlethal137, expedition recovery, shop123, rune learning183. Runtime wiring và progression guide có lỗi fixture/compatibility được gửi root để xử lý sau khi strict đóng: các ID `qa_stash_*` không hợp sequence compact schema2; process population bị fixture tắt nên actor chưa cleanup ở nhánh callback; hint Thanh Vy không có điều kiện làm hở tên trước mốc gặp. Không sửa source/test hay chạy engine trong lúc strict đang chạy.

## Bản cuối sau strict R1 — 09:12 UTC

Root giao quyền InventoryScreen và fixture cho worker này để điều tra thứ tự event. Trace native đã xác minh `mouse_entered` chạy trước `_input` của cùng MouseMotion: ở800, hover ô túi rỗng vẫn đọc tọa độ cũ `(99,273.5)`, gọi UID0 rồi hide; sau đó `_input` mới nhận vị trí tâm card `(525,309)`. Cache event đơn thuần chưa đủ. Đây là kết luận từ raw `sect_tooltip_trace_0904/stdout.log`, không suy từ tên hàm. Không warp con trỏ hệ điều hành hoặc thao tác cửa sổ chính.

Sửa product cuối:

- Chỉ hai connection `mouse_entered` dùng CONNECT_DEFERRED, nên guard và anchor đọc vị trí event đã cập nhật; callback kiểm modal/tab và geometry target còn hợp lệ để bỏ hover quá hạn sau move/scroll/close.
- Giữ panel IGNORE và focus/click synchronous, wheel trong card vẫn do owner `_input` xử lý. Không đổi ownership equip/unequip hoặc nhận click bằng đường tắt.
- Khi viewport đổi kích thước, đóng card gắn vị trí cũ trước layout lại. Lần thử deferred đầu đạt800 nhưng giữ card cũ che toàn cột item ở1280; raw3fail còn được giữ.
- Tắt `Button.tooltip_text` chỉ trên equipment/bag vốn có card riêng. Pixel thực phát hiện popup mặc định “Trống” từ ô phía dưới đè lên số combo; kiểm logic45 lúc đó vẫn PASS, nên sửa dựa ảnh và chạy lại đúng phạm vi.
- Fixture tìm điểm nằm trong ô trang bị khác, trong scroll bounds và ngoài card thực; không hardcode mép một ô vốn có thể đang bị card che. Giữ45 assertions, gồm hover khác món, từng wheel, outer scroll và teardown. Debug trace tạm đã gỡ khỏi product.

Các lượt raw sau R1 đều được giữ nguyên (label có thể khác phút thực; thời gian thật ở RUN_RESULT): `sect_tooltip_ignore_guard_0857`45checks/18fail; `r2_tooltip_event_pointer`45/11fail; `sect_tooltip_trace_0904`45/11fail; `sect_tooltip_deferred_0908`45/3fail; `sect_tooltip_deferred_resize_0910`45/0fail nhưng pixel còn popup “Trống”. Không gọi lượt cuối ấy là nghiệm thu giao diện đầy đủ.

Checkpoint cuối 09:10:01–09:10:33 UTC, cùng InventoryScreen và probe không đổi:

| Lượt | Kết quả | Phạm vi |
| --- | --- | --- |
| `sect_tooltip_final_0911` | 45/45, 6 PNG, exit0, diagnostics[] | Native800/1280, top/combo/bottom, vào card, cuộn, đổi món ngoài card, resize, teardown |
| `sect_tooltip_final_inventory_60_0911` | 54/54, exit0, diagnostics[] | Actual left/right click, identity ledger, equip/unequip/capacity/cooldown/teardown |
| `sect_tooltip_final_modular_60_0911` | 40/40, exit0, diagnostics[] | Actual sáu loại áo/quần/giày/găng/nhẫn/dây chuyền click và bảo toàn modifiers/UID |

Đã xem native pixel `tooltip_top_800`, `tooltip_combo_800`, `tooltip_bottom_800`, `tooltip_combo_1280`, `tooltip_bottom_1280`: đọc được ba đòn và ba nhịp, không còn popup “Trống”, cuối text và hướng dẫn tháo nằm trong card. Đây là viewport input do QA đưa vào và pixel render thật; chưa phải thao tác chuột vật lý của người chơi hay đánh giá cảm giác chơi liên tục.

Source cuối InventoryScreen SHA256 `16A7BD230B0EBF0DFCEBEDF64F25B2EABA6AA0522ECB34E3FA553EE9B19F6736`, probe `C5D476BD46707818EDFBD6D36E7CDE744BFC37E7BA5C1AADDCB99E7A2FCBCA4D`. Mọi raw run, PNG, snapshot `.gd.txt` và hash ở `POST_R1_NATIVE_AND_CLICK_MANIFEST.json`. Đã nhả lane lúc09:10:50 UTC, không còn Godot process. Không chạy strict thay root hoặc sửa save thật.

## Hai ảnh tu sĩ riêng mới và sửa sau R1

`sect_cultivator_art_0858`, 08:58:06–08:58:16 UTC: **32/32,6PNG,exit0,diagnostics[]**, chạy `--native-approved --cultivator-only --expect-mipmaps`. Hai texture từ `assets/npc/cultivators` do art owner tạo/bind, được actual actor nạp với mipmap; bộ ảnh cũ cùng Player portrait lúc08:30 chỉ còn bằng chứng trước thay art. Đã xem patrol/tell/active/hurt Thanh Vân và active Xích Lô: áo trắng/kiếm và giáp nâu đồng phân biệt, chân ở mặt đường, không còn hạt sampling gắt. Vẫn là mỗi NPC một PNG đầy thân với pose/motion/VFX procedural; không gọi đó là atlas hoạt ảnh độc lập hoàn thiện.

Sáu focused headless60 chạy08:59–09:00 trước sửa tooltip cuối: inventory54, modular40, opening_runtime_wiring111, opening_progression_guide202, opening_loop315, armor31 đều PASS, exit0/diagnostics[]. Hai suite click đã lặp có lý do ở checkpoint tooltip cuối phía trên; bốn suite còn lại tận dụng bằng chứng đúng source owner. Kết quả không thay strict tổng thể mà root sẽ chạy. Bằng chứng mới và failed tooltip85/trace đều được chép vào cùng manifest bổ sung, không ghi đè manifest08:25/08:32.

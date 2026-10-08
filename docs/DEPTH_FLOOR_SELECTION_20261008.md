# Chọn lại tầng đã hoàn tất — 08/10/2026

Candidate private `sect-path-repair`, chưa ghép main. Theo yêu cầu người dùng, Lạc Ấn có lựa chọn điểm bắt đầu cho chuyến Ngũ Tầng mới; không cần chơi lại từ tầng1 nếu đã hoàn tất tầng khác. Đây chỉ là lựa chọn trong năm tầng hiện có, chưa thêm tầng, quái, animation, map hay giá/balance.

Luật: phải hạ Golem mở đầu và nhận nhiệm vụ của Lạc Ấn qua owner hiện có. Chuyến đầu bắt đầu tầng1. Sau khi lưu hoàn tất tầngN, có thể chọn tầng1..N. TầngN+1 vẫn phải tới từ lối đi tiếp của một tầng đã dọn, không tự mở khóa từ menu. Chọn tầng không cấp loot, chứng tích hoặc cờ thắng; quái, cửa khóa, rương và boss của chuyến mới sinh đúng vòng đời hiện có.

`DepthProgress.can_start_floor(number)` là policy chỉ đọc trên namespace cũ, không đổi schema hoặc thêm receipt. Guide có OptionButton, giữ danh sách năm tầng/tactic, focus/modal/scroll. `GameFlow.start_depth_campaign(initial_floor=1)` kiểm lại policy trước `_take_prepared_inventory`, truyền `initial_floor` trước khi add scene. Thất bại lưu trang bị giữ Hub và mở lại lựa chọn. Guard run hiện hữu chặn launch lặp. Notice khi về không còn hứa chuyến sau luôn từ Vân Thạch.

Tiến độ và loot vẫn do owner cũ quản lý: clear tầng đã hoàn tất trả thành công idempotent, không tăng revision; clear tầng kế tiếp mới commit đúng một event. Boss mới thuộc namespace depth, không tạo lại chứng tích Golem mở đầu. Loot hữu hạn theo mỗi chuyến vẫn giữ luật cũ; chơi lại boss không đồng nghĩa mở rương/nhặt đồ tự động. Chuỗi bank tiền/UID và recovery NPC khi về không bị thay. Giới hạn cold-return hai save owner đang ghi trong báo cáo chính vẫn còn.

Phạm vi file: `scripts/runtime/depth_progress.gd`, `scripts/npc/depth_guide.gd`, `scripts/hub/game_flow.gd` (chỉ API launch depth), `scripts/rooms/depth_campaign.gd` (chỉ notice); test mới và tài liệu này. Không áp chọn chặng cho opening WorldCampaign vì owner đó chưa có ledger hoàn tất từng chặng tương đương.

Test `tests/depth_floor_selection_test.gd` dùng main/Hub/Guide/GameFlow/room thật và QA save riêng: cold cleared3, reject0/4/5/6 trước chuyểnUID, E/mouse/popup input,800/1280, lựa chọn khôngghi, quarantine/lỗi lưu, launch3/duplicate request, dọn3idempotent→dọn4mới, về/coldbankUIDtiền, replayboss5/duplicatecallback. Fixture tạo tiến độ lịch sử qua commit owner, tắt AI và dùng direct health damage để kết thúc encounter; đây không phải nghiệm thu combat feel. `--native-approved` dành cho lane native được cấp, tự lưu ảnh800/1280/trước xuống/livefloor3; không dùng cùng headless.

## Kiểm chứng private — 09:19UTC

Root import đầu `r2_selector_import` quét source xong nhưng thoát với0xC0000005 sau editor layout; raw giữ nguyên, không coi làPASS hoặc đã sửa crash. Import lại một lượt `selector_import_r2` kết thúc09:13:07UTC, exit0/diagnostics rỗng. Runtime bốn file không đổi từ09:09:53 tới sau native.

| Lượt | Kết quả |
|---|---|
| `selector_60_r4` |55/55, exit0, diagnostics rỗng |
| `selector_120_r4` |55/55, exit0, diagnostics rỗng |
| `selector_native_r4` |55/55, exit0, diagnostics rỗng,4PNG; Compatibility/NVIDIA RTX5080 |

Raw/stdout/stderr/RUN_RESULT.json dưới `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/probes/`. Đã xem bốn ảnh `selector_800.png`, `selector_1280.png`, `selector_chosen_3.png`, `selected_floor_3_live.png`: tiêu đề, điều kiện, dropdown, nút xuống/quay lại nằm trong viewport; danh sách tactic cuộn độc lập, phần cuối bị clip đúng scroll ở800. Dropdown và action hiện tầng3; scene thật là Hàn Kính3/5, cửa còn khóa với4mục tiêu. Đây là lựa chọn qua chuột mở dropdown, keyboard điều hướng popup, chuột launch; không phải OS-input playtest tự nhiên.

Các lượt chẩn đoán giữ riêng: `selector_60_r1` có2assertionfail; r2/r3 còn1. Popup hiện `embedded=true`, focused_item ban đầu−1. Gửi event trực tiếp vào viewport/signal của popup không đi qua định tuyến input thực; gửi qua root viewport làm focused_item lên2 và chọn tầng3. Assertion không nới lỏng. Assertion notice khi về cũng cần chờ frame `_process` cập nhật sau `floor_exit.open()`. Chỉ sửa fixture; không thay policy/gameplay để làm testpass. Test60r4 và120/native cùng runtime; giữa hai lượt chỉ chỉnh tên tham số không dùng/comment trong helperinput. Fullstrict do root quản lý, không thay bằng focused này.

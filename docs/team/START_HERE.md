# Bắt đầu cùng Dungeon Resonance

Gói nguồn bàn giao ngày **2026-10-08**. Godot **4.7.2 stable**, GDScript, renderer **Compatibility**. Đây là prototype hành động 2D offline hướng tới Steam; chưa phải game export hoặc bản phát hành.

## Mở lần đầu

1. Clone repo được ghi trong [trạng thái GitHub](GITHUB_STATUS.md), hoặc giải nén ZIP vào một thư mục mới. Thành viên phát triển bằng Git nên clone; ZIP là snapshot để gửi và đối chiếu, không có lịch sử Git.
2. Chuẩn bị Godot 4.7.2 từ [nguồn chính thức](https://godotengine.org/download/archive/). Gói không kèm engine/executable. Không nâng phiên bản hoặc đổi renderer riêng trên một nhánh nội dung.
3. Import `project.godot`, chờ import xong; main là `scenes/maps/prologue_hub.tscn`. F5 mở Căn Cứ Lữ Khách. F6 chỉ chạy scene đang chọn; các scene Alpha/TestLevel cũ không thay main.
4. Đọc [AGENTS](../../AGENTS.md), [trạng thái](../PROJECT_STATE.md), [kiến trúc](../PROJECT_ARCHITECTURE.md), quyết định mới nhất trong [DECISIONS](../DECISIONS.md), [báo cáo combat hiện hành](../COMBAT_VISUAL_FIX_20261007.md) và nhật ký mới nhất. Các tài liệu mốc cũ giữ giá trị lịch sử.
5. Khi chơi thử, dùng **save riêng** qua [hướng dẫn QA](QA_AND_HANDOFF.md). Main thông thường ghi `user://`; không dùng save thật để thử giao dịch/rèn/chết.

Điều khiển: A/D chạy, Space nhảy, Shift dash; chuột trái đánh, chuột phải tung bùa, hướng theo con trỏ 360°. E tương tác, Tab hành trang/bùa, C sinh tồn, M nhiệm vụ/map; ` hoặc ~ bật chữ debug. QA cấp đồ/warp mặc định tắt.

## Chọn công việc

| Việc | Đọc và thực hiện |
|---|---|
| Chia người, giữ tiến độ, nhận một task | [Kế hoạch nhóm](TEAM_PLAN.md) → [backlog](BACKLOG.md) → [mẫu task](TASK_TEMPLATE.md) |
| Xây/sửa map hiện hữu | [Hướng dẫn map](MAP_GUIDE.md) |
| Ghép bùa, thêm hành vi kỹ năng/VFX | [Hướng dẫn bùa](SPELL_GUIDE.md) |
| Player, quái, boss, NPC, art/animation | [Hướng dẫn nhân vật](CHARACTER_GUIDE.md) |
| Dùng Codex hỗ trợ dự án | [Skill portable và prompt mẫu](AI_SKILL_GUIDE.md) |
| Chạy kiểm tra, gửi PR, ghép nguồn | [QA và bàn giao](QA_AND_HANDOFF.md), [CONTRIBUTING](../../CONTRIBUTING.md) |

## Dự án đang hướng tới đâu?

Vòng chơi: căn cứ → chọn trang bị/bùa → khám phá/chiến đấu → nhặt đồ/bí mật → Golem hoặc trở về sớm → cất/rèn/tu luyện → chuyến tiếp theo. **Gear quyết định class/moveset; Ô Bùa và cộng hưởng là cơ chế tấn công chính.** Có 5 nguyên tố và 10 cặp; không thay bằng cây skill class cố định.

Mục tiêu run 15–20 phút, NPC/khám phá và đột phá mở động tác là định hướng đã chọn. Thời lượng này **chưa được chứng minh bằng playtest tự nhiên**. Nhiều ý tưởng trong roadmap cũ đã được triển khai một phần, vì vậy xem trạng thái/code hiện hành trước khi nhận task. Không mặc định mở tầng/boss mới từ một tài liệu thiết kế.

Bản hiện hành đã ghép sửa combat/bùa/Golem và có kiểm tra tập trung. Còn khựng liên quan save đồng bộ, hai lỗi layout800×600 và native crash lịch sử chưa kết luận; full strict mới trên checkpoint này chưa chạy. Xem [QA](QA_AND_HANDOFF.md) để phân biệt bằng chứng cũ và kiểm tra đóng gói mới.

## Nguồn, quyền sử dụng, dữ liệu

Gói giữ source gameplay, asset runtime, addons với license upstream, `.gd.uid`, `.import`, tài liệu và nguồn/provenance art cần cho asset test. `.godot`, save cá nhân, engine, game export và đa số log/ảnh QA lịch sử không nằm trong ZIP. Các link tới evidence ngoài máy trong báo cáo cũ có thể không mở được ở máy thành viên; evidence combat chọn lọc có trong [evidence](evidence/README.md).

Repo công khai không tự cấp một license chung cho code/art dự án. Giữ license của addon/font và nguồn asset; nhóm dùng repo để cộng tác, không tự đổi giấy phép hoặc xuất bản game từ một PR nội dung. ZIP có `TEAM_SOURCE_MANIFEST.json` để đối chiếu SHA256 từng file và receipt đóng gói ở cạnh ZIP.

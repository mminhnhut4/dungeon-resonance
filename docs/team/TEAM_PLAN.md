# Phối hợp và hướng phát triển

Đọc [hiện trạng, cốt truyện và lộ trình cập nhật](PROJECT_AND_STORY.md) trước: tuyến1–8 và bốn map tông môn đã ghép; các hệ môn phái lớn vẫn là thiết kế. Các mốc M0–M5 dưới đây là trình tự làm việc, cần đối chiếu backlog hiện hành. Đây là kế hoạch đề xuất triển khai từ checkpoint2026-10-08, chưa gán tên người hay cam kết lịch khi chưa biết sức làm của nhóm. Một người có thể giữ nhiều vai; **chỉ một integrator ghép vào main**.

## Vai trò và ranh giới

| Vai | Phạm vi ưu tiên | Đầu ra |
|---|---|---|
| Chủ dự án / integrator | Duyệt scope, khóa file chung, GameFlow/profile/catalog, merge và snapshot | Main có commit xác định, receipt/backup, danh sách việc tuần tới |
| Map / encounter | Geometry hiện hữu, anchor/cửa, bố trí giao chiến, traversal | Tuyến đi thật, ảnh collider và phép thử hai chiều/chuyển phòng |
| Combat / bùa | Recipe/runtime, status, commit/hitbox, hiệu năng có đo | Kỹ năng chơi được từ hành trang thật; kiểm trúng/hụt/cancel/lifetime |
| Nhân vật / art / âm thanh | Rig/atlas, telegraph, VFX/SFX đọc clock, NPC presentation | Art nối runtime, ảnh các pha, cleanup/budget và nguồn asset |
| QA (luân phiên hoặc người riêng) | Save riêng, cold load, regression, playtest/frame-time | Log nguyên vẹn, exit code, cấu hình và lỗi tái hiện |

File chung cần đặt owner trước khi sửa: `project.godot`, `scripts/hub/game_flow.gd`, `scripts/runtime/sanctuary_profile.gd`, `profile_commit_writer.gd`, `gear_inventory.gd`, `scripts/presentation/slice_presentation.gd`, các catalog và scene Player. Không giao hai task đồng thời sửa cùng hotspot. Art có thể làm trước nhưng chỉ nhận hoàn thành khi bind vào scene thật.

## Một task đi tới main

1. Chọn một hàng [BACKLOG](BACKLOG.md), ghi owner/nhánh/files/acceptance theo [TASK_TEMPLATE](TASK_TEMPLATE.md). Giới hạn mỗi người một task đang làm.
2. Nhánh `feature/<id>-<slug>` hoặc `fix/<id>-<slug>` từ main mới nhất. Dùng checkout riêng; không chép patch lên thư mục của người khác.
3. Làm lát cắt nhỏ đi hết từ input/data đến phản hồi trong trận. Giữ riêng proposal, asset chưa nối và phần runtime đã kiểm.
4. Commit, mở PR kèm kiểm tra thật và rủi ro. Người khác review hành vi và ownership. File chung có xung đột thì người sở hữu giải quyết bằng nội dung, không chọn toàn bộ ours/theirs.
5. Integrator sao lưu/ghi commit main trước merge, kiểm checkpoint, chạy gate phù hợp và strict mặc định trước nhận mốc tích hợp. GPU chỉ một lượt nặng tại một thời điểm; giữ lịch đặt lượt trong task/PR.
6. Sau merge cập nhật PROJECT_STATE, BACKLOG, ghi commit/receipt. Nhánh lỗi giữ riêng, không gọi là đã ghép. Đổi quyết định gameplay thì cập nhật DECISIONS; tài liệu kiến trúc đề xuất không là lệnh migration.

## Thứ tự mốc

| Mốc | Công việc | Điều kiện ra mốc |
|---|---|---|
| M0 · nhận nguồn | Mỗi máy import4.7.2, đọc guide, chạy main với save riêng | Repo/commit giống nhau, không thiếu resource; owner/file locks rõ |
| M1 · ổn định opening | DR-001…005: lưu/khựng, layout nhỏ, crash tái hiện, strict checkpoint, chơi tuyến thật | Lỗi có bằng chứng và fix hẹp; full gate ghi đúng kết quả; không mở roster/tầng để né lỗi |
| M2 · nội dung hiện hữu đọc được | DR-006…008: kiểm đủ bùa, chuyển động quái/NPC đang có và art map | Gameplay thật/hitbox/teardown đúng, không chỉ xem asset editor |
| M3 · một vòng chơi đáng lặp lại | Đo ba build từ gear/bùa, nhiệm vụ mở kit, rèn/cất đồ/tu luyện; đối chiếu phần đã có trước bổ sung | Fresh start→trận→return/death→cold-load, không UID/reward lặp; playtest ghi nhịp độ |
| M4 · mở rộng có duyệt | Chọn một slice roadmap còn thiếu: thưởng1/3, một đột phá/nhánh, bí mật/NPC trợ lực | Scope và balance được duyệt; save transaction/migration và integration chơi được |
| M5 · hướng Steam | Export offline, QA máy mục tiêu, gamepad/audio/UI và chuẩn bị store | Là mốc sau; ZIP source này không là build Steam |

Run15–20phút là mục tiêu để đo, không lịch sản xuất mặc định. Trong M0–M2, ưu tiên ổn định tuyến1–8 và roster đã ghép; phần mở thêm boss/tầng cần một scope mới được duyệt. Các giá/loot chưa được người dùng chốt vẫn là prototype. Bản Nguyên Thần Thạch chưa có nguồn loot hợp lệ trong roster hiện tại.

## Nhịp làm việc nhẹ

Đầu tuần chọn ít task đủ sức hoàn tất và phụ thuộc rõ. Mỗi ngày cập nhật bốn dòng vào task: đã làm, chứng cứ, vướng mắc, bước tiếp. Cuối tuần review một build cùng commit: người mới có hiểu cách dùng bùa, nhìn thấy tell của boss, về căn cứ và tiếp tục từ save không? Ghi actual/pending; không lấy số test logic làm chứng nhận FPS.

Definition of Done: acceptance chơi được trên entrypoint thật; source/asset đúng owner; test liên quan và diagnostics nguyên vẹn; save/lifetime khi ảnh hưởng; PR review và main hậu kiểm; docs trạng thái cập nhật. Thiết kế/asset chưa nối runtime dùng trạng thái `Design`/`Art ready`, không `Done`.

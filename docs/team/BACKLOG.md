# Backlog khởi động nhóm

Snapshot2026-10-08. **Owner chưa phân công**; điền username sau khi nhóm nhận việc. Các task dưới là việc tiếp theo, không ghi đè mốc đã ghép ngàyOct7.

| ID | Ưu tiên / trạng thái | Task cụ thể | Acceptance / phụ thuộc |
|---|---|---|---|
| DR-001 | P0 / Todo | Đo khựng còn lại khi mastery/save trong trận thật | A/B cùng seed/engine/scene; p95/p99/max và mẫu hitstop; xác minh bottleneck trước sửa, giữ durability/seal/rollback |
| DR-002 | P0 / Todo | Sửa map/quest cards ở800×600 | Tái hiện baseline trước; nút/scroll/focus đọc được,1280×720 không hồi quy; giữ input/reward |
| DR-003 | P0 / Todo | Điều tra native crash lịch sử nếu tái hiện | Source/engine exact, exit/crash/log và ablation; không gắn nhãn đã fix từ gate sạch đơn lẻ |
| DR-004 | P0 / Todo | Sửa fixture nguồn hit rồi tiếp tục strict | Lượt đóng gói Oct8 dừng campaign_60:31 assertions/exit0 nhưng ERROR ObjectDB. SurvivalTestBase dùng source_id987654 giả, EnemyHitAggro gọi instance_from_id. Fixture cần nguồn sống đúng contract; giữ runtime và không lọc ERROR. Các gate sau chưa chạy. Xem PACKAGING_VERIFICATION.json |
| DR-005 | P0 / Todo | Playtest opening tự nhiên, fresh save | Không warp/clear/directgrant; đánh Slime, ghép bùa, boss/retreat, rèn/cất, load lại; timed notes và lỗi thực |
| DR-006 | P1 / Todo | Native readability5bùa+10 cặp trong trận | Kiểm hướng/windup/active/contact/recovery, blocked/miss và boss;10 cặp logic cũ không thay native proof |
| DR-007 | P1 / Todo | Audit animation quái/NPC hiện hữu | Bảngstate/asset/binding/clock; ưu tiên silhouette fallback đang có; không thêm archetype mới |
| DR-008 | P1 / Todo | Polish art tuyến ngoại cảnh hiện có | P01 pack đang bind; các phòng khác prototype. Art-only giữ collider/transform, ray grounding/occlusion và voice/light budget |
| DR-009 | P1 / Todo | Đo và phân biệt3buildgear+bùa | Nhận kit từ UI/quest thật, cùng encounter; clear time/cast/dash/energy/damage nhận, không tự chốt balance |
| DR-010 | P2 / Design | Chọn một slice tu luyện/NPC/reward còn thiếu | Đối chiếu code/state trước viết; brief được duyệt, có ownership/save contract; phụ thuộcM1/M3 |

## Mẫu cập nhật khi nhận task

`DR-xxx | owner:@username | branch:fix/dr-xxx-slug | files:... | status:Doing | base:<commit> | GPU:<khung giờ nếu cần>`

Trạng thái: Todo → Doing → Review → Verified private → Merged main. Blocked ghi điều kiện cụ thể. `Verified private` cần log/exit/ảnh khi liên quan; `Merged main` cần commit main và hậu kiểm. Không cộng dồn113/268checks cũ để cho task mới PASS.

## Owner và candidate tiếp tục08/10 — chưa ghép

Owner: Codex root/integrator duy nhất; private DgContinue_20261008, base main fe4017e. DR-001 đã đo A/B và loại thử writer không cải thiện; cold-cast prewarm private đã kiểm, mastery/save còn Todo. DR-002 Verified private UI800/native. DR-004 Verified private fixture live-source, default strict đang chạy. DR-006 Verified private10cặp native, wall-contact recipe còn thiếu. DR-008 Verified private background/terrain routes; props/NPC legacy còn prototype. DR-005 và DR-009 giữ Todo cần người chơi thử tự nhiên. DR-003 vẫn chưa rõ native teardown; retry sạch không là fix. Phạm vi được người dùng mở mới: năm tầng/roster khác/boss2phase/NPC Lạc Ấn, private native+focused đã có receipt; chưa Merged main. Xem ../CONTINUATION_20261008.md.

**Root checkpoint 01:43 UTC:** candidate B default strict241/241 sạch,2.193source freeze; root sole integrator chuẩn bị backup/exact-target apply và hậu kiểm main. Không coi focused PNG/logic là playtest tự nhiên.

**Root chốt 01:47 UTC:** đã ghép216exact-target sau strictB241/241; main import/numeric64/native82-17ảnh sạch, backup/hashrollback/save5nguyênbyte. Root soleintegration kết thúc, các agent không chạyGPU. Masterysave peaks/nativecrash chưa rõ/cân bằng tự nhiên còn cần playtest; không mở việc mới.

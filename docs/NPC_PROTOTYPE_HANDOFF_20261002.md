# NPC pilot — bản sao riêng, chưa tích hợp main

Godot 4.7.2 / Compatibility. Workspace: `C:/Users/Admin/AppData/Local/Temp/dungeon_resonance_npc_d271a3fbc6/npc_prototype`. Bên điều phối là người tích hợp cuối; không tự merge hoặc chép về `D:/hầm ngục`.

## Phạm vi đã làm

| ID bền vững | Nơi xuất hiện | Công việc / mục tiêu |
|---|---|---|
| pilot_traveler | P01, x 520–870 | Quan sát đường, nghỉ trước khi qua núi |
| pilot_pilgrim | P03, x 1560–1820 | Chăm đèn gần miếu |
| pilot_gatherer | P04, x 580–900 | Tìm cây thuốc ven đường khô |
| pilot_courier | B03, x 1320–1660 | Đối chiếu đường thư ở bưu trạm |
| pilot_apprentice | B04, x 1120–1450 | Kiểm dây buộc ở xưởng |

Đây là vai trò phụ thử nghiệm, chưa thêm tên/tông môn canon. Giữ nguyên Hạnh, Thiết Lão, Thanh Vy, Vô Danh và toàn bộ ending. Dùng silhouette vector `HubNpc` hiện hữu, không tạo art mới.

`NpcWorldState` giữ năm record dữ liệu thuần; scene chỉ đại diện local. Walk/work/rest/talk/flee/downed/recovering/dead có nhãn quan sát được. AI chạy 4 Hz, tối đa tám bước bù mỗi frame; năm record được cập nhật kể cả khi không có actor local. Mỗi room tối đa một pilot; corridor SC01 không spawn NPC. Chân actor đọc `ExteriorRoom.floor_y()`, không sửa collider địa hình hoặc motor/FSM Player.

E nói chuyện hoặc quyết định khi NPC trọng thương. Melee dùng query Hurtbox thật; mọi DamageEvent qua `NpcPilotResolver`. Health floor 1 giữ `killed=false`, ngăn thưởng kill/relic heal; DIRECT/RESONANCE/DOT/ENVIRONMENT và delivery nội bộ không kết liễu DOWNED. NPC còn sống chạy trốn sau hit, không có đòn phản công mới. Thiệt hại môi trường/nguồn ngoài team Player tăng fear mà không tự trừ trust với Player.

Tha là lựa chọn đầu tiên, giữ fear và trust đã mất, thêm debt nhỏ và phục hồi sau 20 giây chơi tới nửa HP. Hỏi thăm chỉ tăng trust một lần. Giết cần màn xác nhận riêng và token của episode DOWNED còn hiệu lực. Chỉ sau save thành công mới ghi tombstone và tháo actor; save lỗi rollback quyết định. Không có loot, tiền, gear, nhiệm vụ hay phần thưởng khi xử tử.

## Save, ownership và âm thanh

Sidecar `<profile.save_path>.npc_v1.json`, schema NPC 1 riêng; profile v1/geography/UID ledger không thay đổi. Tệp tạm được validate, ghi qua helper giao dịch hiện hữu, giữ backup. JSON load chuẩn hóa scalar int/float, reset khóa talk tạm. Main hỏng hoặc thiếu nhưng còn `.tmp/.previous/.bak` bị cách ly: không phục sinh từ backup cũ, không tự áp Kill đã báo thất bại; giữ evidence để phục hồi thủ công. Pilot bị cách ly không spawn actor.

Modal/hành trang/pause dừng đồng hồ NPC. Không dùng thời gian máy. Clock hiện do `NpcPopulation` trong ExteriorHub sở hữu: tiếp tục trên mọi record khi đang chơi H00/exterior, lưu khi Hub bị tháo; **chưa tiến clock trong DungeonRun**. Muốn mở rộng sau này, đưa registry/clock sang owner GameFlow và gọi `advance_ticks()` theo thời gian chơi, giữ representation thuộc room.

`NpcPopulation.cue_requested(stable_id, cue, world_position, lifetime_owner)` là hook cho worker âm thanh. Cue gồm `npc_footstep`, `npc_walk/work/rest/talk/flee/downed/recovering`. Chỉ phát footstep khi đã đi 40 px, không replay lịch sử ngoài màn hình. Khi chuyển vùng/kill/teardown gọi `AudioManager.stop_owner(actor)`. Worker âm thanh phải dùng owner được truyền, budget voice chung; gói này không thêm audio assets/voice.

## Tích hợp tối thiểu

1. Đọc `handoff/changed_files.json` và `npc_prototype.patch`. Patch đã được kiểm bằng `git -c core.autocrlf=true apply --check` trên baseline riêng (giữ CRLF của runner Windows). Thêm `scripts/npc/` cùng UID và `tests/npc_population_test.gd`/UID. Merge các hook nhỏ ở ExteriorHub; nếu bản điều phối đã sửa file đó, giữ thay đổi của nó và ghép hook thay vì chép toàn bộ file.
2. Hook `_ready()` tạo NpcPopulation khi world_building_enabled; `nearest_station()` so khoảng cách pilot với station cũ; `interact_station()` giao pilot ID cho population. Population tự nghe zone/dialogue signals. Không cần thêm autoload, asset, input hoặc sửa scene.
3. Thêm `npc_population` vào vòng 60/120 Hz của runner strict. `project.godot` trong payload **không có**: config user QA chỉ thuộc bản sao này. Giữ cấu hình main của điều phối.
4. Trước test ở bản tích hợp, đặt custom user dir QA riêng và xác minh `OS.get_user_data_dir()`/`ProjectSettings.globalize_path("user://")` thật. QA ở đây đã xác minh là `C:/Users/Admin/AppData/Roaming/DungeonResonance_QA/npc_d271a3fbc6/`. Dùng engine portable trong `qa_engine/` có `_sc_`, editor_data riêng. Chạy runner mặc định đầy đủ; không dùng GameplayOnly làm gate.

## Bằng chứng và giới hạn

Kết quả strict cuối được ghi ở `handoff/verification_summary.json` và `handoff/evidence/npc_full_strict.log`; log riêng từng gate ở workspace `docs/verification/`. Có kiểm deterministic records, round-trip, quarantine future/corrupt/missing main, rename+rollback cùng lỗi, affinity/death idempotency, input E/choice thật, melee query thật, bảo vệ DOWNED, A→B→A, cold GameFlow reload, actor counts và giữ Player/UID/HP/energy. Rà soát song song chỉ đọc đã kiểm ID/ownership/choice locks; lỗi recovery được sửa và thêm fault test.

Không chạy GPU, không thao tác chuột/phím hệ thống, không đóng app. Chưa xác minh chất lượng hình ảnh, nhịp bước, framing DOWNED/modal hoặc game feel. Không đo FPS/benchmark hàng trăm NPC. Prototype chưa có pathfinding/jump/đổi room của NPC, companion, sect AI, incursion, witnesses, romance, dịch vụ/quest kế vai hoặc nhánh xử tử Thanh Vy. T29 companion/T30 đi liên vùng/T32 NPC canon chết vẫn NOT RUN; T31 mới có bằng chứng headless cho generic pilot. Clock trong dungeon là giới hạn tích hợp đã nêu.

Nguồn đã đọc: AGENTS.md và skill godot-dungeon-dev (entrypoint + architecture/workflow); PROJECT_STATE/PROJECT_ARCHITECTURE/MILESTONE_POLISH_REPORT/DECISIONS phần liên quan; NPC v0 Library `libfile_5b247e5ca89c8191826e07eee174fe35` trả full text 978 dòng; truyện v2 Downloads phần cốt truyện, death/ending/save và acceptance; Graybox_test_cases.txt cùng các phần topology/NPC/collision trong Graybox_dia_hinh_tuyen_dau.txt. P04 dùng terrace hiện hành của source, không dựng lại switchback đã superseded. Không dùng PNG tùy chọn.

Import đầu lúc chẩn đoán có parse error và native exit 0xC0000005, log giữ tại task root. Lượt import đầu dùng executable cũ và log có `EditorSettings: Save OK!`; không có hash editor settings trước lượt đó, nên không khẳng định file settings dùng chung nguyên byte. Sau đó toàn bộ editor gates dùng engine portable với editor_data riêng. Không đóng hoặc điều khiển editor đang mở; không ghi source/saves của checkout gốc. Các lượt strict sạch không chứng minh đã sửa root cause native lịch sử.

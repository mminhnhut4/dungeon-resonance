# NPC sinh hoạt ở khu mở đầu — candidate riêng

Nguồn mới được sao từ `D:/hầm ngục` vào `C:/Users/Admin/Documents/Codex/2026-10-03/task/living_opening`. Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility. Chưa chép patch về gốc; integrator là người ghi gốc và sở hữu GPU. Không có thay đổi vào save/cache/editor settings của gốc.

## Audit hiện trạng

- Actor cũ chỉ nhận x mỗi nhịp AI 0,25 giây; `_process()` rỗng và silhouette không có bước chân. Người chơi thấy các nấc 7,5–14 px thay vì bước liên tục.
- Cả năm record khởi đầu `walk` từ trái sang phải và đều dừng 32 tick / 8 giây ở hai đầu. Lịch chỉ là đi qua lại, không nêu điểm đến.
- Khách P01 chỉ đi x=520–870. Ghế đã có ở x=1380 và mái miếu trang trí trước cửa hầm ở x=320; khách không tới hai điểm này. P02 có cầu dây cố định nhưng không có pilot. P03 đã có người hành hương quanh miếu đèn x=1660.
- NPC local thuộc room; clock thuộc ExteriorHub, tiếp tục mọi record khi chơi H00/ngoài trời. Modal/hành trang/pause dừng clock. Clock trong DungeonRun, đồng hành và di chuyển liên phòng vẫn chưa triển khai.
- Mái miếu P01 là art trước cửa hầm hiện hữu; miếu P03 là điểm tương tác/graybox hiện hữu. Không suy diễn chúng thành tông môn hoặc địa danh trong truyện. Hạnh, Thanh Vy, Thiết Lão và Vô Danh không thuộc pilot killable này.

## Thay đổi có giới hạn

Giữ năm ID cũ, thêm duy nhất `pilot_bridge_keeper` ở P02. Mỗi room vẫn tối đa một pilot, SC01 không spawn; không có handoff liên phòng. AI vẫn 4 Hz / tối đa tám tick bù. Actor lấy mẫu khoảng giữa tick và tiến trong giới hạn tốc độ mỗi frame; chân đọc `ExteriorRoom.floor_y()`. Dáng bước, nghiêng khi rút lui và cử chỉ tay là **vector tạm**, chưa phải model/art hoàn chỉnh.

| Cư dân | Điểm sinh hoạt trong room hiện hữu | Dừng thông thường |
|---|---|---|
| Khách P01 | x380 cạnh mái miếu → x980 đèn → x1380 ghế → x900 nhìn lại đường | 1–3 giây |
| Người hành hương P03 | x1570 đèn → x1705 mái miếu → x1800 nghỉ | 1,75–2,75 giây |
| Người hái thuốc P04 | x610 → x880 → x740 trên đường khô | 1,75–2,5 giây |
| Người đưa tin B03 | x1340 → x1570 → x1640 ở bưu trạm | 1,25–2,25 giây |
| Học việc B04 | x1140 → x1430 → x1280 ở xưởng/cầu tàu | 1,5–2,5 giây |
| Người chăm cầu P02 | x2470 dây đầu cầu → x2720 dây cuối cầu → x2780 nghỉ | 1,25–2,5 giây |

Pha khởi đầu khác nhau giữa walk/work/rest; điểm đến đọc được trên caption. Đóng thoại hoặc cold reload giữa thoại khôi phục mode, mục tiêu, cursor và thời gian dừng đã bị ngắt, không đẩy tất cả về một pha nghỉ mới. Trúng đòn không chí mạng vẫn rút lui khỏi nguồn đánh, không phản công; tới mép an toàn thì nghỉ ba giây rồi tiếp tục tuyến.

### Sửa P2 sau review độc lập

Reviewer phát hiện actor/Hurtbox nội suy đã đi trước record giữa hai nhịp AI: record x520, actor x529,6, đòn từ x526,6 bên trái actor nhưng bên phải record khiến bản candidate đầu chọn rút sang trái. Trường hợp đối xứng khi đi sang trái cũng được tái hiện. `p2_close_hit_before_{60,120}.log` ghi142check/4fail mỗi mức (hai tình huống chọn sai, mỗi tình huống kiểm cả target và chuyển động).

Resolver giờ lấy x thực của actor sở hữu Health/Hurtbox **trước damage callbacks**, đổi sang tọa độ room rồi truyền scalar này vào `receive_hit()`. State chỉ dùng mẫu contact để so hướng rút lui; không sửa `record.x`, tick, cursor hoặc đồng hồ AI. Caller thuần/offscreen không có actor vẫn dùng record.x. Không thêm field save hoặc thay migration.

Thêm17check/mức: đòn cách actor3px từ cả hai bên, khi đi cả hai chiều, tại0,2giây giữa nhịp AI. Mọi trường hợp chọn đúng mép an toàn và tiến liên tục khỏi đòn trong0,5giây với giới hạn1,8× tốc độ; record.x/tick/cursor không đổi tại callback. `p2_close_hit_after_{60,120}.log` và final suite ghi142/142 đạt.

Không sửa motor/FSM Player, geometry, scene, art assets, input, loot, ending hoặc audio bank. Pilot có Hurtbox hiện hữu nhưng không có PhysicsBody chặn người chơi. `NpcPopulation` chỉ đổi dòng gọi `sync_record(playing, accumulator, delta)`; không thay choice IDs, signal order hoặc layout thoại nên UI worker có thể merge độc lập.

## Save và tử vong

- Sidecar giữ đường dẫn `<profile>.npc_v1.json`, **payload schema nâng 1 → 2**; profile/geography/UID ledger không đổi. Schema 2 có sáu record và thêm `schedule_index`, `interrupted` vào mỗi record.
- Schema 1 phải hợp lệ, đúng năm ID cũ và đầy đủ scalar/tombstone mới được nâng trong RAM. Mọi scalar cũ được giữ; chỉ thêm ownership của lịch và record chăm cầu. Read không ghi đè main. Save tiếp theo dùng writer giao dịch và backup hiện hữu.
- Schema 2 thiếu record/cursor lỗi hoặc schema tương lai bị quarantine; không khởi tạo lại cư dân có thể đã chết. Build pilot cũ không đọc schema 2: rollback code cần khôi phục sidecar qua quy trình recovery có kiểm lịch sử, không tự dùng backup cũ để phục sinh.
- Giữ health floor 1, DOWNED không chết do đòn/DOT/môi trường/timer. Giết chỉ qua cảnh báo và xác nhận token episode, commit save thành công rồi mới tháo actor. Save lỗi rollback quyết định. Tha giữ fear/trust, hồi sau 20 giây gameplay tới nửa HP; không có kill reward.
- Clock không dùng giờ máy. Pause cũng giữ nguyên pose và không phát lại bước chân ngoài màn hình. Không có tử vong ngẫu nhiên offscreen cho generic hoặc canon.

## Bằng chứng headless

Raw logs và JSON summary nằm trong `handoff/` cạnh candidate. Tất cả final gates exit0, không có dòng SCRIPT ERROR/ERROR/WARNING/FAIL. Hai mức 60/120 Hz:

| Suite | Check mỗi mức |
|---|---:|
| npc_population | 95 |
| npc_lived_opening | 142 |
| npc_dialogue | 72 |
| exterior_route | 149 |
| movement | 55 |
| combat | 100 |
| pilgrimage_audio | 70 |
| **Tổng mỗi mức / cả hai** | **683 / 1.366** |

Validator warnings-as-errors: 165 scripts / 33 scenes, 0 failures; import headless cuối exit0. Import vẫn ghi hai thông báo không bind được socket IPC trong sandbox (Error 3), không phải lỗi parse; raw log giữ nguyên. **Không chạy full strict suite hoặc GPU.**

Kiểm tra mới bao gồm năm phút lịch deterministic, đi tới mọi stop, 12 giây lấy mẫu cho mỗi actor ở mỗi Hz, không đảo chiều/jump vượt tốc độ, chân bám sàn, rút lui qua DamageEvent thật, không phản công, freeze pose/clock/cue, exact talk resume/cold reload, migration giữ tử vong, backup giữ v1, missing v2 record quarantine và six-cycle cleanup. Tất cả frame đang tiếp cận đích đều có dịch chuyển; dx tối đa 0,933350 px ở60 / 0,466675 px ở120 (ngoại trừ flee được kiểm riêng ở1,8×), sai lệch chân tối đa0,000061 px.

QA user:// thực được in trong hai suite: `.../task/qa_appdata/DungeonResonance_QA/living_opening/`. Engine portable có `_sc_` và editor_data riêng. Lượt đầu báo lỗi kho CA hệ thống do sandbox; dùng bundle CA công khai có sẵn của Git qua override.cfg và setting editor **chỉ trong QA**. Không tắt xác minh TLS; override/bundle/engine/settings không thuộc payload. Cơ chế override: [Godot TLS certificates](https://docs.godotengine.org/en/stable/tutorials/networking/ssl_certificates.html).

Logs thử đầu gồm parse error trong test mới do kiểm kiểu không tương thích và assertion tính cả thời gian đã đứng ở đích trước tick AI tiếp theo; được sửa trong test và giữ nguyên logs lịch sử. Final logs không chứa các lỗi này. `focused_run_before_flee_probe.log` là pass113check trước khi thêm12check flee; package trước sửa P2 được giữ trong `before_p2_repair/`. `focused_run_p2_fixed.log` là lượt focused đầy đủ sau sửa P2; final `npc_lived_opening_{60,120}_final.log`142check là bằng chứng hiện hành. Summary cuối tính từ từng final log.

## Tích hợp bởi integrator

1. Dùng package **`NPC-Living-Opening-Patch-P2-Fixed.zip`**, đọc `changed_files.json` / `verification_summary.json`. So SHA256 baseline của sáu file cũ; nếu gốc đã đổi, merge diff có mục tiêu. Patch có năm runtime scripts NPC (thêm resolver vào payload trước review), hai test scripts, UID của test mới và tài liệu này: tổng chín file. Package tám file trước review chưa có sửa P2.
2. Dùng `npc_living_opening.patch` hoặc exact payload. `npc_population.gd` có đúng một hook sync thay đổi; phối hợp với dialogue UI pilot qua integrator, không chép đè file đang sửa.
3. Thêm `npc_lived_opening` vào danh sách 60/120 của `tests/run_tests.ps1` khi tích hợp. Runner chung không nằm trong payload để tránh ghi đè công việc khác. Engine/override/project.godot QA/save/cache không copy.
4. Integrator chạy strict gate và GPU bằng QA user:// riêng khi được phép. Cần xem P01 đi tới mái miếu/ghế, P02 cầu, P03 miếu, hai chiều đi và flee, thoại/downed/confirmation; headless không chứng minh chất lượng dáng đi, caption, framing hoặc cảm giác tương tác.

Candidate không có game-wide simulation, dân số tông môn, biome/canon mới, companion hoặc migration liên vùng. Bản gốc chưa được cập nhật bởi worker này.

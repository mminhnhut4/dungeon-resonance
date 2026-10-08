# Tu sĩ tuần tra — lát cắt riêng ngày 08/10/2026

Trạng thái 07:18 UTC: đã triển khai và kiểm tra focused trên private `sect-path-repair`, chưa ghép main. Import sạch, focused **60/60 tại 60 Hz và 60/60 tại 120 Hz**, exit 0, không ERROR/WARNING. Chưa chạy native/GPU.

Hai ID bền vững: `thanh_van_disciple_01` của Thanh Vân Môn tại P01 x1500–1760 và `xich_lo_guard_01` của Xích Lô Phái tại P02 x1550–1820. NpcPilotCatalog sở hữu vị trí/lịch tuần tra; CultivatorCatalog chỉ giữ kiểu chiến đấu và trình bày. Các đoạn này thuộc mặt đường liên tục của ExteriorRoom, không qua cửa/cổng hay nhánh nhảy.

NPC trung lập tuần tra theo NpcWorldState. Chỉ sát thương thật được DamageResolver chấp nhận, có source_id đúng Player đang tồn tại và không phải ENVIRONMENT, mới khởi động tự vệ cá nhân. Team 1 không thay cho danh tính gây hấn. Root/source cache hữu hạn ngăn nhiều proc cùng đòn nhân nỗi sợ/trừ tin cậy nhiều lần; bản thân damage vẫn qua lịch sử dedup chuẩn của resolver. HP/ký ức/save thuộc owner hiện có; không thêm writer, loot hoặc phần thưởng hạ NPC.

CultivatorActor kế thừa NpcPilotActor, có nhịp hurt → giữ cự ly → tell → active → recover. Hitbox chỉ sample trong active và chỉ đánh Hurtbox Player; snapshot khóa hướng tại tell. Hurt, modal, hồ sơ bị cách ly/read-only, ra khỏi leash, rút lui hoặc teardown đều vô hiệu hóa hitbox/snapshot. Contact cũng kiểm read-only độc lập; ray collision mask 1 từ thân hiện tại tới Player chặn đòn xuyên solid. Combat clock tạm dừng theo hitstop hiện có. Hai tu sĩ cùng có leash và giới hạn mặt đường; kiếm giữ khoảng trống rộng hơn, hộ vệ chậm và báo trọng đòn lâu hơn. Mọi damage/timing/speed là thông số prototype, chưa được chốt cân bằng.

World state cung cấp `set_local_control` và `update_local_position` không lưu Node/reference. Khi tự vệ local giữ lịch tuần tra; HP ≤ 1 chuyển recovering và population tháo actor. Hồi phục chỉ do GameFlow/owner sau chuyến dungeon trở về, giữ ký ức theo yêu cầu người dùng. Không thay luật chết Player ngoài trời; SafeHub floor 1 hiện có giữ nguyên.

Hình tạm dùng lại `assets/sprites/player/player_swordsman.png`, đổi sắc và caption để phân biệt hai tu sĩ; PNG này đã có trong game, không phát sinh art mới. Đây là full sprite prototype với phản ứng nghiêng và cue theo clock thật, chưa phải rig/animation tu sĩ hoàn thiện, chưa có native visual QA trong phiên. Nhãn môn phái thể hiện xuất thân; chưa có môn phái ghi thù, nhân chứng/báo tin/truy nã hoặc thuê đồng hành.

Focused test `tests/cultivator_patrol_test.gd` dùng GameFlow/ExteriorHub/Player thật, input melee và physics-query Hitbox: trung lập, physical hit bị chặn, nguồn team 1 không phải Player, dedup root và hit window, tell trước active, cancel khi Hurt, damage Player, pause inventory, leash, room teardown, HP1/rút lui, cold-load ký ức. Fixture hồ sơ riêng đi qua physical hit → tell → active rồi read-only xác nhận đóng snapshot/hitbox trước lần chạm mới. Recovery qua real expedition thuộc test/root owner riêng.

## Kiểm tra

Đã chạy bằng helper `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/probes/run_probe.ps1`, với `-Project 'C:/Users/Admin/.codex/worktrees/sect-path-repair/hầm ngục'`, save APPDATA/LOCALAPPDATA riêng và Start-Process Hidden. Engine Godot 4.7.2 stable/Compatibility, chỉ headless. Lane đã trả root lúc 07:18 UTC.

| Label / tham số | Kết quả |
|---|---|
| `cultivator_import_r1 -Import -TimeoutSeconds 60` | exit 0, diagnostics rỗng |
| `cultivator_60_r2 -Headless -Script res://tests/cultivator_patrol_test.gd -UserArgs @('--hz=60') -TimeoutSeconds 60` | 60/60, exit 0, diagnostics rỗng |
| `cultivator_120_r2` với cùng script, `--hz=120` | 60/60, exit 0, diagnostics rỗng |

Raw stdout/stderr và RUN_RESULT.json giữ trong từng thư mục label dưới `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/probes/`. `cultivator_source_r2_before.json` và `cultivator_source_r2_after.json` khóa chín file liên quan runtime/test, không có hash thay đổi trong hai lần chạy r2; đây không là full-source freeze của mọi owner. Các thay đổi life migration/fixtures/GameFlow sau checkpoint cần root tích hợp và kiểm tiếp.

Lượt r1 60 Hz đạt 56/56; r1 120 Hz có một assertion sai kỳ vọng đi ngay sau 0,65 giây. NPC thứ hai có lịch chạy ngoài màn hình nên phép kiểm không được giả định trạng thái đang đi khi người chơi đến. Fixture r2 đợi chuyển động tối đa bốn giây trong lịch hợp lệ; không sửa tốc độ/lịch để chiều test. Raw fail vẫn giữ. Cùng r2 thêm kiểm quarantine theo review của root và chặn contact/read-only trong runtime.

Giới hạn: chưa full strict, chưa native readability/animation, chưa cân bằng hoặc playtest tự nhiên. Ray occlusion có guard trong code nhưng chưa có fixture bức tường riêng; focused chứng minh contact trên hai đoạn mặt đường thực và giới hạn leash. Bản sprite nghiêng không được gọi là bộ animation tu sĩ hoàn thiện. Chưa sửa main/save thật, không commit/apply main.

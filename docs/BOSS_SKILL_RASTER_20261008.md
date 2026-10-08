# Boss skill raster — 08/10/2026

Phần này đang ở bản riêng `DgContinue_20261008`. Agent chỉ tạo `scripts/presentation/boss_skill_raster_helper.gd`, test và UID; root ghép hai hook tại SlicePresentation/BossOrbVFX. Root là đầu mối duy nhất ghép bản chính. Manifest nguồn đã kiểm nằm ngoài sản phẩm tại `dungeon_continue/spell_work/BOSS_SKILL_RASTER_PAYLOAD_MANIFEST.json`.

Đã nối PNG của atlas hiện có vào báo đòn, cú quét và bùa tụ năng lượng của Golem/DepthBoss. Hai lớp lightning/ice giữ màu vẽ gốc; bốn Sprite2D được tái dùng trên mỗi boss, tối đa bốn adapter. Cú quét bám hình chữ nhật tác giả trước đòn và đọc trực tiếp `_query_shape`/offset của hitbox khi active; cả hai quad PNG nằm trong phạm vi đó, không quay/nở tạo vùng sát thương giả. Bùa tại socket hiện có và phục hồi đọc `state_time`, tell/active/recovery/FSM thực; không có clock độc lập hoặc callback gây damage. Idle, stagger, cancel và dead ẩn hiệu ứng ngay.

Root nối glyph PNG26px vào tâm quả cầu thực. Giữ hitbox radius9, nguồn/root sát thương, homing, wake12 điểm/72px, cap24 và lifetime do EnemyHazard sở hữu. Helper không thêm light, audio, collider, hazard, proc, RNG hay save. Bỏ adapter riêng phục hồi chủ gameplay đang sống; xóa boss/phòng xóa sprite và listener.

## Kiểm thử thực chạy

- `boss_skill_raster_import_r1`: import headless, exit0, diagnostics rỗng.
- `boss_skill_raster_runtime_r1`: 73/73 tại60Hz, exit0, diagnostics rỗng.
- `boss_skill_raster_final120`: 73/73 tại120Hz, exit0, diagnostics rỗng.

Test dùng actor/FSM và tick vật lý thực cho Golem, DepthBoss phase1 và phase2; không ghi `state_time`. Đã kiểm báo đòn/quét/hồi phục, shape/offset/root/collider resources, real accepted-hit stop với source fixture đang sống, pause/cancel/death, bùa/3–5 quả cầu đúng socket, glyph26px, nguồn sống/lifetime/wake, cap4/fallback/listener và sprite tái dùng. Cả hai cấu hình giữ Body/Hurtbox resources/transforms; source không thêm damage emitter. Toàn bộ raw stdout/stderr/RUN_RESULT được giữ tại `dungeon_continue/probes/<label>`.

```powershell
& 'C:/Users/Admin/Documents/Codex/2026-10-08/dungeon_continue/probes/run_probe.ps1' -Project 'C:/Users/Admin/AppData/Local/Temp/DgContinue_20261008' -Label 'boss_skill_raster_final120' -Headless -Script 'res://tests/boss_skill_raster_test.gd' -TimeoutSeconds 50 -UserArgs @('--hz=120')
```

Agent không chạy GPU hay đo frame-time nhóm boss này. Đây là bằng chứng runtime binding/clock/geometry/lifetime, chưa là bằng chứng đọc đòn rõ, cảm giác trận tự nhiên hoặc chấp nhận hình ảnh trên native. Root tiếp tục kiểm native và gate trước khi ghép.

## Bổ sung sau probe native first-contact (00:29 UTC)

Root probe `boss_clocks_raster_native_r4` xác minh lỗi thật: hitbox active ở state_time0.516666 nhưng helper còn windup, vì Boss._hit_player bắt đầu hitstop trước lượt physics refresh đầu tiên của VFX. Kiểm incoming hurt trước đó không bao phủ outgoing hit ngay khi mở window.

Helper nay nghe `attack_hitbox.contact_detected` sau listener gameplay đã có. Nó chỉ refresh từ AttackSnapshot hiện hành đúng source/root và hitbox active; không tạo damage hoặc tiến clock. Callback này công bố paint active trong chính tick contact dù hitstop vừa bật. Listener được nối một lần và tháo cùng owner/clear. Sửa được giới hạn ở helper; không sửa BossGolem/Hitbox/Feedback.

Final `boss_skill_first_contact60` và `boss_skill_first_contact120`:82/82 mỗi mức, exit0, diagnostics rỗng. Thêm ba ca Golem/Depth1/Depth2 dùng cú quét thực vào Player ở first-active tick: damage20 một lần, hitstop active, paint/root active đã khớp ngay trước lượt physics bị freeze, giữ nguyên hai tick tiếp theo. Các ca incoming-hurt/pause/cancel/geometry/lifetime/caps vẫn đạt. Source freeze tại00:29:38; manifest đã cập nhật helper/test và identity hai hook root. Root còn kiểm native r5 sau sửa; các ảnh/native r4 không là nghiệm thu bản đã sửa.

# Sửa nguồn DamageEvent của fixture — 08/10/2026

Chỉ sửa bốn file test trên bản riêng: SurvivalTestBase, DamageNumbers, Alpha và DeathGround. Không sửa EnemyHitAggro, resolver, actor, terrain hay runner; không lọc diagnostics/hạ gate. Sao lưu trước sửa và manifest tại `dungeon_continue/spell_work/fixture_fix`.

## Nguyên nhân đã xác minh

Campaign trước sửa in31/31 và engineexit0, nhưng strict runner từ chối ERROR `slot >= slot_max` tại EnemyHitAggro.record:26 → BossGolem._on_hit → campaign_test:73. `_damage` dùng ObjectDB ID bịa987654. DamageNumbers baseline đối chứng có34/34/exit0 nhưng bốn ERROR cùng nguồn ở Slime direct/DOT.

Base dùng một Node2D fixture riêng, không là Player, process disabled, sống dưới SceneTree root suốt suite và giải phóng lúc teardown. Nó tồn tại qua việc thay/free current level, như Campaign đang làm; dùng level ID trong trường hợp này sẽ sai lifetime. Source_team/kind/attack/root/window/damage/reaction không đổi. Chủ không là Player giữ ý nghĩa forced damage và không tạo Player aggro/mastery. DamageNumbers dùng room ID đang sống; Alpha giữ Player ID cho đòn team1, dùng run ID cho forced enemy→Player; DeathGround dùng run ID qua retry.

DeathGround còn dùng tọa độ platform550px đã cũ, gây bốn FAIL cùng nhau ở60/120. Room hiện hành có WestGallery top444px. Fixture nay dùng `room.traversal_points.west_gallery` và so corpse với support.y; giữ kiểm tra collision/resources/terrain active và toàn bộ33 assertions, không đổi geometry.

## Kết quả thực chạy

| Suite | 60Hz | 120Hz |
| --- | --- | --- |
| Campaign |31/31|31/31|
| DamageNumbers |34/34 (r2)|34/34|
| Alpha |80/80|80/80|
| DeathGround |33/33|33/33|

Các lượt được nhận đều exit0, diagnostics rỗng. Campaign stress objects2350→2350/resources531→531; DamageNumbers1700→1700/107→107; Alpha4811→4811/519→519. Không GPU hoặc full strict trong nhóm này; root chạy gate mặc định sau freeze chung.

Một lượt DamageNumbers sau source-ID fix có34/34/diagnostics rỗng nhưng process exit0xC0000005 khi kết thúc; giữ `fixture_damage_numbers_fixed60` là REJECTED. Baseline đối chứng không tái hiện crash trong mẫu, nhưng có ObjectDB ERROR; fixed source byte-identical r2/120 sạch. Chưa xác định nguyên nhân crash hoặc chứng minh các crash lịch sử đã sửa. Không thêm sleep/audio workaround để che nó.

PrologueHub/preview_starter_character chỉ dùng số987654 cho Player/internal DOT trong đoạn hiện hữu, không gọi EnemyHitAggro; không sửa hai file này trong phạm vi hẹp. Các ID bịa còn lại được ghi rõ để tránh tuyên bố toàn bộ test IDs đã dọn.

Raw stdout/stderr và RUN_RESULT giữ tại `dungeon_continue/probes/<label>`. Bản chính chưa ghép bởi agent; root là đầu mối duy nhất ghép.

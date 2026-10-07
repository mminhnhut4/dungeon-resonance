# Combat readability — đã áp riêng sau guide/P0

Ba runtime: player_visual_rig, boss_golem_skin, slice_presentation. Player contact tint tối đa0.18 trong clock0.08 giây giữ82% chi tiết texture, không dùng active fullwhite; hurt/damage grace/status/hitstop giữ owner cũ. Cả concept và modular dùng material actor-local. Golem lane320×26 giữ physics; tell bronze/chevron, active orange, recovery muted đọc FSM; hit_resolved accepted positive nonDOT chỉ refresh presentation. Overload contact dùng magenta/lightning; Firestorm/Ice và emitter budgets giữ.

Ba legacy test sửa đúng kỳ vọng fullwhite đã thay bằng bounded tint; không đổi fixture damage/movement hay test registry. Private và main125/125 (affliction38, modular49, procedural38) sạch. Tái dùng178 producer headless60/120 và42 GPU/15 PNG; reviewer chính xem cả15 native. Guard contact clear có chi tiết Player, Golem phase/landing phân biệt; một phần Player bị rương che trong ảnh Golem nên không dùng ảnh đó chứng minh toàn thân. Không thêm combat GPU lặp vì ảnh Guard đủ phạm vi. Producer runner postcheck gặp editor PID null sau khi engine đã exit0; receipt correction xác nhận PID20428 chết, không claim bảo vệ editor không có.

Sao lưu tám file cũ (runtime3/test3/state/day), rollback sáu runtime/test đã diễn tập. Ghép riêng sau guide; đối chiếu hash reader P0, R3 và floor-return. No fullsuite/new120/import/user save. GPU guide ở integration này là lượt UI riêng, không được gộp thành combat playtest.

Giới hạn: Golem body vẫn PNG cũ, không có authored animation mới. AudioManager.play_material_result chưa có runtime callsite và DamageEvent chưa có material contact tag; không claim metal/parry đã nối. cloud_return là dodge hiện có, không tự đổi thành parry. Gameplay clocks/physics/damage/loot/economy không đổi. Natural20–30min pace chưa đo. Native editor crash lịch sử chưa xác định nguyên nhân.

Receipt/diff/backups/evidence local: workspace opening_guide_combat_on_live2091_20261004_27. Không tải asset, export, install, upload hoặc publish.

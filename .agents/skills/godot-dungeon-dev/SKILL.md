---
name: godot-dungeon-dev
description: Phát triển và kiểm tra Dungeon Resonance bằng Godot 4.7.2/GDScript, theo gear-driven classes, bùa cộng hưởng và ownership của dự án. Dùng khi làm game này; không áp luật dự án lên game khác.
---

# Dungeon Resonance hiện hành

Tìm root qua project.godot. Đọc AGENTS.md, docs/PROJECT_STATE.md, docs/PROJECT_ARCHITECTURE.md, quyết định mới liên quan trong docs/DECISIONS.md và nhật ký mới nhất. Quyết định/GDD hiện hành thay các đề xuất seed của skill cũ; chỉ dẫn người dùng mới nhất ưu tiên. Trao đổi tiếng Việt.

Main là scenes/maps/prologue_hub.tscn; Godot 4.7.2, Compatibility. Khi được giao thiết kế, giữ đúng mức thiết kế; khi giao triển khai, hoàn thành binding runtime và kiểm phù hợp. Kiểm nguồn/owner, sao lưu, dùng checkout riêng trước sửa. Giữ patch khác. Một integrator merge, một kiểm tra GPU nặng tại một thời điểm, save QA riêng; ưu tiên CLI/Hidden.

## Ranh giới cần giữ

- GearItem runtime sở hữu UID/quality/+level/affix; Definition Resource chỉ đọc. Quality được phép ảnh hưởng damage/slot/proc. Cường hóa đã chốt tối đa +12, mỗi mốc +3% damage nền, thành công 100%; không tự cân bằng giá/loot mới.
- Gear quyết định class/moveset. Ô Bùa/cộng hưởng là cơ chế tấn công chính. Resolver match đủ exact multiset, giữ duplicate; empty recipe basic, bộ lỗi không fallback/subset. Key recipe trùng là lỗi catalog.
- Controller commit snapshot theo Aim 360°. Đổi gear/bùa sau không sửa đạn đang bay hoặc reset cooldown. RuneData/catalyst definition không giữ HP/clock/ownership.
- Damage qua Hitbox/Hurtbox/DamageEvent/Resolver/Health. Root/parent/visited/proc budget đi xuyên child/DOT; giữ cap 64 thực thể, chain 2 và room lifetime. Field dữ liệu chưa có consumer thì chưa là feature; hiện cast tiêu 30 energy ở controller, recipe energy_cost không quyết định chi phí thực.
- Motor/controller/hai FSM Player đã ổn định; dùng subclass/component/interfaces. Giữ Movement55/Combat100/Resolver20. Animation manual seek đọc combat clock, không method track điều khiển damage/hitbox. Bone WeaponSlot là sprite trang trí; physical socket/hurtbox ở cây gốc.
- Giữ foot pivot/full PNG alpha/facing theo Aim và Compatibility glow trên world canvas layer 0. Art-only giữ collider/transforms. Golem cuối dùng UV mesh tĩnh; không phục hồi nhánh Polygon2D đã crash từ patch cũ.
- Audio room-owned, tối đa 16 voice; giữ light/VFX budget và cleanup. Wizard tắt thủ công; PNG/SpriteFrames không cần Aseprite CLI.
- Save qua owner profile/writer; giữ numeric seal2/float64/UID ledger/byte guard/rollback. Không serialize Node hoặc tạo writer thứ hai. Native crash lịch sử/layout800/save peaks còn giới hạn; đọc state/code trước claim fix.

## Đọc theo công việc

[project-workflows](references/project-workflows.md) trỏ hướng dẫn map/bùa/nhân vật/QA/tiến độ/prompt trong repo. Chỉ đọc phần liên quan. Author content qua owner hiện hữu; architecture proposal không tự cho phép migration thư mục.

Trước tối ưu, tái hiện và đo bottleneck/frame-time, phân biệt hitstop chủ ý. Tests logic không chứng minh FPS/game feel. Kiểm input/loadout/hitbox/teardown thực và ảnh native khi sửa visual; giữ raw ERROR/WARNING/exit. tests/run_tests.ps1 mặc định strict kiểm import/editor/addon/gameplay; GameplayOnly chỉ chẩn đoán. Tận dụng evidence cũ đúng checkpoint, không chạy lại gate lớn không liên quan để lấy số.

Kết phiên báo nguyên nhân đã xác minh, files, lệnh/kết quả thật, bằng chứng, private/main/commit và lỗi còn lại. Thiết kế/asset chưa nối runtime không Complete. Cập nhật docs trạng thái/quyết định khi cần; nhật ký chỉ ghi sự kiện/lỗi thực có ý nghĩa. Không tự publish/export Steam/cài phần mềm/đổi bảo mật nếu task chưa giao.

# Skill hỗ trợ thành viên làm game

Skill portable ở [SKILL.md](../../.agents/skills/godot-dungeon-dev/SKILL.md), dành cho Dungeon Resonance hiện hành. Bản này cập nhật quality/gear/+level và route runtime; không mang luật seed cũ mâu thuẫn dự án.

## Dùng với Codex

Mở Codex tại root đã clone. AGENTS ưu tiên skill trong repo; nếu client chưa discover, ghi: “Đọc .agents/skills/godot-dungeon-dev/SKILL.md rồi thực hiện task DR-xxx”. Nếu muốn cài cá nhân, chép cả thư mục godot-dungeon-dev vào thư mục skills của Codex trên máy thành viên; nếu đã có skill trùng, backup/so sánh trước, không ghi đè skill riêng. Không cần plugin/CLI art mới.

Skill giúp AI đọc state/decisions, trace owner/runtime, triển khai và kiểm theo scope. Nó không cấp quyền merge/publish và không chứng nhận game mượt. Không gửi save thật/token vào prompt. Với công cụ AI khác, vẫn đọc AGENTS và guide module; không giả định nó tự nhận skill Codex.

## Prompt mẫu để copy

**Map hiện hữu:** “Đọc AGENTS, PROJECT_STATE, DECISIONS và MAP_GUIDE. Nhận DR-008 chỉ polish art P02 trên nhánh riêng, giữ collider/transforms/anchor/cửa. Hash/chụp phần liên quan trước sửa. Bind vào ExteriorRoom thật; kiểm H00→P02→H00 với save QA. Báo files/ảnh/exit và phần chưa ghép.”

**Bùa:** “Nhận DR-006, trace inventory→Tab→exact resolver→snapshot→executor→damage→presentation. Kiểm Phong+Hỏa từ main, ảnh windup/body/contact/recovery, đổi bùa trong flight và cleanup. Giữ balance/UID/cap. Chỉ một kiểm tra GPU nặng mỗi lần. Báo kiểm chứng thật.”

**Nhân vật:** “Nhận DR-007 chỉ audit/polish AncientGuard đã có. Đọc CHARACTER_GUIDE và BaseEnemy/WorldEnemyData. Đồng bộ frames với tell/active/recovery/hitbox thật; giữ Player FSM và roster. Kiểm Hurt/Dead/cancel/room free; giữ raw ERROR/WARNING; PR chờ integrator.”

**Khựng:** “Nhận DR-001. Đúng4.7.2/Compatibility, main thật và save QA. Tái hiện giao chiến; đo frame-time/hitstop/mastery-save cùng seed trước/sau. Chỉ sửa bottleneck đã đo; giữ seal2/rollback/flush/UID. Không lấy headless làm bằng chứng FPS.”

**Cuối phiên:** “Ghi task owner/base commit, thay đổi, lệnh/exit/diagnostics thật, ảnh/frame-time, private/main, lỗi còn lại và bước tiếp. Cập nhật PROJECT_STATE/BACKLOG; nhật ký chỉ sự kiện dự án có ý nghĩa.”

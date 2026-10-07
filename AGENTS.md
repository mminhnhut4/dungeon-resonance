# Chỉ dẫn cho dự án game hầm ngục

Đây là dự án game hành động 2D offline hướng tới Steam, dùng Godot 4/GDScript. Project có Alpha/campaign, gear-driven moveset, 5 nguyên tố/10 cặp cộng hưởng, cổ vật, boss, loot, survival, Sanctuary/save, ánh sáng/VFX/SFX và Player Skeleton2D. Đọc `docs/PROJECT_STATE.md`, `docs/PROJECT_ARCHITECTURE.md`, `docs/MILESTONE_POLISH_REPORT.md` và phần liên quan trước khi tiếp tục. Chạy `tests/run_tests.ps1` mặc định: gate strict kiểm cả import/editor/addon/gameplay; lỗi addon shutdown cũ đã được sửa và kiểm chứng. Không lọc ERROR/WARNING. `-GameplayOnly` chỉ là chế độ chẩn đoán bỏ addon editor gate, không là gate hoàn chỉnh.

Khi tác vụ liên quan thiết kế hoặc phát triển game này, dùng skill `godot-dungeon-dev`. Ưu tiên bản portable theo luật hiện hành tại `.agents/skills/godot-dungeon-dev/SKILL.md` trong checkout; nếu chưa có, dùng bản cá nhân tại `C:/Users/Admin/.codex/skills/godot-dungeon-dev/SKILL.md`. Đọc entrypoint, rồi chỉ đọc reference cần cho tác vụ. Nếu skill không xuất hiện trong danh sách của phiên làm việc, có thể đọc đúng file này; không cần cài thêm plugin. Thành viên mới đọc `docs/team/START_HERE.md` và nhận owner trong `docs/team/BACKLOG.md` trước sửa.

Đọc `docs/PROJECT_STATE.md` và phần liên quan của `docs/DECISIONS.md` để tiếp tục công việc. Khi có GDD hiện hành trong project, GDD đó thay thế các đề xuất khởi điểm của skill. Chỉ dẫn mới của người dùng luôn có ưu tiên.

Yêu cầu hiện hành: Ô Bùa/Cộng hưởng, gear-driven classes; yêu cầu mới Quality Tiers cho phép quality ảnh hưởng damage/slot/proc, thay luật cũ cấm nâng chỉ số. Quality thuộc GearItem runtime, không sửa definition dùng chung. Kiểm soát proc/root/entity lifetime. Recipe rỗng cho basic khi tháo bùa; tổ hợp lỗi không fallback. Melee/cast theo chuột 360°. Player Controller/motor base và 2 FSM giữ logic đã ổn định; nội dung mới dùng subclass/interfaces/components, giữ Movement55/Combat100/Resolver20. Thông số prototype chưa là cân bằng cuối.

Rig Visuals đọc Weapon/Cast clocks bằng manual seek; không đặt method track điều khiển damage/hitbox. WeaponSlot trong xương là slot sprite trang trí; gameplay WeaponSocket/Hitbox và Hurtbox ở cây vật lý cũ. Scene rig độc lập có sprite trống; Player instance dùng concept PNG; atlas từng bộ phận chưa có. Wizard cài đặt nhưng tắt thủ công; PNG/SpriteFrames không phụ thuộc Aseprite CLI. AudioManager quản lý quit/mixer và room-owned voices; giữ entity/light/voice budgets khi thêm nội dung.

Yêu cầu Art Integration mới thay PNG tạm của Player bằng concept full PNG: full-sprite overlay có pivot chân và mask alpha khi render, không đổi nguồn PNG. Visual lật theo con trỏ dù hướng chạy khác; hướng commit damage vẫn do PlayerAim/Weapon. Idle dùng Tween1→1.03→1 trong1.2s với pivot chân cố định. FoyerArt chỉ skin Polygon2D của bục/sàn và thêm cột/đèn; tuyệt đối giữ collision resources/transforms. Glow dùng WorldEnvironment BG_CANVAS SDR với max canvas layer0, giữ HUD riêng và renderer Compatibility. File nguồn staging lưu tại docs/verification/asset_pipeline_sources/staging_archive do xóa bị auto-review từ chối; docs/.gdignore loại toàn bộ evidence khỏi import.

Trao đổi bằng tiếng Việt. Khi người dùng yêu cầu GDD hoặc kiến trúc, giữ đúng mức thiết kế; khi giao triển khai feature, hoàn thành tích hợp và kiểm tra phù hợp. Ghi rõ điều đã chạy kiểm tra và điều còn chưa xác minh.

Người dùng muốn dùng màn chính để xem phim và để Godot ở màn phụ. Ưu tiên sửa file và chạy Godot CLI/headless ở nền; nếu dùng Start-Process cho kiểm tra, dùng WindowStyle Hidden. Hạn chế thao tác chuột/phím và đổi focus. Computer Use nhắm cửa sổ, không cô lập thiết bị nhập theo màn hình; không hứa sẽ khóa mọi thao tác vào một màn.



## Nhật ký vấp ngã

Khi bắt đầu tác vụ, đọc [index nhật ký](<nhật ký vấp ngã/README.md>) và bài mới nhất để giữ đúng ý người dùng và tránh lặp lỗi đã gặp. Khi có sai lệch giao tiếp đáng kể hoặc lỗi thực tế, ghi một mục ngắn gồm ý người dùng, lỗi, nguyên nhân đã xác minh (chưa rõ thì ghi chưa rõ), trạng thái sửa và cách tránh lặp; cập nhật index khi thêm ngày. Chỉ ghi sự kiện dự án, không chép toàn hội thoại hoặc tạo log tool rác. Giữ phân biệt bản riêng đã kiểm thử với thay đổi đã áp dụng bản chính; chọn kiểm tra phù hợp phạm vi và chỉ dẫn mới của người dùng.

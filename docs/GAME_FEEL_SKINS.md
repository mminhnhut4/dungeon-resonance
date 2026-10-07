# Camera, debug overlay và hai ngoại hình Player

Ngày 2026-10-01. Skill: godot-dungeon-dev; xử lý ảnh qua imagegen.

- PlayerCamera gắn dưới Player: zoom 1.35; lookahead = hướng con trỏ ×0.15, giới hạn độ dài vector 40px; nội suy exponential với tốc độ 8/s. Giới hạn phòng 32..1248 ×0..720. Camera dùng position, CombatFeedback tiếp tục sở hữu offset/rung camera. Camera phòng cũ giữ làm fixture, không hoạt động trong gameplay. Hub giữ camera menu cố định.
- Phím backtick/tilde (**` / ~**, bên dưới Esc) bật/tắt debug, mặc định tắt mỗi run. F1 vẫn là sự kiện Quản trò của phòng test. Nhãn thế giới, HP chữ của Slime/bia, các hint F5–F8, thông số năng lượng/stress/stagger đều nằm trong overlay. Giữ Player HP, Boss HP/tên Boss, floating damage và nội dung modal túi đồ/chế tạo/kết quả. Registry theo room, dùng WeakRef và gỡ ngay khi nhãn rời cây; không giữ tham chiếu loot đã hết hạn.
- WeaponDefinition.visual_archetype: auto/swordsman/mage. Auto dùng attack_kind: melee → Kiếm Sĩ, ranged → Thuật Sĩ. PlayerVisualRig đọc definition hiện tại, đổi overlay khi texture thay đổi; controller/motor/hitbox không nhận nhánh theo tên vũ khí. Đại kiếm, kiếm cổ, dao găm/song dao dùng Kiếm Sĩ; trượng dùng Thuật Sĩ. Bùa khảm không tự đổi ngoại hình melee thành mage.
- Hai sprite giữ chiều cao silhouette 42px, cùng pivot chân collider; mirror theo con trỏ, idle breathing và flash hiện hữu. Full-body overlay vẫn chưa có animation deform từng bộ phận. PNG trong suốt được giữ nguyên pixel/alpha khi render, không xóa tiếp phần vải sáng; mỗi nguồn chỉ có một ImageTexture cache thuộc lifetime Texture2D.

## Tài nguyên

- `res://assets/sprites/player/swordsman_reference.png`: nguyên bản ảnh người dùng, đổi tên/di chuyển từ D:/dowload/player_swordsman_sheet.png.png. Bản sao bảo toàn tại docs/verification/swordsman_sources/player_swordsman_sheet.png, SHA-256 trùng khớp; docs bị loại khỏi import.
- `res://assets/sprites/player/player_swordsman.png`: nhân vật nhìn nghiêng phải, nền alpha thật, lấy qua công cụ imagegen từ ảnh tham chiếu. Đây là xử lý ảnh bằng AI, không phải crop bảo toàn pixel tuyệt đối của sheet; giữ ảnh tham chiếu để đối chiếu hoặc thay bằng cutout thủ công về sau.
- `res://assets/sprites/player/player_concept_full.png`: Thuật Sĩ hiện hữu, giữ nguyên source PNG và alpha mask runtime.

## Kiểm tra

Suite game_feel bổ sung camera cap/smoothing, tách shake khỏi follow, phím debug, nhãn spawn/despawn, modal/floating text, alpha/vải sáng, năm loại gear, pivot, cache qua 40 vòng đổi skin, collider và Boss UI. Suite PlayerArt35 vẫn kiểm nguyên bản Thuật Sĩ bằng fixture riêng; Combat100 giữ camera cố định của baseline để các so sánh float chính xác không phụ thuộc zoom mới. Không bỏ assertion cũ.

Gate phát hiện hai Resource kiếm/dao đã thiếu thông số ngoài phạm vi mỹ thuật: Dao Găm không có crit0.35, cả hai thiếu reach/stagger. Đã giữ bản trước sửa trong verification/weapon_data_before_repair, bổ sung reach68/sweep100/stagger10 cho Kiếm Cổ, reach40/thrust/stagger4 và crit0.35 cho Dao Găm; timing/damage/shape cũ giữ nguyên. Reach/crit theo contract test đã có, các trị số sweep/stagger là thông số prototype được ghi rõ, không khẳng định khôi phục byte-for-byte Resource cũ. Những tệp khác có hash khác manifest lịch sử chỉ được kiểm, không tự ghi đè.

Import và rig-editor gate bật thêm --verbose để giữ đầy đủ dữ liệu chẩn đoán. Không đổi các bước kiểm hay lọc WARNING/ERROR; đã quan sát native crash 0xC0000005 ở một số lượt editor chẩn đoán nhưng chưa xác định root cause. Một lần pass không chứng minh loại bỏ vĩnh viễn lỗi native editor này.

Probe tạm tắt kiểm cập nhật editor vẫn có native crash; setting đã khôi phục =1 như ban đầu, không dùng cách này trong runner. PlayerCamera hiện chỉ phụ thuộc Node2D/PlayerAim thay vì lớp Player trực tiếp; ba probe đóng rig editor sau thay đổi đều exit0. Đây là giảm coupling và bằng chứng hậu kiểm, chưa đủ quy nguyên nhân native crash cho một dependency cụ thể.

Gate hiện hành: docs/verification/game_feel_strict_suite.log. GPU preview: game_feel_preview và game_feel_weapons_boss_preview; ảnh art_foyer_idle_right/left, art_player_running/jumping/slash/cast, polish_trail_* và polish_boss_firestorm. Benchmark finite ở Tiền Sảnh và Boss: game_feel_foyer_60/120, game_feel_boss_60/120 stdout/stderr; FPS render thật trên RTX5080, không suy từ headless. Các thử import/editor gặp native exit 0xC0000005 được giữ như bằng chứng điều tra; kết quả gate cuối phải báo riêng, không che exit code.

Kết quả gate cuối: 93 script/18 scene, 2.027 assertion executions, 0fail. Movement55/Combat100 ở cả60/120Hz, Resolver20; game_feel35 ở mỗiHz. Lượt render thật Tiền Sảnh60.001/119.979FPS, Boss60.000/119.999FPS; các GPU process kết thúc sạch WARNING/ERROR. Native editor issue đã quan sát ở lượt trước vẫn được ghi như giới hạn điều tra, không bị lọc khỏi gate.

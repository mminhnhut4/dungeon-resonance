# Tích hợp mỹ thuật

## Môi trường Tiền Sảnh

`FoyerArt` là adapter trình diễn, không tạo hoặc sửa va chạm. Root gọi `rebuild(owner_world)` sau khi dựng phòng Tiền Sảnh hoặc sân thử. Khi tháo component, visibility gốc của các Polygon2D được khôi phục; khi đổi phòng, weak reference không giữ lại physics body đã hủy.

Nguồn `assets/environment/tilesets/dungeon_stone_tileset.png` giữ nguyên PNG 1248×832 do người dùng cung cấp. Sheet không có grid đều và nền đen opaque; năm Resource `AtlasTexture` trong `assets/environment/tilesets/regions/` lấy các vùng riêng, bật `filter_clip`:

| Crop | Rect2 (x, y, width, height) | Sử dụng |
|---|---|---|
| foyer_jade_stone_a | 29, 152, 109, 111 | Bục đá có khe ngọc, hàng trên |
| foyer_jade_stone_b | 141, 393, 107, 109 | Bục đá có khe ngọc, hàng giữa |
| foyer_jade_stone_c | 253, 641, 105, 111 | Bục đá có khe ngọc, hàng dưới |
| foyer_floor_stone | 29, 57, 109, 95 | Sàn đá xám, ghép sprite hữu hạn |
| foyer_chained_talisman_column | 1082, 549, 88, 216 | Trụ có bùa giấy và dây xích, cắt theo thân trụ |

Shader `foyer_stone_key.gdshader` xóa padding gần đen tại runtime, giữ nguyên file nguồn và ánh sáng trên mặt đá. Kênh xanh chiếm ưu thế được nâng mức sáng để khe ngọc phản ứng với glow của WorldEnvironment; vật liệu xám/cột tắt tăng sáng ngọc. Đây là xử lý hình ảnh trình diễn, không thay đổi bùa hoặc DamageEvent.

Sáu bục lấy collider hiện hữu làm nguồn tọa độ: (400,560), (760,470), (1000,540), (240,457), (140,374), (106,227). Mép trên sprite trùng mép trên CollisionShape2D; bevel hình vẽ kéo xuống dưới, không tăng vùng đứng. Test room có bục đầu chênh 2px được nhận diện theo tolerance, những body không khớp giữ nguyên hình vẽ. Sàn chính ghép 12 sprite; sàn chia đôi của sân thử giữ nguyên khe vực.

Hai trụ rộng 48px/cao 118px đặt ở tâm x=1145 và 1235, chân y=640; trụ phải đảo ngang, đối xứng qua cửa khóa x=1190, mép phải không vượt tường x=1264. Có tối đa tám PointLight2D xanh ngọc, texture dùng chung, không shadow/particle. Component không sửa Door lock hay nhãn hướng dẫn.

Suite `tests/foyer_art_test.gd` kiểm crop/texture share, mép hình vẽ, hình dạng/transform/mask collider bất biến, đối xứng cửa, rebuild/restore và lifetime ánh sáng. Suite có30checks tại cả60/120Hz.

## Player và điểm tựa chân

`scenes/actors/player/player.tscn` gán `concept_body_texture` từ `assets/sprites/player/player_concept_full.png`. `PlayerVisualRig` tạo một Sprite2D full-art ngoài Skeleton, trong `ConceptFootPivot`; body sprite cũ bị ẩn và chỉ làm adapter flash/flip cho controller hiện hữu. Native Texture metadata giữ một mask cache theo lifetime nguồn, không giữ Script hay tham chiếu ngược về nguồn.

Nguồn có nền trắng opaque và boot bị cắt sát mép đáy. Flood mask runtime chỉ bỏ những vùng gần trắng nối với biên ảnh, giữ mặt nạ trắng bên trong silhouette; file PNG/hash gốc không đổi. Điểm giữa boot ở hàng thấp nhất được đặt đúng đáy `BodyCollision`. Khi `flip_h` đổi, offset X được bù theo chiều rộng ảnh để không dịch điểm tựa. Chiều cao silhouette mặc định42px; dùng phần chân nhìn thấy trong ảnh, không tự tạo thêm chân ngoài nguồn.

Visual nhìn về chuột với deadband0,5px quanh tâm; hướng chạy và hướng damage đã commit vẫn do các component gameplay quản lý. Idle chạy Tween1→1,03→1 trong1,2s, pivot tại chân. Rời Idle/đánh/niệm/chết thì kill và reset; hit-stop tạm pause. Flash/i-frame tint truyền từ body adapter sang art. Năm bone clip vẫn sẵn cho atlas từng bộ phận, chưa deform ảnh concept toàn thân thành chuyển động từng chi.

`tests/player_art_test.gd` có35checks tại cả60/120Hz: alpha/mặt nạ/source hash, cache, collider origin, mirror, foot pivot, Tween/hit-stop/cancel và tám vòng teardown. `tests/player_rig_test.gd` giữ52checks cho skeleton/pose/clocks/hitbox/hurtbox.

## Glow và preview thật

`DungeonAtmosphere` giữ một WorldEnvironment/BG_CANVAS trên world layer0, glow threshold0,65, intensity0,35, bloom0,04. Các lớp HUD cao hơn không qua bloom. Godot4.7 Compatibility hỗ trợ SDR glow; [Environment](https://docs.godotengine.org/en/stable/classes/class_environment.html) và [2D glow](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html#using-glow-in-2d) là nguồn API.

`tests/preview_art.gd` chạy preview hữu hạn trên màn phụ, input giả lập trong chính tiến trình Godot và profile kiểm chứng riêng. Đã render và xem `art_foyer_idle_right.png`, `art_player_slash.png`; sáu capture gồm idle trái/phải, chạy, nhảy, chém và phép được lưu tại docs/verification. Preview có kiểm Player di chuyển thật, exit sạch. `art_glow_on.png` / `art_glow_off.png` được chụp khi freeze scene/particle; phép so sánh pixel bật/tắt glow đạt, xác nhận hậu kỳ có tác động trên renderer thật.

Chạy lại preview:

```powershell
./tools/run_render_check.ps1 -Script res://tests/preview_art.gd -Name art_preview
```

Không đóng editor Godot đang mở hoặc thay file save chơi chính. Bộ kiểm đầy đủ và GPU benchmark cuối được ghi tại [Polish Report](MILESTONE_POLISH_REPORT.md) và [verification summary](verification/polish_test_summary.json).

# Xây và sửa map trên nguồn hiện hành

## Chọn đúng đường runtime

Main `scenes/maps/prologue_hub.tscn` → `scripts/hub/game_flow.gd` → `scripts/world/exterior_hub.gd` (ExteriorHub kế thừa PrologueHub). Cửa **Đường Bộ** đi ngoại cảnh; cổng đi ải đưa WorldCampaign. Dự án chưa có workflow paint TileMap chung cho toàn bộ map: nhiều collider/đường/cửa được dựng bằng code. Concept tileset là sheet crop, chưa phải bộ ô lưới playable tự động.

| Loại | Nơi author thật | Trách nhiệm |
|---|---|---|
| Ngoại cảnh8phòng O01/O02 | `scripts/world/exterior_route_catalog.gd` | RoomID/region/title, layout heightfield, route/anchor/link hai chiều |
| Hình học ngoại cảnh | `scripts/world/exterior_room.gd` | `configure`, `_author_details`, collider solid, bounds, gate, floor_y |
| ArtP01 | `scripts/presentation/pilgrimage_presentation.gd` | Skin/grounding/occlusion; không ghi actor velocity/collision |
| Hầm ngục | `scripts/rooms/dungeon_room.gd` | Nền ởy640, bậc/shelf/alcove, cổng khóa, traversal_points |
| Vòng phòng/encounter | `scripts/rooms/dungeon_run.gd`, `linear_campaign.gd`, `world_campaign.gd` | Giữ Player/session, dọn room, wave/roster/boss/reward/return |

## Bài thực hành1: polish một đoạn P02 đang có

1. Nhận task map/art hiện hữu; ghi rõ **art-only** hay đổi geometry. Tạo nhánh, chụp collider/traversal trước thay đổi.
2. Mở `ExteriorRouteCatalog.layout(&"o01_p02", MAIN)`. `start` và `beat.y` là cao độ tương đối; `beat.x` là chiều dài ngang. `ExteriorRoom._y(z)` chuyển thành `BASE_Y - z*H`, vớiH 115px. `configure` tự kéo run dốc cho góc≤SAFE_ANGLE 10°. Thay ảnh không thay `beats`.
3. Thêm skin ở presentation/nhánh `_author_details` đúngroom ID. Đặt prop trên `floor_y(x)`; đừng dùng chiều cao ảnh để quyết định collider. Trang trí `_art` không có collision; `_solid` tạo StaticBody2D+CollisionPolygon2D thật.
4. Giữ west/east anchor, các interaction/cổng SC01, `bounds` và links. Nếu thay layout, kiểm anchor nằm mặt phẳng đủ rộng và không chôn actor. Hướng main đi được hai chiều bằng đi bộ; jump/dash là nhánh tùy chọn, không bắt buộc để qua tuyến chính.
5. Từ main đi **H00→P01→P02→P03→P02→P01→H00**, đi qua tuyến bình thường và corridorSC01 nếu ảnh hưởng. Kiểm lever P03/cổng P02 mở thật, chuyển phòng không reset HP/energy/cooldown hay nhân inventory.
6. Headless `tests/exterior_route_test.gd`, rồi ảnh/native traversal có chứng cứ hành vi. Restore geography trong cùng phiên và cold-load nếu sửa route/anchor/save. Physics60/120 khi đổi hình học/movement seams.

Muốn thêm room ID về sau cần cập nhật `ROOMS`, region/layout/link/valid_anchor và geography validation/tests; đây là scope mới cần duyệt, **không thực hiện trong task polish hiện tại**. Không đổi ID đã lưu vì đổi tên hiển thị.

## Bài thực hành2: sửa shelf trong tầng hiện hữu

1. `DungeonRoom._ready()` dựng `_block` nền và `_shelf` bậc/galley. `_block` dùng center/size; `_shelf` dùngRect2 và one-way flag. Kiểm overhead với Player và quái cao nhất, giữ combat spiney640.
2. Nếu thêm art cho shelf/cửa, gắn visual con, giữ CollisionShape2D/resource/transforms. FoyerArt chỉ skin Polygon2D bục/sàn; art không quyết định khóa cổng.
3. Nếu sửa geometry, cập nhật `traversal_points` thật và test đường đi. Spawn của `DungeonRun.enter_room` và roster `WorldCampaign._spawn_wave` phải trên sàn an toàn; collider mới không kẹp spawn hoặc che tell.
4. Dọn qua owner có sẵn: `survival.clear_room`, feedback reset, executor/loot clear, room queue_free; không dựng Player/GearSession thứ hai ở scene map.
5. Kiểm `tests/world/dungeon/dungeon_layout_test.gd`, `opening_dungeon_route_test.gd`, `floor_return_test.gd` khi seam tương ứng đổi. E ở exit phải đi tiếp/về/nhặt tiếp đúng, không grant Golem proof khi retreat.

Một scene preview đẹp chưa là map hoàn tất. PR cần chỉ route từ main, collider overlay trước/sau, vị trí spawn/door, actual physics traversal, teardown và các giới hạn chưa thử. Mọi lệnh kiểm dùng [QA save riêng](QA_AND_HANDOFF.md).

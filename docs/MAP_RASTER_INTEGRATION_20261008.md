# Ảnh nền map hiện có — 2026-10-08

Mốc owner spell/map 23:46 UTC ngày 07/10/2026: chỉ triển khai trên private `C:/Users/Admin/AppData/Local/Temp/DgContinue_20261008`. Root quản lý PNG nguồn, hai callsite, native GPU serial, sao lưu và ghép main. Subagent không sửa main và không chạy GPU.

## Runtime đã nối

`scripts/presentation/existing_map_raster.gd` là một adapter room-owned, tối đa một Sprite2D. Bank lazy có whitelist đúng 8 Texture2D, không giữ actor/room/context, không sinh light/audio/collision hoặc vòng process. Không dùng RNG/save/gear/quest writer. Tất cả PNG nguồn hiện có kích thước thực **1536×1024**, giữ nguyên file ảnh do root tạo.

| ID / stage hiện có | PNG |
|---|---|
| P03 `o01_p03` | `assets/environment/exterior/rendered_v2/p03_shrine.png` |
| P04 `o01_p04` | `assets/environment/exterior/rendered_v2/p04_terraces.png` |
| B01 `o02_b01` | `assets/environment/exterior/rendered_v2/b01_water.png` |
| B02 `o02_b02` | `assets/environment/exterior/rendered_v2/b02_square.png` |
| B03 `o02_b03` | `assets/environment/exterior/rendered_v2/b03_post.png` |
| B04 `o02_b04` | `assets/environment/exterior/rendered_v2/b04_shipyard.png` |
| WorldCampaign stage2 hiện hữu | `assets/environment/backgrounds/campaign_secret_v2.png` |
| WorldCampaign stage3 hiện hữu | `assets/environment/backgrounds/campaign_mutants_v2.png` |

API: `attach_exterior(room)` và `attach_campaign(room, stage, legacy_scope)`. Root gọi từ cuối ExteriorRoom.configure và SlicePresentation.rebuild sau atmosphere.rebuild, với `legacy_scope = atmosphere.room_art`. WorldCampaign stage1/4 và P01/P02 giữ đường art hiện có. Không mở roomID/route/stage mới.

ExteriorRoom.configure thực chạy trước SceneTree. `_ensure_sprite()` cho bind chuẩn bị được trước `_ready`; `_ready` idempotent không tạo Sprite thứ hai hoặc xóa trạng thái đã bind. Attach lặp lại dùng cùng owner/Sprite.

Ảnh được scale uniform kiểu cover và center-crop trong source region tới đúng bounds của room. Sprite z=-30, region clip bật; không bleed ngoài authored camera bounds và không sửa transform/collider của room. Campaign dùng canvas/bounds hiện hành 1280×720. Mỗi biến thể hình học đọc bounds/data của chính instance; không dùng chiều cao ảnh để quyết định đường đi.

## Hình học và foreground

- Exterior chỉ giấu **Polygon2D con trực tiếp** ở z=-20/-18 vốn do `_background` dựng. Giữ water z=-12, square plane z=-13, props/roof/boat/lamp/shrine, terrain Line2D, door/interaction labels và mọi paint dưới collider.
- Campaign chỉ giấu `DungeonBackdrop` trong scope RoomAtmosphere do root truyền. Giữ FoyerArt và DungeonArchitecture, torches, platform/floor textures, chest/barrier và cửa khóa.
- Clear/tháo adapter khôi phục đúng trạng thái visible trước đó, bỏ owner ID/Sprite texture reference. Static bank còn đúng 8 resource theo thiết kế; room teardown không giữ node/actor.
- Audit source hiện hành: hai tường DungeonRoom chỉ là strip rộng 32px, floor dưới y640 cao 80px và door rộng 24px. DungeonArchitecture thêm alcove, arch/stringer/column ở phía trước, không có polygon tường kín toàn canvas che PNG. Native vẫn cần kiểm occlusion thực.

## Kiểm thử thực chạy

Runner `C:/Users/Admin/Documents/Codex/2026-10-08/dungeon_continue/probes/run_probe.ps1`, Project private, save/profile QA cô lập, không lọc diagnostics. Raw logs và RUN_RESULT tại `probes/<label>`.

| Label | Kết quả |
|---|---|
| `existing_map_raster_import_r1` | Headless import đúng 8 PNG/new class; exit0; diagnostics [] |
| `existing_map_raster_runtime_r1` | 103/103, physics60Hz; exit0; diagnostics [] |
| `existing_map_raster_final120` | 103/103, physics120Hz; exit0; diagnostics [] |

Test mới `tests/existing_map_raster_test.gd` thực dùng builders và hooks hiện hữu của 6 ExteriorRoom + WorldCampaign stage2/3. Kiểm collider node/resource IDs, shape nội dung/radius/size/polygon, transforms/layers/masks/one-way/disabled, surfaces/anchors/interactions/jumps/traversal, Sprite crop/scale/bounds, labels/rope/foreground/props, seed state, FoyerArt texture IDs/transforms/individual visibility, cap8 cache và tháo room/run.

Physics queries kiểm các segment của từng route trước/sau binding. Một Player scene thật nhận `move_right/move_left` đi ngắn hai chiều trên dry west approach của đủ 6 phòng. P02 bridge/SC01 nằm ngoài ảnh mới nhưng vẫn kiểm rope và gate đóng→mở→đóng; campaign door đổi visibility/collider theo lock thật. Đây là fixture hẹp, không phải full-route tự nhiên hoặc playtest hoàn chỉnh.

## Giới hạn và bước tiếp

Chưa có native screenshot/readability/occlusion hoặc frame-time của những map này từ subagent. Xem file nguồn P04/secret và import sạch chỉ xác minh asset/integration, không xác minh trải nghiệm đã hoàn thiện. Uniform cover có crop nên landmarks/layering cần xem tại camera anchor thật; background không làm điểm tương tác.

Không chạy lại toàn bộ exterior_route_test/campaign tests hoặc strict suite để lấp thời gian; không đổi geometry/mechanics. Root cần chạy native matrix old maps/campaign, kiểm thấy foreground/platform/labels/actors và biến thể route, rồi gate payload chung trước merge. Chỉ root ghép main sau sao lưu, giữ save thật và rollback.

Owner thêm mới: `existing_map_raster.gd`/UID, `existing_map_raster_test.gd`/UID và báo cáo này. Root hooks/8 PNG không nằm trong quyền sửa của subagent. Manifest SHA256 tại `spell_work/MAP_RASTER_PAYLOAD_MANIFEST.json`. Hoàn tác runtime bằng khôi phục hai hook root từ backup; class mới không đổi state/save schema. Các file nguồn của nhóm spell trước vẫn đóng băng.

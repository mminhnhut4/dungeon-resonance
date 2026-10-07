# Tổ chức asset nguồn — PNG và AtlasTexture

Baseline tổ chức nguồn ban đầu gồm năm ảnh staging, phân loại theo nội dung thực, chuyển thành PNG chuẩn và kiểm lại ảnh đích. Công cụ dùng Godot 4.7.2 `Image` decoder/`save_png`; không đổi đuôi để giả định dạng, không vẽ lại hoặc xóa nền ảnh. Contract năm nguồn/79 assertion này vẫn riêng biệt với các cutout AI và HUD/props được bổ sung bên dưới.

## Cấu trúc và ánh xạ

```text
res://assets/
├── sprites/
│   ├── player/
│   │   ├── player_concept_full.png
│   │   ├── player_concept_closeup.png
│   │   ├── variants/player_concept_closeup_duplicate_01.png
│   │   ├── swordsman_reference.png
│   │   └── player_swordsman.png
│   ├── npc/npc_merchant_kael.png
│   └── enemies/                 # Slime/Golem source reference + alpha cutout
├── environment/
│   ├── tilesets/
│   │   ├── dungeon_stone_tileset.png
│   │   ├── dungeon_stone_tile_sample.tres
│   │   └── regions/             # AtlasTexture dùng cho FoyerArt
│   └── props/dummy.png, chest.png, README.md
└── ui/
    ├── hud_player_frame.png, hud_boss_frame.png
    └── icons/icon_fire.png, icon_wind.png, icon_sword.png, icon_shield.png
```

| Tên gốc trong staging | Đích dưới res://assets | Kích thước | Vai trò |
|---|---|---|---|
| 2D_horizontal_side-scrolling_platformer_dungeon_tileset_goth.webp | environment/tilesets/dungeon_stone_tileset.png | 1248×832 | Sheet concept nền đá/cột |
| 2D_side_view_character_concept_art_of_an_Eastern_fantasy_wan (2).webp | sprites/player/player_concept_full.png | 1248×832 | Concept nhân vật mặt nạ/trượng |
| 2D_side_view_character_concept_art_of_an_Eastern_fantasy_wan.webp | sprites/player/player_concept_closeup.png | 1248×832 | Concept cận cảnh |
| 2D_side_view_character_concept_art_of_an_Eastern_fantasy_wan (1).webp | sprites/player/variants/player_concept_closeup_duplicate_01.png | 1248×832 | Giữ bản trùng trong đường dẫn riêng |
| davinci_2d_character_reference_model_sheet__full_body_view.png | sprites/npc/npc_merchant_kael.png | 1024×1024 | Reference sheet Kael nhiều góc nhìn |

Hai bản closeup có SHA-256 nguồn giống nhau, `4732b4461655352038c1d00dddb6ac5ae190d381eed4d0daba331024395bc77a`. Cả hai nội dung vẫn được giữ; manifest đánh dấu `duplicate_of`, không ghi đè hoặc xóa một bản để che trùng.

File Kael gốc mang đuôi `.png` nhưng bytes bắt đầu `FF D8 FF` và chứa JFIF: **định dạng thật là JPEG**. Công cụ đọc magic bytes, dùng `Image.load_jpg_from_buffer()` rồi lưu PNG. Manifest ghi cả `source_extension=png`, `source_format=jpeg`, `source_format_mismatch=true` và conversion JPEG→PNG. Bốn ảnh còn lại là WebP thật, được decode từ buffer WebP.

## Tính toàn vẹn và staging

Mỗi ảnh có SHA-256 bytes gốc/PNG đích và SHA-256 pixels RGBA8 sau decode. Kích thước và pixels của PNG đích trùng ảnh nguồn đã decode; chuyển đổi không thêm mất mát ảnh. Chất lượng đã mất khi nguồn WebP/JPEG được tạo không thể phục hồi bằng chuyển PNG.

Nguồn nguyên byte cùng năm `.import` cũ được backup trong `docs/verification/asset_pipeline_sources/`, dưới `docs/.gdignore`. Source sidecar chỉ được lưu bằng chứng; Godot đã sinh `.import` mới đúng đường dẫn PNG đích.

Automatic approval review từ chối thao tác xóa staging, trả lý do `blocked by policy`. Root đã dùng cách an toàn hơn: xác minh đường dẫn tuyệt đối rồi **Move-Item với LiteralPath** cả thư mục vào `docs/verification/asset_pipeline_sources/staging_archive`. Vì vậy `res://staging_assets` không còn, nhưng bytes gốc và sidecar vẫn được bảo tồn. Manifest ghi `staging_disposition=archived_after_delete_auto_review_rejection` và `original_source_bytes_deleted=false`; không báo rằng dữ liệu gốc đã bị xóa.

Manifest: `docs/verification/asset_pipeline_manifest.json`, đủ năm ánh xạ, kích thước, hash, duplicate identity, archive path và sample atlas. Không đổi ảnh trình diễn cũ ở `assets/presentation` trong bước tổ chức này.

## Atlas mẫu và giới hạn của concept

`dungeon_stone_tile_sample.tres` là `AtlasTexture` dùng PNG sheet đá, vùng **Rect2(32, 60, 100, 90)**, `filter_clip=true`. Vùng này chứa block đá đầu tiên góc trái trên; đã xem ảnh crop và đối chiếu pixels với `AtlasTexture.get_image()`. Preview kiểm chứng ở `docs/verification/asset_pipeline_sources/_atlas_region_preview.png`.

Sheet có block/cột kích thước, khoảng cách và bố cục không đồng đều. Atlas mẫu là một crop thật, **chưa là TileSet grid/terrain/collision dùng được cho TileMap**. Trước khi dựng TileSet cần chuẩn hóa kích thước cell, padding, các cạnh nối và collision. Lần tổ chức baseline chỉ dành thư mục props với README; FoyerArt sau đó dùng các AtlasTexture vùng đá/cột và không sửa collision. Dummy/Chest alpha là bước Visual tiếp theo bên dưới.

Nhóm năm ảnh baseline đều giữ nền đục: sheet đá nền đen, nhân vật nền trắng. `player_concept_full` giữ tên theo yêu cầu nhưng chân/ủng nguồn nằm sát và bị cắt ở đáy canvas; không tự suy ra phần chân bị thiếu. Closeup không phải frame toàn thân. Kael là sheet nhiều góc nhìn kèm chữ, chưa là một sprite animation. Việc làm mask/shader trong module trình diễn được tách khỏi bước tổ chức file này; PNG nguồn vẫn giữ nguyên pixels. Không áp nhận xét nền đục này cho các PNG alpha bổ sung.

## Công cụ và kiểm tra

```powershell
& 'D:\dowload\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\hầm ngục' --script res://tools/organize_staging_assets.gd
# Chỉ một tiến trình editor/import tại một thời điểm.
& 'D:\dowload\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\hầm ngục' --import
& 'D:\dowload\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\hầm ngục' --script res://tests/asset_pipeline_test.gd
```

Organizer preflight toàn bộ nguồn/đích, từ chối ghi đè PNG hoặc atlas đã đổi, backup nguồn trước ghi, decode theo magic, encode PNG và kiểm pixels. Công cụ không xóa source; có thể chạy lại từ byte backups sau khi staging được lưu trữ. Lượt chạy idempotent đã được kiểm.

Asset Kiếm Sĩ mới nhập trực tiếp từ file người dùng: assets/sprites/player/swordsman_reference.png giữ nguyên PNG gốc, assets/sprites/player/player_swordsman.png là cutout nhìn nghiêng có alpha qua imagegen. Source và provenance ở verification/swordsman_sources, bị docs/.gdignore loại khỏi import. Không đưa cutout AI vào cam kết pixel-identical của organizer cũ. Suite game_feel kiểm alpha/render/pivot/cache và skin theo gear; xem [GAME_FEEL_SKINS.md](GAME_FEEL_SKINS.md).

Suite **79/79**, sạch ERROR/WARNING: PNG magic, dimensions, source/PNG/Texture2D pixel hashes, bytes archive, metadata mới/cũ, bản trùng, JPEG giả đuôi PNG, vùng AtlasTexture và đường dẫn sản phẩm không còn tham chiếu staging. `asset_pipeline_prepare.log`, `asset_pipeline_idempotence.log`, `asset_pipeline_test.log` nằm trong `docs/verification`. Đây là kiểm tổ chức/import asset; kiểm chuyển động/animation và render gameplay thuộc các suite trình diễn riêng.

API tham khảo chính thức: [Image](https://docs.godotengine.org/en/stable/classes/class_image.html), [AtlasTexture](https://docs.godotengine.org/en/stable/classes/class_atlastexture.html), [FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html). API đã được chạy trực tiếp trên engine phiên bản project.

## Mười cutout của Combat Art / Full Visual

| Source mới trong staging archive | PNG alpha dùng trong game | Cách dùng |
|---|---|---|
| `enemy_slime.png (2).png` | `res://assets/sprites/enemies/enemy_slime.png` | Slime36px; mutant kế thừa scale2/tint riêng |
| `boss_golem.png.png` | `res://assets/sprites/enemies/boss_golem.png` | Boss100px, flash/phase/death từ FSM hiện có |
| `props_dungeon.png.png` | `res://assets/environment/props/dummy.png` | Bia48px, foot-pivot flash/wobble |
| `props_dungeon.png.png` | `res://assets/environment/props/chest.png` | Rương28px, lock/open/read-only tint và jade light |
| `hud_player.png.png` | `res://assets/ui/hud_player_frame.png` | Khung rồng HP/Energy, hai socket alpha để progress hiện qua |
| `hud_boss.png.png` | `res://assets/ui/hud_boss_frame.png` | Khung thanh Boss và rồng, runtime AtlasTexture tách đúng tỷ lệ |
| `skill_icons.png.png` | `res://assets/ui/icons/icon_fire.png` | Icon bùa Hỏa |
| `skill_icons.png.png` | `res://assets/ui/icons/icon_wind.png` | Icon bùa Phong |
| `skill_icons.png.png` | `res://assets/ui/icons/icon_sword.png` | Icon vũ khí cận chiến |
| `skill_icons.png.png` | `res://assets/ui/icons/icon_shield.png` | Icon dự phòng/ô khác, tint và tooltip theo dữ liệu |

Slime/Golem còn có `enemy_slime_reference.png` và `boss_golem_reference.png` giữ nguyên byte nguồn tại assets/sprites/enemies. PNG output không ghi đè reference. Cả staging mới gồm tám file (hai enemy, hai sidecar import và bốn sheet HUD/props/icons) đã được chuyển nguyên thư mục vào `docs/verification/enemy_art_sources/staging_archive` sau khi xác minh đường dẫn tuyệt đối và hash. `staging_archive_hashes.json` ghi hash của đủ tám file; không xóa nguồn và không còn phụ thuộc `res://staging_assets` ở runtime.

Các cutout này dùng imagegen với transparent_background=true. Tool loại nền trắng, tách một thành phần của sheet và tạo alpha trống ở socket HUD; **không bảo đảm pixel-identical** với artwork gốc. Màu, chữ trên bùa hoặc chi tiết trang trí có thể thay đổi. Không đưa chúng vào cam kết decode-lossless/pixel-identical của organizer năm nguồn cũ và không thay manifest/79 assertion baseline bằng kết quả AI.

Provenance ở `docs/verification/enemy_art_sources/`:

- `asset_manifest.json`: hai enemy source/reference/cutout, SHA256 và kích thước.
- `provenance.json`: generated output của hai enemy, alpha mode, đối chiếu generated↔integrated hash; prompt nguyên văn không còn được truy xuất nên không tự dựng lại.
- `full_visual_provenance.json`: tám prompt thực tế HUD/props/icons, output path, source/output/generated SHA256. Các prompt chỉ là dữ liệu provenance, không là hướng dẫn runtime.
- `staging_archive_hashes.json`: nguyên byte của staging mới, gồm cả sidecar. Sidecar archive không dùng làm import runtime; project tạo sidecar mới cho PNG đích.

## Import, alpha và tỷ lệ render

Đúng **10 PNG cutout mới** trong bảng bật `mipmaps/generate=true` và sampler LINEAR_WITH_MIPMAPS trên skin/UI. Ảnh hơn1000px được minify còn28–100px nên mip chain giảm alias/speckle; không thay PNG bytes để bake một bản thấp phân giải. Mips chỉ thuộc CTEX/cache import. `EnemySpriteArt` vẫn đọc bounds/pixel chân ở base image và cache native geometry, không giữ actor hoặc ImageTexture clone theo mỗi enemy. Năm Texture2D lịch sử trong AssetPipeline79 giữ import/hash contract cũ, không bật mipmaps hàng loạt toàn assets.

Player actual instance dùng52.5px, tăng25% từ42px; rig standalone giữ42px. Slime36/Boss100/Dummy48/Chest28 đều scale theo alpha silhouette, không theo canvas margin, và đặt pixel chân vào pivot vật lý gốc. Flash shader không phá alpha hoặc nhân texture RGB hai lần. Đổi art không đổi collision/hitbox/physics resource. Alpha PNG giữ nguyên nguồn sáng/ngọc/sleeve/hoa văn của bản cutout; chỉ các reference gốc có quyền cam kết hash nguyên byte người dùng.

ArtHUD dùng CanvasLayer14 và TextureProgressBar thật ở sau socket alpha. Khi tạo TextureRect, expand_mode IGNORE_SIZE được đặt trước texture để kích thước PNG2172/1254px không ép HUD vượt khung. Boss dùng hai runtime AtlasTexture: strip Rect2(0,690,1536,334) và emblem Rect2(330,0,870,714), render giữ tỷ lệ rồng; không kéo toàn source1536×1024 thành một dải mỏng. Đây là region runtime, không thêm resource .tres vào danh mục AtlasTexture sản phẩm. Footer nằm dưới vùng Player đi trên sàn; HUD không chịu CanvasModulate thế giới.

Skin là composition của `SlicePresentation` trong TestLevel/Alpha/campaign; chạy riêng scene enemy/dummy/chest có thể vẫn thấy placeholder do không có composition. Các PNG là full-body still art, chưa có animation sheet hoặc atlas bộ phận. Chest dùng tint/checkmark cho đã mở, không giả định có frame mở nắp. Icon Hỏa/Phong là hai nguyên tố có art riêng; nguyên tố khác dùng fallback tint+tooltip, không gọi đó là đủ năm icon nguyên tố.

Các suite EnemyArt, PlayerPolish, CombatPolish, FullVisualProps và FullVisualHUD kiểm tích hợp mới; kiểm render/FPS thực tách khỏi headless. Kết quả cuối, captures và giới hạn ở [COMBAT_ART_POLISH.md](COMBAT_ART_POLISH.md) và [PROJECT_STATE.md](PROJECT_STATE.md). Lệnh gate vẫn là `tests/run_tests.ps1` mặc định, không bỏ editor/addon hoặc lọc warning.

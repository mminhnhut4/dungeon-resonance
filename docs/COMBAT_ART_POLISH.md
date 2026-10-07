# Full Visual & Combat Polish — Player, HUD và Props

Bản triển khai ngày 2026-10-01, Godot 4.7.2/GDScript, renderer Compatibility. Gói **Full Visual & Combat Polish** tích hợp mười PNG alpha, HUD có khung, skin Player/enemy/props và VFX chiến đấu. Không thay di chuyển, FSM chiến đấu, công thức cộng hưởng hoặc cân bằng sát thương. Gate strict cuối đạt **2.409/2.409 assertion, 0 fail**, giữ toàn bộ 2.027 của mốc trước; preview GPU và bốn benchmark đều đạt. Các lỗi native editor quan sát trong lượt chẩn đoán vẫn được ghi riêng bên dưới.

## Player và điểm tiếp xúc sàn

- Player instance dùng chiều cao silhouette **52,5px**, tăng đúng 25% từ 42px. Rig độc lập vẫn giữ mặc định 42px để preview/edit atlas sau này; chỉ hình ảnh của Player đang chơi được phóng lớn.
- `PlayerVisualRig` giữ BodySprite cũ làm nguồn dữ liệu flash/flip cho controller, nhưng chặn cả visibility và self-modulate khi có concept sprite. Khối chữ nhật xanh/trắng cũ không còn là một lớp hình ảnh nằm dưới chân concept.
- Pivot lấy đáy BodyCollision, rồi đặt pixel chân của alpha silhouette vào pivot đó. Lật chuột trái/phải, Tween thở hoặc đổi kiếm/trượng tiếp tục giữ chân tại điểm va chạm sàn. Không tăng collider để bù cho art lớn hơn.
- Kiếm/dao vẫn dùng Kiếm Sĩ, trượng dùng Thuật Sĩ mặt nạ; camera zoom1,35/lookahead40px và phím backtick/tilde bật debug được giữ từ gói trước.

## Nguồn Slime và Golem

| Thực thể | PNG trong suốt để render | Nguồn tham chiếu nguyên bản | Chiều cao alpha trong game |
|---|---|---|---:|
| Slime thường | `res://assets/sprites/enemies/enemy_slime.png` | `res://assets/sprites/enemies/enemy_slime_reference.png` | 36px |
| Golem | `res://assets/sprites/enemies/boss_golem.png` | `res://assets/sprites/enemies/boss_golem_reference.png` | 100px |

Hai ảnh do người dùng đặt trong staging với tên `enemy_slime.png (2).png` và `boss_golem.png.png`. Nguồn được giữ nguyên byte; SHA256 nguồn archive khớp bản reference trong assets. Cutout mới dùng **imagegen** để bỏ nền trắng, có alpha thật và không ghi đè nguồn. Vì đây là ảnh được xử lý bằng AI, **không bảo đảm pixel-exact** với nguồn; chi tiết trang trí/chữ bùa có thể khác. Không coi ảnh đơn này là sprite sheet animation.

Manifest nguồn, đường dẫn, SHA256 và kích thước PNG Slime/Golem nằm tại `docs/verification/enemy_art_sources/asset_manifest.json`; `provenance.json` ghi tool, alpha mode, generated output và đối chiếu SHA256 với file tích hợp. Không lưu lại prompt nguyên văn của hai enemy khi không còn có thể truy xuất. Bản nguyên gốc giữ tại `docs/verification/enemy_art_sources/`; cả thư mục staging mới cũng đã được chuyển vào `staging_archive` sau khi xác minh đủ tám file/hash. Theo yêu cầu Full Visual tiếp theo, bốn sheet `hud_boss.png.png`, `hud_player.png.png`, `props_dungeon.png.png`, `skill_icons.png.png` đã dùng để tạo tám PNG HUD/props/icon dưới đây. `docs/.gdignore` loại các archive/evidence khỏi import game.

## Tám asset HUD/props/icon bổ sung

| Đường dẫn PNG | Vai trò |
|---|---|
| `res://assets/ui/hud_player_frame.png` | Khung rồng Player; hai khoang thanh máu/năng lượng alpha trống để progress texture hiện qua |
| `res://assets/ui/hud_boss_frame.png` | Khung máu Boss; khoang thanh alpha trống |
| `res://assets/ui/icons/icon_fire.png` | Biểu tượng bùa Hỏa |
| `res://assets/ui/icons/icon_wind.png` | Biểu tượng bùa Phong |
| `res://assets/ui/icons/icon_sword.png` | Biểu tượng vũ khí cận chiến |
| `res://assets/ui/icons/icon_shield.png` | Biểu tượng dự phòng/ô bùa khác/phép |
| `res://assets/environment/props/dummy.png` | Bia tập gỗ nguyên thân đã bỏ nền |
| `res://assets/environment/props/chest.png` | Rương ngọc đóng nắp đã bỏ nền |

`full_visual_provenance.json` ghi đủ tám prompt thực tế, cờ transparent_background, đường dẫn output imagegen và đích copy. Các nguồn sheet gốc được giữ trong staging_archive. Đây vẫn là chỉnh ảnh bằng AI, không bảo đảm màu/chữ/chi tiết trùng từng pixel với sheet; không chỉnh source để lấp alpha socket hoặc giả tạo animation.

`ArtHUD` trên CanvasLayer14 đọc HP/Energy runtime và thanh Boss, hiển thị ba ô bùa Catalyst hiện tại, icon/tên vũ khí và tooltip. Hỏa/Phong dùng icon riêng; nguyên tố khác dùng icon dự phòng được tint và có tên/ID trong tooltip, chưa phải đủ năm icon nguyên tố riêng. TextureProgressBar nằm sau alpha socket của khung nên thanh có thể thay đổi theo HP mà không vẽ đè trang trí. Boss frame chỉ hiện trong trận còn sống; HUD/modal không chịu CanvasModulate thế giới. Các bar cũ vẫn giữ API/value/visibility dùng cho suite cũ nhưng được ẩn riêng bằng self-modulate để không vẽ trùng, rồi phục hồi khi HUD teardown.

Preview thật phát hiện `TextureRect` lấy kích thước tối thiểu của ảnh2172px trước khi bật expand, khiến khung che màn hình. Helper nay đặt expand IGNORE/stretch trước khi gán texture, rồi đặt position/size cuối; test kiểm kích thước sau layout. Boss footer được thu gọn420×91px ở vị trí(430,629), dùng hai vùng AtlasTexture để giữ tỷ lệ đầu rồng và nằm dưới vùng nhân vật trên sàn; thanh vẫn đọc HP runtime, khởi đầu500/500.

## Adapter trình diễn và ranh giới vật lý

- `EnemySpriteArt` đọc bounds/pixel chân từ alpha của PNG import. Texture native lưu một cache geometry nhỏ, không giữ actor hoặc GDScript Resource; sprite dùng chung Texture2D và có scale theo silhouette thay vì khoảng trắng quanh ảnh.
- `SlimeSpriteSkin.bind(Node2D)` ẩn Body polygon và Eyes mặc định, giữ chúng làm feedback adapter. Sprite đọc hướng, flash trắng/đỏ, màu báo chuẩn bị cắn và alpha chết từ dữ liệu Slime cũ. Incident Manhunter có mắt đỏ ở vùng đầu, z-index nằm trên sprite thay vì bị art che; adapter giữ và phục hồi z/position gốc khi unbind. Mutant Băng/Độc dùng tint riêng và giữ scale2, HP120 đã có.
- `BossGolemSkin.bind(Node2D)` ẩn riêng draw placeholder của parent bằng `self_modulate`, cho phép sprite/light child vẫn render. Adapter dựng lại báo đòn quét **320×26px** và vòng báo dậm đất theo FSM cũ; không gọi launch, activate hitbox hay transition FSM. Theo yêu cầu Visual tiếp theo, core light phase1 dùng jade xanh lục, phase2 amber; `current_tint` cyan/amber vẫn là API cue lịch sử. Shader flash, cue stagger và fade0,6s vẫn đọc clock gốc.
- Shader `enemy_sprite_flash.gdshader` trộn sang trắng khi nhận đòn; alpha PNG và tint từ vertex được giữ, tránh nhân texture RGB hai lần. Mỗi actor sở hữu ShaderMaterial riêng; texture/shader nguồn dùng chung.
- Slime/Boss/Dummy/Chest mới bật mipmaps import và sampling LINEAR_WITH_MIPMAPS để giảm hạt alias khi thu ảnh nguồn hơn1000px về28–100px. PNG byte nguồn không đổi, bounds/pixel chân vẫn lấy từ base image. Năm source texture lịch sử giữ import cũ; cải thiện hình ảnh phải đối chiếu bằng preview GPU.
- Skin chỉ gắn vào cây trình diễn bởi `SlicePresentation`, là con của actor và chết cùng actor. `bind(null)` phục hồi adapter cũ; cache geometry không bị xóa khi một skin despawn. Controller/motor, Hurtbox/Hitbox, CollisionShape2D và shape Resource không đổi vị trí/kích thước. Slime vẫn60HP; Golem vẫn500HP, body76×100, hai phase và Stagger.

## Vệt chém, đuôi phép và hit spark

- `WeaponTrail` giữ ribbon theo moveset và bổ sung mesh bán nguyệt **SilverJadeCrescent**: lõi trắng bạc, viền xanh ngọc. 32 đoạn, 66 vertex cho mỗi ribbon/arc; radius đọc reach của AttackStep. Crescent bắt đầu ở Active và mờ trong Recovery; hướng lấy snapshot đã commit, không đổi theo chuột giữa nhát chém. Trượng không có arc melee.
- Shader trail đọc tiến độ clock vũ khí, không dùng TIME để tự trôi trong hit-stop. Các accent lửa/tím/điện của đại đao/song đao/roi được giữ dưới arc bạc; đổi art không đổi thời điểm gây damage hay lực Stagger.
- `SpellProjectileVFX` gắn vào projectile: Line2D phát sáng và **12 hạt GPU**, lifetime hạt0,20s. Wake giữ tối đa12 điểm, dài tối đa72px, mỗi điểm cách5px. Màu lấy từ snapshot khi bind, nên thay bùa không recolor đạn đang bay; hit-stop dừng lấy mẫu/hạt.
- Khi phép va chạm, `presentation_contact` tạo burst vàng/xanh. Đòn melee nhận DamageResult thành công tạo hit spark vàng cam trên bia/quái; query riêng ở đầu Active tạo spark trên tường World. Query tường chỉ phục vụ VFX, không gây DamageEvent mới và không mở hitbox khác.
- `ImpactBurst` giữ vòng sáng/màu nguyên tố; melee đổi màu hạt sang vàng cam. Đòn bị block/duplicate và DOT không lặp impact/sound. Hit-stop0,05s và camera shake vẫn do CombatFeedback quản lý.

## Bia tập và rương PNG theo yêu cầu Visual tiếp theo

- `PropSpriteSkin.bind(Node2D)` hỗ trợ Bia tập và TreasureChest qua adapter ngoài actor core. Hai PNG mới đã được nạp: `res://assets/environment/props/dummy.png` (1024×1536) và `chest.png` (1347×1168), alpha thật. Dummy dùng alpha silhouette48px; chest28px, pivot cùng đáy object cũ.
- Dummy ẩn Body/Target/Stand placeholder nhưng giữ Body làm nguồn feedback. DamageEvent thành công kích shader trắng/đỏ và một Tween nghiêng quanh chân tối đa3°, rồi về0. Hit mới hủy Tween trước; blocked/duplicate/DOT không sinh thêm Tween. Hit-stop cục bộ pause/resume Tween; knockback tiếp tục do motor cũ thực hiện.
- Teardown và `finished` xóa tham chiếu Tween; chỉ resume Tween đang được adapter pause vì hit-stop. Điều này sửa lỗi gọi `play()` trên Tween đã hoàn tất khi bia nhận đòn tiếp theo, không thay feedback/damage clock.
- Chest ẩn old draw bằng self-modulate, không sửa `interact`, lock, loot hoặc giới hạn pickup. Trạng thái đã mở được thể hiện bằng tint và checkmark, **không giả định PNG đóng có animation mở nắp**. Một PointLight2D jade theo chest, energy tối đa0,55 và giảm0,2 khi đã mở; sprite/light cùng lifetime của rương.
- Unbind/teardown phục hồi placeholder, disconnect result listener, hủy Tween và trả sprite/material/light theo owner. Cache native geometry không giữ actor. Rương/Bia nằm trong composition phòng hiện hành; không thêm geometry va chạm hoặc thay luồng loot.

## Ngân sách và cleanup

| Owner | Giới hạn/lifetime |
|---|---|
| ImpactBurst trong phòng | 24 owner, tối đa8 flash light, owner hết sau0,48s |
| Đuôi projectile | 24 owner, 12 điểm +12 hạt mỗi owner; cùng lifetime của đạn |
| Spell light | 12 owner; đạn/hiệu ứng hủy thì ánh sáng hủy |
| Ambient dust | 72 hạt GPU |
| Audio không gian | 16 voice, owner theo room/finite lifetime |
| Boss skin | Một sprite/material và một core light theo actor |
| Bia tập/rương | Một sprite/material theo prop; tối đa một Tween ở bia, một jade light theo rương |

Các ngân sách impact/đạn giữ owner hữu hạn khi spam. Jade light của rương là **một nguồn theo mỗi rương** trong số rương hữu hạn của phòng, không gộp vào budget12spell lights. Room rebuild giải phóng impacts và décor cũ; projectile registry xóa theo tree_exiting. Sprite/material enemy và prop đi cùng node actor. Không thêm pool/framework mới; PNG dùng chung và geometry cache native có lifetime theo texture. Headless không emitting GPU particles và không chứng minh hình ảnh/hiệu năng GPU.

## Kiểm thử logic và trạng thái gate

`tests/run_tests.ps1` mặc định đã chạy xong, exit 0 và **ALL HEADLESS CHECKS PASSED**: **2.409 lượt assertion, 0 fail**. Validator kiểm 98 script sản phẩm/18 scene, data gate 39 Resource; import, addon entrypoints, editor fixture, lifecycle, Player rig editor và main headless đều đạt. Không lọc ERROR/WARNING hoặc bỏ gate editor.

Summary ghi rõ **2.027 assertion của mốc trước được giữ + 382 mới**. Movement55/Combat100 vẫn đạt ở cả 60/120Hz; Resolver20 chạy riêng. Năm suite mới ở mỗi mức: PlayerPolish31, EnemyArt43, CombatPolish47, FullVisualProps39, FullVisualHUD31, tổng 191 assertion/mức. [Log strict cuối](verification/full_visual_strict_suite.log) và [summary](verification/polish_test_summary.json) là bằng chứng hiện hành.

Các bài mới kiểm alpha/pivot/shape Resource và transforms bất biến; DamageEvent thật, flash/Manhunter overlay, Boss phase/telegraph/stagger/death; hit-stop/trail/wall contact; Dummy Tween/lifetime; chest locked/open/loot cap; giá trị/layout/icon/tooltip của HUD và teardown. Những lỗi fixture phát hiện qua kiểm thử được sửa để dùng clock/input đúng và so sánh float gần đúng khi cần, không giảm số assertion.

Stress sau warm-up ở cả 60/120Hz không tăng object/resource: phép 2556→2556/214→214, loot 2701→2701/214→214, Hub 2088→2088/235→235, campaign 1884→1884/236→236, presentation 1886→1886/240→240, combat VFX 2557→2557/245→245. Enemy/props có object cuối giảm hoặc bằng baseline, resource giữ 226/221. Đây là đo finite lifecycle, không khẳng định đã chứng minh mọi đường rò rỉ có thể xảy ra.

Các lượt chẩn đoán trước gate cuối gặp **native editor shutdown `0xC0000005`**, từng quan sát từ milestone trước; không có GDScript ERROR/WARNING giải thích crash. Log lỗi import/rig được giữ riêng, không xóa khi chạy lại. [Native audit](verification/full_visual_native_audit.md) ghi fingerprint Windows và giới hạn kết luận: chưa có native stack/symbol hoặc nguyên nhân đã được chứng minh. **Gate cuối sạch không chứng minh lỗi native gián đoạn đã được sửa vĩnh viễn.** Không dùng `-GameplayOnly` thay gate hoàn chỉnh và không quy lỗi cho addon khi chưa có bằng chứng.

## Preview và benchmark GPU đã đạt

`full_visual_preview_final.stdout.log` ghi **12 captures; PASS**, stderr sạch, preview hữu hạn đã thoát. Ảnh `combat_art_foyer_r3.png` xác nhận HUD gọn, Player chân khớp sàn và không render hộp cũ; bốn `combat_art_slash_*_r3.png` kiểm arc bạc/jade theo moveset. `combat_art_spell_trail_r3.png` và `combat_art_spell_contact_r2.png` dùng phép phát ra/va chạm Hurtbox thật; ảnh Dummy/rương kiểm flash, trạng thái loot. Hai ảnh `combat_art_boss_phase_1_r3.png`/`phase_2_r3.png` kiểm PNG Golem, core light và footer không che Player.

Bốn benchmark thật dùng Compatibility/RTX5080, cửa sổ1152×648, VSync tắt riêng đo, warm-up2s và đo6s. Tải gồm ánh sáng/glow/72 GPU ash,10 phép/s với wake,20 GPU burst/s,4 kiểu trail và10 loot/s; Boss ở phase2 cùng Slime/Eclipse. Mixer hoạt động với bus SFX mute; HP giữ và hit-stop tắt riêng benchmark để đo throughput, không áp vào gameplay.

| Kịch bản/cap | FPS trung bình | p95 frame gồm chờ cap | Peak physics | Peak draw calls |
|---|---:|---:|---:|---:|
| Tiền Sảnh60 | 59,981 | 17,499ms | 4,581ms | 359 |
| Tiền Sảnh120 | 120,003 | 8,769ms | 3,193ms | 344 |
| Boss60 | 59,992 | 17,566ms | 3,314ms | 399 |
| Boss120 | 119,996 | 9,241ms | 5,932ms | 471 |

JSON `full_visual_foyer_render_60.json`/`120.json` và `full_visual_boss_render_60.json`/`120.json` giữ số đo gốc; cả bốn đạt gate benchmark. Peak projectile wake11 ở Tiền Sảnh,14 ở Boss, dưới cap24; particles132/168, impact24/flash8/spell light12/audio voice16 đều giữ ngân sách. Đây là stress hữu hạn trên máy hiện tại, không suy ra FPS từ headless hoặc bảo đảm mọi thiết bị/run vô hạn.

## Giới hạn và cách thử

Đây là **full-body still sprites**, chưa có animation atlas từng bộ phận hoặc sprite poses riêng cho Slime/Golem. Player dùng xương/Tween/overlay đã có; enemy art không đổi hành vi AI. Tỷ lệ art lớn hơn collider là lựa chọn cosmetic của gói này, cần người dùng đánh thử để đánh giá độ đọc đòn.

F5 từ editor chạy main → chọn **Đi ải · 3 tầng + phòng bí mật**. Chuột trái chém, chuột phải phép; F5 trong game đổi vũ khí và F8 tới Boss. Backtick/tilde bật chữ debug khi cần. Preview hữu hạn và benchmark phải đóng trước khi mở cửa sổ chơi cho người dùng; giữ editor đang có nội dung chưa lưu.

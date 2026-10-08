# Tích hợp ảnh bùa — 2026-10-08

Trạng thái lúc 23:31 UTC ngày 07/10/2026: payload nằm ở bản riêng `C:/Users/Admin/AppData/Local/Temp/DgContinue_20261008`. Subagent spell không ghép hoặc sửa bản chính. Root là đầu mối kiểm native, sao lưu và ghép. Không coi kiểm logic, file PNG hoặc ảnh chụp tĩnh là xác nhận trải nghiệm đã hoàn thiện.

## Phần đã đổi

- Dùng PNG render `assets/presentation/rendered_spell_v2.png` thật, 1402×1122 RGBA, 5 cột Hỏa/Phong/Lôi/Băng/Độc và 4 hàng seal/đạn/contact/field. Helper chỉ giữ một sheet, 20 AtlasTexture và một material chung; crop theo kích thước thực, inset 2px, `filter_clip=true`.
- `RuneCastCue` dùng seal PNG 52→70px, đọc payload và clock của `PlayerCastState`. Dash hủy trước release vẫn giấu cue và không sinh đạn. Con trỏ sau commit không đổi hướng seal.
- `SpellProjectileVFX` dùng thân đạn PNG, ghép hai hình nguyên tố theo recipe cho đủ 10 cặp. Màu vẽ sẵn được giữ, snapshot chỉ phủ wash nhẹ. Parent `self_modulate` giấu nét vẽ cũ của projectile; Sprite con vẫn hiện. Khi tháo skin thì khôi phục chính xác màu/alpha gốc.
- Đạn PNG hướng phải được dịch lùi local x = 0.36×chiều rộng (28.08px ở body 78px). Parent rotation vẫn đọc hướng snapshot. Leading quad cách mặt hitbox tối đa 4px trong fixture; echo theo cùng offset. Không dịch cue, contact, collider hoặc actor.
- `ImpactBurst.configure_spell_art(recipe)` chọn contact của đúng cặp. Root nối API với `event.spell_id` sau accepted hit trong SlicePresentation. Melee sparks, particle/light limits, clock fade và finisher decal giữ cơ chế hiện có.
- Firestorm, Blizzard và Miasma dùng ảnh field rỗng tâm, ghép hai nguyên tố, seek theo elapsed/radius thật. Motion/fade khác giữa Miasma và Blizzard; hitstop không cho field clock tiến. Vòng mảnh bổ sung thể hiện radius, PNG là thân hiệu ứng.

Các file owner spell: `scripts/presentation/rendered_spell_art.gd`, `rune_cast_cue.gd`, `spell_projectile_vfx.gd`, `impact_burst.gd`, `element_field_vfx.gd`, `scripts/spells/firestorm_effect.gd`; test mới `tests/rendered_spell_art_test.gd`. SlicePresentation và asset PNG do root quản lý.

## Cơ chế và giới hạn giữ lại

Không sửa Player/FSM, SpellExecutor, ElementField, DamageResolver, recipe, balance, gear classes hoặc save. Không thêm collider, proc, light hay particle owner. Mỗi effect thêm tối đa hai Sprite con, với atlas/material dùng chung.

Projectile wakes và ElementField skins vẫn chia cap 24 ở adapter. Light giữ cap 12, gameplay entities giữ cap 64. Firestorm giữ owner effect hiện hữu và entity/light caps của nó. Clock/timer gây damage vẫn ở actor/effect hiện hữu. Root/context không nằm trong cache atlas.

## Kiểm thử đã chạy trên bản riêng

Runner: `C:/Users/Admin/Documents/Codex/2026-10-08/dungeon_continue/probes/run_probe.ps1`. Tất cả lượt dưới đây chạy `-Project C:/Users/Admin/AppData/Local/Temp/DgContinue_20261008`, dùng save QA cô lập và `-Headless`; import cũng headless. Raw stdout/stderr và `RUN_RESULT.json` giữ tại `probes/<label>`. Không lọc ERROR/WARNING.

| Label | Phạm vi | Kết quả |
|---|---|---|
| `spell_art_v2_import_r1` | Import PNG, helper, classes | exit 0; diagnostics [] |
| `spell_art_runtime_regression_r1` | Cast thật, cancel, 5 single roots/wakes; existing boss clocks | 24/24; exit 0; diagnostics [] |
| `spell_art_field_regression_r1` | Input/contact thật Blizzard/Miasma, freeze, loadout immutability, caps, room teardown | 35/35; exit 0; diagnostics [] |
| `spell_art_vfx_regression_r1` | Existing weapon/impact/particle/light teardown | 62/62; resources 139→139 sau warm; exit 0; diagnostics [] |
| `spell_art_light_regression_r1` | Real snapshot/collider invariants, body light guard, 24/12 caps | 122/122; exit 0; diagnostics [] |
| `spell_art_binding_r1` | Actual I→physical hit đủ 10 cặp; Sprite atlas thật ở 4 phases; finite cache | 65/65, 60Hz; exit 0; diagnostics [] |
| `spell_art_binding_final120_r2` | Thêm accepted-hit hitstop và tháo riêng skin/restoring owner ink | 67/67, 120Hz; exit 0; diagnostics [] |
| `spell_art_geometry_final120` | Final source: 10 cặp actual I/contact, leading quad/hitbox, freeze, field radius, lifetime/cache | 77/77, 120Hz; exit 0; diagnostics [] |
| `spell_art_matrix_regression` | Existing resolver/status/root behavior matrix | 64/64; exit 0; diagnostics [] |
| `spell_art_field_stress_headless` | Reuse actual main scene stress fixture; 24 field skins, visibility ablation, warmed cleanup | 14/14; 1442 samples; exit 0; diagnostics [] |

Lượt `spell_art_binding_final120` đầu tiên có 67/67 assertions nhưng có engine ERROR `slot >= slot_max` tại EnemyHitAggro.record. Không coi là pass. Nguyên nhân đã xác minh: fixture hitstop dùng source ID giả 987654; enemy aggro resolve instance ID đó. Đổi fixture sang live level ID, không đổi sản phẩm; r2 và final geometry sạch. Receipt lỗi được giữ nguyên.

Stress headless chỉ kiểm probe và lifetime: hai modes enabled/disabled đều max 24 skins/12 lights/24 entities; sau clear trở về node 814, object 4654, resource 541, orphan 0. Mode disabled giấu/dừng chỉ child field VFX, giữ base field query/clock/light. Direct executor refill 12 Blizzard +12 Miasma với lifetime 1s/4s, tương đương khoảng 12+3 field/s, **vượt tốc độ cast tự nhiên**. Những số frame-time headless không xác minh chi phí render GPU hoặc độ mượt native.

Focused final geometry chỉ đổi vị trí Sprite của projectile; evidence field stress/lights/status trước đó vẫn phù hợp vì clocks/caps/resources/field branch không đổi.

## Điều chưa xác minh ở mốc báo cáo

- Native PNG 10-pair matrix, screenshot inspection và A/B field GPU frame-time cần root chạy serial. Native 92/92 +43 ảnh của payload vector trước đó không phải bằng chứng PNG mới.
- Fixture stationary high-HP enemy/QA owned grants xác minh các callsite thực, không phải vòng chơi tự nhiên hoặc cảm giác combat hoàn thiện. Chưa xác minh chain/spread với nhiều actor, Neurotoxin khi enemy đang ra đòn, pre-frozen Thermal Shock/pre-poison Combustion bằng native matrix này; matrix logic hiện hữu chỉ xác nhận behavior logic.
- `presentation_contact` cho wall hit hiện chỉ truyền color/direction, không truyền recipe/root. Accepted damage contact có exact pair; wall contact có PNG fallback một nguyên tố. Không tuyên bố exact pair ở wall.
- Chưa đánh giá audio, cảm giác độ sáng, khả năng đọc chi tiết ở pixel size native, alpha crop/neighbor leakage bằng hình đang chạy. Source atlas được xem và import sạch chưa thay thế việc này.
- Không chạy full strict suite trong nhóm này; root giữ trách nhiệm gate khi ghép payload chung. Test logic không thay release approval.

## Handoff và hoàn tác

Sáu file trước art V2 được giữ ở `C:/Users/Admin/Documents/Codex/2026-10-08/dungeon_continue/spell_work/pre_art_v2/`. Manifest SHA256 và các probe độc lập nằm ở `spell_work`. Chưa copy file nào sang main bởi subagent này; khi root ghép cần sao lưu file main và bảo vệ save thật theo runner/scope đang dùng.

Next: root chạy existing `spell_pairs_probe.gd` cho PNG final và `field_stress_probe.gd` native serial, xem ảnh và p95/p99/max/hitstop/resource teardown. Chỉ chỉnh ảnh/cosmetics theo vấn đề có bằng chứng; không mở tầng, thêm hệ thống hay đổi balance.

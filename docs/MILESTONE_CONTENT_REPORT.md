# Vast Linear RPG Content & Deep Build-Crafting

Ngày 2026-09-30 · Godot **4.7.2.stable.official.ed1daf0bf** · GDScript · Compatibility.

Đã tích hợp năm phân hệ vào campaign chạy được: 4 archetype vũ khí, 5 nguyên tố/10 công thức đôi, 4 cổ vật/3 ô, tuyến Tiền sảnh → Khám phá 1.5 → Mutant → Golem và debug F5–F8. Các module Alpha/loot/quality/survival/Sanctuary trước đó cũng đã được nối vào main. Đồ họa giữ hình khối, VFX đơn giản và chữ debug.

**Source/gameplay và benchmark đạt; addon import/shutdown chưa đạt zero-warning.** Phân biệt kết quả này ở phần kiểm chứng và [ADDONS.md](ADDONS.md).

## Chạy và điều khiển

Trong editor, mở project.godot và F5 chạy main; tại Sanctuary chọn **Đi ải · 3 tầng + phòng bí mật**. Campaign được cấp 4 archetype mới để thử cùng các dòng đã mở khóa; vũ khí khởi đầu chọn tại Hub vẫn được tôn trọng. **Alpha · 3 phòng gốc** giữ tuyến trước.

Sân thử riêng: mở scenes/test_level.tscn và F6 trong editor. Khi cửa sổ game có focus, F6 là bảng ma trận, F5 đổi vũ khí; đây là phím debug của game, khác shortcut editor.

| Phím trong game | Thao tác |
|---|---|
| A/D hoặc ←/→; Space/W; Shift/K | Chạy, nhảy biến thiên, dash |
| Chuột trái/J; Chuột phải/I | Attack / cast theo cursor 360° |
| Q | Xoay vòng vũ khí đang sở hữu |
| E | Nhặt/mở rương/campfire/merchant/cổng thắng khi ở gần |
| Tab | Khảm bùa Weapon/Catalyst, time 10%; đóng khôi phục time |
| C | Vết thương, túi đồ, chế tạo tại camp và thay 3 cổ vật |
| F5 | Cấp nếu thiếu và đổi qua Đại đao → Song đao → Trượng → Roi |
| F6 | Chọn một trong 10 công thức; cấp shard test còn thiếu, giữ energy/cooldown |
| F7 | Mở tường/rào bí mật; cấp đủ 4 cổ vật, auto-equip 3 đầu; C đổi Gương vào ô |
| F8 | Đến Boss; từ sân thử cũng chuyển sang campaign và giữ HP/UID/bùa/cổ vật |
| F1/F2/F3 trong sân thử | Incident random / bleeding+leg injury / +100 Soul và crafting |
| R trong sân thử; 1–4 | Reset phòng; ba preset đôi cũ / phép cơ bản |

## 1. Vũ khí có moveset riêng

| WeaponData | Đặc điểm của dữ liệu mẫu |
|---|---|
| Trảm Ma Đao | Base 32, 2 hit, reach 130px, sweep 180°, windup 0,34s; stagger 32/knockback mạnh; step 2 super armor chống interrupt thường, vẫn nhận damage |
| Tật Phong Chủy Thủ | Base 7, 4 hit, reach 46px, crit 40%; windup 0,02s; hit cuối lunge 480px/s trong 0,12s |
| Lạc Lôi Trượng | Base 19, left-click phóng arcane wave hướng chuột; speed 400px/s, lifetime 0,9s, pierce 2, không bật melee hitbox |
| Huyết Thiết Tiên | Base 13, reach 190px, thrust thẳng; pull 170 về điểm trước ngực người chơi |

Các bước combo có data timing/shape/damage/knockback/stagger riêng. Snapshot từng đòn giữ hướng/payload. Hull hình học đã được chuẩn hóa để sector 180° không gây cảnh báo polygon. Swap hủy hit window cũ.

Player Controller, PlayerMotor và hai FSM giữ logic stable của mốc trước. BuildPlayerMotor là subclass dùng interface impulse/extra dash; WeaponBuildComponent nối signal impact/super armor/lunge. Không gọi move_and_slide thứ hai.

## 2. Năm nguyên tố / mười cặp

Ice làm chậm chạy/đánh 60% và cộng 35 freeze/hit; 100 điểm freeze giữ 1,5s trên quái thường. Poison cộng tầng tối đa 5, mỗi tầng **1% max HP/s**, refresh duration 4s. Boss chống hard CC/pull, còn nhận status khác và Stagger.

Damage bên dưới là **base impact trước crit/quality/relic/Eclipse và damage phụ**; test kiểm base snapshot của cả 10 công thức và các phản ứng riêng, không coi một con số là tổng damage mỗi cast.

| Cặp | Recipe / base impact | Hành vi mới |
|---|---|---|
| Hỏa + Phong | Firestorm / 10 | Vortex hút, burn, nổ AoE khi kết thúc |
| Hỏa + Lôi | Overload / 12 | Nổ critical 30, stun 0,5s |
| Phong + Lôi | Charged Slash / 12 | 3 lưỡi dao phân góc, pierce/chain bounded |
| Băng + Hỏa | Thermal Shock / 20 | Frozen target nhận ×3 impact, tiêu thụ frozen, không đóng băng lại cùng hit |
| Băng + Lôi | Superconduct / 16 | Armor-break 5s, damage vật lý nhận ×1.25 |
| Băng + Phong | Blizzard / 14 | Slow AoE, vùng sương giá/tích freeze |
| Độc + Hỏa | Combustion / 18 | Tiêu thụ các tầng độc, chuyển damage DOT còn lại thành burst + explosion AoE |
| Độc + Băng | Frost-Venom / 12 | Freeze quái thường, 2 tầng poison; lan tối đa 2 mục tiêu lân cận |
| Độc + Phong | Miasma Cloud / 10 | Vùng độc 4s; Slime tránh vùng, finite tick/slow; không tạo field đệ quy |
| Độc + Lôi | Neurotoxin / 17 | Interrupt 0,4s, poison và chain lightning |

Exact multiset có tính số lượng/không tính thứ tự; không kích hoạt mọi subset. Một root cast giữ ledger chung cho ba projectile, cap 64 entity, chain tối đa 2, lifetime hữu hạn. Rune/recipe definitions không bị sửa bởi actor. Phép đã phóng giữ snapshot khi đổi loadout.

## 3. Cổ vật từ Resource

- Huyết Thạch: hồi 2 HP khi actual killing blow là melee; staff/ranged/DOT không kích hoạt.
- Lông Vũ: thêm 1 Air Dash trước landing; energy/cooldown/crippled vẫn áp dụng.
- Chu Sa: resonance damage ×1.25, cooldown ×1.15; không buff basic bolt.
- Gương: enemy damage bị chặn trong 0,075s đầu dash tạo PhantomEcho, nổ 22 sau 0,35s, radius 85; root dedup/cap 64/lifetime ngăn spam.

Owned và equipped tách riêng, tối đa 3, không nhân đôi relic grant. C chọn relic trong ItemList rồi nút Ô 1/2/3. Trị số, trigger window, delay và radius nằm ở RelicData; runtime modifier trả về trung tính khi tháo/chết.

## 4. Campaign kế thừa Alpha

1. **Tiền sảnh:** 3 Slime, cửa khóa, bia; dọn xong đi sang phải.
2. **Tầng 1.5:** không wave; tường ảo 2 hit/1 spell và rào chỉ Hỏa, rương nhặt cổ vật, campfire. Người chơi vẫn có thể bỏ qua bí mật để đi tiếp.
3. **Đấu trường đột biến:** 2 wave, mỗi wave 2 mutant geometry ×2/120 HP, aggro 300px; một Poison, một Ice. Telegraph ranged 0,35s/cooldown 1,8s, projectile finite 22 damage/status. Elite thưởng tổng 12 Soul.
4. **Golem:** 500 HP/hai phase/stagger/sweep/orbs/summons/stomp; boss +25 Soul, rương lớn/cổng Victory E. Death về Hub, Soul giữ.

Cùng Player/inventory/relic runtime được dùng qua room: HP/energy/item UID/equipped weapon/shards/cooldown được giữ. Room cũ dispose incident/loot/enemy/hazard/spell. F8 từ test chuyển ledger sang campaign; không copy/duplicate item instance.

## 5. File mới và phạm vi thay đổi

Tất cả dữ liệu mới là Custom Resource độc lập. Tổng hiện tại 82 product scripts / 17 scenes / 39 .tres; manifest liệt kê **mọi file sản phẩm/data/test** cùng SHA-256 ở [verification/content_manifest.json](verification/content_manifest.json).

### Tài nguyên mới của mốc Content (19)

```text
data/weapons/demon_greatsword.tres
data/weapons/gale_dual_daggers.tres
data/weapons/storm_arcane_staff.tres
data/weapons/blood_spiked_whip.tres
data/runes/IceRune.tres
data/runes/PoisonRune.tres
data/resonances/ice_bolt.tres
data/resonances/poison_bolt.tres
data/resonances/thermal_shock.tres
data/resonances/superconduct.tres
data/resonances/blizzard.tres
data/resonances/combustion.tres
data/resonances/frost_venom.tres
data/resonances/miasma_cloud.tres
data/resonances/neurotoxin.tres
data/relics/soul_bloodstone.tres
data/relics/gale_feather.tres
data/relics/cinnabar_seal.tres
data/relics/phantom_mirror.tres
```

### Code / scene / test mới

```text
scripts/definitions/WeaponData.gd, RelicData.gd
scripts/actors/player/build_player_motor.gd
scripts/actors/enemies/mutant_slime.gd
scripts/combat/weapon_build_component.gd, element_status_controller.gd
scripts/spells/element_field.gd, phantom_echo.gd
scripts/runtime/relic_runtime.gd, content_session.gd
scripts/rooms/linear_campaign.gd
scenes/linear_campaign.tscn
scenes/enemies/mutant_slime.tscn
tests/content_data_test.gd
tests/weapon_content_test.gd
tests/spell_matrix_test.gd
tests/relics_test.gd
tests/campaign_test.gd
tests/content_render_benchmark.gd
tests/preview_content.gd
```

Mở rộng interfaces/data/payload của WeaponDefinition/AttackStep, DamageEvent/Snapshot, StatusController/Resolver/Executor, inventory/loot/UI, Hub/GameFlow; không thay logic controller/FSM legacy. UID files do Godot sinh đi kèm scripts. Tài liệu Alpha/Deep/Addon/Architecture/State/Decisions đã cập nhật.

## Kết quả headless

Lệnh: `./tests/run_tests.ps1 -GameplayOnly`. Mọi assertion dưới đây pass; log `verification/final_gameplay_suite.log`. Validator treat GDScript warnings as errors cho code sản phẩm, main headless 180 iterations nạp sạch.

| Suite | 60 Hz | 120 Hz |
|---|---:|---:|
| Movement | 55/55 | 55/55 |
| Combat | 100/100 | 100/100 |
| Resonance Prototype | 69/69 | 69/69 |
| Alpha | 80/80 | 80/80 |
| Gear / secrets | 35/35 | 35/35 |
| Storyteller | 29/29 | 29/29 |
| Conditions | 29/29 | 29/29 |
| Crafting | 32/32 | 32/32 |
| Sanctuary | 28/28 | 28/28 |
| **Weapon Content** | **26/26** | **26/26** |
| **Spell Matrix** | **64/64** | **64/64** |
| **Relics** | **23/23** | **23/23** |
| **Campaign** | **31/31** | **31/31** |

Resolver **20/20**, data load **39/39**, validator **82 script/17 scene** chạy riêng. Tổng 660 assertion độc lập / **1.261 lượt**; Content thêm **183** assertion độc lập / **327 lượt**. Không đếm addon probe là clean pass, không tính validator/main thành assertion gameplay.

Các test mới kiểm hitbox semicircle/front-back, super armor nhận damage, lunge vật lý, staff projectile, whip pull, Q/F5 cancellation, tất cả exact recipe/base damage, frozen consume/poison cap & expiration/armor modifier/spread/cloud teardown, max3 relic/kill heal/extra dash/Perfect Dodge **qua physics Hitbox thật**, UI debug/F8 transfer, secret loot chống duplicate, wave/boss/victory/run persistence.

## Cleanup / render

Stress sau warm-up: 3×200 spell yêu cầu spawn (cap64) **2236→2236 objects / 160→160 resources**; 3×300 loot requests (cap96) **2419→2419 / 158→158**; 8 Hub cycles **1980→1980 / 180→180**; 6 content campaign cycles qua 4 chặng, 10 phép và loot **1818→1818 / 181→181**. Không thấy population tăng hoặc shutdown warning ở gameplay suites; vẫn cần soak dài hơn trước release.

Render thật trên **RTX 5080**, Godot Compatibility, **1152×648**, VSync disabled/cap 60 hoặc 120 riêng benchmark, không dùng fixed-fps để giả lập render. 2s warm-up + 6s sample mỗi cấu hình. Scenario: Golem phase 2 + 2 Slime/respawn adds, Eclipse, 10 recipe luân phiên khoảng 10 cast/s và loot 10/s; Player HP/energy/Boss HP cố định để giữ combat, hit-stop tắt riêng benchmark.

| Đo | 60 FPS / 60 physics Hz | 120 FPS / 120 physics Hz |
|---|---:|---:|
| FPS trung bình | 59,9996 | 119,9972 |
| p95 frame (gồm cap wait) | 17,243ms | 8,776ms |
| Peak physics | 2,384ms | 2,049ms |
| Peak spell entities | 19 | 21 |
| Peak loot | 38 | 43 |
| Peak draw calls | 328 | 351 |

JSON/log ở verification/content_render_60.*, content_render_120.*. Đây là sample ngắn trên máy hiện tại, không bảo đảm mọi GPU/tải/render resolution.

Ảnh render đã quan sát: [Hub](verification/content_hub.png), [Inventory](verification/content_inventory.png), [Crafting](verification/content_crafting.png), [Ma trận](verification/content_matrix.png), [Bí mật](verification/content_secret.png), [Mutant](verification/content_mutants.png), [Boss/Eclipse](verification/content_boss_eclipse.png). Modal đã có nền opaque và HUD nằm trên Eclipse.

## Giới hạn còn mở

Addon đã enable đủ nhưng import/probe có tài nguyên GDScript giữ lại lúc exit; strict runner mặc định **fail**, xem [ADDONS.md](ADDONS.md). -GameplayOnly loại trừ rõ ràng editor import/addon shutdown, không che warning. Wizard chưa có Aseprite CLI nên chưa kiểm import .aseprite. Gameplay/art/sound/cân bằng/thời lượng 15–20 phút vẫn là prototype cần playtest; chưa export Steam.

# Nền tảng nhân vật và bộ trang bị khởi đầu

2026-10-01, Godot 4.7.2/GDScript, Compatibility. Nền tảng nhân vật ghép bộ phận, bộ đồ Thường, hành trang và các động tác cơ bản đã qua gate strict **3.390/3.390**. Gói High Fidelity đã tích hợp theo các board được duyệt; kết quả gate cuối của gói mở rộng và benchmark sẽ được cập nhật từ lần kiểm tra hiện hành. Ảnh chibi người dùng gửi chỉ minh họa cách chia bộ phận; phong cách kiếm sĩ cổ phong đã chọn được giữ.

## Phạm vi hiện hành

- Player dùng cutout PNG/AtlasTexture gắn vào xương, có thể tháo từng nhóm trang phục. Giữ toàn bộ controller, motor, hai FSM và cây va chạm đã ổn định.
- Bộ khởi đầu gồm bảy ô riêng: Vũ khí, Áo, Quần, Giày, Găng tay, Nhẫn, Dây chuyền. Mỗi món có UID riêng; ô trang bị chỉ tham chiếu ledger sở hữu.
- Hub hiển thị cùng bộ mặc định; Alpha và campaign khởi đầu đủ máu sau khi dựng xong bộ đồ. Chuyển phòng giữ HP và các UID, không hồi máu.
- Hành trang vẫn mở bằng Tab, làm chậm thời gian còn 10%; click đồ để mặc/đổi, chuột phải ô đang mặc để tháo, túi 20 ô và trang Bùa được giữ. I vẫn là niệm phép.
- Bộ Thường không có hào quang trang sức hoặc hiệu ứng phẩm cấp phô trương. Sáu bậc và luật màu theo nguyên tố vẫn áp dụng.

## Dữ liệu, atlas và cây xương

`assets/sprites/player/modular/starter_parts_atlas.png` có alpha thật, dùng chung bởi 20 vùng AtlasTexture trong `assets/sprites/player/modular/atlas/`. Metadata vùng cắt ở `verification/starter_atlas_regions.json`; prompt và bản thử giữ trong `art_approval/`. Ảnh được tạo theo hướng đã chọn; không coi đây là atlas vẽ tay thương mại hoặc bản sao từng pixel của ảnh nguồn.

[Provenance mỹ thuật](verification/character_art_provenance.json) ghi đường dẫn nguồn `generated_images`, prompt, SHA256, kích thước, alpha, trạng thái duyệt và các vùng AtlasTexture thực. Đã đối chiếu **8/8** ảnh board/atlas với nguồn imagegen: bản trong project có cùng hash byte với nguồn. Board duyệt hướng mỹ thuật; atlas sản phẩm được tạo và tích hợp sau khi duyệt hướng, không ghi nhận người dùng đã duyệt riêng từng pixel của atlas. Board slash v1 có giấy bùa được lưu làm lịch sử; bản v2 bỏ giấy bùa là hướng được dùng.

| Atlas sản phẩm | Kích thước | Alpha PNG thực | Vùng AtlasTexture | SHA256 |
|---|---|---|---|---|
| `assets/sprites/player/modular/starter_parts_atlas.png` | 1402 × 1122 | RGBA, 0–255 | 20 | `8dbc15af2133b912f7a0959c5ea254acf37fab1933683e510acf7aa6a61187ab` |
| `assets/vfx/slashes/high_fidelity_slash_atlas.png` | 1536 × 1024 | RGBA, 0–254 | 6 | `25db12125128b4fed43390a0fc708674193b7b7d93be047fda0a6d4fa44c24c6` |
| `assets/vfx/movement/high_fidelity_movement_atlas.png` | 1774 × 887 | RGBA, 0–255 | 8 | `e6a2a187a54de5416e5bb23e2273b11d0b1663a607ebd0e14745451b5746e31d` |

Alpha được đọc toàn bộ từ kênh PNG, không suy từ nền đen hoặc các mẫu pixel thưa. Cả ba atlas có nền trong suốt thật; slash có giá trị alpha lớn nhất 254, không mặc định ghi thành 255. Các vùng được đọc từ `.tres` và kiểm trong giới hạn ảnh nguồn. Metadata starter giữ `region` là bounds alpha nguồn, bổ sung `runtime_region` là vùng có padding đang dùng trong AtlasTexture; không nhầm hai loại vùng cắt này.

`ModularCharacterPart` chứa ID, bone slot, Texture2D/AtlasTexture, pivot theo pixel, scale, draw order và tint. `ModularCharacterSkin` chứa các phần cơ thể, visual scale và foot origin. `EquipmentData.visual_parts` chứa lớp trang phục của từng món; các Definition được dùng chung và không lưu UID, HP hay trạng thái đang mặc.

Rig scene giữ 14 Bone2D và 18 sprite slot legacy. Khi dùng skin modular, thêm Knee/Ankle ở hai chân, thành **18 xương thực**. Các slot cũ và `Player.body_sprite` vẫn tồn tại để tương thích feedback; khối placeholder và concept toàn thân được ẩn khi skin modular hoạt động. Bộ hiện hành có **16 attachment cơ thể + 16 attachment trang phục/phụ kiện**, dùng lại vùng atlas cho phía trái/phải.

```text
Player [CharacterBody2D]
├── BodyCollision                         # cây vật lý giữ nguyên
├── Visuals [PlayerVisualRig]
│   ├── Skeleton2D / Root / Hip
│   │   ├── Torso / Head                 # đầu, tóc, áo lót, áo ngoài
│   │   ├── Shoulder.L/R / Arm.L/R / Hand.L/R
│   │   │   └── BodyParts + wearable layers
│   │   └── Leg.L/R / Knee / Ankle        # đùi, cẳng chân, giày
│   ├── AnimationPlayer                  # manual seek từ clock gameplay
│   ├── ActorShadow
│   └── EquipmentVisual / HandSocket / WeaponPivot / WeaponSprite
├── Combat / Aim / WeaponSocket / Weapon / Hitbox
└── Hurtbox / CollisionShape2D
```

Socket cầm kiếm nhìn thấy bám bàn tay của rig. WeaponSocket/Hitbox vật lý giữ vị trí, shape và owner cũ. Pivot chân căn theo đáy BodyCollision; scale, flash, lật hướng, pose và bóng chỉ thuộc lớp mỹ thuật. Khi tháo áo vẫn có lớp áo lót; tháo các món khác chỉ gỡ nhóm tương ứng. Nhẫn và dây chuyền là attachment nhỏ, không sinh hào quang.

## Bộ đồ và chỉ số đã chốt

| Ô | Resource | Chỉ số |
|---|---|---|
| Vũ khí | `data/equipment/common_sword.tres` | Kiếm Sắt Lữ Hành, moveset kiếm 3 hit, base damage 10 |
| Áo | `data/equipment/starter_top.tres` | +10 HP tối đa, +5 giáp |
| Quần | `data/equipment/starter_pants.tres` | +5 HP tối đa, +3 giáp |
| Giày | `data/equipment/starter_boots.tres` | Không cộng chỉ số |
| Găng tay | `data/equipment/starter_gloves.tres` | +3 giáp, +2 sát thương |
| Nhẫn | `data/equipment/starter_ring.tres` | Không cộng chỉ số |
| Dây chuyền | `data/equipment/starter_amulet.tres` | Không cộng chỉ số |

Bộ đủ cho **115 HP tối đa, 11 giáp, +2 sát thương**. Kiếm thường nhát đầu gây 12 damage trước phòng thủ mục tiêu; tháo kiếm có đấm tay không base 5, thành 7 khi còn găng. Đây là các thông số khởi đầu đã chốt, chưa là cân bằng toàn bộ trò chơi.

Giáp dùng `incoming_damage × 100 / (100 + armor)`: 11 giáp giảm khoảng 9,91%, đòn 15 còn khoảng 13,5135. `DamageResolver` áp giáp một lần sau modifier trạng thái, trước Health; không sửa `DamageEvent.base_damage`. DIRECT/RESONANCE/DOT/ENVIRONMENT đều qua công thức này. Friendly fire, bất tử, dedup, HP cap và chết giữ pipeline cũ.

`EquipmentStats` tính lại từ nền và các món đang mặc; thay đồ không cộng chồng, không hồi máu và không hồi sinh. Tăng max HP chỉ tăng dung lượng. Lựa chọn bắt đầu run và retry là các điểm refill rõ ràng; room transition hoặc swap không được refill. `reset_base_stats()` bỏ bonus/penalty của run trước, rồi tính bộ khởi đầu mới. Tooltip hiện HP/Giáp/Sát thương và các bonus khác thực tế.

Ordinal `WEAPON=0, ARMOR=1, RING=2, AMULET=3` được giữ để không làm sai dữ liệu cũ; `ARMOR` nay là ô Áo. `PANTS=4, BOOTS=5, GLOVES=6` được thêm. Thứ tự trình bày UI có thể khác thứ tự ordinal.

## Động tác và phản hồi

AnimationPlayer có `idle`, `run`, `jump`, `fall`, `land`, `dash`, `attack_slash_1`, `attack_slash_2`, `punch`, `cast_spell`, `hurt`, `dead` và `RESET`. Pose chạy có tay/chân đối pha và đầu gối; nhảy, rơi, tiếp đất, lướt, trúng đòn và chết có clip riêng. Đây là cutout và pose theo xương, chưa là animation vẽ từng frame hoặc cloth simulation.

Melee/cast đọc clock Weapon/PlayerCastState bằng manual seek. Hit-stop dừng pose theo cùng clock; không có animation method track phát damage hoặc mở Hitbox. Mỗi đòn giữ hướng chuột đã commit; hình nhân vật lật theo chuột độc lập hướng chạy. Đòn DOT rút HP nhưng không lặp pose giật lùi như đòn trực tiếp.

Gói hiện hành thêm tóc và dải lưng trễ riêng theo chuyển động, tiếp đất co giãn hình quanh pivot chân và các pose `reaction_flinch`, `reaction_knockback`, `reaction_kneel`, `reaction_thrown`, `reaction_get_up`. Chúng đọc clock của `HitReactionComponent`; impulse, khóa điều khiển và hồi phục vẫn thuộc gameplay. Thứ tự trình diễn là chết → reaction đang hoạt động → attack/cast → dash → locomotion. Hit-stop giữ cả transform/bounds của landing squash và offset corpse, tránh đặt lại hình trước khi clock được phép chạy.

Corpse modular dùng tint 0,7 và tiếp xúc sàn theo bounds của các phần cơ thể/trang phục, không đổi collider. Lỗi corpse biến mất trong campaign được tái hiện trên GPU: actor rơi xuyên sàn do room bị disable khiến StaticBody2D mặc định bị gỡ khỏi physics. Terrain của room đã dùng KEEP_ACTIVE; không sửa motor để che lỗi. GPU diagnostic r4 giữ actor tại `(540, 640)`, bounds hình kết thúc đúng `y=640`, corpse nằm ngang nhìn rõ.

SlicePresentation phát bụi chân theo quãng đường và nhịp tối thiểu 0,16s khi chạy trên sàn; đứng yên và di chuyển trên không không phát bụi chạy. Nhảy từ mặt sàn và tiếp đất mỗi lần phát một puff; dash dùng phản hồi riêng. Giữ trần tám owner bụi, bốn GPU hạt mỗi puff, lifetime hữu hạn. Vệt chém, sparks, hit-stop, camera shake và SFX dùng hệ hiện hành và ngân sách cũ.

`MovementVFX` là component thuộc SlicePresentation: tối đa năm afterimage tồn tại 0,25s, chụp texture/transform của các phần đang mặc và kiếm đang cầm; các ảnh đứng lại trong world space, không có Hitbox hoặc đèn. Wind streak, takeoff ring, landing wave và bụi phanh dùng vùng atlas được duyệt, tối đa tám movement mark hữu hạn. Chỉ rơi xa đủ ngưỡng mới thêm microshake. Hệ này giữ nguyên cadence/pool tám puff của FootstepDust; chuyển phòng clear cả node lẫn registry lifetime.

Vệt chém dùng sáu vùng atlas theo sáu phẩm cấp; nguyên tố đã commit quyết định màu, phẩm cấp quyết định độ phức tạp. Đồ Thường giữ hiệu ứng nhẹ; vệt cấp cao không có giấy bùa. Hit spark và finisher dùng metadata mỹ thuật đã commit trong DamageEvent, không tính lại sát thương từ hiệu ứng. Burn/poison trình diễn theo trạng thái thật qua `ElementAfflictionVFX`, không tự gây hoặc cộng trạng thái.

## Kiểm thử và bằng chứng

Gate đầy đủ vẫn là `tests/run_tests.ps1`, gồm import, addon/editor và gameplay; không lọc ERROR/WARNING. `-GameplayOnly` chỉ phục vụ chẩn đoán. Chế độ `-CollectAllFailures` thu đủ lỗi nhưng vẫn trả thất bại nếu một gate lỗi.

Các suite mới kiểm riêng trang bị bảy ô, rig modular, bụi chuyển động, giáp, atlas thật và Hub→run→chết→Hub. Suite Movement55/Combat100/Resolver20 giữ nguyên assertions. Một số suite lịch sử dùng `tests/neutral_equipment_fixture.gd`: clone nông các Definition khởi đầu vào GearItem của fixture, đưa bonus về 0, giữ UID/texture/part references và không sửa Resource cache. Vì vậy chúng tiếp tục kiểm đúng hợp đồng 100 HP/base damage cũ. Armor/ModularEquipment/StarterCharacter/StarterFlow dùng **loadout sản phẩm thực**, không bật fixture trung tính.

Hai hợp đồng cũ được cập nhật có chủ đích và giữ số assertion: Inventory UI 4→7 ô, số item ban đầu trong phòng test 6→12. R1 có 22 failures do ba fixture Milestone/Alpha/Campaign chưa trung tính; đã sửa setup và focused cả60/120 đạt69/80/31. Log lỗi r1 được giữ nguyên, không coi nó là gate đạt.

Gate nền tảng r2 trong [character_foundation_gate_r2.log](verification/character_foundation_gate_r2.log) có **81 dòng RESULT, 3.390 assertion executions, 0 failures** và `ALL HEADLESS CHECKS PASSED`, gồm import/addon/editor/gameplay. Đây là kết quả tại mốc nền tảng trước khi thêm gói High Fidelity, không dùng nó làm kết quả gate cuối của mã đã mở rộng.

GPU starter preview r2/r3 là bằng chứng lịch sử của 16 capture cho trái/phải, chạy/nhảy/rơi/tiếp đất/dash, hành trang, tháo/mặc lại áo bằng GUI và combat. Capture đã chạy không chứng minh corpse hiển thị đúng; lỗi rơi xuyên terrain được tìm và kiểm lại bằng [diagnose_dead_gpu_r4.stdout.log](verification/diagnose_dead_gpu_r4.stdout.log) cùng ảnh `combat_art_death_diagnostic_default_r4.png` đã xem trực quan.

[Movement GPU r2](verification/movement_visual_gpu_r2.stdout.log) ghi **10 capture PASS**: run, skid, dash, jump, landing và năm pose reaction/get-up. [High Fidelity GPU r1](verification/high_fidelity_gpu_preview_r1.stdout.log) ghi **12 capture PASS**: Tiền Sảnh, close-up, sáu cấp slash, độc/cháy thực, finisher và Boss. Log xác minh chạy/chụp hữu hạn trên GPU; không tự coi tất cả ảnh đã được đánh giá mỹ thuật bằng mắt. Provenance ghi riêng các ảnh movement/corpse mà agent đã trực tiếp xem.

Focused sau cùng của phần rig ở cả 60/120 Hz: MovementVisual **34/34**, StarterCharacter **53/53**, ModularRig **49/49**, PlayerRig **52/52**. Các bài mới kiểm clock reaction thực, five-ghost/held-weapon, đời sống pool/material, wardrobe UID, floor contact và freeze toàn bộ silhouette. Stress tám chu kỳ không tăng objects/resources sau warm-up; chưa dùng phép đo hữu hạn này để khẳng định không thể có leak trong mọi tình huống.

**Gate toàn bộ sau tích hợp:** [High Fidelity r3](verification/high_fidelity_gate_r3.log) đạt **3.896/3.896**, 91 RESULT, không lỗi/cảnh báo; Movement55/Combat100 mỗi60/120Hz và Resolver20 giữ nguyên. Benchmark thật Tiền Sảnh/Boss đạt cảcap60/120, trung bình khoảng60/119FPS trênRTX5080/Compatibility1152×648. [Bảng đo và giới hạn](HIGH_FIDELITY_VISUALS.md), [summary JSON](verification/high_fidelity_test_summary.json). Đây là snapshot ổn định sau sửa F5 Hurt guard và terrain Bramble; không dùng headless/fixed-fps để suy ra FPS render. Manifest hash đã đối chiếu nguồn hiện tại.

Native shutdown `0xC0000005`/fault offset `0x547F2C` đã ghi ở các mốc trước vẫn chưa có root cause được xác định. Một lượt sạch không chứng minh lỗi native gián đoạn đã được chữa.

## Phần còn lại

Các board motion/slash v2/hurt được duyệt trước khi tích hợp gói hiện hành. Không tự thay đổi phong cách, làm toàn bộ wardrobe hoặc đưa lại hiệu ứng mạnh cho đồ Thường. Kiểm thực tế tiếp tục cần chú ý seam ở khớp, chân bám sàn, pose kneel, readability ở zoom chơi và cảm giác bấm; chưa đo được thời lượng run 15–20 phút hoặc hoàn tất art thương mại. Mở rộng vũ khí/trang phục tiếp theo vẫn làm lần lượt theo yêu cầu người dùng.


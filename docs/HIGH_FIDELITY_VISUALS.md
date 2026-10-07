# High Fidelity — chuyển động, phản ứng trúng đòn và VFX chiến đấu

2026-10-01, Godot 4.7.2/GDScript, Compatibility. Gói này tiếp nối [nền tảng nhân vật](CHARACTER_FOUNDATION.md) đã qua **3.390/3.390 checks** ở gate strict `verification/character_foundation_gate_r2.log`. Giữ kiếm sĩ cổ phong modular, bảy ô trang bị và bộ khởi đầu 115 HP/11 giáp/+2 sát thương. Hình minh họa chibi không thay đổi phong cách hoặc tỉ lệ nhân vật.

## Phần đã tích hợp

- Hai production PNG alpha trong `assets/vfx/movement/` và `assets/vfx/slashes/`, dùng **14 vùng AtlasTexture**: tám dấu chuyển động/trạng thái/va chạm và sáu bậc vệt chém. VFX dùng hạt khoáng, bụi, lửa, khí độc và kiếm khí; không phát giấy, lá cây hoặc mảnh bùa trang trí trên mỗi nhát chém.
- Chuyển động giữ cutout trên 18 xương; tóc và dải áo có góc trễ riêng, landing squash giữ pivot chân. Dash chụp cơ thể/trang phục/vũ khí đang mặc thành afterimage trong không gian thế giới. Không thêm bộ điều khiển di chuyển vào VFX.
- HitReactionComponent thêm bốn phản ứng được tác giả chọn trong DamageEvent: giật nhẹ, đẩy lùi, khuỵu và hất văng. Độc/cháy đọc trạng thái thật để nhuộm nhẹ sprite và bật emitter trên actor; không tạo bộ đếm sát thương thứ hai.
- Vệt chém dùng hình vẽ đã duyệt, giữ màu nguyên tố và bậc hiếm tại thời điểm commit. Va chạm dùng spark nhỏ; đòn kết chuỗi Sử thi trở lên có vết nứt khoáng và méo hình cục bộ hữu hạn.
- Ánh sáng gần Player, vignette góc và số sát thương được chỉnh để hỗ trợ đọc chiến đấu. Renderer vẫn Compatibility/SDR, HUD nằm ở lớp riêng.

Đây là ảnh cutout và chuyển động theo xương, không phải bộ animation vẽ mới từng frame. Các vũ khí khác tiếp tục dùng moveset đã định nghĩa; dagger thrust/whip/ranged giữ mesh hoặc cast fallback thích hợp, không bị đổi thành kiếm quét ngang.

## Danh mục VFX

| Thư mục vùng | Regions | Dùng cho |
|---|---|---|
| `assets/vfx/slashes/regions/` | common, rare, very_rare, epic, legendary, divine | Sáu bậc Thường→Thần thánh |
| `assets/vfx/movement/regions/` | dust_cloud, takeoff_ring, landing_wave, wind_streak | Phanh, nhảy, tiếp đất, dash |
| Cùng movement atlas | hit_spark, ground_crack | Tia khoáng khi trúng và vết nứt đòn kết |
| Cùng movement atlas | poison_wisp, burn_flame | Khí độc/lửa bám actor khi trạng thái còn sống |

Atlas slash có sáu ô 512×512, hướng +X. Tâm quỹ đạo tại pixel (170,256); Sprite2D centered dùng offset (86,0) để đặt đúng WeaponSocket cũ. Shader chuyển màu theo nguyên tố trong khi giữ độ sáng, alpha và chi tiết hình. Phẩm cấp chọn hình/radiance; không tự chọn màu nguyên tố.

Nguồn tạo ảnh, các bản duyệt và kiểm tra alpha/GPU được ghi trong phần bằng chứng bên dưới.

Ba board người dùng đã duyệt:

- [Chuyển động](art_approval/high_fidelity_movement_candidate_v1.png).
- [Slash v2 bỏ giấy/lá](art_approval/high_fidelity_wind_slash_candidate_v2.png).
- [Hurt/độc/cháy](art_approval/high_fidelity_hurt_candidate_v1.png), từ output ảnh `exec-fceb9ab8-f4e3-48d3-a344-af2f8ea2dcea.png`.

Production atlas được tạo riêng để có alpha và ô cắt rõ; board minh họa không được đưa nguyên khung nhãn/text vào gameplay. Prompt giữ cạnh các board và trong `art_approval/high_fidelity_{movement,slash}_atlas_v1.prompt.txt`.

## Đồng hồ và dữ liệu đòn đánh

`GearItem.quality` → `GearSession.sync_quality()` → `Weapon.visual_quality` → `AttackSnapshot.cosmetic_quality`. Snapshot đồng thời lưu `cosmetic_element`, `cosmetic_tint`, `cosmetic_combo_index`; Weapon sao chép các trường này sang DamageEvent. Resource moveset/rune dùng chung không bị sửa để lưu trạng thái mỹ thuật.

Màu được lấy từ bùa đã lắp khi commit; khi nhiều nguyên tố cùng hiện diện, precedence trình diễn Hỏa→Băng→Độc→Lôi→Phong được giữ nhất quán giữa slash và contact. Lôi có màu riêng kể cả khi payload chỉ có chain, không mang stun. Bùa rỗng dùng màu vật lý dịu. Đổi bùa/phẩm cấp khi đòn đang tồn tại chỉ ảnh hưởng lần commit tiếp theo; cancel/equip đổi moveset kết thúc đòn theo vòng đời Weapon cũ.

Ba đòn kiếm dùng quỹ đạo mỹ thuật 100°/130°/160°, easing cosine và nhát thứ hai quét ngược. Chúng đọc Active/recovery clock hiện hành với cửa sổ sweep 0,12 s, không đổi góc hitbox, sát thương hoặc thời gian combat. Không có animation method track gây damage. Bounded mesh 66 vertices/legacy sweep 120° vẫn là dữ liệu/fallback; khi art được chọn, hai lớp mesh sáng/ink được làm trong suốt để không chồng hai vệt sáng.

Một PointLight2D nhỏ thuộc WeaponTrail, texture_scale 0,35, energy khoảng 0,25–0,55. Chỉ bật trong Active khi có nguyên tố hoặc vũ khí từ Hiếm; kiếm Thường vật lý giữ đèn tắt. Pulse đọc đúng clock đòn, không dùng shader TIME để vượt qua hit-stop. Đây là **một owner ánh sáng thêm**, không một đèn mới mỗi attack.

Common giữ hình gọn, không ground decal hoặc screen warp. Tia va chạm là 10–14 hạt hướng ngược đòn, fan 42°, texture lớn được chuẩn hóa thành 3–7 px (Băng có thể 10 px). Chí mạng không nâng bậc hiếm hay số hạt lên bậc khác. Hit 3 từ Sử thi mới có decal nhỏ khoảng 94×17 px trong 1 s và warp cục bộ 96×96 px trong 0,12 s; hit spark/đèn vẫn hết trong 0,48 s. Tất cả cùng owner ImpactBurst hữu hạn, không thêm pool toàn cục.

## Chuyển động và lifetime

MovementVFX thuộc room presentation, ngoài cây vật lý của Player. Dash tạo tối đa năm afterimage, lifetime 0,25 s, gồm các Sprite đang mặc và vũ khí cầm trên tay tại thời điểm chụp. Mỗi ảnh lưu transform thế giới riêng; chuyển pose/đổi đồ sau đó không làm nó chạy theo nhân vật.

Nhảy lên và landing mỗi vòng chỉ sinh một dấu; phanh chỉ sinh ba hạt bụi sau chạy liên tục tối thiểu 0,22 s rồi giảm tốc qua ngưỡng. Một fall thật từ 180 px với tốc độ chạm sàn≥650 px/s tạo camera impulse 0,12. Không phát lặp ở idle, trên không, giữ vào tường hoặc teleport. Pool dấu tối đa tám owner, lifetime mặc định≤0,32 s; bộ bụi chân cũ tám puff/bốn hạt vẫn giữ cadence quãng đường và tối thiểu 0,16 s.

Tóc giới hạn±0,16 rad, dải áo±0,26 rad. Các hiệu ứng/secondary motion đọc tick đã đóng băng của CombatFeedback. Hit-stop phải giữ cả transform pose, landing squash và offset corpse, không chỉ dừng time counter; focused regression kiểm các transform thật.

## Phản ứng trúng đòn

| Reaction | Thời gian prototype | Hành vi |
|---|---|---|
| flinch | 0,16 s | Giật nhẹ; không khóa toàn bộ điều khiển |
| knockback | 0,24 s | Khóa action tạm; motor xử lý impulse ngang |
| kneel | 0,32 s | Khuỵu trên mặt đất; trên không chuyển knockback |
| thrown | Pose 0,36 s; chờ rơi tối đa 1,5 s | Hất lên→nằm 0,14 s→đứng dậy 0,26 s |

`heavy_hit` vẫn dùng hợp đồng cũ, không tự suy ra một reaction khác. DOT/ignore_damage_grace/blocked/lethal không khởi động phản ứng mới. Super armor của moveset vẫn được tôn trọng theo authored heavy hit. Player tick component đúng một lần; BuildPlayerMotor sở hữu velocity và một lần move_body, hai FSM giữ vòng enter/exit của Attack/Cast/Dash/Hurt/Dead.

Dash phục hồi có cửa khóa tối thiểu 0,12 s và phải qua kiểm tra dash/mana hiện hành, không dash miễn phí. Hoàn tất/get-up có bảo vệ bổ sung tối thiểu 0,18 s theo grace hiện hành. Q/click/F5 cycle khi Hurt phải tôn trọng action lock; đổi dữ liệu bằng inventory/debug không được thoát Hurt về Ready để bỏ qua recovery hoặc đánh thức Player đã chết. Modal đóng/mở không xóa reaction; relocate/reset/death dọn component ở những điểm vòng đời rõ ràng.

## Chết, terrain và trạng thái nguyên tố

Terrain của DungeonRoom và EnvironmentBarrier đặt `CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE`. Khi trận đấu dừng process của phòng để mở màn Thất Bại, sàn/Bramble kín vẫn còn trong physics; Player đang rơi có thể tiếp đất và xác giữ trên bề mặt đang đứng. Cách này sửa lỗi corpse rơi xuyên nền hoặc qua chướng ngại sau khi room bị disable; shape, vị trí và layer terrain không đổi. Barrier đã mở vẫn giữ shape disabled; KEEP_ACTIVE không đóng lại lối đi. Dọn phòng vẫn giải phóng terrain/collider như trước. Alpha và campaign kiểm riêng chết từ mặt sàn, bục, trên không, Bramble Stage 2 và đang bị hất văng.

ElementAfflictionVFX đọc StatusController/ElementStatusController thật: burn nine particles, poison seven, lifetime hạt 0,8 s. Khi hết status, chết hoặc actor teardown, emitter/tint được tắt và dọn cùng actor. Shader hit_flash có `status_strength` mặc định 0, giữ alpha và API flash cũ. Độc và cháy đồng thời pha hai màu; đổi skin remount lại material của actor, không sửa texture/Resource cache hay actor khác. DOT không gọi lại chuỗi phản ứng chiến đấu chỉ vì đang nhuộm màu.

Số sát thương có pop 1,4→1 trong 0,12 s, chuyển động cong với gravity 240 px/s², jitter nhỏ độc lập từng owner; lifetime 0,65 s. Crit thêm màu vàng/font 29/dấu! và nét lôi nhỏ, font thường 18. Clock dừng cùng hit-stop, không dùng số sát thương để quyết định gameplay.

## Ánh sáng và ngân sách

Giữ BG_CANVAS/max layer 0 và SDR glow. Player mote texture_scale 2,5 trên radial 128 px cho bán kính khoảng 160 px; vignette strength 0,18 ở CanvasLayer 1, HUD ở layer cao hơn. Năm chi mote yên tĩnh chỉ phát khi Player sống, grounded, Idle/Ready; không coi mote môi trường là aura trang bị Thường. Torches/ambient ash và projectile glow giữ owner hiện hành.

Ngân sách giữ: impacts 24, impact lights 8, projectile lights 12, projectile trails 24; movement ghosts 5/marks 8, bụi chân 8, thêm blade light 1 có điều kiện. Particle và decal có lifetime hữu hạn dù renderer headless không gửi GPU finished. AudioManager/room voices không được tái tạo bởi các effect mới.

## Kiểm thử và trạng thái xác minh

Gate chuẩn vẫn `tests/run_tests.ps1`, gồm import, addon shutdown/editor, validate và tất cả suite 60/120. Không lọc ERROR/WARNING. `-CollectAllFailures` chỉ thu đủ lỗi, không biến failed gate thành pass; headless/fixed-fps không chứng minh FPS render.

Năm suite bổ sung: combat_visuals, movement_visual, hit_reaction, death_ground, affliction_visuals. Chúng kiểm loadout/atlas sản phẩm, snapshot quality/hue, đổi bùa giữa đòn, freeze transform, reaction/recovery, sàn sau defeat, status tint, finite pools và cleanup. Movement 55/Combat 100/Resolver 20 giữ kiểm thử gốc; fixture gear trung tính chỉ dùng cho hợp đồng lịch sử, suite sản phẩm mới không dùng fixture đó.

**Full strict R1:** `verification/high_fidelity_gate_r1.log` đạt 3.884/3.884 checks, exit 0, không ERROR/WARNING; validator 113 scripts/20 scenes, content_data 48 checks. Rig có sửa freeze transform trong lúc R1 chạy, nên R1 không là bằng chứng toàn bộ snapshot cuối.

**R2 trước audit cuối:** `verification/high_fidelity_gate_r2.log` cũng đạt 3.884/3.884, exit 0, không ERROR/WARNING. Audit sau đó tái hiện hai đường chưa được suite bao phủ: debug F5 bỏ Hurt guard và Bramble bị loại khỏi physics khi room disable. Đã sửa và thêm regression input F5/defeat trên Bramble thật; R1/R2 được giữ làm bằng chứng lịch sử trước các bản sửa.

**Gate cuối R3:** [raw log đầy đủ](verification/high_fidelity_gate_r3.log) đạt **3.896/3.896 checks**, 91 dòng RESULT, exit 0 và `ALL HEADLESS CHECKS PASSED`. Không ERROR/WARNING/SCRIPT ERROR; validator 113 scripts/20 scenes, content_data 48 checks. Product code và test không đổi trong toàn bộ lượt R3; benchmark GPU kết thúc trước khi chạy gate. Import/addon/editor/main scene đều qua cùng gate strict.

| Suite sản phẩm mới | Checks mỗi lượt 60/120 Hz |
|---|---:|
| combat_visuals | 74 |
| movement_visual | 34 |
| hit_reaction | 70 |
| death_ground | 33 |
| affliction_visuals | 38 |
| starter_character / starter_flow | 53 / 15 |

Các stress suite ghi objects/resources trước và sau cleanup, gồm wardrobe, Hub, movement/status VFX và chuyển phòng. Lượt kiểm hữu hạn không cho thấy owner/resource tích lũy; đây không phải phép chứng minh không có mọi kiểu leak trong một phiên chơi dài.

## Benchmark GPU thực

Bốn lượt render cuối đã đạt các assertion trên **RTX 5080 / Compatibility / 1152×648**, gồm emitter độc/cháy thật, năm afterimage, tám movement mark và crack/warp Sử thi trở lên. Mỗi lượt warm-up 2s, đo khoảng 6s; frame time dưới đây gồm thời gian chờ giới hạn FPS. Không chạy full headless đồng thời để tránh tranh CPU.

| Phòng / mức | FPS render trung bình | p95 frame time | JSON |
|---|---:|---:|---|
| Tiền sảnh / 60 | 59,905 | 17,873ms | [foyer60](verification/high_fidelity_foyer_render_60.json) |
| Tiền sảnh / 120 | 119,102 | 9,785ms | [foyer120](verification/high_fidelity_foyer_render_120.json) |
| Boss / 60 | 59,878 | 17,749ms | [boss60](verification/high_fidelity_boss_render_60.json) |
| Boss / 120 | 118,958 | 10,137ms | [boss120](verification/high_fidelity_boss_render_120.json) |

Fixture stress dùng 10 phép/s, 20 impact/s, 10 loot/s, emitter độc/cháy đang hoạt động, năm ảnh dash/tám movement mark cùng lúc, luân chuyển moveset/phẩm cấp và đèn/glow/hạt môi trường thật. Boss ở phase2 với hai Slime/Eclipse. HP Player/Boss được giữ, hit-stop tắt khi đo throughput; input/reaction/hit-stop thật được kiểm riêng bằng suite và preview. Audio mixer chạy với SFX bus muted. Đây là phép đo stress hữu hạn trên máy này, không phải cam kết 120 FPS ở mọi frame, cấu hình hoặc cả run 15–20 phút.

Các owner đạt đỉnh trong ngân sách: 24 impact, 8 impact light, 12 projectile light, 16 spatial voice, 5 afterimage và 8 movement mark. Warp đồng thời tối đa 3 trong lượt đo, ground crack tối đa **18** (Tiền sảnh120); cả hai vẫn thuộc trần 24 ImpactBurst. Draw calls tối đa **500**. Mức120 đo gần119 FPS trung bình; p95 trên8,33ms nên chưa chứng minh giữ tuyệt đối120FPS mỗi frame.

Benchmark fixture r2 từng thiếu `DamageEvent.source_id`, khiến damage bị chặn và không bật status thật. Đã sửa **test fixture**, bổ sung kiểm tra blocked/burn/poison emission; bốn kết quả r3 phía trên sạch. Raw logs r1/r2 được giữ để phân biệt lỗi fixture với lỗi sản phẩm.

## Nguồn ảnh và capture GPU

[Manifest nguồn ảnh](verification/character_art_provenance.json) ghi tám ảnh nguồn/bản duyệt, SHA256, prompt, phạm vi duyệt, kích thước/mode/alpha thực và **34 vùng atlas** cho nền tảng nhân vật cùng VFX. Production PNG alpha và nguồn AI là bản sao đúng hash; atlas region/crop là cấu hình Resource. Việc duyệt board xác nhận hướng mỹ thuật, không được ghi thành duyệt riêng từng pixel production.

Hai lượt GPU preview tạo **22 capture** và đạt assertion render/lifetime. Ảnh lưu theo nhóm dưới đây; log chứng minh việc chụp, không thay cho người dùng đánh giá trực tiếp game feel.

| Nhóm | Capture |
|---|---|
| Chuyển động | [Run](verification/movement_visual_run_secondary.png), [phanh](verification/movement_visual_skid_dust.png), [dash](verification/movement_visual_dash_afterimages.png), [nhảy](verification/movement_visual_jump_takeoff.png), [tiếp đất](verification/movement_visual_landing_compression.png) |
| Phản ứng | [Flinch](verification/movement_visual_reaction_flinch.png), [knockback](verification/movement_visual_reaction_knockback.png), [kneel](verification/movement_visual_reaction_kneel.png), [thrown](verification/movement_visual_reaction_thrown.png), [get-up](verification/movement_visual_reaction_get_up.png) |
| Slash sáu bậc | [Thường](verification/high_fidelity_slash_tier_0.png), [Hiếm](verification/high_fidelity_slash_tier_1.png), [Cực hiếm](verification/high_fidelity_slash_tier_2.png), [Sử thi](verification/high_fidelity_slash_tier_3.png), [Huyền thoại](verification/high_fidelity_slash_tier_4.png), [Thần thánh](verification/high_fidelity_slash_tier_5.png) |
| Actor/va chạm | [Starter](verification/high_fidelity_starter_closeup.png), [độc](verification/high_fidelity_poison_player.png), [cháy](verification/high_fidelity_burn_player.png), [impact Sử thi](verification/high_fidelity_epic_impact.png) |
| Phòng | [Tiền sảnh kích thước game](verification/high_fidelity_foyer_native.png), [Boss](verification/high_fidelity_boss_arena.png) |

Log preview: [10 capture chuyển động](verification/movement_visual_gpu_r2.stdout.log), [12 capture High Fidelity](verification/high_fidelity_gpu_preview_r1.stdout.log). [Capture corpse riêng](verification/combat_art_death_diagnostic_default_r4.png) ghi vị trí actor/chân tại y=640, được agent rig xem để kiểm xác tiếp sàn. Các agent đã xem những ảnh liên quan phần mình và root xem thêm Tiền sảnh/Boss; không tuyên bố đã review mỹ thuật toàn bộ mọi frame.

Native shutdown **0xC0000005 / fault 0x547F2C** ở lịch sử vẫn chưa có root cause được xác định; không tuyên bố đã sửa chỉ từ các lượt sạch.



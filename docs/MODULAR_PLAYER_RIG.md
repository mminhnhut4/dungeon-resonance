# Skeleton2D và nhân vật ghép bộ phận

> Tài liệu này giữ bằng chứng của mốc khung rig và concept PNG trước. Player hiện đã có atlas chia bộ phận, bảy ô trang bị và18xương khi dùng skin modular; xem [CHARACTER_FOUNDATION.md](CHARACTER_FOUNDATION.md) cho kiến trúc và phạm vi hiện hành. Các con số14xương/slot trống/chưa atlas dưới đây mô tả mốc lịch sử, không thay thế trạng thái mới.

Scene `res://scenes/actors/player_visual_rig.tscn` là một rig cutout 2D độc lập. Player instance rig ở node `Visuals`; controller, hai FSM, Motor, Aim, WeaponSocket, Hitbox và Hurtbox giữ nguyên cây vật lý. Rig đọc trạng thái sau Player ở physics priority 10, không phát DamageEvent và không điều khiển di chuyển.

```text
Player [CharacterBody2D]
├── BodyCollision                           ← giữ nguyên
├── Visuals [instance PlayerVisualRig]
│   ├── Skeleton2D
│   │   └── Root [Bone2D]
│   │       └── Hip [Bone2D] + HipSprite
│   │           ├── Torso [Bone2D] + BodySprite
│   │           │   ├── Head [Bone2D]
│   │           │   │   └── HeadSprite, Hair, Face, Mask [Sprite2D]
│   │           │   ├── Shoulder.L [Bone2D] + ShoulderSprite
│   │           │   │   └── Arm.L [Bone2D] + ArmSprite
│   │           │   │       └── Hand.L [Bone2D] + HandSprite
│   │           │   │           └── WeaponSlot [Node2D] / WeaponSprite
│   │           │   └── Shoulder.R / Arm.R / Hand.R / WeaponSlot
│   │           ├── Leg.L [Bone2D] + LegSprite
│   │           │   └── Foot.L [Bone2D] + FootSprite
│   │           └── Leg.R / Foot.R
│   └── AnimationPlayer
│   └── ConceptFootPivot / ConceptSprite      ← overlay tạo khi có concept PNG
├── Combat / Aim
├── Combat / WeaponSocket / Weapon / Hitbox   ← giữ nguyên
└── Hurtbox / CollisionShape2D               ← giữ nguyên
```

Có 14 Bone2D với rest pose, length và bone angle khai báo rõ; 18 Sprite2D có thể lắp riêng. Scene rig độc lập không có texture. Player gán `fallback_body_texture` PNG lên BodySprite và `concept_body_texture` bằng `res://assets/sprites/player/player_concept_full.png`. Khi concept hoạt động, BodySprite được ẩn nhưng vẫn là adapter cho `Player.body_sprite`, giữ flash/bất tử/flip của controller hiện hữu. ConceptSprite nằm ngoài Skeleton; các pose xương không deform hình toàn thân này. Atlas bộ phận sẽ dùng các ô Sprite2D hiện có sau này. Không cần Aseprite CLI.

## PNG thực, nền trong suốt và điểm tựa bàn chân

Concept nguồn là PNG 1248×832 đã chuẩn hóa từ hình người dùng cung cấp. File vẫn có nền trắng opaque. Rig tạo ImageTexture riêng ở runtime: flood-fill các pixel gần trắng nối với mép ảnh và đổi alpha thành 0. Các vùng trắng được đường viền bao kín, gồm mặt nạ nhân vật, giữ nguyên. RGB của hình và bytes PNG nguồn không bị sửa; thuật toán không dùng color key trắng trên toàn ảnh.

Source Texture2D giữ một cache native qua metadata `dungeon_concept_alpha_v1`, gồm ImageTexture/bounds/foot_pixel. Cache không chứa Node, Script hay tham chiếu ngược tới texture nguồn; không dùng static Resource trong GDScript. Các Player dùng cùng asset tái sử dụng mask, không flood-fill lại mỗi lần đổi phòng. Mask chỉ được tạo cho nguồn tối đa 4.194.304 pixel.

Rig tìm bounds alpha còn nhìn thấy và trung điểm các pixel boot ở đáy. `ConceptFootPivot` đặt tại đáy `BodyCollision`; ConceptSprite dùng offset âm của boot pivot và scale theo `concept_height` (mặc định 42 px). Collider gốc cao 36 px giữ nguyên. Khi `flip_h` đổi, offset X được bù theo `texture_width - foot_x`, giữ boot pivot tại cùng tọa độ dù ảnh không đối xứng. `get_concept_foot_world()` trả vị trí điểm tựa để kiểm thử. Hình nguồn có boot bị cắt ở mép dưới; hệ thống căn phần boot còn nhìn thấy, không tái tạo phần chân đã thiếu.

Các API quan sát: `concept_sprite`, `concept_pivot`, `concept_bounds`, `concept_foot_pixel`, `visual_facing_left`, `breath_tween`. `prepare_concept(texture)` chuẩn bị hoặc đổi concept; texture export được nạp khi rig ready.

## Animation và đồng hồ chiến đấu

| Clip | Pose mẫu | Nguồn thời gian |
|---|---|---|
| idle | Nhấp nhô Hip, co giãn Torso theo nhịp thở | Chu kỳ 1,2s trong trạng thái nghỉ |
| run | Nghiêng Torso, tay và chân vung đối pha | Chu kỳ 0,6s trong locomotion Run |
| attack_slash_1 | Tay vung theo chiều thứ nhất | Wind-up → clip 0–0,2s; Active → 0,2–0,3s; Recovery → 0,3–0,6s |
| attack_slash_2 | Vung ngược cho nhát kế tiếp | Cùng ánh xạ; chọn theo chẵn/lẻ combo index |
| cast_spell | Giơ tay rồi đẩy ấn về trước | Wind-up → 0–0,2s; recovery sau phóng → 0,2–0,5s |
| RESET | Pose gốc | Dùng khi đổi clip, hủy/ chết và preview |

AnimationPlayer dùng manual seek theo thời gian còn lại của Weapon/PlayerCastState. Vì vậy vũ khí có wind-up khác nhau vẫn đưa rig vào vùng Active đúng lúc Hitbox mở. Hit-stop dùng đồng hồ hiện hữu: rig và mesh trail đứng lại cùng đòn đánh. Không có animation method track mở hitbox hoặc gây damage lần thứ hai.

Concept dùng thêm một Tween trên `ConceptFootPivot.scale.y`: 1 → 1,03 trong 0,6s → 1 trong 0,6s, ease Sine/InOut, lặp khi Action Ready và locomotion Idle. Điểm tựa ở gốc pivot nên thở không nhấc chân khỏi sàn. Tween chạy theo physics, được pause cùng hit-stop, resume cùng Tween cũ và kill/reset khi chạy, nhảy, dash, attack/cast, dead, unbind hoặc exit. Không tween CharacterBody2D, collider hay gameplay Weapon.

WeaponSlot định hướng theo hướng đã commit của snapshot; thay vị trí chuột giữa đòn không bẻ nhát chém. Skeleton và concept lật theo vị trí con trỏ trái/phải so với Player, độc lập hướng chạy. Rig bù `BodySprite.flip_h` do controller sở hữu để tránh lật hai lần; concept có flip riêng. Flash máu được truyền sang cả concept và các sprite đã lắp. WeaponSlot là vị trí trang trí vũ khí; không reparent Weapon/Hitbox vào xương.

## Nạp bộ phận

```gdscript
var rig := player.get_node("Visuals")
rig.equip(&"hair", hair_atlas_texture)
rig.equip(&"mask", mask_atlas_texture)
rig.equip(&"weapon_right", sword_atlas_texture)
rig.equip(&"mask", null) # tháo mặt nạ
```

Slot được whitelist, không nhận NodePath tùy ý. Các slot: body/torso, hip, head, hair, face, mask, shoulder_left/right, arm_left/right, hand_left/right, leg_left/right, foot_left/right, weapon_left/right. Texture assignment nằm trên từng Sprite instance, không sửa shared Resource. Pivot mỗi bộ phận là gốc local của Bone tương ứng; chuẩn hóa atlas theo pivot trước khi làm art hoàn chỉnh. Chưa có atlas bộ phận hay mesh deform/IK; đây là khung rig và pose mẫu theo yêu cầu.

Khi chuyển sang atlas đã tách bộ phận, ẩn `concept_pivot`, bật lại `body_sprite.visible` và thay texture/offset từng ô. Hình concept hiện tại chỉ có lật/flash/thở tổng thể; nó chưa có hoạt ảnh chân tay riêng và không thay thế atlas rig hoàn chỉnh.

## Kiểm chứng

`tests/player_rig_test.gd` giữ **52/52** tại 60/120 physics Hz: hierarchy/rest, slot độc lập, track chỉ chạm xương, các phase của bốn moveset, combo/cast, committed aim, hit-stop và bất biến hitbox/hurtbox/HP/năng lượng. Stress 8 rig sau warm-up: objects 2419→2419, resources 207→207.

`tests/player_art_test.gd` đạt **35/35** ở cả hai mức tick: source PNG/bounds, alpha nền nối mép, giữ trắng mặt nạ, không sửa bytes nguồn, cache native, flip theo chuột độc lập movement, boot pivot khi mirror/thở, Tween lifecycle, flash và teardown. Stress 8 concept rig: objects 2405→2405, resources 202→202; các lần chạy này không ERROR/WARNING. Đây là stress hữu hạn, không chứng minh mọi thời lượng chơi. Root chạy lại Movement 55/55, Combat 100/100 và full strict runner cùng bản tích hợp; xem báo cáo milestone cuối để biết kết quả toàn bộ và benchmark GPU.

API nền: [Skeleton2D](https://docs.godotengine.org/en/stable/classes/class_skeleton2d.html) quản lý hierarchy/rest của Bone; [Bone2D](https://docs.godotengine.org/en/stable/classes/class_bone2d.html) dùng rest tương đối parent; [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html) lưu clip và hỗ trợ seek. Thiết lập explicit length tránh cảnh báo auto-calculate trên xương lá.

Tween là lựa chọn trình diễn của dự án; API tại [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html). Mask alpha nối mép và điểm tựa boot là thuật toán riêng của rig; runtime texture dùng [ImageTexture](https://docs.godotengine.org/en/stable/classes/class_imagetexture.html).

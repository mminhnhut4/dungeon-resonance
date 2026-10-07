# Combat cơ bản và ngắm chuột

Main scene: `res://scenes/test_level.tscn`. J/chuột trái đánh cận chiến; chuột quyết định hướng chém 360°. A/D vẫn quyết định hướng chạy/Sprite. R đặt lại phòng, HP, bia, quái và các hiệu ứng.

## Combo

| Đòn | Windup | Active hitbox | Recovery | Damage | Push / lift |
|---|---:|---:|---:|---:|---|
| 1 | 0,065s | 0,085s | 0,115s | 10 | 140 / -60 px/s |
| 2 | 0,075s | 0,085s | 0,125s | 12 | 180 / -90 px/s |
| 3 | 0,10s | 0,11s | 0,20s | 18 | 340 / -160 px/s |

Nhấn riêng từng lần để nối combo; giữ nút không tự đánh liên tục. Trong một đòn, một lần nhấn tiếp được buffer; sau recovery có cửa sổ 0,22s để nối đòn 2/3. Hết cửa sổ bắt đầu lại đòn 1. Damage là thông số nền của moveset, không là nâng cấp cấp vũ khí.

Mỗi nhát chốt hướng chuột tại lúc bắt đầu. Đổi chuột trong windup/active không bẻ hitbox đã commit; nhát kế tiếp lấy hướng mới. Marker vàng nhỏ chỉ hướng ngắm hiện tại. Có thể chạy/nhảy khi đánh, chém lên/xuống và chém ngược hướng chạy. Dash hủy combo ở mọi phase và đóng hitbox ngay.

## Damage và phản hồi

Weapon xoay Hitbox và hình nhát chém cùng một transform quanh WeaponSocket tại ngực. Active window dùng physics shape query tại vị trí sau Motor.move_body. Một actor có nhiều Hurtbox vẫn chỉ nhận một hit mỗi nhát.

DamageEvent mang source/target, attack/window/root/parent ID, hướng, world target, damage, world knockback. X của data knockback là push theo hướng ngắm; Y là lift theo trục world. Hurtbox lọc team/self/i-frame, Resolver lọc duplicate/dead/invalid và Health phát lượng damage thực nhận.

Hit-stop 0,05s dừng Player, Dummy, Slime, combo/cast/status/cooldown/đạn; vẫn nhận buffer input và HUD vẫn cập nhật. RoomCamera rung tối đa 2,5 px mỗi trục, giảm trong 0,16s. Không thay Engine.time_scale hoặc SceneTree.pause.

Bia 120 HP: flash trắng rồi đỏ, knockback vật lý, số damage nảy/fade, số chí mạng có dấu !. HP refill sau 2s không bị đánh; quay về chỗ sau 0,7s; chết respawn sau 0,8s. R reset số hit, tổng damage và DPS.

DPS prototype = tổng damage thực / thời gian gameplay đo của các chuỗi đánh (denominator tối thiểu 0,1s). Đồng hồ dừng khi hit-stop và khi đã không nhận hit quá 2s; R bắt đầu phép đo mới. Chưa là thống kê cho boss/run dài.

I/chuột phải hiện thi triển phép qua CastSpell; xem [RESONANCE_PROTOTYPE.md](RESONANCE_PROTOTYPE.md).

## Kiểm chứng

Combat suite: **100/100** ở 60/120 physics tick/giây, gồm 84 kiểm tra gốc và 16 kiểm tra con trỏ. Đã kiểm active window, combo, cancel, nhảy+đánh, knockback, damage dedup, HP chết/respawn, text/flash, multi-Hurtbox, hit-stop/input buffer và teardown.

Runner: `tests/run_tests.ps1`. Log: `docs/verification/combat_60.log`, `combat_120.log`. Người dùng đã đánh thử bản combat trước khi chuyển sang ngắm chuột và báo ổn định; bản hướng chuột mới đã qua integration.

API query đối chiếu [Godot — Area2D](https://docs.godotengine.org/en/stable/classes/class_area2d.html) và [PhysicsDirectSpaceState2D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate2d.html).

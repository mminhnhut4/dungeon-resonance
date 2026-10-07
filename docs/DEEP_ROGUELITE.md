# Survival / Storyteller / Sanctuary

Hệ thống gắn qua SurvivalSession, giữ DamageEvent và FSM hiện hữu. Các hằng số là lựa chọn prototype để playtest.

## Incident Director

Threat = `(35 + tổng shard×5 + quality vũ khí×15) × (0.4 + 0.6×HP/maxHP)`, clamp 10–250. Máu thấp giảm ngân sách; Threat điều chỉnh khoảng nghỉ. Một incident hoạt động; duration 14/18/22s cho steady/balanced/chaotic.

| Incident | Hành vi / đối phó |
|---|---|
| Toxic Miasma | 2 HP/s qua DamageEvent cho actor ngoài safe radius; Player stress +2,5/s. Đài thanh tẩy radius 90 hoặc bùa Phong tạo vùng sạch radius 160 trong 3s |
| Manhunter Swarm | Attack rate ×1.4, mắt đỏ; Slime tìm mục tiêu gần không phân biệt team; mask khôi phục khi kết thúc |
| Wandering Smuggler | Trong khu bí mật; một Dao Găm Masterwork, trả 15 Soul hoặc hiến 10 max HP của run; không mua lặp cùng incident |
| Arcane Eclipse | Vùng nhìn 175px quanh Player; Hỏa/Lôi damage ×2 tại commit; HUD trên lớp tối |

Ổn định chạy chu kỳ event, Cân bằng random ưu tiên merchant khi thấp máu, Hỗn loạn random/thời gian nghỉ biến thiên. Hết incident/chuyển phòng/chết khôi phục modifier và entity tạm.

## Cơ thể / stress

- Heavy/Critical hit có thể gây injury; BodyConditionComponent riêng từng actor.
- Bleeding tick theo severity, vận động tăng severity; đứng yên 1,5s hoặc dùng bandage băng bó. Không trừ HP trực tiếp ngoài DamageEvent.
- Crippled Leg: speed ×0.6, cấm Air Dash 5s; dash dưới đất vẫn được phép.
- Severe Burn: heal ×0.5, cast cooldown ×1.5 trong 8s. Modifier trung tính không ảnh hưởng fixtures legacy.
- Áp lực 0–100 tăng khi cast bùa/ở Toxic; 100 gây mental break 12s: 3 phantom thị giác hữu hạn, hoặc Berserk melee ×1.5 và mất 5 HP khi vung hụt.
- Campfire an toàn giảm stress 4/s. Chết/reset dọn injury/mindbreak/modifier.

## Quality / salvage / crafting

GearItem UID riêng: **Awful / Normal / Good / Masterwork / Legendary**. Damage factor **0.85 / 1 / 1.1 / 1.2 / 1.35**, extra slot **0 / 0 / 1 / 1 / 2**, resonance proc **0 / 0 / 0.12 / 0.22 / 0.35**. Max Catalyst 5 / Weapon 3. Yêu cầu mới này thay mặc định cũ không nâng weapon stats.

C mở tình trạng cơ thể/túi đồ/cổ vật; E ở campfire mở chế tạo. Rã đồ kiểm UID tồn tại và không đang trang bị/khảm, commit tài nguyên một lần. Weapon/Catalyst/Rune rã thành Ancient Metal hoặc Crystal Dust; cổ vật không rã. Upgrade quality, potion (4 dust), bandage (2 dust), trap (4 metal). Trap cap 8, lifetime 45s, một hit 25 damage/stun 0,5s rồi mất.

Recipe 4/5 shard để thử slot cao cấp: `astral_firestorm`, `eclipse_blades`; exact multiset không match subset.

## Sanctuary / save

Elite cho 3 Soul, Boss 25. Soul giữ khi chết; profile version 1: `user://sanctuary_v1.json` (temp flush/rename + backup recovery). Lưu Soul/unlock/discovered/archive/style/vũ khí khởi đầu; không lưu HP/item/bag/injury/cooldown của run.

Anvil mở Quạt Phi Đao 50 Soul, Trượng Trì Chú 75; Archive lưu recipe đã khám phá 5 Soul; chọn steady/balanced/chaotic cho run. Hub và dungeon dùng cùng profile; scene/run được giải phóng.

Sân thử: F1 random Toxic/Swarm/Eclipse; F2 bleeding + cripple; F3 +100 Soul/crafting; C chi tiết/cổ vật. F5–F8 xem báo cáo Content. Debug grant là thao tác thử, không là reward chính thức.

Ở 60/120 Hz: Storyteller **29**, Conditions **29**, Crafting **32**, Sanctuary **28**, tất cả 0 fail. Có test không rã duplicate/equipped, recipe slot cao, save/load/recovery/Soul death→Hub và 8 chu kỳ Hub/dungeon; Object/Resource count trở lại baseline. Giới hạn addon ở [ADDONS.md](ADDONS.md).

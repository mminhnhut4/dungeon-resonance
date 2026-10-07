# Alpha Gameplay Loop / Gear / Secrets

Prototype logic dùng hình khối và nhãn debug. Main mở Sanctuary; **Alpha · 3 phòng gốc** chạy `dungeon_run.tscn`. Campaign mới kế thừa luồng này, xem [MILESTONE_CONTENT_REPORT.md](MILESTONE_CONTENT_REPORT.md).

## Luồng Alpha

1. Phòng 1: 3 Slime 60 HP và bia tập. Cửa đóng đến khi dọn sạch.
2. Phòng 2: hai đợt 3 Slime; quái cuối mỗi đợt là elite, thưởng 3 Soul.
3. Phòng 3: **Golem Cổ Bảo 500 HP**. Phase 1 quét sàn rộng, bắn 3 orb homing. Dưới 250 HP vào phase 2 đúng một lần, speed ×1.3, recovery ngắn hơn, triệu hồi 2 Slime, nhảy/dậm phát 2 sóng về mép phòng.
4. Boss chết: adds/hazards tan, cửa mở, rương lớn mở khóa và cổng E kích hoạt; thưởng 25 Soul.
5. HP=0: khóa input, đóng modal, hiện Thất Bại/Thử lại ngay/Thoát; GameFlow về Hub sau 1,2s. Thử lại trước khi về Hub hủy lịch chuyển. Chiến thắng về Hub sau 2s.

Sau dọn phòng 1/2 có campfire. Đi sang phải qua x=1220 vào phòng kế. HP, energy, weapon UID, rune loadout và cooldown giữ qua room. Retry làm mới run, giữ Soul.

Golem có Stagger 100: tích đủ stun 1s, sau đó 4s kháng tái choáng. Boss chống freeze/stun/pull thường; burn/poison/slow/armor-break vẫn đi pipeline. Thông số còn cần playtest.

## Gear / tài nguyên / môi trường

- Kiếm Cổ: 3-hit sweep vừa; Dao Găm Ám Khí: 4-hit thrust ngắn/nhanh/crit cao; bốn archetype content có dữ liệu riêng.
- Q xoay vòng vũ khí sở hữu. Chuột trái/J theo cursor; từng hit có timing/shape riêng.
- Bùa slot Weapon biến đổi đòn thường; slot Catalyst quyết định phép chuột phải/I. Energy 100, dash 25, cast 30, regen 24/s sau 0,45s; cooldown recipe vẫn áp dụng.
- Nhận đòn có i-frame nhấp nháy 0,6s. DOT cơ thể dùng DamageEvent nội bộ, không lợi dụng contact immunity để chữa vết thương.
- Loot bay/bob, tự hút 95px sau 0,35s; E nhặt 100px. Cap 96, lifetime 90s; potion +30 không tiêu hao khi đầy HP.
- Tab mở bảng bùa, giảm thời gian xuống 10%. Chọn ô rồi bùa; Shift+ô đổi hai slot, Backspace tháo; 1–3/5–6 Catalyst, 4/7–8 Weapon, F/G/H/B/V là Hỏa/Phong/Lôi/Băng/Độc.
- Tường ảo mở bằng 2 hit khác nhau hoặc 1 phép; rào gai chỉ mở bằng burn (Hỏa/Bão Lửa). Hurtbox môi trường dùng chung damage pipeline.
- E mở rương gần; chỉ bung loot một lần. Rương quality-mode có 5 nguyên tố, các vũ khí content và Catalyst; phòng 1.5 thêm cổ vật.

`test_level.tscn` giữ 2 bia/2 Slime, tường ảo, rào gai, rương và campfire. R reset phòng/actor/status/entity; 1–4 chọn ba cặp cũ/basic. F1–F8/C được mô tả ở các báo cáo khác.

Alpha **80/80**, Gear **35/35** ở 60/120 Hz; source/gameplay sạch. Import addon shutdown còn issue riêng. Stress loot 3×300 yêu cầu spawn giữ cap và Object/Resource count trở lại baseline.

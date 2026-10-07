# Căn Cứ Lữ Khách — World-Building & Combat Ecosystem

**2026-10-02 — Sửa có mục tiêu đã hoàn tất:** NPC72/72 ở60/120Hz; full strict5.666/5.666 (116gate,111RESULT), validator148script/31scene/176Resource; GPUr2 retry31captures, exit0 và stderr sạch. Đã sửa viewport thoại, shop-key kiếm khởi đầu và chọn màn hợp lệ. [Báo cáo/bằng chứng](TARGETED_REPAIR_20261002.md). Handoff tạm dừng và các số gate phía dưới là lịch sử; mở rộng thế giới ngoài hầm ngục/cốt truyện20h vẫn là thiết kế chờ review, chưa triển khai rộng.

Godot 4.7.2/GDScript, Compatibility. Báo cáo đang chốt bằng chứng; không coi kết quả focused là full strict gate. Tài liệu này thay mô tả Main Sanctuary/loot bảo đảm trong các báo cáo lịch sử.

## Nội dung và luồng chơi

- Main `res://scenes/maps/prologue_hub.tscn`: căn cứ an toàn có sân luyện, mộc nhân đo damage, Slime cắn nhẹ bật/tắt, nhà riêng/giường nghỉ, rương bộ thử bảy ô, kho, Kael, Thiết Lão, Thanh Vy, Vô Danh và cổng WorldCampaign.
- Sân/nhà/đền/lửa/items dùng art đã duyệt, alpha thật và mipmaps. Lửa có bốn frame, flicker ánh sáng, ember và PCM crackle thuộc room. Dọn fire owner trước rebuild/đổi khu/đổi phòng, không khởi động lại loop cũ trong lúc teardown.
- Bảy ô đồ giữ bộ khởi đầu 115 HP, 11 giáp, +2 sát thương. `Tab` mở Hành Trang, click thay/tháo; giáp dùng `100/(100+armor)`, thay đồ không tự hồi máu. Các collider và hai FSM Player đã ổn định giữ vị trí cũ.
- `E` ở NPC mở thoại chữ chạy/portrait và dịch vụ bằng chuột; Space/E hiện hết/qua đoạn, Tab/Esc đóng. Modal sở hữu input/thời gian, không đánh/nhảy hoặc mở thêm túi phía sau.
- Kael mua Thường/Hiếm và bán tinh thạch/Tinh chất Slime; Thiết Lão sửa đồ, ghép đá, cường hóa, đúc công thức đã học. Thanh Vy bán/chế thuốc và mua nâng cấp vĩnh viễn bằng Tàn Hồn. Vô Danh giao nhiệm vụ hạ Golem, thưởng kiếm biến thể có đòn đâm/lunge thứ tư.
- WorldCampaign giữ bốn chặng: Tiền Sảnh có2 Thi Binh/1 Minh Điêu/1 Slime; phòng khám phá có rương ẩn; phòng hai đợt quái trộn Kiếm Linh/Hộ Pháp; cuối Golem 500 HP. Legacy Alpha/LinearCampaign dùng fixture riêng để kiểm hồi quy.

## Vũ khí, quái và chiến lợi phẩm

Mười họ có moveset dữ liệu riêng và pose đọc clock thật: Kiếm cong quét3; Đại kiếm nặng3; Song đao nhanh4; Thương đâm3; Kích quét/đâm3; Rìu bổ2; Chùy dồn Stagger3; Roi xích dài/pull3; Quạt phóng3 lưỡi chia ledger; Trượng phù phóng sóng2. Base damage prototype13–26 so với kiếm khởi đầu10. Mỗi họ có sáu `GearVariantData`; tổng60 biến thể,40 công thức rèn Cực hiếm trở lên. Quality/+level/dòng phụ ở `GearItem` runtime, không sửa definition cache.

Động tác tay/torso dùng manual pose theo Weapon wind-up/active/recovery; không có method track/tween phát damage. Tầm/góc/window/hitbox/đạn và màu bùa được snapshot khi commit. Mười model đã duyệt dùng chung giữa các bậc trong đợt này; art riêng60 model và sprite sheet frame-by-frame chưa được làm.

Bốn `BaseEnemy` kế thừa độc lập khỏi Slime legacy: Thi Binh quét đao có Poise trong active; Minh Điêu bay/bổ nhào hoặc phun độc; Kiếm Linh fade có báo hướng rồi lướt đâm; Hộ Pháp1.5x có shieldHP chặn damage máu và vùng làm chậm có warning. Chúng nhận Hurtbox/DamageEvent/DoT/stun/pull, flash và số damage, chết hữu hạn. Hazard cap16, slow field4, trail10 điểm; visual không ghi physics.

Pool loot chia theo archetype. Quái có khả năng rơi rỗng hoàn toàn; survival ingredients dùng chế thuốc/băng/giải độc. Secret chest có3–5 món (rương lớn thêm1), lượng vật liệu3–5 hoặc đồ hỏng Hiếm theo prototype. Đồ hỏng phải sửa; bonus3–8% và tối đa một affix nhỏ giữ nguyên khi nhận/sửa. Không cho Cực hiếm+ dùng ngay qua drop.

Bản vẽ dùng một gate0,5% tổng/elite hoặcBoss, sau đó chọn họ chưa học; quái thường không rơi. Đá cường hóa cấp1–6 ép5:1; +0→+12 thành công100%, +3% sát thương gốc/cấp, không đổi phẩm cấp hay tăng độ bùng nổ của kiếm Thường chỉ vì +level.

**Bản Nguyên Thần Thạch hiện không có nguồn rơi/mua. Chỉ Boss đặc biệt tương lai được quyền rơi.** Huyền thoại và Thần thánh vẫn cần đá; bản hiện tại chỉ rèn tự nhiên tới Sử thi. Thần thánh50% và mất vật liệu khi thất bại đã có logic giao dịch, kiểm bằng fixture riêng, không cấp đá cho game chính.

## Save, ownership và ngân sách

Đồng trong run giữ trong escrow, chỉ bank khi chiến thắng. Kho an toàn/Tàn Hồn đã nhận/công thức/quest/nâng cấp vĩnh viễn giữ sau chết; vật liệu/đồ đang mang trong run mất. Safe equipment UID ledger serialize; bắt đầu run chuyển ownership và xóa safe snapshot bằng save thành công trước chuyển scene. Save lỗi rollback mọi chi phí và gear; victory trả phần đồ còn lại một lần. Không gắn reference scene đã free vào profile.

Ngân sách hiện có giữ: spatial voice16, projectile light12, impact24/flash light8, root cast/child budget64. Fire ambience và combat voice theo owner, mixer drain khi quit. Wizard tắt manual; PNG/SpriteFrames không cần Aseprite CLI.

## Bằng chứng kiểm tra

Chưa có full strict gate cho snapshot cuối. Focused weapon suite đã238/238 ở60 và120physicsHz. Bằng chứng cuối sẽ ghi tại đây sau khi mọi module đóng source.

Phân biệt: headless kiểm logic/tick/lifetime; GPU benchmark đo render hữu hạn trên máy hiện tại. Preview tự động dùng save riêng, supplies fixture và heldHP, không thay save người chơi. Kết quả benchmark không bảo đảm mọi frame/mọi máy hoặc run15–20 phút.

## File chính

- `scripts/resources/weapon_variant_catalog.gd`, `gear_variant_data.gd`, `forge_recipe.gd`, `drop_table_resource.gd`, `material_catalog.gd`.
- `scripts/hub/prologue_hub.gd`, `npc_actor.gd`, `npc_catalog.gd`, `game_flow.gd`, `permanent_progression_component.gd`; `scripts/ui/dialogue_box.gd`.
- `scripts/runtime/economy_session.gd`; codec/safe persistence và `GearItem` runtime.
- `scripts/actors/enemies/base_enemy.gd`, motor/state/hazard/visual; `scripts/rooms/world_campaign.gd`.
- `data/gear_variants/`60, `data/forge/`40,10 Weapon/Equipment pairs,4 enemy definitions/scenes, `data/loot/world_drop_table.tres`.
- `verification/prologue_art_provenance.json`, `world_art_provenance.json`; nguồn/prompt/duyệt giữ nguyên tại `docs/art_approval/`.

## Giới hạn còn mở

Các giá, damage, tỷ lệ loot ngoài0,5% blueprint/50%Divine/100%enhance cần playtest; không là cân bằng phát hành. Chưa có Boss đặc biệt/rate Thần Thạch, art riêng từng bậc, đủ hàng trăm item, mỗi-frame enemy sheet, quan hệ NPC/cảnh giới hoàn chỉnh hoặc pacing15–20 phút. Native shutdown lịch sử0xC0000005/fault0x547F2C chưa có root cause; lượt gate sạch không được coi chứng minh đã sửa nguyên nhân native cũ.

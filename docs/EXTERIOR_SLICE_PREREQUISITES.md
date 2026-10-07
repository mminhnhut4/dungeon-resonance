# Ngoại cảnh: lát cắt kỹ thuật đề xuất để duyệt

2026-10-02. Đây là kế hoạch kỹ thuật, không phải canon mới hoặc nội dung đã triển khai. Chờ duyệt thiết kế thế giới/cốt truyện trước khi dựng địa lý rộng.

## Phạm vi nhỏ có thể hoàn tác

Một tuyến graybox ba phòng: sân căn cứ hiện có → ngoại cảnh thử nghiệm → cửa hầm ngục. Một nhánh khám phá mở shortcut quay về sân; một tương tác NPC đọc cờ khám phá. Dùng Player, moveset, inventory, camera, HUD và art hiện có; không thêm Boss/đá Thần Thạch/phần thưởng cao cấp hoặc thay cốt truyện. Tiêu chí là hành trình đi-về có trạng thái chính xác, chưa là campaign20giờ.

## Hệ thống hiện có cần mở rộng

| Hệ thống | Hiện tại | Phần mở rộng cần duyệt |
|---|---|---|
| GameFlow / PrologueHub | Đổi Hub–run; sân–nhà giữ cùng Player và GearInventory | Travel policy tách safe travel, chuyển vùng trong expedition và kết thúc expedition. Chỉ chuyển ownership khi qua ranh giới risk/session, không bank Đồng hoặc clone gear mỗi lần đổi vùng |
| DungeonRun / LinearCampaign / WorldCampaign | enter_room/enter_stage tuyến tính; dọn entity theo phòng | Route graph theo ID vùng ổn định; các scene ngoại cảnh dùng cùng session và chỉ đổi room-owned content. Không biến bốn chặng prototype thành toàn bộ world graph |
| SanctuaryProfile / SafeInventoryPersistence | Profile schema1, safe UID ledger, quest/proofs/upgrades và rollback | Trạng thái world được validate: vùng đã khám phá, shortcut đã mở, quest/claim/checkpoint ID. Cần migration và backup recovery; không lưu Node/Resource runtime vào profile |
| GearSession / EconomySession | UID ledger, run escrow, bank victory một lần, rollback save | Giữ một ledger qua travel; reward khám phá claim đúng một lần. Không coi chuyển vùng là thắng run hoặc cấp lại starter gear |
| PlayerCamera / Terrain | Camera bounds và movement physics hiện có | Bounds/entry marker từng vùng và spawn vị trí hợp lệ. Cửa vào/ra không thay motor/FSM, không teleport vào collider |
| SlicePresentation / AudioManager / TimeScaleClaims | Entity/light/voice theo owner, modal/hitstop claims hữu hạn | Dọn room/audio/UI owner khi travel, giữ effect/cooldown snapshot theo chính sách. Không để modal của vùng cũ khóa input/thời gian ở vùng mới |
| NPC / DialogueBox | Dịch vụ VN và một bounty Golem | NPC đọc quest/discovery ID đã commit, không giữ scene reference; lời thoại/backstory mới phải từ thiết kế được duyệt |

## Quyết định còn cần thiết kế

- Ngoại cảnh nào là an toàn, ngoại cảnh nào thuộc expedition; chết ngoài trời có cùng luật mất đồrun hay không.
- Checkpoint/fast travel được mở thế nào; quay về căn cứ có kết thúc/bank expedition hay vẫn giữ một session đang đi.
- Những gate đi lại nào là năng lực vĩnh viễn. Không khóa main route vào bùa/gear tạm có thể mất khi chết; cơ chế wall-jump/grapple hiện chưa được triển khai.
- Khi quay lại vùng: enemy/loot nào respawn, thứ gì giữ vĩnh viễn, seed nào giữ cho cùng expedition. Không kéo dài20giờ chỉ bằng grind hoặc lượt đi lại bắt buộc.

## Kiểm tra cần có khi triển khai được duyệt

- Đi A→B→A lặp: cùng UID, HP/energy/cooldown; không tạo bản gear an toàn thứ hai, không bank/claim hai lần.
- Đổi vùng giữa cast/hurt/modal và teardown: không callback của room cũ, không kẹt TimeScaleClaims, không giữ enemy/hazard/audio owner.
- Shortcut/discovery/quest claim reload đúng; save fail rollback progress và reward; schema cũ nạp được, backup không phục hồi wardrobe đã tiêu hao.
- Death/victory tại ngoại cảnh áp đúng travel policy đã chốt; có entry/respawn marker trên terrain hợp lệ.
- Các gate/nút đi lại sử dụng input thật, camera giới hạn đúng; Player Movement55/Combat100 ở60/120Hz và Resolver20 giữ nguyên.
- Full strict runner import/editor/addon/gameplay giữ nguyên; GPU preview đi-về và benchmark tải đại diện sau khi source ổn định.

Nguồn: docs/PROJECT_ARCHITECTURE.md, docs/DECISIONS.md, docs/PROLOGUE_HUB.md, scripts/hub/game_flow.gd, scripts/runtime/sanctuary_profile.gd, scripts/hub/safe_inventory_persistence.gd, scripts/runtime/economy_session.gd, scripts/rooms/world_campaign.gd.

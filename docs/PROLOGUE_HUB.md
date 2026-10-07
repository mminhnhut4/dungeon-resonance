# Hub mở đầu và nhà lữ khách

2026-10-01. Nền tảng trước gói này đạt gate strict 3.896 checks. Gói Hub dùng Godot 4.7.2/GDScript và giữ Player/motor/hitbox/FSM hiện hành. Sân, nhà riêng, nền đền, Kael alpha, icon vật phẩm và lửa trại đã được tích hợp qua các adapter trình diễn. Kết quả kiểm tra ghi dưới đây là focused của module Hub; gate strict toàn dự án và kết quả GPU được chốt riêng ở mốc tích hợp cuối.

## Luồng scene

`scenes/maps/prologue_hub.tscn` là wrapper GameFlow chọn `scenes/hub/prologue_hub_room.tscn`. `GameFlow.hub_scene` là tùy chọn; `scenes/game_flow.tscn` không đặt tùy chọn này nên vẫn vào SanctuaryHub cũ và giữ API `show_hub/start_run/start_campaign` cho các suite lịch sử.

PrologueHub có sân rộng 2.400 px, Player thật, GearSession, SpellExecutor, CombatFeedback, SlicePresentation, DamageNumberSpawner và EconomySession. Nhà là `scenes/hub/player_home.tscn` ở x=3.200, được mở/ẩn như một khu indoor riêng. Ra vào nhà giữ **cùng Player và GearInventory**, chỉ relocate/camera bounds và dọn đạn đang bay; không tạo một bản nhân vật khác.

Sân có các Marker: `training`, `test_chest`, `house`, `stash`, `merchant`, `blacksmith`, `portal`. E chỉ tương tác trong 85 px, không dùng khi Inventory mở hoặc đang khóa Hurt. Cổng phải bắt đầu Campaign tầng 1. Giường trong nhà dùng E để nghỉ, hồi HP/năng lượng và xóa condition.

Mỹ thuật do adapter riêng đọc các Marker/world và các signal `interaction_requested(station_id, hub)` / `zone_changed(home|yard)`. Adapter không sở hữu collider, vật phẩm hay chuyển trạng thái chiến đấu. Các hình khối nền được ẩn khi skin đã duyệt hoạt động; cây vật lý, dummy và chest thật vẫn giữ logic hiện hành.

## Mỹ thuật đã tích hợp và ngôn ngữ

`PrologueHubArt` gắn nền sân `assets/environment/backgrounds/prologue_courtyard_v1.png`, nền nhà `assets/environment/backgrounds/player_home_v1.png` và nhà/cổng/kho/đài rèn từ `assets/environment/props/prologue_props_atlas_v1.png`. Kael dùng sprite góc nghiêng có alpha `assets/sprites/npc/kael_side_v2.png`. Nhà có ánh sáng ấm; sân có ánh sáng cổng ngọc. Các nhãn tương tác chỉ hiện khi ở gần. Điểm E của giường được căn theo đồ nội thất trong ảnh, không đổi terrain/collider.

DungeonBackdrop dùng `assets/environment/backgrounds/dungeon_temple_v1.png` phía sau Tiền Sảnh và đấu trường Golem; Boss có tint tối hơn. Nền vẽ chỉ thuộc trình diễn, không thay cửa khóa hay va chạm phòng.

Mười hai icon AtlasTexture từ `assets/ui/items/prologue_items_atlas_v1.png` nằm ở `assets/ui/items/regions/`: Tinh Thạch, Tinh Chất Slime, Kim Loại, Bột Phép, Thuốc, Băng Gạc, Thuốc Giải Độc và năm icon đồ hỏng (kiếm, dao, trượng, áo, găng). ItemArtCatalog và LootVisualSkin dùng cùng icon cho vật phẩm trên đất và giao diện; tên hiển thị lấy từ danh mục tiếng Việt, không suy gameplay từ hình ảnh.

Lửa trại sân dùng AnimatedSprite2D với bốn khung `assets/environment/props/campfire/campfire_frames_v1.tres`, PointLight2D cam rung sáng nhẹ theo clock và tám hạt tàn lửa hữu hạn; không phát hạt GPU trong headless. CampfireVisualSkin chỉ phát âm thanh không gian khi Player ở gần và lửa đang hiện. AudioManager cung cấp đoạn lửa tổng hợp offline dài 2,4 s, được adapter gia hạn theo lifetime và dọn theo owner khi ẩn/rời scene. Không tạo voice mỗi frame; ngân sách âm thanh chung vẫn được giữ.

Định hướng người dùng đã xác nhận là game dành cho người Việt: giao diện và tên vật phẩm dùng tiếng Việt; tránh chữ Hán/Trung có thể đọc trên tranh, bùa hoặc kiến trúc. Chi tiết trang trí dùng hình ảnh, ký hiệu hư cấu hoặc nét khắc mờ. Quét văn bản nguồn `scripts/`, `data/`, `scenes/` (GD/TRES/TSCN) tại lần rà này không có ký tự Han; kiểm tra này không chứng minh nội dung chữ đã được vẽ vào mọi PNG.

## NPC và hội thoại — phần mở rộng đang kiểm tra

PrologueHub có cờ `world_building_enabled` mặc định tắt cho fixture legacy. Khi bật, Thiết Lão ở gần đài rèn, Thanh Vy ở gần lửa trại và Vô Danh ở gần cổng. Ba vùng Atlas đã được người dùng duyệt nằm ở `assets/sprites/npc/regions/{thiet_lao,thanh_vy,vo_danh}.tres`. HubNpc dùng alpha bounds để đặt chiều cao thân 60 px và pivot chân, thở nhẹ 1,4% trên Sprite2D; không thêm collider/hào quang. Nếu art chưa có, chỉ dùng bóng người vector ghi rõ phác thảo.

DialogueBox có tên NPC/lời thoại tiếng Việt đúng mẫu đã duyệt, hiện chữ dần theo wall clock, Space/E hiện hết rồi qua trang; chuột chọn dịch vụ hoặc đóng. Panel co theo viewport, phần nội dung cuộn và nút đóng nằm ngoài vùng cuộn. Trong thoại, Player bị suspend controls và UI giữ một TimeScaleClaims 10%; Hub router xử lý phím trước Inventory/Player nên không nhảy, chém hoặc niệm phép sau modal. Khi đóng hoặc chuyển scene, claim được trả lại.

Các hook `smith_requested(hub)`, `permanent_upgrade_requested(id, hub)` và `bounty_requested(id, hub)` dùng để phối hợp dịch vụ; mọi giao dịch đi qua EconomySession, không tự trừ tiền/Tàn Hồn trong UI. Thiết Lão nối menu sửa đồ hiện có; Thanh Vy báo giá Max HP/hồi năng lượng/ô Catalyst; Vô Danh giao nhiệm vụ Golem với một biến thể combo được tác giả định nghĩa. Trạng thái này đang được tích hợp API và kiểm focused riêng, chưa được tính vào 68 checks đã ghi bên dưới.

## An toàn và cảm giác chiến đấu

`HealthComponent.minimum_health` là trạng thái runtime mặc định **0**. SafeHubComponent đặt **1** cho Player Hub và trả giá trị cũ khi teardown. Clamp nằm tại Health nên bao phủ DamageResolver, DOT thật và penalty nội bộ của Berserk; feedback/hitbox vẫn hoạt động và không có died signal tại căn cứ. Player mới trong Dungeon giữ minimum_health=0, nhận sát thương và chết bình thường.

Slime luyện tập dùng FSM/collider cũ, mặc định hiền. E ở sân luyện bật/tắt chase/bite; cú cắn prototype 5 sát thương trước giáp, telegraph 0,45 s. Tắt đóng bite hitbox/contact ngay. Slime chết tự hồi sau 1,2 s và không thưởng vật liệu tại sân. Mộc nhân giữ refill/knockback/hit-stop và phát số qua shared DamageNumberSpawner.

## Chuẩn bị trang bị

Player khởi đầu đủ bảy ô: Vũ khí/Áo/Quần/Giày/Găng/Nhẫn/Dây chuyền, 115 HP/11 giáp/+2 ATK. Tab dùng InventoryScreen thật, click đổi UID, thời gian 10% và giữ Bùa.

Rương thử cung cấp một bộ bảy món Thường, kiếm Lôi Hiếm và Hỏa/Phong/Lôi. Chỉ nhận **một lần mỗi phiên GameFlow**; không cấp đồ Cực hiếm trở lên. Kiếm Lôi dùng `EquipmentData.intrinsic_runes` mặc định rỗng trên definition khác; GearSession thêm nguyên tố này vào Weapon runtime bên cạnh bùa khảm. Shared definition không bị sửa khi trang bị.

Rương không được nhận lại sau khi chết trong cùng phiên. Đồ thử đã mang vào run cũng mất khi chết; Hub tạo bộ khởi đầu mới đủ bảy ô để tiếp tục chơi. Khởi động một phiên GameFlow mới sẽ có rương thử mới.

## Quyền sở hữu qua run

- Bắt đầu run: HubPreparation sao chép GearItem runtime/UID/quality/rolled fields, destination slot, rune, consumable và vật liệu; chỉ chia sẻ Resource định nghĩa đọc. Sau đó xóa toàn bộ ledger đang mang khỏi Hub, chuyển quyền sở hữu sang run **một lần**. Không có bản đồ gốc giữ lại để rã/tiêu thụ lặp.
- Profile stash/Đồng/Tàn Hồn không nằm trong bản sao run. Vật liệu đã gửi kho ở căn cứ được giữ độc lập.
- Chết/abandon: không trả đồ run; Hub nguồn rỗng tạo starter kit mới. Flag rương thử vẫn đã nhận.
- Thắng: trả toàn bộ ledger còn lại, gồm UID đồ nhặt mới, bùa, consumable còn lại và vật liệu; sao chép rolled state và xóa nguồn run một lần. Điều hướng Hub lặp không trả thưởng lần nữa.
- Nếu ledger trả về vượt 20 ô, hệ thống grid có sẵn giữ UID trong các trang tiếp theo; không âm thầm bỏ vật phẩm. Cap 20 vẫn áp khi nhặt thêm hoặc nhận bộ thử. Suite kiểm trang thứ hai thật.

Không thêm luật khóa rã các UID chuẩn bị; việc chuyển quyền sở hữu xử lý nguyên nhân nhân đôi. Sáu trường loot `source/drop_bonus/affix_id/affix_value/broken/loot_rolled` đi qua clone mà không reroll.

## Kho, Kael và sửa đồ

E ở kho mở danh sách MaterialCatalog hiện hành; gửi tất cả hoặc rút từng đơn vị qua EconomySession. E ở Kael hiển thị báo giá từ vật liệu trong kho: Tinh Thạch 5 Đồng, Tinh Chất Slime 3 Đồng (prototype). Giao dịch save-backed có rollback do EconomySession quản lý; Hub không tự cộng tiền.

E ở thợ rèn liệt kê đồ hỏng và chi phí sửa từ kho. Thường dùng 2 Kim Loại +1 Bột Phép; Hiếm 4+2. UID/roll được giữ. Phôi loot Cực hiếm trở lên hiện báo cần công thức/rèn, không sửa để vượt luật trang bị. Run từ Prologue bật các drop mới; luồng legacy giữ cờ mặc định trung tính.

Panel tương tác căn giữa theo viewport, chiều rộng tối đa 640 px, chiều cao tối đa 600 px và co theo cửa sổ. Nội dung dài nằm trong ScrollContainer; nút đóng cao 44 px ở ngoài vùng cuộn. Label tiếng Việt word-wrap, nút dài dùng ellipsis. PrologueInputRouter nhận E/Tab trước InventoryModal; một station đang mở không tạo modal thứ hai và nút mở hành trang được ẩn tạm.

## Bằng chứng focused

`tests/prologue_hub_test.gd` đạt **68/68** ở 60/120 Hz: input J/I/E/Tab thật, safe floor direct/DOT/Berserk, click Rare và intrinsic Lôi, cùng Player khi ra/vào nhà, bed rest, kho/Kael/smith GUI, move ownership, chết/thắng, full pickup→win→Hub→repair, overflow trang2 và panel resize thật 720×480 với 20 dòng dài. Stress sáu chu kỳ Hub/campaign: objects **2.847→2.847**, resources **359→359** sau warm-up.

Raw logs: `verification/prologue_hub_60_r6.log`, `verification/prologue_hub_120_r6.log`; exit0, không ERROR/WARNING/SCRIPT ERROR. `tests/starter_flow_test.gd` legacy vẫn **15/15** cả hai Hz sau thay đổi GameFlow: logs `verification/prologue_legacy_starter_flow_{60,120}_r3.log`, objects 2.303→2.303/resources372→372.

Headless xác minh logic/lifecycle, không chứng minh độ đẹp/FPS render. Gate toàn bộ sau tích hợp art/loot/economy chưa được report module này tuyên bố: lượt strict R1 hiện giữ failure “Room rebuild drains its spatial audio owner” ở suite Polish40 và đang được sửa/kiểm lại; không coi R1 là snapshot hoàn chỉnh đã đạt. Kết quả GPU được lưu/báo cáo riêng bởi mốc tích hợp. Native shutdown lịch sử `0xC0000005 / fault 0x547F2C` chưa được quy nguyên nhân; focused sạch không chứng minh đã sửa.

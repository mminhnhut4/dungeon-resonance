# Làm nhân vật, quái và boss

## Chọn owner phù hợp

| Đối tượng | Điểm bắt đầu hiện hữu |
|---|---|
| Player gameplay | scenes/actors/player/player.tscn; scripts/actors/player/player.gd, motor/hai FSM |
| Player visual/gear | scenes/actors/player_visual_rig.tscn; data/characters/starter_swordsman.tres; equipment/visual rig |
| Bốn quái world | scenes/enemies/base_enemy.tscn; scripts/actors/enemies/base_enemy.gd; scripts/resources/world_enemy_data.gd; data/enemies/*.tres |
| Golem | scenes/enemies/boss_golem.tscn; scripts/actors/enemies/boss_golem.gd; scripts/presentation/boss_golem_skin.gd, golem_art_rig.gd |
| NPC dịch vụ | scripts/hub/npc_actor.gd, npc_catalog.gd; DialogueBox/EconomySession |
| Resident ngoài trời | scripts/npc/npc_world_state.gd và population/pilot/social; sidecar khác profile/gear ledger |

## Player: thêm ngoại hình hoặc kit theo gear

1. Clone checkout, giữ scene Player/motor/controller/hai FSM và physical socket/Hurtbox. Mở skin resource và visual rig để xem instance đang live; scene rig độc lập có thể chưa mang sprite giống instance Player.
2. Full PNG có pivot chân/mask alpha khi render; giữ nguồn PNG. Facing theo con trỏ dù chạy ngược; hướng damage do Aim/Weapon commit. Idle thở 1→1.03→1 trong1.2s từ pivot chân. Atlas/cutout gắn bone visual, không kéo body collider theo áo.
3. Bộ đồ đi qua EquipmentData → GearItem → GearInventory → GearSession → EquipmentStats/EquipmentVisual. Class kiếm/thuật sĩ và moveset dựa gear. Khi được giao bộ mới, author definition/variant/part/catalog theo hợp đồng; không sao chép Player thành class controller khác.
4. Damage/hit-window thuộc Weapon/Hitbox/Spell; rig manual seek đọc clock Windup/Active/Recovery. WeaponSlot trong xương chỉ trang trí; WeaponSocket vật lý ở cây gameplay. Không method track phát damage/mở hitbox.
5. Kiểm đi/chạy/nhảy/dash, aim360, đổi gear trong attack/cast, Hurt/Dead/cancel, camera/alpha/pivot/ownership. Dùng tests/modular_rig_test.gd, modular_equipment_test.gd, world_weapons_test.gd theo scope; giữ Movement55/Combat100/Resolver20.

## Bài thực hành quái: Cổ Thi Binh

Mở scenes/enemies/ancient_guard.tscn: kế thừa base_enemy.tscn, override definition=data/enemies/ancient_guard.tres. WorldEnemyData giữ HP/timing/moveset/flying/body_size; actor có motor/state/hazard/visual riêng. HP/clocks/target lock runtime không ghi vào .tres.

Trace attack từ BaseEnemy qua WorldEnemyState/Motor/Hazard và scripts/presentation/world_enemy_visual.gd. Polish atlas/SpriteFrames đọc state clock; tell/active/recovery trùng hazard/hitbox thật. Hình lưỡi đao không tự gây hit. Quái đã nằm WorldCampaign.MONSTERS và roster _spawn_wave; asset chưa bind không xuất hiện trong run.

Khi về sau được duyệt archetype mới, dùng scene/data/subclass theo BaseEnemy; nối spawn/death/loot/condition qua WorldCampaign. Gán player/feedback theo contract, giữ room ID guard cho deferred loot; không bypass UID/reward/gated drop. Task hiện tại ưu tiên quái đã có.

## Golem: animation theo chiến đấu thật

Rig Oct7 dùng MeshInstance2D/ArrayMesh UV tĩnh trên PNG hiện có, đọc BossGolem: idle/walk, sweep tell/active/recovery, orb cast, stomp air/recovery, hurt/stagger/death. Giữ pivot chân, phase/hurt shader và collider. Nhánh Polygon2D UV động từng crash lúc quit đã bị loại; không chép lại patch đó.

Với mỗi pose, ghi mapping state + phase + clock → animation/VFX/hitbox thực. Walk chỉ được chứng minh khi AI đang di chuyển với velocity thật; nhãn ảnh walk chưa đủ. Kiểm phase2 một lần, ngắt attack bởi Hurt/Dead, recovery không đánh lén, cleanup khi room free. Attack mới/balance là task riêng được duyệt.

## NPC và mỹ thuật

NPC bán đồ gọi dịch vụ gốc, dialog modal và Economy transaction; resident life/schedule/social thuộc owner NPC sidecar. Không serialize Node/reference actor vào profile, không đưa NPC ID vào gear ledger. Resident vector fallback chưa thành bộ art thương mại; portrait/idle không chứng minh walk/hurt/death đã làm.

Art cần nguồn/license, kích thước/pivot/atlas region và path binding runtime. PNG/SpriteFrames không cần Aseprite CLI; Wizard tắt thủ công. Hit shader/áo/pháp giữ silhouette/tell, light/voice hữu hạn. Art-only giữ hash collider/resource/transforms.

PR cần ảnh idle/move/tell/active/recovery/hurt/death theo scope, gameplay native từ main, teardown exit0/noERROR-WARNING và tests/world_enemy_test.gd/boss/presentation liên quan. Assertions đúng nhưng crash khi thoát vẫn là FAIL.

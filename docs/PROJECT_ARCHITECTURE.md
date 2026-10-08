# Kiến trúc — Dungeon Resonance

**Bổ sung 08/10/2026, connector + sect slice:** `WorldCampaign` dùng `DepthCampaign` cho nhánh nối Golem→Depth, giữ actor/session, localDepth1..5 và hiển thị4..8. `SectRouteCatalog` bổ sung bốn roomID; `ExteriorRouteCatalog.ROOMS` giữ tám phần tử cũ, `all_rooms()` dùng cho discovery/map. `SectJourney` gắn vào ExteriorHub, DialogueBox giữ focus/time; `SectJourneyProgress` dùng extension transaction owner `sect_journey_v1` với tám event hữu hạn, không cấp currency. `NpcWorldState` schema4 thêm hai chấp sự, backup `.pre_sect_v3.json` trước ghi; quy tắc schema1/2 cũ giữ nguyên. `SectRoomArt` room-owned, một texture nền đang dùng, không author hitbox. [Nguồn/QA/giới hạn](SECT_MAPS_RESUME_20261008.md). Không thêm witness/hire/leadership owner trong lát cắt này.

Prototype ngoài trời2026-10-02: main `scenes/maps/prologue_hub.tscn` vẫn là `GameFlow`, chọn scene `ExteriorHub : PrologueHub`. `ExteriorRouteCatalog` khai báo tám roomID, hai region, graph cửa và profile cao độ; `ExteriorRoom` dựng collider solid/art/anchor/cổng theo từng phòng. Mỗi lần tải một phòng ở origin(8000,0); giữ actor cùng GearSession/inventory/EconomySession của Hub. `ExteriorHub` kiểm modal/Hurt/grounded cho E, prebuild target và lưu geography trước commit, rollback lỗi save/load, dọn room-owned presentation, dùng `PlayerTravel.relocate` hiện có và cập nhật camera bounds. H00 road tách cửa dungeon; SC01 đi qua corridor P02 bằng hai cửa hầm bình thường. DungeonRun/WorldCampaign và controller/motor/haiFSM không sửa.

`ExteriorProgress` xác thực geographyv1: room/region/route/anchor, danh sách bounded discoveries/notes và SC01. `SanctuaryProfile` globalv1 thêm extension tùy chọn; legacy absent giữ mặc định, malformed geography quarantine độc lập khỏi UID ledger, future extension không bị build cũ ghi đè. Không lưu HP/energy/cooldown trong geography; restore cùng phiên giữ actor, cold start theo GameFlow hiện có. Hạnh/record dùng DialogueBox hiện hành, lựa chọn xác nhận mới lưu note, cancellation không ghi. Chưa có NPC AI/permadeath/companion hoặc enemy ngoài trời. [Phạm vi, sơ đồ và kiểm chứng](EXTERIOR_FIRST_SLICE_20261002.md).

World-Building mới: Main `scenes/maps/prologue_hub.tscn` là `GameFlow` wrapper mở `PrologueHub` an toàn và đi `WorldCampaign`. `world_building_enabled` opt-in giữ legacy Alpha/Linear/Hub fixture. Profile sở hữu permanent progress và safe UID ledger; Hub/run chuyển ownership, không clone một món thành hai phần thưởng. `EconomySession` là giao dịch rèn/shop/ghép đá/+level và rollback save lỗi. `DropTableResource` quản lý pool archetype, một gate blueprint0,5% và drop rỗng; không có nguồn Bản Nguyên Thần Thạch hiện tại. [Báo cáo](WORLD_BUILDING_REPORT.md).

`WeaponVariantCatalog → GearVariantData(60) → EquipmentData/WeaponDefinition(10) → GearItem` tách grade definition khỏi quality/+level/affix runtime. `WeaponMotionPose`/EquipmentVisual/Rig đọc authoritative clock; chỉ Weapon/Hitbox/SpellExecutor gây damage. `BaseEnemy` mới có WorldEnemyData/Motor/State/Hazard/Visual; legacy Slime/Player controller không đổi. `DialogueBox`/HubNpc/NpcCatalog sở hữu thoại VN và modal, dịch vụ giao cho EconomySession; `PermanentProgressionComponent` áp bonus profile vào actor/session.

High Fidelity: `Weapon.visual_quality` và bùa vũ khí được chụp vào `AttackSnapshot.cosmetic_*` rồi sao chép sang `DamageEvent`; `WeaponTrail`/`ImpactBurst` đọc snapshot, giữ màu và phẩm cấp của đòn đang bay khi đổi đồ. `HitReactionComponent` điều phối trạng thái Hurt tùy chọn, `BuildPlayerMotor` sở hữu impulse/collision; rig chỉ đọc pose clock. `MovementVFX` chứa tối đa5 afterimage/8 dấu trong room; `ElementAfflictionVFX` thuộc actor và chỉ đọc status burn/poison để điều khiển shader/hạt. [Chi tiết và bằng chứng](HIGH_FIDELITY_VISUALS.md).

Hành Trang: `GearInventory.items` là ledger UID duy nhất; equipment_uids[7]/equipment_positions chỉ lưu vị trí. `InventoryScreen : GearInventoryModal` thêm bảy ô trang bị và giữ Bùa/TimeScaleClaims. `EquipmentData` immutable→`GearItem` UID/quality→`GearSession` moveset/quality→`EquipmentStats` runtime và `EquipmentVisual` cosmetic. ModularCharacterSkin/Part→AtlasTexture→các lớp Sprite2D trên xương; EquipmentVisual chỉ nối lớp mặc và socket nhìn thấy. Bộ mặc định **115 HP/11 giáp/+2 ATK**; DamageResolver áp giáp một lần sau modifier. WeaponSocket/Hitbox/Hurtbox và hai FSM giữ nguyên. [Mốc hiện hành](CHARACTER_FOUNDATION.md); [lát cắt Hành Trang trước](INTERACTIVE_INVENTORY_SLICE.md).

Godot 4.7.2, GDScript, Compatibility. Main scenes/maps/prologue_hub.tscn; scenes/game_flow.tscn giữ Sanctuary legacy. Danh mục/hash đầy đủ ở verification/content_manifest.json. Root D:/hầm ngục tương ứng res://.

## Thư mục

~~~text
res://
├── project.godot
├── addons/phantom_camera, rmsmartshape, beehave, AsepriteWizard
├── assets/sprites/player/, npc/, enemies/ # Player modular/atlas, Slime/Golem PNG alpha
├── assets/environment/
│   ├── tilesets/regions/         # Sheet đá PNG và AtlasTexture crops
│   └── props/                   # Dummy/Chest PNG alpha và README
├── assets/ui/                   # Khung HUD Player/Boss alpha socket
│   └── icons/                   # Hỏa/Phong/kiếm/khiên PNG
├── assets/presentation/          # PNG bake, torch SpriteFrames, light/particle
├── assets/audio/                 # PCM preview, runtime synth không cần file ngoài
├── data/
│   ├── weapons/                 # 8 vũ khí + training fixture; AttackStep con
│   ├── runes/                   # 5 nguyên tố + 2 Resource khung legacy
│   ├── catalysts/               # Catalyst mở 3 ô cơ bản
│   ├── resonances/              # 18 recipe rõ ràng
│   ├── relics/                  # 4 RelicData
│   ├── equipment/               # kiếm + sáu món đồ khởi đầu, part overlays
│   └── characters/              # ModularCharacterSkin với pivot/bone attachments
├── scenes/
│   ├── game_flow.tscn
│   ├── hub/sanctuary_hub.tscn
│   ├── dungeon_run.tscn         # Alpha 3 phòng
│   ├── linear_campaign.tscn     # Kế thừa Alpha, 4 chặng
│   ├── test_level.tscn, training_dummy.tscn
│   ├── actors/player/player.tscn
│   ├── actors/player_visual_rig.tscn
│   ├── enemies/slime_enemy, mutant_slime, boss_golem.tscn
│   ├── weapons/weapon.tscn
│   ├── projectiles/spell_projectile.tscn
│   ├── effects/, ui/
│   └── main/, rooms/            # Scene khung ban đầu
├── scripts/
│   ├── actors/, state_machine/
│   ├── definitions/            # Chỉ dữ liệu dùng chung
│   ├── combat/, spells/         # Emit/resolve/presentation
│   ├── runtime/                 # Item ledger, loadout, relic, session, save
│   ├── conditions/, story/      # Wounds/stress/director
│   ├── loot/, environment/      # Pickup/chest/barrier/camp/trap
│   ├── rooms/, hub/, ui/
│   ├── utils/                   # ProceduralAnimator: clock/pose math, không sở hữu actor
│   └── presentation/, audio/     # Cosmetic rig/VFX/shadow/lighting và AudioManager
├── shaders/                     # Additive weapon trail và flash sprite enemy/prop
├── tests/                       # Gameplay/presentation/art ở 2 Hz, data/addon/validator
└── docs/verification/           # .gdignore; logs/ảnh/benchmark/addon nguồn
~~~

Danh mục đầy đủ ở verification/content_manifest.json. Cache .godot không phải dữ liệu gameplay. Thư mục addon dùng tên upstream; SmartShape2D chứa đường dẫn tuyệt đối rmsmartshape.

## Ranh giới module

| Thành phần | Trách nhiệm |
|---|---|
| Player, PlayerMotor, 2 FSM | Input, chuyển trạng thái, movement đã kiểm chứng; motor duy nhất ghi velocity/move_and_slide Player |
| BuildPlayerMotor | Kế thừa: short lunge, slow, số dash trên không; modifier trung tính giữ hành vi legacy |
| PlayerAim | World target và hướng 360°, độc lập hướng chạy |
| WeaponDefinition → WeaponData, AttackStepDefinition | Reach/sweep/timing/combo/crit/stagger/projectile, super armor/lunge/pull |
| Weapon, WeaponBuildComponent | Snapshot từng nhát, active hit window, đòn tầm xa; phản ứng impact qua signal |
| RuneData, CatalystData, ResonanceDefinition, RelicData | Custom Resource dùng chung, không lưu HP/timer/owned/equipped runtime |
| GearItem, GearInventory, GearSession | UID/quality/bag/slot/salvage/crafting, sync scalar modifier vào actor |
| CatalystRuntime, LoadoutRuntime, ResonanceController | Installed IDs, exact recipe, cooldown theo recipe ID; commit snapshot |
| RelicRuntime | Owned/equipped tối đa 3, modifier từ data, kill/dodge signals; không sửa definition |
| SpellSnapshot, SpellContext, SpellExecutor | Payload sau commit, root/child ledger, spawn cap 64, chain tối đa 2, một proc chính |
| SpellProjectile, FirestormEffect, ElementField, PhantomEcho | Hành vi hữu hạn: sweep world, pull/explode, vùng DOT, bóng nổ |
| Hitbox → Hurtbox → DamageResolver → Health | Query/receive/filter/dedup/status modifier→armor100/(100+armor)→damage một lần; phản hồi từ DamageResult |
| EquipmentStats, ModularCharacterSkin/Part, EquipmentVisual | Tính gear stats từ nền; Resource part/pivot/atlas chỉ đọc; mount per-bone và grip cosmetic, không sửa physical socket |
| StatusController → ElementStatusController | Burn/stun legacy + slow/freeze/poison/armor break; DOT quay về DamageEvent |
| SlimeEnemy/MutantSlime, BossGolem | Enemy FSM; mutant kế thừa Slime và thêm projectile; boss hai phase/stagger |
| BodyConditionComponent, StorytellerDirector, SurvivalSession | Wound/stress/incident lifecycle; session nối tín hiệu/UI/camp/shrine |
| DungeonRun → LinearCampaign | Room/wave/lock/loot/boss/death; thêm khám phá và mutant bằng kế thừa |
| SanctuaryProfile, GameFlow, SanctuaryHub | Permanent Soul/unlock/archive/style; save JSON có recovery; Hub/run disposable |
| EnemySpriteArt, SlimeSpriteSkin, BossGolemSkin | Alpha geometry native cache, read-only sprite/flash/phase/death; không đổi enemy AI/collision |
| PropSpriteSkin | Dummy flash/wobble và chest opened/tint/jade light; DamageEvent/loot/interaction ở actor gốc |
| WeaponTrail, SpellProjectileVFX, ImpactBurst | Mesh crescent, finite wake/hạt/vòng sáng từ snapshot/contact/result; không gây damage |
| ArtHUD | CanvasLayer đọc HP/Energy/Boss/gear; TextureProgressBar qua socket alpha và native UI restore |
| ProceduralAnimator, ActorShadow | Pose toàn sprite và bóng chân; chỉ node visual, World ray query tối đa 30Hz, không ghi movement |
| CombatFeedback, HitstopManager, TimeScaleClaims | Local clock legacy hoặc real-time hitstop live; claim min theo owner, root dedup và teardown |
| PlayerCamera | Lookahead qua position; trauma² noise qua offset, decay realtime và cường độ rung chỉnh được |
| FootstepDust | Bốn GPU hạt mỗi puff, pool thuộc phòng tối đa 8, lifetime hữu hạn, không tạo collision/light |
| AudioManager | Hai API legacy/weighted, PCM offline, 16 voice chung, bus/limiter và room/quit cleanup |

## Player Scene

~~~text
Player (CharacterBody2D) [player.gd]
├── BodyCollision
├── Visuals [PlayerVisualRig]
│   ├── Skeleton2D/Root/...       # 14 legacy/18 live bones, per-bone body/wearable Atlas
│   ├── ConceptFootPivot/ConceptDynamics/ConceptSprite # fallback PNG; ẩn khi modular active
│   ├── EquipmentVisual/HandSocket/WeaponPivot/WeaponSprite # grip theo hand bone
│   ├── ActorShadow              # Ellipse24đỉnh; chiếu World tối đa30Hz
│   └── AnimationPlayer          # Manual seek từ clock vũ khí/cast
├── Camera2D [PlayerCamera]       # Zoom1.35, lookahead40px/position, trauma²/offset
├── Motor [BuildPlayerMotor : PlayerMotor]
├── LocomotionStateMachine
│   └── Idle, Run, Jump, Fall
├── ActionStateMachine
│   └── Ready, Attack, CastSpell, Dash, Hurt, Dead
├── Combat
│   ├── Aim [PlayerAim]
│   ├── WeaponSocket/Weapon/Hitbox/CollisionShape2D
│   └── DamageResolver
├── Health, Energy
├── StatusController [ElementStatusController : StatusController]
├── Hurtbox/CollisionShape2D
└── Spells/CatalystA, CatalystB, ResonanceController

Room composition (khởi tạo bằng code):
├── GearSession → inventory, LootSpawner, Tab modal
├── SurvivalSession → BodyCondition, Director, camp/shrine, C modal, HUD
├── ContentSession → RelicRuntime, WeaponBuildComponent, F6 panel
└── SlicePresentation
    ├── DungeonAtmosphere, FoyerArt, DungeonDebugOverlay
    ├── ArtHUD [CanvasLayer14] → HP/Energy, 3 bùa, vũ khí, Boss footer
    ├── FiniteImpactPool → GPU hit sparks/flash lights
    ├── FiniteFootstepPool → FootstepDust, tối đa8puff/4hạt mỗi puff
    ├── WeaponTrail → child cosmetic của Weapon
    ├── SlimeSpriteSkin/BossGolemSkin → child của enemy thuộc phòng
    ├── PropSpriteSkin → child Dummy/Chest thuộc phòng
    └── SpellProjectileVFX/light → child của thực thể phép
~~~

Jump/Fall và Attack/Cast độc lập. Mỗi đòn lấy hướng khi commit; dash/death đóng hitbox/hủy wind-up. Motor nhận yêu cầu impulse; component mới không gọi movement thứ hai. Rig có clip hurt/dead/land/dash/punch chỉ để trình diễn; interruption của vũ khí content qua component, không thay FSM legacy.

## Pipeline

~~~mermaid
flowchart LR
    Gear[UID + quality + slots] --> Weapon[WeaponData / AttackSnapshot]
    Gear --> Catalyst[CatalystRuntime]
    Catalyst --> Resolver[Exact multiset Resolver]
    Resolver --> Commit[Controller / SpellSnapshot]
    Aim[Mouse world aim] --> Weapon
    Aim --> Commit
    Relic[RelicRuntime] --> Commit
    Weapon --> Hitbox
    Commit --> Executor[SpellExecutor / finite Context]
    Executor --> Hitbox
    Hitbox --> Event[DamageEvent]
    Event --> Hurtbox
    Hurtbox --> Damage[DamageResolver]
    Damage --> HP[Health / DamageResult]
    Damage --> Status[ElementStatusController]
    Status --> DOT[DOT DamageEvent]
    DOT --> Hurtbox
    HP --> Loot[Death / Loot / room clear]
    HP --> Feedback[Hit-stop / shake / flash / text]
    Director[Incident Director] --> Event
    Director --> Conditions[Body conditions / stress]
~~~

Damage cache 256 request gần nhất; root/parent IDs chống proc đệ quy. Đạn/hiệu ứng giới hạn 64, loot 96, trap 8; mỗi entity có lifetime và owner scene. Recipe là **toàn bộ multiset**; ba/bốn/năm bùa không tự kích hoạt các cặp bên trong. Recipe rỗng chủ động bắn basic magic. Đổi loadout giữ cooldown đã commit và đạn đã phóng.

Quality là trạng thái GearItem, không sửa WeaponData/RuneData được cache chung. Catalyst normal có 3 ô, Weapon normal 1 ô; max quality có 5/3 ô. Item ledger tách instance khỏi definition và kiểm tra rã đồ không còn trang bị.

Health/gear giữ khi chuyển room trong run; incident, loot chưa nhặt, đạn và enemy thuộc phòng cũ được giải phóng. GameFlow chỉ giữ SanctuaryProfile khi chết/thắng; trang bị/vết thương/nguyên liệu mới cho run sau.

## Layer / clock / addon

Physics: World=1, PlayerBody=2, EnemyBody=3, PlayerHurtbox=4 (mask 8), EnemyHurtbox=5 (mask 16). Hitbox dùng shape query; projectile sweep World rồi chung DamageEvent.

Trong renderer live, SlicePresentation bật HitstopManager con của CombatFeedback: global scale 0,05 trong 0,06s thực khi melee gây damage; 0,12s cho critical/heavy hoặc melee trúng Boss. Timer bỏ qua pause/time scale, root dedup 64 và một timer hoạt động cho mỗi burst. Actor/weapon clocks đọc is_frozen, không cộng thêm local freeze sau release. Headless mặc định giữ local 0,05s để fixture cũ độc lập; suite CombatJuice chủ động bật global và kiểm deadline thực. hit_stop_seconds=0 tắt cả hai mode trong benchmark throughput.

Tab dùng TimeScaleClaims để sở hữu scale 0,1. Claim combat 0,05 và modal 0,1 hợp thành min, owner cuối trả baseline trước claim; reset/teardown không ghi 1 đè một modal đang mở. Claims lưu scalar IDs trong SceneTree metadata; GameFlow release_subtree trước detach run, manager ngắt callback timer khi exit. C và F6 vẫn khóa input không giảm time. Eclipse ở CanvasLayer 8 dưới HUD giữ khả năng đọc HP/Boss.

Phantom Camera, SmartShape2D và Beehave bật ở editor; Wizard giữ cài đặt nhưng tắt chờ thủ công. Không thay enemy FSM hoặc camera gameplay đã ổn định. Import, editor fixture thật, entrypoint compile và runtime lifecycle có gate strict riêng; addon shutdown cũ đã sạch. Xem [ADDONS.md](ADDONS.md).

Chạy tests/run_tests.ps1 mặc định để kiểm cả editor/addon/source/gameplay. Kết quả/giới hạn ở [PROJECT_STATE.md](PROJECT_STATE.md).

## Trình diễn và rig xương

PlayerCamera child dùng zoom 1.35 và lookahead vector 40px bằng position; add_shake dùng FastNoiseLite×trauma² qua offset, decay realtime và shake_intensity 0..1. CombatFeedback phát trauma 0,2 melee/0,4 phép, Boss stomp→recover 0,7; Camera2D legacy của fixture giữ shake cũ. SlicePresentation chọn camera này khi vào dungeon; Hub chọn camera cố định của menu. DungeonDebugOverlay theo room quản lý WeakRef các nhãn/thanh phụ, default off và toggle bằng backtick/tilde; tự unregister khi nhãn despawn. HP Player/Boss, modal và số damage được giữ. WeaponDefinition.visual_archetype xác định ngoại hình; PlayerVisualRig tự chọn Kiếm Sĩ/mage theo gear, không chạm gameplay hitbox. Xem [GAME_FEEL_SKINS.md](GAME_FEEL_SKINS.md).

`Player.Visuals` instance `scenes/actors/player_visual_rig.tscn`: Skeleton2D/Root/Hip/Torso/Head, hai chuỗi Shoulder→Arm→Hand→WeaponSlot và hai chuỗi Leg→Foot. `Player.body_sprite` trỏ BodySprite ở Torso. Rig bind bằng actor instance ID, 18 slot texture độc lập, có rest/length explicit và 5 animation mẫu; manual seek đọc pha Weapon/Cast, nhận mirror/flash/hit-stop. Weapon/Hurtbox không là con của xương. [MODULAR_PLAYER_RIG.md](MODULAR_PLAYER_RIG.md) có cây đầy đủ và API lắp atlas.

`SlicePresentation` nghe Hurtbox.hit_resolved, Weapon.attack_committed, action/enemy state_changed và presentation_cast/presentation_burst/presentation_contact từ SpellExecutor. DamageResult thành công tạo sparks + SFX; DOT/blocked không tạo lặp. Một query World tại đầu Active chỉ phát spark chém tường, không thêm DamageEvent/hitbox hoặc đổi physics. Atmosphere duy trì một CanvasModulate, bốn đuốc, Player light, room backdrop/dust. Mỗi room rebuild hủy décor và audio owner cũ; in-flight effect/light tự hủy theo executor.

Budgets: 24 impact owner/lifetime0.48s nhưng chỉ8flash lights mới nhất, 12spell light owner, 24projectile-trail owner, 72ambient GPU particles, 16spatial voice. Mỗi wake tối đa12point/72px và12GPU motes/lifetime0.2s. Burst/projectile vẫn có emissive visual khi hết light budget; giảm số pass đèn trong bài spam. Boss có một core light, mỗi chest có một jade light energy≤0.55; số chest hữu hạn theo room, không tính vào12spell lights. Dummy có tối đa một Tween wobble±3°; hit mới thay Tween, hit-stop chỉ resume Tween đã pause, finished bỏ reference. Texture PNG preload dùng chung; GPU particles headless không emitting nhưng finite owner clock vẫn chạy. AudioManager singleton tạo PCM và voice finite; quit nút/cửa sổ drain mixer80ms. CanvasLayer HUD không chịu CanvasModulate world. Script trình diễn không làm thay đổi stats, collision shape hoặc physics hierarchy.

## Full Visual composition và asset lifetime

Player full-body instance tăng từ42 lên52.5px theo silhouette, giữ physical foot pivot; BodySprite cũ chỉ còn nguồn flash/flip và bị chặn render bằng visibility/self-modulate. Skin theo gear không làm đổi WeaponSocket, Hurtbox hoặc Skeleton hierarchy. Standalone rig vẫn height42, slot trống; đây chưa là atlas animation từng bộ phận.

EnemySpriteArt đọc alpha bounds và lowest foot pixels, cache hai giá trị native trên Texture2D, không giữ script/actor. SlimeSpriteSkin ẩn Body polygon, đọc hướng/flash/death0.25s; Manhunter eyes overlay nằm trên sprite, unbind phục hồi z/position. Mutant Băng/Độc giữ scale2 và tint riêng. BossGolemSkin dùng sprite100px và core jade phase1/amber phase2; old parent draw bị self-modulate0, telegraph320×26 và stomp radius60 được dựng lại từ FSM nguyên gốc. PropSpriteSkin ẩn Dummy Body/Target/Stand, đọc flash và wobble48px quanh chân; chest28px thay old draw, đọc lock/open và hiện tint/checkmark, không giả tạo animation mở nắp từ một PNG.

Các adapter giữ native node ID hoặc native node/WeakRef thay vì thêm state vào Resource definition. Teardown ngắt listener, hủy Tween và phục hồi placeholder khi unbind; sprite/material/light là con của actor/prop và được giải phóng cùng owner. Registry bound_actors chỉ dành actor có Hurtbox; chest bind riêng qua groupchests/has_node để không đổi contract số actor cũ. Khi chạy riêng enemy/dummy/chest scene trong editor, composition SlicePresentation có thể không tồn tại và placeholder gốc vẫn xuất hiện; art mới được gắn trong TestLevel/Alpha/campaign, không sửa serialized physics scenes.

ArtHUD trên CanvasLayer14 đọc runtime HP/Energy/Boss, ba slot Catalyst và vũ khí. Bar legacy vẫn giữ API/value/visibility cho hệ thống cũ nhưng ẩn riêng bằng self-modulate để không vẽ trùng; WeakRef cache phục hồi khi HUD teardown. Bốn icon mới có Hỏa/Phong/kiếm/khiên; các nguyên tố khác dùng fallback tint+tooltip, chưa có đủ năm icon riêng. Hai runtime AtlasTexture crop khung và emblem Boss giữ tỷ lệ rồng thay vì kéo dẹp cả PNG; footer đặt dưới vùng Player đi trên sàn. HUD/modal không chịu ánh sáng canvas thế giới và không bật lại chữ debug.

ArtHUD kiểm Variant từ thuộc tính world và WeakRef còn sống trước cast. Thuộc tính world.boss có thể giữ object đã free sau Dead FSM; HUD không được cast trước kiểm hiệu lực. Boss vắng/chết xóa footer ID/HP/text/tooltip, Boss đang sống giữ cập nhật trực tiếp không reset 0 mỗi frame. Actor rời cây ẩn Player/Boss; HUD chỉ giữ ID/WeakRef. DynamicVFX có 7 kiểm tra vòng đời Boss chết thật, retry, đổi phòng và HUD sống lâu hơn world.

Mười PNG cutout mới gồm hai enemy, hai props, hai HUD frames và bốn icons. Import của đúng10PNG này bật mipmaps, sampler skin/UI LINEAR_WITH_MIPMAPS giảm alias khi minify; PNG/source bytes giữ nguyên. Năm nguồn lịch sử của organizer/AssetPipeline79 giữ import/hash contract riêng. Source mới8file archive nguyên byte tại verification/enemy_art_sources/staging_archive; provenance ghi AI extraction, output hash, tám prompt HUD/props/icon và giới hạn không pixel-exact. Hai enemy và Player full-body cũng chưa có animation sheet. Đường dẫn và pipeline ở [ASSET_PIPELINE.md](ASSET_PIPELINE.md); validation/render của Full Visual ở [COMBAT_ART_POLISH.md](COMBAT_ART_POLISH.md), nghiệm thu hiện hành ở [DYNAMIC_COMBAT_POLISH.md](DYNAMIC_COMBAT_POLISH.md).

## Dynamic presentation và giao dịch save

ProceduralAnimator tính bob 2,5px/lean 8°/breathing 1,035, Slime anticipation/stretch/elastic landing từ clock hiện có. ConceptDynamics và enemy motion chỉ đặt pose dưới pivot chân; full PNG không deform từng xương. Slime hop 6px là visual trong horizontal bite, không đổi AI/physics. ActorShadow đọc foot gốc, reuse World ray và ellipse 24 đỉnh, giới hạn 30Hz/actor; effect owner dọn theo actor.

Shared hit_flash.gdshader nhận active/flash_color, giữ source alpha và tham số flash legacy. Flash trắng 0,08s theo actor/visual clock có chịu hitstop; Player hit-result listener ngắt khi unbind. WeaponTrail/slash_arc.tscn quét crescent 120° trong 0,12s từ Active/Recovery, ink dùng chung mesh 66 đỉnh, recovery fade 0,12s; không thay hit window. SlicePresentation gắn dust 4 hạt vào Dash/landing/Boss stomp, pool 8 owner lifetime 0,34s.

AudioManager.play_weighted_event có 9 cue, PCM click/body/sub-bass đã mix startup, pitch 0,88..1,12, một voice/cue; play_event giữ 5 cue/pitch 0,9..1,1. AudioBusLayout routes SFX_Combat→SFX→Master/Ambient→Master và HardLimiter −0,8dB. Các API chung budget 16 voice/owner ID/realtime deadline/mixer quit, không reset bus/effect người dùng.

SanctuaryProfile giao dịch RAM→validated temp→backup good main→commit→changed. Writer/copy/rename lỗi trả false và rollback Soul/unlock/archive/style/starting weapon; main hỏng không poison backup, future schema từ chối không overwrite. Hub selector gọi set_starting_weapon, refresh về lựa chọn đã commit và báo lỗi khi save thất bại; mua/archive/style cũng có thông báo I/O đúng lý do. Schema 1 giữ 7 field vĩnh viễn cũ, chưa có realm/NPC quest; backup recovery không là cam kết atomic rename ở mọi trường hợp mất điện. Chi tiết clock/ownership/gate/giới hạn ở [DYNAMIC_COMBAT_POLISH.md](DYNAMIC_COMBAT_POLISH.md).

Gate hiện hành sau sửa HUD: 103 script/19 scene/39 Resource gameplay, runner strict mặc định **2.857/2.857**, giữ đủ baseline 2.409 và thêm 448. DynamicVFX 30/30 mỗi 60/120Hz giữ 23 cũ và thêm 7 kiểm tra vòng đời HUD; render preview 14 captures và benchmark GPU Foyer/Boss 60/120 đạt. Gate 2.817/2.843 trước đó giữ làm lịch sử; root cause native editor intermittent cũ chưa chứng minh. Các hệ thống tương lai được chọn (cảnh giới/quest unlock/reward 1-of-3/seed secret) chưa thuộc kiến trúc runtime save v1 này; xem roadmap để tránh nhầm thiết kế với module đã tạo.

## Addendum 08/10/2026 — candidate private, integration pending

- OpeningCultivationState chấp nhận legacy schema1 và compact schema2 (recent8+receipt_floor; revision/next_event đơn điệu). SanctuaryProfile.compact_cultivation_receipts tạo preimage bất biến, commit cùng writer rồi mới bind gameplay; unknown/evicted event không được coi là event mới. Profile writer/seal core không đổi.
- GameFlow giữ NpcWorldState qua expedition; chỉ outcome DungeonRun + reward/corebank đã commit mới recover NPC, trước khi chuyển quyền inventory. NPC write fail giữ run/retry/UID, không cộng lại coin. Hub rebuild/road transition/cold load không tự hồi phục.
- NpcWorldState schema3 giữ legacy death fact trong archive, không tạo permadeath mới; local combat ownership chỉ RAM. Hai CultivatorActor dùng Hurtbox/DamageEvent/Hitbox và actual player identity, không điều khiển hitbox bằng animation.
- RuneLearningService dùng EconomySession busy/publication + SanctuaryProfile event namespace cho5 bài học hữu hạn; knowledge/cost/UID cùng commit. Chế lại dùng giao dịch inventory/material hiện có, không tạo receipt vô hạn theo lần chế.
- Guide/card/readout chỉ đọc source/progress. Confirmation UI revalidates ở owner khi xác nhận; preview không cấp UID hoặc trừ tiền.

- DepthProgress.can_start_floor đọc accepted/unlocked/cleared trong namespace hiện có; DepthGuide gửi floor_number và GameFlow kiểm lại trước chuyển prepared UIDs. Chỉ initial_floor của chuyến đổi, không schema/loot/boss receipt mới. Guide/UI không là authority mở tầng.

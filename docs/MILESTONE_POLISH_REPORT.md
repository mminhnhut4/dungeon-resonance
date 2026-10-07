# Polish Vertical Slice, VFX/Audio, Player Rig và Art Integration

Cập nhật 2026-10-01, Godot 4.7.2 / Compatibility. Milestone nghe–nhìn đã ghép vào TestLevel, Alpha và campaign. Yêu cầu tiếp theo về Skeleton2D, Asset Pipeline và tích hợp art được ghép trong cùng lượt triển khai. Main scene vẫn Hub → đi ải; dữ liệu trang bị, damage và FSM gameplay giữ nguyên.

Mốc hiện hành **Dynamic Combat Polish sau sửa HUD đạt 2.857/2.857 assertion, 0 fail**, giữ 2.409 Full Visual (gồm 2.027 baseline) và thêm 448. Preview GPU 14 ảnh và bốn benchmark Tiền Sảnh/Boss 60/120 đều đạt. Gate 2.843 trước đó sạch nhưng playtest thật tái hiện cast Boss đã free; bản sửa đã qua focused và toàn bộ strict chạy lại. Chi tiết ở [DYNAMIC_COMBAT_POLISH.md](DYNAMIC_COMBAT_POLISH.md). Các phần đầu giữ bằng chứng lịch sử của VFX/Audio/Rig/Art Integration và Full Visual; số 1.957/2.409 hoặc hitstop local-only ở đó không phải toàn bộ trạng thái mới.

## Những gì đã tạo

- `SlicePresentation` nối sự kiện đã resolve sang VFX và SFX. Đòn bị chặn hoặc DOT không lặp flash/âm thanh; hit-stop 0,05s và camera shake vẫn do CombatFeedback quản lý.
- `DungeonAtmosphere` có một CanvasModulate xanh tím, bốn đuốc PNG/AnimatedSprite2D, đốm sáng ấm quanh Player và 72 hạt tro GPUParticles2D. Backdrop đá/vòm/nứt được vẽ procedural và nhận ánh sáng thật. HUD CanvasLayer giữ độ sáng riêng.
- Masonry tĩnh được bake thành hai PNG bằng `tools/bake_dungeon_backdrops.gd`; runtime mỗi backdrop dùng một Sprite2D nhận light. Giữ nguồn procedural và chế độ bake để chỉnh hình, tránh hàng trăm draw commands xen kẽ rectangle/line mỗi khung hình.
- Tiền Sảnh dùng các crop AtlasTexture từ sheet đá thật cho bục/sàn và hai cột dây xích/bùa giấy quanh cửa. Tối đa8đèn khe ngọc; FoyerArt chỉ ẩn/khôi phục Polygon2D placeholder, giữ nguyên collider và cơ chế khóa cửa.
- WorldEnvironment dùng BG_CANVAS, glow threshold0,65/intensity0,35/bloom0,04 trên world layer0. Glow SDR hỗ trợ renderer Compatibility hiện tại; CanvasLayer HUD không tham gia. [Environment](https://docs.godotengine.org/en/stable/classes/class_environment.html) và [2D glow](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html#using-glow-in-2d) là API tham chiếu đã kiểm.
- Player full-sprite có pivot tại đáy BodyCollision, lật theo con trỏ độc lập hướng chạy và Tween thở1→1,03→1 trong1,2s khi Idle. Nguồn PNG giữ nguyên; transparency runtime giữ mặt nạ trắng. Chi tiết và giới hạn nguồn concept ở [ART_INTEGRATION.md](ART_INTEGRATION.md).
- Đạn phép/Firestorm có PointLight2D theo màu snapshot; tối đa 12 light owner. Thay bùa không đổi màu hoặc payload đạn đang bay. Đạn chết kéo theo ánh sáng và xóa owner registry; khi spam vượt ngân sách, đạn vẫn có hình phát sáng.
- `WeaponTrail` dùng mesh additive/shader cho đại đao lửa rộng, song đao tím mỏng, roi xích điện và trượng; vẫn hỗ trợ vũ khí legacy. Đọc Weapon phase/snapshot, không sửa hitbox. Nét debug cũ được ẩn riêng, không ẩn child mesh.
- `ImpactBurst` tạo GPU sparks/vòng chớp/point light cho vật lý, Hỏa, Băng, Độc và Lôi. Lifetime tối đa 0,48s; pool 24 và tối đa 8 nguồn sáng chớp mới nhất, sparks/vòng nổ vẫn chạy. Texture PNG được preload chung, không tạo lại ảnh radial mỗi lần trúng đòn.
- Golem có skin đá phân mảng và lõi rune cyan → amber ở phase 2, flash/stagger/death fade đọc state cũ. Silhouette trong khung 76×100; giữ dấu hiệu báo đòn ngoài thân.
- AudioManager autoload tạo năm cue PCM offline: vung kiếm, dash, phép/nổ, aggro, hurt. AudioStreamPlayer2D, pitch 0,9–1,1, bus DungeonSFX -10dB, tối đa 16 voice; dọn theo finished, owner và deadline wall-clock. Thoát bằng nút/đóng cửa sổ chờ mixer 80ms trước quit.
- Player có rig 14 Bone2D, 18 Sprite2D slot trống trong scene độc lập, 5 clip pose mẫu và RESET. Player instance dùng concept full PNG với mask alpha runtime và điểm tựa chân; bone slots dành cho atlas từng bộ phận. Chi tiết ở [MODULAR_PLAYER_RIG.md](MODULAR_PLAYER_RIG.md).

## Cleanup addon

Phantom Camera không còn static giữ script; draw-limits preference có lifetime manager. Beehave sửa self-reference/debug registry/custom monitor và guard debugger. SmartShape giữ API gốc; Wizard được giữ trong addons nhưng tắt editor plugin ở chế độ chờ thủ công. Không cần executable Aseprite cho pipeline PNG.

Runner mặc định kiểm import, compile cả bốn entrypoint riêng, editor mở scene addon thật, runtime probe và 10 chu kỳ lifecycle. Không lọc warning hoặc bỏ unload gate. Không tải EditorPlugin vào game runtime: đó là trách nhiệm tiến trình editor, được kiểm riêng. [ADDONS.md](ADDONS.md) và [addon_cleanup_evidence.md](verification/addon_cleanup_evidence.md) mô tả bản vá và giới hạn đo.

## Bằng chứng

Runner `./tests/run_tests.ps1` là gate đầy đủ, với warnings-as-errors cho script sản phẩm. `verification/polish_strict_suite.log` giữ số lượt assertion của mốc lịch sử này; `polish_test_summary.json` nay phản ánh gate Dynamic Combat hiện hành ở cuối tài liệu. Tại mốc lịch sử, 1.261 cũ được giữ nguyên, gồm Movement55/Combat100/Resolver20; toàn bộ runner đạt1.957 lượt assertion/0fail, gồm audio/VFX/presentation/rig/art/asset pipeline/addon lifecycle. Headless dùng fixed tick để kiểm logic; không suy ra FPS từ các bài này.

Rig suite đạt52/52 ở cả60/120Hz; kiểm shape transforms/physics origin bất biến, phase của bốn moveset, hai clip combo, mouse commit360, cast release, mirror/flash và lifecycle. Import/editor/runtime addon gates không có GDScript Resource/ObjectDB warning lúc exit.

GPU benchmark chạy Compatibility trên RTX 5080, 1152×648, VSync tắt riêng benchmark; 2s warm-up + 6s đo mỗi mức 60/120. Kịch bản Boss phase 2 + Slime/Eclipse, ánh sáng/72 GPU ash, 10 phép/s, 20 impact burst/s, bốn kiểu trail, 10 loot/s; audio mixer thật hoạt động nhưng bus mute để không phát âm trong lúc người dùng xem phim. HP/energy/Boss HP được giữ và hit-stop tắt riêng đo throughput. JSON `polish_render_60.json` / `polish_render_120.json` ghi FPS, p95, physics peak, draw calls và peak entity.

| Render cap | FPS trung bình | p95 frame gồm chờ cap | Peak physics | Peak draw calls |
|---|---:|---:|---:|---:|
| Boss 60 | 60,01 | 17,713ms | 3,552ms | 502 |
| Boss 120 | 120,00 | 9,031ms | 2,960ms | 523 |
| Tiền Sảnh 60 | 60,00 | 17,421ms | 4,271ms | 378 |
| Tiền Sảnh 120 | 119,99 | 8,800ms | 2,923ms | 476 |

Bản rig trước khi bake nền có lần chỉ đạt111,84FPS ở cap120; nguồn tĩnh xen nhiều rectangle/line tạo gần1.000drawcalls. Bake PNG giữ hình nền và lighting, giảm draw commands; số flash lights cũng được giới hạn để spam không đẩy nhiều pass đèn. Gate benchmark yêu cầu average≥95%cap và p95≤1,4×framebudget. FPS cap là mục tiêu đo, không phải mọi frame đều đúng8,333/16,667ms.

Ảnh render cuối: `art_foyer_idle_right.png`, `art_foyer_idle_left.png`, `art_player_running.png`, `art_player_jumping.png`, `art_player_slash.png`, `art_player_cast.png`, `polish_foyer.png`, bốn `polish_trail_*.png`, `polish_boss_firestorm.png`; preview tự đóng trên màn phụ. Cặp `art_glow_on.png`/`art_glow_off.png` freeze scene/particle có pixel difference, kiểm glow renderer thật. Tiền Sảnh dùng cùng tải spam benchmark và lưu `art_foyer_render_60.json`/`art_foyer_render_120.json`. WAV nghe thử ở `assets/audio/polish_sfx_preview.wav`. Nội dung âm thanh đã kiểm PCM/playback/mixer, chưa có đánh giá chất âm bằng tai từ người dùng.

Sau warm-up, suite presentation lặp Hub → bốn chặng → Hub và kiểm objects/resources không tăng; audio owner, projectile light và finite impact đều hết sau teardown. Các log exit của editor, headless và GPU không được phép có ERROR/WARNING. Đây là bằng chứng stress hữu hạn trên máy hiện tại, chưa là bảo đảm hiệu năng cho mọi thiết bị hoặc run vô hạn.

## Thử trong Godot

F5 chạy main, chọn **Đi ải · 3 tầng + phòng bí mật**. Trong game: F5 đổi bốn vũ khí, F6 ma trận bùa, F8 tới Boss; chuột trái chém, chuột phải phép, Shift dash. Mở `scenes/actors/player_visual_rig.tscn` để xem Skeleton/slot/AnimationPlayer, chọn clip trong editor để preview pose. Rig độc lập không hiện skin khi chưa gán texture; Player instance hiển thị concept PNG và lật theo con trỏ.

Không cần cài công cụ âm thanh hoặc Aseprite. Scene editor đang mở trước thay đổi được giữ nguyên, không đóng cửa sổ có nội dung chưa lưu. Đây là prototype polish/rig; atlas nhân vật từng bộ phận, cân bằng run và art thương mại cần các bước tiếp theo.

API tham chiếu: [PointLight2D](https://docs.godotengine.org/en/stable/classes/class_pointlight2d.html), [CanvasModulate](https://docs.godotengine.org/en/stable/classes/class_canvasmodulate.html), [GPUParticles2D](https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html), [SpriteFrames](https://docs.godotengine.org/en/stable/classes/class_spriteframes.html). Chỉ world canvas có CanvasModulate; UI layer tách riêng để giữ khả năng đọc.



## Game Feel và hai ngoại hình (2026-10-01)

Camera Player zoom1.35, mouse lookahead40px; debug off theo room với phím backtick/tilde; HP/Boss và modal giữ riêng. Kiếm Sĩ alphaPNG/mage theo data gear, pivot khi đổi skin lúc mirror và registry despawn được kiểm. Gate đầy đủ 2.027/2.027, 93scripts/18scenes; GPU60/120Foyer/Boss đạt. Báo cáo phạm vi, AI asset và lỗi native editor đã quan sát: [GAME_FEEL_SKINS.md](GAME_FEEL_SKINS.md).

## Full Visual & Combat Polish (2026-10-01)

Mười PNG alpha đã tích hợp:4icon,2HUDframes,2props vàSlime/Golem. Source staging nguyên byte được archive tại `verification/enemy_art_sources/staging_archive`, provenance/hash và tám prompt HUD/props/icon được lưu. Cutout dùng imagegen, không bảo đảm pixel-exact; sprite toàn thân tĩnh và rương đóng không có animation mở nắp. Mipmaps/sampler LINEAR_WITH_MIPMAPS chỉ áp vào10PNG mới để giảm alias khi thu nhỏ; source lịch sử không bị đổi hash/import contract.

Player art tăng25% lên52,5px và chặn render BodySprite placeholder, giữ collider/physics foot anchor. Slime36px/Golem100px đọc flash/tint/death/FSM cũ; core Golem jade ởphase1,amber ởphase2 và telegraph được giữ. Bia48px có một Tween rung tối đa3° quanh chân; rương28px đọc lock/open/loot và một jade light theo owner. Các adapter không ghi HP/damage, không đổi Hitbox/Hurtbox hoặc timer gameplay.

ArtHUD CanvasLayer14 có HP/shared Energy TextureProgressBar qua alpha socket,3icon bùa,slot vũ khí vàBoss footer500/500 đọc runtime. Các nguyên tố chưa có icon riêng dùng fallback tint+tooltip. Preview phát hiện TextureRect minimum-size của ảnh làm HUD lớn vượt màn hình; helper nay đặt expand/stretch trước texture và kích thước cuối. Boss footer420×91px nằm dưới vùng Player trên sàn. Dummy Tween chỉ resume khi adapter pause do hit-stop và xóa reference khi finished, sửa lỗi play Tween đã hoàn tất.

VFX gồm mesh crescent trắng bạc/viền jade theo Weapon clock,hướng commit; hit sparks GPU vàng cam cho melee/quái/bia/tường; projectile wake Line2D+12GPUhạt vàburst contact vàng/jade. Query tường chỉ thêm cosmeticcontact. Giữ hit-stop0,05s/shake, budgets24impact/8flash/12spell lights/16voice; wake24owners,12points/72px và lifetime0,20s.

Preview GPU cuối **12 captures; PASS**, stderr sạch, gồm Tiền Sảnh4moveset,phép thật trúngHurtbox,Dummy/rương vàBoss2phase. Benchmark mới trênRTX5080/Compatibility1152×648 đều đạt; warm-up2s/đo6s và tải10phép/s,20burst/s,10loot/s với glow/lighting/GPUash vàmixerbusmute. Hit-stop tắt riêng đo throughput.

| Kịch bản/cap | FPS trung bình | p95 frame gồm chờ cap | Peak physics |
|---|---:|---:|---:|
| Tiền Sảnh60 | 59,981 | 17,499ms | 4,581ms |
| Tiền Sảnh120 | 120,003 | 8,769ms | 3,193ms |
| Boss60 | 59,992 | 17,566ms | 3,314ms |
| Boss120 | 119,996 | 9,241ms | 5,932ms |

JSON `full_visual_{foyer,boss}_render_{60,120}.json` vàảnh `combat_art_*` giữ bằng chứng; không thay các số đo lịch sử phía trên. Kịch bản stress hữu hạn không bảo đảm mọi máy hoặc thời gian chơi vô hạn.

**Gate Full Visual lịch sử đạt 2.409/2.409 assertion, 0 fail**, giữ baseline 2.027 và thêm PlayerPolish31/EnemyArt43/CombatPolish47/FullVisualProps39/FullVisualHUD31 ở mỗi 60/120Hz: 382 bổ sung. Movement55/Combat100 đạt cả hai mức, Resolver20 đạt riêng; validator 98 script/18 scene và 39 Resource. Import/editor/addon/main/lifecycle sạch, không lọc ERROR/WARNING. [Log strict Full Visual](verification/full_visual_strict_suite.log) và [summary baseline được giữ](verification/hades_juice_baseline_summary.json) là bằng chứng của mốc đó; summary trung tâm thuộc các gate Dynamic ở phần sau.

Stress finite sau warm-up ở cả 60/120Hz: phép 2556→2556 object/214→214 resource, loot 2701→2701/214→214, Hub 2088→2088/235→235, campaign 1884→1884/236→236, combat VFX 2557→2557/245→245. Enemy/prop teardown không tăng object/resource; điều này không bảo đảm mọi thời lượng chơi vô hạn.

Các lượt chẩn đoán trước gate cuối có **native editor shutdown0xC0000005**, chưa có nguyên nhân/stack đã chứng minh. Log lỗi vẫn được archive; [native audit](verification/full_visual_native_audit.md) phân biệt lỗi này với GDScript retention cũ và không chứng minh addon vô can. Một lượt strict sạch không khẳng định lỗi native gián đoạn đã hết. Chi tiết tính năng, bằng chứng và giới hạn ở [COMBAT_ART_POLISH.md](COMBAT_ART_POLISH.md).

## Dynamic Combat Polish và save transaction (2026-10-01)

Player có bob 2,5px/lean 8° và thở 1,035 trên ConceptDynamics, giữ Tween legacy và pivot/collider. Slime đọc clock horizontal bite để anticipation/stretch/elastic landing và hop visual 6px; Boss idle breath. Cả ba có ellipse 24 đỉnh chiếu World tối đa 30Hz/actor và thu/mờ khi nhảy. Đây là procedural toàn PNG, chưa đổi AI jump hoặc atlas/deform.

Live renderer bật global hitstop scale 0,05/0,06s thực cho melee, 0,12s critical/heavy/Boss; một unscaled timer và root dedup 64. TimeScaleClaims compose min với Tab 0,1, owner cuối trả baseline, không có local freeze còn sót. Headless cũ giữ mode cục bộ; suite mới force global kiểm thật. PlayerCamera trauma² smooth noise 0,2/0,4/0,7 đọc real clock, position/lookahead 40/zoom 1,35 không đổi, có shake_intensity=0. Shared hit_flash giữ alpha và trắng 0,08s theo clock visual; shader thống nhất Player/Slime/Boss/dummy.

Crescent bạc/jade quét 120°/0,12s theo Active/Recovery, thêm viền mực dùng cùng mesh; bụi chân 4 hạt/puff tối đa 8 owner cho Dash/landing/stomp. AudioBusLayout có Master/SFX/SFX_Combat/Ambient, HardLimiter −0,8dB; chín weighted cue pitch 0,88–1,12 và click/sub-bass mix startup, giữ API cũ 5 cue±0,1 và budget 16 voice.

Khảo sát tìm thấy giao dịch SanctuaryProfile từng báo thành công dù save fail. Nay Soul/unlock/archive/discovery/style/starting weapon rollback RAM khi writer/copy/rename fail và chỉ changed sau commit, giữ backup đã validate khi main hỏng, từ chối future schema. UI Hub phục hồi dropdown vũ khí khởi đầu và báo lỗi I/O theo đúng lý do, không hiển thị mua/lưu thành công giả. Schema 1 không đổi, chưa lưu cảnh giới/NPC; recovery bằng backup không đồng nghĩa commit nguyên tử qua mọi mất điện.

Năm suite mới mỗi 60/120Hz: ProceduralActors 38, CombatJuice 51, AudioWeight 47, DynamicVFX 30, SaveTransaction 58; **448 assertion thêm**, baseline 2.409 giữ nguyên. Gate toàn bộ sau sửa HUD đạt **2.857/2.857, 0 fail**, validator 103 script/19 scene/39 Resource. Import/editor/addon lifecycle/rig/main/source/gameplay đều exit 0, không bỏ gate hoặc lọc ERROR/WARNING; [log cuối](verification/hades_juice_strict_suite.log) kết thúc `ALL HEADLESS CHECKS PASSED`, [summary](verification/polish_test_summary.json) có `all_strict_gates_passed=true`. [Gate trung gian 2.817](verification/hades_juice_interim_2817_strict.log) giữ trước khi tăng SaveTransaction 45→58, [gate trung gian 2.843](verification/hades_juice_interim_2843_strict.log) trước khi tăng DynamicVFX 23→30.

Playtest campaign thật phát hiện world.boss vẫn giữ tham chiếu sau khi Dead FSM queue_free; ArtHUD cast trước kiểm hiệu lực sinh `Trying to cast a freed object`. Bản sửa kiểm Variant thô trước cast cả Boss/world properties/legacy WeakRef, xóa footer ID/HP/text/tooltip khi Boss chết/vắng, không reset thanh đang sống mỗi frame. Regression lethal DamageEvent→Dead FSM/free, refresh lặp, retry, đổi phòng và HUD sống lâu hơn world đã tái hiện 30 checks/2 fail trước sửa và đạt 30/30 sau sửa. [Repro](verification/hades_juice_freed_boss_repro.log), [focused fix](verification/hades_juice_freed_boss_fix.log) giữ bằng chứng; lỗi GDScript này tách khỏi native editor intermittent.

Stress finite sau warm-up: combat VFX 2591→2591 objects /251→251 resources ở cả60/120Hz; procedural actors 2574→2567 /230→230 ở120Hz. Suite mới kiểm deadline/claim/release, geometry/clock không lệch, finite shadow/dust/voice và save fault không duplicate; không dùng stress hữu hạn để khẳng định mọi run đều không thể rò rỉ.

Preview GPU **14 captures PASS**, log `verification/hades_juice_preview_boss_lifetime_final.stdout.log`, exit 0/stderr rỗng: idle/shadow, actual Run/Jump/Dash/landing, Slime pose/bite hops, melee thật trúng Hurtbox, Boss heavy hit/stomp; thêm lethal DamageEvent→Boss free/HUD ẩn→E cổng/Victory. Ảnh mới `combat_art_dynamic_*_r3.png`, `combat_art_dynamic_boss_removed_hud_released.png`, `combat_art_dynamic_boss_victory_flow.png`. Chưa đánh giá SFX bằng tai hoặc combat feel chủ quan; user cần playtest. Native editor 0xC0000005 lịch sử chưa root cause, không claim đã sửa.

Bốn benchmark RTX5080/Compatibility1152×648 mới đều PASS (2s warm-up + 6s đo):

| Kịch bản/cap | FPS trung bình | p95 frame | Peak physics | Peak draw calls |
|---|---:|---:|---:|---:|
| Tiền Sảnh60 | 59,989 | 17,435ms | 2,770ms | 300 |
| Tiền Sảnh120 | 119,980 | 9,007ms | 3,012ms | 350 |
| Boss60 | 60,001 | 17,644ms | 3,440ms | 412 |
| Boss120 | 120,000 | 9,289ms | 3,680ms | 472 |

JSON `verification/hades_juice_{foyer,boss}_render_{60,120}.json` giữ dữ liệu thô. Tải thêm 10 foot-puff/s đạt peak 4 owner/16 hạt cùng các tải spells/impacts/loot/mixer cũ; budgets 24 impact/8 flash/12 spell lights/16 voice giữ. Hitstop tắt riêng đo throughput, preview phía trên bật hitstop thật. Không suy FPS từ headless hoặc kết luận mọi máy/run vô hạn, không dùng mixer mute để khẳng định chất âm đã được nghe.

WAV montage đã xuất thật tại `verification/weighted_sfx_preview.wav` (5,51s/save0), log `hades_juice_audio_export.log` có AudioWeight47/47 và shutdown sạch. Campaign screen1 PID32048 đã kết thúc, startup sạch nhưng sau đó sinh lỗi HUD; `hades_juice_playtest_freed_boss_session.json` và stderr lỗi được giữ. Sau gate 2.857 đã mở bản sửa trên screen1 PID29500; session hiện hành và `hades_juice_playtest_visible_r2.stdout.log/.stderr.log` ghi phiên mới. Editor8568/nội dung chưa lưu giữ nguyên. Đây là khởi chạy để người dùng chơi, không chứng minh cả phiên playtest hoặc quit sạch.

Định hướng đã chọn cho gói tiếp theo là run 15–20 phút + Hub tu luyện lâu dài, ba build/cảnh giới/NPC. Đột phá mở chiêu mới chọn một nhánh, đột phá đầu dùng chứng tích Boss + Tàn Hồn; người mới khởi đầu kiếm, kit khác qua quest NPC; chọn đúng một trợ lực NPC ở Hub trước run, khám phá mở lựa chọn cho run sau; reward room chọn 1/3, ordinary drop giữ riêng; mỗi tầng một cơ hội bí mật đổi vị trí/dấu hiệu theo seed. Thiết kế death giữ Soul/realm/formulas/NPC relationship mất gear. Realm/NPC/reward UI/seed secret/trợ lực NPC chưa implement, save v1 giữ progress hiện có. Chi tiết phân biệt thiết kế và code ở [DYNAMIC_COMBAT_POLISH.md](DYNAMIC_COMBAT_POLISH.md) và [CULTIVATION_RUN_ROADMAP.md](CULTIVATION_RUN_ROADMAP.md).

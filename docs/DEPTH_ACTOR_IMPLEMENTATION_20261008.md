# Actors của chuyến đi năm tầng — trạng thái bản riêng

Owner boss_audit, integrator root. Checkout `C:/Users/Admin/AppData/Local/Temp/DgContinue_20261008`; source freeze cuối từ2026-10-08 00:25:14UTC sau refinement art. Chưa ghép main; owner không chạy GPU hoặc full strict suite. Root native lượt trước phát hiện lỗi cắt đầu/chồng pose; lượt cuối đang chờ root review, vì pass logic không chứng nhận hình ảnh.

## Thực hiện

`DepthEnemy` extends BaseEnemy, export depth_floor1..4 được set trước add_child. Mỗi actor duplicate WorldEnemyData hiện hữu, đổi id/tên theo tầng; không sửa definition dùng chung. HP/damage/shield prototype kế thừa bốn archetype cũ. Vân Thạch giữ sweep và có bước lùi hồi phục tạo sườn; Mộc Căn dive/spore poison hiện hữu và rút lên/ra xa qua motor thật; Hàn Kính khóa aim thrust, phạm vi mới180 giúp dash qua mục tiêu; Xích Lô dùng runtime shield/field và lùi hồi chiêu. Giữ status/resolver/root/faction/poise/duplicate gates và actor-owned death signal.

`DepthBoss` extends BossGolem, giữ rig/500HP/stagger/phase threshold/death protocol, tạo moves riêng. Phase1 thrust20 với tell0.70s và narrow140x30; ba orb15 dùng hazard hiện hữu theo fan±0.34rad. Phase2 threshold actualHP<250 chuyển một lần, tell0.90s, sweep280x32 và năm orb fan±0.62rad. Active/recovery riêng và bước lùi vật lý. EnemyHazard khởi tạo aim trong _ready, nên chỉ DepthBoss commit fan direction sau add_child; không thay shared hazard. Budget24 và lifetime/contact dedup của emitter hiện hữu giữ. Stats này là prototype mới, chưa chứng nhận cân bằng.

DepthEnemyArt/DepthBossArt đọc manual actor clocks và actual motor distance, không track method thay damage/hitbox. Metadata cuối dùng one-row PNG với vùng pixel nguyên được tác giả xác định và16pose isolated cho các vùng chồng nhau; không sửa PNG nguồn. Bốn enemy mỗi loại6body+4gait; boss12body+4gait. Semantic pivot đặt theo boot/robe/claw, không lấy mũi vũ khí thấp nhất. Primary scale theo chiều cao cơ thể từng pose, gait giữ một scale cho cả bốn frame. AtlasTexture thêm4pixel khoảng trống trong canvas vẽ và filter_clip; không mask/cắt source alpha để che lỗi. Callback hit/state đọc ngay clocks; boss bổ sung callback contact sau delivery hiện hữu để active body pose không lưu tell trong hitstop đầu tiên. Cleanup chỉ bỏ array view riêng, không clear immutable bank. Cues read live window: sweep/thrust rectangle trùng Hitbox, field64 trùng emitter, fan rays trùng direction. Không thêm light/audio/damage emitter hoặc viết lại Player/old actors.

Root đã nối `custom_boss_visual` metadata guard ở SlicePresentation để không chồng GolemStoneSkin trên boss mới; hit/state/affliction integration vẫn do root sở hữu. Map agent sở hữu DepthCampaign/DepthRoom/spawn/save/reward/lifecycle. Hai scene mới kế thừa BaseEnemy/BossGolem scenes; các legacy files trong manifest giữ initial snapshot hash.

## Lỗi xác minh trong quá trình triển khai

R1: thrust mới đặt center_y=foot-55, height30; Player hurtbox thật foot-18,height32. Box kết thúc cao hơn Player nên không thể trúng grounded Player. Sửa riêng offset/VFX của boss mới về-32. R3 trace chứng minh actual contact một lần, Player100→80. Spore withdraw được motor deceleration làm mượt: ở recovery0.10/0.116s vx còn burst cũ, tới0.225/0.25s vận tốc(90,-90); kiểm sau trong cửa sổ retreat0.32s, không đổi motor để pass.

R2: adapter mới share array từ static texture bank rồi cleanup clear, khiến lần spawn sau mất frames. Đổi sang array view duplicate; AtlasTextures vẫn dùng chung immutable. Thêm repeated actor teardown checks và tất cả raster ngân hàng sống qua3cycles primary/2cycles walk.

DepthCampaign60R2 của map owner chạy23:30:54→23:32:23 trong lúc walk API được thêm23:31:27. Raw lỗi đầu là DepthBossArt đọc frame_scales trên DepthEnemyArt đã cache phiên bản cũ; floor5 tải script boss mới muộn. Sau đó bounds/leaks là hậu quả bind hỏng. Không nới assertions/hide diagnostics. Source đã freeze và yêu cầu map owner chạy fresh process; receipt tích hợp này không được nhận là pass.

## Kiểm thực chạy

| Receipt | Kết quả và giới hạn |
|---|---|
| depth_actor_60_r1 |54checks/2fail, before raster; hai fail thrust lane và early spore recovery |
| depth_actor_asset_import_r1 |headless import exit0, raw diagnostics rỗng |
| depth_actor_60_r2 |59checks/1assertfail và script errors cache teardown; không nhận |
| depth_actor_60_r3 |74/74@60, exit0 diagnostics rỗng, actual6/8body raster |
| depth_actor_120_r3 |74/74@120, exit0 diagnostics rỗng |
| depth_actor_probe_headless_dryrun_r1 |74/74@60, native probe control/trace dryrun; headless không có ảnh; trước append gait |
| depth_walk_import_r1 |headless import gait/newclasses exit0, diagnostics rỗng |
| depth_walk_60_r1 |61/61@60, four real movement frames/each actor, scale/root/freeze/teardown, sạch |
| depth_walk_120_r1 |62/62@120, số quan sát frame khác do timestep; cùng contract, sạch |
| depth_walk_probe_headless_dryrun_r1 |61/61@60, probe control/trace dryrun, sạch; chưa native |

Tận dụng74@60/120 cho damage/states/phase/lifetime đã phù hợp; sau art-only append gait chỉ chạy gate gait hẹp và teardown. Không lặp toàn bộ để tăng tổng. Không tính import/dryrun/source ảnh thành trải nghiệm hoàn thiện. Fixture dùng QA user/save/evidence riêng, không save thật. Chưa thêm tests mới vào default runner; root làm gate strict và integration sau freeze.

## Payload và bước kiểm tiếp

`depth_actor_work/DEPTH_ACTOR_PAYLOAD_MANIFEST.json` hiện chứa12source/test/metadata mới,8uid engine hiện có và hash; đúng27root PNG được tham chiếu là dependency. Các atlas multigrid cũ giữ ở private nhưng không tham chiếu, không thuộc payload. Không sửa main. Root sao lưu rồi ghép một đầu mối sau fresh integration/native review đạt.

Hai external probe ở evidence `depth_actor_work`: depth_actor_native_probe.gd tạo32ảnh paused render đúng timestamp của real state/hitbox/contact/recovery/hurt, bao gồm phase2 sweep recovery/hurt (clinical arena); depth_walk_native_probe.gd tạo10ảnh hai gait frames/actor theo movement thật. Hai probe không sửa sản phẩm, không cùng GPU. Không chứng nhận campaign traversal hoặc ordinary user gameplay vì fixture setup/đổi vị trí chủ động. Native cần xem bodypose/facing/feet/cell clipping/cues và combat contact; map owner/root có configured-main traversal proof riêng.

Rủi ro art còn cần xem native: semantic boot được đặt thủ công và body scale được đo từ source, chưa chứng nhận cảm giác chuyển pose/kích thước/độ đọc tell ở trận thật. Gait bốn frame đã gọi thật trong headless. Không đổi physics/collider để che lỗi render.

## Refinement cuối00:25UTC

Lỗi root native xác minh: grid đều không đúng bố cục source, nên head/cape của pose khác vào Atlas region; alpha-lowest pivot cũng có thể neo vũ khí. Không chấp nhận các ảnh này dù native process/logic không có lỗi. Chuyển sang safe row regions và16isolates, metadata semantic pivots. Phase2 sweep riêng dùng tell8/active9/recover10/hurt11; active9 là low glaive sweep, Xích Lô active3 là ritual field cast. Giữ cơ chế/chỉ số/collider đã kiểm trước.

Lỗi first outgoing contact xác minh: BossGolem sweep giữ cùng FSM state từ tell sang active, trong khi accepted Player hit đã bật hitstop trước lượt physics của Art; body còn pose tell. Test `depth_boss_contact_test.gd --legacy-binding` chỉ tháo cosmetic listener tái hiện2FAIL/4checks. Listener mới nối sau owner delivery, kiểm live source/snapshot/active rồi refresh cùng clock; không gọi shape/time/damage. Fixed4/4 tại60 và120, Player thực nhận damage và snapshot callback đúng active3/9 ngay khi frozen. EnemyArt không cùng đường lỗi vì BaseEnemy enter attack và state_changed seek trước sample_contacts.

| Receipt cuối | Kết quả |
|---|---|
| depth_final_pose_import_r2 |exit0, không ERROR/WARNING/diagnostics |
| depth_atlas_margin_60 |7/7, margin/region/foot identity thực trên Godot4.7.2 |
| depth_raster_final_60_r3 |240/52FAIL:51 fixture JSONfloat-vs-int equality và1 physics catch-up sau đọc pixels; raw lưu đầy đủ |
| depth_raster_final_60_r4 |240/1FAIL: immediate hurt/frame11 đúng, freeze đã hết do synchronous pixel traversal; raw lưu đầy đủ |
| depth_raster_final_60_r5 |242/242@60, source alpha/bounds/full pose/margins/pivots/phase clips/actual hit/freeze/collider/lifetime; sạch |
| depth_walk_final_60_r3 |61/61@60, actual motor/four gait frames/one walk scale/root/hit freeze/teardown; sạch |
| depth_body_contact_baseline_60 |4checks/2FAIL chính xác trước callback, không script ERROR/WARNING |
| depth_body_contact_final_60 và120 |4/4 mỗiHz, first accepted physical outgoing contact seeks active3/9 khi frozen; sạch |

Sửa fixture integer gate bằng kiểm từng số đúng pixel nguyên, không nới border/opaque gate. Flush4physics frames sau synchronous source traversal trước sample hitstop ngắn; không kéo dài hitstop sản phẩm. Numeric `DEPTH_REGION_COMPONENT_QA.json` kiểm51unique regions không cắt component alpha≥8, size≥500pixels; 16full-source isolated giữ toàn image. Godot gate riêng kiểm alpha gốc và4pixel clear draw margin; root native phải xác minh low-alpha haze không tạo ghost. Các nguồn/normals không phải bằng chứng hoàn thiện trải nghiệm.

Tận dụng74@60/120 mechanics trước, không chạy lại toàn bộ sau art-only. Focused final mới có242raster+61gait+8contact checks; default strict toàn dự án và configured-main native vẫn thuộc root. Đóng băng source/metadata sau00:25:14UTC cho root chạy một build nhất quán.

## Skin skill enemy tầng2/4 — freeze00:39:16UTC

Thêm DepthEnemySkillArt và focused test mới, không thaw actor source/metadata. Root nối production hook ở WorldEnemyHazard._ready: actual BaseEnemy cast dùng WorldEnemyHazard, không EnemyHazard của BossOrb. Chỉ live DepthEnemy tầng4/slow_field và tầng2/jade_bolt được skin. Forge dùng rendered FIELD/fire cam, vòng radius64 theo collider; spore dùng PROJECTILE/poison/cyan tip radius7. Đọc age/direction/center/lifetime hiện hữu,2Sprite layers và max16helper; không thêm damage/light/audio/impact.

First accepted forge tick bật Player hitstop trước helper physics khiến paint còn warning: baseline30checks/2FAIL đã tái hiện. Listener accepted hit_resolved kiểm source/root, reject blocked/DOT và đọc cùng hazard.age trước freeze; listener cleanup bằng Hurtbox ID. Final30/30@60 và120 sạch, kiểm actual auto attach, spore12base/poison contact, field2damage/slow,0.45warn/3s expiry, source death, collider/root identity, freeze, cap overflow/restore/foreign/dedup. Giữ damage/slow hiện hữu; màu fire là skin theo lò rèn.

Import lần đầu access violation -1073741819, diagnostics rỗng, chưa rõ nguyên nhân; fresh import r2 exit0 sạch. Raw failures giữ đầy đủ. Configured-main external native probe đã dryrun25/25 sạch,6timestamp records; root còn phải GPU/read6PNG. Probe dùng actual Guide→Flow→DepthCampaign và actual floor roster FSM tạo hazards, có QA proof/floor/positions/AI isolation, không tự spawn native hazard hoặc tăng HP/invulnerability. Geared actual damage có armor, trace giữ base12/base2, poison/slow và exact root. Không nhận headless/source art là native hay trải nghiệm hoàn thiện.

## Native receipts cuối đã đọc00:50UTC

Root actor_final_native_r2 chạy00:30:38.318→00:30:56.928UTC exit0 diagnostics[],109/109 với32PNG; walk_final_native_r2 chạy00:25:57.697→00:26:05.224UTC exit0 diagnostics[],70/70 với10PNG. Root đã xem bodies đầy đủ, không headcut/neighbor ghost, phase2low sweep9 đúng. Đây clinical real-FSM timestamp proof, không natural-play hoặc human combat-feel acceptance.

Root enemy_skill_native_final_r1 chạy00:49:25.603→00:49:40.740UTC exit0 diagnostics[],stdout31/31 (=25logic+6savePNG),6ảnh. Root đã xem forge warning/first-active-frozen/expiry và spore windup/flight/contact rõ trong DepthRoom thật. Existing payload/radius/source/root/life/cleanup giữ. Child chỉ đọc source/receipt, không chạy GPU hoặc tự nhận đã xem ảnh cuối. Configured-main actual Guide/Flow/actor FSM caller đã được xác minh trong fixture khai báo; không đo frame-time từ PNG/readback.

Readonly roster/theme/tactics audit5tầng không thấy mismatch chặn. NPC/room HUD dùng cùng Catalog. Floor1sweep→flank recovery; floor2near dive/far poison spore→withdraw; floor3locked physical thrust/dash; floor4runtime shield+slow field→retreat; floor5phase1thrust/fan, phase2low sweep/wider fan và hai floor4guards. UI không hứa Hàn Kính freeze hay forge burn, không hứa timed shield lower. Minor tên UI: Guide dùng “Huyền Uyên Chấp Ấn”, HUD boss hiện “U Minh Tháp · Thủ Lĩnh Phong Ấn”; cùng mục tiêu tầng5, chưa đồng nhất proper name. Runtime4enemy names hiện có nhưng UI chỉ floor heading/tactic, chưa enemy nameplate riêng. Audit không sửa runtime/tests/assets. Main merge/strict status do root báo cáo riêng.

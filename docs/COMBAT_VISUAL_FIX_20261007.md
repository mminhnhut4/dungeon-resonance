# Combat / bùa / Golem — 2026-10-07

Trạng thái: **đã ghép 28 file vào bản chính, hậu kiểm import + 268 headless + 21 native + 5 cold-load đạt, raw exit0/không ERROR-WARNING**. Không lấy 113 checks hoặc FPS của các mốc trước làm bằng chứng ba lỗi này đã hết.

## Nguồn và môi trường

- Project đọc thành công ngay bước đầu; không gặp `helper_unknown_error: setup refresh had errors`.
- Godot `4.7.2.stable.official.ed1daf0bf`, executable `D:/dowload/Godot_v4.7.2-stable_win64.exe`, SHA256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`.
- Main thật `res://scenes/maps/prologue_hub.tscn`, `GameFlow → ExteriorHub → WorldCampaign`; QA tools OFF. Scene dungeon đo là `res://scenes/world_campaign.tscn`, không phải sân thử.
- Compatibility, OpenGL3.3, RTX5080, driver616.92; cửa sổ1152×648, physics60Hz, cap120, vsyncOFF, Master mute trong tiến trình QA. Không suy ra âm thanh nghe bằng tai.
- Baseline2114 nguồn khớp handoff và được đối chiếu lại trước apply. Không Git; dùng full source snapshot và manifest SHA256. Không đóng/focus phiên của người dùng, không tải lên/cài thêm/đổi bảo mật.
- Full source backup: `C:\Users\Admin\Documents\Codex\2026-10-02\task\combat_spell_boss_20261007_2c4c78df\original_snapshot`. Bản riêng: `C:\Users\Admin\AppData\Local\Temp\DgCSB_2c4c78df`. Receipt/trace/scripts ngoài sản phẩm: `C:\Users\Admin\Documents\Codex\2026-10-02\task\combat_spell_boss_20261007_2c4c78df`.
- Mọi probe save dùng APPDATA/LOCALAPPDATA/DUNGEON_QA_DATA_ROOT riêng và `user://combat_probe/profile.json`; cold process dùng lại đúng QA root. Không đọc/ghi save thật.

## Nguyên nhân được đo và thay đổi

1. **Vệt kiếm tải lại atlas mỗi đòn.** `_on_attack_committed` gọi `load(AtlasTexture)`; recovery xóa sprite texture, không giữ tham chiếu resident. Đo callback tối đa32.357ms. Giữ6 AtlasTexture dùng chung từ `_ready` đến lúc phòng/node hủy; không pool entity hoặc sửa clock/hitbox. Probe bật cache riêng giảm số frame>25ms từ21 xuống13; cache+ngắt riêng mastery xuống0 trong cùng chẩn đoán. Phạm vi strong reference hữu hạn6texture, không giữ qua room teardown.
2. **Mastery hit commit đồng bộ.** Save/seal/JSON diễn ra trên hit thật; baseline mean25.088ms, max29.421ms. Profiling phát hiện quét JSON lặp và journal ẩn vẫn dựng lại button (mean3.588ms, max4.587ms). Scanner lấy2opaque leaf một lượt; writer giữ bản document đã xác minh riêng chỉ khi full byte digest trên đĩa còn khớp, recovery/candidate mới vẫn parse/validate, deep copy chống caller sửa cache. Tránh validate current hai lần và scan toàn candidate chỉ để so opaque leaf. Journal ẩn đánh dấu dirty, mở M mới flush; explicit refresh vẫn đồng bộ. **Vẫn commit/flush giao dịch ngay**, không hoãn mastery, bỏ seal, đổi format, currency, reward hoặc life fence.
3. **Bùa đã sinh thực thể nhưng thân VFX nhỏ/mờ và không có cue windup.** Đường runtime thật: rune rương → GearInventory/Tab1F → Catalyst exact multiset → PlayerCastState committed snapshot → SpellExecutor/SpellProjectile → projectile VFX → physical primary hit/DamageEvent → ImpactBurst. Thêm seal/arrow seek windup/recovery thật; hủy cast tắt cue, cursor sau commit không đổi hướng. Thân Hỏa/Băng/Phong/Lôi/Độc khác hình, viền/ruột unshaded z6, cue z7 dưới HUD; giữ wake12point/12particle/72px và lifetime/owner. Contact giữ element thật, thêm fracture hướng đánh/Phong crescent. Bão Lửa vẽ3spiral trong radius/elapsed thật; không đổi pull/explosion/duration/proc.
4. **Body Golem chỉ PNG với breathing.** Dùng UV MeshInstance2D/ArrayMesh tĩnh khớp phần tay/chân/đầu của chính PNG hiện có, giữ alpha/texture nguồn. Rig trình diễn seek `state_time`, velocity/facing, grounded, hitboxactive, flash/emitted_orbs thật. Có idle/walk, sweep tell/active/recover, orbs gather/release, stomp crouch/air/landing, stagger/hurt và slump/death. Fist strike đạt pose tại contact0.5s; không đặt method track gây damage hoặc dịch collider. Trần đèn/VFX/audio, death deadline, hai sóng stomp và AI/balance giữ nguyên. Đây là rig thủ tục của asset hiện có; chưa phải atlas vẽ mới từng frame.

## Frame-time đo trong giao chiến thật

Mỗi chế độ6.5s, ít nhất8hit melee được DamageResolver chấp nhận; cùng target caoHP đứng yên và Player J thật. Có hồi HP/đặt vị trí fixture và API chuyển tầng, **không chứng nhận natural pace/full run**. Wall-clock từ process-frame; PNG readback nằm ngoài mẫu đo. p99 dưới đây nội suy tuyến tính theo `(n-1)*0.99` từ raw samples, không lấy FPS trung bình thay cho khựng.

| Chế độ | Baseline p99/max ms | Bản riêng cuối p99/max ms | Frame>25ms baseline → riêng |
|---|---:|---:|---:|
| Hitstop bình thường | 38.161 / 41.387 | 23.698 / 27.978 | 21/672 → 6/707 |
| Chỉ tắt hitstop | 41.601 / 42.695 | 29.208 / 32.692 | 24/740 → 11/786 |
| Chỉ ngắt mastery commit | 41.045 / 42.752 | 9.471 / 13.171 | 12/766 → 0/796 |

Hitstop chủ ý60ms thường/120ms heavy/boss, scale0.05 vẫn giữ. Tắt hitstop không xóa spike nên không quy toàn bộ khựng cho hitstop. Mean mastery riêng cuối15.275ms (12.972–18.843); **còn synchronous save peaks, chưa chứng minh hết mọi khựng**. Không dùng mẫu này để cam kết120FPS mọi máy.

## Kiểm tra thực sự đã chạy trên bản riêng

Mỗi hàng là receipt riêng, không cộng các lần lặp thành thành tích mới. PASS chỉ khi assertion0fail, exit0 và raw stdout/stderr không ERROR/WARNING/SCRIPT ERROR; log thất bại vẫn giữ.

| Receipt cuối được chấp nhận | Checks | Kết quả/phạm vi |
|---|---:|---|
| `private_final_import` | import/editor | exit0, không diagnostics; không thay full strict addon gate |
| `spans_many_r1` | 109 | exact opaque/Unicode/duplicate grammar +4many-leaf checks |
| `candidate_final_profile_numeric_seal_test` | 64 | exactfloat64/seal2/downgrade |
| `candidate_final_opening_profile_writer_test` | 250 | writer fault/recovery/authority |
| `final_profile_writer_cache_test` | 8 | cache mutation isolation, external byte change rejection, cold authority |
| `final_r4_save_transaction_test` | 58 | rollback/save |
| `final_r4_opening_social_quarantine_test` | 154 | opaque social/quarantine/fault preservation |
| `final_r4_quest_hidden_refresh_test` | 5 | real main, hidden coalescing, M flush, no disk write |
| `rig_ids_contract` | 24 | actualI/cancel/snapshot,5runes root/caps/free, natural boss clock/hitstop/death/physical resource invariants |
| `candidate_r4_boss_peak_readability_test` | 55 | tell/active/recovery + lights |
| `candidate_r4_talisman_light_readability_test` | 122 | existing light/suppression/readability contracts |
| `candidate_r4_dynamic_vfx_test` | 30 | bounded movement effects |
| `candidate_r4_vfx_test` | 62 | bounded effect roots/lifetimes |
| `final_resonance_test` | 20 | exact recipe/basic/invalid multiset |
| `final_spell_matrix_test` | 64 |10pairs, status/proc/entity budgets; headless không là visual acceptance của tất cả cặp |
| `candidate_rich_r3` | 15 | native actual main/melee A-B, chest equip/I/contact, boss phases/orbs/stomp/death/reward/Hub, exit0 |
| `candidate_cold_r2` | 5 | tiến trình mới đọc mastery/proof/Soul/fullgear UID-quality-stat-slot/Fire recipe đúng |

Native baseline đầy đủ `baseline_rich_r1`15/15, exit0 dùng đối chiếu crash và hình. Các kết quả trước của các tác vụ khác chỉ dùng tham chiếu, không thay các receipt trên. Các byte Player motor/controller/FSM, enemy hit aggro, physics scene/collision, definitions/data/PNG, balance và gate runner không nằm trong payload.

## File sản phẩm và test đã sửa/thêm

- `scripts/presentation/boss_golem_skin.gd`
- `scripts/presentation/impact_burst.gd`
- `scripts/presentation/slice_presentation.gd`
- `scripts/presentation/spell_projectile_vfx.gd`
- `scripts/presentation/weapon_trail.gd`
- `scripts/runtime/profile_commit_writer.gd`
- `scripts/runtime/profile_json_spans.gd`
- `scripts/spells/firestorm_effect.gd`
- `scripts/ui/quest_journal.gd`
- `scripts/presentation/golem_art_rig.gd`
- `scripts/presentation/rune_cast_cue.gd`
- `tests/boss_peak_readability_test.gd`
- `tests/dynamic_vfx_test.gd`
- `tests/map_quest_test.gd`
- `tests/profile_json_spans_test.gd`
- `tests/vfx_test.gd`
- `tests/combat_visual_runtime_test.gd`
- `tests/profile_writer_cache_test.gd`
- `tests/quest_hidden_refresh_test.gd`

Hai script trình diễn mới và ba test mới có `.gd.uid` do private editor tạo. Thêm báo cáo này; cập nhật checkpoint PROJECT_STATE, quyết định tối ưu/rig, nhật ký ngàyOct7. Ba test VFX dùng sourceID của fixture sống thay số ObjectDB giả; không sửa enemy aggro runtime để nới test. `map_quest_test` đổi tên subscription assertion cho journal deferred, không nới geometry assertion.

## Kết quả không đạt và giới hạn

- `candidate_final_map_quest_test`190/191 và `candidate_final_quest_cards`54/55: layout nội dung/button bị cắt800×600. Baseline gốc chạy độc lập **cũng fail đúng hai assertion này**; không nhận full PASS, không sửa UI ngoài phạm vi. Các cỡ lớn và logic phần còn lại vẫn có assertion chạy.
- `candidate_signal_cost_r2` và `candidate_rich_r2` in checks0fail nhưng native exit`0xC0000005`: đều **REJECTED**. Baseline rich sạch; ablation không rig và full rig shutdown riêng sạch nên chưa cô lập root cause. Rest-map instanceID và thử clear texture/material sớm vẫn không đủ: `main_rich_r1/r2` và `rig_retire_extended` đều crash0xC0000005/fault0x547F2C. Baseline extended21/exit0 và ablation tắt riêng skin/rig21/exit0 sạch. Đổi các mảnh UV sang MeshInstance2D/ArrayMesh tĩnh giữ chính điểm cắt/pose: private `rig_mesh_extended`21/exit0 rồi main `main_rich_r3`21/exit0 sạch. Nhánh Polygon2D bị loại; workaround nhánh rig được kiểm trên mẫu này, **không tuyên bố đã giải quyết root cause native trong engine hoặc mọi crash lịch sử**. Raw crash/events trước giữ lại.
- Fixture thử có sai aim sau camera, vị trí rương, ContentSession single-recipe unsupported, thời điểm capture/active, fabricated ObjectDBID và standalone journal cleanup. Đã sửa fixture về actual main/owner/input; không dùng lượt failed hoặc screenshotreadback spikes làm kết luận sản phẩm.
- Chưa chạy full `tests/run_tests.ps1` strict, addon lifecycle toàn bộ, toàn Gameplay60/120 hoặc test ngoài phạm vi; theo yêu cầu tận dụng gate cũ và không lặp toàn bộ không liên quan. Không dùng `-GameplayOnly` làm full gate. Chưa xác nhận một phiên chơi tự nhiên dài hoặc GPU10cặp đầy đủ, chưa nghe âm thanh.

## Ghép / evidence / rollback

Chỉ owner tác vụ này copy file liệt kê từ bản riêng sau guard toàn baseline2114 và backup từng target tại `pre_apply_backup`. APPLY_MANIFEST ghi before/after SHA256; không copy `.godot`, save hoặc patch thử khác. Hậu kiểm main/import/focused/native/cold và hash untouched đã ghi ở receipt cuối bên dưới. Docs `.gdignore` giữ evidence ngoài import.

Evidence đầy đủ (raw failed và accepted) ở task root nêu trên. Bản project lưu ảnh/trace/tóm tắt và receipt chọn tại `docs/verification/combat_visual_20261007/`; `FRAME_METRICS.json`, `frame_time_comparison.svg`, `runtime_contact_sheet.png`. Ảnh là native actual combat; contact sheet chỉ crop/ghép nhãn, không sửa PNG asset nguồn.

Rollback không chạy tự động: đối chiếu hash bản chính với receipt APPLY_MANIFEST trước phục hồi các file cũ từ `pre_apply_backup` hoặc original_snapshot. Các script mới chỉ bị runtime gọi qua file cũ; phục hồi owner cũ ngừng kích hoạt chúng. Không phục hồi toàn thư mục nếu có patch khác sau task.

## Hậu kiểm bản chính và trạng thái cuối

| Receipt trên D:/hầm ngục | Checks | Kết quả |
|---|---:|---|
| main_import | import/editor | exit0, diagnostics rỗng |
| main_profile_json_spans_test | 109 | PASS |
| main_profile_numeric_seal_test | 64 | PASS |
| main_profile_writer_cache_test | 8 | PASS |
| main_mesh_contract | 24 | PASS; rig mesh cuối, real pose/hitbox/death |
| main_quest_hidden_refresh_test | 5 | PASS |
| main_save_transaction_test | 58 | PASS |
| main_rich_r3 | 21 | PASS; native 5bùa đơn + Bão Lửa, tất cả pha Golem, reward/Hub/teardown, exit0 |
| main_cold_r2 | 5 | PASS; tiến trình khác đọc chính save native cuối |

268 headless là tổng6suite cuối, không cộng lần visual24 trước mesh vào tổng. Các receipt đều giữ raw logs. Main native32ảnh; các ảnh pose, spell flight/contact và Bão Lửa đã đối chiếu. Giữ nguyên save/balance/collider/controller/FSM. Không có runtime feature pending ở bản riêng; ngoài bản chính chỉ còn instrumentation/backup/nhánh Polygon2D và các thử nghiệm thất bại.

Mẫu A/B mới cùng `main_probe_r2.gd`, baseline clone2114byte-identical và main mesh cuối; bảng đo trong trận dưới đây thuộc hai lượt **exit0**:

| Chế độ | Baseline p99 / max ms | Main p99 / max ms | >25ms baseline → main |
|---|---:|---:|---:|
| Hitstop bình thường | 37.578 / 38.350 | 23.431 / 27.527 | 21/674 → 4/709 |
| Tắt riêng hitstop | 40.776 / 44.783 | 27.870 / 29.909 | 24/748 → 11/788 |
| Ngắt riêng mastery (chẩn đoán) | 39.146 / 41.824 | 9.333 / 13.100 | 12/770 → 0/796 |

Mean mastery commit baseline 25.678ms → main 14.718ms; vẫn còn spike lưu đồng bộ. Main trace 2293frames/43accepted hits; không lấy FPS trung bình thay smoothness.

Fixture bổ sung r1 khảm trực tiếp Catalyst nên khám phá Bão Lửa emit profile.changed → PermanentProgression.refresh → GearSession.sync_loadout, đưa về Fire thật trong inventory; raw hit chứng minh recipe Fire. R2 chuyển sang grant/equip **chỉ QA inventory** qua API thật và khôi phục canonical full inventory trước victory-save; không sửa runtime để ép PASS. `main_firestorm_diagnosis`14headless sạch, rồi final native21 sạch.

Engine `.exe`, UID/script/data/PNG ngoài payload và2097baselinefile không sửa tiếp đều được SHA256 hậu kiểm. Final receipt `FINAL_VERIFICATION_RESULT.json`; APPLY_MANIFEST có backup cũ và revision mesh/docs. Main và private28sourcefile cuối byte-identical. Nhánh thử không được copy vào sản phẩm.

Lệnh tái hiện (runner và script cùng thư mục evidence; QA root tách biệt tự tạo):

```powershell
$qaRunner='D:/hầm ngục/docs/verification/combat_visual_20261007/run_probe.ps1'
& $qaRunner -Project 'D:/hầm ngục' -Label 'rerun_visual_contract' -Script 'res://tests/combat_visual_runtime_test.gd' -Headless
& $qaRunner -Project 'D:/hầm ngục' -Label 'rerun_combat' -Script 'D:/hầm ngục/docs/verification/combat_visual_20261007/main_probe_r2.gd' -UserArgs @('--label=rerun') -TimeoutSeconds 100
# Cold-load dùng ProfileRoot của RUN_RESULT.json ở lượt native vừa chạy.
```

Native historical crash, residual save peaks, hai layout800×600 và phạm vi fullstrict/long natural run/9cặp GPU còn chưa được chứng nhận đã hết. Các failed probe không bị biến thành PASS sau khi có final clean.


### Bổ sung xác minh dáng đi thực

`main_boss_walk`4/4 native/exit0 sạch: Player ra ngoài130px thì AI cũ tự đi80px/s, boss position đổi thật và rig.pose=walk với khớp chân chuyển động; Player trở vào100px thì motor dừng và rig.pose=idle. Không sửa AI/tốc độ/ngưỡng. Ảnh `boss_actual_walk.png`/`boss_actual_idle.png` đã xem. Ảnh tên boss_walk trong lượt rich trước đứng trong ngưỡng130 nên không dùng làm bằng chứng dáng đi; receipt4 và hai ảnh mới là bằng chứng bổ sung, không cộng vào rich21. Tổng native xác minh cuối gồm21 trận +4 walk riêng, tất cả exit0.

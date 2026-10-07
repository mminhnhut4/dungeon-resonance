# Sửa NPC, cửa hàng khởi đầu và GPU preview — 2026-10-02

Workspace `D:/hầm ngục`; Dungeon Resonance, Godot4.7.2.stable.official.ed1daf0bf/GDScript/Compatibility. Chỉ sửa lỗi có mục tiêu và hoàn tất verification; địa lý/cốt truyện rộng vẫn là đề xuất chờ review. Dùng6.1Sol cho repair và6.1Sol/xhigh cho review, helper input và screen selection. Không liên lạc được với thread Codex gốc bằng API được hỗ trợ; dựa trên source/handoff của dự án, không tuyên bố đã hỏi agent đó.

## Sửa gì và tại sao

1. `scripts/ui/dialogue_box.gd`: chữ tự xuống dòng tạo minimum tạm rất cao trước khi layout ổn định, khiến panel giữ840×1170 dù minimum cuối193×275. Coalesced deferred resize khi minimum/viewport thay đổi đưa panel về840×390; portrait, body scroll, hint/Close footer, typewriter wall-clock và modal/time ownership giữ hành vi hiện hữu.
2. `scripts/hub/prologue_hub.gd`: `common_sword.tres` có gear/saveID`ancient_sword` nhưng EconomySession mua bằng resource/shopkey`common_sword`. UI trước dùng gearID cho quote và nút, làm nút sai/bị disabled. Adapter dùng shopkey đúng cho riêng kiếm khởi đầu, không đổi definition/saveID/giá/transaction.
3. `tests/npc_dialogue_test.gd`: giữ58check cũ, thêm14 hồi quy mua Common qua GUI và portrait/footer/scrolled-goodbye của3NPC ở1152×648/720×480. Helper mouse dùng tọa độ viewport với `root.push_input(event,true)`. Chẩn đoán chứng minh headless window64×64/content1280×720 làm `Input.parse_input_event()` scale sai: cùng nút clicked0/coins1000, còn viewport input clicked1/coins980/items8→9. Đây là lỗi fixture, tách khỏi lỗi shopkey thật.
4. `tests/preview_world_building.gd`: giữ nullguard; mua qua GUI phải trừ giá quote và tăng đúng một item, không chỉ dựa delta20Đồng.
5. `tools/run_render_check.ps1`: chọn màn phụ nếu có, fallback0 khi chỉ có một màn; `-ScreenIndex` tùy chọn được validate trước launch. Giữ hidden console, own-process timeout, stderr/exit checks. R2 đầu có31capture/counter0 nhưng ERROR screen1/count1 nên INVALID; retry sạch mới được PASS.

Nguồn gốc năm file được backup tại task/repair_originals, kiểm SHA256 trước mỗi lần áp dụng; không reset working tree hoặc ghi đè project.godot vừa được editor lưu. Phần thay đổi sau full gate là helper PowerShell và tài liệu; gameplay/GDScript không đổi sau gate.

## Kết quả, tách focused và full

| Kiểm tra | Kết quả |
|---|---|
| NPC trước sửa60Hz |58checks/1failure: footer vượt viewport |
| Focused NPC sau sửa60Hz |72/72,0failure |
| Focused NPC sau sửa120Hz |72/72,0failure |
| Full strict |5.666/5.666assertion,111RESULT,116gate,0failure/ERROR/WARNING; `ALL HEADLESS CHECKS PASSED` |
| Validator/source |148script sản phẩm,31scene,176Resource gameplay |
| Core giữ nguyên |Movement55/Combat100 ở60/120Hz, Resolver20 |
| GPUr2 retry |31captures,0failures,exit0,stderr rỗng; RTX5080/Compatibility; screen0/count1 |

Full gate kiểm import/editor/addon/rig/main/source/gameplay; `-CollectAllFailures` chỉ thu đủ lỗi, không bỏ gate. Không dùng `-GameplayOnly`. Không diễn giải một counter0 hoặc process exit0 thành PASS khi stderr có lỗi.

Lệnh đã chạy:

```powershell
& 'D:\dowload\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\hầm ngục' --fixed-fps 60 --script res://tests/npc_dialogue_test.gd -- --hz=60
& 'D:\dowload\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\hầm ngục' --fixed-fps 120 --script res://tests/npc_dialogue_test.gd -- --hz=120
& 'D:\hầm ngục\tests\run_tests.ps1' -CollectAllFailures
& 'D:\hầm ngục\tools\run_render_check.ps1' -Script res://tests/preview_world_building.gd -Name world_gpu_preview_r2_retry -TimeoutSeconds 120
```

- [Log full](verification/world_repair_strict_20261002_r1.log), [summary mới](verification/world_building_test_summary.json), [manifest nguồn](verification/content_manifest.json).
- [GPU runner sạch](verification/world_gpu_preview_r2_retry.runner.log), [stdout](verification/world_gpu_preview_r2_retry.stdout.log), [stderr](verification/world_gpu_preview_r2_retry.stderr.log), [preview JSON](verification/world_gpu_preview.json).
- [Lượt GPUr2 bị từ chối đúng](verification/world_gpu_preview_r2.runner.log) giữ lỗi screen selection; r1 INVALID cũng được giữ. Gate High Fidelity3.896 và các summary Polish lịch sử không bị ghi đè.

## Ảnh trước/sau

| Bằng chứng | Trước | Sau |
|---|---|---|
| Thoại Thiết Lão |[Panel tràn/clipped](verification/repair_20261002_before/world_smith_dialogue.png) |[Portrait, body scroll và footer trong viewport](verification/world_smith_dialogue.png) |
| Kael |[Previewr1 cửa hàng](verification/repair_20261002_before/world_kael_basic_shop.png) |[Common sword20Đồng và giao dịch thành công](verification/world_kael_basic_shop.png) |

Đã xem hình GPU Thiết Lão/cửa hàng, đối chiếu log actual mouse purchase và regressed GUI input. Hai viewport/baNPC được kiểm bằng GUI input thật trong focused suite. GPU dùng save riêng `user://verification/world_preview_private.json`, supplied fixture/heldHP/zeroThầnThạch; không dùng fixture làm cân bằng game chính.

## Context cho thiết kế thế giới/cốt truyện

Game hành động2D màn ngang, melee/cast ngắm chuột360°, camera zoom1,35/lookahead40px. Căn Cứ Lữ Khách có sân luyện, nhà riêng, kho/lửa/Kael và baNPC Thiết Lão/Thanh Vy/Vô Danh. WorldCampaign hiện tuyến tính4chặng: Tiền Sảnh→Tầng1.5·Khám Phá Bí Mật→Đấu Trường Đột Biến→Golem Cổ Bảo. Seed chỉ shuffle anchor quái trên sàn; chưa có graph nhiều vùng ngoài trời/settlement/shortcut lâu dài.

Canon nguồn rất ít: lời Thanh Vy nói bùa bị oán khí ăn mòn/tịnh hóa linh thức bằng Tàn Hồn; Thiết Lão nói thanh kiếm cổ rỉ sét; Vô Danh từng tới Tầng4 và nhắc lõi phù trận Golem. Không có lịch sử thế giới, niên đại, protagonist có tên hoặc phản diện trung tâm đã chốt. Kael là thương nhân chưa có backstory. NPC text nằm trong `scripts/hub/npc_catalog.gd`; lore mới cần được duyệt, không suy lời thoại thành cơ chế miễn nhiễm kiếm thường.

Death giữ Tàn Hồn đã nhận/kho/công thức/quest/upgrades đã commit; mất gear/vật liệu/Đồng của run. Victory bank Đồng/trả gear còn lại một lần. Profile schema1+safe UID ledger, save rollback và backup quarantine chống nhân đôi. Cảnh giới/quan hệ NPC đầy đủ/reward1-of3/seed secret/kit-unlock qua quest phần lớn còn ở roadmap, không mô tả như đã code.

Mục tiêu cũ run15–20phút và mục tiêu mới campaign≥20giờ là định hướng thiết kế; prototype chưa đo đạt các mốc đó. Ngoại cảnh cần tách travel trong một expedition khỏi kết thúc/bank expedition, giữ cùng session UID/HP/cooldown, và lưu region/discovery/shortcut/quest ID bằng migration giao dịch. [Lát cắt kỹ thuật để duyệt](EXTERIOR_SLICE_PREREQUISITES.md) đề xuất tuyến graybox nhỏ, không tạo canon mới.

## Checkpoint và giới hạn

Code, logs, ảnh và báo cáo đã lưu; các tiến trình verification kết thúc. Không có công việc nền/schedule tiếp tục sửa. Editor hiện có được giữ nguyên. Đây là checkpoint có thể dừng tác vụ cục bộ.

Kiểm tra hữu hạn không chứng minh mọi máy/run20giờ hoặc chất âm/game feel chủ quan. Native editor shutdown lịch sử0xC0000005/fault0x547F2C vẫn chưa root cause; gate sạch lần này không tuyên bố đã sửa nguyên nhân đó. Broad-world narrative/map design phải được review trước khi triển khai rộng.

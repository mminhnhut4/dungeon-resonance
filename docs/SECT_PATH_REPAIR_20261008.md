# Dungeon Resonance — sửa FPS và làm rõ đường tiến triển

Phiên 08/10/2026, nối tiếp baseline main `f626fd9edff51ccad6bdcddf40953b10ebce20ea`. Người dùng đã gia hạn thành **18:00 giờ Việt Nam / 11:00 UTC**. Gói core đã ghép vào **bản chính lúc10:28UTC**, sau strictR4. Các lượt private/main được phân biệt bên dưới. Yêu cầu mới nối năm ải thành tầng4–8 đang triển khai riêng sau checkpoint này.

## Thay đổi core đã ghép bản chính

- **Khựng khi trúng đòn:** lịch sử tu luyện chuyển từ danh sách tăng tới 1.024 receipt sang biểu diễn hữu hạn, giữ 8 receipt gần nhất và mốc chống phát lại. Giữ mastery, cảnh giới, tài nguyên, sequence và đường ghi nguyên tử hiện có. Có bản sao v1 nguyên byte trước migration; lỗi lưu không áp tiến độ mới.
- **Kẹt bậc bên trái:** đóng khe 18 px giữa tường và WestStair mà capsule 20 px lọt xuống. Chỉ sửa mép trái của bậc; giữ mép phải, độ cao và motor/FSM.
- **Mua hàng:** xem món/giá/số dư rồi xác nhận hoặc hủy; Escape hủy trước, giá/khả năng mua được kiểm lại khi trả tiền. Nâng cấp bằng Tàn Hồn cũng có xác nhận.
- **Máu và mana:** giữ nâng máu tối đa hiện hữu, bổ sung mana tối đa bằng Tàn Hồn; tăng dung lượng không hồi đầy hoặc cộng lặp khi đổi đồ.
- **Học bùa chủ động:** Thanh Vy có Học & chế bùa. Học từng nguyên tố một lần, lưu kiến thức và cấp một UID bùa; chế thêm dùng vật liệu trong kho. Giữ bùa nhặt cũ, không bắt học lại để được dùng.
- **Hướng dẫn:** thẻ Trúc Cơ xuất hiện sớm, chỉ điều kiện thiếu và việc làm tiếp; bảng tu luyện phân biệt tu vi với mana. Tab Bùa giải thích cách kiếm/học/lắp bùa. Trang bị có số nền, phẩm cấp/cường hóa, chí mạng, từng đòn và thời gian, cùng so sánh trước/sau.
- **Tu sĩ:** hai đệ tử Thanh Vân/Xích Lô tuần tra, có báo đòn/ra đòn/hồi, phản công qua damage pipeline hiện hữu. Mọi NPC trọng thương rút lui; trở lại sau chuyến hầm ngục thực, giữ ký ức và ID. Không hồi chỉ vì đóng/mở map hoặc tải lại.
- **Tên boss:** HUD tầng 5 dùng Huyền Uyên Chấp Ấn, khớp hướng dẫn Lạc Ấn.
- **Vân Thạch rộng hơn:** tầng đầu tăng từ 1.280 lên 1.920 px, giữ ba vệ binh và bộ chỉ số, chia ba vị trí giao chiến. Thêm nhánh nhảy tới một rương thường, ba mốc chỉ đường; camera, cửa ra và nền phủ theo chiều rộng mới. Tầng 2–5 giữ nguyên hình học. Đây chưa phải mở tầng 6 hoặc tăng thời lượng đã đo bằng người chơi.
- **Chọn lại tầng:** Lạc Ấn cho bắt đầu chuyến ở tầng Depth đã hoàn tất; GameFlow kiểm quyền trước chuyển UID. Giữ tiến trình, không cấp thưởng khi chọn và vẫn đánh lại roster của chuyến mới.

Năm tầng, boss hai phase và gói bùa/map PNG đã có trên baseline của phiên trước; không tính lại là nội dung mới của gói này. Toàn bộ nhân chứng/báo tin/truy nã, thuê đồng hành và chưởng môn chưa được coi là đã có chỉ vì hai NPC có nhãn môn phái.

## Nguyên nhân đã xác minh

1. Profile thật được đọc và sao chụp ổn định ở 07:27 UTC: mastery 1.019, cultivation receipts 1.024. Đường mỗi hit hợp lệ đồng bộ qua model, xác thực và ghi profile. Với 980 receipt, warm mean **153,010 ms/hit**, khoảng 144,58–160,198 ms; ở trần 1.024 không còn nhận lệnh tu luyện mới. Đây là chi phí ngoài hitstop.
2. Candidate recent8 giữ nguyên mastery 1.019 của bản sao. Cùng microprobe 980 receipt: mean **15,615 ms**, max 19,342; bản sao trần 1.024: mean **15,724 ms**, max 17,870. Đây là số CPU transaction, chưa tự chứng minh FPS native.
3. Trận fixture qua Input J → FSM → WeaponHitbox → DamageEvent có 10 root, 20 contact cận chiến/40 resolved event. Callback gồm feedback và mastery còn khoảng 18–19 ms trung bình, nên chưa tuyên bố hết mọi frame khựng.
4. Kẹt được tái hiện bằng di chuyển/nhảy/knockback vào khe, cả 60/120 Hz: đi ngang một giây vẫn không thoát, trong khi cast thật còn hoạt động. Sau sửa hình học, cùng đường vào thoát được. Không phải khóa input toàn bộ.
5. Đo tách parser trên profile gọn: quét chuỗi khoảng 0,279 ms/read, không đủ là lý do mở thêm tối ưu rủi ro. Giữ nguyên JSON guards và readback/seal của writer. Biến động I/O/host chưa được quy nguyên nhân cho antivirus hoặc hệ điều hành.

## Kiểm thử thực chạy tới checkpoint này

Mọi lượt dùng QA APPDATA/LOCALAPPDATA riêng, giữ raw ERROR/WARNING/exit. Kết quả focused không thay full strict; ảnh/render không thay người chơi đánh giá cảm giác.

| Nhóm | Kết quả đã có |
|---|---|
| WestStair | Trước sửa 6 lỗi/38 check ở cả 60/120; sau 38/38 mỗi mức, Movement 55/55 mỗi mức. |
| Receipt compaction | 100/100; model legacy 189/189; probe hiệu năng 62/62. |
| Actual combat headless | Bản sao profile thật 68/68; fixture portable 67/67 ở 60/120. |
| NPC nonlethal | 137/137 ở 60/120, gồm migration/backup/failure/quarantine. |
| Cultivator combat | 60/60 ở 60/120 tại focused checkpoint; full strict sẽ kiểm lại cùng candidate cuối. |
| Rune learning | 183/183 ở 60/120; UID, trả phí một lần, craft, giới hạn túi, lỗi writer và cold recovery. |
| Xác nhận mua | 123/123 ở 60/120; hủy, stale callback/giá, lỗi lưu và cold profile. |
| Về căn cứ/hồi NPC | 29/29 ở 60/120 trong strict R1: real run return, lỗi ghi NPC rồi retry, coins/UID không nhân đôi, cold reload giữ quan hệ; kiểm cả giới hạn cold retry đã nêu bên dưới. |
| Mana/gear/quest | World economy 88/88, inventory equipment 54/54, quest cards 63/63 ở 60 Hz; full strict sẽ phủ candidate cuối. |
| Chọn tầng đã hoàn tất | 55/55 mỗi60/120 và55/55 native,4ảnh; actual E/dropdown/launch3, coldload, reject tầng chưa xong, write-fail, về/bankUID và replayboss không lặp receipt. |
| Mipmap/ảnh nguồn | PlayerArt40/40, PlayerRig52/52; game_feel sau sửa phép so base-level36/36 mỗi60/120. Giữ đủ byte nguồn/mip-chain và PNG sau40lần đổi vũ khí. |
| Bản sao save đang dùng | 110/110 actual main startup/coldload: toàn bộ inventory/UID, số dư, progress, actors/origins, extension và ký ức NPC được giữ; backup migration nguyên byte. Năm file save thật/raw copy không đổi hash. |

Native frame-time đã chạy A/B bằng cùng bản sao 980 receipt (giảm từ 1.024 để baseline vẫn nhận mastery), 2 đòn warm-up rồi 13 đòn mỗi pha. RTX 5080 / Ryzen 7 9800X3D, Compatibility OpenGL 3.3, driver 616.92, 1280×720, cap 120, physics 60, VSync tắt. Mỗi bản 11/11 check; cùng mastery 975→1.003 và 56 chain contact, seal hợp lệ.

| Native rendered frame-time | Main baseline | Candidate |
|---|---:|---:|
| Normal p99 / max | 156,91 / 168,36 ms | 28,38 / 31,35 ms |
| Tắt hitstop p99 / max | 158,94 / 171,30 ms | 28,98 / 31,61 ms |
| Frame >50 ms mỗi pha | 13 | 0 |
| Frame >33,33 ms candidate | — | 0 ở cả hai pha |

Đây là trận có dựng hình, input/Hitbox thật với mục tiêu đứng tại chỗ và setup có kiểm soát; không phải chơi tự nhiên đủ mọi tình huống. Ảnh trận đã xem. Vẫn còn frame 28–31 ms quanh hit, không cam kết nhịp 60/120 FPS tuyệt đối.

UI/NPC native đầu: 117/117 check và 18 ảnh, exit0/diagnostic rỗng; root xem ảnh phát hiện riêng tooltip07 đã biến mất. Kiểm chặt hơn tái hiện mất card khi pointer xuyên xuống ô trống; STOP đạt focused nhưng strict phát hiện chặn click nên đã loại. Trace xác minh `mouse_entered` đến trước `_input`, khiến guard đọc tọa độ cũ. Sửa hai hover callback sang deferred, dùng cùng event position, bỏ callback quá hạn và đóng anchor cũ khi resize; giữ click/focus đồng bộ. Tắt tooltip mặc định “Trống” đang đè lên card riêng. Native cuối **45/45, 6 PNG ở800/1280**, inventory54/54 và modular40/40 cùng source, exit0/diagnostics[]; đã xem top/combo/bottom thật. Các lượt fail và lượt logic đạt nhưng ảnh còn lỗi được giữ riêng.

Default strict R1 đã chạy đủ 257 gate: **236 PASS, 21 FAILED**, source không đổi trong lượt. Các nhóm lỗi có nguyên nhân gồm consumer ảnh không bỏ mipmap trước khi mask base level; tooltip STOP chặn click; fixture chưa bấm xác nhận nâng HP; fixture sequence/nhãn trang bị cũ; callback NPC chưa dọn actor ngay và copy hướng dẫn tiết lộ tên chưa gặp. Một lượt damage_numbers_120 có 34/34 assertion nhưng exit 0xC0000005 vẫn tính FAILED. Các sửa tương ứng đã được đưa vào strict R2 bên dưới. Không lọc ERROR/WARNING hay cộng lượt lỗi thành PASS. Raw giữ tại `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/`.

Strict R2 chạy09:21:21–09:36:30UTC: **259 PASS,2 FAILED/261**,2183file nguồn không đổi. Hai lỗi còn lại là game_feel60/120 so toàn buffer có mipmap với output mask base-level; kiểm tra đã được sửa để so đúng base pixels và thêm xác nhận mip-chain nguồn bất biến. Focused mới36/36 ởcảhai mức sạch09:37. R2 vẫn được lưu là FAILED, không đổi nhãn. Các kiểm tra import/editor/addon và gameplay khác đều đã chạy; strict cuối tiếp theo sẽ kiểm thêm phần Vân Thạch rộng nếu phần đó hoàn tất.

Strict R3 chạy09:55:50–10:11:27UTC: **260 PASS,3 FAILED/263**,2185file nguồn không đổi. Không assertion gameplay nào lỗi; ba process `addon_entrypoints`, `player_rig_editor`, `enemy_art_120` thoát0xC0000005 sau phần kiểm/dọn dẹp. Dump mới đều cùng chuỗi cleanup đã audit; chưa có sửa crash. Một canary project rỗng, headless editor60frame cùng engine, chạy10:12:02–05UTC: exit0/diagnostics[], không copy save. Mẫu sạch này không phủ định lỗi. Root bắt đầu đúng một lượt strictR4 trên cùng source frozen lúc10:12UTC; giữ R3 là FAILED.
**Strict R4 đạt:** chạy10:12:14–10:27:41UTC,263/263gatePASS,0FAILED,2185sourcefilekhôngđổi; cùnghashnguồnR3. Bao gồm import/editor/addon, validator229scripts/37scenes, Movement55/Combat100 mỗi60/120 vàResolver20. Lượt sạch là gate của checkpoint này, không phải bằng chứng đã sửa crash cleanup; R1/R2/R3 vẫn giữ kết quả gốc. Vân Thạch rộng47/47 và terrain150/150 trongdefaultgate (required-raster focused171/171 cảhai mức đã chạy riêng).
Hai tu sĩ đã được nối PNG riêng theo stable ID, import có mipmap, giữ body 60 px/foot pivot/collision và đồng hồ đánh cũ. Native mới 32/32, 6 ảnh, exit0/diagnostic rỗng; root đã xem tuần tra, báo đòn, ra đòn, phản ứng và hai silhouette khác nhau. Ảnh là một pose nguồn chuyển động theo rig hiện hữu, chưa phải atlas đi/chém riêng. Hai đoạn thoại mỗi người mở hướng điều tra dấu niêm, chưa cấp quest hoặc thưởng mới.

## Ghép, bảo vệ save và phần còn lại

**Đã ghép core10:28:30–32UTC:**105file,52preimage được sao lưu,2287file tracked khác được giữ nguyên. Năm file save thật giữ nguyên hash khi ghép. Root là integrator duy nhất, không chép profileQA/cache. Manifest/backup ở `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/handoff_core_final_1028/`. Rehearsal trên đúng105target đã kiểm complete apply, partial apply53target và từ chối hash lạ trước mọi mutation; sentinel/source/backup không đổi.

Hướng chơi cụ thể ở [Hướng dẫn tiến trình](HUONG_DAN_TIEN_TRINH_20261008.md); luật tông môn đã chốt ở [Nhân quả tông môn](SECT_CAUSALITY_DESIGN_20261008.md). [Roadmap cốt truyện và tông môn](SECT_STORY_ROADMAP_20261008.md) đã ghi hai biome riêng, tám vai NPC, 15 nhiệm vụ, học công pháp, khiêu chiến và kế nhiệm chưởng môn. Đây là thiết kế, chưa thêm các map/hệ thống đó vào runtime.

Giới hạn lỗi ghi giữa hai owner: bank profile thành công nhưng NPC sidecar thất bại thì nút retry giữ run trong phiên. Nếu đóng game ngay lúc đó, tiền/UID đã lưu vẫn còn, NPC tiếp tục dưỡng thương tới chuyến sau; chưa có recovery marker bền qua cold start. Không tuyên bố giao dịch giữa hai file là atomic hoặc đã có cold retry cho riêng hồi NPC.

Core đã qua strictR4 và hậu kiểm nêu dưới.  Native frame-time đã có A/B nhưng còn đỉnh 28–31 ms; cần người dùng chơi tự nhiên và nghe âm thanh. Animation đi/đánh riêng theo từng NPC, toàn bộ tông môn và các tầng bổ sung chưa hoàn tất. Native teardown access violation lịch sử chưa có nguyên nhân xác minh; một lượt sạch không được gọi là đã sửa triệt để. Import09:12 cũng thoát0xC0000005 sau hoàn tất scan/layout; Windows ghi cùng fault0x547F2C như damage_numbers_120 và lịch sử, chưa đủ quy lỗi cho một asset.

## Hậu kiểm bản chính và cách hoàn tác

- Import main exit0/diagnostics[]; numeric seal64/64. Bản sao mới của năm file save đang dùng qua110/110 startup/coldload, nguyên UID/chỉ số/số dư/tiến độ/ký ức; chỉ bảnQA được migrate. Hash save thật giữ nguyên tới10:29:01UTC.
- Native combat main10:29:01–28:11/11,2375frame/28root. Normal p99/max29.282/32.031ms; tắt hitstop28.075/32.511ms; cảhai pha không có frame>33.333ms hoặc>50ms. Cùngfixture/hardware với A/B, không phải trải nghiệm tự nhiên hoặc cam kết60FPS mỗi frame.
- Sau đó phát hiện editor và game của người dùng mở17:29:52/58VN. GPU guard từ chối khởi chạy hậu kiểm UI bổ sung; không có testUI main mới, không đóng cửa sổ người dùng. Tái dùng native UI117, tooltip cuối45, NPC32, selector55 và wide47 phù hợp với mã đã ghép; giới hạn của từng fixture vẫn giữ.
- Quan sát đọc sau khi game mở: save dùng cultivation schema2 với8receipt, có bảnbackup migration; file/thứ tự tiến độ đã thay đổi trong phiên đang chơi. Không ghi lại save cũ và không gọi hash của phiên chơi hiện tại là bất biến. HaiEXE Desktop/D: có cùngSHA256.
- Hoàn tác source: `rollback_guarded.ps1 -ManifestPath <handoff_core_final_1028/MANIFEST.json>`. Script từ chối hash lạ, chỉ đổi target đã ghi; **không phục hồi save tự động**. Save đã migrate2 không đọc được bằng codecultivationv1; phải giữ tiến độ mới và xem backup trước khi chọn phương án riêng. Không chạy rollback trong phiên người dùng đang chơi.
- Commit core được ghi tại `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/handoff_core_final_1028/CORE_COMMIT.json` sau khi chốt tài liệu. Raw R1–R4 và các failure vẫn giữ nguyên ở thư mục task.

## Yêu cầu mới đang tiếp tục sau core

Người dùng làm rõ lúc17:34VN: nối cả năm ải trong bảng LạcẤn vào hầm ngục chính, làm các tầng sâu hơn. Hướng đang triển khai: opening1–3/Golem → VânThạch4 → MộcCăn5 → HànKính6 → XíchLô7 → UMinhTháp8; giữ localDepthIDs1..5 và save cũ. Chưa gọi phần nối này là đã ghép cho tới khi có biên bản riêng. Bản nháp làm đẹp cửa phongấn giữ ngoài checkout để nhường ưu tiên cho yêu cầu này.
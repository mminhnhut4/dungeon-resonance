# Đối chiếu assertion UI legacy — 2026-10-08

Nguồn private của hai test đã freeze lúc **01:01:08 UTC**. Chỉ sửa `tests/ui_ux_test.gd` và `tests/opening_progression_guide_test.gd`; không sửa runtime, asset, save thật hoặc bản chính. Root là đầu mối duy nhất quyết định ghép và strict cuối.

## Nguyên nhân đã xác minh

Trước sửa, test UI SHA256 `ED3CE88F730EA70747F8C4CD5FE286C9DBD5203947BE6DD377484B811E8C94C2` và guide test `6B9AA154376AE26B641D4F731D111054422D00BCBF7D74E002A4CC87D3905725` giống byte giữa original_snapshot, main và private. InventoryScreen, GearInventoryModal, MapQuestProjection, OpeningQuestCards, GearInventory, GearSession và PrologueHub cũng giống baseline/main/private; toàn bộ hash ghi trong `UI_LEGACY_PAYLOAD_MANIFEST.json`. QuestJournal private có phần nối depth do owner khác; callback liên quan đã là `_request_refresh` cả ở main/baseline, nên thất bại listener không phát sinh từ phần depth.

Một baseline main với Godot 4.7.2 cùng executable, `--headless --fixed-fps 60`, QA APPDATA mới và không import đã tái hiện đúng **UI 68 checks / 3 FAIL**. Guide baseline tái hiện **202 checks / 1 FAIL**. Guide chạy bản test external cùng nội dung assertion, chỉ đổi đường dẫn xuất bản sao tiếng Việt sang evidence riêng để không ghi vào main.

- Test cũ yêu cầu 3 tab, trong khi InventoryScreen đã có tab Vật phẩm thứ tư; Trang bị/Bùa/Bản đồ vẫn giữ vị trí 0/1/2, 7 ô trang bị, 20 ô túi và 8 ô bùa.
- Test cũ yêu cầu launcher giữ focus khi đóng. Launcher thật đã dùng FOCUS_NONE và InventoryScreen.close giải phóng focus thuộc modal, tránh Enter/A mở lại bảng. Cơ chế này đã có trên main.
- Test cũ tìm Golem trong tiêu đề detail. OpeningQuestCards trình bày tiêu đề thực **Lời hẹn của Vô Danh**; Golem Cổ Bảo nằm trong phần chi tiết. Không có vị trí boss được đánh dấu lên sơ đồ đường bộ. Fixture nay mở trang bản đồ trước signal để đọc projection đang hiển thị, phù hợp hidden coalescing hiện có.
- Guide test cũ đếm Callable `journal.refresh`, nhưng journal đã bind `journal._request_refresh`. Đây là sai callback identity, không phải chứng cứ leak. Callback total của toàn bộ inventory không dùng làm gate.

## Thay đổi test và kết quả thật

UI test giữ kiểm tra bounds, input/cancel, UID equip/unequip, full/empty bag, profile bytes và teardown. Assertion tab kiểm đúng đối tượng/route; focus kiểm launcher hiển thị với FOCUS_NONE và không còn focus ở modal. Bổ sung Enter/A sau đóng không mở lại/đổi UID/nhân đồ và click thật trên launcher vẫn mở đúng focus trang bị. Known bounty kiểm tiêu đề owner, Golem trong detail và objective_room rỗng.

Guide test bind lại 6 lần, kiểm chính xác một `_request_refresh` của journal trên cả inventory/profile, bảo toàn callback của owner khác. Cleanup kiểm instance ID journal cũ, không suy từ chuỗi tên Callable.

| Receipt trong ui_legacy_work | Checks | Exit | Diagnostics |
| --- | ---: | ---: | --- |
| main_ui_before_fixed60 | 68 / 3 FAIL | 1 | 3 assertion FAIL; stderr rỗng |
| main_guide_before_fixed60 | 202 / 1 FAIL | 1 | 1 assertion FAIL; stderr rỗng |
| private_ui_updated_fixed60 | **70 / 70** | **0** | **[]** |
| private_guide_updated_fixed60 | **202 / 202** | **0** | **[]** |

Các lệnh narrow dùng `ui_legacy_work/run_probe.ps1 -Project <main hoặc private> -Label <receipt> -Headless -Script <test> -TimeoutSeconds 45`; guide có thêm `-UserArgs --hz=60`. Runner cố định `--fixed-fps 60`, tách APPDATA/LOCALAPPDATA/DUNGEON_QA_DATA_ROOT, WindowStyle Hidden. Engine SHA256 trong manifest. Toàn bộ stdout/stderr/RUN_RESULT.json được giữ, không lọc lỗi.

Nguồn sau sửa:

- UI test: `91D77FA78D6E915CD32A1FACD74F631C68E553B4119590189F89B0321AB1DB4B`.
- Guide test: `010A49B87E6C8D9743861B6C223BE3A80DDBBAFF846E1D1FFE46889841182015`.

## Giới hạn và bàn giao

Đây là sửa kỳ vọng test đã lỗi thời, không claim sửa lỗi runtime UI. Không GPU, không ảnh mới, không trải nghiệm người chơi tự nhiên. Không chạy lại fullsuite hoặc 120 Hz; root sẽ chạy strict serial sau freeze. Bản chính chưa nhận hai test này tại thời điểm handoff.

Crash damage_numbers C0000005 vẫn **unknown** theo `damage_shutdown_work/DAMAGE_NUMBER_SHUTDOWN_AUDIT.md`; 34/34 assertion và focused sạch không xóa một process exit lỗi của strict trước. Không có sửa nguồn cho crash và không claim đã khắc phục. Strict cuối phải dùng exit/diagnostics thật của lần chạy root mới.

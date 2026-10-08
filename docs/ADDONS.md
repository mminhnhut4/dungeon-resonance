# Godot addons — cài đặt và dọn vòng đời

Milestone Polish Vertical Slice: **Phantom Camera, SmartShape2D và Beehave đang bật; Aseprite Wizard đã cài nhưng tắt thủ công.** Import, editor chứa scene addon thật và kiểm tra vòng đời runtime đã sạch ERROR/WARNING trên Godot **4.7.2.stable.official.ed1daf0bf**. Runner strict mặc định đã vượt các gate này; log `verification/polish_strict_suite.log` kết thúc bằng `ALL HEADLESS CHECKS PASSED`.

Chọn Beehave trong yêu cầu “LimboAI hoặc Beehave” để dùng GDScript, không thay engine/binary. Camera/FSM gameplay hiện hành được giữ; addon có probe riêng để kiểm chức năng thực tế.

## Nguồn và cấu trúc

Các tag được xác minh là bản phát hành mới nhất trên GitHub tại lần cài ngày 2026-09-30. Chỉ lấy thư mục addon, giữ LICENSE upstream.

| Addon | Tag / nguồn chính thức | Thư mục | Chế độ |
|---|---|---|---|
| Phantom Camera | [v0.11.0.3](https://github.com/ramokz/phantom-camera/releases/tag/v0.11.0.3) | res://addons/phantom_camera | Bật |
| SmartShape2D | [3.3.2](https://github.com/SirRamEsq/SmartShape2D/releases/tag/3.3.2) | res://addons/rmsmartshape | Bật |
| Beehave | [v2.9.3](https://github.com/bitbrain/beehave/releases/tag/v2.9.3) | res://addons/beehave | Bật |
| Aseprite Wizard | [v9.8.0-4](https://github.com/viniciusgerevini/godot-aseprite-wizard/releases/tag/v9.8.0-4) | res://addons/AsepriteWizard | Đã cài, tắt thủ công |

SmartShape và Wizard giữ tên thư mục upstream vì code có đường dẫn cố định. `editor_plugins/enabled` chỉ chứa ba plugin đang bật. Các autoload PhantomCameraManager, BeehaveGlobalMetrics và BeehaveGlobalDebugger được đặt rõ trong `project.godot`; Phantom updater_mode=0 để quy trình offline không phụ thuộc mạng.

Archive ZIP và nguồn nguyên bản ở `verification/addon_downloads/`, dưới `docs/.gdignore`. SHA-256 archive ở `verification/addon_downloads/sha256.json`. Manifest tag/mode/hash các file sửa ở `verification/addon_manifest.json`; diff so với upstream ở `verification/addon_cleanup_patches.log`.

## Bản vá local

Tổng cộng tám script vendor khác nguồn archive; không sửa Player hoặc hai FSM.

- PhantomCamera2D: bỏ `static var _draw_limits` vốn giữ GDScript cùng dependency graph; preference dùng chung chuyển sang `PhantomCameraManager.draw_limits_2d`, theo vòng đời Node manager. Signal `tween_interrupted` dùng Node2D và kiểm Host qua interface `get_active_pcam`, giữ các bản vá tương thích từ mốc trước.
- PhantomCameraHost: local trong configuration warning dùng Node; kiểm loại Host bằng chuỗi `Script.get_base_script()` thay self-class constant. Cách này vẫn nhận Host kế thừa.
- SmartShape `normal_range.gd`: gọi static helper cùng script trực tiếp, bỏ self-class prefix. Các thử nghiệm đổi API/constructor/type của SmartShape đã hoàn nguyên.
- Beehave `beehave_node.gd` và `beehave_tree.gd`: kiểm loại qua interface `get_class_name()` thay self-class check trong lambda/debug traversal; các lớp kế thừa vẫn được nhận diện.
- Beehave tree luôn unregister khỏi debugger khi rời scene, cả khi không bật custom monitor. Thêm/xóa performance monitor chỉ khi cần, tránh lỗi xóa monitor không tồn tại hoặc đăng ký trùng.
- Beehave debugger chỉ đăng ký capture và gửi message khi `EngineDebugger.is_active()`, tránh lỗi “No active debugger” trong CLI.

Không dùng `GDScript.reload()` để xóa bytecode, không lọc WARNING/ERROR, không tắt ba addon đang hoạt động để làm sạch kết quả. Khi cập nhật addon, đối chiếu tám bản vá với archive rồi chạy lại các gate.

## Kiểm chứng vòng đời

| Gate strict | Kết quả / phạm vi |
|---|---|
| `--headless --import` | Compile/import và đóng editor sạch ERROR/WARNING, không còn ObjectDB/GDScript Resource retention |
| `addon_test.gd` | **15/15**: metadata/mode/entrypoint tồn tại, camera điều khiển Camera2D, point data, blackboard và registry |
| `addon_cleanup_entrypoints.gd` | **8/8**: metadata và compilation của cả bốn editor entrypoint trong tiến trình riêng |
| Editor mở addon fixture | Scene thật chứa PhantomHost/PhantomCamera2D, SmartShape bốn điểm và BeehaveTree/ActionLeaf; đóng sau 60 frame sạch |
| `addon_cleanup_lifecycle.gd` | **79/79**: warm-up rồi 10 chu kỳ tạo/tick/free; WeakRef của world/point data/blackboard hết; registry và custom monitor được dọn |

Sau warm-up, lifetime test ghi **objects 1566→1566, resources 38→38**. Đây là bằng chứng stress hữu hạn trên các đường đã chạy, không phải chứng minh mọi tổ hợp addon không thể leak. Log verbose editor còn một StringName `Node` ở housekeeping engine, không có WARNING/ERROR hoặc GDScript Resource còn giữ.

Các log strict hiện hành: `verification/import.log`, `addons.log`, `addon_entrypoints.log`, `addon_editor_scene.log`, `addon_lifecycle.log`. Các log `addon_cleanup_*.log` giữ bằng chứng điều tra và hậu kiểm. [Bằng chứng cleanup chi tiết](verification/addon_cleanup_evidence.md).

## Ranh giới editor/runtime

Probe cũ load các `EditorPlugin` GDScript vào tiến trình gameplay vốn đã compile các class runtime. Trong thứ tự này, SmartShape giữ 19 script ở shutdown; load entrypoint riêng hoặc chạy runtime riêng đều sạch. Nguyên nhân nội bộ compiler/cache chưa được kết luận.

Gate mới phản ánh vòng đời dùng thực tế: compiler entrypoint riêng, editor thật bật plugin và mở scene addon, rồi runtime tạo/free node. Tất cả vẫn có kiểm tra strict. Game runtime không load `EditorPlugin`; tách gate không bỏ qua kiểm compilation hoặc scene editor. Những log lỗi cũ được giữ như bằng chứng lịch sử, không mô tả kết quả cuối hiện hành.

## Aseprite và ảnh PNG

Wizard giữ nguyên source nhưng không nằm trong `editor_plugins/enabled`, theo yêu cầu chế độ chờ/manual. Chưa tìm thấy Aseprite.exe trong PATH, Program Files và hai Steam Library đã kiểm. Chưa kiểm nhập `.ase/.aseprite`; không cần CLI cho đường ảnh hiện tại.

Ảnh presentation hiện dùng PNG, `AnimatedSprite2D` và `SpriteFrames` chuẩn của Godot. Khi có Aseprite CLI, cấu hình setting **aseprite/general/command_path**, bật lại Wizard và kiểm import riêng trước khi dùng nó trong asset pipeline. Không tự mua hoặc tải phần mềm thương mại.

## Chạy lại

```powershell
# Đầy đủ gate addon, source và gameplay; WARNING/ERROR vẫn làm fail.
./tests/run_tests.ps1

# Chỉ dùng khi cần kiểm gameplay độc lập; không thay kết quả gate addon.
./tests/run_tests.ps1 -GameplayOnly

& 'D:\dowload\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\hầm ngục' --script res://tests/addon_cleanup_lifecycle.gd --verbose
```
## Cập nhật 08/10/2026 — không đồng nhất lỗi retention cũ với crash mới

Gate strictR3 của candidate sect-path-repair lúc09:56UTC có `addon_entrypoints` in8/8 nhưng exit0xC0000005; `player_rig_editor` cũng crash sau unload addon và lưuEditorSettings. Đây vẫn là FAILED. Dấu vết mới cùng đường cleanup native lịch sử, chưa xác định nguyên nhân; không dùng kết quả cleanup/retention sạch ở mốc cũ để khẳng định không thể crash. Không tắt plugin hoặc đổi runner sangGameplayOnly. Xem [audit native](NATIVE_CRASH_AUDIT_20261008.md) và [báo cáo phiên](SECT_PATH_REPAIR_20261008.md) cho trạng thái gate và quyết định ghép mới nhất.
# Sửa giới hạn tiến trình dùng chung, 13/11/2026

## Nguyên nhân đã tái hiện

Một save chơi bình thường có chín nhóm tiến trình độc lập: `courier`, `abilities`, `depth_expedition_v1`, `member_dungeon_v1`, `sect_journey_v1`, `npc_social`, `tan_dang_mon_v1`, `opening_exploration_v1`, `rune_learning_v1`. TEAM TEST còn có scope QA riêng.

`SanctuaryProfile` chỉ cho tối đa tám namespace. Vì vậy người đã trải nghiệm tám hệ còn lại có thể bị từ chối khi đột phá Trúc Cơ. Tái hiện dùng các owner thật của nhiệm vụ, tầng, trợ giúp NPC, phần thưởng hốc đá và học bùa; lệnh Trúc Cơ thứ chín trả `ability_scope_requires_review`. Không sửa cờ trong save để giả lập đã hoàn thành.

## Thay đổi

- Một hằng `MAX_EXTENSION_NAMESPACES = 16` dùng chung cho đọc envelope, giao dịch thường, đột phá, migration legacy và giao dịch kết hợp NPC/profile.
- Giữ nguyên profile format 1/2, envelope format 1, seal, UID, dữ liệu/receipt và phần thưởng. Không thêm hoặc xóa namespace trong save hiện có.
- Vẫn tối đa 256 receipt/namespace; giới hạn profile 524.288 byte, NPC 32.768 byte và kiểm tra checksum không đổi. Số namespace không bảo đảm mọi state cực đại sẽ cùng vừa giới hạn byte tổng.
- Scope thứ 17 bị từ chối mà không thay primary; các owner đã có vẫn cập nhật/replay được khi đủ 16 scope.

## Kiểm chứng trên Mac

Godot `4.7.2.stable.mono.official.ed1daf0bf`, Compatibility; runtime/cache riêng và user directory riêng `Dungeon Resonance Scope QA/20261113`. Không đọc/ghi save cá nhân, không chạy hoặc đổi AMD/API đang mở.

| Lượt kiểm | Kết quả |
| --- | --- |
| Baseline chưa vá, `profile_scope_capacity_test.gd -- --baseline` | 40 kiểm tra, 1 lỗi đúng tại owner thứ chín; exit 1. Primary và inventory giữ nguyên khi từ chối. |
| Bản vá, `profile_scope_capacity_test.gd -- --run=fixed_4` | 217/217, exit 0. Chín owner thật; giới hạn 16/17; replay; migration sau tám scope; giao dịch NPC kết hợp tại scope 16; Trúc Cơ tại scope 16/17 và từ chối tạo scope NPC mới khi đã đủ 16. |
| Tiến trình Godot mới, `profile_scope_capacity_test.gd -- --cold-check` | 42/42, exit 0. Đọc lại bảy profile có 9 hoặc 16 scope và bốn NPC sidecar; giữ nguyên byte cả hai primary, ledger UID, tu luyện và life state. Manifest rỗng hoặc fixture trùng không được tính đạt. |
| Test có sẵn `test_amd_capsule.gd`, không sửa | 38/38, exit 0. Wire JSON, ngưỡng byte và các trường hợp từ chối. |
| Unit harness .NET 10 biên dịch nguyên `CapsulePolicy.cs` hiện có | 14/14, exit 0. Capsule từ Godot có 9/16 scope, summary, giới hạn byte chính xác và lớn hơn một byte, checksum và đọc payload cũ. |
| `git diff --check` | Đạt. |

Các log lượt cuối không có `ERROR:`, `WARNING:`, `SCRIPT ERROR` hoặc `FAIL:`. Log baseline và hai lần sửa fixture được giữ riêng. Fixture đầu sửa tên class preload; fixture kế so sánh ledger bằng canonical JSON thay vì so sánh trực tiếp int trong RAM với float từ JSON. Không sửa runtime để che lỗi fixture.

Server lưu hai tài liệu như payload opaque, không áp trần số namespace; client cloud đưa việc đọc seal/schema về `SanctuaryProfile`. Vì vậy không phải đổi giới hạn hoặc DTO server/client. Harness server kiểm policy hiện có, không thay thế kiểm endpoint, PostgreSQL, Docker hoặc deployment.

## Chạy lại an toàn

Test tự từ chối nếu chưa có user directory QA riêng. Trên Mac tạo một runtime project riêng, liên kết tài nguyên/source, có cache riêng và các thiết lập:

```ini
[application]
config/name="Dungeon Resonance Scope QA"
config/use_custom_user_dir=true
config/custom_user_dir_name="Dungeon Resonance Scope QA/<mã-lượt-mới>"
```

Đặt `DUNGEON_QA_DATA_ROOT` tới thư mục Application Support `Dungeon Resonance Scope QA`, `DUNGEON_QA_EVIDENCE_ROOT` tới một thư mục bằng chứng riêng. Chạy Godot `--headless --path <runtime-riêng> --script res://tests/profile_scope_capacity_test.gd -- --run=<mã_fixture_mới>`, rồi chạy lại bằng `--cold-check` trong tiến trình mới với cùng runtime/user directory. Không dùng hoặc trỏ test vào save thường; dùng mã fixture mới cho mỗi lần chạy, không xóa save để thử lại.

## Giới hạn và trạng thái

Đây là sửa một điểm chặn tiến trình, không phải triển khai hệ tông chủ/phó tông chủ hoặc mô phỏng thế giới mới. Không thay combat, gear-driven class, ghép bùa hoặc cổng khám phá theo nhiệm vụ.

Save cũ có tối đa tám scope vẫn đọc không cần migration. Binary cũ còn trần tám scope có thể từ chối save mới đã vượt tám; không khẳng định tương thích ngược với client chưa vá. Dùng client đã cập nhật khi chuyển save đó giữa máy.

Đây là kiểm logic/persistence/cloud-policy có giới hạn, không phải full playthrough, strict toàn game, đo FPS, kiểm âm thanh hoặc chứng minh crash lịch sử đã hết. Bản sửa ban đầu ở nhánh local `fix/game-profile-scope-capacity-20261113` (77f4c31), sau đó được tích hợp vào checkout AMD review thành `437827d`. Đã kiểm lại owner 217/217, cold 42/42, capsule 38/38 và native AMD write/restore/edge/menu; xem `docs/amd201/INTEGRATION_MAC_20261113.md`. Trạng thái push/deploy cần đối chiếu remote; tích hợp local không tự chứng minh deployment.
